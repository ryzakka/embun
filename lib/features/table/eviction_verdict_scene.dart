import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/ornate.dart';

double _seg(double v, double a, double b) =>
    ((v - a) / (b - a)).clamp(0.0, 1.0).toDouble();

double _smooth(double x) => x * x * (3 - 2 * x);

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Angka semu-acak yang stabil (0..1) untuk pecahan, retakan, dan abu.
double _rnd(int i, int k) {
  final v = math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
  return v - v.floorToDouble();
}

ColorFilter _gray(double sat) {
  final inv = 1 - sat;
  const r = 0.2126, g = 0.7152, b = 0.0722;
  return ColorFilter.matrix(<double>[
    inv * r + sat, inv * g, inv * b, 0, 0, //
    inv * r, inv * g + sat, inv * b, 0, 0, //
    inv * r, inv * g, inv * b + sat, 0, 0, //
    0, 0, 0, 1, 0,
  ]);
}

/// Adegan pengusiran: pemain yang dituduh mayoritas untuk KEDUA kalinya
/// keluar dari desa. Sengaja berbeda dari adegan kurungan (besi, gembok,
/// merah): di sini suasananya sinematik dan sunyi. Bilah layar lebar, dunia
/// memudar jadi abu-abu, nyawa terakhir pecah, lalu sosoknya hancur jadi abu
/// dan kabut ungu.
///
/// Memakai aset yang sudah ada: `desajembatan-keringgulita` (bentang),
/// ikon `helaidaun`. Tanpa aset baru.
///
///  0.00-0.08  fade dari hitam; bilah sinema meluncur masuk
///  0.05-0.16  potret muncul dengan dua hati (satu sudah patah); teks
///             TUDUHAN KEDUA; latar perlahan mendekat
///  0.14-0.28  ketegangan: hati terakhir berdetak makin cepat (haptic
///             mengikuti), vinyet menyempit, pendar merah berdenyut
///  0.30       hati pecah jadi serpihan; kilat putih, cincin kejut, getar
///             kuat; KELUAR DARI DESA menghantam; dunia mulai luntur warna
///  0.30-0.50  retakan menjalar di potret, tanda silang merah tergores
///  0.50-0.78  potret pecah jadi kepingan yang naik seperti abu; pendar
///             berubah ungu; kabut dan bara naik; nama dicoret
///  0.74-0.94  satu daun jatuh melayang: "Hayu kehilangan 1 daun"
///  0.94-1.00  memudar ke hitam
///
/// Ketuk untuk melewati. [isMe] mengubah kata ganti menjadi "Kamu".
class EvictionVerdictScene extends StatefulWidget {
  final String name;
  final String? card; // id kartu karakter (protagonistPath)
  final bool isMe;

  /// Jumlah suara yang menjatuhkan vonis (dari teks vonis), bila diketahui.
  final int? votes;
  final VoidCallback onDone;

  const EvictionVerdictScene({
    super.key,
    required this.name,
    required this.card,
    required this.onDone,
    this.isMe = false,
    this.votes,
  });

  @override
  State<EvictionVerdictScene> createState() => _EvictionVerdictSceneState();
}

