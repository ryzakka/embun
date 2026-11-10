import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../data/hayu_effects.dart';
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

const dayMetricValue = TextStyle(
  fontSize: 27,
  height: 1,
  fontWeight: FontWeight.w800,
  fontFeatures: [FontFeature.tabularFigures()],
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
  final int? leavesChange;
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
    this.leavesChange,
    required this.onPlayers,
    required this.onHayu,
    this.village,
    this.playersKey,
    this.showOffering = true,
  });

  Widget _rule(double height) => Container(
    width: 1,
    height: height,
    color: accent.withValues(alpha: 0.20),
  );

  Widget _dayMetric({required bool wide}) => SizedBox(
    width: wide ? 68 : 44,
    child: Semantics(
      label: 'Hari $day',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HARI', style: dayOverline.copyWith(color: accent)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              day.toString().padLeft(2, '0'),
              style: dayMetricValue.copyWith(
                fontSize: short ? 25 : 31,
                color: EmbunColors.cream,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _hayuRow() {
    final change = leavesChange;
    final delta = change == null || change == 0
        ? null
        : hayuAmount(change, signed: true);
    return Row(
      children: [
        Tooltip(
          message:
              'Pohon Hayu · $leaves daun, target akhir $winLeaves'
              '${delta == null ? '' : ' · $delta daun setelah persembahan'}'
              '${worms == 0 ? '' : ' · $worms ulat senyap'}',
          child: InkWell(
            onTap: onHayu,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GameIcon('helaidaun', size: 23),
                  const SizedBox(width: 5),
                  SizedBox(
                    width: 46,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            delta == null ? 'Hayu' : 'Hayu $delta',
                            style: dayCaption.copyWith(fontSize: 10),
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '$leaves/$winLeaves',
                            style: dayMetricValue.copyWith(
                              fontSize: 17,
                              color: EmbunColors.leaf,
                            ),
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
        const SizedBox(width: 6),
        _rule(28),
        const SizedBox(width: 6),
        Expanded(child: parts),
      ],
    );
  }

  Widget _roomStatus({
    required bool wide,
    required double rosterWidth,
    required bool tight,
    required bool showWorms,
  }) {
    final hint = offeringIn == 0 ? 'Malam ini' : '$offeringIn hari lagi';
    return Row(
      children: [
        if (!wide) ...[
          SizedBox(width: tight ? 41 : 115, child: identity),
          const SizedBox(width: 7),
        ],
        Expanded(
          child: showOffering
              ? Tooltip(
                  message: offeringIn == 0
                      ? 'Persembahan malam ini'
                      : 'Persembahan $hint',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Persembahan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: dayCaption.copyWith(fontSize: 9.5),
                      ),
                      Text(
                        hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        if (showWorms)
          Padding(
            padding: EdgeInsets.only(right: tight ? 4 : 8),
            child: Tooltip(
              message: '$worms ulat senyap',
              child: Text(
                'Ulat $worms',
                style: dayCaption.copyWith(fontSize: 11),
              ),
            ),
          ),
        if (village != null) SizedBox(width: rosterWidth, child: village),
        if (deadline != null)
          Countdown(
            deadline: deadline,
            compact: true,
            style: const TextStyle(
              fontSize: 12,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        const SizedBox(width: 3),
        Tooltip(
          message: 'Daftar warga · $ready dari $total siap',
          child: InkWell(
            key: playersKey,
            onTap: onPlayers,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GameIcon('persona', size: 17),
                  const SizedBox(width: 3),
                  Text(
                    '$ready/$total',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: EmbunColors.cream,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final wide = box.maxWidth >= (short ? 690 : 740);
      final tight = box.maxWidth < 470;
      final rosterWidth = wide
          ? (box.maxWidth * 0.21).clamp(130.0, 230.0)
          : box.maxWidth >= 500
          ? (box.maxWidth * 0.26).clamp(108.0, 180.0)
          : 37.0;
      final showWorms =
          worms > 0 &&
          (box.maxWidth >= 355 ||
              MediaQuery.textScalerOf(context).scale(11) <= 13);
      final primary = Padding(
        padding: EdgeInsets.symmetric(vertical: short ? 3 : 6),
        child: Row(
          children: [
            _dayMetric(wide: wide),
            _rule(short ? 32 : 38),
            SizedBox(width: tight ? 7 : 12),
            Expanded(
              child: Align(alignment: Alignment.centerLeft, child: balance),
            ),
            if (wide) ...[
              SizedBox(
                width: box.maxWidth >= 1000 ? 190 : 136,
                child: identity,
              ),
              const SizedBox(width: 7),
            ],
            ...tools,
          ],
        ),
      );
      final hayu = _hayuRow();
      final room = _roomStatus(
        wide: wide,
        rosterWidth: rosterWidth,
        tight: tight,
        showWorms: showWorms,
      );
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.alphaBlend(accent.withValues(alpha: 0.08), EmbunColors.bg),
              EmbunColors.bg.withValues(alpha: 0.91),
            ],
          ),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: tight ? 7 : 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primary,
              Divider(height: 1, color: accent.withValues(alpha: 0.20)),
              if (wide)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: short ? 2 : 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: (box.maxWidth * 0.42).clamp(302.0, 415.0),
                        child: hayu,
                      ),
                      const SizedBox(width: 10),
                      _rule(28),
                      const SizedBox(width: 10),
                      Expanded(child: room),
                    ],
                  ),
                )
              else ...[
                Padding(
                  padding: EdgeInsets.symmetric(vertical: short ? 2 : 4),
                  child: hayu,
                ),
                Divider(height: 1, color: accent.withValues(alpha: 0.11)),
                room,
              ],
            ],
          ),
        ),
      );
    },
  );
}
