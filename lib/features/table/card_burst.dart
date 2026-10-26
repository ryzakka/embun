import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'card_tile.dart' show CardBack;

/// Adegan persembahan: kartu-kartu dilempar ke Hayu.
///
/// Garis waktu (ms, total 2900):
///    0-220   kartu terkipas di bawah, bergetar menyimpan tenaga
///  220-...   tiap kartu dilempar bergantian (jeda 120 ms) menyusur
///            lengkung, berputar cepat, meninggalkan jejak bayangan
///  +720      kartu mendarat: cincin kejut, percikan, getar haptic
///            (kartu terakhir paling keras: kilatan + aura)
///  setelah   aura Hayu berdenyut, serpihan berhamburan
///
/// Menyesuaikan suasana permainan:
///  - [dark] (Si Terbisik yang tidak sedang menyamar): palet ungu kelam,
///    kabut menyedot ke pohon, serpihan bulir hitam, getar haptic ganda.
///    Pakai `showAsAntag` dari TablePage, jadi Mode Samaran ikut dihormati.
///  - [leaves] (kesehatan Hayu, 0-30): makin sedikit daun, makin redup aura,
///    makin sedikit partikel, dan daun yang jatuh makin kecokelatan.
///  - 30 daun (sakura): kelopak merah muda, bukan daun hijau.
class CardBurst extends StatefulWidget {
  final int count;
  final VoidCallback onDone;
  final bool dark;
  final int leaves;
  const CardBurst({
    super.key,
    required this.count,
    required this.onDone,
    this.dark = false,
    this.leaves = 30,
  });
  @override
  State<CardBurst> createState() => _CardBurstState();
}

class _Palette {
  final Color glow, ringA, ringB, auraA, auraB, sparkA, sparkB, flash, dew;
  final double dim;
  const _Palette({
    required this.glow,
    required this.ringA,
    required this.ringB,
    required this.auraA,
    required this.auraB,
    required this.sparkA,
    required this.sparkB,
    required this.flash,
    required this.dew,
    required this.dim,
  });

  static const light = _Palette(
    glow: Color(0xFFFFD866),
    ringA: Color(0xFFFFE08A),
    ringB: Color(0xFF9DF0B8),
    auraA: Color(0xFFFFE9A0),
    auraB: Color(0xFF7FE0A0),
    sparkA: Color(0xFFFFE08A),
    sparkB: Color(0xFFBFF5D0),
    flash: Color(0xFFFFF6D6),
    dew: Color(0xFF7FD3F7),
    dim: 0.38,
  );

  static const dark = _Palette(
    glow: Color(0xFFB07CE8),
    ringA: Color(0xFFB07CE8),
    ringB: Color(0xFF6A3FA0),
    auraA: Color(0xFFD9B8FF),
    auraB: Color(0xFF5A2E8C),
    sparkA: Color(0xFFD9B8FF),
    sparkB: Color(0xFF8A5CC0),
    flash: Color(0xFFE6D6FF),
    dew: Color(0xFF8A74A8),
    dim: 0.55,
  );
}

