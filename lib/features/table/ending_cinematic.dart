import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import '../common/sfx.dart';
import 'flip_card.dart';

double _seg(double v, double a, double b) =>
    ((v - a) / (b - a)).clamp(0.0, 1.0).toDouble();

double _smooth(double x) => x * x * (3 - 2 * x);

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Sebab permainan berakhir. Bila server mengirim `end_reason`
/// (daun_penuh | tertangkap | antag_left | daun_habis | waktu_habis) nilai itu
/// dipakai; kalau tidak, sebabnya disimpulkan dari pemenang + jumlah daun.
enum _Kind {
  bloom, // warga menang: daun penuh, Hayu mekar
  caughtBarren, // Si Terbisik tertangkap, Hayu nyaris gundul (<= 12 daun)
  caughtMid, // tertangkap, Hayu setengah pulih (13-20 daun)
  caughtHigh, // tertangkap, Hayu hampir mekar (21-29 daun)
  left, // Si Terbisik meninggalkan permainan
  withered, // Si Terbisik menang: daun habis
  dusk, // Si Terbisik menang: waktu habis, Hayu masih bertahan
}

class _Spec {
  final String label, title, tagline;
  final bool good; // gaya emas (warga) vs ungu (Si Terbisik)
  final int pulih; // menang: gambar awal N tahap lebih buruk
  final int layu; // kalah: gambar awal N tahap lebih sehat
  final bool sakura;
  final double rays, motes; // kekuatan sinar & kilau (0..1)
  final bool petals, ash, cracks;
  final double shake;
  final double mist0, mist1; // selubung kabut gelap di awal & akhir tahap pohon
  final double satFrom, satTo;
  final double flash; // alpha puncak kilatan klimaks
  final int countFrom;
  const _Spec({
    required this.label,
    required this.title,
    required this.tagline,
    required this.good,
    this.pulih = 0,
    this.layu = 0,
    this.sakura = false,
    this.rays = 0,
    this.motes = 1,
    this.petals = false,
    this.ash = false,
    this.cracks = false,
    this.shake = 0,
    this.mist0 = 0,
    this.mist1 = 0,
    this.satFrom = 1,
    this.satTo = 1,
    this.flash = 0.6,
    this.countFrom = 0,
  });
}

const _caught = 'SI TERBISIK TERTANGKAP';

_Spec _specFor(_Kind k) {
  switch (k) {
    case _Kind.bloom:
      return const _Spec(
        label: 'WARGA DESA MENANG',
        title: 'Hayu mekar kembali!',
        tagline: 'Daun-daunnya pulih sepenuhnya, dan lembah bernapas lega.',
        good: true,
        pulih: 3,
        sakura: true,
        rays: 1,
        motes: 1,
        petals: true,
        flash: 0.85,
      );
    case _Kind.caughtBarren:
      return const _Spec(
        label: _caught,
        title: 'Hayu tak sempat tumbuh, tetapi sang Terbisik telah tiada.',
        tagline: 'Dahannya masih telanjang. Kelak, tunas pertama akan datang.',
        good: true,
        pulih: 1,
        rays: 0.55,
        motes: 0.35,
        mist0: 0.45,
        satFrom: 0.55,
        satTo: 0.85,
        flash: 0.5,
      );
    case _Kind.caughtMid:
      return const _Spec(
        label: _caught,
        title: 'Bayangan itu tersingkap, dan Hayu mulai bernapas lagi.',
        tagline: 'Beberapa daun muda mulai tampak di dahannya.',
        good: true,
        pulih: 2,
        rays: 0.8,
        motes: 0.7,
        mist0: 0.4,
        satFrom: 0.6,
        flash: 0.65,
      );
    case _Kind.caughtHigh:
      return const _Spec(
        label: _caught,
        title: 'Sang Terbisik tumbang, dan Hayu nyaris pulih!',
        tagline: 'Sedikit lagi, dan ia akan mekar seutuhnya.',
        good: true,
        pulih: 3,
        rays: 1,
        motes: 0.9,
        mist0: 0.3,
        satFrom: 0.7,
        flash: 0.75,
      );
    case _Kind.left:
      return const _Spec(
        label: 'SI TERBISIK KABUR',
        title: 'Sang Terbisik lari dari desa, dan kabut pun surut.',
        tagline: 'Tanpa bisikannya, Hayu perlahan menarik napas.',
        good: true,
        pulih: 2,
        rays: 0.7,
        motes: 0.6,
        mist0: 0.4,
        satFrom: 0.6,
        flash: 0.6,
      );
    case _Kind.withered:
      return const _Spec(
        label: 'SI TERBISIK MENANG',
        title: 'Hayu layu, desa kembali redup...',
        tagline: 'Daun terakhir gugur, dan kabut menelan lembah.',
        good: false,
        layu: 5,
        ash: true,
        cracks: true,
        shake: 1,
        mist1: 0.38,
        satTo: 0.45,
        flash: 0.6,
        countFrom: 30,
      );
    case _Kind.dusk:
      return const _Spec(
        label: 'SI TERBISIK MENANG',
        title: 'Malam menutup lembah, dan sang Terbisik lolos.',
        tagline: 'Waktu habis sebelum bayangan itu tertangkap.',
        good: false,
        layu: 2,
        ash: true,
        shake: 0.25,
        mist1: 0.5,
        satTo: 0.6,
        flash: 0.35,
        countFrom: 30,
      );
  }
}

