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

  /// Saat benturan, sebagai pecahan (0..1) dari [kNightImpactMs].
  double get hit => !applied
      ? 0.32
      : switch (effect) {
    NightImpactEffect.bowHit ||
    NightImpactEffect.bowFinal ||
    NightImpactEffect.bowMiss => 0.50,
    NightImpactEffect.mirror ||
    NightImpactEffect.shield ||
    NightImpactEffect.guard => 0.46,
    NightImpactEffect.pump => 0.86,
    NightImpactEffect.burn => 0.30,
    NightImpactEffect.theft => actor ? 0.62 : 0.30,
    NightImpactEffect.clinicHeal => 0.36,
    NightImpactEffect.clinicTrap => 0.36,
  };

  /// Kekuatan guncangan layar saat benturan.
  double get shakePower => !applied
      ? 0.2
      : switch (effect) {
    NightImpactEffect.bowFinal => 1.5,
    NightImpactEffect.bowHit => actor ? 0.9 : 1.3,
    NightImpactEffect.bowMiss => 0.6,
    NightImpactEffect.mirror ||
    NightImpactEffect.shield ||
    NightImpactEffect.guard => 0.8,
    NightImpactEffect.pump => 0.4,
    NightImpactEffect.burn => 0.7,
    NightImpactEffect.theft => 0.6,
    NightImpactEffect.clinicHeal => 0.35,
    NightImpactEffect.clinicTrap => 1.2,
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
  final bool active;
  final String? cardName;

  const NightImpactReport({
    super.key,
    required this.impact,
    required this.message,
    required this.active,
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
        ],
      ),
    );
  }
}

// ===========================================================================
// Adegan dampak LAYAR PENUH
// ===========================================================================

/// Lama (ms) satu adegan dampak layar penuh.
const int kNightImpactMs = 2200;

double _cl(double v) => v < 0 ? 0.0 : (v > 1 ? 1.0 : v);

double _range(double t, double start, double end) =>
    ((t - start) / (end - start)).clamp(0.0, 1.0).toDouble();

double _lerpD(double a, double b, double t) => a + (b - a) * t;

double _hash(int i, int k) {
  final v = math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
  return v - v.floorToDouble();
}

Offset _quad(Offset a, Offset c, Offset b, double t) {
  final k = 1 - t;
  return a * (k * k) + c * (2 * k * t) + b * (t * t);
}

double _cardW(Size s) => math.min(s.width * 0.42, 190.0);

double _theftFlight(double p) =>
    Curves.easeInOutCubic.transform(_range(p, 0.28, 0.62));

Offset _theftPos(Size s, bool actor, double t) {
  final a = Offset(s.width * 0.82, s.height * 0.16);
  final b = Offset(s.width * 0.5, s.height * 0.66);
  final c = Offset(s.width * 0.97, s.height * 0.60);
  return actor ? _quad(a, c, b, t) : _quad(b, c, a, t);
}

double _theftAngle(bool actor, double t) =>
    (actor ? -1.0 : 1.0) * 0.55 * math.sin(t * math.pi) + 0.18 * t;

double _theftScale(bool actor, double t) =>
    actor ? _lerpD(0.7, 1.05, t) : _lerpD(1.05, 0.4, t);

/// Adegan dampak yang memenuhi seluruh layar, digambar di atas isi adegan
/// malam. [progress] 0..1 selama [kNightImpactMs].
class NightImpactStage extends StatelessWidget {
  final NightImpact impact;
  final double progress;
  final String? cardArt;

  const NightImpactStage({
    super.key,
    required this.impact,
    required this.progress,
    this.cardArt,
  });

