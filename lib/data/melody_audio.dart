import 'dart:async';
import 'melody_music.dart';

/// Platform-independent transport, also used to exercise asynchronous loading,
/// refresh seeks, speed changes and mute without a real speaker or backend.
abstract interface class MelodyAudioPort {
  Future<void> load(String asset);
  Future<void> rate(double value);
  Future<void> volume(double value);
  Future<void> seek(int milliseconds);
  Future<int?> position();
  Future<void> resume();
  Future<void> pause();
  Future<void> dispose();
}

class MelodyMusicController {
  MelodyMusicController(this.port, {int Function()? clockMs, this.onError}) {
    _watch.start();
    _clock = clockMs ?? () => _watch.elapsedMilliseconds;
  }
  final MelodyAudioPort port;
  final void Function(bool failed)? onError;
  final Stopwatch _watch = Stopwatch();
  late final int Function() _clock;
  MelodyMusicFrame? _wanted;
  Future<void>? _worker;
  String? _loaded;
  int _wantedAt = 0, _lastDispatch = -10000;
  bool _failed = false, _fresh = false;
  double _rate = -1, _volume = -1;
  bool _playing = false, _dirty = false, _disposed = false;

  void sync(MelodyMusicFrame frame) {
    if (_disposed) return;
    final old = _wanted;
    final now = _clock();
    _wanted = frame;
    _wantedAt = now;
    final urgent =
        old?.session != frame.session ||
        old?.asset != frame.asset ||
        old?.play != frame.play ||
        old?.rate != frame.rate;
    if (old?.session != frame.session || old?.asset != frame.asset) {
      _failed = false;
    }
    if (_failed || (!urgent && now - _lastDispatch < 75)) return;
    _lastDispatch = now;
    _schedule();
  }

  /// A button can retry playback when browser autoplay was blocked.
  void retry() {
    if (_disposed) return;
    _failed = false;
    _schedule();
  }

  void stop() {
    _wanted = null;
    if (!_disposed) _schedule();
  }

  void _schedule() {
    _dirty = true;
    _worker ??= _drain().whenComplete(() {
      _worker = null;
      if (_dirty && !_disposed) _schedule();
    });
  }

  double _position(MelodyMusicFrame f) =>
      f.positionMs + (f.play ? (_clock() - _wantedAt) * f.rate : 0);

  Future<void> _drain() async {
    while (_dirty && !_disposed) {
      _dirty = false;
      final attempted = _wanted;
      final attemptedKey = attempted == null
          ? null
          : '${attempted.session}/${attempted.asset}';
      try {
        var f = _wanted;
        if (f == null) {
          if (_playing) await port.pause();
          _playing = false;
          continue;
        }
        final key = '${f.session}/${f.asset}';
        if (_loaded != key) {
          await port.pause();
          _playing = false;
          _loaded = null;
          await port.load(f.asset);
          _loaded = key;
          _fresh = true;
          _rate = _volume = -1;
          // Loading may complete after cancellation or a different session.
          if (_disposed) return;
          if (_wanted == null ||
              '${_wanted!.session}/${_wanted!.asset}' != key) {
            _dirty = true;
            continue;
          }
        }
        f = _wanted;
        if (f == null) {
          _dirty = true;
          continue;
        }
        if (!f.play) {
          if (_playing) await port.pause();
          _playing = false;
          if (_volume != 0) await port.volume(0);
          _volume = 0;
          continue;
        }
        final rateChanged = _rate != f.rate;
        if (rateChanged) {
          await port.rate(f.rate);
          _rate = f.rate;
        }
        // The media clock runs continuously. Re-seeking every poll or at
        // each rate change can repeatedly replay the intro on Web when the
        // player reports a stale cursor or cannot yet seek the streamed URL.
        // Align once on start/resume; changing rate never restarts playback.
        if (!_playing) {
          f = _wanted;
          if (_disposed || f == null || !f.play) {
            _dirty = true;
            continue;
          }
          final target = _position(f).round();
          if (!_fresh || target > 80) {
            int? actual;
            try {
              actual = await port.position().timeout(
                const Duration(milliseconds: 250),
              );
            } catch (_) {
              /* A missing cursor is not a reason to restart. */
            }
            f = _wanted;
            if (_disposed || f == null || !f.play) {
              _dirty = true;
              continue;
            }
            final latest = _position(f).round();
            if (actual == null || (actual - latest).abs() > 80) {
              await port
                  .seek(latest)
                  .timeout(const Duration(milliseconds: 1500));
            }
          }
        }
        f = _wanted;
        if (_disposed ||
            f == null ||
            !f.play ||
            '${f.session}/${f.asset}' != _loaded) {
          _dirty = true;
          continue;
        }
        if ((_volume - f.volume).abs() > .004) {
          await port.volume(f.volume);
          _volume = f.volume;
        }
        if (_disposed ||
            _wanted == null ||
            !_wanted!.play ||
            '${_wanted!.session}/${_wanted!.asset}' != _loaded) {
          _dirty = true;
          continue;
        }
        if (!_playing) {
          await port.resume();
          _playing = true;
          _fresh = false;
        }
        _failed = false;
        onError?.call(false);
      } catch (_) {
        if (_disposed) return;
        final current = _wanted;
        final currentKey = current == null
            ? null
            : '${current.session}/${current.asset}';
        if (currentKey != attemptedKey) {
          _failed = false;
          _dirty = true;
          continue;
        }
        // Keep a failure latched until an explicit gesture or a new session.
        // Automatically pause/seek/resume every two seconds creates an intro
        // loop if the platform keeps rejecting a seek/play operation.
        _failed = true;
        _playing = false;
        try {
          await port.pause();
        } catch (_) {}
        onError?.call(true);
        _dirty = false;
      }
    }
  }

  Future<void> flush() async {
    while (_worker != null) {
      await _worker;
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _wanted = null;
    await flush();
    await port.dispose();
    _watch.stop();
  }
}