/// Sinematik penutup permainan (sebelum layar rekap).
///
/// Urutan (total 18 detik, ketuk "Lewati" kapan saja):
///   0.00  layar hitam memudar, bilah sinema masuk
///   0.07  pohon Hayu bergerak (kamera mendekat pelan) melewati rangkaian
///         gambar:
///           MENANG: pulih dari kondisi lebih buruk -> berkas sinar,
///                   kilatan emas, kelopak sakura (bila daun >= 30)
///           KALAH : layu bertahap sampai ke keadaan akhir -> layar bergetar,
///                   retakan ungu, kabut dan abu
///   0.50  klimaks (kilatan + haptic)
///   0.50  judul muncul huruf demi huruf, lalu cap menang/kalah, hitung daun
///   0.72  layar meredup: kartu Si Terbisik dibalik (pakai FlipCard suspense)
///   0.92  nama pemain + username terungkap, tombol "Lihat rekap"
///
/// Bila data rahasia gagal dimuat atau tak ada antagonis, bagian pengungkapan
/// dilewati dan sinematik berhenti di judul.
class EndingCinematic extends StatefulWidget {
  final bool wargaMenang;
  final int leaves;
  final String? verdict;
  final Future<Map<String, Map<String, dynamic>>> secrets;
  final Future<Map<String, String>> usernames;
  final List<Map<String, dynamic>> players;
  final VoidCallback onDone;

  /// Id pemain yang menonton; dipakai untuk menyatakan "kamu menang / kalah".
  final String? myId;

  /// Opsional: games.end_reason bila server menyediakannya.
  final String? endReason;

  const EndingCinematic({
    super.key,
    this.myId,
    required this.wargaMenang,
    required this.leaves,
    required this.secrets,
    required this.usernames,
    required this.players,
    required this.onDone,
    this.verdict,
    this.endReason,
  });

  @override
  State<EndingCinematic> createState() => _EndingCinematicState();
}

class _Part {
  final double x, phase, speed, size, sway;
  final int kind; // 0 = kilau/kabut, 1 = kelopak/abu
  const _Part(this.x, this.phase, this.speed, this.size, this.sway, this.kind);
}

