import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';

double _seg(double t, double a, double b) =>
    ((t - a) / (b - a)).clamp(0.0, 1.0).toDouble();

/// Adegan sinematik peralihan hari (3,4 detik). Linimasa (t = 0..1):
///
///  0.00-0.15  bilah sinema menutup atas-bawah, langit malam gelap
///  0.00-0.60  matahari terbit dari bawah, sinar berputar, bintang memudar,
///             langit berubah dari malam ke fajar
///  0.25-0.65  lanskap Hayu (sesuai jumlah daun) muncul perlahan
///  0.18-0.32  tulisan "HARI" turun
///  0.30-0.50  angka hari menghantam dari besar ke ukuran asli
///  0.50       kilatan putih, cincin kejut, percikan, getar haptic berat
///  0.50-0.75  angka bergetar mereda; garis bercahaya memanjang
///  0.60-0.72  info persembahan naik
///  0.68-0.84  jumlah daun dihitung naik
///  0.76-0.88  vonis hari sebelumnya (bila ada)
///  0.88-1.00  seluruh adegan memudar
///
/// Ketuk untuk melewati. [dark] = palet ungu untuk Si Terbisik yang tidak
/// sedang menyamar (ikuti `showAsAntag` dari TablePage).
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

  late final AnimationController c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3400));
  bool _slammed = false;
  bool _done = false;

  Color get _warm =>
      widget.dark ? const Color(0xFFB07CE8) : const Color(0xFFFFC857);
  Color get _cool =>
      widget.dark ? const Color(0xFF2A1745) : const Color(0xFF24365E);

  @override
  void initState() {
    super.initState();
    HapticFeedback.lightImpact();
    c.addListener(() {
      if (!_slammed && c.value >= 0.5) {
        _slammed = true;
        HapticFeedback.heavyImpact();
        Future.delayed(
            const Duration(milliseconds: 110), HapticFeedback.mediumImpact);
      }
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
    final offering = widget.day % widget.cycle == 0;
    final subtitle = offering
        ? 'Malam persembahan'
        : 'Persembahan ${widget.cycle - widget.day % widget.cycle} hari lagi';

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

            final master = min(_seg(t, 0, 0.06), 1 - _seg(t, 0.88, 1.0));
            final sky = Curves.easeOut.transform(_seg(t, 0, 0.6));
            final reveal = Curves.easeIn.transform(_seg(t, 0.25, 0.65));
            final barH = h * 0.09 * Curves.easeOut.transform(_seg(t, 0, 0.15));
            final flash = max(0.0, 1 - (t - 0.5).abs() / 0.035) * 0.5;

            // --- teks ---
            final lt = _seg(t, 0.18, 0.32);
            final slamK = Curves.easeOutBack.transform(_seg(t, 0.3, 0.5));
            final numOpacity = _seg(t, 0.3, 0.38);
            final shakeK = _seg(t, 0.5, 0.75);
            final shake = t > 0.5 ? sin(shakeK * 60) * 12 * (1 - shakeK) : 0.0;
            final barW = 160 * Curves.easeOut.transform(_seg(t, 0.5, 0.66));
            final st = _seg(t, 0.6, 0.72);
            final lvT = _seg(t, 0.68, 0.84);
            final shownLeaves =
            (widget.leaves * Curves.easeOut.transform(lvT)).round();
            final vt = _seg(t, 0.76, 0.88);

            final shadows = [
              const Shadow(color: Colors.black, blurRadius: 10),
              const Shadow(color: Colors.black, blurRadius: 3),
            ];

            final label = Opacity(
              opacity: lt,
              child: Transform.translate(
                offset: Offset(0, (1 - lt) * -14),
                child: Text('HARI',
                    style: TextStyle(
                      fontSize: 18,
                      letterSpacing: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                      shadows: shadows,
                    )),
              ),
            );

            final number = Opacity(
              opacity: numOpacity,
              child: Transform.translate(
                offset: Offset(shake, 0),
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
            );

            final line = Container(
              width: barW,
              height: 3,
              decoration: BoxDecoration(
                color: warm,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [BoxShadow(color: warm, blurRadius: 10)],
              ),
            );

            final sub = Opacity(
              opacity: st,
              child: Transform.translate(
                offset: Offset(0, (1 - st) * 14),
                child: Text(subtitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: offering ? FontWeight.w800 : FontWeight.w500,
                      letterSpacing: 1,
                      color: offering ? Colors.amberAccent : Colors.white70,
                      shadows: shadows,
                    )),
              ),
            );

            final leavesChip = Opacity(
              opacity: lvT,
              child: Transform.translate(
                offset: Offset(0, (1 - lvT) * 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.eco,
                        size: 22,
                        color: widget.dark
                            ? Colors.blueGrey
                            : Colors.greenAccent),
                    const SizedBox(width: 6),
                    Text('$shownLeaves daun',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: shadows,
                        )),
                  ],
                ),
              ),
            );

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
                      Icon(Icons.gavel, size: 16, color: warm),
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

            final content = Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      label,
                      number,
                      const SizedBox(height: 8),
                      line,
                      const SizedBox(height: 12),
                      sub,
                      const SizedBox(height: 14),
                      leavesChip,
                      if (widget.verdict != null) ...[
                        const SizedBox(height: 14),
                        verdictBox,
                      ],
                    ],
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
                          Color.lerp(_night,
                              Color.lerp(_cool, warm, 0.5)!, sky)!,
                        ],
                      ),
                    ),
                  ),
                  // bintang, matahari terbit, sinar
                  CustomPaint(
                    painter: _SkyPainter(t: t, warm: warm, seed: widget.day),
                  ),
                  // lanskap Hayu sesuai jumlah daun
                  Opacity(
                    opacity: reveal * 0.82,
                    child: Backdrop(
                      path: landscapePath(widget.leaves),
                      dark: widget.dark,
                      dim: 0.5,
                    ),
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
                  // cincin kejut + percikan saat angka mendarat
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

/// Bintang berkelip yang memudar, matahari terbit, dan sinar yang berputar.
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
      for (var i = 0; i < 46; i++) {
        final x = rnd.nextDouble() * w;
        final y = rnd.nextDouble() * h * 0.65;
        final r = 0.8 + rnd.nextDouble() * 1.8;
        final ph = rnd.nextDouble() * 2 * pi;
        final tw = 0.55 + 0.45 * sin(t * 14 + ph);
        canvas.drawCircle(
          Offset(x, y),
          r,
          Paint()
            ..color = Colors.white
                .withValues(alpha: (starFade * tw).clamp(0.0, 1.0).toDouble()),
        );
      }
    }

    // matahari
    final sunT = Curves.easeOutCubic.transform(_seg(t, 0, 0.6));
    final r = min(w, h) * 0.14;
    final c = Offset(w * 0.5, h * (1.1 - 0.5 * sunT));

    canvas.drawCircle(
      c,
      r * 5,
      Paint()
        ..shader = RadialGradient(colors: [
          warm.withValues(alpha: 0.6 * sunT),
          warm.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: c, radius: r * 5)),
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

/// Cincin kejut dan percikan yang meledak saat angka hari mendarat (t = 0.5).
class _RingPainter extends CustomPainter {
  final double t;
  final Color warm;
  final int seed;
  _RingPainter({required this.t, required this.warm, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final s = _seg(t, 0.5, 0.85);
    if (s <= 0 || s >= 1) return;
    final c = Offset(size.width / 2, size.height * 0.46);
    final e = Curves.easeOutCubic.transform(s);

    for (var ring = 0; ring < 2; ring++) {
      final rs = ((s - ring * 0.12) / (1 - ring * 0.12)).clamp(0.0, 1.0);
      if (rs <= 0) continue;
      final re = Curves.easeOutCubic.transform(rs.toDouble());
      canvas.drawCircle(
        c,
        30 + 360 * re,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (7 * (1 - rs)).clamp(0.5, 7.0).toDouble()
          ..color = Color.lerp(warm, Colors.white, ring * 0.6)!
              .withValues(alpha: (1 - rs).clamp(0.0, 1.0).toDouble()),
      );
    }

    final rnd = Random(seed * 31 + 3);
    final streak = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    for (var k = 0; k < 18; k++) {
      final ang = rnd.nextDouble() * 2 * pi;
      final dist = 90 + rnd.nextDouble() * 220;
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