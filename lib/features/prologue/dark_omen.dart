import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/fx_shaders.dart';
import '../common/ornate.dart';
import '../common/sfx.dart';

double _seg(double v, double a, double b) =>
    ((v - a) / (b - a)).clamp(0.0, 1.0).toDouble();

double _smooth(double x) => x * x * (3 - 2 * x);

double _rnd(int i, int k) {
  final v = math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
  return v - v.floorToDouble();
}

/// Gambar latar peringatan, dicari berurutan dari assets/bentang. Taruh aset
/// awan gelap di urutan pertama (nama berkas tanpa ekstensi); bila belum ada,
/// jatuh ke langit malam yang sudah tersedia.
const _omenScenery = [
  'langit-matamerahgelap',
  'awan-gelap',
  'awangelap',
  'awan-gelapdramatis',
  'langit-malammerahungugelap',
  'langit-malamberawan',
];

/// Peringatan dramatis untuk pemain yang terpilih menjadi Si Terbisik.
/// Awan gelap bergulung (shader: menyala dari dalam tiap kali petir
/// menyambar), tiga sambaran petir (getar haptic berat), lalu
/// "SI TERBISIK" menghantam layar. Tombol muncul di akhir; [onContinue]
/// dipanggil saat ditekan. Tampil HANYA di layar Si Terbisik.
class DarkOmen extends StatefulWidget {
  final VoidCallback onContinue;
  const DarkOmen({super.key, required this.onContinue});

  @override
  State<DarkOmen> createState() => _DarkOmenState();
}