class _EndingCinematicState extends State<EndingCinematic>
    with SingleTickerProviderStateMixin {
  static const _totalMs = 18000;
  static const _revealAt = 0.72;

  late final AnimationController _ctl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: _totalMs));

  late final _Spec _spec;
  late final List<String?> _frames;
  late final List<(double, double)> _windows;
  final List<_Part> _parts = _makeParts();
  final List<List<Offset>> _cracks = _makeCracks();

  bool _revealReady = false;

  /// Hasil untuk pemain ini; null selama peran belum termuat.
  bool? _myWon;
  List<({String name, int seed, String? card, String? username})> _antags = [];
  bool _hapClimax = false;
  bool _hapTitle = false;
  bool _done = false;

  /// Adegan pengungkapan Si Terbisik (jalan sendiri, lebih panjang dari
  /// sisa timeline utama) sudah selesai.
  bool _revealDone = false;

  bool get _win => widget.wargaMenang;

  _Kind _resolveKind() {
    final r = widget.endReason;
    final l = widget.leaves;
    _Kind tier() => l <= 12
        ? _Kind.caughtBarren
        : (l <= 20 ? _Kind.caughtMid : _Kind.caughtHigh);
    if (_win) {
      if (r == 'antag_left') return _Kind.left;
      if (r == 'daun_penuh') return _Kind.bloom;
      if (r == 'tertangkap' || r == 'panah') return tier();
      return l >= 30 ? _Kind.bloom : tier(); // tanpa data: simpulkan dari daun
    }
    if (r == 'waktu_habis') return _Kind.dusk;
    if (r == 'daun_habis') return _Kind.withered;
    return l <= 0 ? _Kind.withered : _Kind.dusk;
  }

  bool get _atEnd {
    final v = _ctl.value;
    // Ada Si Terbisik untuk diungkap: tombol akhir menunggu adegannya.
    if (_antags.isNotEmpty && v >= _revealAt) return _revealDone;
    if (v >= 0.97) return true;
    return v >= _revealAt && _revealReady && _antags.isEmpty;
  }

  @override
  void initState() {
    super.initState();
    _spec = _specFor(_resolveKind());
    _buildFrames();
    _ctl.addListener(_onTick);
    _ctl.forward();
    Sfx.I.setDuck(this, true);
    _load();
  }

  @override
  void dispose() {
    _ctl.dispose();
    Sfx.I.release(this);
    super.dispose();
  }

  // ---------- data ----------

  Future<void> _load() async {
    final found = <({String name, int seed, String? card, String? username})>[];
    bool? myWon;
    try {
      final s = await widget.secrets;
      final id = widget.myId;
      final myRole = id == null ? null : s[id]?['role'];
      if (myRole != null) myWon = (myRole == 'antagonis') != widget.wargaMenang;
      for (final e in s.entries) {
        if (e.value['role'] == 'antagonis') {
          String name = '?';
          String? card; // kartu baik samaran
          for (final p in widget.players) {
            if (p['user_id'] == e.key) {
              name = p['name'] as String;
              card = p['character_card'] as String?;
            }
          }
          String? uname;
          try {
            uname = (await widget.usernames)[e.key];
          } catch (_) {}
          found.add((
            name: name,
            seed: (e.value['dark_seed'] as int?) ?? 0,
            card: card,
            username: uname,
          ));
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _antags = found;
      _myWon = myWon;
      _revealReady = true;
    });
    // Timeline sempat menunggu data di titik pengungkapan.
    if (found.isNotEmpty && !_ctl.isAnimating && _ctl.value < 1) {
      _ctl.forward();
    }
  }

  void _buildFrames() {
    final fin = ((30 - widget.leaves.clamp(0, 30)) * 9.99 / 30).floor();
    final idx = <int>[];
    if (_win) {
      for (var i = math.min(9, fin + _spec.pulih); i >= fin; i--) {
        idx.add(i);
      }
    } else {
      for (var i = math.max(0, fin - _spec.layu); i <= fin; i++) {
        idx.add(i);
      }
    }
    final frames = <String?>[
      for (final i in idx) AssetCatalog.I.file(pohonDir, 'pohon$i'),
    ];
    final sakura = _spec.sakura && widget.leaves >= 30;
    if (sakura) frames.add(AssetCatalog.I.file(pohonDir, 'pohon0-sakura'));
    _frames = frames;

    // Jendela fade tiap gambar (indeks 0 = dasar, selalu terlihat).
    final n = frames.length;
    final main = sakura ? n - 1 : n;
    final mainEnd = sakura ? 0.46 : 0.50;
    final wins = <(double, double)>[(0, 0)];
    for (var i = 1; i < n; i++) {
      if (sakura && i == n - 1) {
        wins.add((0.46, 0.56));
      } else {
        final d = (mainEnd - 0.07) / math.max(1, main - 1);
        wins.add((0.07 + (i - 1) * d, 0.07 + i * d));
      }
    }
    _windows = wins;
  }

  void _onTick() {
    final v = _ctl.value;
    if (!_hapClimax && v >= 0.49) {
      _hapClimax = true;
      HapticFeedback.heavyImpact();
    }
    if (!_hapTitle && v >= 0.52) {
      _hapTitle = true;
      HapticFeedback.lightImpact();
    }
    if (v >= _revealAt && _ctl.isAnimating) {
      if (!_revealReady || _antags.isEmpty) {
        _ctl.stop();
        setState(() {});
      }
    }
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    return Material(
      color: EmbunColors.bg,
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        final barH = (h * 0.07).clamp(16.0, 52.0).toDouble();
        return AnimatedBuilder(
          animation: _ctl,
          builder: (context, _) => _scene(context, w, h, barH),
        );
      }),
    );
  }

  Widget _scene(BuildContext context, double w, double h, double barH) {
    final t = _ctl.value;
    final sec = t * _totalMs / 1000;
    final sp = _spec;
    final win = sp.good;
    final topPad = MediaQuery.of(context).padding.top;

    // Kamera + getar.
    final zoom = 1.05 + 0.16 * t;
    final shakeEnv =
        _smooth(_seg(t, 0.36, 0.46)) * (1 - _smooth(_seg(t, 0.50, 0.58)));
    final amp = 7 * sp.shake * shakeEnv;
    final shake = Offset(math.sin(sec * 63) * amp, math.cos(sec * 51) * amp * 0.7);

    final stage = _smooth(_seg(t, 0.07, 0.50));
    final sat = _lerp(sp.satFrom, sp.satTo, stage);
    final mist = _lerp(sp.mist0, sp.mist1, stage);

    // Selubung & efek.
    final bloom = win ? _smooth(_seg(t, 0.46, 0.60)) : 0.0;
    final flashPeak = math.pow(math.sin(math.pi * _seg(t, 0.44, 0.58)), 2)
        .toDouble();
    final moteEnv = win
        ? (_smooth(_seg(t, 0.05, 0.30)) * 0.4 + bloom * 0.6) * sp.motes
        : _smooth(_seg(t, 0.10, 0.50));
    final fallEnv = sp.petals
        ? _smooth(_seg(t, 0.50, 0.66))
        : (sp.ash ? _smooth(_seg(t, 0.25, 0.55)) * 0.85 : 0.0);
    final crackP = sp.cracks ? _smooth(_seg(t, 0.40, 0.52)) : 0.0;
    final crackFade = 1 - _smooth(_seg(t, 0.55, 0.68));

    final fadeIn = 1 - _smooth(_seg(t, 0.0, 0.05));
    final bars = _smooth(_seg(t, 0.0, 0.06));

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),

        // Pohon.
        Transform.translate(
          offset: shake,
          child: Transform.scale(
            scale: zoom,
            alignment: const Alignment(0.1, 0.2),
            child: ColorFiltered(
              colorFilter: _satFilter(sat),
              child: _treeLayer(t),
            ),
          ),
        ),

        // Warna suasana.
        IgnorePointer(
          child: win
              ? DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.6, -0.8),
                radius: 1.3,
                colors: [
                  const Color(0xFFFFE9A6).withValues(
                      alpha: (0.10 + 0.30 * bloom) * sp.rays.clamp(0.3, 1.0)),
                  Colors.transparent,
                ],
              ),
            ),
          )
              : const SizedBox.shrink(),
        ),
        // Kabut gelap: menipis saat Si Terbisik tumbang, menebal saat ia menang.
        if (mist > 0.005)
          IgnorePointer(
            child: ColoredBox(
              color: const Color(0xFF120A1E).withValues(alpha: mist),
            ),
          ),

        if (win && sp.rays > 0)
          IgnorePointer(
            child: CustomPaint(
              painter: _RaysPainter(sec: sec, a: bloom * sp.rays),
              size: Size.infinite,
            ),
          ),
        if (sp.cracks && crackP > 0 && crackFade > 0)
          IgnorePointer(
            child: CustomPaint(
              painter: _CrackPainter(
                  lines: _cracks, progress: crackP, fade: crackFade),
              size: Size.infinite,
            ),
          ),
        IgnorePointer(
          child: CustomPaint(
            painter: _FxPainter(
              sec: sec,
              win: win,
              petals: sp.petals,
              moteEnv: moteEnv,
              fallEnv: fallEnv,
              parts: _parts,
            ),
            size: Size.infinite,
          ),
        ),

        // Vinyet.
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.0,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: win ? 0.55 : 0.85),
                ],
                stops: const [0.55, 1.0],
              ),
            ),
          ),
        ),

        // Kilatan klimaks.
        if (flashPeak > 0.01)
          IgnorePointer(
            child: ColoredBox(
              color: (win ? const Color(0xFFFFF2C0) : const Color(0xFF2A1048))
                  .withValues(alpha: sp.flash * flashPeak),
            ),
          ),

        // Gradasi bawah untuk judul.
        IgnorePointer(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: 0.6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(
                          alpha: 0.8 * _smooth(_seg(t, 0.48, 0.56))),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Judul.
        Positioned(
          left: 24,
          right: 24,
          top: topPad + barH + 10,
          bottom: barH + 84,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: math.max(160.0, w - 48)),
                child: _title(t),
              ),
            ),
          ),
        ),

        // Pengungkapan Si Terbisik.
        _reveal(t, w, h),

        // Bilah sinema.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: barH * bars,
          child: const IgnorePointer(child: ColoredBox(color: Colors.black)),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: barH * bars,
          child: const IgnorePointer(child: ColoredBox(color: Colors.black)),
        ),

        // Fade dari hitam.
        if (fadeIn > 0)
          IgnorePointer(
            child: ColoredBox(
                color: Colors.black.withValues(alpha: fadeIn)),
          ),

        // Lewati.
        if (t > 0.06 && !_atEnd)
          Positioned(
            top: topPad + 6,
            right: 10,
            child: TextButton(
              onPressed: _finish,
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              child: const Text('Lewati'),
            ),
          ),

        // Tombol akhir.
        Positioned(
          left: 24,
          right: 24,
          bottom: barH + 14,
          child: IgnorePointer(
            ignoring: !_atEnd,
            child: AnimatedOpacity(
              opacity: _atEnd ? 1 : 0,
              duration: const Duration(milliseconds: 500),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_myWon != null) ...[
                        _myOutcome(small: true),
                        const SizedBox(height: 12),
                      ],
                      EmbunButton(
                        label: 'Lihat rekap',
                        icon: 'centang',
                        expand: true,
                        onPressed: _finish,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _treeLayer(double t) {
    final layers = <Widget>[];
    for (var i = 0; i < _frames.length; i++) {
      final op =
      i == 0 ? 1.0 : _smooth(_seg(t, _windows[i].$1, _windows[i].$2));
      if (op <= 0) continue;
      layers.add(Opacity(
        opacity: op,
        child: GameImage(path: _frames[i], cacheWidth: 1600),
      ));
    }
    return Stack(fit: StackFit.expand, children: layers);
  }

  /// Pernyataan hasil pribadi: "KAMU MENANG" (emas) / "KAMU KALAH" (merah).
  Widget _myOutcome({bool small = false}) {
    final won = _myWon ?? _win;
    final c = won ? EmbunColors.gold : EmbunColors.blood;
    final stamp = won ? 'menang' : 'kalah';
    final banner = won ? 'akhir-menang' : 'akhir-kalah';
    final icon = !small && ikonPath(banner) != null ? banner : stamp;
    if (ikonPath(icon) != null) {
      final w = small ? 130.0 : 206.0;
      final h = icon == banner ? w * 0.46 : w / 2.8;
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: 26),
          ],
        ),
        child: Semantics(
          image: true,
          label: won ? 'Kamu menang' : 'Kamu kalah',
          child: GameIcon(icon, width: w, height: h),
        ),
      );
    }
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 14 : 18, vertical: small ? 6 : 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c, width: 2),
        boxShadow: [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 18)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(won ? Icons.emoji_events_rounded : Icons.heart_broken_rounded,
              size: small ? 22 : 28, color: c),
          const SizedBox(width: 8),
          Text(won ? 'KAMU MENANG' : 'KAMU KALAH',
              style: TextStyle(
                  fontSize: small ? 16 : 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                  color: won ? EmbunColors.cream : Colors.white)),
        ],
      ),
    );
  }

  Widget _title(double t) {
    final sp = _spec;
    final win = sp.good;
    final appear = _seg(t, 0.50, 0.62);
    final out = _antags.isNotEmpty ? _smooth(_seg(t, 0.70, 0.76)) : 0.0;
    if (appear <= 0 || out >= 1) return const SizedBox.shrink();

    final color = win ? EmbunColors.cream : const Color(0xFFE6D8F5);
    final glow = win ? EmbunColors.gold : EmbunColors.mist;
    final label = sp.label;
    final title = sp.title;

    final countT = _smooth(_seg(t, 0.64, 0.70));
    final shown =
    _lerp(sp.countFrom.toDouble(), widget.leaves.toDouble(), countT);

    return Opacity(
      opacity: 1 - out,
      child: Transform.translate(
        offset: Offset(0, -18 * out),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_myWon != null) ...[
              Opacity(
                opacity: _smooth(_seg(t, 0.50, 0.56)),
                child: _myOutcome(),
              ),
              const SizedBox(height: 10),
            ],
            Opacity(
              opacity: _smooth(_seg(t, 0.50, 0.55)),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                  color: glow,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _StaggerText(
              text: title,
              t: appear,
              color: color,
              glow: glow,
              size: title.length > 34 ? 24 : 30,
              spacing: _lerp(10, 1.5, _smooth(appear)),
            ),
            const SizedBox(height: 8),
            Opacity(
              opacity: _smooth(_seg(t, 0.58, 0.64)),
              child: Text(
                sp.tagline,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, height: 1.3, color: Colors.white70),
              ),
            ),
            if (widget.verdict != null) ...[
              const SizedBox(height: 6),
              Opacity(
                opacity: _smooth(_seg(t, 0.62, 0.67)),
                child: Text(
                  widget.verdict!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.white54),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Opacity(
              opacity: countT,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GameIcon('helaidaun', size: 28),
                  const SizedBox(width: 6),
                  Text(
                    'Daun akhir: ${shown.round()}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: EmbunColors.gold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reveal(double t, double w, double h) {
    if (_antags.isEmpty || t < _revealAt) return const SizedBox.shrink();
    void complete() {
      if (mounted && !_revealDone) setState(() => _revealDone = true);
    }

    final a = _antags.first;
    return Positioned.fill(
      child: _antags.length == 1
          ? _AntagReveal(
              key: const ValueKey('antagReveal'),
              name: a.name,
              username: a.username,
              seed: a.seed,
              card: a.card,
              onDone: complete,
            )
          : TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1000),
              onEnd: complete,
              builder: (_, opacity, child) => Opacity(
                opacity: opacity,
                child: child,
              ),
              child: ColoredBox(
                color: const Color(0xFF150F20),
                child: SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 66),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Dua Terbisik Terungkap',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 23,
                              color: EmbunColors.mist,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final antag in _antags)
                                Flexible(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CardArt(
                                          path: darkCardPath(antag.seed),
                                          width: math.min(w * 0.27, h * 0.29),
                                          glow: EmbunColors.mist,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          antag.name,
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: EmbunColors.cream,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if (antag.username != null)
                                          Text(
                                            antag.username!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Colors.white60),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pengungkapan Si Terbisik: wajah samaran dulu, lalu wajah aslinya
// ---------------------------------------------------------------------------

double _rr(int i, int k) {
  final v = math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
  return v - v.floorToDouble();
}

/// Adegan penutup sebelum rekap. Berjalan dengan pengendali sendiri supaya
/// tidak terikat sisa timeline utama.
///
///  0.00-0.06  layar menggelap
///  0.05-0.10  "Selama ini, ia menyamar sebagai..."
///  0.09-0.28  kartu baik samarannya masuk lalu berbalik (pendar emas)
///  0.30-0.36  nama pemain + nama kartu samaran
///  0.46-0.68  PUTAR BALIK: kartu baik menggelap dan bergetar, layar
///             tersentak, kartu terbelah bayangan merah-ungu (glitch),
///             kilatan ungu, lalu berganti jadi kartu gelap; asap, cincin
///             kejut, bara ungu
///  0.50-0.62  teks berganti: "Si Terbisik ternyata..." / nama berubah warna
///             / "SI TERBISIK"
///  0.68-0.74  username asli
///  0.86       selesai (tombol "Lihat rekap" muncul)
class _AntagReveal extends StatefulWidget {
  final String name;
  final String? username;
  final int seed;
  final String? card; // kartu karakter (samaran)
  final VoidCallback onDone;

  const _AntagReveal({
    super.key,
    required this.name,
    required this.username,
    required this.seed,
    required this.card,
    required this.onDone,
  });

  @override
  State<_AntagReveal> createState() => _AntagRevealState();
}

class _AntagRevealState extends State<_AntagReveal>
    with SingleTickerProviderStateMixin {
  static const _ms = 7600;
  static const _cream = Color(0xFFFFF2C0);
  static const _lavender = Color(0xFFE6D8F5);

  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: _ms));
  final Set<int> _fired = {};
  bool _done = false;

  late final String? _darkPath = darkCardPath(widget.seed);
  late final String? _disPath =
  widget.card == null ? null : protagonistPath(widget.card!);
  bool get _hasDis => _disPath != null;

  @override
  void initState() {
    super.initState();
    _c.addListener(_tick);
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    widget.onDone();
  }

  void _tick() {
    final u = _c.value;
    if (u >= 0.20 && _fired.add(0)) HapticFeedback.lightImpact();
    if (_hasDis) {
      if (u >= 0.47 && _fired.add(1)) HapticFeedback.mediumImpact();
      if (u >= 0.50 && _fired.add(2)) HapticFeedback.mediumImpact();
      if (u >= 0.53 && _fired.add(3)) HapticFeedback.heavyImpact();
    }
    if (u >= 0.54 && _fired.add(4)) {
      HapticFeedback.heavyImpact();
      Future.delayed(
          const Duration(milliseconds: 150), HapticFeedback.heavyImpact);
      Future.delayed(
          const Duration(milliseconds: 420), HapticFeedback.mediumImpact);
    }
    if (u >= 0.86) _finish();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      return AnimatedBuilder(
        animation: _c,
        builder: (context, _) => _body(box.maxWidth, box.maxHeight),
      );
    });
  }

  Widget _body(double w, double h) {
    final u = _c.value;
    final sec = u * _ms / 1000;
    final hasDis = _hasDis;
    final tw = hasDis ? _seg(u, 0.46, 0.68) : 1.0;
    final swapped = !hasDis || tw >= 0.36;
    final mixC = hasDis ? _smooth(_seg(tw, 0.30, 0.55)) : 1.0;
    final accent = Color.lerp(EmbunColors.gold, EmbunColors.mist, mixC)!;

    final scrim = _smooth(_seg(u, 0, 0.06));
    final ch = (h * 0.40).clamp(120.0, 300.0).toDouble();
    final cw = ch / cardAspectFor(_darkPath ?? _disPath);

    // Layar tersentak saat putar balik.
    var shake = Offset.zero;
    if (hasDis && tw > 0 && tw < 0.62) {
      final q = (tw * 60).floor();
      final ramp = tw < 0.30 ? 2.5 * _seg(tw, 0, 0.30) : 0.0;
      final hit = tw >= 0.30 ? 12.0 * (1 - _seg(tw, 0.30, 0.62)) : 0.0;
      final amp = ramp + hit;
      shake = Offset((_rr(q, 13) - 0.5) * amp, (_rr(q, 14) - 0.5) * amp);
    }

    // Kartu.
    Widget card;
    if (_darkPath == null && _disPath == null) {
      card = const SizedBox.shrink();
    } else if (u < 0.09) {
      card = SizedBox(width: cw, height: ch);
    } else {
      card = FlipCard(
        key: const ValueKey('antagCard'),
        index: 0,
        width: cw,
        height: ch,
        revealed: true,
        dark: !hasDis,
        suspense: !hasDis,
        glow: Color.lerp(EmbunColors.gold, EmbunColors.mist, mixC)!,
        front: _front(cw, ch, tw, swapped, accent, sec),
      );
    }

    // Label atas.
    final lab1 = hasDis
        ? _smooth(_seg(u, 0.05, 0.10)) * (1 - _smooth(_seg(u, 0.44, 0.49)))
        : 0.0;
    final lab2 = hasDis
        ? _smooth(_seg(u, 0.50, 0.56))
        : _smooth(_seg(u, 0.05, 0.10));

    // Nama dan keterangan.
    final nameA = _smooth(_seg(u, 0.30, 0.36));
    final mixName = hasDis ? _smooth(_seg(u, 0.54, 0.62)) : 1.0;
    final ph2 = hasDis ? _smooth(_seg(u, 0.56, 0.62)) : 1.0;
    final nameColor = Color.lerp(_cream, _lavender, mixName)!;
    final glow = Color.lerp(EmbunColors.gold, EmbunColors.mist, mixName)!;
    final unameA = _smooth(_seg(u, 0.68, 0.74));
    final disTitle = widget.card == null ? null : characterTitle(widget.card!);

    // Kilatan ungu di titik tukar.
    final flashA = hasDis
        ? (_seg(tw, 0.30, 0.36) * (1 - _smooth(_seg(tw, 0.36, 0.56))) * 0.8)
        .clamp(0.0, 1.0)
        .toDouble()
        : 0.0;

    final tw2 = hasDis ? _seg(u, 0.46, 0.86) : _seg(u, 0.10, 0.50);

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Colors.black.withValues(
              alpha: 0.62 * scrim + 0.14 * _smooth(_seg(tw, 0.2, 0.5))),
        ),
        Transform.translate(
          offset: shake,
          child: Align(
            alignment: const Alignment(0, -0.15),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 22,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: lab1.clamp(0.0, 1.0).toDouble(),
                        child: const Text(
                          'Selama ini, ia menyamar sebagai...',
                          style: TextStyle(
                              fontSize: 15,
                              letterSpacing: 1.5,
                              color: Colors.white70),
                        ),
                      ),
                      Opacity(
                        opacity: lab2.clamp(0.0, 1.0).toDouble(),
                        child: const Text(
                          'Si Terbisik ternyata...',
                          style: TextStyle(
                              fontSize: 15,
                              letterSpacing: 1.5,
                              color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: cw,
                  height: ch,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: -cw * 0.8,
                        top: -ch * 0.4,
                        width: cw * 2.6,
                        height: ch * 1.8,
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _RevealFxPainter(
                              u: u,
                              tw: tw,
                              tw2: tw2,
                              sec: sec,
                              cw: cw,
                              ch: ch,
                              hasDis: hasDis,
                            ),
                          ),
                        ),
                      ),
                      card,
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Opacity(
                  opacity: nameA,
                  child: Transform.translate(
                    offset: Offset(0, 12 * (1 - nameA)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: nameColor,
                            shadows: [
                              Shadow(
                                  color: glow.withValues(alpha: 0.9),
                                  blurRadius: 18),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 26,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (hasDis && disTitle != null)
                                Opacity(
                                  opacity: (1 - ph2).clamp(0.0, 1.0).toDouble(),
                                  child: Text(
                                    'sang $disTitle',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        letterSpacing: 0.6,
                                        color: Colors.white70),
                                  ),
                                ),
                              Opacity(
                                opacity: ph2.clamp(0.0, 1.0).toDouble(),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const GameIcon('bulirhitam', size: 24),
                                    const SizedBox(width: 6),
                                    Text(
                                      'SI TERBISIK',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 3,
                                        color: EmbunColors.mist,
                                        shadows: [
                                          Shadow(
                                              color: EmbunColors.mist
                                                  .withValues(alpha: 0.8),
                                              blurRadius: 12),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.username != null)
                          Opacity(
                            opacity: unameA,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('yaitu ${widget.username}',
                                  style: const TextStyle(
                                      fontSize: 15, color: Colors.white70)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (flashA > 0.01)
          IgnorePointer(
            child: ColoredBox(
              color: Color.lerp(Colors.white, const Color(0xFFE2C8FF), 0.55)!
                  .withValues(alpha: flashA),
            ),
          ),
      ],
    );
  }

  /// Muka kartu: kartu baik samaran, menggelap dan terbelah glitch, lalu
  /// kartu gelap Si Terbisik. Dibangun ulang tiap detik animasi karena
  /// [FlipCard] mengembalikan `front` apa adanya setelah selesai berbalik.
  Widget _front(double cw, double ch, double tw, bool swapped, Color accent,
      double sec) {
    final hasDis = _hasDis;

    Widget face(String? path) => Container(
      width: cw,
      height: ch,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent, width: 2),
        boxShadow: [
          BoxShadow(
              color: accent.withValues(alpha: 0.5), blurRadius: 18),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: GameImage(path: path, cacheWidth: 600),
      ),
    );

    Widget core() {
      Widget f = face(swapped ? _darkPath : _disPath);
      if (hasDis && !swapped && tw > 0) {
        f = ColorFiltered(
          colorFilter: ColorFilter.mode(
              const Color(0xFF0A0714)
                  .withValues(alpha: 0.55 * _smooth(_seg(tw, 0, 0.34))),
              BlendMode.srcATop),
          child: f,
        );
      }
      return f;
    }

    final layers = <Widget>[];
    if (hasDis && tw > 0.26 && tw < 0.62) {
      final q = (tw * 55).floor();
      final g = _seg(tw, 0.26, 0.32) * (1 - _seg(tw, 0.42, 0.62));
      for (var k = 0; k < 2; k++) {
        layers.add(Transform.translate(
          offset: Offset((_rr(q, k + 1) - 0.5) * 30 * g,
              (_rr(q, k + 4) - 0.5) * 8 * g),
          child: Opacity(
            opacity: (0.5 * g).clamp(0.0, 1.0).toDouble(),
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                  (k == 0 ? EmbunColors.blood : EmbunColors.mist)
                      .withValues(alpha: 0.75),
                  BlendMode.srcATop),
              child: core(),
            ),
          ),
        ));
      }
    }
    final tremble = (hasDis && tw > 0)
        ? math.sin(sec * 90) *
        3 *
        _seg(tw, 0, 0.34) *
        (1 - _seg(tw, 0.34, 0.5))
        : 0.0;
    layers.add(Transform.translate(offset: Offset(tremble, 0), child: core()));
    return SizedBox(
      width: cw,
      height: ch,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: layers,
      ),
    );
  }
}

/// Pendar emas (kartu baik), aura + asap + cincin kejut + bara ungu (kartu
/// gelap). Digambar di kotak 2,6 x 1,8 kali kartu, berpusat di kartu.
class _RevealFxPainter extends CustomPainter {
  final double u, tw, tw2, sec, cw, ch;
  final bool hasDis;
  const _RevealFxPainter({
    required this.u,
    required this.tw,
    required this.tw2,
    required this.sec,
    required this.cw,
    required this.ch,
    required this.hasDis,
  });

  static const _smoke = Color(0xFF7C7391);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);

    // Pendar emas di balik kartu baik; padam ketika putar balik.
    if (hasDis) {
      final a = 0.40 *
          _smooth(_seg(u, 0.12, 0.30)) *
          (1 - _smooth(_seg(tw, 0.2, 0.5)));
      if (a > 0.01) {
        final r = ch * (0.75 + 0.08 * math.sin(sec * 2.2));
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..shader = RadialGradient(colors: [
              EmbunColors.gold.withValues(alpha: a),
              EmbunColors.gold.withValues(alpha: 0),
            ]).createShader(Rect.fromCircle(center: c, radius: r)),
        );
      }
    }

    // Aura ungu.
    final aura = _smooth(_seg(tw, 0.2, 0.6));
    if (aura > 0.01) {
      final r = ch * (0.8 + 0.25 * math.sin(math.pi * _seg(tw, 0.3, 1.0)) +
          0.05 * math.sin(sec * 2.6));
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            EmbunColors.mist.withValues(alpha: 0.55 * aura),
            EmbunColors.mist.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    if (!hasDis && tw2 <= 0) return;

    // Cincin kejut.
    if (hasDis) {
      final maxR = ch * 1.4;
      for (final s in const [0.30, 0.40, 0.50]) {
        final p = _seg(tw2, s, s + 0.30);
        if (p <= 0 || p >= 1) continue;
        final e = Curves.easeOutCubic.transform(p);
        canvas.drawCircle(
          c,
          _lerp(ch * 0.3, maxR, e),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 * (1 - p) + 1
            ..color = EmbunColors.mist.withValues(alpha: 0.8 * (1 - p)),
        );
      }
    }

    // Asap yang mengepul dari kartu.
    final paint = Paint();
    final from = hasDis ? 0.0 : 0.0;
    for (var i = 0; i < 22; i++) {
      final st = from + 0.28 + 0.22 * _rr(i, 1);
      final p = _seg(tw2, st, st + 0.5);
      if (p <= 0 || p >= 1) continue;
      final start = c +
          Offset((_rr(i, 2) - 0.5) * cw, ch * (0.1 + 0.35 * _rr(i, 3)));
      final pos = start +
          Offset(math.sin(p * 3 + i) * cw * 0.25,
              -p * ch * (0.7 + 0.8 * _rr(i, 4)));
      final r = cw * (0.18 + 0.34 * p) * (0.7 + 0.7 * _rr(i, 5));
      final a = math.sin(p * math.pi) * 0.6;
      final col = i % 3 == 0
          ? const Color(0xFF05020A)
          : (i.isEven ? EmbunColors.mist : _smoke);
      paint.shader = RadialGradient(
        colors: [col.withValues(alpha: a), col.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: pos, radius: r));
      canvas.drawCircle(pos, r, paint);
    }

    // Bara ungu yang terus naik setelah kartu gelap terbuka.
    final env = _smooth(_seg(tw, 0.5, 1.0));
    if (env > 0.01) {
      final m = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      for (var i = 0; i < 14; i++) {
        final f = (sec * 0.14 + _rr(i, 1)) % 1.0;
        final x = c.dx + (_rr(i, 2) - 0.5) * size.width * 0.9 +
            math.sin(sec * 0.8 + i) * 8;
        final y = c.dy + ch * 0.9 - f * ch * 1.9;
        final a = (env * math.sin(math.pi * f) * 0.8).clamp(0.0, 1.0).toDouble();
        m.color = EmbunColors.mist.withValues(alpha: a);
        canvas.drawCircle(Offset(x, y), 1.5 + 2.2 * _rr(i, 3), m);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RevealFxPainter old) => true;
}

// ---------------------------------------------------------------------------
// Teks huruf-demi-huruf
// ---------------------------------------------------------------------------

class _StaggerText extends StatelessWidget {
  final String text;
  final double t; // 0..1
  final Color color;
  final Color glow;
  final double size;
  final double spacing;
  const _StaggerText({
    required this.text,
    required this.t,
    required this.color,
    required this.glow,
    required this.size,
    required this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    final n = text.length;
    final spans = <InlineSpan>[];
    for (var i = 0; i < n; i++) {
      final s = i / n * 0.65;
      final a = _smooth(_seg(t, s, s + 0.35));
      spans.add(TextSpan(
        text: text[i],
        style: TextStyle(
          color: color.withValues(alpha: a),
          shadows: [
            Shadow(color: glow.withValues(alpha: a * 0.85), blurRadius: 20),
          ],
        ),
      ));
    }
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w800,
          letterSpacing: spacing,
          height: 1.15,
        ),
        children: spans,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter warna, partikel, sinar, retakan
// ---------------------------------------------------------------------------

ColorFilter _satFilter(double s) {
  final inv = 1 - s;
  const r = 0.2126, g = 0.7152, b = 0.0722;
  return ColorFilter.matrix(<double>[
    inv * r + s, inv * g, inv * b, 0, 0, //
    inv * r, inv * g + s, inv * b, 0, 0, //
    inv * r, inv * g, inv * b + s, 0, 0, //
    0, 0, 0, 1, 0,
  ]);
}

List<_Part> _makeParts() {
  final r = math.Random(11);
  return [
    for (var i = 0; i < 64; i++)
      _Part(
        r.nextDouble(),
        r.nextDouble(),
        0.4 + r.nextDouble() * 0.9,
        2 + r.nextDouble() * 4,
        0.6 + r.nextDouble() * 1.4,
        i < 28 ? 0 : 1,
      ),
  ];
}

List<List<Offset>> _makeCracks() {
  final r = math.Random(5);
  final out = <List<Offset>>[];
  for (var k = 0; k < 8; k++) {
    var ang = k * 2 * math.pi / 8 + (r.nextDouble() - 0.5) * 0.4;
    final pts = <Offset>[const Offset(0.5, 0.58)];
    for (var s = 0; s < 6; s++) {
      ang += (r.nextDouble() - 0.5) * 0.7;
      final step = 0.07 + 0.05 * r.nextDouble();
      final p = pts.last;
      pts.add(Offset(p.dx + math.cos(ang) * step, p.dy + math.sin(ang) * step));
    }
    out.add(pts);
  }
  return out;
}

class _FxPainter extends CustomPainter {
  final double sec;
  final bool win;
  final bool petals; // true: kelopak jatuh; false: abu
  final double moteEnv;
  final double fallEnv;
  final List<_Part> parts;
  const _FxPainter({
    required this.sec,
    required this.win,
    required this.petals,
    required this.moteEnv,
    required this.fallEnv,
    required this.parts,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in parts) {
      final mote = p.kind == 0;
      final env = mote ? moteEnv : fallEnv;
      if (env <= 0.01) continue;
      final f = (sec * p.speed * (mote ? 0.045 : 0.06) + p.phase) % 1.0;
      final y = mote ? size.height * (1 - f) : size.height * f;
      final x = size.width * p.x +
          math.sin(sec * p.sway + p.phase * 6.283) *
              size.width *
              (mote ? 0.025 : 0.05);
      final alpha = (env * math.sin(f * math.pi)).clamp(0.0, 1.0).toDouble();
      if (alpha <= 0.01) continue;

      if (mote) {
        final tw = 0.6 + 0.4 * math.sin(sec * 2.2 * p.sway + p.phase * 9);
        final c = win ? const Color(0xFFFFE08A) : EmbunColors.mist;
        paint
          ..color = c.withValues(alpha: alpha * tw * (win ? 0.9 : 0.45))
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, p.size * 0.9);
        canvas.drawCircle(Offset(x, y), p.size * (win ? 1.0 : 2.2), paint);
      } else {
        paint.maskFilter = null;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(sec * p.sway + p.phase * 6.283);
        if (petals) {
          paint.color = (p.phase > 0.5
              ? const Color(0xFFFFE4EC)
              : const Color(0xFFF7B6C8))
              .withValues(alpha: alpha * 0.9);
          canvas.drawOval(
              Rect.fromCenter(
                  center: Offset.zero,
                  width: p.size * 2.4,
                  height: p.size * 1.4),
              paint);
        } else {
          paint.color =
              const Color(0xFF9A8F88).withValues(alpha: alpha * 0.7);
          canvas.drawRect(
              Rect.fromCenter(
                  center: Offset.zero, width: p.size, height: p.size * 0.7),
              paint);
        }
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FxPainter old) => true;
}

class _RaysPainter extends CustomPainter {
  final double sec;
  final double a;
  const _RaysPainter({required this.sec, required this.a});

  @override
  void paint(Canvas canvas, Size size) {
    if (a <= 0.01) return;
    final origin = Offset(size.width * 0.8, -size.height * 0.08);
    final len = size.longestSide * 1.3;
    Offset dir(double ang) => Offset(-math.sin(ang), math.cos(ang));
    for (var i = 0; i < 7; i++) {
      final ang = 0.12 + i * 0.14;
      final half = 0.035 + 0.02 * ((i * 5) % 3);
      final pulse = 0.55 + 0.45 * math.sin(sec * 0.8 + i * 1.7);
      final p1 = origin + dir(ang - half) * len;
      final p2 = origin + dir(ang + half) * len;
      final path = Path()
        ..moveTo(origin.dx, origin.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();
      final paint = Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.linear(
          origin,
          origin + dir(ang) * len,
          [
            const Color(0xFFFFF0B0).withValues(alpha: 0.38 * a * pulse),
            const Color(0x00FFF0B0),
          ],
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RaysPainter old) => true;
}

class _CrackPainter extends CustomPainter {
  final List<List<Offset>> lines;
  final double progress;
  final double fade;
  const _CrackPainter(
      {required this.lines, required this.progress, required this.fade});

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6)
      ..color = EmbunColors.mist.withValues(alpha: 0.6 * fade);
    final core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFF1E6FF).withValues(alpha: 0.95 * fade);
    for (final pts in lines) {
      final path = Path()
        ..moveTo(pts.first.dx * size.width, pts.first.dy * size.height);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx * size.width, p.dy * size.height);
      }
      for (final m in path.computeMetrics()) {
        final sub = m.extractPath(0, m.length * progress);
        canvas.drawPath(sub, glow);
        canvas.drawPath(sub, core);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CrackPainter old) => true;
}