class _CardBurstState extends State<CardBurst>
    with SingleTickerProviderStateMixin {
  static const _totalMs = 2900.0;
  static const _startMs = 220.0;
  static const _staggerMs = 120.0;
  static const _flightMs = 720.0;
  static const _cardW = 70.0, _cardH = 100.0;

  late final AnimationController c;
  final Set<int> _landed = {};
  final int _seed = Random().nextInt(1 << 20);

  _Palette get _pal => widget.dark ? _Palette.dark : _Palette.light;
  double get _vitality => (widget.leaves / 30).clamp(0.0, 1.0).toDouble();

  double _flightStart(int i) => _startMs + i * _staggerMs;
  double _landMs(int i) => _flightStart(i) + _flightMs;
  double get _lastLand => _landMs(widget.count - 1);

  @override
  void initState() {
    super.initState();
    HapticFeedback.selectionClick();
    c = AnimationController(
        vsync: this, duration: Duration(milliseconds: _totalMs.toInt()));
    c.addListener(_tick);
    c.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  void _tick() {
    final ms = c.value * _totalMs;
    for (var i = 0; i < widget.count; i++) {
      if (ms >= _landMs(i) && _landed.add(i)) {
        if (i == widget.count - 1) {
          HapticFeedback.heavyImpact();
          // peran gelap: dentum kedua yang berat; warga: yang lebih ringan
          Future.delayed(
              const Duration(milliseconds: 90),
              widget.dark
                  ? HapticFeedback.heavyImpact
                  : HapticFeedback.mediumImpact);
        } else {
          HapticFeedback.mediumImpact();
        }
      }
    }
  }

  @override
  void dispose() {
    c.removeListener(_tick);
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = _pal;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      final target = Offset(w * 0.5, h * 0.3);
      final n = widget.count;

      Offset start(int i) =>
          Offset(w * 0.5 + (i - (n - 1) / 2) * 76, h * 0.88);

      Offset bezier(int i, double e) {
        final p0 = start(i);
        final side = i.isEven ? -1.0 : 1.0;
        final ctrl = Offset(
            p0.dx + side * w * 0.32, (p0.dy + target.dy) / 2 - h * 0.18);
        final a = (1 - e) * (1 - e), b = 2 * (1 - e) * e, d = e * e;
        return Offset(a * p0.dx + b * ctrl.dx + d * target.dx,
            a * p0.dy + b * ctrl.dy + d * target.dy);
      }

      return AnimatedBuilder(
        animation: c,
        builder: (_, __) {
          final ms = c.value * _totalMs;
          final lastLand = _lastLand;

          final dim = ms < lastLand
              ? pal.dim * (ms / 300).clamp(0.0, 1.0)
              : pal.dim * (1 - (ms - lastLand) / 700).clamp(0.0, 1.0);
          // Kilatan lebih redup bila Hayu sudah lemah.
          final flashPeak = (widget.dark ? 0.4 : 0.55) * (0.6 + 0.4 * _vitality);
          final flash = (ms >= lastLand && ms < lastLand + 260)
              ? flashPeak * (1 - (ms - lastLand) / 260)
              : 0.0;

          final cards = <Widget>[];
          for (var i = 0; i < n; i++) {
            final dir = i.isEven ? -1.0 : 1.0;
            final fs = _flightStart(i);
            final u = ((ms - fs) / _flightMs).clamp(0.0, 1.0);
            if (ms >= _landMs(i)) continue;

            double ease(double v) => Curves.easeInCubic.transform(v);

            if (ms < fs) {
              final charge = (ms / fs).clamp(0.0, 1.0);
              final p = start(i);
              final jitter = sin(ms * 0.06 + i) * 3 * charge;
              cards.add(_card(
                pos: p + Offset(jitter, 8 * charge),
                angle: (i - (n - 1) / 2) * 0.18 + jitter * 0.01,
                scale: 1 + 0.12 * charge,
                glow: 0.2 + 0.6 * charge,
                color: pal.glow,
              ));
              continue;
            }

            for (var k = 5; k >= 1; k--) {
              final uk = u - k * 0.05;
              if (uk <= 0) continue;
              cards.add(_card(
                pos: bezier(i, ease(uk)),
                angle: uk * 2 * pi * 2.5 * dir,
                scale: 1 - 0.65 * ease(uk),
                glow: 0.4,
                color: pal.glow,
                opacity: (1 - k / 6) * 0.35,
              ));
            }

            final e = ease(u);
            cards.add(_card(
              pos: bezier(i, e),
              angle: u * 2 * pi * 2.5 * dir + (1 - u) * 0.3 * dir,
              scale: (1 + 0.25 * sin(u * pi).clamp(0.0, 1.0)) * (1 - 0.65 * e),
              glow: 0.5 + 0.5 * u,
              color: pal.glow,
            ));
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: Colors.black.withValues(alpha: dim)),
              CustomPaint(
                painter: _ImpactPainter(
                  ms: ms,
                  count: n,
                  target: target,
                  seed: _seed,
                  landMs: [for (var i = 0; i < n; i++) _landMs(i)],
                  pal: pal,
                  dark: widget.dark,
                  vitality: _vitality,
                  sakura: widget.leaves >= 30,
                  flightStart: [for (var i = 0; i < n; i++) _flightStart(i)],
                  flightMs: _flightMs,
                ),
              ),
              ...cards,
              if (flash > 0.01)
                ColoredBox(
                    color: pal.flash
                        .withValues(alpha: flash.clamp(0.0, 1.0).toDouble())),
            ],
          );
        },
      );
    });
  }

  Widget _card({
    required Offset pos,
    required double angle,
    required double scale,
    required double glow,
    required Color color,
    double opacity = 1,
  }) {
    return Positioned(
      left: pos.dx - _cardW / 2,
      top: pos.dy - _cardH / 2,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: angle,
          child: Transform.scale(
            scale: scale.clamp(0.05, 3.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(
                        alpha: (0.7 * glow).clamp(0.0, 1.0).toDouble()),
                    blurRadius: 10 + 22 * glow,
                    spreadRadius: 1 + 3 * glow,
                  ),
                ],
              ),
              // Punggung kartu sama untuk semua kartu (identitas tidak bocor).
              child: const CardBack(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kabut/aura, cincin kejut, percikan, serta daun/kelopak/serpihan.
class _ImpactPainter extends CustomPainter {
  final double ms;
  final int count;
  final Offset target;
  final int seed;
  final List<double> landMs;
  final List<double> flightStart;
  final double flightMs;
  final _Palette pal;
  final bool dark;
  final double vitality;
  final bool sakura;
  _ImpactPainter({
    required this.ms,
    required this.count,
    required this.target,
    required this.seed,
    required this.landMs,
    required this.flightStart,
    required this.flightMs,
    required this.pal,
    required this.dark,
    required this.vitality,
    required this.sakura,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final last = landMs.last;

    // ---- peran gelap: kabut ungu tersedot ke pohon selagi kartu terbang ----
    if (dark && ms < last) {
      final prog = ((ms - flightStart.first) / (last - flightStart.first))
          .clamp(0.0, 1.0)
          .toDouble();
      final rnd = Random(seed + 77);
      for (var k = 0; k < 14; k++) {
        final ang = rnd.nextDouble() * 2 * pi;
        final r0 = 160 + rnd.nextDouble() * 160;
        final phase = rnd.nextDouble() * 0.4;
        final f = ((prog - phase) / (1 - phase)).clamp(0.0, 1.0).toDouble();
        final r = r0 * (1 - Curves.easeIn.transform(f));
        final p = target + Offset(cos(ang + f * 2.2), sin(ang + f * 2.2)) * r;
        canvas.drawCircle(
          p,
          10 + 14 * (1 - f),
          Paint()
            ..color = pal.auraB.withValues(
                alpha: (0.22 * sin(f * pi)).clamp(0.0, 1.0).toDouble())
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
    }

    // ---- aura Hayu: berdenyut setelah hantaman terakhir ----
    final aS = (ms - last) / 1500;
    if (aS > 0 && aS < 1) {
      final strength = 0.45 + 0.55 * vitality; // Hayu lemah = aura redup
      final r = (40 + 240 * Curves.easeOut.transform(aS)) * (0.7 + 0.3 * vitality);
      final pulse = 0.85 + 0.15 * sin(aS * 16);
      final a = (0.6 * strength * (1 - aS) * pulse).clamp(0.0, 1.0).toDouble();
      canvas.drawCircle(
        target,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            pal.auraA.withValues(alpha: a),
            pal.auraB.withValues(alpha: a * 0.5),
            pal.auraB.withValues(alpha: 0),
          ], stops: const [0, 0.45, 1])
              .createShader(Rect.fromCircle(center: target, radius: r)),
      );
    }

    // ---- tiap kartu mendarat: cincin kejut + percikan ----
    for (var i = 0; i < count; i++) {
      final s = (ms - landMs[i]) / 900;
      if (s <= 0 || s >= 1) continue;
      final strength = i == count - 1 ? 1.0 : 0.6;
      final e = Curves.easeOutCubic.transform(s);

      for (var ring = 0; ring < 2; ring++) {
        final rs = ((s - ring * 0.14) / (1 - ring * 0.14)).clamp(0.0, 1.0);
        if (rs <= 0) continue;
        final re = Curves.easeOutCubic.transform(rs);
        canvas.drawCircle(
          target,
          18 + 170 * strength * re,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = (7 * (1 - rs)).clamp(0.5, 7.0).toDouble()
            ..color = Color.lerp(pal.ringA, pal.ringB, ring.toDouble())!
                .withValues(alpha: (1 - rs).clamp(0.0, 1.0).toDouble()),
        );
      }

      final rnd = Random(seed + i * 977);
      final sparks = (6 + 12 * vitality).round() * (i == count - 1 ? 1 : 1);
      final streak = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3;
      for (var k = 0; k < sparks; k++) {
        final ang = rnd.nextDouble() * 2 * pi;
        final dist = (60 + rnd.nextDouble() * 150) * strength;
        final dir = Offset(cos(ang), sin(ang));
        final head = target + dir * (dist * e) + Offset(0, 40 * s * s);
        final tail = target + dir * (dist * max(0.0, e - 0.18));
        streak.color = (k.isEven ? pal.sparkA : pal.sparkB)
            .withValues(alpha: (1 - s).clamp(0.0, 1.0).toDouble());
        canvas.drawLine(tail, head, streak);
      }
    }

    // ---- serpihan berhamburan: daun / kelopak sakura / bulir hitam ----
    final ls = (ms - last - 100) / 1800;
    if (ls > 0 && ls < 1) {
      final rnd = Random(seed + 31337);
      final alpha = ls < 0.7 ? 1.0 : (1 - (ls - 0.7) / 0.3).clamp(0.0, 1.0);
      final total = (10 + 14 * vitality).round();
      const healthy = [
        Color(0xFF6FBF73),
        Color(0xFF8FE08F),
        Color(0xFF3E8E7E),
        Color(0xFFB9F08A),
      ];
      const petals = [
        Color(0xFFF7B6D2),
        Color(0xFFFFD3E4),
        Color(0xFFF08FB5),
      ];
      const wilted = Color(0xFF8A6A3A);
      for (var k = 0; k < total; k++) {
        final vx = (rnd.nextDouble() - 0.5) * 340;
        final vy = 120 + rnd.nextDouble() * 220;
        final spin = (rnd.nextDouble() - 0.5) * 12;
        final sz = 6 + rnd.nextDouble() * 7;
        final pick = rnd.nextInt(4);
        final dew = k % 4 == 3;
        final t = ls * 1.8;
        final p = target +
            Offset(vx * t * 0.7 + sin(t * 5 + k) * 10, -vy * t + 360 * t * t);

        if (dark) {
          if (dew) {
            // bulir hitam: titik gelap berpendar ungu
            canvas.drawCircle(p, sz * 0.5,
                Paint()..color = const Color(0xFF1B1030).withValues(alpha: alpha));
            canvas.drawCircle(
                p,
                sz * 0.5,
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.5
                  ..color = pal.glow.withValues(alpha: alpha * 0.9));
          } else {
            canvas.save();
            canvas.translate(p.dx, p.dy);
            canvas.rotate(spin * t);
            final shard = Path()
              ..moveTo(0, -sz)
              ..lineTo(sz * 0.55, 0)
              ..lineTo(0, sz * 1.3)
              ..lineTo(-sz * 0.55, 0)
              ..close();
            canvas.drawPath(shard,
                Paint()..color = const Color(0xFF2A1745).withValues(alpha: alpha));
            canvas.drawPath(
                shard,
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.2
                  ..color = pal.sparkA.withValues(alpha: alpha * 0.8));
            canvas.restore();
          }
          continue;
        }

        if (dew) {
          canvas.drawCircle(p, sz * 0.45,
              Paint()..color = pal.dew.withValues(alpha: alpha * 0.9));
          continue;
        }

        // warna: sakura > hijau sehat; makin lemah makin cokelat
        final base = sakura ? petals[pick % petals.length] : healthy[pick];
        final col = sakura
            ? base
            : Color.lerp(wilted, base, (vitality * 1.4).clamp(0.0, 1.0))!;
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(spin * t);
        final path = Path()
          ..moveTo(0, -sz)
          ..quadraticBezierTo(sz * 0.9, -sz * 0.2, 0, sz)
          ..quadraticBezierTo(-sz * 0.9, -sz * 0.2, 0, -sz);
        canvas.drawPath(path, Paint()..color = col.withValues(alpha: alpha));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ImpactPainter old) => old.ms != ms;
}