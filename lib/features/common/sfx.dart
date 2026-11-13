import 'dart:async';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'menu_playlist.dart';

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

  // ---- narasi ----
  static const narasiProlog = Snd('prolog-narasibicara.mp3', 1.0);

  /// Narasi tutorial, satu per halaman (urut sama dengan TutorialPage).
  static const tutor = [
    Snd('1.selamatdatang.mp3', 1.0),
    Snd('2.peranwarga.mp3', 1.0),
    Snd('3.satusiklus.mp3', 1.0),
    Snd('4.embun.mp3', 1.0),
    Snd('5.pagiberbelanja.mp3', 1.0),
    Snd('6.pasarriset.mp3', 1.0),
    Snd('7.kartukombinasi.mp3', 1.0),
    Snd('8.informasikartupalsu.mp3', 1.0),
    Snd('9.seranganmalam.mp3', 1.0),
    Snd('10.malampersembahan.mp3', 1.0),
    Snd('11.musyawarah.mp3', 1.0),
    Snd('12.nyawa.mp3', 1.0),
    Snd('13.akhirkemenangan.mp3', 1.0),
  ];

  static const winds = [swingWind1, swingWind2, swingWind3];
  static const fires = [swingFire1, swingFire2];
  static const timers = [timer1, timer2];

  // ---- musik latar (di-loop) ----
  static const bgmMeja = Snd('backsound01.mp3', 0.32);
  static const bgmProlog = Snd('latarprologawal.mp3', 0.6);
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
class Sfx with WidgetsBindingObserver {
  Sfx._();
  @visibleForTesting
  Sfx.testing();
  static final Sfx I = Sfx._();

  /// Bisukan semua suara. Ubah nilainya untuk menyalakan / mematikan.
  final ValueNotifier<bool> muted = ValueNotifier<bool>(false);

  static const _maxVoices = 8;
  static const _duckLevel = 0.22;
  static const _narDuckLevel = 0.65; // musik di bawah narasi

  final _rng = math.Random();
  final List<_Voice> _voices = [];
  final List<_Lease> _leases = [];
  final Set<Object> _duckers = {};
  final Map<String, Future<AudioPool?>> _pools = {};

  final Object _menuOwner = Object();
  final MenuPlaylist _menuPlaylist = MenuPlaylist();
  bool _menuEnabled = false;
  bool _bgmIsMenu = false;
  int _sourceSerial = 0;
  int _completionHandledSerial = -1;
  StreamSubscription<void>? _bgmComplete;
  Future<void> _musicQueue = Future<void>.value();

  AudioPlayer? _bgm;
  Snd? _bgmTrack;
  double _bgmVol = 0;
  int _epoch = 0;
  bool _syncing = false;
  Timer? _stepTimer;

  // Narasi (satu saja pada satu waktu); musik latar diredam selama ada.
  AudioPlayer? _nar;
  Object? _narOwner;
  StreamSubscription<void>? _narSub;
  Completer<void>? _narDone;
  double _narVol = 1.0;

  /// Selesai saat narasi yang sedang berjalan habis (atau dihentikan).
  /// Langsung selesai bila tidak ada narasi (mis. suara dibisukan), jadi
  /// aman ditunggu tanpa memeriksa apa pun dulu.
  Future<void> get narrationDone => _narDone?.future ?? Future<void>.value();

  bool _inited = false;
  bool _paused = false;

  /// Panggil sekali di main() setelah ensureInitialized.
  void init() {
    if (_inited) return;
    _inited = true;
    WidgetsBinding.instance.addObserver(this);
    muted.addListener(_onMuteChanged);
    HardwareKeyboard.instance.addHandler(_onKey);

    // PENTING: Jangan panggil AudioPlayer.global di Web karena kanal
    // xyz.luan/audioplayers.global/events tidak diimplementasikan di Web
    // dan akan melempar MissingPluginException.
    if (!kIsWeb) {
      try {
        AudioPlayer.global
            .setAudioContext(
              AudioContextConfig(
                focus: AudioContextConfigFocus.mixWithOthers,
              ).build(),
            )
            .catchError((Object e) => _log('audioContext', e));
      } catch (e) {
        _log('audioContext', e);
      }
    }
    _log('init', 'siap (kIsWeb=$kIsWeb, kDebugMode=$kDebugMode)');
  }

