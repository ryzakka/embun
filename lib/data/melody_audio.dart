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
  int _wantedAt = 0, _lastCheck = -10000, _lastDispatch = -10000;
  int _retryAt = 0;
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
    if (now < _retryAt || (!urgent && now - _lastDispatch < 75)) return;
    _lastDispatch = now;
    _schedule();
  }

  /// A button can retry playback when browser autoplay was blocked.
  void retry() {
    if (_disposed) return;
    _retryAt = 0;
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
        // Source-file position and rate come from the same frozen timeline
        // used by the chart. No phrase restart and no whole-song reloading.
        if (!_playing || rateChanged || _clock() - _lastCheck >= 500) {
          final actual = _playing ? await port.position() : null;
          f = _wanted;
          if (_disposed || f == null || !f.play) {
            _dirty = true;
            continue;
          }
          final target = _position(f).round();
          if (!_playing ||
              rateChanged ||
              (actual != null && (actual - target).abs() > 90)) {
            await port.seek(target);
          }
          _lastCheck = _clock();
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
        }
        _retryAt = 0;
        onError?.call(false);
      } catch (_) {
        // Failure never changes timing, judge or reward. Retry is available
        // from a user gesture and automatically after a short backoff.
        _retryAt = _clock() + 2000;
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
