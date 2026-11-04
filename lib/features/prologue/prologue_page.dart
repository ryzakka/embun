import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../../data/lobby_repository.dart';
import '../common/art.dart';
import '../common/fx_shaders.dart';
import '../common/ornate.dart';
import '../common/scene_flow.dart';
import '../common/sfx.dart';
import '../table/table_page.dart';
import 'character_pick.dart';
import 'dark_omen.dart';
import 'role_reveal.dart';
import '../../data/game_repository.dart';

double _seg(double v, double a, double b) =>
    ((v - a) / (b - a)).clamp(0.0, 1.0).toDouble();

double _smooth(double x) => x * x * (3 - 2 * x);

/// Suasana tiap adegan: menentukan partikel, kabut, dan warna.
enum _Mood { lush, fading, barren, hope, dark }

/// Satu adegan prolog.
///
/// [frames] adalah urutan gambar bentang (nama berkas tanpa ekstensi) yang
/// saling memudar selama adegan, jadi lembah terlihat benar-benar berubah
/// dari subur menuju kering. [decayFrom]/[decayTo] (0 = subur, 1 = mati)
/// mengatur seberapa pudar warnanya. Kamera bergerak pelan dari
/// [zoomFrom]/[panFrom] ke [zoomTo]/[panTo] (efek Ken Burns).
class _Scene {
  final String text;
  final List<String> frames;
  final int ms;
  final _Mood mood;
  final double decayFrom, decayTo;
  final double zoomFrom, zoomTo;
  final Alignment panFrom, panTo;
  const _Scene({
    required this.text,
    required this.frames,
    required this.ms,
    required this.mood,
    this.decayFrom = 0,
    this.decayTo = 0,
    this.zoomFrom = 1.0,
    this.zoomTo = 1.12,
    this.panFrom = Alignment.center,
    this.panTo = Alignment.center,
  });
}

const _prologue = [
  // 1. Lembah subur.
  _Scene(
    text:
    'Dahulu, di lembah yang dikelilingi kabut,\nberdiri sebuah pohon tua bernama Hayu.',
    frames: ['lembah-hijau0'],
    ms: 6500,
    mood: _Mood.lush,
    zoomFrom: 1.0,
    zoomTo: 1.15,
    panFrom: Alignment(-0.4, 0.3),
    panTo: Alignment(0.3, -0.2),
  ),
  // 2. Desa yang hidup.
  _Scene(
    text:
    'Selama Hayu berdaun,\nsungai mengalir, buah bergelantungan,\ndan desa tidak pernah gelap.',
    frames: ['rumahdesa-hijau'],
    ms: 6500,
    mood: _Mood.lush,
    zoomFrom: 1.14,
    zoomTo: 1.0,
    panFrom: Alignment(0.7, -0.4),
    panTo: Alignment(-0.5, 0.3),
  ),
  // 3. Kemerosotan: subur -> mulai layu, lalu kering, daun berguguran.
  _Scene(
    text:
    'Suatu musim, kabut turun terlalu lama.\nSatu per satu daun Hayu gugur tanpa angin.',
    frames: ['lembah-hijau1', 'lembah-hijau2', 'lembah-hijau3'],
    ms: 9000,
    mood: _Mood.fading,
    decayFrom: 0.05,
    decayTo: 0.55,
    zoomFrom: 1.02,
    zoomTo: 1.15,
    panFrom: Alignment(0.3, 0.2),
    panTo: Alignment(-0.3, -0.2),
  ),
  // 4. Gersang, dilupakan.
  _Scene(
    text:
    'Orang-orang desa berbisik:\npohon itu tidak sedang sakit,\nia sedang dilupakan.',
    frames: ['lembah-hijau4', 'rumahdesa-gersang'],
    ms: 8000,
    mood: _Mood.barren,
    decayFrom: 0.7,
    decayTo: 0.85,
    zoomFrom: 1.12,
    zoomTo: 1.0,
    panFrom: Alignment(-0.6, 0.0),
    panTo: Alignment(0.5, 0.2),
  ),
  // 5. Harapan: kamera naik menyusuri batang Hayu, cahaya hangat.
  _Scene(
    text: 'Maka mereka datang,\nmembawa air, doa, dan pita harapan.',
    frames: ['pohon-zoom', 'pohon-zoomberkascahayanaik'],
    ms: 7000,
    mood: _Mood.hope,
    decayFrom: 0.25,
    decayTo: 0.05,
    zoomFrom: 1.0,
    zoomTo: 1.18,
    panFrom: Alignment(0.0, 0.8),
    panTo: Alignment(0.0, -0.6),
  ),
  // 6. Kegelapan: kering -> krisis -> gulita, benih hitam berdenyut.
  _Scene(
    text:
    'Tetapi kabut tidak pernah pergi sendirian.\nIa membisiki satu orang dari desa itu\ndan menitipkan sebutir benih hitam di dadanya.',
    frames: ['desajembatan-kering', 'lembah-hijau5', 'desajembatan-keringgulita'],
    ms: 10000,
    mood: _Mood.dark,
    decayFrom: 0.8,
    decayTo: 1.0,
    zoomFrom: 1.0,
    zoomTo: 1.2,
    panFrom: Alignment(-0.2, 0.2),
    panTo: Alignment(0.2, 0.0),
  ),
];