class _DarkOmenState extends State<DarkOmen> with TickerProviderStateMixin {
  static const _ms = 7000;
  static const _bolts = [0.20, 0.36, 0.52];

  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: _ms));
  late final AnimationController _loop = AnimationController(
      vsync: this, duration: const Duration(seconds: 120))
    ..repeat();
  final Set<int> _fired = {};
  late final String? _bg = firstScenery(_omenScenery);

  /// Shader awan bercahaya petir; null = awan gradasi lama.
  ui.FragmentShader? _sky;

  @override
  void initState() {
    super.initState();
    _sky = FxShaders.make(FxShaders.omenSky);
    _c.addListener(_tick);
    _c.forward();
    // Musik prolog diredam selama peringatan; angin bergulung bersama awan.
    Sfx.I.setDuck(this, true);
    Sfx.I.playAny(Snd.winds, owner: this, tag: 'wind');
  }

  @override
  void dispose() {
    _c.dispose();
    _loop.dispose();
    _sky?.dispose();
    Sfx.I.release(this);
    super.dispose();
  }

  void _tick() {
    final t = _c.value;
    for (var i = 0; i < _bolts.length; i++) {
      if (t >= _bolts[i] && _fired.add(i)) {
        HapticFeedback.heavyImpact();
        // Petir pertama dan terakhir; yang terakhir memulai ulang gemuruhnya.
        if (i == 0 || i == _bolts.length - 1) {
          Sfx.I.play(Snd.thunder, owner: this, tag: 'thunder', replace: true);
        }
      }
    }
    if (t >= 0.46 && _fired.add(10)) {
      HapticFeedback.heavyImpact();
      Future.delayed(
          const Duration(milliseconds: 160), HapticFeedback.mediumImpact);
    }
  }

  double _bump(double t, double c, double w) =>
      math.max(0.0, 1 - (t - c).abs() / w);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: AnimatedBuilder(
        animation: Listenable.merge([_c, _loop]),
        builder: (context, _) {
          final t = _c.value;
          final sec = _loop.value * 120;

          var flash = 0.0;
          for (final b in _bolts) {
            flash += _bump(t, b, 0.025) * 0.55;
          }
          final sh = 8 * _bump(t, 0.36, 0.04) +
              10 * _bump(t, 0.47, 0.05) +
              6 * _bump(t, 0.52, 0.03);
          final shake = Offset(math.sin(sec * 95) * sh, math.cos(sec * 81) * sh * 0.7);

          final slamT = _seg(t, 0.40, 0.54);
          final slam = Curves.easeOutBack.transform(slamT);
          final l1 = _smooth(_seg(t, 0.14, 0.26));
          final l2 = _smooth(_seg(t, 0.38, 0.46));
          final l3 = _smooth(_seg(t, 0.62, 0.74));
          final btn = _smooth(_seg(t, 0.80, 0.92));

          Widget content = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: l1,
                child: const Text(
                  'SEBUAH BISIKAN DARI KABUT',
                  style: TextStyle(
                      fontSize: 12.5,
                      letterSpacing: 6,
                      fontWeight: FontWeight.bold,
                      color: Colors.white60),
                ),
              ),
              const SizedBox(height: 18),
              Opacity(
                opacity: l2,
                child: const Text(
                  'KAMU TERPILIH SEBAGAI',
                  style: TextStyle(
                      fontSize: 16,
                      letterSpacing: 5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70),
                ),
              ),
              const SizedBox(height: 6),
              Opacity(
                opacity: _seg(slamT, 0, 0.3),
                child: Transform.scale(
                  scale: 2.6 - 1.6 * slam.clamp(0.0, 1.2),
                  child: Text(
                    'SI TERBISIK',
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 10 - 6 * _smooth(slamT),
                      color: EmbunColors.mist,
                      shadows: [
                        Shadow(
                            color: EmbunColors.mist.withValues(alpha: 0.9),
                            blurRadius: 30),
                        const Shadow(color: Colors.black, blurRadius: 8),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: 200 * _smooth(_seg(t, 0.50, 0.62)),
                height: 2,
                decoration: BoxDecoration(
                  color: EmbunColors.mist,
                  boxShadow: [
                    BoxShadow(
                        color: EmbunColors.mist.withValues(alpha: 0.8),
                        blurRadius: 12),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Opacity(
                opacity: l3,
                child: Transform.translate(
                  offset: Offset(0, (1 - l3) * 12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: const Text(
                      'Kabut menitipkan sebutir benih hitam di dadamu. '
                          'Hanya kamu yang tahu. Pilihlah wajah gelapmu, lalu '
                          'bersembunyilah di balik kartu warga.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13.5, height: 1.45, color: Colors.white70),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Opacity(
                opacity: btn,
                child: IgnorePointer(
                  ignoring: btn < 0.9,
                  child: EmbunButton(
                    label: 'Terima bisikan kabut',
                    icon: 'bulirhitam',
                    onPressed: widget.onContinue,
                  ),
                ),
              ),
            ],
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              Transform.translate(
                offset: shake,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Opacity(
                      opacity: _smooth(_seg(t, 0.0, 0.2)),
                      child: Transform.scale(
                        scale: 1.0 + 0.2 * t,
                        child: Backdrop(path: _bg, dark: true, dim: 0.45),
                      ),
                    ),
                    IgnorePointer(
                      child: CustomPaint(
                        painter: _OmenPainter(t: t, time: sec, shader: _sky),
                        size: Size.infinite,
                      ),
                    ),
                  ],
                ),
              ),
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.95,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.85),
                      ],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Transform.translate(
                  offset: shake * 1.3,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: content,
                      ),
                    ),
                  ),
                ),
              ),
              if (flash > 0.01)
                IgnorePointer(
                  child: ColoredBox(
                    color: Color.lerp(Colors.white, EmbunColors.mist, 0.3)!
                        .withValues(alpha: flash.clamp(0.0, 0.85).toDouble()),
                  ),
                ),
              // Masuk dari gelap total.
              IgnorePointer(
                child: ColoredBox(
                  color: Colors.black
                      .withValues(alpha: 1 - _smooth(_seg(t, 0.0, 0.12))),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Awan gelap yang bergulung makin pekat, ditambah tiga sambaran petir.
/// Dengan [shader], awan digambar volumetrik dan menyala dari dalam di
/// sekitar titik sambaran; tanpa shader dipakai gradasi lingkaran lama.
class _OmenPainter extends CustomPainter {
  final double t;
  final double time;
  final ui.FragmentShader? shader;
  const _OmenPainter({required this.t, required this.time, this.shader});

  /// Posisi mendatar awal sambaran [k]; harus sama dengan yang dipakai
  /// [_bolt] (Random berbenih sama, panggilan pertama).
  double _boltX(Size size, int k) =>
      size.width * (0.18 + 0.64 * math.Random(k * 97 + 5).nextDouble());

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final dens = _smooth(_seg(t, 0.0, 0.5));

    if (shader != null) {
      _sky(canvas, size, dens);
    } else {
      // awan (gradasi lama)
      final paint = Paint();
      for (var i = 0; i < 14; i++) {
        final dir = i.isEven ? 1.0 : -1.0;
        final x = ((_rnd(i, 1) + time * 0.012 * dir) % 1.4 - 0.2) * w;
        final y = h * (0.04 + 0.5 * _rnd(i, 2)) + math.sin(time * 0.3 + i) * 10;
        final r = math.max(w, h) * (0.18 + 0.2 * _rnd(i, 3));
        final col = switch (i % 3) {
          0 => const Color(0xFF05020A),
          1 => const Color(0xFF2A1745),
          _ => const Color(0xFF3A2358),
        };
        final a = ((0.30 + 0.4 * _rnd(i, 4)) * dens).clamp(0.0, 1.0).toDouble();
        paint.shader = RadialGradient(
          colors: [col.withValues(alpha: a), col.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: r));
        canvas.drawCircle(Offset(x, y), r, paint);
      }
    }

    // petir
    const times = _DarkOmenState._bolts;
    for (var k = 0; k < times.length; k++) {
      final u = (t - times[k]) / 0.08;
      if (u <= 0 || u >= 1) continue;
      final a = (1 - u).clamp(0.0, 1.0).toDouble();
      _bolt(canvas, size, k, a);
    }
  }

  /// Awan shader; cahaya tiap sambaran ikut menerangi awan di sekitarnya.
  void _sky(Canvas canvas, Size size, double dens) {
    final sh = shader!;
    sh
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time)
      ..setFloat(3, dens);
    const times = _DarkOmenState._bolts;
    for (var k = 0; k < times.length; k++) {
      final u = (t - times[k]) / 0.08;
      final a = (u <= 0 || u >= 1) ? 0.0 : (1 - u) * 1.2;
      sh
        ..setFloat(4 + 3 * k, _boltX(size, k))
        ..setFloat(5 + 3 * k, size.height * 0.22)
        ..setFloat(6 + 3 * k, a);
    }
    canvas.drawRect(Offset.zero & size, Paint()..shader = sh);
  }

  void _bolt(Canvas canvas, Size size, int k, double a) {
    final rnd = math.Random(k * 97 + 5);
    var x = size.width * (0.18 + 0.64 * rnd.nextDouble());
    var y = 0.0;
    final path = Path()..moveTo(x, y);
    const steps = 10;
    final len = size.height * (0.5 + 0.2 * rnd.nextDouble());
    for (var i = 0; i < steps; i++) {
      x += (rnd.nextDouble() - 0.5) * size.width * 0.12;
      y += len / steps;
      path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..color = const Color(0xFFB07CE8).withValues(alpha: 0.75 * a),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFF1E6FF).withValues(alpha: a),
    );
  }

  @override
  bool shouldRepaint(covariant _OmenPainter old) => true;
}