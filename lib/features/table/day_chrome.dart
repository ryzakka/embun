import 'package:flutter/material.dart';

import '../common/art.dart';
import '../common/ornate.dart';
import 'countdown.dart';

const dayOverline = TextStyle(
  color: Color(0xFFB8C6B6),
  fontSize: 10,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.35,
);

const dayCaption = TextStyle(
  color: Color(0xFFBBC7B8),
  fontSize: 12,
  height: 1.3,
);

/// Garis pemisah di meja yang menyatu dengan latar permainan.
BoxDecoration tableEdge(
  Color accent, {
  bool vertical = false,
  bool top = false,
}) {
  final line = BorderSide(color: accent.withValues(alpha: 0.32));
  return BoxDecoration(
    border: vertical
        ? Border(left: line)
        : top
        ? Border(top: line)
        : Border(bottom: line),
  );
}

class DayTableHeader extends StatelessWidget {
  final Color accent;
  final int day;
  final int leaves;
  final int winLeaves;
  final int worms;
  final int offeringIn;
  final DateTime? deadline;
  final int ready;
  final int total;
  final bool short;
  final Widget identity;
  final Widget balance;
  final List<Widget> tools;
  final Widget parts;
  final VoidCallback onPlayers;
  final VoidCallback onHayu;
  final Widget? village;
  final GlobalKey? playersKey;
  final bool showOffering;

  const DayTableHeader({
    super.key,
    required this.accent,
    required this.day,
    required this.leaves,
    required this.winLeaves,
    required this.worms,
    required this.offeringIn,
    required this.deadline,
    required this.ready,
    required this.total,
    required this.short,
    required this.identity,
    required this.balance,
    required this.tools,
    required this.parts,
    required this.onPlayers,
    required this.onHayu,
    this.village,
    this.playersKey,
    this.showOffering = true,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final singleLine = box.maxWidth >= (short ? 620 : 940);
      final inlineVillage =
          village != null && box.maxWidth >= (singleLine ? 1010 : 475);
      final showParts =
          box.maxWidth >= (inlineVillage ? 1100 : (singleLine ? 800 : 402));
      final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
      final showWorms = box.maxWidth >= 355 || scale <= 1.25;
      final fullOffering = singleLine && box.maxWidth >= 1050 && scale <= 1.35;
      final shortOffering = offeringIn == 0
          ? 'Malam ini'
          : '$offeringIn hari lagi';
      final offering = offeringIn == 0
          ? 'Persembahan malam ini'
          : 'Persembahan $shortOffering';
      final actionRow = Row(
        children: [
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: identity),
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 96),
            child: balance,
          ),
          const SizedBox(width: 3),
          ...tools,
        ],
      );
      final statusRow = Row(
        children: [
          Expanded(
            flex: fullOffering ? 2 : 1,
            child: Tooltip(
              message: showOffering ? offering : 'Hari $day',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HARI $day',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: dayOverline.copyWith(color: accent),
                    ),
                    if (showOffering && !short)
                      Text(
                        fullOffering ? offering : shortOffering,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: dayCaption.copyWith(fontSize: 11),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Flexible(
            flex: 1,
            child: Tooltip(
              message:
                  'Pohon Hayu · $leaves daun, target akhir $winLeaves'
                  '${worms > 0 ? ' · $worms ulat senyap' : ''}',
              child: InkWell(
                onTap: onHayu,
                borderRadius: BorderRadius.circular(9),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const GameIcon('helaidaun', size: 18),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hayu',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: dayCaption.copyWith(fontSize: 10),
                            ),
                            Text(
                              '$leaves/$winLeaves',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                color: EmbunColors.leaf,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (showParts) parts,
          if (worms > 0 && showWorms)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Tooltip(
                message: '$worms ulat senyap',
                child: Text(
                  'Ulat $worms',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          if (deadline != null) ...[
            const SizedBox(width: 3),
            Countdown(
              deadline: deadline,
              compact: true,
              style: const TextStyle(fontSize: 12),
            ),
          ],
          const SizedBox(width: 3),
          Tooltip(
            message: 'Daftar warga · $ready dari $total siap',
            child: InkWell(
              key: playersKey,
              onTap: onPlayers,
              borderRadius: BorderRadius.circular(9),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const GameIcon('persona', size: 18),
                    const SizedBox(width: 3),
                    Text(
                      '$ready/$total',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: EmbunColors.cream,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!inlineVillage && village != null)
            SizedBox(width: 38, child: village),
        ],
      );

      final embeddedWidth = (box.maxWidth * (singleLine ? 0.24 : 0.30)).clamp(
        125.0,
        325.0,
      );
      final roster = inlineVillage
          ? SizedBox(width: embeddedWidth, child: village)
          : null;
      return DecoratedBox(
        decoration: tableEdge(accent),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: singleLine
              ? Row(
                  children: [
                    Expanded(flex: 5, child: actionRow),
                    if (roster != null) ...[const SizedBox(width: 8), roster],
                    const SizedBox(width: 8),
                    Expanded(flex: 6, child: statusRow),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    actionRow,
                    if (roster == null)
                      statusRow
                    else
                      Row(
                        children: [
                          Expanded(child: statusRow),
                          roster,
                        ],
                      ),
                  ],
                ),
        ),
      );
    },
  );
}
