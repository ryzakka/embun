import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/ornate.dart';
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

  /// Opsional: games.end_reason bila server menyediakannya.
  final String? endReason;

  const EndingCinematic({
    super.key,
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
  Map<String, dynamic>? _antag; // {name, seed, username}
  bool _hapClimax = false;
  bool _hapTitle = false;
  bool _done = false;

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
      if (r == 'tertangkap') return tier();
      return l >= 30 ? _Kind.bloom : tier(); // tanpa data: simpulkan dari daun
    }
    if (r == 'waktu_habis') return _Kind.dusk;
    if (r == 'daun_habis') return _Kind.withered;
    return l <= 0 ? _Kind.withered : _Kind.dusk;
  }

  bool get _atEnd {
    final v = _ctl.value;
    if (v >= 0.97) return true;
    return v >= _revealAt && _revealReady && _antag == null;
  }

  @override
  void initState() {
    super.initState();
    _spec = _specFor(_resolveKind());
    _buildFrames();
    _ctl.addListener(_onTick);
    _ctl.forward();
    _load();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  // ---------- data ----------

  Future<void> _load() async {
    Map<String, dynamic>? found;
    try {
      final s = await widget.secrets;
      for (final e in s.entries) {
        if (e.value['role'] == 'antagonis') {
          String name = '?';
          for (final p in widget.players) {
            if (p['user_id'] == e.key) name = p['name'] as String;
          }
          String? uname;
          try {
            uname = (await widget.usernames)[e.key];
          } catch (_) {}
          found = {
            'name': name,
            'seed': (e.value['dark_seed'] as int?) ?? 0,
            'username': uname,
          };
          break;
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _antag = found;
      _revealReady = true;
    });
    // Timeline sempat menunggu data di titik pengungkapan.
    if (found != null && !_ctl.isAnimating && _ctl.value < 1) {
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
      if (!_revealReady || _antag == null) {
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
                  child: EmbunButton(
                    label: 'Lihat rekap',
                    icon: 'centang',
                    expand: true,
                    onPressed: _finish,
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

  Widget _title(double t) {
    final sp = _spec;
    final win = sp.good;
    final appear = _seg(t, 0.50, 0.62);
    final out = _antag != null ? _smooth(_seg(t, 0.70, 0.76)) : 0.0;
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
    final a = _antag;
    if (a == null) return const SizedBox.shrink();
    final scrim = _smooth(_seg(t, _revealAt, 0.78));
    if (scrim <= 0) return const SizedBox.shrink();

    final lab = _smooth(_seg(t, 0.76, 0.82));
    final nameA = _smooth(_seg(t, 0.92, 0.97));
    final ch = (h * 0.40).clamp(120.0, 300.0).toDouble();
    final cw = ch * 7 / 9;
    final path = darkCardPath(a['seed'] as int);
    final uname = a['username'] as String?;

    Widget card;
    if (path == null) {
      card = const SizedBox.shrink();
    } else if (t < 0.80) {
      card = SizedBox(width: cw, height: ch);
    } else {
      card = FlipCard(
        key: const ValueKey('antagCard'),
        index: 0,
        width: cw,
        height: ch,
        revealed: true,
        dark: true,
        suspense: true,
        glow: EmbunColors.mist,
        front: Container(
          width: cw,
          height: ch,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: EmbunColors.mist, width: 2),
            boxShadow: [
              BoxShadow(
                  color: EmbunColors.mist.withValues(alpha: 0.5),
                  blurRadius: 18),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: GameImage(path: path, cacheWidth: 600),
          ),
        ),
      );
    }

    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Colors.black.withValues(alpha: 0.66 * scrim)),
          Align(
            alignment: const Alignment(0, -0.15),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: lab,
                  child: const Text(
                    'Si Terbisik ternyata...',
                    style: TextStyle(
                        fontSize: 15,
                        letterSpacing: 1.5,
                        color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 12),
                card,
                const SizedBox(height: 14),
                Opacity(
                  opacity: nameA,
                  child: Transform.translate(
                    offset: Offset(0, 12 * (1 - nameA)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          a['name'] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFE6D8F5),
                            shadows: [
                              Shadow(
                                  color: EmbunColors.mist
                                      .withValues(alpha: 0.9),
                                  blurRadius: 18),
                            ],
                          ),
                        ),
                        if (uname != null)
                          Text('yaitu $uname',
                              style: const TextStyle(
                                  fontSize: 15, color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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