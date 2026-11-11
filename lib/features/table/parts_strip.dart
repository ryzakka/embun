import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/asset_catalog.dart';
import '../../data/game_rules.dart';
import '../../data/hayu_effects.dart';
import '../common/art.dart';
import 'day_chrome.dart';

/// Lencana kondisi dengan cincin tipis dan gambar yang terpusat.
class PartBadge extends StatelessWidget {
  const PartBadge(this.part, this.cond, {super.key, this.size = 28});

  final String part;
  final String cond;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tone = PartsStrip.colorOf(cond);
    final path = sceneryPath('pohonindikator-$part');
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [tone.withValues(alpha: 0.21), const Color(0xFF10231E)],
        ),
        border: Border.all(color: tone.withValues(alpha: 0.58)),
      ),
      child: path == null
          ? Icon(PartsStrip.fallbackIcon(part), size: size * 0.62, color: tone)
          : ClipOval(
              child: GameImage(path: path, cacheWidth: (size * 3).round()),
            ),
    );
  }
}

/// Akar, Batang, dan Tanah memakai lebar serta susunan yang seragam.
class PartsStrip extends StatelessWidget {
  const PartsStrip({super.key, required this.effects, required this.onTap});

  final HayuEffects effects;
  final VoidCallback onTap;

  static Color colorOf(String c) => switch (c) {
    'prima' => const Color(0xFF5DE5C3),
    'kuat' => const Color(0xFF79E8AB),
    'subur' => const Color(0xFF87E1A0),
    'tumbuh' => const Color(0xFFB5DC8D),
    'layu' => const Color(0xFFFFCB73),
    'rapuh' => const Color(0xFFF9AE79),
    'rusak' => const Color(0xFFFF9A92),
    'kritis' => const Color(0xFFFF7288),
    _ => const Color(0xFFACBEB4),
  };

  static IconData fallbackIcon(String part) => switch (part) {
    'akar' => Icons.water_drop,
    'batang' => Icons.park,
    'daun' => Icons.eco,
    _ => Icons.landscape,
  };

  static String partName(String part) => switch (part) {
    'akar' => 'Akar',
    'batang' => 'Batang',
    'daun' => 'Daun',
    _ => 'Tanah',
  };

