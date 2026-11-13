import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../common/art.dart';
import '../common/sfx.dart';

enum NightImpactEffect {
  bowHit,
  bowFinal,
  bowMiss,
  mirror,
  shield,
  guard,
  pump,
  burn,
  theft,
  clinicHeal,
  clinicTrap,
}

class NightImpact {
  final NightImpactEffect effect;
  final bool actor;
  final bool applied;
  final num? delta;
  final String? card;
  final String? targetName;

  const NightImpact._(
    this.effect, {
    required this.actor,
    required this.applied,
    this.delta,
    this.card,
    this.targetName,
  });

  static NightImpact? fromReport(Map<String, dynamic> report) {
    final data = report['impact'];
    if (report['kind'] != 'private' ||
        report['user_id'] == null ||
        data is! Map) {
      return null;
    }
    final effect = switch (data['effect']) {
      'bow_hit' => NightImpactEffect.bowHit,
      'bow_final' => NightImpactEffect.bowFinal,
      'bow_miss' => NightImpactEffect.bowMiss,
      'mirror' => NightImpactEffect.mirror,
      'shield' => NightImpactEffect.shield,
      'guard' => NightImpactEffect.guard,
      'pump' => NightImpactEffect.pump,
      'burn' => NightImpactEffect.burn,
      'theft' => NightImpactEffect.theft,
      'clinic_heal' => NightImpactEffect.clinicHeal,
      'clinic_trap' => NightImpactEffect.clinicTrap,
      _ => null,
    };
    if (effect == null ||
        (data['view'] != 'actor' &&
            data['view'] != 'target' &&
            !(effect == NightImpactEffect.guard &&
                data['view'] == 'guardian'))) {
      return null;
    }
    final delta = data['delta'];
    final card = data['card'];
    return NightImpact._(
      effect,
      actor: data['view'] == 'actor',
      applied: data['applied'] != false,
      delta: delta is num ? delta : null,
      card: card is String ? card : null,
      targetName: data['target_name'] is String
          ? data['target_name'] as String
          : null,
    );
  }

  String get title {
    if (!applied) {
      return switch (effect) {
        NightImpactEffect.pump => 'Tak ada embun tersedot',
        NightImpactEffect.burn ||
        NightImpactEffect.theft => 'Tak ada kartu hilang',
        _ => 'Tak ada dampak',
      };
    }
    return switch (effect) {
      NightImpactEffect.clinicHeal =>
        actor ? 'Perawatanmu berhasil' : 'Nyawamu pulih',
      NightImpactEffect.clinicTrap =>
        actor ? 'Jebakan pondok terpicu' : 'Jebakan di pondok',
      NightImpactEffect.bowHit =>
        actor ? 'Panah mengenai sasaran' : 'Kamu terkena panah',
      NightImpactEffect.bowFinal =>
        actor ? 'Si Terbisik tumbang' : 'Panah terakhir mengenaimu',
      NightImpactEffect.bowMiss => 'Panah berbalik',
      NightImpactEffect.mirror =>
        actor ? 'Seranganmu dipantulkan' : 'Cermin Kecil memantulkan serangan',
      NightImpactEffect.shield =>
        actor ? 'Seranganmu tertahan' : 'Perisai Malam menahan serangan',
      NightImpactEffect.guard => 'Penjagaanmu berhasil',
      NightImpactEffect.pump =>
        actor ? 'Embun berhasil disedot' : 'Embunmu tersedot',
      NightImpactEffect.burn =>
        actor ? 'Kartu sasaran terbakar' : 'Kartumu terbakar',
      NightImpactEffect.theft =>
        actor ? 'Kartu berhasil dicuri' : 'Kartumu dicuri',
    };
  }

  String? get amount {
    if (!applied) return null;
    if (effect == NightImpactEffect.guard ||
        effect == NightImpactEffect.shield) {
      return '1 serangan tertahan';
    }
    if (effect == NightImpactEffect.burn) return '1 kartu terbakar';
    if (effect == NightImpactEffect.theft) {
      return actor ? '+1 kartu' : '−1 kartu';
    }
    final value = delta;
    if (value == null || value == 0) return null;
    final magnitude = value.abs();
    final number = magnitude
        .toStringAsFixed(magnitude % 1 == 0 ? 0 : 1)
        .replaceAll('.', ',');
    final unit = switch (effect) {
      NightImpactEffect.bowHit => actor ? 'nyawa sasaran' : 'nyawa',
      NightImpactEffect.bowMiss ||
      NightImpactEffect.clinicHeal ||
      NightImpactEffect.clinicTrap => actor ? 'nyawa sasaran' : 'nyawa',
      NightImpactEffect.mirror => 'bulir hitam',
      NightImpactEffect.pump => actor ? 'bulir hitam' : 'tetes embun',
      _ => null,
    };
    return unit == null ? null : '${value < 0 ? '−' : '+'}$number $unit';
  }

