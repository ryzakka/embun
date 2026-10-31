import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';

double _seg(double t, double a, double b) =>
    ((t - a) / (b - a)).clamp(0.0, 1.0).toDouble();

double _bump(double t, double c, double w) =>
    max(0.0, 1 - (t - c).abs() / w);

double _hillY(double x, double w, double h) =>
    h * 0.80 +
        sin(x / w * pi * 2 + 0.6) * h * 0.018 +
        sin(x / w * pi * 5 + 1.3) * h * 0.007;

double _hill2Y(double x, double w, double h) =>
    h * 0.89 + sin(x / w * pi * 3 + 2.0) * h * 0.016;

/// Adegan sinematik peralihan hari (4,4 detik). Menyambung dari NightScene:
/// dunia yang sama (bulan, bukit, rumah desa, pohon Hayu) tetapi sekarang
/// fajar menyingsing. Linimasa (t = 0..1):
///
///  0.00-0.06  layar menggelap, bilah sinema menutup
///  0.00-0.50  malam sunyi: bulan tenggelam di balik bukit, bintang memudar,
///             kabut bergeser. Tulisan "HARI" jatuh huruf demi huruf, angka
///             hari kemarin tampak redup lalu terangkat dan lenyap
///  0.05-0.30  jendela rumah desa menyala satu per satu (desa terbangun)
///  0.15-0.65  matahari terbit di balik bukit, langit beralih dari malam ke
///             fajar, sinar berputar, tepi bukit berpendar, burung melintas
///  0.30-0.70  lanskap Hayu muncul menggantikan siluet dengan zoom perlahan
///  0.40-0.52  angka hari baru menghantam dari besar ke ukuran asli
///  0.52       kilatan, tiga cincin kejut, percikan, layar terhentak dan
///             bergetar, getar haptic ganda
///  0.52-0.66  garis bercahaya memanjang; butiran cahaya mulai naik
///  0.62-0.74  info persembahan naik
///  0.68-0.84  jumlah daun dihitung naik, bilah kesehatan Hayu terisi
///  0.78-0.90  vonis hari sebelumnya (bila ada)
///  0.90-1.00  seluruh adegan memudar
///
/// Pohon Hayu pada siluet mengikuti kesehatan: rimbun saat daun banyak,
/// jarang dan berwarna kelabu saat daun sedikit. Malam persembahan (hari
/// kelipatan siklus) memakai palet bara jingga, Si Terbisik yang tidak
/// menyamar memakai palet ungu. Ketuk untuk melewati.
class DayTransition extends StatefulWidget {
  final int day;
  final int leaves;
  final int cycle;
  final String? verdict;
  final bool dark;
  final VoidCallback onDone;

  const DayTransition({
    super.key,
    required this.day,
    required this.leaves,
    required this.cycle,
    required this.onDone,
    this.verdict,
    this.dark = false,
  });

  @override
  State<DayTransition> createState() => _DayTransitionState();
}