  Widget _metric({
    required Widget icon,
    required String amount,
    required Color tone,
  }) => Row(
    children: [
      icon,
      const SizedBox(width: 5),
      Expanded(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            amount,
            style: dayMetricValue.copyWith(fontSize: 15, color: tone),
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final root = '${hayuAmount(effects.akar.akarPercent, signed: true)}%';
    final shield = hayuAmount(effects.batang.batangShield, signed: true);
    final fog = hayuAmount(effects.tanah.tanahFog, signed: true);
    final leaves = '${effects.leaves}/${effects.winLeaves}';
    final change = effects.leavesChange ?? 0;
    final delta = change == 0 ? '' : ' ${hayuAmount(change, signed: true)}';
    final leafTone = effects.expandedRules
        ? colorOf(effects.leafLevel.name)
        : const Color(0xFF7BD88F);

    return Semantics(
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      label:
          'Dampak Hayu. Daun $leaves$delta, ${effects.leafLevel.label}. '
          'Akar ${_partReading(effects.akar)}, $root embun. '
          'Batang ${_partReading(effects.batang)}, $shield perlindungan. '
          'Tanah ${_partReading(effects.tanah)}, $fog kabut.',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: LayoutBuilder(
          builder: (context, box) {
            final size = box.maxWidth < 340 ? 30.0 : 38.0;
            final entries = [
              _metric(
                icon: _HayuRing(
                  value: effects.leaves.clamp(0, kLeavesMax) / kLeavesMax,
                  tone: leafTone,
                  size: size,
                  mark: effects.winLeaves.clamp(0, kLeavesMax) / kLeavesMax,
                  child: GameIcon('helaidaun', size: size * 0.64),
                ),
                amount: leaves,
                tone: leafTone,
              ),
              for (final (part, condition, amount) in [
                ('akar', effects.akar, root),
                ('batang', effects.batang, shield),
                ('tanah', effects.tanah, fog),
              ])
                _metric(
                  icon: _partRing(part, condition, size: size),
                  amount: amount,
                  tone: colorOf(condition.toneKey),
                ),
            ];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (var i = 0; i < entries.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(child: entries[i]),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

String _partReading(HayuPartStatus part) => part.score == null
    ? part.label
    : '${hayuAmount(part.score!, signed: true)} · ${part.label}';

Widget _partRing(String name, HayuPartStatus part, {double size = 44}) =>
    _HayuRing(
      value: part.score == null
          ? switch (part.condition) {
              HayuCondition.subur => 0.5,
              HayuCondition.biasa => 0.0,
              HayuCondition.layu => -0.5,
              HayuCondition.rusak => -1.0,
            }
          : part.score! / kHayuPartMax,
      tone: PartsStrip.colorOf(part.toneKey),
      size: size,
      child: PartBadge(name, part.toneKey, size: size * 0.70),
    );

class _HayuRing extends StatelessWidget {
  const _HayuRing({
    required this.value,
    required this.tone,
    required this.size,
    required this.child,
    this.mark,
  });

  final double value;
  final Color tone;
  final double size;
  final Widget child;
  final double? mark;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: value.clamp(-1.0, 1.0)),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 480),
    curve: Curves.easeOutCubic,
    child: Center(child: child),
    builder: (context, progress, child) => SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(progress, tone, mark),
        child: child,
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.value, this.tone, this.mark);

  final double value;
  final Color tone;
  final double? mark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.12);
    canvas.drawCircle(center, radius, track);
    final arc = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      arc,
      -math.pi / 2,
      value * math.pi * 2,
      false,
      track..color = tone,
    );
    final marker = mark ?? 0;
    final angle = marker * math.pi * 2 - math.pi / 2;
    final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    canvas.drawCircle(point, 1.6, Paint()..color = const Color(0xFFECE3C2));
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.tone != tone || old.mark != mark;
}

/// Rincian Hayu dari kondisi publik dan, bila tersedia, laju pribadi pemain.
Future<void> showPartsSheet(
  BuildContext context, {
  required HayuEffects effects,
  int? offeringIn,
}) {
  final change = effects.leavesChange;
  final root = '${hayuAmount(effects.akar.akarPercent, signed: true)}%';
  final shield = hayuAmount(effects.batang.batangShield, signed: true);
  final fog = hayuAmount(effects.tanah.tanahFog, signed: true);
  final missing = effects.missingLeaves;
  final removed = effects.tanah.extraWormRemoval;
  final spawned = effects.tanah.extraWormSpawn;
  final damageLoss = effects.damageLeafLoss;
  final leafTone = effects.expandedRules
      ? PartsStrip.colorOf(effects.leafLevel.name)
      : const Color(0xFF7BD88F);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF121812),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, sc) => ListView(
        controller: sc,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          const Center(
            child: Text(
              'Dampak Hayu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              effects.expandedRules
                  ? 'Akar, Batang, dan Tanah bergerak dari −8 sampai +8. Cincin bergerak searah jarum jam untuk nilai positif dan berlawanan untuk nilai negatif. '
                        'Setiap dua persembahan, bagian yang belum Rusak atau Kritis bergeser satu poin ke 0.'
                  : 'Angka menunjukkan dampak dari kondisi saat ini.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
          ),
          const SizedBox(height: 12),
          if (offeringIn != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                offeringIn == 0
                    ? 'Persembahan malam ini'
                    : 'Persembahan $offeringIn hari lagi',
                style: dayCaption,
                textAlign: TextAlign.center,
              ),
            ),
          if (effects.income case final income?) _IncomeBreakdown(income),
          if (damageLoss > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '−$damageLoss daun jika kondisi rusak ini bertahan sampai awal persembahan.',
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ),
          _PartCard(
            zoom: 'pohonindikator-zoomdedaunan',
            badge: _HayuRing(
              size: 44,
              value: effects.leaves.clamp(0, kLeavesMax) / kLeavesMax,
              tone: leafTone,
              mark: effects.winLeaves.clamp(0, kLeavesMax) / kLeavesMax,
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: GameImage(
                  path: sceneryPath('pohonindikator-daun'),
                  fit: BoxFit.contain,
                  cacheWidth: 132,
                ),
              ),
            ),
            title: 'Daun',
            status:
                '${effects.leaves}/${effects.winLeaves}'
                '${effects.expandedRules ? ' · ${effects.leafLevel.label}' : ''}',
            color: leafTone,
            desc: missing == 0
                ? 'Target akhir tercapai. $kLeavesMax daun untuk menang langsung.'
                : 'Kurang $missing daun untuk target akhir. '
                      '$kLeavesMax daun untuk menang langsung.',
            effect: [
              if (change != null)
                change == 0
                    ? 'Daun tetap setelah persembahan.'
                    : '${hayuAmount(change, signed: true)} daun bersih setelah persembahan.',
              if (effects.worms > 0)
                '${effects.worms} ulat tersisa · −1 daun pada persembahan berikutnya jika masih ada ulat.',
              if (effects.income?.isAntagonist == true)
                '${hayuAmount(effects.antagonistLeavesBonus, signed: true)} bulir hitam per hari. '
                    '${effects.expandedRules ? 'Naik +0,5 tiap 5 daun.' : 'Naik +1 tiap 10 daun.'}',
            ].join('\n'),
          ),
          _PartCard(
            zoom: 'pohonindikator-zoomakar',
            badge: _partRing('akar', effects.akar),
            title: 'Akar',
            status: _partReading(effects.akar),
            color: PartsStrip.colorOf(effects.akar.toneKey),
            desc: effects.expandedRules
                ? 'Tiap poin menggeser laju embun Warga sebesar 6 poin persentase setelah penalti laju.'
                : 'Pengali laju embun Warga setelah penalti laju.',
            effect: '$root embun harian Warga',
          ),
          _PartCard(
            zoom: 'pohonindikator-zoombatang',
            badge: _partRing('batang', effects.batang),
            title: 'Batang',
            status: _partReading(effects.batang),
            color: PartsStrip.colorOf(effects.batang.toneKey),
            desc: effects.expandedRules
                ? 'Tiap dua poin menggeser satu perisai. Dihitung saat persembahan mulai, selama perlindungan belum dilucuti.'
                : 'Berlaku saat persembahan jika perlindungan tidak dilucuti. Perlindungan paling rendah 0.',
            effect: '$shield perlindungan',
          ),
          _PartCard(
            zoom: 'pohonindikator-zoomtanah',
            badge: _partRing('tanah', effects.tanah),
            title: 'Tanah',
            status: _partReading(effects.tanah),
            color: PartsStrip.colorOf(effects.tanah.toneKey),
            desc: effects.expandedRules
                ? 'Tiap dua poin menggeser satu kabut. Kabut dihitung dari kondisi awal persembahan.'
                : 'Kondisi awal persembahan mengubah kabut yang menggerogoti daun.',
            effect: [
              '$fog kabut pada malam persembahan',
              if (removed > 0) 'Hingga $removed ulat senyap tambahan hilang.',
              if (spawned > 0)
                'Kartu penambah ulat membawa $spawned ulat tambahan.',
            ].join('\n'),
          ),
        ],
      ),
    ),
  );
}

