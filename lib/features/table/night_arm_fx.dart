import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../common/ornate.dart';
import 'card_tile.dart';

double _seg(double v, double a, double b) =>
    ((v - a) / (b - a)).clamp(0.0, 1.0).toDouble();

double _smooth(double x) => x * x * (3 - 2 * x);

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _rnd(int i, int k) {
  final v = math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
  return v - v.floorToDouble();
}

const _smokeGrey = Color(0xFF7C7391);

/// Overlay di dalam dialog serangan malam: begitu kartu disiapkan, kartunya
/// memudar dan berubah jadi asap ungu yang naik, lalu ikon bulan muncul dari
/// asap itu dan berdenyut (dengan riak cincin) sebagai tanda "siap malam ini".
/// Selesai sendiri; ketuk untuk melewati.
///
///  0.00-0.08  latar gelap menutup isi dialog; kartu tampil dengan pendar
///  0.12-0.60  kartu dikaburkan, diwarnai ungu, naik, dan memudar; asap
///             mengepul dari seluruh permukaannya
///  0.45-0.65  bulan membesar dari asap
///  0.62-0.74  teks "Disiapkan untuk malam ini"
///  0.68 / 0.80 / 0.92  tiga denyut bulan + cincin riak (haptic ringan)
class NightArmOverlay extends StatefulWidget {
  final Map<String, dynamic>? def;
  final VoidCallback onDone;

  const NightArmOverlay({super.key, required this.def, required this.onDone});

  @override
  State<NightArmOverlay> createState() => _NightArmOverlayState();
}