class _DayTransitionState extends State<DayTransition>
    with SingleTickerProviderStateMixin {
  static const _night = Color(0xFF05080F);
  static const _land = 0.52;

  late final AnimationController c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 4400));
  final Set<int> _fired = {};
  bool _done = false;

  bool get _offering => widget.day % widget.cycle == 0;

  Color get _warm => widget.dark
      ? const Color(0xFFB07CE8)
      : _offering
      ? const Color(0xFFFF9A52)
      : const Color(0xFFFFC857);

  Color get _cool => widget.dark
      ? const Color(0xFF2A1745)
      : _offering
      ? const Color(0xFF3A2438)
      : const Color(0xFF24365E);

  @override
  void initState() {
    super.initState();
    c.addListener(() {
      final t = c.value;
      if (t >= 0.04 && _fired.add(0)) HapticFeedback.lightImpact();
      if (t >= 0.32 && _fired.add(3)) HapticFeedback.selectionClick();
      if (t >= _land && _fired.add(1)) {
        HapticFeedback.heavyImpact();
        Future.delayed(
            const Duration(milliseconds: 120), HapticFeedback.heavyImpact);
      }
      if (t >= 0.7 && _fired.add(2)) HapticFeedback.selectionClick();
    });
    c.forward().whenComplete(_finish);
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    widget.onDone();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final warm = _warm;
    final offering = _offering;
    final subtitle = offering
        ? 'Malam persembahan'
        : 'Persembahan ${widget.cycle - widget.day % widget.cycle} hari lagi';
    final vit = (widget.leaves / 30).clamp(0.0, 1.0).toDouble();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        final numSize = (h * 0.28).clamp(64.0, 120.0).toDouble();

        return AnimatedBuilder(
          animation: c,
          builder: (context, _) {
            final t = c.value;

            final master = min(_seg(t, 0, 0.06), 1 - _seg(t, 0.9, 1.0));
            final sky = Curves.easeOut.transform(_seg(t, 0.15, 0.65));
            final reveal = Curves.easeIn.transform(_seg(t, 0.3, 0.7));
            final kb = Curves.easeOutCubic.transform(_seg(t, 0.2, 1.0));
            final zoom = 1.0 + 0.16 * (1 - kb) + 0.035 * _bump(t, _land, 0.06);
            final barH = h * 0.09 * Curves.easeOut.transform(_seg(t, 0, 0.15));
            final flash = _bump(t, _land, 0.03) * 0.55;

            // --- guncangan seluruh teks setelah angka mendarat ---
            final shakeK = _seg(t, _land, 0.74);
            final shakeX =
            t > _land ? sin(shakeK * 70) * 14 * (1 - shakeK) : 0.0;
            final shakeY =
            t > _land ? sin(shakeK * 83) * 6 * (1 - shakeK) : 0.0;

            // --- angka kemarin -> angka hari ini ---
            final pvIn = _seg(t, 0.08, 0.2);
            final pvOut = Curves.easeIn.transform(_seg(t, 0.26, 0.38));
            final slamK = Curves.easeOutBack.transform(_seg(t, 0.4, _land));
            final numOpacity = _seg(t, 0.4, 0.45);

            final shadows = [
              const Shadow(color: Colors.black, blurRadius: 10),
              const Shadow(color: Colors.black, blurRadius: 3),
            ];

            Widget letter(int i) {
              final lt = _seg(t, 0.04 + i * 0.03, 0.14 + i * 0.03);
              return Opacity(
                opacity: lt,
                child: Transform.translate(
                  offset: Offset(0, (1 - lt) * -26),
                  child: Text('HARI'[i],
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white70,
                        shadows: shadows,
                      )),
                ),
              );
            }

            final label = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                letter(0),
                const SizedBox(width: 12),
                letter(1),
                const SizedBox(width: 12),
                letter(2),
                const SizedBox(width: 12),
                letter(3),
              ],
            );

            final numberBox = SizedBox(
              width: numSize * 2.4,
              height: numSize * 1.05,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  if (widget.day > 1)
                    Opacity(
                      opacity: (pvIn * (1 - pvOut)).clamp(0.0, 1.0).toDouble(),
                      child: Transform.translate(
                        offset: Offset(0, -70 * pvOut),
                        child: Transform.scale(
                          scale: 1 - 0.3 * pvOut,
                          child: Text('${widget.day - 1}',
                              style: TextStyle(
                                fontSize: numSize,
                                height: 1.0,
                                fontWeight: FontWeight.w900,
                                color: Colors.white38,
                              )),
                        ),
                      ),
                    ),
                  Opacity(
                    opacity: numOpacity,
                    child: Transform.scale(
                      scale: 2.8 - 1.8 * slamK,
                      child: Text('${widget.day}',
                          style: TextStyle(
                            fontSize: numSize,
                            height: 1.0,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            shadows: [
                              Shadow(color: warm, blurRadius: 32),
                              const Shadow(color: Colors.black, blurRadius: 8),
                            ],
                          )),
                    ),
                  ),
                ],
              ),
            );

            final line = Container(
              width: 170 * Curves.easeOut.transform(_seg(t, _land, 0.66)),
              height: 3,
              decoration: BoxDecoration(
                color: warm,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [BoxShadow(color: warm, blurRadius: 10)],
              ),
            );

            final st = _seg(t, 0.62, 0.74);
            final sub = Opacity(
              opacity: st,
              child: Transform.translate(
                offset: Offset(0, (1 - st) * 14),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: offering ? FontWeight.w800 : FontWeight.w500,
                    letterSpacing: 1,
                    color: offering ? Colors.amberAccent : Colors.white70,
                    shadows: shadows,
                  ),
                ),
              ),
            );

            final lvT = _seg(t, 0.68, 0.84);
            final lvE = Curves.easeOut.transform(lvT);
            final shownLeaves = (widget.leaves * lvE).round();
            final barColor = widget.dark
                ? const Color(0xFFB07CE8)
                : Color.lerp(Colors.redAccent, Colors.greenAccent, vit)!;
            final leavesBlock = Opacity(
              opacity: lvT,
              child: Transform.translate(
                offset: Offset(0, (1 - lvT) * 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const GameIcon('helaidaun', size: 30),
                        const SizedBox(width: 6),
                        Text('$shownLeaves daun',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              shadows: shadows,
                            )),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 180,
                      height: 6,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Stack(
                          children: [
                            const Positioned.fill(
                                child: ColoredBox(color: Colors.white12)),
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor:
                              (vit * lvE).clamp(0.0, 1.0).toDouble(),
                              child: SizedBox.expand(
                                  child: ColoredBox(color: barColor)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );

            final vt = _seg(t, 0.78, 0.9);
            final verdictBox = widget.verdict == null
                ? const SizedBox.shrink()
                : Opacity(
              opacity: vt,
              child: Transform.translate(
                offset: Offset(0, (1 - vt) * 14),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                    border:
                    Border.all(color: warm.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const GameIcon('vote', size: 26),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(widget.verdict!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
            );

            final content = Transform.translate(
              offset: Offset(shakeX, shakeY),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        label,
                        numberBox,
                        const SizedBox(height: 8),
                        line,
                        const SizedBox(height: 12),
                        sub,
                        const SizedBox(height: 14),
                        leavesBlock,
                        if (widget.verdict != null) ...[
                          const SizedBox(height: 14),
                          verdictBox,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );

            return Opacity(
              opacity: master.clamp(0.0, 1.0).toDouble(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // langit malam -> fajar
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.lerp(_night, _cool, sky)!,
                          Color.lerp(
                              _night, Color.lerp(_cool, warm, 0.6)!, sky)!,
                          Color.lerp(
                              _night, Color.lerp(_cool, warm, 0.95)!, sky)!,
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                  // bintang, bulan tenggelam, matahari terbit, sinar
                  CustomPaint(
                    painter: _SkyPainter(t: t, warm: warm, seed: widget.day),
                  ),
                  // siluet desa + Hayu (menyambung dari layar malam)
                  if (reveal < 0.99)
                    Opacity(
                      opacity: (1 - reveal).clamp(0.0, 1.0).toDouble(),
                      child: CustomPaint(
                        painter: _GroundPainter(
                          t: t,
                          warm: warm,
                          vit: vit,
                          dark: widget.dark,
                          leaves: widget.leaves,
                        ),
                      ),
                    ),
                  // lanskap Hayu: muncul + zoom perlahan + terhentak
                  Opacity(
                    opacity: reveal * 0.82,
                    child: Transform.scale(
                      scale: zoom,
                      child: Backdrop(
                        path: landscapePath(widget.leaves),
                        dark: widget.dark,
                        dim: 0.5,
                      ),
                    ),
                  ),
                  // kabut malam + butiran cahaya fajar
                  CustomPaint(
                    painter: _MotesPainter(t: t, warm: warm, seed: widget.day),
                  ),
                  // vinyet agar teks terbaca
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 0.95,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                        ],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                  CustomPaint(
                    painter: _RingPainter(t: t, warm: warm, seed: widget.day),
                  ),
                  content,
                  if (flash > 0.01)
                    ColoredBox(
                        color: Colors.white.withValues(
                            alpha: flash.clamp(0.0, 1.0).toDouble())),
                  // bilah sinema
                  Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                        height: barH,
                        width: w,
                        child: const ColoredBox(color: Colors.black)),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                        height: barH,
                        width: w,
                        child: const ColoredBox(color: Colors.black)),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: barH + 8,
                    child: Opacity(
                      opacity: _seg(t, 0.3, 0.45) * 0.7,
                      child: const Text('Ketuk untuk lewati',
                          textAlign: TextAlign.center,
                          style:
                          TextStyle(fontSize: 11, color: Colors.white54)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }
}

/// Bintang yang memudar, bulan yang tenggelam (posisinya sama dengan layar
/// malam), matahari terbit, dan sinar yang berputar.
class _SkyPainter extends CustomPainter {
  final double t;
  final Color warm;
  final int seed;
  _SkyPainter({required this.t, required this.warm, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // bintang
    final starFade = 1 - Curves.easeIn.transform(_seg(t, 0.05, 0.55));
    if (starFade > 0) {
      final rnd = Random(seed * 97 + 5);
      for (var i = 0; i < 60; i++) {
        final x = rnd.nextDouble() * w;
        final y = rnd.nextDouble() * h * 0.62;
        final r = 0.8 + rnd.nextDouble() * 1.8;
        final ph = rnd.nextDouble() * 2 * pi;
        final tw = 0.55 + 0.45 * sin(t * 14 + ph);
        canvas.drawCircle(
          Offset(x, y),
          r,
          Paint()
            ..color = Colors.white.withValues(
                alpha: (starFade * tw).clamp(0.0, 1.0).toDouble()),
        );
      }
    }

    // bulan tenggelam ke balik bukit
    final moonT = 1 - Curves.easeIn.transform(_seg(t, 0.04, 0.5));
    if (moonT > 0.01) {
      final r = min(w, h) * 0.11;
      final mc = Offset(w * 0.74, h * (0.2 + 0.62 * (1 - moonT)));
      final tint = const Color(0xFFF3E9B8);
      canvas.drawCircle(
        mc,
        r * 3.4,
        Paint()
          ..shader = RadialGradient(colors: [
            tint.withValues(alpha: 0.30 * moonT),
            tint.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: mc, radius: r * 3.4)),
      );
      canvas.drawCircle(
        mc,
        r,
        Paint()
          ..color = const Color(0xFFF6EDBF)
              .withValues(alpha: (0.95 * moonT).clamp(0.0, 1.0).toDouble()),
      );
      for (final k in const [
        [-0.3, -0.25, 0.22],
        [0.28, 0.12, 0.16],
        [-0.08, 0.42, 0.12],
      ]) {
        canvas.drawCircle(mc + Offset(k[0] * r, k[1] * r), k[2] * r,
            Paint()..color = Colors.black.withValues(alpha: 0.08 * moonT));
      }
    }

    // matahari terbit dari balik bukit
    final sunT = Curves.easeOutCubic.transform(_seg(t, 0.15, 0.62));
    final r = min(w, h) * 0.14;
    final c = Offset(w * 0.45, h * (0.98 - 0.52 * sunT));

    canvas.drawCircle(
      c,
      r * 5.5,
      Paint()
        ..shader = RadialGradient(colors: [
          warm.withValues(alpha: 0.65 * sunT),
          warm.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: c, radius: r * 5.5)),
    );

    const n = 16;
    final half = pi / n * 0.35;
    final rl = max(w, h) * 1.3;
    final rot = t * 0.8;
    final rayPaint = Paint()..color = warm.withValues(alpha: 0.13 * sunT);
    for (var i = 0; i < n; i++) {
      final a = rot + i * 2 * pi / n;
      final p = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + cos(a - half) * rl, c.dy + sin(a - half) * rl)
        ..lineTo(c.dx + cos(a + half) * rl, c.dy + sin(a + half) * rl)
        ..close();
      canvas.drawPath(p, rayPaint);
    }

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = Color.lerp(warm, Colors.white, 0.55)!
            .withValues(alpha: sunT.clamp(0.0, 1.0).toDouble()),
    );
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => old.t != t;
}

/// Siluet bukit, rumah desa, dan pohon Hayu. Rumah terbangun (jendela
/// menyala), tepi bukit berpendar disinari matahari, burung melintas.
/// Pohon mengikuti kesehatan Hayu: jarang dan kelabu bila daun sedikit.
class _GroundPainter extends CustomPainter {
  final double t;
  final Color warm;
  final double vit;
  final bool dark;
  final int leaves;
  _GroundPainter({
    required this.t,
    required this.warm,
    required this.vit,
    required this.dark,
    required this.leaves,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final sunT = Curves.easeOutCubic.transform(_seg(t, 0.15, 0.62));
    final dawn = _seg(t, 0.3, 0.7);
    final u = min(w, h);

    // ---- bukit belakang ----
    final ridge = Path()..moveTo(0, _hillY(0, w, h));
    final hill = Path()..moveTo(0, h);
    hill.lineTo(0, _hillY(0, w, h));
    for (double x = 6; x <= w + 6; x += 6) {
      final y = _hillY(x, w, h);
      ridge.lineTo(x, y);
      hill.lineTo(x, y);
    }
    hill.lineTo(w, h);
    hill.close();

    final topCol = Color.lerp(const Color(0xFF0B1630),
        Color.lerp(const Color(0xFF1A2438), warm, 0.4)!, sunT)!;
    canvas.drawPath(
      hill,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, h * 0.75), Offset(0, h),
            [topCol, const Color(0xFF050A14)]),
    );
    // tepi bukit berpendar
    canvas.drawPath(
      ridge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
        ..color = warm.withValues(alpha: 0.65 * sunT),
    );

    // ---- rumah desa terbangun ----
    final bw = u * 0.055, bh = bw * 0.8, rh = bw * 0.5;
    const hx = [0.50, 0.61, 0.73, 0.85];
    final wake = _seg(t, 0.05, 0.28) * (1 - _seg(t, 0.45, 0.7));
    for (var i = 0; i < hx.length; i++) {
      final x = w * hx[i];
      final by = _hillY(x, w, h) + 2;
      canvas.drawRect(Rect.fromLTWH(x - bw / 2, by - bh, bw, bh),
          Paint()..color = const Color(0xFF040810));
      canvas.drawPath(
        Path()
          ..moveTo(x - bw * 0.62, by - bh)
          ..lineTo(x, by - bh - rh)
          ..lineTo(x + bw * 0.62, by - bh)
          ..close(),
        Paint()..color = const Color(0xFF03060D),
      );
      // tiap rumah bangun bergantian
      final lit = (_seg(t, 0.05 + i * 0.05, 0.12 + i * 0.05)) *
          (1 - _seg(t, 0.45 + i * 0.03, 0.62 + i * 0.03)) *
          (0.85 + 0.15 * sin(t * 40 + i * 2));
      if (lit > 0.01 && wake >= 0) {
        final win = Rect.fromCenter(
            center: Offset(x, by - bh * 0.5),
            width: bw * 0.3,
            height: bw * 0.3);
        canvas.drawCircle(
          win.center,
          bw * 1.2,
          Paint()
            ..shader = ui.Gradient.radial(win.center, bw * 1.2, [
              const Color(0xFFFFC857).withValues(alpha: 0.32 * lit),
              const Color(0xFFFFC857).withValues(alpha: 0),
            ]),
        );
        canvas.drawRect(win,
            Paint()..color = const Color(0xFFFFD27A).withValues(alpha: lit));
      }
    }

    // ---- pohon Hayu ----
    final tx = w * 0.20;
    final baseY = _hillY(tx, w, h);
    final th = h * 0.06;
    final ch = h * 0.045;
    final trunkW = h * 0.011;
    final canopyBase = baseY - th;
    final nightTree = const Color(0xFF06101A);
    final aliveCol = vit >= 0.95
        ? const Color(0xFF8A4A62) // sakura: rona merah muda gelap
        : Color.lerp(const Color(0xFF3A3640), const Color(0xFF1F5A3A), vit)!;
    final treeCol = Color.lerp(nightTree, aliveCol, dawn * 0.85)!;

    // aura Hayu menyala seiring fajar
    final auraA = (0.10 + 0.22 * vit) * dawn * (1 - _seg(t, 0.62, 0.7));
    final ac = Offset(tx, canopyBase - ch * 0.4);
    final auraCol = dark ? const Color(0xFFB07CE8) : const Color(0xFF7FE0A0);
    canvas.drawCircle(
      ac,
      ch * 3.6,
      Paint()
        ..shader = ui.Gradient.radial(ac, ch * 3.6, [
          auraCol.withValues(alpha: auraA.clamp(0.0, 1.0)),
          auraCol.withValues(alpha: 0),
        ]),
    );

    final trunkPaint = Paint()..color = nightTree;
    canvas.drawPath(
      Path()
        ..moveTo(tx - trunkW, baseY + 2)
        ..lineTo(tx - trunkW * 0.55, canopyBase)
        ..lineTo(tx + trunkW * 0.55, canopyBase)
        ..lineTo(tx + trunkW, baseY + 2)
        ..close(),
      trunkPaint,
    );
    // dahan telanjang, tampak jelas bila daun sedikit
    final branch = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = trunkW * 0.55
      ..color = nightTree;
    const br = [
      [-1.0, 1.5],
      [1.0, 1.6],
      [-0.5, 2.0],
      [0.55, 2.1],
    ];
    for (final b in br) {
      canvas.drawLine(
          Offset(tx, canopyBase),
          Offset(tx + b[0] * ch * 1.3, canopyBase - b[1] * ch),
          branch);
    }

    const crown = [
      [0.0, 0.2, 1.0],
      [-0.9, 0.0, 0.7],
      [0.9, 0.05, 0.75],
      [-0.4, 0.9, 0.7],
      [0.45, 0.85, 0.65],
    ];
    final count = (1 + vit * 4).round().clamp(1, 5);
    final fill = Paint()..color = treeCol;
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = warm.withValues(alpha: 0.5 * sunT);
    for (var i = 0; i < count; i++) {
      final c = crown[i];
      final p = Offset(tx + c[0] * ch, canopyBase - c[1] * ch);
      canvas.drawCircle(p, c[2] * ch, fill);
      canvas.drawCircle(p, c[2] * ch, rim);
    }

    // ---- bukit depan ----
    final front = Path()..moveTo(0, h);
    for (double x = 0; x <= w + 6; x += 6) {
      front.lineTo(x, _hill2Y(x, w, h));
    }
    front.lineTo(w, h);
    front.close();
    canvas.drawPath(front, Paint()..color = const Color(0xFF03060D));

    // ---- burung melintas ----
    final bt = _seg(t, 0.5, 0.9);
    if (!dark && bt > 0 && bt < 1) {
      final bp = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.6
        ..color = const Color(0xFF05080F)
            .withValues(alpha: 0.75 * sin(bt * pi).clamp(0.0, 1.0));
      for (var i = 0; i < 5; i++) {
        final f = (bt * 1.15 - i * 0.05).clamp(0.0, 1.0);
        final x = w * (-0.08 + 1.16 * f);
        final y = h * (0.26 + 0.035 * i) + sin(f * 9 + i) * h * 0.012;
        final s = u * (0.016 + 0.003 * (i % 3));
        final flap = sin(t * 70 + i * 1.7) * s * 0.7;
        final path = Path()
          ..moveTo(x - s, y - flap)
          ..quadraticBezierTo(x - s * 0.4, y - s * 0.5, x, y)
          ..quadraticBezierTo(x + s * 0.4, y - s * 0.5, x + s, y - flap);
        canvas.drawPath(path, bp);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GroundPainter old) => old.t != t;
}

/// Kabut malam yang bergeser dan memudar saat fajar, lalu butiran cahaya
/// yang melayang naik.
class _MotesPainter extends CustomPainter {
  final double t;
  final Color warm;
  final int seed;
  _MotesPainter({required this.t, required this.warm, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    final fog = 0.09 * (1 - _seg(t, 0.3, 0.62)) * _seg(t, 0, 0.1);
    if (fog > 0.003) {
      final p = Paint()
        ..color = Colors.white.withValues(alpha: fog)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 38);
      for (var i = 0; i < 5; i++) {
        final dir = i.isEven ? 1.0 : -1.0;
        final x = (i * 0.27 + t * 0.35 * dir) % 1.3 - 0.15;
        canvas.drawCircle(
            Offset(w * x, h * (0.55 + 0.09 * i)), max(w, h) * 0.2, p);
      }
    }

    final mt = _seg(t, 0.35, 0.55);
    if (mt > 0) {
      final rnd = Random(seed * 53 + 9);
      for (var i = 0; i < 30; i++) {
        final x0 = rnd.nextDouble();
        final sp = 0.5 + rnd.nextDouble();
        final sz = 1.5 + rnd.nextDouble() * 3.5;
        final ph = rnd.nextDouble();
        final f = (t * 1.3 * sp + ph) % 1.0;
        final y = h * (1.05 - f * 1.1);
        final x = w * x0 + sin((f + ph) * 2 * pi) * 16;
        final a = (sin(f * pi) * 0.7 * mt).clamp(0.0, 1.0).toDouble();
        canvas.drawCircle(
          Offset(x, y),
          sz,
          Paint()
            ..color = (i.isEven ? warm : Colors.white).withValues(alpha: a),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MotesPainter old) => old.t != t;
}

/// Cincin kejut dan percikan yang meledak saat angka hari mendarat.
class _RingPainter extends CustomPainter {
  final double t;
  final Color warm;
  final int seed;
  _RingPainter({required this.t, required this.warm, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final s = _seg(t, _DayTransitionState._land, 0.88);
    if (s <= 0 || s >= 1) return;
    final c = Offset(size.width / 2, size.height * 0.46);
    final e = Curves.easeOutCubic.transform(s);

    for (var ring = 0; ring < 3; ring++) {
      final rs = ((s - ring * 0.1) / (1 - ring * 0.1)).clamp(0.0, 1.0);
      if (rs <= 0) continue;
      final re = Curves.easeOutCubic.transform(rs.toDouble());
      canvas.drawCircle(
        c,
        30 + 420 * re,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (8 * (1 - rs)).clamp(0.5, 8.0).toDouble()
          ..color = Color.lerp(warm, Colors.white, ring * 0.4)!
              .withValues(alpha: (1 - rs).clamp(0.0, 1.0).toDouble()),
      );
    }

    final rnd = Random(seed * 31 + 3);
    final streak = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    for (var k = 0; k < 24; k++) {
      final ang = rnd.nextDouble() * 2 * pi;
      final dist = 90 + rnd.nextDouble() * 260;
      final dir = Offset(cos(ang), sin(ang));
      final head = c + dir * (dist * e);
      final tail = c + dir * (dist * max(0.0, e - 0.2));
      streak.color = (k.isEven ? warm : Colors.white)
          .withValues(alpha: (1 - s).clamp(0.0, 1.0).toDouble());
      canvas.drawLine(tail, head, streak);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.t != t;
}