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
        height: 112,
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

  Paint _glow(double opacity, {double width = 6, double blur = 6}) => Paint()
    ..color = impact.color.withValues(alpha: opacity.clamp(0.0, 1.0))
    ..strokeCap = StrokeCap.round
    ..strokeWidth = width
    ..style = PaintingStyle.stroke
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

  Paint _fill(double opacity, {Color? color, double blur = 0}) => Paint()
    ..color = (color ?? impact.color).withValues(alpha: opacity.clamp(0.0, 1.0))
    ..style = PaintingStyle.fill
    ..maskFilter = blur > 0 ? MaskFilter.blur(BlurStyle.normal, blur) : null;

  double _h(int i, int k) {
    final v = math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
    return v - v.floorToDouble();
  }

  double _lerpD(double a, double b, double t) => a + (b - a) * t;

  /// Cincin kejut: lingkar berpendar + inti terang.
  void _shock(Canvas canvas, Offset c, double p, double radius) {
    if (p <= 0 || p >= 1) return;
    final e = Curves.easeOutCubic.transform(p);
    final a = 1 - p;
    canvas.drawCircle(
        c, 6 + radius * e, _glow(0.6 * a, width: 8 * a + 2, blur: 6));
    canvas.drawCircle(
      c,
      6 + radius * e,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * a + 0.6
        ..color = Colors.white.withValues(alpha: 0.85 * a),
    );
  }

  /// Semburan garis radial + kilatan cahaya.
  void _burst(
      Canvas canvas,
      Offset c,
      double p, {
        int n = 12,
        double reach = 36,
        double flash = 20,
      }) {
    if (p <= 0 || p >= 1) return;
    final e = Curves.easeOutCubic.transform(p);
    final a = 1 - p;
    canvas.drawCircle(c, flash * (0.6 + 0.8 * e), _fill(0.6 * a * a, blur: 10));
    canvas.drawCircle(
        c, flash * 0.35 * a, _fill(0.9 * a, color: Colors.white, blur: 3));
    for (var i = 0; i < n; i++) {
      final ang = (i + _h(i, 3) * 0.6) * 2 * math.pi / n;
      final dir = Offset(math.cos(ang), math.sin(ang));
      final len = 6 + 12 * _h(i, 5);
      final r1 = 6 + reach * (0.5 + 0.5 * _h(i, 7)) * e;
      canvas.drawLine(
        c + dir * math.max(4.0, r1 - len * (1 - p)),
        c + dir * r1,
        _ink(a, width: 2.2 * a + 0.6),
      );
    }
  }

  void _arrow(
      Canvas canvas,
      Offset tip,
      double direction,
      double opacity, {
        double trail = 0,
      }) {
    final tail = tip - Offset(45 * direction, 0);
    if (trail > 0) {
      canvas.drawLine(
        tail,
        tail - Offset(trail * direction, 0),
        _glow(opacity * 0.5, width: 6, blur: 5),
      );
      for (final y in [-3.5, 3.5]) {
        canvas.drawLine(
          tail - Offset(6 * direction, y),
          tail - Offset(trail * 0.7 * direction, y),
          _ink(opacity * 0.4, width: 1),
        );
      }
    }
    canvas.drawLine(tail, tip, _ink(opacity * 0.23, width: 7));
    canvas.drawLine(tail, tip, _ink(opacity, width: 2));
    canvas.drawCircle(tip, 5, _fill(opacity * 0.8, blur: 4));
    for (final y in [-7.0, 7.0]) {
      canvas.drawLine(tip, tip - Offset(12 * direction, y), _ink(opacity));
      canvas.drawLine(tail, tail + Offset(9 * direction, y / 2), _ink(opacity));
    }
  }

  void _bow(Canvas canvas) {
    final miss = impact.effect == NightImpactEffect.bowMiss;
    final fin = impact.effect == NightImpactEffect.bowFinal;
    final face = impact.actor ? 1.0 : -1.0;
    // Anak panah melesat makin cepat lalu menghantam.
    final t = Curves.easeInCubic.transform(_range(progress, 0, 0.48));
    final back = Curves.easeInOut.transform(_range(progress, 0.43, 0.80));
    final hit = _range(progress, 0.46, 1.0);
    final shake = hit > 0 && hit < 0.4 && !miss
        ? math.sin(hit * 140) * 5 * (1 - hit / 0.4)
        : 0.0;
    final target = Offset(66 * face + shake, -4);
    final tip = Offset((-90 + 156 * t - (miss ? 146 * back : 0)) * face, -4);

    // Bidikan: cincin mengunci sasaran sebelum panah tiba.
    final lock = _range(progress, 0, 0.46);
    final lockA = (0.25 + 0.5 * lock) * (miss ? 1.0 : 1 - hit * 0.6);
    final r = 15 + 8 * (1 - lock);
    canvas.drawCircle(target, r, _ink(lockA, width: 1.4));
    canvas.drawCircle(target, 7, _ink(lockA * 0.8, width: 1));
    for (final d in const [
      Offset(1, 0),
      Offset(-1, 0),
      Offset(0, 1),
      Offset(0, -1),
    ]) {
      canvas.drawLine(
          target + d * (r + 3), target + d * (r + 9), _ink(lockA, width: 1.4));
    }

    if (hit > 0) {
      if (!miss) {
        _burst(canvas, target, hit,
            n: fin ? 22 : 14, reach: fin ? 54 : 40, flash: fin ? 32 : 22);
        _shock(canvas, target, _range(hit, 0, 0.8), fin ? 58 : 40);
        _shock(canvas, target, _range(hit, 0.15, 1), fin ? 80 : 56);
        if (fin) {
          // Tanda silang di sasaran terakhir.
          final xa = _range(hit, 0.1, 0.3) * (1 - _range(hit, 0.7, 1));
          for (final s in [-1.0, 1.0]) {
            canvas.drawLine(target + Offset(-10, -10 * s),
                target + Offset(10, 10 * s), _glow(xa, width: 5, blur: 4));
            canvas.drawLine(target + Offset(-10, -10 * s),
                target + Offset(10, 10 * s), _ink(xa, width: 2));
          }
        }
      } else {
        _burst(canvas, target - Offset(14 * face, 0), _range(hit, 0, 0.6),
            n: 8, reach: 24, flash: 14);
      }
    }
    if (miss && progress > 0.65) {
      final rp = _range(progress, 0.65, 1);
      final origin = Offset(-80 * face, -4);
      _burst(canvas, origin, rp, n: 10, reach: 30, flash: 16);
      _shock(canvas, origin, rp, 34);
    }
    if (miss || progress < 0.68) {
      _arrow(
        canvas,
        tip,
        miss && back > 0 ? -face : face,
        1 - _range(progress, miss ? 0.88 : 0.50, miss ? 1 : 0.68),
        trail: 70 * (1 - _range(progress, 0.40, 0.50)),
      );
    }
  }

  void _ward(Canvas canvas) {
    final mirror = impact.effect == NightImpactEffect.mirror;
    final guard = impact.effect == NightImpactEffect.guard;
    if (guard) {
      final travel = Curves.easeOutCubic.transform(_range(progress, 0, 0.35));
      canvas.drawLine(
        const Offset(-75, 0),
        const Offset(55, 0),
        _ink(0.16, width: 1),
      );
      canvas.drawCircle(const Offset(-75, 0), 9, _ink(0.5));
      // Jejak cahaya perisai yang meluncur.
      canvas.drawLine(
        const Offset(-75, 0),
        Offset(-65 + 115 * travel, 0),
        _glow(0.45 * (1 - travel), width: 10, blur: 7),
      );
      canvas.translate(-65 + 115 * travel, 0);
    }
    final face = impact.actor || guard ? 1.0 : -1.0;
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

    // Aura berdenyut di belakang pelindung.
    final pulse = 0.5 + 0.5 * math.sin(progress * 22);
    canvas.drawCircle(
      Offset.zero,
      34 + 5 * pulse + 6 * bounce,
      _fill(0.16 + 0.12 * pulse + 0.2 * math.sin(bounce * math.pi), blur: 12),
    );
    canvas.drawPath(outline, _ink(0.19, width: 9));
    canvas.drawPath(outline, _glow(0.5, width: 5, blur: 5));
    canvas.drawPath(outline, _ink(0.9, width: 1.9));
    // Riak kerangka yang melebar saat dihantam.
    final rip = _range(progress, 0.38, 0.95);
    if (rip > 0 && rip < 1) {
      canvas.save();
      canvas.scale(1 + 0.55 * Curves.easeOutCubic.transform(rip));
      canvas.drawPath(outline, _ink(0.6 * (1 - rip), width: 1.4));
      canvas.restore();
    }
    if (mirror) {
      canvas.drawLine(const Offset(-7, 13), const Offset(7, -13), _ink(0.55));
      // Kilau di permukaan cermin saat terkena.
      final shine = math.sin(math.pi * _range(progress, 0.36, 0.7));
      if (shine > 0) {
        canvas.drawLine(const Offset(-16, 10), const Offset(16, -10),
            _glow(0.9 * shine, width: 4, blur: 3));
        canvas.drawLine(
            const Offset(-16, 10),
            const Offset(16, -10),
            Paint()
              ..color = Colors.white.withValues(alpha: shine)
              ..strokeWidth = 1.5
              ..strokeCap = StrokeCap.round);
      }
    }
    final x = (22 + 77 * (1 - arrival) + (mirror ? 77 * bounce : 0)) * face;
    final opacity = mirror ? 1 - _range(progress, 0.78, 1) : 1 - bounce;
    // Sinar serangan berpendar; setelah dipantulkan makin tebal.
    final beamW = mirror && bounce > 0 ? 6.0 : 4.0;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x + 30 * face, 0),
      _glow(opacity * 0.6, width: beamW + 5, blur: 5),
    );
    canvas.drawLine(
      Offset(x, 0),
      Offset(x + 22 * face, 0),
      _ink(opacity, width: beamW),
    );
    // Hantaman: kilatan, cincin, dan percikan.
    final contact = Offset(20 * face, 0);
    _burst(canvas, contact, _range(progress, 0.38, 0.9),
        n: 14, reach: 34, flash: 22);
    _shock(canvas, contact, bounce, 36);
    _shock(canvas, contact, _range(progress, 0.5, 1), 52);
  }

  void _drops(Canvas canvas) {
    final face = impact.actor ? 1.0 : -1.0;
    final dest = Offset(80 * face, 11);
    final absorb = _range(progress, 0.3, 1);
    final swell = math.sin(absorb * math.pi);

    // Bola penyerap di tujuan membesar, dengan pusaran partikel.
    canvas.drawCircle(dest, 8 + 12 * swell, _fill(0.35 * swell, blur: 9));
    for (var i = 0; i < 8; i++) {
      final ang = absorb * 7 + i * math.pi / 4;
      final rad = 28 * (1 - absorb) + 4;
      canvas.drawCircle(
        dest + Offset(math.cos(ang), math.sin(ang) * 0.7) * rad,
        1.8,
        _fill(0.9 * swell, color: Colors.white),
      );
    }

    for (var i = 0; i < 10; i++) {
      final t = _range(progress, i * 0.05, 0.64 + i * 0.04);
      final alpha = math.sin(math.pi * t);
      if (alpha <= 0) continue;
      Offset pos(double tt) => Offset(
        (-86 + tt * 172) * face,
        11 - math.sin(tt * math.pi) * (19 + i * 2),
      );
      // Ekor tetes: bintik pudar di belakang.
      for (var k = 1; k <= 3; k++) {
        final tt = (t - k * 0.04).clamp(0.0, 1.0);
        canvas.drawCircle(
            pos(tt), 3.2 - k * 0.7, _fill(alpha * (0.4 - 0.1 * k)));
      }
      final p = pos(t);
      canvas.drawCircle(
          p + const Offset(0, 1), 9, _fill(alpha * 0.35, blur: 6));
      final drop = Path()
        ..moveTo(p.dx, p.dy - 6)
        ..quadraticBezierTo(p.dx + 8, p.dy + 4, p.dx, p.dy + 5)
        ..quadraticBezierTo(p.dx - 8, p.dy + 4, p.dx, p.dy - 6);
      canvas.drawPath(drop, _fill(alpha));
      canvas.drawCircle(p + const Offset(-1.8, 0), 1.3,
          _fill(alpha * 0.9, color: Colors.white));
    }
    _shock(canvas, dest, _range(progress, 0.32, 1), 24);
    _burst(canvas, dest, _range(progress, 0.72, 1),
        n: 9, reach: 24, flash: 14);
  }

  void _cards(Canvas canvas) {
    final burn = impact.effect == NightImpactEffect.burn;
    final t = _range(progress, 0.16, 0.94);
    final swell = math.sin(math.pi * t);
    if (burn) {
      // Panas: cahaya membesar di belakang kartu.
      canvas.drawCircle(
          const Offset(0, -4), 26 + 22 * t, _fill(0.35 * swell, blur: 16));
      for (var i = 0; i < 18; i++) {
        final op = swell * (0.55 + 0.025 * i);
        final x = (i - 8.5) * (2.4 + t * 5.2);
        final y = 26 - t * (36 + (i * 13) % 38);
        final s = 0.8 + 0.7 * _h(i, 2);
        final flame = Path()
          ..moveTo(x, y + 9 * s)
          ..quadraticBezierTo(x - 7 * s, y + 2 * s, x + 1 * s, y - 10 * s)
          ..quadraticBezierTo(x - 1 * s, y - 2 * s, x + 6 * s, y + 4 * s)
          ..quadraticBezierTo(x + 7 * s, y + 10 * s, x, y + 9 * s);
        canvas.drawPath(flame, _fill(op * 0.4, blur: 5));
        canvas.drawPath(flame, _fill(op));
      }
      // Bara kecil yang melayang naik.
      for (var i = 0; i < 16; i++) {
        final u = _range(t, _h(i, 4) * 0.4, 0.55 + 0.45 * _h(i, 6));
        if (u <= 0 || u >= 1) continue;
        final x = (_h(i, 1) - 0.5) * 76 + math.sin(u * 7 + i) * 6;
        final y = 18 - u * (54 + 26 * _h(i, 8));
        canvas.drawCircle(
          Offset(x, y),
          1 + 1.6 * _h(i, 9) * (1 - u),
          _fill(math.sin(u * math.pi) * 0.9),
        );
      }
    } else {
      final dir = impact.actor ? -1.0 : 1.0;
      final dest = Offset(dir * 58, -10);
      // Garis sambar berpendar + kerlip partikel di sepanjang lintasan.
      for (var i = 0; i < 12; i++) {
        final opacity = swell * (0.6 + 0.03 * i);
        final x = (i - 5.5) * (3 + t * 7);
        final y = (i % 5 - 2) * 9 - t * 14;
        final move = dir * t * 40;
        canvas.drawLine(Offset(x + move, y), Offset(x + move - 16 * dir, y),
            _glow(opacity * 0.5, width: 4, blur: 3));
        canvas.drawLine(Offset(x + move, y), Offset(x + move - 14 * dir, y),
            _ink(opacity, width: 1.5));
      }
      for (var i = 0; i < 14; i++) {
        final u = _range(t, i * 0.04, 0.55 + i * 0.03);
        if (u <= 0 || u >= 1) continue;
        final px = _lerpD(-dir * 20, dest.dx, u) + math.sin(u * 9 + i) * 5;
        final py = _lerpD(0, dest.dy, u) + math.cos(u * 8 + i) * 8;
        canvas.drawCircle(Offset(px, py), 1.2 + 1.8 * _h(i, 3) * (1 - u),
            _fill(math.sin(u * math.pi), color: Colors.white));
      }
      _burst(canvas, dest, _range(progress, 0.78, 1),
          n: 10, reach: 28, flash: 14);
    }
    _shock(canvas, Offset.zero, t, burn ? 43 : 32);
    _shock(canvas, Offset.zero, _range(t, 0.2, 1), burn ? 62 : 46);
  }

  @override
  bool shouldRepaint(covariant _ImpactPainter oldDelegate) =>
      oldDelegate.impact != impact || oldDelegate.progress != progress;
}