  @override
  Widget build(BuildContext context) {
    final p = MediaQuery.disableAnimationsOf(context) ? 0.7 : progress;
    final m = 1 - _range(p, 0.86, 1.0);
    final usesCard = impact.applied &&
        (impact.effect == NightImpactEffect.burn ||
            impact.effect == NightImpactEffect.theft);
    return ExcludeSemantics(
      child: IgnorePointer(
        child: SizedBox.expand(
          child: LayoutBuilder(builder: (context, box) {
            final size = Size(box.maxWidth, box.maxHeight);
            return Stack(
              fit: StackFit.expand,
              children: [
                if (usesCard) _cardWidget(size, p, m),
                CustomPaint(
                  painter: _StagePainter(impact, p, m),
                  size: size,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _cardWidget(Size s, double p, double m) {
    final cw = _cardW(s);
    final art = cardArt;
    final Widget face = art == null
        ? const GameIcon('mydeck2', size: 110)
        : CardArt(path: art, width: cw, glow: impact.color);
    if (impact.effect == NightImpactEffect.burn) {
      final appear = Curves.easeOutBack.transform(_range(p, 0.0, 0.22));
      final burnt = _range(p, 0.30, 0.82);
      final jitter = math.sin(p * 160) * 5 * (burnt * (1 - burnt) * 4);
      final alpha = _range(p, 0.0, 0.1) * (1 - _range(p, 0.62, 0.84));
      final tint = Color.lerp(Colors.white, const Color(0xFF241006), burnt)!;
      return Positioned(
        left: s.width / 2 - cw / 2 + jitter,
        top: s.height * 0.40 - cw * 0.7,
        width: cw,
        child: Opacity(
          opacity: _cl(alpha),
          child: Transform.scale(
            scale: 0.55 + 0.45 * appear,
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(tint, BlendMode.modulate),
              child: face,
            ),
          ),
        ),
      );
    }
    final t = _theftFlight(p);
    final pos = _theftPos(s, impact.actor, t);
    final appear = _range(p, 0.0, 0.14);
    final fade = impact.actor ? 1.0 : 1 - _range(p, 0.60, 0.80);
    final bob = t == 0 ? math.sin(p * 30) * 5 : 0.0;
    return Positioned(
      left: pos.dx - cw / 2,
      top: pos.dy - cw * 0.7 + bob,
      width: cw,
      child: Opacity(
        opacity: _cl(appear * fade),
        child: Transform.rotate(
          angle: _theftAngle(impact.actor, t),
          child: Transform.scale(
            scale: _theftScale(impact.actor, t),
            child: face,
          ),
        ),
      ),
    );
  }
}

class _StagePainter extends CustomPainter {
  final NightImpact impact;
  final double p;
  final double m;

  const _StagePainter(this.impact, this.p, this.m);

  @override
  void paint(Canvas canvas, Size size) {
    final f = _Fx(canvas, size, impact.color, p, m);
    if (!impact.applied) {
      _fxNull(f, impact);
      return;
    }
    switch (impact.effect) {
      case NightImpactEffect.clinicHeal:
        _fxHeal(f, impact);
      case NightImpactEffect.clinicTrap:
        _fxTrap(f, impact);
      case NightImpactEffect.bowHit:
      case NightImpactEffect.bowFinal:
      case NightImpactEffect.bowMiss:
        _fxBow(f, impact);
      case NightImpactEffect.mirror:
      case NightImpactEffect.shield:
      case NightImpactEffect.guard:
        _fxWard(f, impact);
      case NightImpactEffect.pump:
        _fxPump(f, impact);
      case NightImpactEffect.burn:
        _fxBurn(f, impact);
      case NightImpactEffect.theft:
        _fxTheft(f, impact);
    }
  }

  @override
  bool shouldRepaint(covariant _StagePainter old) =>
      old.p != p || old.m != m || old.impact != impact;
}

/// Kotak perkakas menggambar: semua gambar ikut memudar lewat [m] dan
/// ukuran mengikuti layar lewat [u].
class _Fx {
  final Canvas c;
  final Size s;
  final Color col;
  final double p;
  final double m;

  _Fx(this.c, this.s, this.col, this.p, this.m);

  double get w => s.width;
  double get h => s.height;
  double get u => s.shortestSide / 360;
  double get diag => math.sqrt(w * w + h * h);

  Color tone(Color? color, double a) =>
      (color ?? col).withValues(alpha: _cl(a * m));

  Paint stroke(
      double a, {
        double width = 2,
        double blur = 0,
        Color? color,
        bool add = false,
      }) =>
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = width
        ..color = tone(color, a)
        ..blendMode = add ? BlendMode.plus : BlendMode.srcOver
        ..maskFilter = blur > 0 ? MaskFilter.blur(BlurStyle.normal, blur) : null;

  Paint fill(
      double a, {
        double blur = 0,
        Color? color,
        bool add = false,
      }) =>
      Paint()
        ..style = PaintingStyle.fill
        ..color = tone(color, a)
        ..blendMode = add ? BlendMode.plus : BlendMode.srcOver
        ..maskFilter = blur > 0 ? MaskFilter.blur(BlurStyle.normal, blur) : null;

  /// Kilatan seluruh layar yang meredup cepat.
  void flash(double at, {double len = 0.10, double peak = 0.8, Color? color}) {
    if (p < at) return;
    final a = peak * math.exp(-(p - at) / len * 3);
    if (a < 0.01) return;
    c.drawRect(Offset.zero & s, fill(a, color: color ?? Colors.white));
  }

  /// Gelap di tepi layar.
  void vignette(double strength, {Color? color}) {
    if (strength <= 0.005) return;
    final base = color ?? Colors.black;
    final r = Offset.zero & s;
    c.drawRect(
      r,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [base.withValues(alpha: 0), tone(base, strength)],
          stops: const [0.45, 1.0],
        ).createShader(r),
    );
  }

  /// Pita hitam sinematik di atas dan bawah.
  void bars(double amount) {
    if (amount <= 0.01) return;
    final bh = h * 0.075 * amount;
    final paint = Paint()..color = Colors.black.withValues(alpha: _cl(0.92 * m));
    c.drawRect(Rect.fromLTWH(0, 0, w, bh), paint);
    c.drawRect(Rect.fromLTWH(0, h - bh, w, bh), paint);
  }

  /// Bola cahaya: lingkar luar, tubuh, dan inti putih.
  void orb(Offset o, double r, double a, {Color? color}) {
    if (r <= 0.5 || a <= 0) return;
    c.drawCircle(o, r * 2.0, fill(0.30 * a, blur: r * 0.9, color: color, add: true));
    c.drawCircle(o, r, fill(0.65 * a, blur: r * 0.25, color: color, add: true));
    c.drawCircle(o, r * 0.45, fill(0.95 * a, color: Colors.white, add: true));
  }

  /// Cincin kejut yang melebar sampai [maxR].
  void shock(
      Offset o,
      double at,
      double maxR, {
        double width = 18,
        Color? color,
        double len = 0.34,
      }) {
    final t = _range(p, at, at + len);
    if (t <= 0 || t >= 1) return;
    final e = Curves.easeOutCubic.transform(t);
    final a = 1 - t;
    final r = 10 + maxR * e;
    c.drawCircle(o, r,
        stroke(0.55 * a, width: width * a * u + 3, blur: 10, color: color, add: true));
    c.drawCircle(
        o, r, stroke(0.9 * a, width: 1.5 + 3 * a, color: Colors.white, add: true));
  }

  /// Garis cahaya memancar ke segala arah.
  void rays(
      Offset o,
      double at, {
        int n = 28,
        double len = 0.30,
        double reachFactor = 0.7,
        Color? color,
      }) {
    final t = _range(p, at, at + len);
    if (t <= 0 || t >= 1) return;
    final e = Curves.easeOutCubic.transform(t);
    final a = 1 - t;
    for (var i = 0; i < n; i++) {
      final ang = (i + _hash(i, 1) * 0.8) * 2 * math.pi / n;
      final d = Offset(math.cos(ang), math.sin(ang));
      final reach = diag * reachFactor * (0.35 + 0.65 * _hash(i, 2)) * e;
      c.drawLine(
        o + d * (20 * u + reach * 0.35),
        o + d * (20 * u + reach),
        stroke(0.8 * a,
            width: (1 + 3 * _hash(i, 3)) * a + 0.6,
            color: i.isEven ? Colors.white : color,
            add: true),
      );
    }
  }

  /// Percikan yang terlempar lalu jatuh (gravity negatif = naik).
  void sparks(
      Offset o,
      double at, {
        int n = 40,
        double len = 0.55,
        double spread = 1.0,
        double gravity = 140,
        int seed = 0,
        Color? color,
      }) {
    final t = _range(p, at, at + len);
    if (t <= 0 || t >= 1) return;
    final e = Curves.easeOutCubic.transform(t);
    for (var i = 0; i < n; i++) {
      final ang = _hash(i + seed, 7) * 2 * math.pi;
      final sp = (0.18 + 0.75 * _hash(i + seed, 8)) * diag * 0.6 * spread;
      final pos = o +
          Offset(
            math.cos(ang) * sp * e,
            math.sin(ang) * sp * e +
                gravity * u * t * t * (0.5 + _hash(i + seed, 9)),
          );
      final r = (1 + 2.6 * _hash(i + seed, 10)) * (1 - t) * u + 0.6;
      c.drawCircle(
        pos,
        r,
        fill(0.95 * (1 - t), color: i % 3 == 0 ? Colors.white : color, add: true),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Panah
// ---------------------------------------------------------------------------

void _arrowShape(_Fx f, Offset tip, double dir, double speed) {
  final c = f.c;
  final u = f.u;
  final len = 150 * u;
  final tail = tip - Offset(len * dir, 0);
  if (speed > 0.02) {
    final trailLen = f.w * 0.5 * speed;
    c.drawLine(tail, tail - Offset(trailLen * dir, 0),
        f.stroke(0.5, width: 14 * u, blur: 10 * u, add: true));
    c.drawLine(tail, tail - Offset(trailLen * dir, 0),
        f.stroke(0.8, width: 3 * u, color: Colors.white, add: true));
    for (var i = 0; i < 6; i++) {
      final y = (i - 2.5) * 22 * u;
      final l = trailLen * (0.4 + 0.5 * _hash(i, 3));
      c.drawLine(
        tail + Offset(-18 * u * dir, y),
        tail + Offset(-(18 * u + l) * dir, y),
        f.stroke(0.45 * speed, width: 1.6 * u + 0.4, add: true),
      );
    }
  }
  c.drawLine(tail, tip, f.stroke(0.35, width: 12 * u, blur: 6 * u, add: true));
  c.drawLine(tail, tip, f.stroke(1, width: 3.5 * u, color: Colors.white));
  final head = Path()
    ..moveTo(tip.dx + 16 * u * dir, tip.dy)
    ..lineTo(tip.dx - 6 * u * dir, tip.dy - 11 * u)
    ..lineTo(tip.dx - 6 * u * dir, tip.dy + 11 * u)
    ..close();
  c.drawPath(head, f.fill(1, color: Colors.white));
  c.drawPath(head, f.fill(0.5, blur: 6 * u, add: true));
  for (final y in [-1.0, 1.0]) {
    c.drawLine(
      tail + Offset(26 * u * dir, 0),
      tail - Offset(6 * u * dir, y * 13 * u),
      f.stroke(1, width: 2.5 * u),
    );
  }
}

void _fxBow(_Fx f, NightImpact imp) {
  final p = f.p, u = f.u, w = f.w, h = f.h, c = f.c;
  final miss = imp.effect == NightImpactEffect.bowMiss;
  final fin = imp.effect == NightImpactEffect.bowFinal;
  final dir = imp.actor ? 1.0 : -1.0;
  const hitT = 0.50;
  final target = Offset(imp.actor ? w * 0.74 : w * 0.5, h * 0.40);
  final startX = imp.actor ? -w * 0.2 : w * 1.2;

  f.vignette(0.6 * _range(p, 0, 0.18));
  f.bars(Curves.easeOut.transform(_range(p, 0, 0.12)));

  // Bidikan mengunci sasaran.
  final lock = Curves.easeOutCubic.transform(_range(p, 0.04, 0.40));
  final reA = (p < hitT ? 1.0 : 1 - _range(p, hitT, hitT + 0.1)) *
      _range(p, 0.04, 0.12);
  if (reA > 0.01) {
    final rr = (110 - 62 * lock) * u;
    c.drawCircle(target, rr, f.stroke(0.85 * reA, width: 2 * u + 1, add: true));
    c.drawCircle(target, rr * 0.45, f.stroke(0.7 * reA, width: 1.2 * u + 0.6));
    final spin = lock * 1.6;
    for (var i = 0; i < 4; i++) {
      final ang = spin + i * math.pi / 2;
      final d = Offset(math.cos(ang), math.sin(ang));
      c.drawLine(target + d * (rr + 6 * u), target + d * (rr + 26 * u),
          f.stroke(0.9 * reA, width: 3 * u + 1, add: true));
    }
    f.orb(target, (4 + 3 * math.sin(p * 60)) * u, reA);
  }

  // Garis kecepatan melintasi layar.
  final fwd = Curves.easeInCubic.transform(_range(p, 0.28, hitT));
  if (fwd > 0 && p < hitT + 0.02) {
    for (var i = 0; i < 16; i++) {
      final y = h * (0.08 + 0.84 * _hash(i, 21));
      final len = w * (0.25 + 0.5 * _hash(i, 22));
      final x0 = w * _hash(i, 23);
      c.drawLine(Offset(x0, y), Offset(x0 - dir * len * fwd, y),
          f.stroke(0.35 * fwd, width: 1.4 * u + 0.4, color: Colors.white, add: true));
    }
  }

  // Anak panah.
  final contactX = target.dx - dir * 36 * u;
  final backT =
  miss ? Curves.easeInCubic.transform(_range(p, 0.56, 0.84)) : 0.0;
  final double tipX;
  if (miss) {
    tipX = backT > 0
        ? _lerpD(contactX, startX, backT)
        : _lerpD(startX, contactX, fwd);
  } else {
    tipX = _lerpD(startX, target.dx, fwd);
  }
  final speed = backT > 0
      ? backT * 0.8 + 0.2
      : (fwd > 0 && fwd < 1 ? fwd : 0.0);
  if (p >= 0.28 && (!miss || backT < 1)) {
    final wob = (!miss && p >= hitT)
        ? math.sin(p * 220) * 7 * u * (1 - _range(p, hitT, hitT + 0.2))
        : 0.0;
    _arrowShape(f, Offset(tipX, target.dy + wob), miss && backT > 0 ? -dir : dir,
        (p < hitT || backT > 0) ? speed : 0.0);
  }

  if (!miss) {
    f.flash(hitT, peak: fin ? 0.95 : 0.8, len: 0.12);
    f.flash(hitT + 0.012, color: imp.color, peak: 0.5, len: 0.25);
    f.shock(target, hitT, f.diag * (fin ? 1.0 : 0.8), width: 26);
    f.shock(target, hitT + 0.07, f.diag * (fin ? 0.8 : 0.6), width: 16);
    f.rays(target, hitT, n: fin ? 44 : 30);
    f.sparks(target, hitT, n: fin ? 90 : 55, gravity: 220);
    final coreR = 90 *
        u *
        Curves.easeOut.transform(_range(p, hitT, hitT + 0.08)) *
        (1 - _range(p, hitT + 0.05, hitT + 0.3));
    f.orb(target, coreR, 1);
    if (!imp.actor && p >= hitT) {
      f.vignette(0.65 * math.exp(-(p - hitT) * 3.5), color: imp.color);
    }
    if (fin) {
      final xs = Curves.easeOutCubic.transform(_range(p, hitT + 0.02, hitT + 0.14));
      if (xs > 0) {
        for (final sg in [-1.0, 1.0]) {
          final a0 = Offset(target.dx - w * 0.45, target.dy - sg * h * 0.38);
          final b0 = Offset(target.dx + w * 0.45, target.dy + sg * h * 0.38);
          final e = Offset.lerp(a0, b0, xs)!;
          c.drawLine(a0, e, f.stroke(0.6, width: 24 * u, blur: 14 * u, add: true));
          c.drawLine(a0, e, f.stroke(1, width: 4 * u, color: Colors.white));
        }
      }
    }
  } else {
    final dp = Offset(contactX, target.dy);
    f.flash(hitT, peak: 0.5, len: 0.12);
    f.shock(dp, hitT, f.diag * 0.5, width: 18);
    f.rays(dp, hitT, n: 20);
    f.sparks(dp, hitT, n: 40);
    final edge = Offset(imp.actor ? 0 : w, target.dy);
    f.flash(0.84, peak: 0.35, len: 0.15, color: imp.color);
    f.shock(edge, 0.84, f.diag * 0.7, width: 20);
    f.sparks(edge, 0.84, n: 50, spread: 0.8, seed: 5);
  }
}

// ---------------------------------------------------------------------------
// Cermin, perisai, penjagaan
// ---------------------------------------------------------------------------

Path _emblem(double r, bool mirror) {
  if (mirror) {
    return Path()
      ..moveTo(0, -r * 1.05)
      ..lineTo(r * 0.78, 0)
      ..lineTo(0, r * 1.05)
      ..lineTo(-r * 0.78, 0)
      ..close();
  }
  return Path()
    ..moveTo(0, -r)
    ..lineTo(r * 0.82, -r * 0.62)
    ..quadraticBezierTo(r * 0.86, r * 0.42, 0, r * 1.02)
    ..quadraticBezierTo(-r * 0.86, r * 0.42, -r * 0.82, -r * 0.62)
    ..close();
}

void _fxWard(_Fx f, NightImpact imp) {
  final p = f.p, u = f.u, w = f.w, h = f.h, c = f.c;
  final mirror = imp.effect == NightImpactEffect.mirror;
  final guard = imp.effect == NightImpactEffect.guard;
  const hitT = 0.46;
  final dirB = imp.actor ? 1.0 : -1.0;
  final startX = imp.actor ? -w * 0.2 : w * 1.2;
  final center = Offset(w * 0.5, h * 0.40);
  final appear = Curves.easeOutBack.transform(_range(p, 0, 0.26));
  final punch = p < hitT ? 0.0 : math.exp(-(p - hitT) * 9);

  f.vignette(0.4 * _range(p, 0, 0.2));

  var pos = center;
  if (guard) {
    final tr = Curves.easeOutCubic.transform(_range(p, 0, 0.3));
    pos = Offset(_lerpD(-w * 0.15, center.dx, tr), center.dy);
    if (tr < 1) {
      c.drawLine(Offset(-w * 0.15, center.dy), pos,
          f.stroke(0.5 * (1 - tr) + 0.1, width: 26 * u, blur: 14 * u, add: true));
    }
  }
  final r = 92 * u * (0.2 + 0.8 * appear) * (1 + 0.14 * punch);

  // Aura + cincin tanda berputar.
  c.drawCircle(pos, r * 1.7, f.fill(0.20 + 0.22 * punch, blur: r * 0.7, add: true));
  final tickR = r * 1.38;
  final tickA = _cl(appear);
  for (var i = 0; i < 28; i++) {
    final ang = i * 2 * math.pi / 28 + p * 2.2;
    final d = Offset(math.cos(ang), math.sin(ang));
    final len = (i % 4 == 0 ? 14 : 7) * u;
    c.drawLine(pos + d * tickR, pos + d * (tickR + len),
        f.stroke(0.7 * tickA, width: 2 * u + 0.5, add: true));
  }

  // Lambang.
  final path = _emblem(r, mirror).shift(pos);
  c.drawPath(path, f.fill(0.12 + 0.14 * punch, add: true));
  c.drawPath(path, f.stroke(0.55, width: 14 * u, blur: 9 * u, add: true));
  c.drawPath(path, f.stroke(0.95, width: 3.2 * u, color: Colors.white));
  c.drawPath(_emblem(r * 0.72, mirror).shift(pos), f.stroke(0.5, width: 1.6 * u));
  if (mirror) {
    final sx = _lerpD(-r, r, (p * 1.4) % 1.0);
    c.drawLine(pos + Offset(sx - 14 * u, r * 0.9), pos + Offset(sx + 14 * u, -r * 0.9),
        f.stroke(0.5, width: 5 * u, blur: 3 * u, color: Colors.white, add: true));
  }

  // Serangan masuk.
  const warm = Color(0xFFFF8A7A);
  final contact = pos - Offset(dirB * r * 0.95, 0);
  if (p < hitT) {
    final inT = Curves.easeIn.transform(_range(p, 0.16, hitT));
    final head = Offset(_lerpD(startX, contact.dx, inT), pos.dy);
    final tail = head - Offset(dirB * w * 0.45, 0);
    c.drawLine(tail, head, f.stroke(0.55, width: 30 * u, blur: 14 * u, color: warm, add: true));
    c.drawLine(tail, head, f.stroke(1, width: 6 * u, color: Colors.white));
  }

  // Benturan.
  f.flash(hitT, peak: 0.5, len: 0.12);
  f.flash(hitT + 0.01, color: imp.color, peak: 0.55, len: 0.22);
  f.shock(contact, hitT, f.diag * 0.9, width: 26);
  f.shock(pos, hitT + 0.05, f.diag * 0.7, width: 18);
  f.rays(contact, hitT, n: 28);
  f.sparks(contact, hitT, n: 60, gravity: 120);

  if (mirror) {
    if (p >= hitT) {
      final rT = Curves.easeIn.transform(_range(p, hitT + 0.02, 0.82));
      final head = Offset(_lerpD(contact.dx, startX, rT), pos.dy);
      final tail = head + Offset(dirB * w * 0.5 * math.min(1.0, rT * 3 + 0.2), 0);
      c.drawLine(tail, head, f.stroke(0.7, width: 34 * u, blur: 14 * u, add: true));
      c.drawLine(tail, head, f.stroke(1, width: 7 * u, color: Colors.white));
    }
    final edge = Offset(imp.actor ? 0 : w, pos.dy);
    f.flash(0.82, peak: 0.4, len: 0.15, color: imp.color);
    f.shock(edge, 0.82, f.diag * 0.7, width: 22);
    f.sparks(edge, 0.82, n: 50, spread: 0.8, seed: 9);
  } else if (p >= hitT) {
    // Serangan pecah jadi serpihan; retakan cahaya di lambang.
    final t = _range(p, hitT, hitT + 0.5);
    final base = dirB > 0 ? math.pi : 0.0;
    for (var i = 0; i < 16; i++) {
      final ang = base + (_hash(i, 31) - 0.5) * 2.2;
      final dist = (40 + 220 * _hash(i, 32)) * u * Curves.easeOutCubic.transform(t);
      final q = contact + Offset(math.cos(ang), math.sin(ang)) * dist;
      final a = 1 - t;
      c.drawLine(
        q,
        q + Offset(math.cos(ang + 1.2), math.sin(ang + 1.2)) * ((10 + 14 * _hash(i, 33)) * u),
        f.stroke(0.9 * a, width: 3 * u, color: Colors.white, add: true),
      );
    }
    for (var i = 0; i < 7; i++) {
      final ang = (_hash(i, 35) - 0.5) * 2.4 + (dirB > 0 ? 0.0 : math.pi);
      final len = r * (0.5 + 0.8 * _hash(i, 36)) * Curves.easeOut.transform(_range(t, 0, 0.4));
      c.drawLine(contact, contact + Offset(math.cos(ang), math.sin(ang)) * len,
          f.stroke(0.8 * (1 - t), width: 3 * u, blur: 2 * u, add: true));
    }
  }
}

// ---------------------------------------------------------------------------
// Embun tersedot
// ---------------------------------------------------------------------------

void _fxPump(_Fx f, NightImpact imp) {
  final p = f.p, u = f.u, w = f.w, h = f.h, c = f.c;
  final actor = imp.actor;
  final s0 = actor ? Offset(w * 0.08, h * 0.82) : Offset(w * 0.5, h * 0.48);
  final d0 = actor ? Offset(w * 0.74, h * 0.34) : Offset(w * 1.05, h * 0.10);
  final absorb = _range(p, 0.30, 0.86);
  final swell = math.sin(absorb * math.pi);

  f.vignette(0.45 * _range(p, 0, 0.2));
  f.vignette(0.30 * _range(p, 0.1, 0.4), color: imp.color);

  // Gelembung embun melayang di seluruh layar.
  final amb = _range(p, 0, 0.2);
  for (var i = 0; i < 40; i++) {
    final t = (p * 0.6 + _hash(i, 61)) % 1.0;
    final x = _hash(i, 62) * w + math.sin(t * 8 + i) * 14 * u;
    final y = h * (1.1 - t * 1.2);
    final r = (2 + 4 * _hash(i, 63)) * u;
    c.drawCircle(Offset(x, y), r,
        f.fill(0.28 * math.sin(math.pi * t) * amb, color: Colors.white, add: true));
  }

  // Pusaran di tujuan.
  for (var k = 0; k < 4; k++) {
    final rr = (40 + k * 34) * u * (0.4 + swell);
    final dirK = k.isEven ? 1.0 : -1.0;
    c.drawArc(
      Rect.fromCircle(center: d0, radius: rr),
      p * 8 * dirK + k,
      1.7,
      false,
      f.stroke(0.55 * swell, width: 3 * u + 0.5, add: true),
    );
  }

  // Tetes embun mengalir melengkung.
  final jit = actor ? 60.0 : 130.0;
  for (var i = 0; i < 34; i++) {
    final t = _range(p, 0.02 + i * 0.017, 0.62 + i * 0.017);
    if (t <= 0 || t >= 1) continue;
    final src = s0 + Offset((_hash(i, 64) - 0.5) * jit * u * 2, (_hash(i, 65) - 0.5) * jit * u * 2);
    final ctrl = Offset.lerp(src, d0, 0.5)! - Offset(0, h * (0.22 + 0.12 * _hash(i, 66)));
    final e = Curves.easeInOut.transform(t);
    final pos = _quad(src, ctrl, d0, e);
    final nxt = _quad(src, ctrl, d0, math.min(1.0, e + 0.02));
    final ang = math.atan2(nxt.dy - pos.dy, nxt.dx - pos.dx);
    final a = math.sin(math.pi * t);
    for (var k = 1; k <= 5; k++) {
      final tp = _quad(src, ctrl, d0, math.max(0.0, e - k * 0.03));
      c.drawCircle(tp, (4 - k * 0.6) * u, f.fill(a * (0.5 - 0.08 * k), add: true));
    }
    final rd = 7 * u;
    c.save();
    c.translate(pos.dx, pos.dy);
    c.rotate(ang);
    final tail = Path()
      ..moveTo(-3.2 * rd, 0)
      ..lineTo(0, -0.95 * rd)
      ..lineTo(0, 0.95 * rd)
      ..close();
    c.drawCircle(Offset.zero, rd * 1.9, f.fill(0.35 * a, blur: rd * 0.9, add: true));
    c.drawCircle(Offset.zero, rd, f.fill(a));
    c.drawPath(tail, f.fill(a));
    c.drawCircle(Offset(rd * 0.3, -rd * 0.3), rd * 0.3, f.fill(0.9 * a, color: Colors.white));
    c.restore();
  }

  // Bola penyerap.
  final pulse = 5 * u * math.sin(p * 50);
  f.orb(d0, (10 + 62 * absorb) * u * (1 - _range(p, 0.88, 0.96)) + pulse * absorb, absorb);

  f.flash(0.86, peak: 0.35, len: 0.14, color: imp.color);
  f.shock(d0, 0.86, f.diag * 0.8, width: 22);
  f.shock(d0, 0.90, f.diag * 0.55, width: 14);
  f.rays(d0, 0.86, n: 24);
  f.sparks(d0, 0.86, n: 50, spread: 0.8, gravity: 80);
}

// ---------------------------------------------------------------------------
// Kartu terbakar
// ---------------------------------------------------------------------------

void _fxBurn(_Fx f, NightImpact imp) {
  final p = f.p, u = f.u, w = f.w, h = f.h, c = f.c;
  final cw = _cardW(f.s);
  final ch = cw * 1.4;
  final center = Offset(w * 0.5, h * 0.40);
  final rect = Rect.fromCenter(center: center, width: cw, height: ch);
  final heat = Curves.easeOut.transform(_range(p, 0.22, 0.5));
  final burnT = _range(p, 0.30, 0.82);
  const orange = Color(0xFFFF7A2A);

  f.vignette(0.55 * _range(p, 0, 0.2));
  f.vignette(0.55 * heat, color: const Color(0xFFFF5A1A));
  c.drawCircle(center, cw * (0.9 + 0.6 * heat),
      f.fill(0.35 * heat, blur: cw * 0.35, color: orange, add: true));

  // Dinding api dari dasar layar.
  if (heat > 0.01) {
    final maxH = h * 0.62 * heat;
    for (var layer = 0; layer < 2; layer++) {
      final path = Path()..moveTo(0, h);
      const step = 7.0;
      final lift = layer == 0 ? 1.0 : 0.62;
      for (var x = 0.0; x <= w + step; x += step) {
        final n = 0.55 +
            0.25 * math.sin(x * 0.045 + p * 26 + layer * 1.7) +
            0.20 * math.sin(x * 0.11 - p * 41 + layer * 2.9);
        path.lineTo(x, h - maxH * lift * math.max(0.1, n));
      }
      path.lineTo(w + step, h);
      path.close();
      final cols = layer == 0
          ? [const Color(0xFFFF6A1F), const Color(0xFFD0261C), const Color(0xFFD0261C)]
          : [const Color(0xFFFFF0B0), const Color(0xFFFFA330), const Color(0xFFFF6A1F)];
      final alphas = layer == 0 ? [0.85, 0.55, 0.0] : [0.95, 0.7, 0.0];
      c.drawPath(
        path,
        Paint()
          ..blendMode = layer == 0 ? BlendMode.srcOver : BlendMode.plus
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              for (var k = 0; k < 3; k++) f.tone(cols[k], alphas[k]),
            ],
          ).createShader(Rect.fromLTWH(0, h - maxH - 1, w, maxH + 1)),
      );
    }
  }

  // Garis bakar menjalar naik di kartu.
  if (burnT > 0 && burnT < 1) {
    final y = rect.bottom - burnT * ch;
    final line = Path()..moveTo(rect.left - 10 * u, y);
    for (var i = 0; i <= 16; i++) {
      final x = rect.left - 10 * u + (cw + 20 * u) * i / 16;
      line.lineTo(x, y + math.sin(i * 1.9 + p * 70) * 5 * u);
    }
    c.drawPath(line, f.stroke(0.8, width: 18 * u, blur: 10 * u, color: orange, add: true));
    c.drawPath(line, f.stroke(1, width: 3.5 * u, color: const Color(0xFFFFF2B0)));
    for (var i = 0; i < 12; i++) {
      final fx = rect.left + cw * (i + 0.5) / 12;
      final fh = (22 + 30 * _hash(i, 41)) * u * (0.6 + 0.4 * math.sin(p * 60 + i * 2));
      final flame = Path()
        ..moveTo(fx - 7 * u, y)
        ..quadraticBezierTo(fx - 3 * u, y - fh * 0.5, fx, y - fh)
        ..quadraticBezierTo(fx + 3 * u, y - fh * 0.5, fx + 7 * u, y)
        ..close();
      c.drawPath(flame, f.fill(0.9, color: orange, add: true));
    }
  }

  // Bara api naik.
  for (var i = 0; i < 70; i++) {
    final t = (p * 1.2 + _hash(i, 42)) % 1.0;
    final x = _hash(i, 43) * w + math.sin(t * 9 + i) * 18 * u;
    final y = h * (1.05 - t * 1.15 * (0.5 + 0.5 * _hash(i, 44)));
    final r = (1 + 2.5 * _hash(i, 45)) * u * (1 - t);
    c.drawCircle(
      Offset(x, y),
      r,
      f.fill(heat * (1 - t), color: i % 3 == 0 ? const Color(0xFFFFE08A) : orange, add: true),
    );
  }

  // Abu jatuh setelah kartu hangus.
  for (var i = 0; i < 40; i++) {
    final t = _range(p, 0.55 + _hash(i, 46) * 0.1, 1.0);
    if (t <= 0) continue;
    final x = center.dx + (_hash(i, 47) - 0.5) * cw * 1.2 + math.sin(t * 6 + i) * 16 * u;
    final y = center.dy - ch * 0.3 + t * h * 0.5 * (0.6 + _hash(i, 48));
    c.drawRect(
      Rect.fromCenter(center: Offset(x, y), width: 4 * u * (1 + _hash(i, 49)), height: 2.5 * u),
      f.fill(0.7 * (1 - t), color: const Color(0xFF3A3340)),
    );
  }

  f.flash(0.30, color: orange, peak: 0.5, len: 0.12);
  f.shock(center, 0.30, f.diag * 0.6, color: orange, width: 20);
  f.flash(0.80, color: orange, peak: 0.45, len: 0.12);
  f.shock(center, 0.80, f.diag * 0.9, color: orange, width: 26);
  f.rays(center, 0.80, n: 30, color: orange);
  f.sparks(center, 0.80, n: 80, gravity: -80, color: orange);
}

// ---------------------------------------------------------------------------
// Kartu dicuri
// ---------------------------------------------------------------------------

void _fxTheft(_Fx f, NightImpact imp) {
  final p = f.p, u = f.u, c = f.c;
  final actor = imp.actor;
  final t = _theftFlight(p);
  final cw = _cardW(f.s);
  final ch = cw * 1.4;
  final startP = _theftPos(f.s, actor, 0);
  final endP = _theftPos(f.s, actor, 1);

  f.vignette(0.55 * _range(p, 0, 0.2));
  f.vignette(0.35 * _range(p, 0.05, 0.3), color: imp.color);

  // Pusaran menarik di titik asal kartu.
  final pullA = _range(p, 0.05, 0.3) * (1 - _range(p, 0.4, 0.6));
  if (pullA > 0.01) {
    for (var k = 0; k < 3; k++) {
      final rr = (60 + k * 30) * u * (1.3 - pullA * 0.3);
      c.drawArc(
        Rect.fromCircle(center: startP, radius: rr),
        p * 7 * (k.isEven ? 1 : -1) + k * 2,
        1.8,
        false,
        f.stroke(0.6 * pullA, width: 3 * u + 0.5, add: true),
      );
    }
  }

  // Bayangan sisa kartu di sepanjang lintasan.
  final trailFade = 1 - _range(p, 0.62, 0.75);
  if (t > 0) {
    for (var k = 1; k <= 8; k++) {
      final tt = t - k * 0.045;
      if (tt <= 0) continue;
      final pos = _theftPos(f.s, actor, tt);
      final a = (1 - k / 9) * 0.5 * trailFade;
      final sc = _theftScale(actor, tt);
      c.save();
      c.translate(pos.dx, pos.dy);
      c.rotate(_theftAngle(actor, tt));
      final rr = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: cw * 0.9 * sc, height: ch * 0.9 * sc),
        Radius.circular(10 * u),
      );
      c.drawRRect(rr, f.stroke(a, width: 3 * u, blur: 3 * u, add: true));
      c.restore();
    }
  }

  // Pita asap berkelok mengikuti kartu.
  if (t > 0.01 && t < 0.995) {
    for (var r = 0; r < 3; r++) {
      final path = Path();
      final t0 = math.max(0.0, t - 0.35);
      const steps = 28;
      for (var i = 0; i <= steps; i++) {
        final tt = _lerpD(t0, t, i / steps);
        final a = _theftPos(f.s, actor, tt);
        final b = _theftPos(f.s, actor, math.min(1.0, tt + 0.01));
        final dx = b.dx - a.dx, dy = b.dy - a.dy;
        final len = math.max(0.001, math.sqrt(dx * dx + dy * dy));
        final off = math.sin(tt * 16 + p * 25 + r * 2.1) * (16 + 8 * r) * u;
        final q = a + Offset(-dy / len, dx / len) * off;
        if (i == 0) {
          path.moveTo(q.dx, q.dy);
        } else {
          path.lineTo(q.dx, q.dy);
        }
      }
      c.drawPath(path, f.stroke(0.55, width: 3 * u, blur: 2 * u, add: true));
    }
  }

  // Dirampas dari titik asal.
  f.flash(0.28, peak: 0.55, len: 0.12, color: imp.color);
  f.shock(startP, 0.28, f.diag * 0.55, width: 18);
  f.rays(startP, 0.28, n: 22);
  f.sparks(startP, 0.28, n: 40);
  if (!actor && p >= 0.28) {
    f.vignette(0.45 * math.exp(-(p - 0.28) * 3.0), color: const Color(0xFFFF4A5A));
  }

  // Tiba di tujuan.
  f.flash(0.62, peak: 0.4, len: 0.14, color: imp.color);
  f.shock(endP, 0.62, f.diag * 0.7, width: 20);
  f.rays(endP, 0.62, n: 26);
  f.sparks(endP, 0.62, n: 60, spread: 0.8, gravity: 100, seed: 3);
}

// ---------------------------------------------------------------------------
// Klinik: pemulihan & jebakan
// ---------------------------------------------------------------------------

void _fxHeal(_Fx f, NightImpact imp) {
  final p = f.p, u = f.u, w = f.w, h = f.h, c = f.c;
  final center = Offset(w * 0.5, h * 0.40);
  const hitT = 0.36;
  final punch = p < hitT ? 0.0 : math.exp(-(p - hitT) * 8);

  f.vignette(0.4 * _range(p, 0, 0.2));
  f.vignette(0.35 * _range(p, 0.1, 0.4), color: imp.color);

  // Sinar cahaya dari bawah.
  final rayA = _range(p, 0.05, 0.4);
  for (var i = 0; i < 9; i++) {
    final x = w * (i + 0.5) / 9;
    final sway = math.sin(p * 3 + i) * 20 * u;
    c.drawLine(
      Offset(x, h * 1.05),
      Offset(x + (i - 4) * 24 * u + sway, -h * 0.05),
      f.stroke(0.16 * rayA * (0.6 + 0.4 * math.sin(p * 8 + i * 1.3)),
          width: 40 * u, blur: 26 * u, add: true),
    );
  }

  // Tanda tambah raksasa.
  final appear = Curves.easeOutBack.transform(_range(p, 0.06, 0.34));
  final r = 80 * u * appear * (1 + 0.12 * punch);
  if (r > 1) {
    final th = r * 0.36;
    Path plus(double k) => Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: r * 2 * k, height: th * 2 * k),
          Radius.circular(th * 0.5 * k)))
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: th * 2 * k, height: r * 2 * k),
          Radius.circular(th * 0.5 * k)));
    c.drawCircle(center, r * 2, f.fill(0.25 + 0.25 * punch, blur: r * 0.8, add: true));
    c.drawPath(plus(1.0), f.fill(0.8, blur: 10 * u, add: true));
    c.drawPath(plus(1.0), f.fill(0.9));
    c.drawPath(plus(0.7), f.fill(0.95, color: Colors.white));
  }

  f.flash(hitT, color: imp.color, peak: 0.6, len: 0.14);
  f.shock(center, hitT, f.diag * 0.8, width: 22);
  f.shock(center, 0.50, f.diag * 0.7, width: 18);
  f.shock(center, 0.64, f.diag * 0.6, width: 14);
  f.rays(center, hitT, n: 30);

  // Tanda tambah kecil naik ke seluruh layar.
  final on = _range(p, 0.16, 0.3);
  for (var i = 0; i < 42; i++) {
    final t = (p * 1.15 + _hash(i, 51)) % 1.0;
    final x = _hash(i, 52) * w;
    final y = h * (1.05 - t * 1.2);
    final sz = (5 + 9 * _hash(i, 53)) * u;
    final a = math.sin(math.pi * t) * 0.85 * on;
    final colr = i % 3 == 0 ? Colors.white : null;
    final pa = f.stroke(a, width: 2 * u + 0.6, color: colr, add: true);
    c.drawLine(Offset(x - sz, y), Offset(x + sz, y), pa);
    c.drawLine(Offset(x, y - sz), Offset(x, y + sz), pa);
  }
}

void _fxTrap(_Fx f, NightImpact imp) {
  final p = f.p, u = f.u, w = f.w, h = f.h, c = f.c;
  const hitT = 0.36;
  final seam = Offset(w * 0.5, h * 0.5);

  f.vignette(0.6 * _range(p, 0, 0.18));
  f.bars(Curves.easeOut.transform(_range(p, 0, 0.1)));

  final k = Curves.easeInCubic.transform(_range(p, 0.12, hitT));
  final bounce = p >= hitT
      ? math.sin((p - hitT) * 45) * math.exp(-(p - hitT) * 10) * 0.03
      : 0.0;
  final topEdge = _lerpD(-h * 0.12, h * 0.5 - 4 * u, k) - bounce * h;
  final botEdge = _lerpD(h * 1.12, h * 0.5 + 4 * u, k) + bounce * h;
  const teeth = 9;
  final tw = w / teeth;
  final th = h * 0.09;

  final top = Path()
    ..moveTo(0, topEdge - h)
    ..lineTo(w, topEdge - h)
    ..lineTo(w, topEdge);
  for (var i = teeth - 1; i >= 0; i--) {
    top
      ..lineTo(i * tw + tw * 0.5, topEdge + th)
      ..lineTo(i * tw, topEdge);
  }
  top.close();
  final bot = Path()
    ..moveTo(0, botEdge + h)
    ..lineTo(w, botEdge + h)
    ..lineTo(w, botEdge);
  for (var i = teeth; i >= 0; i--) {
    bot
      ..lineTo(i * tw, botEdge - th)
      ..lineTo(i * tw - tw * 0.5, botEdge);
  }
  bot.close();
  const jaw = Color(0xFF2A0A10);
  for (final path in [top, bot]) {
    c.drawPath(path, f.fill(0.94, color: jaw));
    c.drawPath(path, f.stroke(0.9, width: 4 * u, blur: 5 * u, add: true));
    c.drawPath(path, f.stroke(0.9, width: 1.6 * u, color: Colors.white));
  }

  f.flash(hitT, peak: 0.9, len: 0.10);
  f.flash(hitT + 0.01, color: imp.color, peak: 0.6, len: 0.22);
  f.shock(seam, hitT, f.diag, width: 30);
  f.shock(seam, hitT + 0.07, f.diag * 0.7, width: 18);
  f.rays(seam, hitT, n: 40);
  for (var i = 0; i < 3; i++) {
    f.sparks(Offset(w * (0.15 + 0.35 * i), seam.dy), hitT,
        n: 40, gravity: 200, seed: i * 13);
  }
  if (p >= hitT) {
    f.vignette(0.7 * math.exp(-(p - hitT) * 2.5), color: imp.color);
    // Retakan menjalar dari garis rahang.
    final grow = Curves.easeOutCubic.transform(_range(p, hitT, hitT + 0.15));
    for (var i = 0; i < 8; i++) {
      final path = Path()..moveTo(seam.dx, seam.dy);
      var x = seam.dx, y = seam.dy;
      final ang = (i / 8) * 2 * math.pi + _hash(i, 71);
      const steps = 8;
      final len = f.diag * 0.5 * grow / steps;
      for (var s = 0; s < steps; s++) {
        final a = ang + (_hash(i * 9 + s, 72) - 0.5) * 0.9;
        x += math.cos(a) * len;
        y += math.sin(a) * len;
        path.lineTo(x, y);
      }
      c.drawPath(path, f.stroke(0.7, width: 8 * u, blur: 6 * u, add: true));
      c.drawPath(path, f.stroke(0.9, width: 1.8 * u, color: Colors.white));
    }
  }
}

// ---------------------------------------------------------------------------
// Tak ada dampak
// ---------------------------------------------------------------------------

void _fxNull(_Fx f, NightImpact imp) {
  final p = f.p, u = f.u, w = f.w, h = f.h, c = f.c;
  final center = Offset(w * 0.5, h * 0.40);
  f.vignette(0.5 * _range(p, 0, 0.25));
  final shrink = Curves.easeInCubic.transform(_range(p, 0, 0.34));
  final radius = _lerpD(f.diag * 0.55, 64 * u, shrink);
  c.drawCircle(center, radius,
      f.stroke(0.6 * (1 - shrink * 0.3), width: 4 * u, blur: 6 * u, add: true));
  c.drawCircle(center, radius, f.stroke(0.8, width: 1.5 * u + 0.5, color: Colors.white));

  final xa = Curves.easeOut.transform(_range(p, 0.30, 0.44));
  if (xa > 0) {
    final shake = p > 0.34 ? math.sin(p * 180) * 5 * u * (1 - _range(p, 0.34, 0.5)) : 0.0;
    for (final sg in [-1.0, 1.0]) {
      final a = center + Offset(-50 * u + shake, -50 * u * sg);
      final b = center + Offset(50 * u + shake, 50 * u * sg);
      final e = Offset.lerp(a, b, xa)!;
      c.drawLine(a, e, f.stroke(0.5, width: 22 * u, blur: 12 * u, add: true));
      c.drawLine(a, e, f.stroke(1, width: 5 * u, color: Colors.white));
    }
  }
  f.shock(center, 0.34, f.diag * 0.35, width: 8);
  f.sparks(center, 0.34, n: 24, spread: 0.5, gravity: 160);
}