List<double> _sat(double s) {
  final inv = 1 - s;
  final r = 0.2126 * inv, g = 0.7152 * inv, b = 0.0722 * inv;
  return [
    r + s, g, b, 0, 0,
    r, g + s, b, 0, 0,
    r, g, b + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

class PrologueFlow extends StatefulWidget {
  final String gameId;
  final LobbyRepository repo;

  /// true = masuk kembali saat gerbang prolog masih tertutup (mis. aplikasi
  /// dibuka ulang): lewati cerita, langsung ke pilihan kartu (bila belum
  /// memilih) atau pengungkapan peran.
  final bool resume;
  const PrologueFlow({
    super.key,
    required this.gameId,
    required this.repo,
    this.resume = false,
  });

  @override
  State<PrologueFlow> createState() => _PrologueFlowState();
}

/// story    : cerita sinematik
/// shuffling: animasi kocok singkat
/// pick     : pilih 1 dari 3 kartu karakter terbalik (semua pemain)
/// role     : pengungkapan peran (tahan kartu); Si Terbisik: peringatan awan
///            gelap + pilih wajah gelap disisipkan lewat [RoleReveal.twistGate]
/// waiting  : menunggu semua pemain selesai
enum _Step { story, shuffling, pick, role, waiting }

class _PrologueFlowState extends State<PrologueFlow>
    with TickerProviderStateMixin {
  _Step step = _Step.story;
  int line = 0;
  int? _prev; // adegan sebelumnya, untuk memudar silang
  String? role;
  int darkSeed = 0;
  String myCard = 'default';

  // Pilih kartu karakter (semua) dan wajah gelap (Si Terbisik).
  // true = tidak perlu memilih (sudah memilih, atau migrasi belum jalan).
  bool _charChosen = true;
  bool _darkChosen = true;
  List<String> _goodOptions = [];
  List<int> _darkOptions = [];
  int _pickEpoch = 0; // naik tiap pilihan dikocok ulang (kunci widget)
  String? _pickNote; // pesan galat dari percobaan sebelumnya
  bool _omen = false; // peringatan awan gelap sedang tampil
  bool _darkPick = false; // pilihan wajah gelap sedang tampil
  Completer<void>? _darkGate;

  // Gerbang prolog.
  StreamSubscription<Map<String, dynamic>?>? _gameSub;
  Timer? _waitTimer;
  bool _opened = false;
  final _gr = GameRepository();
  Timer? _beat;

  // Lewati cerita bersama: baru jalan bila SEMUA pemain setuju.
  StreamSubscription<Map<String, dynamic>?>? _storySub;
  bool _iSkipped = false;
  int _skipCount = 0;
  int _total = 0;

  // Penggerak prolog: kemajuan adegan, silang-pudar antar adegan, dan jam
  // berkelanjutan untuk partikel.
  late final AnimationController _sc = AnimationController(
      vsync: this, duration: Duration(milliseconds: _prologue[0].ms));
  late final AnimationController _xf = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));
  late final AnimationController _loop = AnimationController(
      vsync: this, duration: const Duration(seconds: 120))
    ..repeat();
  bool _seedFired = false;
  bool _precached = false;

  // Penutup cerita: adegan terakhir ditahan sampai narasi benar-benar habis,
  // lalu layar memudar ke gelap sebelum kocok kartu.
  bool _closing = false;
  late final AnimationController _outro = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

  /// Shader atmosfer prolog; null = pakai painter lama (kabut/cahaya/bulir).
  ui.FragmentShader? _fx;

  // Controller untuk animasi putar/kocok kartu
  late final AnimationController _shuffleCtrl;
  List<String> randomStems = [];
  int shuffleIndex = 0;
  Timer? _shuffleTimer;

  @override
  void initState() {
    super.initState();
    _fx = FxShaders.make(FxShaders.prologue);
    Sfx.I.music(Snd.bgmProlog, owner: this);
    if (widget.resume) step = _Step.role;
    randomStems = protagonistStems();
    _shuffleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    widget.repo.mySecret(widget.gameId).then((s) {
      if (!mounted || s == null) return;
      setState(() {
        role = s['role'] as String?;
        darkSeed = (s['dark_seed'] as int?) ?? 0;
        // false persis = belum memilih; null = migrasi belum jalan (lewati).
        _charChosen = s['char_chosen'] != false;
        _darkChosen = s['dark_chosen'] != false || role != 'antagonis';
      });
      if (widget.resume && !_charChosen && step == _Step.role) _enterPick();
    });
    widget.repo.players(widget.gameId).first.then((rows) {
      final me = rows.where((p) => p['user_id'] == widget.repo.myId);
      if (mounted && me.isNotEmpty) {
        setState(() {
          myCard = me.first['character_card'] as String;
          _total = rows.length;
        });
      }
    });

    _sc.addListener(_onSceneTick);
    _sc.addStatusListener((s) {
      if (s == AnimationStatus.completed) _advance();
    });
    if (!widget.resume) {
      // Narasi dimulai lebih dulu; adegan baru berjalan begitu suaranya
      // benar-benar terdengar, supaya gambar dan kalimat sejajar dengan suara.
      _beginStory();
      // Suara lewati dari semua pemain; bila lengkap, semua pindah bersamaan.
      _storySub = widget.repo.game(widget.gameId).listen((g) {
        if (g == null || !mounted) return;
        final n = (g['story_skips'] as int?) ?? 0;
        if (n != _skipCount) setState(() => _skipCount = n);
        if (g['story_skipped'] == true && !_closing) _toShuffling();
      });
    }

    _gr.tick(widget.gameId).catchError((_) {});
    _beat = Timer.periodic(const Duration(seconds: 8), (_) {
      _gr.tick(widget.gameId).catchError((_) {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    // Muat semua gambar adegan lebih dulu supaya tidak ada kedipan.
    final stems = <String>{for (final s in _prologue) ...s.frames};
    for (final stem in stems) {
      final p = sceneryPath(stem);
      if (p != null) {
        precacheImage(ResizeImage(AssetImage(p), width: 1280), context)
            .catchError((_) {});
      }
    }
  }

  void _startScene() {
    _seedFired = false;
    _sc.duration = Duration(milliseconds: _prologue[line].ms);
    _sc.forward(from: 0);
    _xf.forward(from: 0);
  }

  void _onSceneTick() {
    // Benih hitam muncul di adegan terakhir: getar dua kali.
    if (line == _prologue.length - 1 && !_seedFired && _sc.value >= 0.55) {
      _seedFired = true;
      HapticFeedback.heavyImpact();
      Future.delayed(
          const Duration(milliseconds: 150), HapticFeedback.heavyImpact);
    }
  }

  /// Lanjut ke adegan berikutnya. Hanya dipanggil saat adegan berakhir
  /// sendiri (tidak ada lagi ketukan layar untuk melompat).
  void _advance() {
    if (!mounted || step != _Step.story) return;
    if (line < _prologue.length - 1) {
      setState(() {
        _prev = line;
        line++;
      });
      _startScene();
    } else {
      // Cerita tuntas di sini: dihitung "sudah lewat" supaya tidak menahan
      // pemain yang menekan Lewati.
      widget.repo.storySkip(widget.gameId, true).catchError((_) {});
      _finishStory();
    }
  }

  /// Memutar narasi dari awal (musik latar otomatis meredup), lalu memulai
  /// adegan pertama. Bila suara lambat dimuat (>3 dtk) adegan jalan juga;
  /// penutup cerita tetap menunggu narasi, jadi suara tidak pernah terpotong.
  Future<void> _beginStory() async {
    try {
      await Sfx.I
          .narrate(Snd.narasiProlog, owner: this)
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
    if (!mounted || step != _Step.story) return;
    _startScene();
  }

  /// Adegan terakhir selesai: TAHAN sampai suara narator habis, beri jeda
  /// hening sesaat, memudar ke gelap, baru lanjut. Bila suara dibisukan atau
  /// tak pernah berbunyi, tidak ada yang ditunggu. Batas aman 10 dtk.
  Future<void> _finishStory() async {
    if (_closing || step != _Step.story) return;
    setState(() => _closing = true);
    try {
      await Sfx.I.narrationDone.timeout(const Duration(seconds: 10));
    } catch (_) {}
    if (!mounted || step != _Step.story) return;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted || step != _Step.story) return;
    await _outro.forward(from: 0);
    if (!mounted || step != _Step.story) return;
    _toShuffling();
  }

  /// Tombol Lewati: hanya memberi (atau menarik) suara; layar tetap di cerita
  /// sampai semua pemain setuju.
  void _toggleSkip() {
    if (step != _Step.story) return;
    final want = !_iSkipped;
    setState(() => _iSkipped = want);
    widget.repo.storySkip(widget.gameId, want).catchError((_) {
      if (mounted) setState(() => _iSkipped = !want); // gagal: kembalikan
    });
  }

  void _toShuffling() {
    if (step != _Step.story) return;
    _storySub?.cancel();
    _sc.stop();
    // Sepakat melewati: suara dipelankan sampai senyap, bukan dipotong.
    // (Pada akhir alami narasi sudah habis, jadi ini tidak berbuat apa-apa.)
    unawaited(Sfx.I.fadeOutNarration());
    if (!mounted) return;
    setState(() => step = _Step.shuffling);
    HapticFeedback.heavyImpact();

    // Efek kocok kartu berputar cepat sebelum masuk ke pilihan kartu
    _shuffleTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted && randomStems.isNotEmpty) {
        setState(() {
          shuffleIndex = Random().nextInt(randomStems.length);
        });
      }
    });

    _shuffleCtrl.forward().whenComplete(() {
      _shuffleTimer?.cancel();
      _afterShuffle();
    });
  }

  // ====================== pilih kartu karakter ======================

  void _afterShuffle() {
    if (!mounted) return;
    if (!_charChosen) {
      _enterPick();
    } else {
      setState(() => step = _Step.role);
    }
  }

  /// Tiga kartu baik acak dengan judul berbeda satu sama lain.
  List<String> _rollGood() {
    final pool = protagonistStems()
        .where((s) => s != 'default')
        .toList()
      ..shuffle(Random());
    final seen = <String>{};
    final out = <String>[];
    for (final s in pool) {
      if (seen.add(characterTitle(s))) {
        out.add(s);
        if (out.length == 3) break;
      }
    }
    return out;
  }

  void _enterPick() {
    if (!mounted) return;
    _goodOptions = _rollGood();
    if (_goodOptions.length < 2) {
      // Tak cukup gambar untuk dipilih: pakai kartu yang sudah ada.
      _charChosen = true;
      setState(() => step = _Step.role);
      return;
    }
    setState(() => step = _Step.pick);
  }

  /// null = berhasil; selain itu pesan galat. Bila gagal, pilihan dikocok
  /// ulang (mis. kartunya baru saja diambil pemain lain).
  Future<String?> _pickGood(int i) async {
    final stem = _goodOptions[i];
    try {
      await widget.repo.chooseCharacter(widget.gameId, stem);
      myCard = stem;
      _charChosen = true;
      return null;
    } catch (e) {
      final msg = errMsg(e);
      if (mounted) {
        setState(() {
          _goodOptions = _rollGood();
          _pickEpoch++;
          _pickNote = msg;
        });
      }
      return msg;
    }
  }

  void _goodDone() {
    if (mounted) setState(() => step = _Step.role);
  }

  /// "Lanjut tanpa memilih": pakai kartu yang dibagikan server.
  void _skipPick() {
    _charChosen = true;
    _goodDone();
  }

  // ====================== pilih wajah gelap ======================

  /// Tiga indeks gambar antagonis acak.
  List<int> _rollDark() {
    final n = AssetCatalog.I.stems(antagonisDir).length;
    final idx = List<int>.generate(n, (i) => i)..shuffle(Random());
    return idx.take(3).toList();
  }

  /// Dipanggil [RoleReveal] setelah kartu baik Si Terbisik terbuka: putar
  /// peringatan awan gelap, lalu pilihan wajah gelap. Selesai bila sudah
  /// memilih (atau tak ada yang perlu dipilih).
  Future<void> _antagGate() async {
    if (_darkChosen || !mounted) return;
    _darkOptions = _rollDark();
    if (_darkOptions.length < 2) {
      _darkChosen = true;
      return;
    }
    final c = Completer<void>();
    _darkGate = c;
    setState(() => _omen = true);
    await c.future;
  }

  void _omenContinue() {
    if (!mounted) return;
    setState(() {
      _omen = false;
      _darkPick = true;
    });
  }

  Future<String?> _pickDark(int i) async {
    try {
      await widget.repo.chooseDark(widget.gameId, _darkOptions[i]);
      darkSeed = _darkOptions[i];
      _darkChosen = true;
      return null;
    } catch (e) {
      return errMsg(e);
    }
  }

  void _darkPicked() {
    if (mounted) setState(() => _darkPick = false);
    _darkGate?.complete();
    _darkGate = null;
  }

  void _skipDark() {
    _darkChosen = true;
    _darkPicked();
  }

  // ====================== gerbang prolog ======================

  /// Tombol lanjut di akhir pengungkapan peran: semua pemain menunggu di
  /// gerbang yang sama, jadi tak ada yang bisa menebak siapa yang sedang
  /// memilih.
  void _afterReveal() {
    if (role == null || step != _Step.role) return;
    _enterWaiting();
  }

  /// Menunggu semua pemain selesai prolog; meja dibuka bersamaan.
  void _enterWaiting() {
    if (!mounted) return;
    setState(() => step = _Step.waiting);
    void report() => widget.repo.finishPrologue(widget.gameId).catchError((_) {});
    report();
    _waitTimer?.cancel();
    _waitTimer = Timer.periodic(const Duration(seconds: 5), (_) => report());
    _gameSub?.cancel();
    _gameSub = widget.repo.game(widget.gameId).listen((g) {
      if (g != null && g['prologue_until'] == null) _openTable();
    });
  }

  void _openTable() {
    if (_opened || !mounted || role == null) return;
    _opened = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TablePage(gameId: widget.gameId, role: role!),
      ),
    );
  }

  @override
  void dispose() {
    _beat?.cancel();
    _waitTimer?.cancel();
    _gameSub?.cancel();
    _storySub?.cancel();
    Sfx.I.release(this); // juga menghentikan narasi milik halaman ini
    _fx?.dispose();
    _outro.dispose();
    _sc.dispose();
    _xf.dispose();
    _loop.dispose();
    _shuffleCtrl.dispose();
    _shuffleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (step == _Step.story) {
      return Scaffold(
        backgroundColor: const Color(0xFF050A08),
        body: _story(),
      );
    }
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Backdrop(path: sceneryPath('desajembatan-keringgulita'), dim: 0.5),
          if (step == _Step.shuffling)
            SafeArea(child: _shufflingStep())
          else if (step == _Step.pick)
            SafeArea(
              child: CardPick(
                key: ValueKey('pick$_pickEpoch'),
                title: 'Pilih Kartu Karaktermu',
                hint: 'Tiga kartu terbalik. Ketuk satu; wajahnya baru '
                    'terlihat setelah kamu memilih.',
                options: [
                  for (final s in _goodOptions)
                    PickOption(protagonistPath(s), characterTitle(s)),
                ],
                note: _pickNote,
                onPick: _pickGood,
                onDone: _goodDone,
                onSkip: _skipPick,
              ),
            )
          else if (step == _Step.waiting)
              const EmbunLoading(text: 'Menunggu pemain lain...')
            else
              RoleReveal(
                role: role,
                cardPath: _roleCardPath(),
                // Kartu baik samaran: dibuka lebih dulu oleh Si Terbisik
                // sebelum kartu gelapnya terungkap.
                disguisePath: protagonistPath(myCard),
                disguiseName: characterTitle(myCard),
                twistGate: _antagGate,
                onContinue: role == null ? () {} : _afterReveal,
              ),
          // Hanya Si Terbisik: peringatan lalu pilihan wajah gelap.
          if (_omen)
            Positioned.fill(child: DarkOmen(onContinue: _omenContinue)),
          if (_darkPick) Positioned.fill(child: _darkPickLayer()),
        ],
      ),
    );
  }

  Widget _darkPickLayer() {
    final stems = AssetCatalog.I.stems(antagonisDir);
    return Stack(
      fit: StackFit.expand,
      children: [
        Backdrop(path: nightSkyPath(attack: true), dark: true, dim: 0.55),
        SafeArea(
          child: CardPick(
            key: const ValueKey('darkpick'),
            dark: true,
            title: 'Pilih Wajah Gelapmu',
            hint: 'Tiga wajah terbalik. Ketuk satu; ini wajah aslimu yang '
                'hanya kamu yang melihat.',
            options: [
              for (final i in _darkOptions)
                PickOption(AssetCatalog.I.file(antagonisDir, stems[i]),
                    'Wajah gelap'),
            ],
            onPick: _pickDark,
            onDone: _darkPicked,
            onSkip: _skipDark,
          ),
        ),
      ],
    );
  }

  // ====================== PROLOG SINEMATIK ======================

  Widget _img(String stem) =>
      GameImage(path: sceneryPath(stem), cacheWidth: 1280);

  /// Gambar satu adegan pada kemajuan [p]: gambar-gambar saling memudar,
  /// kamera bergerak pelan, warna memudar menurut tingkat kekeringan.
  Widget _sceneImage(int i, double p) {
    final s = _prologue[i];
    final n = s.frames.length;
    final layers = <Widget>[];
    if (n == 1) {
      layers.add(_img(s.frames[0]));
    } else {
      final q = p * (n - 1);
      final k = min(q.floor(), n - 2);
      final f = _smooth(_seg(q - k, 0.2, 0.8));
      layers.add(_img(s.frames[k]));
      if (f > 0) {
        layers.add(Opacity(opacity: f, child: _img(s.frames[k + 1])));
      }
    }

    final e = Curves.easeInOut.transform(p);
    final scale = s.zoomFrom + (s.zoomTo - s.zoomFrom) * e;
    final al = Alignment.lerp(s.panFrom, s.panTo, e)!;
    final d = s.decayFrom + (s.decayTo - s.decayFrom) * p;

    final Color tint = switch (s.mood) {
      _Mood.lush => const Color(0xFFFFE08A).withValues(alpha: 0.06),
      _Mood.fading => const Color(0xFF8A7A5A).withValues(alpha: 0.10),
      _Mood.barren => const Color(0xFF6A7A8A).withValues(alpha: 0.12),
      _Mood.hope => const Color(0xFFFFC857).withValues(alpha: 0.14),
      _Mood.dark => const Color(0xFF2A1745).withValues(alpha: 0.18 + 0.2 * d),
    };

    return ClipRect(
      child: Transform.scale(
        scale: scale,
        alignment: al,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColorFiltered(
              colorFilter: ColorFilter.matrix(_sat(1 - 0.45 * d)),
              child: Stack(fit: StackFit.expand, children: layers),
            ),
            IgnorePointer(child: ColoredBox(color: tint)),
          ],
        ),
      ),
    );
  }

  Widget _ornament(double t) => Opacity(
    opacity: t,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56 * t,
          height: 1.5,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              EmbunColors.gold.withValues(alpha: 0),
              EmbunColors.gold.withValues(alpha: 0.9),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        Transform.rotate(
          angle: pi / 4,
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: EmbunColors.gold,
              boxShadow: [
                BoxShadow(
                    color: EmbunColors.gold.withValues(alpha: 0.7),
                    blurRadius: 8),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 56 * t,
          height: 1.5,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              EmbunColors.gold.withValues(alpha: 0.9),
              EmbunColors.gold.withValues(alpha: 0),
            ]),
          ),
        ),
      ],
    ),
  );

  /// Teks adegan: tiap baris muncul bergantian (naik pelan, jarak huruf
  /// merapat), lalu seluruhnya memudar di akhir adegan.
  Widget _storyText(_Scene s, double ms) {
    final lines = s.text.split('\n');
    final out = 1 - _smooth(_seg(ms, s.ms - 900.0, s.ms.toDouble()));
    final ornT = _smooth(_seg(ms, 300, 1300));
    return Opacity(
      opacity: out.clamp(0.0, 1.0).toDouble(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ornament(ornT),
            const SizedBox(height: 12),
            for (var i = 0; i < lines.length; i++)
              Builder(builder: (_) {
                final delay = 700.0 + i * 1250;
                final lt = _smooth(_seg(ms, delay, delay + 1300));
                return Opacity(
                  opacity: lt,
                  child: Transform.translate(
                    offset: Offset(0, (1 - lt) * 14),
                    child: Text(
                      lines[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 21,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.6 - 1.0 * lt,
                        color: EmbunColors.cream,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 14),
                          Shadow(color: Colors.black, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 12),
            _ornament(ornT),
          ],
        ),
      ),
    );
  }

  Widget _progressBar(double p) => Row(
    children: [
      for (var i = 0; i < _prologue.length; i++)
        Expanded(
          child: Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: i < line ? 1.0 : (i == line ? p : 0.0),
              child: const DecoratedBox(
                decoration: BoxDecoration(color: EmbunColors.gold),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _story() {
    return LayoutBuilder(builder: (context, box) {
      final h = box.maxHeight;
      return AnimatedBuilder(
        animation: Listenable.merge([_sc, _xf, _loop, _outro]),
        builder: (context, _) {
          final s = _prologue[line];
          final p = _sc.value;
          final x = Curves.easeInOut.transform(_xf.value);
          final ms = p * s.ms;
          final time = _loop.value * 120;
          final d = s.decayFrom + (s.decayTo - s.decayFrom) * p;
          final open = line == 0 ? x : 1.0;
          final barH = min(h * 0.065, 44.0) * Curves.easeOut.transform(open);
          final vignette = 0.42 + 0.25 * d;

          // Atmosfer shader: tampilan tiap adegan dicampur dengan adegan
          // sebelumnya selama silang-pudar, supaya warna kabut tak melompat.
          var look = _FxLook.of(s.mood, d, p);
          if (_prev != null && x < 1) {
            final ps = _prologue[_prev!];
            look = _FxLook.lerp(_FxLook.of(ps.mood, ps.decayTo, 1.0), look, x);
          }
          final seedOn = s.mood == _Mood.dark;
          final seedBeat = pow(max(0.0, sin(time * 2.6)), 6).toDouble();
          final pulse = seedOn ? _seg(p, 0.52, 0.72) * seedBeat : 0.0;
          final shockT = seedOn ? _seg(p, 0.52, 0.80) : 0.0;
          final shock = (shockT > 0 && shockT < 1) ? shockT : -1.0;
          final fx = _fx;

          return Stack(
            fit: StackFit.expand,
            children: [
              if (_prev != null && x < 1) _sceneImage(_prev!, 1.0),
              Opacity(opacity: x, child: _sceneImage(line, p)),
              // atmosfer shader: kabut volumetrik, berkas cahaya, bulir, benih
              if (fx != null)
                IgnorePointer(
                  child: CustomPaint(
                    painter: _FogPainter(
                      shader: fx,
                      look: look,
                      time: time,
                      p: p,
                      intro: line == 0 ? x : 1.0,
                      shock: shock,
                      pulse: pulse,
                    ),
                    size: Size.infinite,
                  ),
                ),
              // daun, debu, benih (dan kabut/cahaya/bulir bila tanpa shader)
              IgnorePointer(
                child: CustomPaint(
                  painter: _FxPainter(
                    mood: s.mood,
                    time: time,
                    p: p,
                    decay: d,
                    intro: x,
                    shaderOn: fx != null,
                  ),
                ),
              ),
              // vinyet
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 1.0,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: vignette),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
              ),
              // bayangan bawah agar teks terbaca
              IgnorePointer(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: 0.55,
                    widthFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // bilah sinema
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                    height: barH,
                    width: double.infinity,
                    child: const ColoredBox(color: Colors.black)),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                    height: barH,
                    width: double.infinity,
                    child: const ColoredBox(color: Colors.black)),
              ),
              // teks
              Positioned(
                left: 24,
                right: 24,
                bottom: barH + 62,
                child: Center(child: _storyText(s, ms)),
              ),
              // bilah kemajuan + lewati
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: _progressBar(p),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Tak ada lagi yang dilewati saat penutup berjalan.
                        AnimatedOpacity(
                          opacity: _closing ? 0 : 1,
                          duration: const Duration(milliseconds: 400),
                          child: IgnorePointer(
                            ignoring: _closing,
                            child: MedallionButton(
                              icon: 'skip2',
                              label: _iSkipped ? 'Batal' : 'Lewati',
                              size: 40,
                              selected: _iSkipped,
                              badge:
                              _total > 0 ? '$_skipCount/$_total' : null,
                              onTap: _toggleSkip,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // memudar ke gelap setelah narasi habis
              sceneVeil(Curves.easeInOut.transform(_outro.value)),
            ],
          );
        },
      );
    });
  }

  // ====================== kocok kartu & peran ======================

  Widget _shufflingStep() {
    final displayCard = randomStems.isNotEmpty
        ? protagonistPath(randomStems[shuffleIndex])
        : null;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Mengocok nasib dan peran di desa...',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: EmbunColors.gold)),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _shuffleCtrl,
            builder: (_, child) {
              return Transform.rotate(
                angle: _shuffleCtrl.value * 20 * pi,
                child: Transform.scale(
                  scale: 1.0 + 0.3 * sin(_shuffleCtrl.value * pi),
                  child: CardArt(path: displayCard, width: 140),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Muka kartu pemain: kartu gelap untuk Si Terbisik, kartu karakter untuk
  /// warga. Null selama peran belum dimuat.
  String? _roleCardPath() {
    if (role == null) return null;
    return role == 'antagonis' ? darkCardPath(darkSeed) : protagonistPath(myCard);
  }
}

/// Efek atmosfer prolog menurut suasana adegan:
/// * lush    kunang-kunang emas, berkas cahaya, kabut lembah tipis
/// * fading  daun berguguran (hijau -> cokelat), kabut menebal
/// * barren  daun kering dan debu tertiup angin, kabut kelabu
/// * hope    butiran cahaya hangat naik, berkas cahaya dari atas
/// * dark    kabut ungu, bara ungu, dan benih hitam yang berdenyut
class _FxPainter extends CustomPainter {
  final _Mood mood;
  final double time; // detik
  final double p; // kemajuan adegan 0..1
  final double decay; // 0 subur .. 1 mati
  final double intro; // 0..1 saat adegan baru masuk
  final bool shaderOn; // true = kabut, cahaya, bulir digambar oleh shader
  _FxPainter({
    required this.mood,
    required this.time,
    required this.p,
    required this.decay,
    required this.intro,
    this.shaderOn = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (intro <= 0.01) return;
    if (!shaderOn) {
      _fog(canvas, size);
      if (mood == _Mood.lush || mood == _Mood.hope) _rays(canvas, size);
      if (mood == _Mood.lush || mood == _Mood.hope || mood == _Mood.dark) {
        _motes(canvas, size);
      }
    }
    if (mood == _Mood.fading || mood == _Mood.barren) _leaves(canvas, size);
    if (mood == _Mood.barren) _dust(canvas, size);
    if (mood == _Mood.dark) _seed(canvas, size);
  }

  void _fog(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final (Color col, double a) = switch (mood) {
      _Mood.lush => (const Color(0xFFDFF3E6), 0.05),
      _Mood.hope => (const Color(0xFFFFE9B0), 0.05),
      _Mood.fading => (const Color(0xFFD8D4C8), 0.07 + 0.08 * decay),
      _Mood.barren => (const Color(0xFFC9C3B6), 0.11),
      _Mood.dark => (const Color(0xFFB07CE8), 0.12 + 0.08 * p),
    };
    final paint = Paint()
      ..color = col.withValues(alpha: (a * intro).clamp(0.0, 1.0).toDouble())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    for (var i = 0; i < 5; i++) {
      final dir = i.isEven ? 1.0 : -1.0;
      final x = (i * 0.27 + time * 0.012 * dir) % 1.3 - 0.15;
      canvas.drawCircle(
          Offset(w * x, h * (0.55 + 0.09 * i)), max(w, h) * 0.2, paint);
    }
  }

  void _rays(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final strength = mood == _Mood.hope ? 0.12 : 0.07;
    final origin = Offset(w * (mood == _Mood.hope ? 0.5 : 0.15), -h * 0.1);
    final len = max(w, h) * 1.4;
    for (var i = 0; i < 6; i++) {
      final ang = pi / 2 - 0.55 + i * 0.22 + sin(time * 0.2 + i) * 0.03;
      final half = 0.04 + 0.02 * (i % 3);
      final dir = Offset(cos(ang), sin(ang));
      final path = Path()
        ..moveTo(origin.dx, origin.dy)
        ..lineTo(origin.dx + cos(ang - half) * len,
            origin.dy + sin(ang - half) * len)
        ..lineTo(origin.dx + cos(ang + half) * len,
            origin.dy + sin(ang + half) * len)
        ..close();
      final a = strength * intro * (0.7 + 0.3 * sin(time * 0.6 + i * 1.3));
      canvas.drawPath(
        path,
        Paint()
          ..blendMode = BlendMode.plus
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14)
          ..shader = ui.Gradient.linear(
            origin,
            origin + dir * len,
            [
              const Color(0xFFFFF1C0).withValues(alpha: a.clamp(0.0, 1.0)),
              const Color(0xFFFFF1C0).withValues(alpha: 0),
            ],
          ),
      );
    }
  }

  void _motes(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final n = switch (mood) {
      _Mood.hope => 38,
      _Mood.dark => 14,
      _ => 28,
    };
    final rnd = Random(11);
    final cols = switch (mood) {
      _Mood.dark => const [Color(0xFFB07CE8), Color(0xFF8A5CC0)],
      _Mood.hope => const [Color(0xFFFFE08A), Color(0xFFFFC857)],
      _ => const [Color(0xFFFFE08A), Color(0xFFBFF5D0)],
    };
    for (var i = 0; i < n; i++) {
      final x0 = rnd.nextDouble();
      final y0 = rnd.nextDouble();
      final base = mood == _Mood.hope ? 0.05 : 0.02;
      final sp = base + rnd.nextDouble() * 0.05;
      final sz = 1.4 + rnd.nextDouble() * (mood == _Mood.hope ? 3.6 : 2.6);
      final ph = rnd.nextDouble() * 2 * pi;
      final tw = 1.2 + rnd.nextDouble() * 2;
      final f = (y0 - time * sp) % 1.0;
      final o = Offset((x0 + sin(time * 0.35 + ph) * 0.03) * w, f * h);
      final a = (0.35 + 0.65 * (0.5 + 0.5 * sin(time * tw + ph))) *
          sin(f * pi) *
          intro;
      final col = cols[i % cols.length];
      canvas.drawCircle(o, sz * 3,
          Paint()..color = col.withValues(alpha: (0.16 * a).clamp(0.0, 1.0)));
      canvas.drawCircle(
          o,
          sz,
          Paint()
            ..color = Color.lerp(col, Colors.white, 0.5)!
                .withValues(alpha: (0.9 * a).clamp(0.0, 1.0)));
    }
  }

  void _leaves(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final fading = mood == _Mood.fading;
    final n = fading ? 18 : 12;
    final rnd = Random(23);
    for (var i = 0; i < n; i++) {
      final x0 = rnd.nextDouble();
      final ph = rnd.nextDouble();
      final sp = (fading ? 0.05 : 0.09) + rnd.nextDouble() * 0.06;
      final sz = 5 + rnd.nextDouble() * 7;
      final f = (time * sp + ph) % 1.0;
      final x = ((x0 + f * 0.4 + sin(f * 7 + ph * 6) * 0.04) % 1.1) * w;
      final y = (-0.05 + f * 1.1) * h;
      final rot = f * 8 + ph * 6;
      final Color col = fading
          ? Color.lerp(const Color(0xFF6FBF73), const Color(0xFF9A7440),
          (decay * 1.6).clamp(0.0, 1.0))!
          : (i.isEven ? const Color(0xFF8A6A3A) : const Color(0xFFB08A4A));
      final a = (sin(f * pi) * 0.9 * intro).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      canvas.scale(1, 0.25 + 0.75 * cos(f * 10 + ph * 5).abs());
      final path = Path()
        ..moveTo(0, -sz)
        ..quadraticBezierTo(sz * 0.9, -sz * 0.2, 0, sz)
        ..quadraticBezierTo(-sz * 0.9, -sz * 0.2, 0, -sz);
      canvas.drawPath(path, Paint()..color = col.withValues(alpha: a));
      canvas.restore();
    }
  }

  void _dust(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rnd = Random(37);
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.2;
    for (var i = 0; i < 36; i++) {
      final y = rnd.nextDouble() * h;
      final x0 = rnd.nextDouble();
      final sp = 0.06 + rnd.nextDouble() * 0.08;
      final len = 10 + rnd.nextDouble() * 30;
      final x = ((x0 + time * sp) % 1.2 - 0.1) * w;
      final a = (0.10 + rnd.nextDouble() * 0.14) * intro;
      paint.color = const Color(0xFFE0C89A).withValues(alpha: a);
      canvas.drawLine(Offset(x, y), Offset(x + len, y + len * 0.12), paint);
    }
  }

  void _seed(Canvas canvas, Size size) {
    final t = _seg(p, 0.52, 0.72);
    if (t <= 0) return;
    const violet = Color(0xFFB07CE8);
    final c = Offset(size.width / 2, size.height * 0.36);
    final r = min(size.width, size.height) * 0.032;
    final beat = pow(max(0.0, sin(time * 2.6)), 6).toDouble();

    final glowR = r * (5 + 3 * beat);
    canvas.drawCircle(
      c,
      glowR,
      Paint()
        ..shader = RadialGradient(colors: [
          violet.withValues(alpha: 0.55 * t * (0.6 + 0.4 * beat)),
          violet.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: c, radius: glowR)),
    );

    for (var k = 0; k < 3; k++) {
      final ph = (time * 0.8 + k / 3) % 1.0;
      canvas.drawCircle(
        c,
        r * 1.5 + r * 16 * ph,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = violet.withValues(alpha: (1 - ph) * 0.45 * t),
      );
    }

    final body = r * (0.6 + 0.4 * Curves.easeOutBack.transform(t)) *
        (1 + 0.12 * beat);
    canvas.drawCircle(
      c,
      body,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.3),
          colors: [Color(0xFF3A2358), Color(0xFF07040F)],
        ).createShader(Rect.fromCircle(center: c, radius: body)),
    );
    canvas.drawCircle(
      c,
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = violet.withValues(alpha: 0.9 * t),
    );
  }

  @override
  bool shouldRepaint(covariant _FxPainter old) => true;
}

/// Parameter tampilan atmosfer shader untuk satu suasana.
class _FxLook {
  final double fog, rays, motes, lightX, dark;
  final Color fogCol, lightCol;
  const _FxLook({
    required this.fog,
    required this.rays,
    required this.motes,
    required this.lightX,
    required this.dark,
    required this.fogCol,
    required this.lightCol,
  });

  static _FxLook of(_Mood m, double decay, double p) => switch (m) {
    _Mood.lush => const _FxLook(
        fog: 0.30, rays: 0.55, motes: 0.8, lightX: 0.15, dark: 0.0,
        fogCol: Color(0xFFDFF3E6), lightCol: Color(0xFFFFE9A8)),
    _Mood.hope => const _FxLook(
        fog: 0.25, rays: 1.0, motes: 1.0, lightX: 0.5, dark: 0.0,
        fogCol: Color(0xFFFFE9B0), lightCol: Color(0xFFFFD98A)),
    _Mood.fading => _FxLook(
        fog: 0.45 + 0.30 * decay, rays: 0.15, motes: 0.2, lightX: 0.3,
        dark: 0.10 + 0.15 * decay,
        fogCol: const Color(0xFFD8D4C8), lightCol: const Color(0xFFE6D8A8)),
    _Mood.barren => const _FxLook(
        fog: 0.55, rays: 0.0, motes: 0.0, lightX: 0.3, dark: 0.30,
        fogCol: Color(0xFFC9C3B6), lightCol: Color(0xFFD8C79A)),
    _Mood.dark => _FxLook(
        fog: 0.60 + 0.30 * p, rays: 0.0, motes: 0.5, lightX: 0.5,
        dark: 0.35 + 0.50 * p,
        fogCol: const Color(0xFFB07CE8), lightCol: const Color(0xFFB07CE8)),
  };

  static _FxLook lerp(_FxLook a, _FxLook b, double t) {
    double l(double x, double y) => x + (y - x) * t;
    return _FxLook(
      fog: l(a.fog, b.fog),
      rays: l(a.rays, b.rays),
      motes: l(a.motes, b.motes),
      lightX: l(a.lightX, b.lightX),
      dark: l(a.dark, b.dark),
      fogCol: Color.lerp(a.fogCol, b.fogCol, t)!,
      lightCol: Color.lerp(a.lightCol, b.lightCol, t)!,
    );
  }
}

/// Menggambar shaders/prologue_fx.frag. Urutan setFloat HARUS sama dengan
/// deklarasi uniform di berkas shader itu.
class _FogPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final _FxLook look;
  final double time, p, intro, shock, pulse;
  const _FogPainter({
    required this.shader,
    required this.look,
    required this.time,
    required this.p,
    required this.intro,
    required this.shock,
    required this.pulse,
  });

  void _rgb(int i, Color c) {
    shader
      ..setFloat(i, c.r)
      ..setFloat(i + 1, c.g)
      ..setFloat(i + 2, c.b);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (intro <= 0.01 || size.isEmpty) return;
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time)
      ..setFloat(3, p)
      ..setFloat(4, look.fog)
      ..setFloat(5, look.rays)
      ..setFloat(6, look.motes)
      ..setFloat(7, look.lightX)
      ..setFloat(8, shock)
      ..setFloat(9, intro)
      ..setFloat(10, pulse)
      ..setFloat(11, look.dark);
    _rgb(12, look.fogCol);
    _rgb(15, look.lightCol);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _FogPainter old) => true;
}