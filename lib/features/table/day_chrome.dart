import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

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
  const DayTableHeader({
    super.key,
    required this.accent,
    required this.day,
    required this.offeringIn,
    required this.deadline,
    required this.short,
    required this.balance,
    required this.parts,
    required this.players,
    required this.tools,
    required this.wideTools,
    required this.menu,
    required this.menuAttention,
    this.village,
  });

  final Color accent;
  final int day;
  final int? offeringIn;
  final DateTime? deadline;
  final bool short;
  final Widget balance;
  final Widget parts;
  final Widget players;
  final List<Widget> tools;
  final List<Widget> wideTools;
  final Widget menu;
  final bool menuAttention;
  final Widget? village;

  Widget _divider({double height = 28}) => SizedBox(
    height: height,
    child: VerticalDivider(width: 17, color: accent.withValues(alpha: 0.20)),
  );

  Widget _dayMetric({required bool wide}) {
    final due = offeringIn;
    return SizedBox(
      width: wide && due != null ? 112 : 42,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'HARI',
              style: dayOverline.copyWith(color: accent, letterSpacing: 1),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              day.toString().padLeft(2, '0'),
              style: dayMetricValue.copyWith(
                fontSize: short ? 24 : 28,
                color: EmbunColors.cream,
              ),
            ),
          ),
          if (wide && due != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Persembahan ${due == 0 ? 'malam ini' : '$due hari lagi'}',
                  style: dayCaption.copyWith(fontSize: 9.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actions({required bool wide}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (deadline != null) ...[
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 62),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Countdown(
              deadline: deadline,
              compact: true,
              style: const TextStyle(
                fontSize: 12,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
      ],
      for (final tool in [
        ...tools,
        if (wide) ...wideTools,
        Badge(
          isLabelVisible: !wide && menuAttention,
          backgroundColor: EmbunColors.gold,
          child: menu,
        ),
      ])
        SizedBox(
          width: wide ? 44 : 40,
          height: 44,
          child: Center(child: tool),
        ),
    ],
  );

  Widget _roster() => Align(
    alignment: Alignment.centerRight,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 236),
      child: village,
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
      final wide = box.maxWidth >= 1040 && textScale <= 1.3;
      final showRoster = village != null && box.maxWidth >= 680;
      final dayMetric = _dayMetric(wide: wide);
      final actions = _actions(wide: wide);
      final primary = Row(
        children: [
          dayMetric,
          const SizedBox(width: 4),
          Expanded(child: balance),
          const SizedBox(width: 4),
          actions,
        ],
      );
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            accent.withValues(alpha: 0.045),
            EmbunColors.bg.withValues(alpha: 0.96),
          ),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 13 : 9,
            vertical: short ? 3 : 4,
          ),
          child: wide
              ? Row(
                  children: [
                    dayMetric,
                    SizedBox(width: 132, child: balance),
                    _divider(),
                    SizedBox(
                      width: (box.maxWidth * 0.29).clamp(300.0, 350.0),
                      child: parts,
                    ),
                    _divider(),
                    Expanded(child: showRoster ? _roster() : const SizedBox()),
                    players,
                    const SizedBox(width: 8),
                    actions,
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    primary,
                    Divider(
                      height: short ? 5 : 7,
                      color: accent.withValues(alpha: 0.15),
                    ),
                    Row(
                      children: [
                        if (showRoster) ...[
                          SizedBox(width: 360, child: parts),
                          _divider(),
                          Expanded(child: _roster()),
                        ] else
                          Expanded(child: parts),
                        const SizedBox(width: 5),
                        if (showRoster || village == null)
                          players
                        else
                          SizedBox(width: 49, child: village),
                      ],
                    ),
                  ],
                ),
        ),
      );
    },
  );
}