class _NightArmOverlayState extends State<NightArmOverlay>
    with SingleTickerProviderStateMixin {
  static const _totalMs = 2300;
  static const _pulses = [0.68, 0.80, 0.92];
  static const _cardW = 112.0;
  static const _stage = Size(240, 230);

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
    if (t >= 0.12 && _fired.add(0)) HapticFeedback.lightImpact();
    if (t >= 0.45 && _fired.add(1)) HapticFeedback.mediumImpact();
    for (var i = 0; i < _pulses.length; i++) {
      if (t >= _pulses[i] && _fired.add(10 + i)) {
        HapticFeedback.selectionClick();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => _body(_c.value),
      ),
    );
  }

  Widget _body(double t) {
    double pulse(double at) => t < at ? 0.0 : math.exp(-(t - at) / 0.05 * 5);
    final beat = math.min(
        1.2, _pulses.map(pulse).reduce((a, b) => a + b).toDouble());

    final dis = _smooth(_seg(t, 0.12, 0.60));
    final cardH = _cardW * 9 / 7;
    final moonIn = _seg(t, 0.45, 0.65);
    final moonScale = _lerp(0.4, 1.0, Curves.easeOutBack.transform(moonIn)) *
        (1 + 0.18 * beat);

    final card = IgnorePointer(
      child: CardTile(
        def: widget.def,
        fallbackName: '',
        width: _cardW,
      ),
    );

    Widget cardLayer = ColorFiltered(
      colorFilter: ColorFilter.mode(
          EmbunColors.mist.withValues(alpha: 0.55 * dis), BlendMode.srcATop),
      child: card,
    );
    if (dis > 0.02) {
      final sigma = 9 * dis;
      cardLayer = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: cardLayer,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0714)
            .withValues(alpha: 0.9 * _smooth(_seg(t, 0.0, 0.08))),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: _stage.width,
              height: _stage.height,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Pendar ungu di belakang.
                  Opacity(
                    opacity: 0.55 *
                        _smooth(_seg(t, 0.0, 0.12)) *
                        (1 - 0.4 * _smooth(_seg(t, 0.6, 1.0))),
                    child: Container(
                      width: _stage.width,
                      height: _stage.height,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            EmbunColors.mist.withValues(alpha: 0.45),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Kartu: terangkat, kabur, memudar.
                  Opacity(
                    opacity: (1 - _smooth(_seg(dis, 0.35, 1.0))) *
                        _smooth(_seg(t, 0.0, 0.08)),
                    child: Transform.translate(
                      offset: Offset(0, -cardH * 0.08 * dis),
                      child: Transform.scale(
                        scale: 1 + 0.08 * dis,
                        child: cardLayer,
                      ),
                    ),
                  ),
                  // Asap.
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _SmokePainter(
                          t: t, cardW: _cardW, cardH: cardH),
                      size: _stage,
                    ),
                  ),
                  // Cincin riak tiap denyut.
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _RipplePainter(t: t, starts: _pulses),
                      size: _stage,
                    ),
                  ),
                  // Bulan dari asap.
                  Opacity(
                    opacity: _smooth(moonIn),
                    child: Transform.scale(
                      scale: moonScale,
                      child: Icon(
                        Icons.nightlight_round,
                        size: 68,
                        color: EmbunColors.mist,
                        shadows: [
                          Shadow(
                              color: EmbunColors.mist
                                  .withValues(alpha: 0.6 + 0.3 * beat),
                              blurRadius: 22 + 18 * beat),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Opacity(
              opacity: _smooth(_seg(t, 0.62, 0.74)),
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - _smooth(_seg(t, 0.62, 0.74)))),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Disiapkan untuk malam ini',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: EmbunColors.mist,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.def?['name'] ?? ''}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12.5, color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gumpalan asap lembut yang lahir dari permukaan kartu, naik, melebar, lalu
/// menghilang.
class _SmokePainter extends CustomPainter {
  final double t;
  final double cardW, cardH;
  const _SmokePainter(
      {required this.t, required this.cardW, required this.cardH});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final paint = Paint();
    for (var i = 0; i < 20; i++) {
      final d = 0.10 + 0.35 * _rnd(i, 1);
      final u = _seg(t, d, d + 0.42);
      if (u <= 0 || u >= 1) continue;
      final start = c +
          Offset((_rnd(i, 2) - 0.5) * cardW * 0.9,
              (_rnd(i, 3) - 0.5) * cardH * 0.8);
      final pos = start +
          Offset(math.sin(u * 3 + i) * cardW * 0.18,
              -u * cardH * (0.45 + 0.6 * _rnd(i, 4)));
      final r = cardW * (0.14 + 0.26 * u) * (0.7 + 0.7 * _rnd(i, 5));
      final a = math.sin(u * math.pi) * 0.55;
      final col = i.isEven ? EmbunColors.mist : _smokeGrey;
      paint.shader = RadialGradient(
        colors: [col.withValues(alpha: a), col.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: pos, radius: r));
      canvas.drawCircle(pos, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SmokePainter old) => old.t != t;
}

/// Cincin yang melebar dari bulan pada setiap denyut.
class _RipplePainter extends CustomPainter {
  final double t;
  final List<double> starts;
  const _RipplePainter({required this.t, required this.starts});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (final s in starts) {
      final u = _seg(t, s, s + 0.14);
      if (u <= 0 || u >= 1) continue;
      final e = Curves.easeOutCubic.transform(u);
      canvas.drawCircle(
        c,
        _lerp(30, 88, e),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - u) + 0.8
          ..color = EmbunColors.mist.withValues(alpha: 0.7 * (1 - u)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter old) => old.t != t;
}

/// Ikon bulan serangan malam. Bila [armed], berdenyut seperti detak jantung
/// (dua denyut pendek) dengan pendar ungu dan cincin riak; bila tidak, diam.
class PulsingMoon extends StatefulWidget {
  final bool armed;
  final double size;
  final Color idleColor;

  const PulsingMoon({
    super.key,
    required this.armed,
    this.size = 26,
    this.idleColor = Colors.white70,
  });

  @override
  State<PulsingMoon> createState() => _PulsingMoonState();
}

class _PulsingMoonState extends State<PulsingMoon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void initState() {
    super.initState();
    if (widget.armed) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant PulsingMoon old) {
    super.didUpdateWidget(old);
    if (widget.armed == old.armed) return;
    if (widget.armed) {
      _c.repeat();
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static double _f(double x) => x < 0 ? 0.0 : math.exp(-x * 16);

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    if (!widget.armed) {
      return Icon(Icons.nightlight_round, size: s, color: widget.idleColor);
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final u = _c.value;
        final beat = math.min(1.0, _f(u) + 0.7 * _f(u - 0.22));
        final ring = _seg(u, 0.0, 0.6);
        return SizedBox(
          width: s,
          height: s,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (ring > 0 && ring < 1)
                CustomPaint(
                  painter: _MoonRingPainter(p: ring, size: s),
                  size: Size(s, s),
                ),
              Transform.scale(
                scale: 1 + 0.16 * beat,
                child: Icon(
                  Icons.nightlight_round,
                  size: s,
                  color: EmbunColors.mist,
                  shadows: [
                    Shadow(
                        color: EmbunColors.mist
                            .withValues(alpha: 0.45 + 0.4 * beat),
                        blurRadius: 8 + 12 * beat),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MoonRingPainter extends CustomPainter {
  final double p;
  final double size;
  const _MoonRingPainter({required this.p, required this.size});

  @override
  void paint(Canvas canvas, Size s) {
    final e = Curves.easeOutCubic.transform(p);
    canvas.drawCircle(
      s.center(Offset.zero),
      _lerp(size * 0.5, size * 1.25, e),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * (1 - p) + 0.6
        ..color = EmbunColors.mist.withValues(alpha: 0.55 * (1 - p)),
    );
  }

  @override
  bool shouldRepaint(covariant _MoonRingPainter old) => old.p != p;
}