  Color get color => switch (effect) {
    NightImpactEffect.clinicHeal => const Color(0xFF8DE7B7),
    NightImpactEffect.clinicTrap => const Color(0xFFFF9384),
    NightImpactEffect.bowHit || NightImpactEffect.bowFinal =>
      actor ? const Color(0xFFFFD78B) : const Color(0xFFFF9384),
    NightImpactEffect.bowMiss ||
    NightImpactEffect.burn => const Color(0xFFFF9E70),
    NightImpactEffect.mirror => const Color(0xFFCCB7FF),
    NightImpactEffect.shield => const Color(0xFFAAD9FF),
    NightImpactEffect.guard => const Color(0xFF8DE7B7),
    NightImpactEffect.pump =>
      actor ? const Color(0xFFD7ADF5) : const Color(0xFF84E0E6),
    NightImpactEffect.theft => const Color(0xFFC1ABEF),
  };

  Snd? get sound => !applied
      ? null
      : switch (effect) {
          NightImpactEffect.bowHit ||
          NightImpactEffect.bowFinal ||
          NightImpactEffect.bowMiss => Snd.slashCahaya,
          NightImpactEffect.mirror ||
          NightImpactEffect.shield ||
          NightImpactEffect.guard ||
          NightImpactEffect.clinicHeal => Snd.clickTung,
          NightImpactEffect.clinicTrap => Snd.slashCahaya,
          NightImpactEffect.pump || NightImpactEffect.theft => Snd.swingWind2,
          NightImpactEffect.burn => Snd.swingFire1,
        };
}

class NightImpactReport extends StatelessWidget {
  final NightImpact impact;
  final String message;
  final double progress;
  final bool active;
  final String? cardArt;
  final String? cardName;

  const NightImpactReport({
    super.key,
    required this.impact,
    required this.message,
    required this.progress,
    required this.active,
    this.cardArt,
    this.cardName,
  });

  @override
  Widget build(BuildContext context) {
    final color = impact.color;
    final amount = impact.amount;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xED0D1420),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: active ? 0.65 : 0.26),
        ),
        boxShadow: [
          if (active)
            BoxShadow(color: color.withValues(alpha: 0.17), blurRadius: 23),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const GameIcon('lock', size: 16),
              const SizedBox(width: 6),
              Text(
                'HASIL PRIBADI',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            impact.title,
            style: TextStyle(
              color: color,
              fontSize: active ? 21 : 16,
              fontWeight: FontWeight.w800,
              height: 1.16,
            ),
          ),
          if (impact.targetName case final name?)
            Padding(
              padding: const EdgeInsets.only(top: 7, bottom: 3),
              child: Text(
                'Kamu → $name',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 5),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFFE5EAF4),
              height: 1.3,
              fontSize: 13,
            ),
          ),
          if (amount != null || cardName != null)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                amount ?? cardName!,
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ),
          if (active)
            NightImpactVisual(
              impact: impact,
              progress: progress,
              cardArt: cardArt,
            ),
        ],
      ),
    );
  }
}

/// Ilustrasi hasil pribadi. Menggunakan satu garis waktu dengan laporan malam.
class NightImpactVisual extends StatelessWidget {
  final NightImpact impact;
  final double progress;
  final String? cardArt;

  const NightImpactVisual({
    super.key,
    required this.impact,
    required this.progress,
    this.cardArt,
  });

