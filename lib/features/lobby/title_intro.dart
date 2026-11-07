import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';

double _seg(double v, double a, double b) =>
    ((v - a) / (b - a)).clamp(0.0, 1.0).toDouble();
double _smooth(double x) => x * x * (3 - 2 * x);

/// Latar layar judul yang bercerita: Hayu mulai dari kering dan hancur
/// (pohon9), lalu daunnya kembali tahap demi tahap sampai rimbun (pohon0)
/// diiringi kamera yang menjauh, cahaya yang meledak naik, dan hujan daun.
/// Di awal, bayangan Si Terbisik samar mengintai dan pita sinema menutup
/// layar; semuanya sirna saat Hayu pulih.
///
/// [progress] 0..1 adalah naskah pembukaan (dikendalikan induk, supaya logo
/// dan tombol bisa muncul pada waktunya). [clock] adalah jam berkelanjutan
/// untuk gerak latar setelah pembukaan selesai.
class TitleIntroBackdrop extends StatelessWidget {
  final Animation<double> progress;
  final Animation<double> clock;
  const TitleIntroBackdrop(
      {super.key, required this.progress, required this.clock});

  static const _stages = [
    'pohon9',
    'pohon8',
    'pohon6',
    'pohon4',
    'pohon2',
    'pohon0'
  ];

  List<String> get _paths => [
    for (final s in _stages)
      if (AssetCatalog.I.file(pohonDir, s) != null)
        AssetCatalog.I.file(pohonDir, s)!
  ];