  /// Cetak galat audio di konsol (mode debug) supaya tidak tertelan diam.
  static void _log(String where, Object e) {
    if (kDebugMode) debugPrint('[Sfx] $where: $e');
  }

  /// Di Web, kebijakan autoplay memblokir musik sebelum ada interaksi pengguna.
  /// Panggil ini setiap ada aksi suara agar BGM yang tertahan langsung menyala.
  void _retryMusicIfNeeded() {
    if (_leases.isNotEmpty &&
        _bgmTrack == null &&
        !_syncing &&
        !muted.value &&
        !_paused) {
      unawaited(_syncMusic());
    }
  }

  /// Panggil dari interaksi nyata untuk mencoba lagi jika browser menahan autoplay.
  void unlockAudio() => _retryMusicIfNeeded();

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent) unlockAudio();
    return false;
  }

  /// Manifest memastikan nama huruf besar/kecil cocok dengan berkas yang dibangun.
  Future<void> prepareMenuMusic({Iterable<String>? assetPaths}) async {
    try {
      final paths =
          assetPaths ??
          (await AssetManifest.loadFromAssetBundle(rootBundle)).listAssets();
      _menuPlaylist.replace(MenuPlaylist.fromAssets(paths));
      if (_menuPlaylist.current == null) {
        _log(
          'musik menu',
          'Belum ada musiklatar-1.mp3 sampai musiklatar-4.mp3 di assets/sound/.',
        );
      }
      if (_menuEnabled) {
        _setMenuLease();
        unawaited(_syncMusic());
      }
    } catch (error) {
      _log('manifest musik menu', error);
    }
  }

  /// Satu sewa dasar: berpindah halaman menu tidak mengulang lagu.
  void startMenuMusic() {
    if (_menuEnabled) {
      unlockAudio();
      return;
    }
    _menuEnabled = true;
    _setMenuLease();
    unawaited(_syncMusic());
  }

  void stopMenuMusic() {
    if (!_menuEnabled) return;
    _menuEnabled = false;
    _leases.removeWhere((lease) => identical(lease.owner, _menuOwner));
    unawaited(_syncMusic());
  }

  void _setMenuLease() {
    _leases.removeWhere((lease) => identical(lease.owner, _menuOwner));
    final file = _menuPlaylist.current;
    if (file != null) _leases.insert(0, _Lease(_menuOwner, Snd(file, 0.32)));
  }

  void _menuTrackComplete(AudioPlayer player, int serial) {
    if (serial != _sourceSerial ||
        serial == _completionHandledSerial ||
        !identical(player, _bgm) ||
        !_bgmIsMenu ||
        !_menuEnabled ||
        muted.value ||
        _paused ||
        _leases.isEmpty ||
        !identical(_leases.last.owner, _menuOwner)) {
      return;
    }
    _completionHandledSerial = serial;
    _menuPlaylist.advance();
    _setMenuLease();
    unawaited(_syncMusic());
  }

  // ===================================================================
  // Efek
  // ===================================================================

  /// Klik singkat tanpa pemilik (sangat pendek, tidak perlu dilepas).
  void click(Snd s) {
    if (muted.value || _paused) return;
    _retryMusicIfNeeded();

    // Di Web, gunakan AudioPlayer langsung karena AudioPool kerap gagal pada
    // interaksi pertama di browser.
    if (kIsWeb) {
      unawaited(play(s));
      return;
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
        path: 'sound/${s.file}',
        maxPlayers: 3,
      );
    } catch (e) {
      _log('pool ${s.file}', e);
      return null;
    }
  }

  /// Putar [s]. [owner] = State adegan (wajib untuk suara adegan).
  Future<void> play(
    Snd s, {
    Object? owner,
    String? tag,
    bool replace = false,
    double volume = 1.0,
  }) async {
    if (muted.value || _paused || _ownerGone(owner)) return;
    _retryMusicIfNeeded();

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
  }) => play(
    list[_rng.nextInt(list.length)],
    owner: owner,
    tag: tag,
    replace: replace,
    volume: volume,
  );

  bool _ownerGone(Object? o) => o is State && !o.mounted;

  void _stop(_Voice v, {int fadeMs = 220}) {
    if (v.gone) return;
    final first = !v.dead;
    v.dead = true;
    final p = v.player;
    if (p == null) return;
    if (!first && fadeMs > 0) return;
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
  // Narasi
  // ===================================================================

  /// Putar narasi [s] untuk [owner]. Hanya satu narasi pada satu waktu;
  /// musik latar diredam selama narasi bicara.
  Future<void> narrate(Snd s, {required Object owner}) async {
    await stopNarration();
    if (muted.value || _paused) return;
    _retryMusicIfNeeded();
    final p = AudioPlayer();
    _nar = p;
    _narOwner = owner;
    _narVol = s.volume;
    _narDone = Completer<void>();
    _kick(); // musik meredup
    try {
      await p.setReleaseMode(ReleaseMode.stop);
      _narSub = p.onPlayerComplete.listen((_) => stopNarration());
      await p.play(AssetSource('sound/${s.file}'), volume: s.volume);
    } catch (e) {
      _log('narasi ${s.file}', e);
      if (identical(_nar, p)) await stopNarration();
    }
  }

  /// Lompat ke posisi tertentu pada narasi (mis. saat pemain mengetuk lanjut).
  void seekNarration(Duration to) {
    try {
      _nar?.seek(to);
    } catch (e) {
      _log('seek narasi', e);
    }
  }

  /// Pelankan narasi sampai senyap lalu hentikan (bukan dipotong mendadak).
  /// Dipakai saat semua pemain sepakat melewati cerita.
  Future<void> fadeOutNarration({int ms = 450}) async {
    final p = _nar;
    if (p == null) return;
    const steps = 9;
    for (var i = steps - 1; i >= 0; i--) {
      if (!identical(_nar, p)) return;
      try {
        await p.setVolume(_narVol * i / steps);
      } catch (_) {}
      await Future<void>.delayed(Duration(milliseconds: ms ~/ steps));
    }
    if (identical(_nar, p)) await stopNarration();
  }

  /// Hentikan narasi; musik latar naik lagi.
  Future<void> stopNarration() async {
    final p = _nar;
    _nar = null;
    _narOwner = null;
    _narSub?.cancel();
    _narSub = null;
    final done = _narDone;
    _narDone = null;
    if (done != null && !done.isCompleted) done.complete();
    _kick();
    if (p == null) return;
    try {
      await p.stop();
    } catch (_) {}
    try {
      await p.dispose();
    } catch (_) {}
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

  /// Lepas SEMUA yang dipegang [owner]: efek (dipudarkan), narasi, sewa
  /// musik, dan peredam. Panggil di dispose() setiap adegan yang memakai Sfx.
  void release(Object owner) {
    if (identical(_narOwner, owner)) unawaited(stopNarration());
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

  double _targetVol() {
    // Adegan layar penuh meredam musik dalam (0.22); narasi cukup meredam
    // sedikit supaya musik latar tetap terdengar di bawah suara narator.
    var k = 1.0;
    if (_nar != null) k = _narDuckLevel;
    if (_duckers.isNotEmpty) k = math.min(k, _duckLevel);
    return (_bgmTrack?.volume ?? 0) * k;
  }

  Future<void> _syncMusic() {
    final epoch = ++_epoch;
    // Semua pergantian sumber berjalan berurutan. Pemuatan lagu lama tidak
    // boleh selesai belakangan lalu menimpa musik permainan yang baru masuk.
    _musicQueue = _musicQueue
        .then<void>((_) async {
          if (epoch == _epoch) await _applyMusic(epoch);
        })
        .catchError((Object error) => _log('sinkronisasi musik', error));
    return _musicQueue;
  }

  Future<void> _applyMusic(int epoch) async {
    _leases.removeWhere((lease) => _ownerGone(lease.owner));
    final lease = _leases.isEmpty ? null : _leases.last;
    final want = muted.value || _paused ? null : lease?.track;
    final isMenu = lease != null && identical(lease.owner, _menuOwner);
    if (want != null &&
        want.file == _bgmTrack?.file &&
        isMenu == _bgmIsMenu &&
        _bgm?.state != PlayerState.completed &&
        _bgm?.state != PlayerState.stopped) {
      _kick();
      return;
    }
    if (want == null && _bgmTrack == null) return;
    _syncing = true;
    final player = _bgm ??= AudioPlayer();
    try {
      if (_bgmTrack != null &&
          !muted.value &&
          player.state != PlayerState.completed) {
        const steps = 7;
        final from = _bgmVol;
        for (var i = 1; i <= steps; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          if (epoch != _epoch) return;
          _bgmVol = from * (1 - i / steps);
          try {
            await player.setVolume(_bgmVol);
          } catch (_) {}
        }
      }
      if (epoch != _epoch) return;
      ++_sourceSerial;
      await _bgmComplete?.cancel();
      _bgmComplete = null;
      try {
        await player.stop();
      } catch (_) {}
      _bgmTrack = null;
      _bgmIsMenu = false;
      _bgmVol = 0;
      if (epoch != _epoch || want == null) return;
      final serial = _sourceSerial;
      _bgmComplete = player.onPlayerComplete.listen(
        (_) => _menuTrackComplete(player, serial),
      );
      await player.setReleaseMode(isMenu ? ReleaseMode.stop : ReleaseMode.loop);
      await player
          .play(AssetSource('sound/${want.file}'), volume: 0)
          .timeout(const Duration(seconds: 10));
      if (epoch != _epoch) {
        // Napas terakhir pemuatan lama: hentikan sebelum permintaan berikutnya.
        try {
          await player.stop();
        } catch (_) {}
        return;
      }
      _bgmTrack = want;
      _bgmIsMenu = isMenu;
      _bgmVol = 0;
    } catch (error) {
      _log('musik ${want?.file}', error);
      ++_sourceSerial;
      await _bgmComplete?.cancel();
      _bgmComplete = null;
      try {
        await player.dispose();
      } catch (_) {}
      if (identical(_bgm, player)) {
        _bgm = null;
        _bgmTrack = null;
        _bgmIsMenu = false;
        _bgmVol = 0;
      }
    } finally {
      _syncing = false;
      if (epoch == _epoch && _bgmTrack != null) _kick();
    }
  }

  @visibleForTesting
  Future<void> disposeForTesting() async {
    muted.value = true;
    _menuEnabled = false;
    _leases.clear();
    _stopAllVoices();
    await stopNarration();
    await _syncMusic();
    _stepTimer?.cancel();
    _stepTimer = null;
    await _bgmComplete?.cancel();
    _bgmComplete = null;
    await _bgm?.dispose();
    _bgm = null;
    if (_inited) {
      WidgetsBinding.instance.removeObserver(this);
      HardwareKeyboard.instance.removeHandler(_onKey);
      muted.removeListener(_onMuteChanged);
      _inited = false;
    }
    muted.dispose();
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
    if (muted.value) {
      _stopAllVoices();
      try {
        _nar?.pause();
      } catch (_) {}
    } else {
      try {
        _nar?.resume();
      } catch (_) {}
    }
    unawaited(_syncMusic());
  }

  void _stopAllVoices() {
    for (final v in List<_Voice>.of(_voices)) {
      _stop(v, fadeMs: 0);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final away =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    if (away && !_paused) {
      _paused = true;
      _stopAllVoices();
      try {
        _bgm?.pause();
      } catch (_) {}
      try {
        _nar?.pause();
      } catch (_) {}
    } else if (state == AppLifecycleState.resumed && _paused) {
      _paused = false;
      if (!muted.value) {
        try {
          _nar?.resume();
        } catch (_) {}
      }
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
