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
        border: Border.all(color: tone.withValues(alpha: 0.76)),
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
    'subur' => const Color(0xFF87E1A0),
    'layu' => const Color(0xFFFFCB73),
    'rusak' => const Color(0xFFFF9A92),
    _ => const Color(0xFFACBEB4),
  };

  static IconData fallbackIcon(String part) => switch (part) {
    'akar' => Icons.water_drop,
    'batang' => Icons.park,
    _ => Icons.landscape,
  };

  static String partName(String part) => switch (part) {
    'akar' => 'Akar',
    'batang' => 'Batang',
    _ => 'Tanah',
  };

  Widget _one(
    String part,
    HayuCondition condition,
    String amount,
    String impact, {
    required bool inline,
  }) {
    final name = partName(part);
    final badge = PartBadge(part, condition.name, size: inline ? 27 : 24);
    final label = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: inline
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(name, style: dayCaption.copyWith(fontSize: 10)),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            amount,
            style: dayMetricValue.copyWith(
              fontSize: 15,
              color: colorOf(condition.name),
            ),
          ),
        ),
      ],
    );
    return Tooltip(
      message: '$name ${condition.name} · $impact',
      child: inline
          ? Row(
              children: [
                badge,
                const SizedBox(width: 5),
                Expanded(child: label),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [badge, const SizedBox(height: 3), label],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final root = '${hayuAmount(effects.akar.akarPercent, signed: true)}%';
    final shield = hayuAmount(effects.batang.batangShield, signed: true);
    final fog = hayuAmount(effects.tanah.tanahFog, signed: true);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: LayoutBuilder(
        builder: (context, box) {
          final inline = box.maxWidth >= 162;
          final entries = [
            _one(
              'akar',
              effects.akar,
              root,
              '$root laju embun Warga',
              inline: inline,
            ),
            _one(
              'batang',
              effects.batang,
              shield,
              '$shield perlindungan',
              inline: inline,
            ),
            _one('tanah', effects.tanah, fog, '$fog kabut', inline: inline),
          ];
          return Row(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0) const SizedBox(width: 3),
                Expanded(child: entries[i]),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Rincian Hayu dari kondisi publik dan, bila tersedia, laju pribadi pemain.
Future<void> showPartsSheet(
  BuildContext context, {
  required HayuEffects effects,
}) {
  final change = effects.leavesChange;
  final root = '${hayuAmount(effects.akar.akarPercent, signed: true)}%';
  final shield = hayuAmount(effects.batang.batangShield, signed: true);
  final fog = hayuAmount(effects.tanah.tanahFog, signed: true);
  final missing = effects.missingLeaves;
  final soilNote = switch (effects.tanah) {
    HayuCondition.subur =>
      'Hingga 1 ulat senyap tambahan hilang saat persembahan.',
    HayuCondition.rusak => 'Kartu yang menambah ulat menambah 1 ulat lagi.',
    _ => 'Berlaku saat malam persembahan.',
  };
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
          const Center(
            child: Text(
              'Angka menunjukkan dampak dari kondisi saat ini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.white60),
            ),
          ),
          const SizedBox(height: 12),
          if (effects.income case final income?) _IncomeBreakdown(income),
          if (effects.losesLeafOnOffering)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                '−1 daun saat persembahan jika dua bagian atau lebih masih rusak.',
                style: TextStyle(color: Colors.orangeAccent),
              ),
            ),
          _PartCard(
            zoom: 'pohonindikator-zoomdedaunan',
            badge: SizedBox(
              width: 44,
              height: 44,
              child: GameImage(
                path: sceneryPath('pohonindikator-daun'),
                fit: BoxFit.contain,
                cacheWidth: 132,
              ),
            ),
            title: 'Daun',
            status: '${effects.leaves}/${effects.winLeaves}',
            color: const Color(0xFF7BD88F),
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
                '${hayuAmount(effects.antagonistLeavesBonus, signed: true)} bulir hitam per hari · +1 tiap 10 daun.',
            ].join('\n'),
          ),
          _PartCard(
            zoom: 'pohonindikator-zoomakar',
            badge: PartBadge('akar', effects.akar.name, size: 44),
            title: 'Akar',
            status: effects.akar.name,
            color: PartsStrip.colorOf(effects.akar.name),
            desc: 'Pengali laju embun Warga setelah penalti laju.',
            effect: '$root embun harian Warga',
          ),
          _PartCard(
            zoom: 'pohonindikator-zoombatang',
            badge: PartBadge('batang', effects.batang.name, size: 44),
            title: 'Batang',
            status: effects.batang.name,
            color: PartsStrip.colorOf(effects.batang.name),
            desc:
                'Berlaku saat persembahan jika perlindungan tidak dilucuti. '
                'Perlindungan paling rendah 0.',
            effect: '$shield perlindungan',
          ),
          _PartCard(
            zoom: 'pohonindikator-zoomtanah',
            badge: PartBadge('tanah', effects.tanah.name, size: 44),
            title: 'Tanah',
            status: effects.tanah.name,
            color: PartsStrip.colorOf(effects.tanah.name),
            desc: '$soilNote Kabut menggerogoti daun Hayu.',
            effect: '$fog kabut pada malam persembahan',
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
