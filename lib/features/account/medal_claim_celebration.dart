import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/profile_medals.dart';
import '../common/ornate.dart';

class MedalClaimCelebration extends StatefulWidget {
  const MedalClaimCelebration({
    super.key,
    required this.medal,
    required this.art,
  });
  final ProfileMedal medal;
  final Widget art;
  @override
  State<MedalClaimCelebration> createState() => _MedalClaimCelebrationState();
}

class _MedalClaimCelebrationState extends State<MedalClaimCelebration>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = 1;
    } else {
      _animation.forward();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    key: const ValueKey('medal-claim-celebration'),
    backgroundColor: const Color(0xFF10251D),
    insetPadding: const EdgeInsets.all(18),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              liveRegion: true,
              child: const Text(
                'Medali baru diraih!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: EmbunColors.gold,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 10),
            AnimatedBuilder(
              animation: _animation,
              child: widget.art,
              builder: (context, child) {
                final t = _animation.value;
                final appear = Curves.easeOutBack.transform(
                  (t / .55).clamp(0, 1),
                );
                return SizedBox(
                  height: 240,
                  width: 280,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: _MedalGlow(t)),
                      ),
                      Transform.scale(
                        scale: .25 + .75 * appear,
                        child: Opacity(
                          opacity: (t / .2).clamp(0, 1),
                          child: child,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Text(
              widget.medal.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: EmbunColors.gold,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.medal.series.requirement(widget.medal.target),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Sudah ditambahkan ke koleksimu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey('close-medal-celebration'),
              onPressed: () => Navigator.pop(context),
              child: const Text('Lanjutkan'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MedalGlow extends CustomPainter {
  const _MedalGlow(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * .49;
    final strength = (.35 + .3 * math.sin(t * math.pi)).clamp(0.0, 1.0);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            EmbunColors.gold.withValues(alpha: strength),
            const Color(0xFF79C48F).withValues(alpha: strength * .25),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6 + t * .4;
      final inner = Offset(math.cos(angle), math.sin(angle)) * (radius * .5);
      final outer = Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawLine(
        center + inner,
        center + outer,
        Paint()
          ..color = EmbunColors.gold.withValues(alpha: .10 + .12 * (1 - t))
          ..strokeWidth = 3,
      );
    }
    for (var i = 0; i < 28; i++) {
      final angle = i * 2.39996;
      final spread = (.35 + .65 * Curves.easeOut.transform(t));
      final distance = radius * (.5 + (i % 7) / 13) * spread;
      final point =
          center + Offset(math.cos(angle), math.sin(angle)) * distance;
      final shimmer = (.35 + .65 * math.sin(t * 9 + i).abs());
      final paint = Paint()
        ..color = (i.isEven ? EmbunColors.gold : Colors.white).withValues(
          alpha: shimmer * (.7 - .3 * t),
        );
      final r = 1.5 + (i % 3);
      canvas.drawLine(
        point - Offset(r, 0),
        point + Offset(r, 0),
        paint..strokeWidth = 1.2,
      );
      canvas.drawLine(point - Offset(0, r), point + Offset(0, r), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MedalGlow oldDelegate) => oldDelegate.t != t;
}