  @override
  Widget build(BuildContext context) {
    final paths = _paths;
    final ghosts = wrathGhostPaths();
    return AnimatedBuilder(
      animation: Listenable.merge([progress, clock]),
      builder: (context, _) {
        final p = progress.value;
        final time = clock.value * 120;
        // Tahap pohon: lambat di awal, lalu mengalir.
        final tp = _smooth(_seg(p, 0.04, 0.70));
        final last = paths.isEmpty ? 0 : paths.length - 1;
        final pos = tp * last;
        final lo = pos.floor().clamp(0, last).toInt();
        final hi = (lo + 1).clamp(0, last).toInt();
        final fr = _smooth((pos - lo).clamp(0.0, 1.0).toDouble());

        // Kamera menjauh dari batang, lalu bernapas pelan.
        final pull = 1 - Curves.easeOutCubic.transform(_seg(p, 0.0, 0.92));
        final breath = 0.012 * sin(time * 0.5);
        final scale = 1.08 + 0.30 * pull + breath;
        final align = Alignment(0.0, 0.32 * pull);

        final sat = 0.22 + 0.78 * _smooth(_seg(p, 0.05, 0.78));
        final dark = 0.72 * (1 - _smooth(_seg(p, 0.0, 0.8))) + 0.14;
        final glowBurst = _burst(p);

        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF040807)),
            ColorFiltered(
              colorFilter: ColorFilter.matrix(_saturation(sat)),
              child: Transform.scale(
                scale: scale,
                alignment: align,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (paths.isNotEmpty)
                      GameImage(path: paths[lo], cacheWidth: 1280),
                    if (paths.isNotEmpty && hi != lo)
                      Opacity(
                        opacity: fr,
                        child: GameImage(path: paths[hi], cacheWidth: 1280),
                      ),
                  ],
                ),
              ),
            ),
            // dingin di awal, hangat di akhir
            ColoredBox(
              color: Color.lerp(const Color(0xFF0A1424),
                  const Color(0xFF3A2A08), _smooth(_seg(p, 0.3, 1.0)))!
                  .withValues(alpha: 0.30 * (1 - tp) + 0.05),
            ),
            if (ghosts.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: (1 - _seg(p, 0.0, 0.55)).clamp(0.0, 1.0),
                    child: Apparition(paths: ghosts, peak: 0.5),
                  ),
                ),
              ),
            IgnorePointer(
              child: CustomPaint(
                painter: _IntroFx(p: p, time: time, burst: glowBurst, tp: tp),
              ),
            ),
            ColoredBox(
                color: Colors.black.withValues(alpha: dark.clamp(0.0, 1.0))),
            // vinyet
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 1.0,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55 + 0.25 * (1 - tp)),
                    ],
                    stops: const [0.42, 1.0],
                  ),
                ),
              ),
            ),
            // pita sinema
            LayoutBuilder(builder: (context, c) {
              final bar = c.maxHeight * 0.11 *
                  (1 - _smooth(_seg(p, 0.35, 0.95)));
              return Stack(children: [
                Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: bar,
                    child: const ColoredBox(color: Colors.black)),
                Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: bar,
                    child: const ColoredBox(color: Colors.black)),
              ]);
            }),
            // kilat putih lembut saat Hayu pulih
            if (glowBurst > 0.01)
              IgnorePointer(
                child: ColoredBox(
                  color: const Color(0xFFFFF1C0)
                      .withValues(alpha: 0.28 * glowBurst),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Puncak cahaya singkat di sekitar p = 0.72.
  static double _burst(double p) {
    final up = _smooth(_seg(p, 0.64, 0.74));
    final down = 1 - _smooth(_seg(p, 0.74, 0.92));
    return (up * down).clamp(0.0, 1.0).toDouble();
  }

  static List<double> _saturation(double s) {
    const r = 0.2126, g = 0.7152, b = 0.0722;
    final i = 1 - s;
    return [
      r * i + s, g * i, b * i, 0, 0, //
      r * i, g * i + s, b * i, 0, 0, //
      r * i, g * i, b * i + s, 0, 0, //
      0, 0, 0, 1, 0,
    ];
  }
}

/// Berkas cahaya, abu yang jatuh (awal) berganti daun dan embun (akhir).
class _IntroFx extends CustomPainter {
  final double p;
  final double time;
  final double burst;
  final double tp;
  const _IntroFx(
      {required this.p,
        required this.time,
        required this.burst,
        required this.tp});

  static double _r(int i, int k) {
    final v = sin(i * 12.9898 + k * 78.233) * 43758.5453;
    return v - v.floor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final c = Offset(w * 0.5, h * 0.40);

    // sinar menyebar dari tajuk pohon
    final rayA = (_smooth(_seg(p, 0.62, 0.86)) * 0.20 + burst * 0.25);
    if (rayA > 0.01) {
      for (var i = 0; i < 14; i++) {
        final a = (i / 14) * 2 * pi + time * 0.02 + _r(i, 1);
        final half = 0.035 + 0.03 * _r(i, 2);
        final len = h * (0.8 + 0.5 * _r(i, 3));
        final path = Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + cos(a - half) * len, c.dy + sin(a - half) * len)
          ..lineTo(c.dx + cos(a + half) * len, c.dy + sin(a + half) * len)
          ..close();
        final tw = 0.6 + 0.4 * sin(time * 0.8 + i);
        canvas.drawPath(
          path,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = RadialGradient(colors: [
              const Color(0xFFFFE9A8).withValues(alpha: rayA * tw),
              const Color(0xFFFFE9A8).withValues(alpha: 0),
            ]).createShader(Rect.fromCircle(center: c, radius: len)),
        );
      }
    }

    // butiran melayang: abu pucat di awal, daun dan embun di akhir
    const n = 54;
    for (var i = 0; i < n; i++) {
      final spd = 0.025 + 0.05 * _r(i, 4);
      final x0 = _r(i, 5);
      final yy = ((time * spd + _r(i, 6)) % 1.0);
      final sway = sin(time * (0.4 + _r(i, 7)) + i) * 0.03;
      final pos = Offset((x0 + sway) * w, yy * (h + 20) - 10);
      final size0 = 1.2 + 2.6 * _r(i, 8);
      final ash = 1 - tp;
      final isLeaf = _r(i, 9) < 0.45;
      final col = Color.lerp(
        const Color(0xFFB9B4A8),
        isLeaf ? const Color(0xFF8FE39A) : const Color(0xFFFFF0B0),
        _smooth(tp),
      )!;
      final a = ((0.25 + 0.45 * _r(i, 10)) *
          (0.35 + 0.65 * (ash > 0.5 ? ash : _smooth(_seg(p, 0.45, 0.8))))) *
          (0.4 + 0.6 * _seg(p, 0.02, 0.2));
      if (a <= 0.01) continue;
      final paint = Paint()
        ..color = col.withValues(alpha: a.clamp(0.0, 1.0))
        ..maskFilter = size0 > 3 ? const MaskFilter.blur(BlurStyle.normal, 1.5) : null;
      if (isLeaf && tp > 0.4) {
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(time * (0.5 + _r(i, 11)) + i);
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset.zero, width: size0 * 3.2, height: size0 * 1.5),
            paint);
        canvas.restore();
      } else {
        canvas.drawCircle(pos, size0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IntroFx old) => true;
}