class _IncomeBreakdown extends StatelessWidget {
  const _IncomeBreakdown(this.income);

  final HayuIncome income;

  @override
  Widget build(BuildContext context) {
    final color = income.isAntagonist
        ? const Color(0xFFC6A5F2)
        : const Color(0xFF7BD88F);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Perkiraan pemasukan hari ${income.day}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            '${hayuAmount(income.total, signed: true)} ${income.currency}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          for (final (label, amount) in income.components)
            Row(
              children: [
                Expanded(child: Text(label)),
                Text(
                  hayuAmount(amount, signed: true),
                  style: TextStyle(
                    color: amount < 0 ? Colors.orangeAccent : color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 4),
          const Text(
            'Perkiraan berlaku jika kondisi dan laju saat ini bertahan.',
            style: TextStyle(fontSize: 11, color: Colors.white60),
          ),
        ],
      ),
    );
  }
}

class _PartCard extends StatelessWidget {
  final String zoom;
  final Widget badge;
  final String title;
  final String status;
  final Color color;
  final String desc;
  final String effect;
  const _PartCard({
    required this.zoom,
    required this.badge,
    required this.title,
    required this.status,
    required this.color,
    required this.desc,
    required this.effect,
  });

  @override
  Widget build(BuildContext context) {
    final z = sceneryPath(zoom);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: GameImage(path: z, cacheWidth: 900)),
          Positioned.fill(
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.62)),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                badge,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            status,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        desc,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                      if (effect.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          effect,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
