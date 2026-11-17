import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'player_status.dart';

/// Public portraits and public status only. A target whitelist is supplied by
/// the ability owner; selecting a tile never sends an action by itself.
class MeetingPlayerGrid extends StatelessWidget {
  const MeetingPlayerGrid({
    super.key,
    required this.players,
    required this.day,
    this.myId,
    this.selectedId,
    this.eligibleIds,
    this.onSelected,
    this.onInspect,
    this.speakingId,
    this.focusId,
    this.focusCross,
    this.focusColor,
    this.focusAnchor,
    this.shrinkWrap = false,
    this.busy = false,
  });
  final List<Map<String, dynamic>> players;
  final int day;
  final String? myId, selectedId, speakingId, focusId;
  final Set<String>? eligibleIds;
  final ValueChanged<String>? onSelected;
  final ValueChanged<Map<String, dynamic>>? onInspect;
  final double? focusCross;
  final Color? focusColor;
  final GlobalKey? focusAnchor;
  final bool shrinkWrap, busy;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final cols = box.maxWidth >= 370 ? 2 : 1;
      final height = 98.0 + math.max(0, scale - 1) * 38;
      return GridView.builder(
        key: const ValueKey('meeting-player-grid'),
        padding: const EdgeInsets.all(8),
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
        itemCount: players.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisExtent: height,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (context, i) {
          final p = players[i];
          final id = '${p['user_id']}';
          final out = isOut(p), jailed = isJailed(p, day);
          final targeting = eligibleIds != null;
          final enabled =
              !busy &&
              (targeting
                  ? eligibleIds!.contains(id) && onSelected != null
                  : onInspect != null);
          final selected = selectedId == id, focused = focusId == id;
          final speaking = speakingId == id && !out;
          final accent = selected
              ? const Color(0xFF8FCBFF)
              : focused
              ? (focusColor ?? EmbunColors.blood)
              : speaking
              ? EmbunColors.gold
              : jailed
              ? const Color(0xFFE5B96C)
              : const Color(0xFF547360);
          final cross = focused && focusCross != null
              ? focusCross!
              : out
              ? 1.0
              : 0.0;
          return Semantics(
            key: focused ? focusAnchor : null,
            label:
                '${p['name']}${id == myId ? ', kamu' : ''}, ${out
                    ? 'tersingkir'
                    : jailed
                    ? 'dikurung'
                    : '${livesLeft(p)} nyawa'}',
            selected: selected,
            button: enabled,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: targeting && !enabled && !selected
                  ? .42
                  : out
                  ? .62
                  : 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: out
                        ? const [Color(0xFF252B2A), Color(0xFF141918)]
                        : [
                            Color.lerp(const Color(0xFF1B322B), accent, .13)!,
                            const Color(0xFF0C1C17),
                          ],
                  ),
                  border: Border.all(
                    color: accent.withValues(
                      alpha: selected || focused || speaking ? 1 : .5,
                    ),
                    width: selected || focused ? 2 : 1,
                  ),
                  boxShadow: selected || focused || speaking
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: .22),
                            blurRadius: 16,
                          ),
                        ]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: ValueKey('meeting-player-$id'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: enabled
                        ? () {
                            if (targeting) {
                              onSelected!(id);
                            } else {
                              onInspect!(p);
                            }
                          }
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(9),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 44,
                                  height: 66,
                                  child: ColorFiltered(
                                    colorFilter: out
                                        ? const ColorFilter.mode(
                                            Colors.grey,
                                            BlendMode.saturation,
                                          )
                                        : const ColorFilter.mode(
                                            Colors.transparent,
                                            BlendMode.srcOver,
                                          ),
                                    child: GameImage(
                                      path: protagonistPath(
                                        '${p['character_card'] ?? 'default'}',
                                      ),
                                      fit: BoxFit.cover,
                                      cacheWidth: 160,
                                    ),
                                  ),
                                ),
                              ),
                              if (cross > 0)
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _CrossPaint(cross),
                                  ),
                                ),
                              if (jailed)
                                const Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Icon(
                                    Icons.lock,
                                    color: Color(0xFFE5B96C),
                                    size: 19,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    Text(
                                      '${p['name'] ?? 'Pemain'}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: out
                                            ? Colors.white54
                                            : EmbunColors.cream,
                                      ),
                                    ),
                                    if (cross > 0)
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: _NameStrike(cross),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Flexible(
                                  child: Text(
                                    out
                                        ? 'Tersingkir'
                                        : jailed
                                        ? 'Dikurung'
                                        : id == myId
                                        ? 'Kamu'
                                        : speaking
                                        ? 'Sedang bicara'
                                        : 'Aktif',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: out ? Colors.white38 : accent,
                                    ),
                                  ),
                                ),
                                if (!out) ...[
                                  const SizedBox(height: 4),
                                  LivesRow(lives: livesLeft(p), size: 12),
                                ],
                              ],
                            ),
                          ),
                          if (selected)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.check_circle,
                                color: Color(0xFF8FCBFF),
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _CrossPaint extends CustomPainter {
  _CrossPaint(this.t);
  final double t;
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = const Color(0xFFE85F64)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final a = Offset(s.width * .12, s.height * .18),
        b = Offset(s.width * .88, s.height * .82);
    c.drawLine(a, Offset.lerp(a, b, (t * 2).clamp(0, 1))!, p);
    if (t > .5) {
      final d = Offset(s.width * .88, s.height * .18),
          e = Offset(s.width * .12, s.height * .82);
      c.drawLine(d, Offset.lerp(d, e, ((t - .5) * 2).clamp(0, 1))!, p);
    }
  }

  @override
  bool shouldRepaint(_CrossPaint o) => o.t != t;
}

class _NameStrike extends CustomPainter {
  _NameStrike(this.t);
  final double t;
  @override
  void paint(Canvas c, Size s) {
    c.drawLine(
      Offset(0, s.height * .55),
      Offset(s.width * t, s.height * .45),
      Paint()
        ..color = const Color(0xFFE85F64)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_NameStrike o) => o.t != t;
}