class _EvictionVerdictSceneState extends State<EvictionVerdictScene>
    with SingleTickerProviderStateMixin {
  static const _totalMs = 8000;
  static const _night = Color(0xFF05080F);

  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: _totalMs));
  final Set<int> _fired = {};
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onTick);
    _c.forward().whenComplete(_finish);
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

  void _onTick() {
    final t = _c.value;
    // Detak jantung yang makin cepat.
    for (var i = 0; i < _beats.length; i++) {
      if (t >= _beats[i] && _fired.add(i)) {
        HapticFeedback.mediumImpact();
      }
    }
    if (t >= 0.30 && _fired.add(10)) {
      HapticFeedback.heavyImpact();
      Future.delayed(
          const Duration(milliseconds: 100), HapticFeedback.heavyImpact);
      Future.delayed(
          const Duration(milliseconds: 220), HapticFeedback.heavyImpact);
    }
    if (t >= 0.44 && _fired.add(11)) HapticFeedback.mediumImpact();
    if (t >= 0.50 && _fired.add(12)) HapticFeedback.selectionClick();
    if (t >= 0.80 && _fired.add(13)) HapticFeedback.lightImpact();
  }

  static const _beats = [0.14, 0.19, 0.235, 0.27];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: Material(
        color: _night,
        child: LayoutBuilder(builder: (context, box) {
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) =>
                _scene(context, box.maxWidth, box.maxHeight),
          );
        }),
      ),
    );
  }

  Widget _scene(BuildContext context, double w, double h) {
    final t = _c.value;
    final sec = t * _totalMs / 1000;
    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).padding.bottom;

    double pulse(double at, double len) =>
        t < at ? 0.0 : math.exp(-(t - at) / len * 5);

    final beat = math.min(
        1.0, [for (final b in _beats) pulse(b, 0.035)].reduce((a, b) => a + b));
    final tension = t < 0.30
        ? _smooth(_seg(t, 0.12, 0.30))
        : 1 - _smooth(_seg(t, 0.30, 0.46));

    // Getar: berdebar saat tegang, kuat saat hati pecah.
    final sh = 10 * pulse(0.30, 0.06) +
        3 * pulse(0.50, 0.05) +
        2 * tension * beat;
    final shake =
    Offset(math.sin(sec * 80) * sh, math.cos(sec * 67) * sh * 0.7);

    final cardPath =
    widget.card == null ? null : protagonistPath(widget.card!);
    final aspect = cardAspectFor(cardPath);
    final ph = math.min(h * 0.42, w * 0.66 * aspect);
    final pw = ph / aspect;
    final heartSize = math.min(46.0, math.max(28.0, pw * 0.2));

    final barH = h * 0.07 * _smooth(_seg(t, 0.0, 0.08));

    // Latar: mendekat pelan, lalu luntur warna setelah hati pecah.
    final bgSat = _lerp(1.0, 0.3, _smooth(_seg(t, 0.30, 0.50)));
    final bgScale = 1.05 +
        0.12 * _smooth(_seg(t, 0.0, 0.30)) -
        0.05 * _smooth(_seg(t, 0.50, 1.0));
    final scrimA = 0.80 - 0.10 * _smooth(_seg(t, 0.50, 0.90));
    final bg = sceneryPath('desajembatan-keringgulita') ??
        sceneryPath('keterasingan');

    // Potret.
    final pIn = _seg(t, 0.05, 0.16);
    final groupScale = _lerp(0.85, 1.0, Curves.easeOutBack.transform(pIn)) *
        (1 + 0.06 * _smooth(_seg(t, 0.16, 0.30))) *
        (1 - 0.05 * pulse(0.30, 0.04));
    final sat = _lerp(1.0, 0.2, _smooth(_seg(t, 0.30, 0.42)));

    // Pendar: merah berdenyut sebelum pecah, lalu ungu.
    final glowColor = Color.lerp(EmbunColors.blood, EmbunColors.mist,
        _smooth(_seg(t, 0.30, 0.50)))!;
    final glowA = 0.40 *
        _smooth(_seg(t, 0.06, 0.2)) *
        (1 - _smooth(_seg(t, 0.70, 0.82))) *
        (0.75 + 0.25 * math.sin(sec * (5 + 12 * tension)));

    final whiteFlash = 0.38 * pulse(0.30, 0.03);
    final redFlash = 0.26 * pulse(0.30, 0.06);
    final mistFlash = 0.12 * pulse(0.50, 0.05);

    final fadeIn = 1 - _smooth(_seg(t, 0.0, 0.04));
    final fadeOut = _smooth(_seg(t, 0.94, 1.0));

    final who = widget.isMe ? 'Kamu' : widget.name;
    final struck = t >= 0.62;
    final nameColor = Color.lerp(EmbunColors.cream, Colors.white54,
        _smooth(_seg(t, 0.50, 0.66)))!;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Latar bentang kering; luntur jadi abu-abu.
        ColorFiltered(
          colorFilter: _gray(bgSat),
          child: Transform.scale(
            scale: bgScale,
            child: GameImage(path: bg, cacheWidth: 1600),
          ),
        ),
        ColoredBox(color: _night.withValues(alpha: scrimA)),

        // Kabut ungu dan bara yang naik.
        IgnorePointer(
          child: CustomPaint(
            painter: _MistPainter(
              sec: sec,
              env: _smooth(_seg(t, 0.48, 0.64)) *
                  (1 - _smooth(_seg(t, 0.92, 1.0))),
            ),
            size: Size.infinite,
          ),
        ),

        // Pendar di belakang potret.
        if (glowA > 0.01)
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.08),
                  radius: 0.85,
                  colors: [
                    glowColor.withValues(alpha: glowA),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

        // Isi yang ikut bergetar.
        Transform.translate(
          offset: shake,
          child: Align(
            alignment: const Alignment(0, -0.08),
            child: Transform.scale(
              scale: groupScale,
              child: Opacity(
                opacity: _smooth(pIn),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _portraitStack(t, cardPath, pw, ph, sat),
                    SizedBox(height: heartSize * 0.45),
                    _hearts(t, heartSize, beat),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Daun jatuh dari Hayu.
        _leaf(t, w, h),

        // Vinyet: menyempit saat tegang.
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.0,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.75 + 0.15 * tension),
                ],
                stops: [_lerp(0.55, 0.26, tension), 1.0],
              ),
            ),
          ),
        ),

        // Kilatan.
        if (redFlash > 0.01)
          IgnorePointer(
              child: ColoredBox(
                  color: EmbunColors.blood.withValues(alpha: redFlash))),
        if (mistFlash > 0.01)
          IgnorePointer(
              child: ColoredBox(
                  color: EmbunColors.mist.withValues(alpha: mistFlash))),
        if (whiteFlash > 0.01)
          IgnorePointer(
              child: ColoredBox(
                  color: Colors.white.withValues(alpha: whiteFlash))),

        // Bilah sinema.
        Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: barH,
            child: const ColoredBox(color: Colors.black)),
        Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: barH,
            child: const ColoredBox(color: Colors.black)),

        // Teks atas: "TUDUHAN KEDUA" lalu "KELUAR DARI DESA".
        Positioned(
          left: 20,
          right: 20,
          top: topPad + h * 0.07 + 14,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Opacity(
                opacity: _smooth(_seg(t, 0.06, 0.14)) *
                    (1 - _smooth(_seg(t, 0.29, 0.31))),
                child: const Text(
                  'TUDUHAN KEDUA',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 6,
                    fontWeight: FontWeight.bold,
                    color: EmbunColors.blood,
                  ),
                ),
              ),
              Opacity(
                opacity: _smooth(_seg(t, 0.30, 0.34)),
                child: Transform.scale(
                  scale: _lerp(1.8, 1.0,
                      Curves.easeOutCubic.transform(_seg(t, 0.30, 0.38))),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'KELUAR DARI DESA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        letterSpacing: 7,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFFFE3DC),
                        shadows: [
                          Shadow(
                              color: EmbunColors.blood.withValues(alpha: 0.9),
                              blurRadius: 22),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Nama + keterangan.
        Positioned(
          left: 20,
          right: 20,
          bottom: botPad + h * 0.07 + 14,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: _smooth(_seg(t, 0.14, 0.22)),
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - _smooth(_seg(t, 0.14, 0.22)))),
                  child: Text(
                    who,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: nameColor,
                      decoration: struck
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: EmbunColors.blood,
                      decorationThickness: 3,
                      shadows: [
                        Shadow(
                            color: EmbunColors.blood.withValues(alpha: 0.8),
                            blurRadius: 18),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 44,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Opacity(
                      opacity: _smooth(_seg(t, 0.20, 0.28)) *
                          (1 - _smooth(_seg(t, 0.46, 0.52))),
                      child: Text(
                        widget.votes == null
                            ? 'dituduh mayoritas untuk kedua kalinya'
                            : 'dituduh mayoritas untuk kedua kalinya '
                            '(${widget.votes} suara)',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.white70),
                      ),
                    ),
                    Opacity(
                      opacity: _smooth(_seg(t, 0.58, 0.66)) *
                          (1 - _smooth(_seg(t, 0.80, 0.84))),
                      child: Text(
                        widget.isMe
                            ? 'Kamu hanyalah warga biasa.\n'
                            'Kini kamu hanya bisa menonton.'
                            : 'Ia hanyalah warga biasa.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.white70, height: 1.35),
                      ),
                    ),
                    Opacity(
                      opacity: _smooth(_seg(t, 0.84, 0.90)),
                      child: const Text(
                        'Hayu kehilangan 1 daun',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14, color: EmbunColors.leaf),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Fade masuk / keluar.
        if (fadeIn > 0)
          IgnorePointer(
              child: ColoredBox(color: Colors.black.withValues(alpha: fadeIn))),
        if (fadeOut > 0)
          IgnorePointer(
              child: ColoredBox(color: _night.withValues(alpha: fadeOut))),
      ],
    );
  }

  // ---------------------------------------------------------------- potret

  Widget _portraitStack(
      double t, String? path, double pw, double ph, double sat) {
    return SizedBox(
      width: pw,
      height: ph,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          _portraitBody(t, path, pw, ph, sat),
          if (t >= 0.30)
            IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CustomPaint(
                  painter: _CrackPainter(p: _seg(t, 0.30, 0.46)),
                  size: Size(pw, ph),
                ),
              ),
            ),
          if (t >= 0.38)
            IgnorePointer(
              child: Opacity(
                opacity: 1 - _smooth(_seg(t, 0.66, 0.76)),
                child: CustomPaint(
                  painter: _XPainter(
                      a: _seg(t, 0.38, 0.45), b: _seg(t, 0.44, 0.51)),
                  size: Size(pw, ph),
                ),
              ),
            ),
          if (t >= 0.30)
            IgnorePointer(
              child: CustomPaint(
                painter: _RingPainter(
                  p: _seg(t, 0.30, 0.46),
                  r0: pw * 0.3,
                  r1: pw * 1.8,
                  color: Colors.white,
                ),
                size: Size(pw, ph),
              ),
            ),
        ],
      ),
    );
  }

  Widget _portraitBody(
      double t, String? path, double pw, double ph, double sat) {
    final dis = _seg(t, 0.50, 0.78);
    final borderA = 1 - _smooth(_seg(t, 0.50, 0.58));
    final iw = pw - 4, ih = ph - 4; // dikurangi tebal garis tepi
    final Widget img = path == null
        ? const ColoredBox(
      color: Color(0xFF1A1218),
      child: Center(child: GameIcon('character', size: 48)),
    )
        : GameImage(path: path, cacheWidth: 600);
    return Container(
      width: pw,
      height: ph,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: EmbunColors.blood.withValues(alpha: borderA), width: 2),
        boxShadow: [
          BoxShadow(
              color: EmbunColors.blood.withValues(alpha: 0.55 * borderA),
              blurRadius: 24),
        ],
      ),
      child: ColorFiltered(
        colorFilter: _gray(sat),
        child: dis <= 0
            ? ClipRRect(borderRadius: BorderRadius.circular(8), child: img)
            : _tiles(img, iw, ih, dis),
      ),
    );
  }

  /// Potret dipecah jadi kepingan yang naik, berputar, dan memudar seperti
  /// abu, dari atas ke bawah dengan acakan.
  Widget _tiles(Widget img, double iw, double ih, double dis) {
    const cols = 5, rows = 7;
    final tw = iw / cols, th = ih / rows;
    final out = <Widget>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final i = r * cols + c;
        final d = (r / rows) * 0.45 + _rnd(i, 1) * 0.30;
        final p = _smooth(_seg(dis, d, d + 0.31));
        final dx = (_rnd(i, 2) - 0.5) * iw * 0.9 * p;
        final dy = -(0.10 + 0.6 * _rnd(i, 3)) * ih * p;
        final rot = (_rnd(i, 4) - 0.5) * 2.0 * p;
        out.add(Positioned(
          left: c * tw,
          top: r * th,
          width: tw,
          height: th,
          child: Opacity(
            opacity: (1 - p).clamp(0.0, 1.0).toDouble(),
            child: Transform.translate(
              offset: Offset(dx, dy),
              child: Transform.rotate(
                angle: rot,
                child: ClipRect(
                  child: OverflowBox(
                    alignment:
                    Alignment(-1 + 2 * c / (cols - 1), -1 + 2 * r / (rows - 1)),
                    minWidth: iw,
                    maxWidth: iw,
                    minHeight: ih,
                    maxHeight: ih,
                    child: img,
                  ),
                ),
              ),
            ),
          ),
        ));
      }
    }
    return Stack(clipBehavior: Clip.none, children: out);
  }

  // ------------------------------------------------------------------ hati

  /// Dua nyawa: yang kiri sudah patah (tuduhan pertama), yang kanan berdetak
  /// lalu pecah.
  Widget _hearts(double t, double size, double beat) {
    final broke = t >= 0.30;
    final breakE = Curves.easeOutBack.transform(_seg(t, 0.30, 0.38));
    final scale = broke ? _lerp(1.7, 1.0, breakE) : 1 + 0.28 * beat;
    final color = Color.lerp(
        EmbunColors.blood, Colors.white30, _smooth(_seg(t, 0.30, 0.42)))!;
    return Opacity(
      opacity: 1 - _smooth(_seg(t, 0.58, 0.68)),
      child: SizedBox(
        width: size * 2.25,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: Icon(Icons.heart_broken_rounded,
                  size: size, color: Colors.white30),
            ),
            Positioned(
              left: size * 1.25,
              top: 0,
              child: Transform.scale(
                scale: scale,
                child: Icon(
                  broke
                      ? Icons.heart_broken_rounded
                      : Icons.favorite_rounded,
                  size: size,
                  color: color,
                  shadows: broke
                      ? null
                      : [
                    Shadow(
                        color:
                        EmbunColors.blood.withValues(alpha: 0.9),
                        blurRadius: 16),
                  ],
                ),
              ),
            ),
            if (t >= 0.30)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ShardPainter(
                      p: _seg(t, 0.30, 0.55),
                      center: Offset(size * 1.75, size / 2),
                      reach: size * 2.8,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ daun

  /// Satu daun Hayu jatuh melayang: harga dari pengusiran.
  Widget _leaf(double t, double w, double h) {
    final p = _seg(t, 0.74, 0.94);
    if (p <= 0 || p >= 1) return const SizedBox.shrink();
    final x = w / 2 + math.sin(p * math.pi * 3) * w * 0.08;
    final y = _lerp(h * 0.26, h * 0.70, Curves.easeIn.transform(p));
    final rot = math.sin(p * math.pi * 3 + 1) * 0.7;
    final a = _smooth(_seg(p, 0.0, 0.15)) * (1 - _smooth(_seg(p, 0.8, 1.0)));
    return Positioned(
      left: x - 22,
      top: y,
      child: IgnorePointer(
        child: Opacity(
          opacity: a,
          child: Transform.rotate(
            angle: rot,
            child: ikonPath('helaidaun') != null
                ? const GameIcon('helaidaun', size: 44)
                : const Icon(Icons.eco_rounded,
                size: 40, color: EmbunColors.leaf),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _RingPainter extends CustomPainter {
  final double p;
  final double r0, r1;
  final Color color;
  const _RingPainter(
      {required this.p,
        required this.r0,
        required this.r1,
        required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (p <= 0 || p >= 1) return;
    final e = Curves.easeOutCubic.transform(p);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * (1 - p) + 1
      ..color = color.withValues(alpha: 0.8 * (1 - p));
    canvas.drawCircle(size.center(Offset.zero), _lerp(r0, r1, e), paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.p != p;
}

/// Serpihan hati yang pecah: segitiga kecil memancar, jatuh, dan memudar.
class _ShardPainter extends CustomPainter {
  final double p;
  final Offset center;
  final double reach;
  const _ShardPainter(
      {required this.p, required this.center, required this.reach});

  @override
  void paint(Canvas canvas, Size size) {
    if (p <= 0 || p >= 1) return;
    final e = Curves.easeOutCubic.transform(p);
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 12; i++) {
      final a = i * 2 * math.pi / 12 + (_rnd(i, 5) - 0.5) * 0.5;
      final d = reach * e * (0.45 + 0.55 * _rnd(i, 6));
      final pos = center +
          Offset(math.cos(a), math.sin(a)) * d +
          Offset(0, reach * 0.35 * p * p);
      final s = (3 + 6 * _rnd(i, 7)) * (1 - 0.5 * p);
      final rot = a + p * 4 * (_rnd(i, 8) - 0.5) * 4;
      final path = Path()
        ..moveTo(pos.dx + math.cos(rot) * s, pos.dy + math.sin(rot) * s)
        ..lineTo(pos.dx + math.cos(rot + 2.3) * s * 0.8,
            pos.dy + math.sin(rot + 2.3) * s * 0.8)
        ..lineTo(pos.dx + math.cos(rot + 4.1) * s * 0.8,
            pos.dy + math.sin(rot + 4.1) * s * 0.8)
        ..close();
      paint.color = Color.lerp(
          EmbunColors.blood, Colors.white, _rnd(i, 9) * 0.4)!
          .withValues(alpha: (1 - p).clamp(0.0, 1.0).toDouble());
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ShardPainter old) => old.p != p;
}

/// Retakan yang menjalar dari dada potret ke segala arah.
class _CrackPainter extends CustomPainter {
  final double p;
  const _CrackPainter({required this.p});

  static const _rays = [-2.7, -1.8, -0.7, 0.4, 1.4, 2.4];
  static const _n = 8;

  @override
  void paint(Canvas canvas, Size size) {
    if (p <= 0) return;
    final c = Offset(size.width * 0.5, size.height * 0.4);
    final path = Path();
    for (var i = 0; i < _rays.length; i++) {
      final len = size.height * 0.75 * (0.7 + 0.3 * _rnd(i, 11));
      final stepLen = len / _n;
      var pt = c;
      path.moveTo(pt.dx, pt.dy);
      final total = p * _n;
      for (var k = 1; k <= _n; k++) {
        final f = math.min(1.0, total - (k - 1));
        if (f <= 0) break;
        final ang = _rays[i] + (_rnd(i * 10 + k, 3) - 0.5) * 0.9;
        pt = pt + Offset(math.cos(ang), math.sin(ang)) * stepLen * f;
        path.lineTo(pt.dx, pt.dy);
        if (f < 1) break;
      }
    }
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.black.withValues(alpha: 0.7));
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(covariant _CrackPainter old) => old.p != p;
}

/// Tanda silang merah yang digoreskan dua kali di atas potret.
class _XPainter extends CustomPainter {
  final double a, b;
  const _XPainter({required this.a, required this.b});

  @override
  void paint(Canvas canvas, Size size) {
    final m = size.width * 0.12;
    final mh = size.height * 0.12;
    void stroke(Offset from, Offset to, double prog) {
      if (prog <= 0) return;
      final end = Offset.lerp(from, to, prog)!;
      canvas.drawLine(
          from,
          end,
          Paint()
            ..strokeWidth = 16
            ..strokeCap = StrokeCap.round
            ..color = Colors.black.withValues(alpha: 0.6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawLine(
          from,
          end,
          Paint()
            ..strokeWidth = 9
            ..strokeCap = StrokeCap.round
            ..color = EmbunColors.blood);
      canvas.drawLine(
          from,
          end,
          Paint()
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFFFFB4AA));
    }

    stroke(Offset(m, mh), Offset(size.width - m, size.height - mh), a);
    stroke(Offset(size.width - m, mh), Offset(m, size.height - mh), b);
  }

  @override
  bool shouldRepaint(covariant _XPainter old) => old.a != a || old.b != b;
}

/// Pita kabut ungu tipis + bara/abu yang naik pelan ke atas.
class _MistPainter extends CustomPainter {
  final double sec;
  final double env;
  const _MistPainter({required this.sec, required this.env});

  @override
  void paint(Canvas canvas, Size size) {
    if (env <= 0.01) return;
    final w = size.width, h = size.height;
    for (var i = 0; i < 3; i++) {
      final bandW = w * 2.4;
      final x = -w * 0.7 + math.sin(sec * (0.25 + i * 0.07) + i) * w * 0.35;
      final y = h * (0.50 + i * 0.13);
      final rect = Rect.fromLTWH(x, y - h * 0.09, bandW, h * 0.18);
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            EmbunColors.mist.withValues(alpha: 0.16 * env),
            Colors.transparent,
          ],
        ).createShader(rect);
      canvas.drawRect(rect, paint);
    }
    final ember = Paint();
    for (var i = 0; i < 46; i++) {
      final a = (i * 0.6180339) % 1.0;
      final b = (i * 0.7548776) % 1.0;
      final f = (sec * (0.05 + 0.07 * b) + a) % 1.0;
      final x = w * ((a * 1.3 + 0.1 * math.sin(sec * 0.7 + i)) % 1.0);
      final y = h * (1 - f);
      final al = (env * math.sin(f * math.pi)).clamp(0.0, 1.0).toDouble();
      ember.color = (i.isEven ? EmbunColors.mist : const Color(0xFFB9A89A))
          .withValues(alpha: al * 0.75);
      canvas.drawCircle(Offset(x, y), 1.2 + 2.2 * b, ember);
    }
  }

  @override
  bool shouldRepaint(covariant _MistPainter old) => true;
}