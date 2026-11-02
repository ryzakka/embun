import 'dart:async';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Satu berkas suara di assets/sound/ beserta volume dasarnya (0..1).
class Snd {
  final String file;
  final double volume;
  const Snd(this.file, [this.volume = 1.0]);

  // ---- UI ----
  static const click = Snd('clickbutton.mp3', 0.8);
  static const click2 = Snd('clickbutton2.mp3', 0.8);
  static const clickTung = Snd('clickbutton-tung.mp3', 0.9);
  static const buy = Snd('buy.mp3', 0.9);

  // ---- efek adegan ----
  static const thunder = Snd('thunder.mp3', 0.9);
  static const slashPedang = Snd('slashpedang.mp3', 0.85);
  static const slashCahaya = Snd('slashgemerciklight.mp3', 0.8);
  static const fairyGrow = Snd('fairygrow.mp3', 0.75);
  static const pagarPenjara = Snd('dentumpagarpenjara.mp3', 0.9);
  static const swingFire1 = Snd('swingfire1.mp3', 0.8);
  static const swingFire2 = Snd('swingfire2.mp3', 0.8);
  static const swingWind1 = Snd('swingwind1.mp3', 0.6);
  static const swingWind2 = Snd('swingwind2.mp3', 0.6);
  static const swingWind3 = Snd('swingwind3.mp3', 0.6);
  static const timer1 = Snd('timermendekatihabis.mp3', 0.8);
  static const timer2 = Snd('timermendekatihabis2.mp3', 0.8);

  static const winds = [swingWind1, swingWind2, swingWind3];
  static const fires = [swingFire1, swingFire2];
  static const timers = [timer1, timer2];

  // ---- musik latar (di-loop) ----
  static const bgmMeja = Snd('backsound01.mp3', 0.32);
  static const bgmProlog = Snd('latarprologawal.mp3', 0.45);
  static const bgmVoting = Snd('dentumanmelodivoting.mp3', 0.45);
  static const bgmAkhir = Snd('latarakhirendingstatistik.mp3', 0.5);
}

class _Voice {
  final Object? owner;
  final String? tag;
  final double volume;
  AudioPlayer? player;
  StreamSubscription<void>? sub;
  bool dead = false; // diminta berhenti
  bool gone = false; // sudah dibuang
  _Voice(this.owner, this.tag, this.volume);
}

class _Lease {
  final Object owner;
  final Snd track;
  _Lease(this.owner, this.track);
}

/// Pemutar suara satu pintu untuk seluruh aplikasi.
///
/// ATURAN ANTI-BOCOR (suara tak boleh bertahan setelah adegannya selesai):
///  * Setiap suara adegan WAJIB membawa `owner: this` (State adegannya) dan
///    adegan itu WAJIB memanggil [release] di `dispose()`. Semua suara milik
///    owner itu dipudarkan dan dibuang, musik yang disewanya dilepas, dan
///    peredam (duck)-nya dicabut.
///  * [play] diam saja bila owner sudah tidak `mounted` (mis. timer yang
///    telat berbunyi setelah adegan ditutup).
///  * Suara yang baru mulai dimuat saat owner dilepas dibuang begitu siap.
///  * Aplikasi ke latar belakang: semua efek langsung dihentikan, musik dijeda.
///  * Dibisukan: semua efek dihentikan dan musik dipudarkan.
///
/// Musik memakai "sewa" bertumpuk: yang terakhir menyewa yang terdengar. Saat
/// sewa itu dilepas, musik sebelumnya (mis. musik meja) otomatis kembali.
class Sfx with WidgetsBindingObserver {
  Sfx._();
  static final Sfx I = Sfx._();

  /// Bisukan semua suara. Ubah nilainya untuk menyalakan / mematikan.
  final ValueNotifier<bool> muted = ValueNotifier<bool>(false);

  static const _maxVoices = 8;
  static const _duckLevel = 0.22;

  final _rng = math.Random();
  final List<_Voice> _voices = [];
  final List<_Lease> _leases = [];
  final Set<Object> _duckers = {};
  final Map<String, Future<AudioPool?>> _pools = {};

  AudioPlayer? _bgm;
  Snd? _bgmTrack;
  double _bgmVol = 0;
  int _epoch = 0;
  bool _syncing = false;
  Timer? _stepTimer;

  bool _inited = false;
  bool _paused = false;

