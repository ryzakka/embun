import 'package:flutter/material.dart';

import '../common/art.dart';
import '../common/ornate.dart';
import 'countdown.dart';

BoxDecoration daySurface(Color accent, {double radius = 18}) => BoxDecoration(
  color: accent == EmbunColors.mist
      ? const Color(0xF2191525)
      : const Color(0xF20B1C17),
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: accent.withValues(alpha: 0.24)),
);

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
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final singleLine = box.maxWidth >= (short ? 600 : 840);
      final showParts = box.maxWidth >= (singleLine ? 780 : 402);
      final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
      final fullOffering = singleLine && box.maxWidth >= 950 && scale <= 1.35;
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
              message: offering,
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
                    if (!short)
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
              message: 'Pohon Hayu · $leaves daun, target akhir $winLeaves',
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
          if (worms > 0)
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
        ],
      );
      final divider = Divider(height: 1, color: accent.withValues(alpha: 0.2));

      return Container(
        decoration: daySurface(accent),
        padding: EdgeInsets.symmetric(
          horizontal: singleLine ? 12 : 8,
          vertical: short ? 2 : 5,
        ),
        child: singleLine
            ? Row(
                children: [
                  Expanded(flex: short ? 5 : 6, child: actionRow),
                  SizedBox(
                    height: 32,
                    child: VerticalDivider(
                      width: 20,
                      color: accent.withValues(alpha: 0.25),
                    ),
                  ),
                  Expanded(flex: short ? 6 : 5, child: statusRow),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  actionRow,
                  if (!short) const SizedBox(height: 3),
                  divider,
                  statusRow,
                ],
              ),
      );
    },
  );
}
