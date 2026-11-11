import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Cahaya penutup yang memakai kanvas dan mengikuti pengaturan gerak pengguna.
class EndgameAura extends StatelessWidget {
  const EndgameAura({
    super.key,
    required this.color,
    required this.time,
    this.progress = 1,
    this.intensity = 1,
  });

  final Color color;
  final double time;
  final double progress;
  final double intensity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _AuraPainter(color, time, progress, intensity),
        size: Size.infinite,
      ),
    ),
  );
}

class _AuraPainter extends CustomPainter {
  const _AuraPainter(this.color, this.time, this.progress, this.intensity);

  final Color color;
  final double time;
  final double progress;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.4);
    final radius = math.max(size.width, size.height) * 0.64;
    final strength =
        Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0)) * intensity;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.18 * strength),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.sin(time * 0.035) * 0.10);
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      final spread = 0.045 + math.sin(i * 7.1).abs() * 0.04;
      final beam = Path()
        ..moveTo(0, 0)
        ..lineTo(
          math.cos(angle - spread) * radius,
          math.sin(angle - spread) * radius,
        )
        ..lineTo(
          math.cos(angle + spread) * radius,
          math.sin(angle + spread) * radius,
        )
        ..close();
      canvas.drawPath(
        beam,
        Paint()..color = color.withValues(alpha: 0.024 * strength),
      );
    }
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (var i = 0; i < 3; i++) {
      final pulse = (time * 0.035 + i / 3) % 1;
      canvas.drawCircle(
        Offset.zero,
        radius * (0.12 + pulse * 0.40),
        ring..color = color.withValues(alpha: (1 - pulse) * 0.14 * strength),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AuraPainter old) =>
      old.time != time ||
      old.color != color ||
      old.progress != progress ||
      old.intensity != intensity;
}