  /// Panggil sekali di main() setelah ensureInitialized.
  void init() {
    if (_inited) return;
    _inited = true;
    WidgetsBinding.instance.addObserver(this);
    muted.addListener(_onMuteChanged);
    // Efek berdampingan dengan musik; jangan merebut fokus audio.
    try {
      AudioPlayer.global
          .setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
            .build(),
      )
          .catchError((Object e) => _log('audioContext', e));
    } catch (e) {
      _log('audioContext', e);
    }
    _log('init', 'siap (kDebugMode=$kDebugMode)');
  }

  /// Cetak galat audio di konsol (mode debug) supaya tidak tertelan diam.
  static void _log(String where, Object e) {
    if (kDebugMode) debugPrint('[Sfx] $where: $e');
  }

  // ===================================================================
  // Efek
  // ===================================================================

  /// Klik singkat tanpa pemilik (sangat pendek, tidak perlu dilepas).
  void click(Snd s) {
    if (muted.value || _paused) return;
    // Di web, musik baru boleh jalan setelah ada sentuhan pengguna: coba lagi
    // bila sebelumnya gagal mulai.
    if (_leases.isNotEmpty && _bgmTrack == null && !_syncing) {
      unawaited(_syncMusic());
    }
    unawaited(() async {
      try {
        final p = await _pools.putIfAbsent(s.file, () => _makePool(s));
        await p?.start(volume: s.volume);
      } catch (e) {
        _log('click ${s.file}', e);
      }
    }());
  }

  Future<AudioPool?> _makePool(Snd s) async {
    try {
      return await AudioPool.createFromAsset(
          path: 'sound/${s.file}', maxPlayers: 3);
    } catch (e) {
      _log('pool ${s.file}', e);
      return null;
    }
  }

  /// Putar [s]. [owner] = State adegan (wajib untuk suara adegan). [tag]
  /// mencegah dua suara bertag sama berbunyi bersamaan (yang baru diabaikan,
  /// kecuali [replace] true: yang lama dipudarkan dan diganti).
  Future<void> play(
      Snd s, {
        Object? owner,
        String? tag,
        bool replace = false,
        double volume = 1.0,
      }) async {
    if (muted.value || _paused || _ownerGone(owner)) return;
    if (tag != null) {
      final same = _voices.where((v) => v.tag == tag && !v.dead).toList();
      if (same.isNotEmpty) {
        if (!replace) return;
        for (final v in same) {
          _stop(v, fadeMs: 150);
        }
      }
    }
    if (_voices.where((v) => !v.dead).length >= _maxVoices) {
      final old = _voices.firstWhere((v) => !v.dead);
      _stop(old, fadeMs: 100);
    }
    final v = _Voice(owner, tag, (volume * s.volume).clamp(0.0, 1.0));
    _voices.add(v);
    try {
      final p = AudioPlayer();
      v.player = p;
      await p.setReleaseMode(ReleaseMode.release);
      v.sub = p.onPlayerComplete.listen((_) => _drop(v));
      await p.play(AssetSource('sound/${s.file}'), volume: v.volume);
      // Dilepas selagi masih memuat: buang begitu siap.
      if (v.dead) _drop(v);
    } catch (e) {
      _log('play ${s.file}', e);
      _drop(v);
    }
  }

  /// Putar salah satu dari [list] secara acak.
  Future<void> playAny(
      List<Snd> list, {
        Object? owner,
        String? tag,
        bool replace = false,
        double volume = 1.0,
      }) =>
      play(list[_rng.nextInt(list.length)],
          owner: owner, tag: tag, replace: replace, volume: volume);

  bool _ownerGone(Object? o) => o is State && !o.mounted;

  void _stop(_Voice v, {int fadeMs = 220}) {
    if (v.gone) return;
    final first = !v.dead;
    v.dead = true;
    final p = v.player;
    if (p == null) return; // belum dibuat: play() akan membuangnya
    if (!first && fadeMs > 0) return; // sudah dalam proses memudar
    if (fadeMs <= 0) {
      _drop(v);
      return;
    }
    unawaited(() async {
      const steps = 5;
      for (var i = 1; i <= steps && !v.gone; i++) {
        await Future<void>.delayed(Duration(milliseconds: fadeMs ~/ steps));
        try {
          await p.setVolume(v.volume * (1 - i / steps));
        } catch (_) {}
      }
      _drop(v);
    }());
  }

  void _drop(_Voice v) {
    if (v.gone) return;
    v.gone = true;
    v.dead = true;
    _voices.remove(v);
    v.sub?.cancel();
    final p = v.player;
    v.player = null;
    if (p != null) {
      unawaited(() async {
        try {
          await p.stop();
        } catch (_) {}
        try {
          await p.dispose();
        } catch (_) {}
      }());
    }
  }

  // ===================================================================
  // Musik
  // ===================================================================

  /// Sewa musik latar untuk [owner]. Yang terakhir menyewa yang terdengar.
  void music(Snd track, {required Object owner}) {
    _leases.removeWhere((l) => identical(l.owner, owner));
    _leases.add(_Lease(owner, track));
    unawaited(_syncMusic());
  }

  /// Turunkan musik (mis. saat adegan layar penuh) selama [on] true.
  void setDuck(Object owner, bool on) {
    final changed = on ? _duckers.add(owner) : _duckers.remove(owner);
    if (changed) _kick();
  }

  /// Lepas SEMUA yang dipegang [owner]: efek (dipudarkan), sewa musik, dan
  /// peredam. Panggil di dispose() setiap adegan yang memakai Sfx.
  void release(Object owner) {
    for (final v in List<_Voice>.of(_voices)) {
      if (identical(v.owner, owner)) _stop(v);
    }
    final hadLease = _leases.any((l) => identical(l.owner, owner));
    _leases.removeWhere((l) => identical(l.owner, owner));
    final hadDuck = _duckers.remove(owner);
    if (hadLease) {
      unawaited(_syncMusic());
    } else if (hadDuck) {
      _kick();
    }
  }

  double _targetVol() =>
      (_bgmTrack?.volume ?? 0) * (_duckers.isEmpty ? 1.0 : _duckLevel);

  Future<void> _syncMusic() async {
    final epoch = ++_epoch;
    final want = (_leases.isEmpty || muted.value || _paused)
        ? null
        : _leases.last.track;
    if (want != null && want.file == _bgmTrack?.file) {
      _kick();
      return;
    }
    if (want == null && _bgmTrack == null) return;
    _syncing = true;
    final p = _bgm ??= AudioPlayer();
    try {
      // Pudar keluar lagu lama.
      if (_bgmTrack != null) {
        const steps = 7;
        final from = _bgmVol;
        for (var i = 1; i <= steps; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          if (epoch != _epoch) return;
          _bgmVol = from * (1 - i / steps);
          try {
            await p.setVolume(_bgmVol);
          } catch (_) {}
        }
      }
      try {
        await p.stop();
      } catch (_) {}
      if (epoch != _epoch) return;
      _bgmTrack = null;
      _bgmVol = 0;
      if (want == null) {
        _syncing = false;
        return;
      }
      await p.setReleaseMode(ReleaseMode.loop);
      await p.play(AssetSource('sound/${want.file}'), volume: 0);
      _bgmTrack = want;
      _bgmVol = 0;
      if (epoch != _epoch) return; // yang lebih baru mengurus sisanya
      _syncing = false;
      _kick();
    } catch (e) {
      _log('musik ${want?.file}', e);
      if (epoch == _epoch) {
        _syncing = false;
        _bgmTrack = null;
      }
    }
  }

  /// Dekatkan volume musik ke targetnya (pudar masuk / duck), bertahap.
  void _kick() {
    _stepTimer ??= Timer.periodic(const Duration(milliseconds: 50), (_) {
      final p = _bgm;
      if (p == null || _bgmTrack == null) {
        _stepTimer?.cancel();
        _stepTimer = null;
        return;
      }
      if (_syncing) return;
      final tgt = _targetVol();
      final diff = tgt - _bgmVol;
      if (diff.abs() < 0.005) {
        _bgmVol = tgt;
        try {
          p.setVolume(_bgmVol);
        } catch (_) {}
        _stepTimer?.cancel();
        _stepTimer = null;
        return;
      }
      _bgmVol += diff.sign * math.min(diff.abs(), 0.035);
      try {
        p.setVolume(_bgmVol);
      } catch (_) {}
    });
  }

  // ===================================================================
  // Siklus hidup & bisu
  // ===================================================================

  void _onMuteChanged() {
    if (muted.value) _stopAllVoices();
    unawaited(_syncMusic());
  }

  void _stopAllVoices() {
    for (final v in List<_Voice>.of(_voices)) {
      _stop(v, fadeMs: 0);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final away = state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    if (away && !_paused) {
      _paused = true;
      _stopAllVoices();
      try {
        _bgm?.pause();
      } catch (_) {}
    } else if (state == AppLifecycleState.resumed && _paused) {
      _paused = false;
      if (_bgmTrack != null && !muted.value) {
        try {
          _bgm?.resume();
        } catch (_) {}
      } else {
        unawaited(_syncMusic());
      }
    }
  }
}

/// Tombol bisu kecil (dipakai di bilah atas).
class SfxMuteButton extends StatelessWidget {
  final double size;
  const SfxMuteButton({super.key, this.size = 26});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: Sfx.I.muted,
    builder: (_, m, _) => IconButton(
      tooltip: m ? 'Nyalakan suara' : 'Matikan suara',
      visualDensity: VisualDensity.compact,
      onPressed: () => Sfx.I.muted.value = !m,
      icon: Icon(
        m ? Icons.volume_off_rounded : Icons.volume_up_rounded,
        size: size,
        color: m ? Colors.white38 : const Color(0xFFE8C766),
      ),
    ),
  );
}