  @override
  Widget build(BuildContext context) {
    final p = MediaQuery.disableAnimationsOf(context) ? 0.78 : progress;
    final color = impact.color;
    final card = cardArt;
    final isBurn = impact.effect == NightImpactEffect.burn;
    final isTheft = impact.effect == NightImpactEffect.theft;
    final travel = Curves.easeInOut.transform(_range(p, 0.22, 0.84));
    final cardX = isTheft ? (impact.actor ? -1.0 : 1.0) * 58 * travel : 0.0;
    final cardY = isTheft ? -10 * travel : -6 * travel;
    final cardAlpha = isBurn ? 1 - _range(p, 0.34, 0.82) : 1.0;
    return ExcludeSemantics(
      child: SizedBox(
        height: 96,
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: RadialGradient(
                  radius: 0.64,
                  colors: [
                    color.withValues(alpha: 0.16),
                    const Color(0x00202738),
                  ],
                ),
              ),
            ),
            if (!impact.applied)
              const Center(child: GameIcon('silang', size: 34))
            else ...[
              if (isBurn || isTheft)
                Center(
                  child: Transform.translate(
                    offset: Offset(cardX, cardY),
                    child: Transform.rotate(
                      angle: (isTheft ? 0.24 : 0.07) * travel,
                      child: Opacity(
                        opacity: cardAlpha,
                        child: card == null
                            ? const GameIcon('mydeck2', size: 43)
                            : CardArt(path: card, width: 39, glow: color),
                      ),
                    ),
                  ),
                ),
              CustomPaint(painter: _ImpactPainter(impact, p)),
            ],
          ],
        ),
      ),
    );
  }
}

double _range(double t, double start, double end) =>
    ((t - start) / (end - start)).clamp(0.0, 1.0).toDouble();

class _ImpactPainter extends CustomPainter {
  final NightImpact impact;
  final double progress;

  const _ImpactPainter(this.impact, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    // Ruang animasi tetap utuh pada ponsel dan desktop.
    final scale = math.min(size.width / 242, size.height / 96);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    switch (impact.effect) {
      case NightImpactEffect.clinicHeal:
      case NightImpactEffect.clinicTrap:
        _clinic(canvas);
      case NightImpactEffect.bowHit:
      case NightImpactEffect.bowFinal:
      case NightImpactEffect.bowMiss:
        _bow(canvas);
      case NightImpactEffect.mirror:
      case NightImpactEffect.shield:
      case NightImpactEffect.guard:
        _ward(canvas);
      case NightImpactEffect.pump:
        _drops(canvas);
      case NightImpactEffect.burn:
      case NightImpactEffect.theft:
        _cards(canvas);
    }
  }

  void _clinic(Canvas canvas) {
    final p = Curves.easeOut.transform(progress.clamp(0.0, 1.0));
    final heal = impact.effect == NightImpactEffect.clinicHeal;
    canvas.drawCircle(Offset.zero, 18 + 22 * p, _ink((1 - p) * .75, width: 3));
    final ink = Paint()
      ..color = impact.color.withValues(alpha: .95)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-18, 0), const Offset(18, 0), ink);
    if (heal) canvas.drawLine(const Offset(0, -18), const Offset(0, 18), ink);
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final distance = 25 + 24 * p;
      canvas.drawCircle(
        Offset(math.cos(angle) * distance, math.sin(angle) * distance),
        2.5,
        _ink(1 - p, width: 2),
      );
    }
  }

  Paint _ink(double opacity, {double width = 2}) => Paint()
    ..color = impact.color.withValues(alpha: opacity.clamp(0.0, 1.0))
    ..strokeCap = StrokeCap.round
    ..strokeWidth = width
    ..style = PaintingStyle.stroke;

  void _ring(Canvas canvas, Offset center, double p, double radius) {
    canvas.drawCircle(center, 7 + radius * p, _ink(0.65 * (1 - p)));
  }

  void _arrow(Canvas canvas, Offset tip, double direction, double opacity) {
    final tail = tip - Offset(45 * direction, 0);
    canvas.drawLine(tail, tip, _ink(opacity * 0.23, width: 7));
    canvas.drawLine(tail, tip, _ink(opacity, width: 2));
    for (final y in [-7.0, 7.0]) {
      canvas.drawLine(tip, tip - Offset(12 * direction, y), _ink(opacity));
      canvas.drawLine(tail, tail + Offset(9 * direction, y / 2), _ink(opacity));
    }
  }

  void _bow(Canvas canvas) {
    final miss = impact.effect == NightImpactEffect.bowMiss;
    final face = impact.actor ? 1.0 : -1.0;
    final t = Curves.easeOutCubic.transform(_range(progress, 0, 0.48));
    final back = Curves.easeInOut.transform(_range(progress, 0.43, 0.80));
    final target = Offset(66 * face, -4);
    final tip = Offset((-90 + 156 * t - (miss ? 146 * back : 0)) * face, -4);
    canvas.drawCircle(target, 15, _ink(0.35, width: 1));
    if (progress > 0.35) {
      _ring(canvas, target, _range(progress, 0.35, 0.98), 37);
    }
    if (miss && progress > 0.65) {
      _ring(canvas, const Offset(-80, -4), _range(progress, 0.65, 1), 25);
    }
    if (miss || progress < 0.68) {
      _arrow(
        canvas,
        tip,
        miss && back > 0 ? -face : face,
        1 - _range(progress, miss ? 0.88 : 0.50, miss ? 1 : 0.68),
      );
    }
  }

  void _ward(Canvas canvas) {
    final mirror = impact.effect == NightImpactEffect.mirror;
    if (impact.effect == NightImpactEffect.guard) {
      final travel = Curves.easeOutCubic.transform(_range(progress, 0, 0.35));
      canvas.drawLine(
        const Offset(-75, 0),
        const Offset(55, 0),
        _ink(0.16, width: 1),
      );
      canvas.drawCircle(const Offset(-75, 0), 9, _ink(0.5));
      canvas.translate(-65 + 115 * travel, 0);
    }
    final face = impact.actor || impact.effect == NightImpactEffect.guard
        ? 1.0
        : -1.0;
    final arrival = _range(progress, 0, 0.4);
    final bounce = _range(progress, 0.4, 0.88);
    final outline = mirror
        ? (Path()
            ..moveTo(0, -28)
            ..lineTo(23, 0)
            ..lineTo(0, 28)
            ..lineTo(-23, 0)
            ..close())
        : (Path()
            ..moveTo(0, -27)
            ..lineTo(23, -18)
            ..quadraticBezierTo(24, 11, 0, 28)
            ..quadraticBezierTo(-24, 11, -23, -18)
            ..close());
    canvas.drawPath(outline, _ink(0.19, width: 9));
    canvas.drawPath(outline, _ink(0.85, width: 1.7));
    if (mirror) {
      canvas.drawLine(const Offset(-7, 13), const Offset(7, -13), _ink(0.55));
    }
    final x = (22 + 77 * (1 - arrival) + (mirror ? 77 * bounce : 0)) * face;
    final opacity = mirror ? 1 - _range(progress, 0.78, 1) : 1 - bounce;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x + 22 * face, 0),
      _ink(opacity, width: 4),
    );
    _ring(canvas, Offset(18 * face, 0), bounce, 31);
  }

  void _drops(Canvas canvas) {
    final face = impact.actor ? 1.0 : -1.0;
    for (var i = 0; i < 6; i++) {
      final t = _range(progress, i * 0.07, 0.66 + i * 0.055);
      final x = (-86 + t * 172) * face;
      final y = 11 - math.sin(t * math.pi) * (19 + i * 2);
      final alpha = math.sin(math.pi * t);
      final drop = Path()
        ..moveTo(x, y - 6)
        ..quadraticBezierTo(x + 8, y + 4, x, y + 5)
        ..quadraticBezierTo(x - 8, y + 4, x, y - 6);
      canvas.drawPath(drop, _ink(alpha)..style = PaintingStyle.fill);
    }
    _ring(canvas, Offset(80 * face, 11), _range(progress, 0.32, 1), 24);
  }

  void _cards(Canvas canvas) {
    final burn = impact.effect == NightImpactEffect.burn;
    final t = _range(progress, 0.16, 0.94);
    for (var i = 0; i < 11; i++) {
      final opacity = math.sin(math.pi * t) * (0.6 + 0.035 * i);
      final x = (i - 5) * (3 + t * 7);
      final y = burn ? 24 - t * (39 + (i * 13) % 35) : (i % 5 - 2) * 9 - t * 14;
      if (burn) {
        final flame = Path()
          ..moveTo(x, y + 9)
          ..quadraticBezierTo(x - 7, y + 2, x + 1, y - 9)
          ..quadraticBezierTo(x - 1, y - 2, x + 6, y + 4)
          ..quadraticBezierTo(x + 7, y + 10, x, y + 9);
        canvas.drawPath(flame, _ink(opacity)..style = PaintingStyle.fill);
      } else {
        final move = (impact.actor ? -1 : 1) * t * 34;
        canvas.drawLine(
          Offset(x + move, y),
          Offset(x + move - 12, y),
          _ink(opacity, width: 1.5),
        );
      }
    }
    _ring(canvas, Offset.zero, t, burn ? 43 : 32);
  }

  @override
  bool shouldRepaint(covariant _ImpactPainter oldDelegate) =>
      oldDelegate.impact != impact || oldDelegate.progress != progress;
}
