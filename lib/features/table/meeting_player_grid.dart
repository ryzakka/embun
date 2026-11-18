import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'player_status.dart';

/// Public portraits and public status only. A target whitelist is supplied by
/// the ability owner; selecting a tile never sends an action by itself.
///
/// Parameter publik TIDAK berubah dari versi sebelumnya. Satu tambahan opsional:
/// [focusFlash] (0..1) menyalakan kilatan pada ubin fokus saat adegan hantaman.
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
    this.focusFlash,
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
  final double? focusCross, focusFlash;
  final Color? focusColor;
  final GlobalKey? focusAnchor;
  final bool shrinkWrap, busy;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final reduced = MediaQuery.disableAnimationsOf(context);
      final cols = box.maxWidth >= 370 ? 2 : 1;
      final height = 78.0 + math.max(0, scale - 1) * 32;
      return GridView.builder(
        key: const ValueKey('meeting-player-grid'),
        padding: const EdgeInsets.all(6),
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
        itemCount: players.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisExtent: height,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
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
          final flash = focused ? (focusFlash ?? 0.0) : 0.0;
          Widget tile = RepaintBoundary(
            child: _PlayerTile(
              player: p,
              id: id,
              myId: myId,
              out: out,
              jailed: jailed,
              targeting: targeting,
              enabled: enabled,
              selected: selected,
              focused: focused,
              speaking: speaking,
              accent: accent,
              cross: cross,
              flash: flash,
              anchor: focused ? focusAnchor : null,
              onTap: enabled
                  ? () {
                if (targeting) {
                  onSelected!(id);
                } else {
                  onInspect!(p);
                }
              }
                  : null,
            ),
          );
          // Masuk berurutan: muncul + membesar sedikit. Tidak menggeser posisi,
          // supaya titik sasaran efek di adegan papan tetap akurat.
          if (!reduced) {
            tile = TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 280 + math.min(i, 8) * 45),
              curve: Curves.easeOutCubic,
              builder: (context, v, child) => Opacity(
                opacity: v.clamp(0.0, 1.0).toDouble(),
                child: Transform.scale(scale: 0.94 + 0.06 * v, child: child),
              ),
              child: tile,
            );
          }
          return tile;
        },
      );
    },
  );
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({
    required this.player,
    required this.id,
    required this.myId,
    required this.out,
    required this.jailed,
    required this.targeting,
    required this.enabled,
    required this.selected,
    required this.focused,
    required this.speaking,
    required this.accent,
    required this.cross,
    required this.flash,
    required this.anchor,
    required this.onTap,
  });
  final Map<String, dynamic> player;
  final String id;
  final String? myId;
  final bool out, jailed, targeting, enabled, selected, focused, speaking;
  final Color accent;
  final double cross, flash;
  final GlobalKey? anchor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = player;
    final me = id == myId;
    final strong = selected || focused || speaking;
    final stateText = out
        ? 'tersingkir'
        : jailed
        ? 'dikurung'
        : '${livesLeft(p)} nyawa';

    final statusText = out
        ? 'Tersingkir'
        : jailed
        ? 'Dikurung'
        : me
        ? 'Kamu'
        : speaking
        ? 'Sedang bicara'
        : 'Aktif';
    final statusIcon = out
        ? Icons.close_rounded
        : jailed
        ? Icons.lock_rounded
        : me
        ? Icons.person_rounded
        : speaking
        ? Icons.graphic_eq_rounded
        : Icons.eco_rounded;
    final statusColor = out
        ? const Color(0xFFB4686B)
        : jailed
        ? const Color(0xFFE5B96C)
        : me
        ? EmbunColors.mist
        : speaking
        ? EmbunColors.gold
        : EmbunColors.leaf;

    return Semantics(
      key: anchor,
      label: '${p['name']}${me ? ', kamu' : ''}, $stateText',
      selected: selected,
      button: enabled,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: targeting && !enabled && !selected
            ? .42
            : out
            ? .66
            : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: out
                  ? const [Color(0xFF252B2A), Color(0xFF141918)]
                  : [
                Color.lerp(const Color(0xFF1B322B), accent, .16)!,
                const Color(0xFF0C1C17),
              ],
            ),
            border: Border.all(
              color: accent.withValues(alpha: strong ? 1 : .5),
              width: selected || focused ? 2 : 1,
            ),
            boxShadow: strong
                ? [
              BoxShadow(
                color: accent.withValues(alpha: .26),
                blurRadius: 18,
                spreadRadius: 0.5,
              ),
            ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: ValueKey('meeting-player-$id'),
                    borderRadius: BorderRadius.circular(13),
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 7,
                      ),
                      child: Row(
                        children: [
                          _Portrait(
                            cardId: '${p['character_card'] ?? 'default'}',
                            out: out,
                            jailed: jailed,
                            glow: strong,
                            accent: accent,
                            cross: cross,
                          ),
                          const SizedBox(width: 9),
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
                                        fontSize: 13,
                                        height: 1.12,
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
                                const SizedBox(height: 3),
                                // Status dan nyawa sebaris; status mengecil
                                // bila ruangnya sempit.
                                Row(
                                  children: [
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: StatusTag(
                                          text: statusText,
                                          color: statusColor,
                                          icon: statusIcon,
                                        ),
                                      ),
                                    ),
                                    if (!out) ...[
                                      const SizedBox(width: 6),
                                      LivesRow(lives: livesLeft(p), size: 12),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (selected)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.4, end: 1.0),
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutBack,
                                builder: (context, v, child) =>
                                    Transform.scale(scale: v, child: child),
                                child: const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF8FCBFF),
                                  size: 20,
                                ),
                              ),
                            )
                          else if (targeting && enabled)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.radio_button_unchecked_rounded,
                                color: Colors.white24,
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (out)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _HatchPaint()),
                    ),
                  ),
                if (flash > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: Color.lerp(
                          Colors.white,
                          accent,
                          .35,
                        )!.withValues(alpha: (flash * .5).clamp(0.0, .6)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Portrait extends StatelessWidget {
  const _Portrait({
    required this.cardId,
    required this.out,
    required this.jailed,
    required this.glow,
    required this.accent,
    required this.cross,
  });
  final String cardId;
  final bool out, jailed, glow;
  final Color accent;
  final double cross;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: accent.withValues(alpha: glow ? .9 : .55),
            width: 1.5,
          ),
          boxShadow: glow
              ? [BoxShadow(color: accent.withValues(alpha: .35), blurRadius: 10)]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.5),
          child: SizedBox(
            width: 38,
            height: 57,
            child: ColorFiltered(
              colorFilter: out
                  ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                  : const ColorFilter.mode(
                Colors.transparent,
                BlendMode.srcOver,
              ),
              child: GameImage(
                path: protagonistPath(cardId),
                fit: BoxFit.cover,
                cacheWidth: 160,
              ),
            ),
          ),
        ),
      ),
      if (jailed)
        const Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _BarsPaint())),
        ),
      if (cross > 0)
        Positioned.fill(child: CustomPaint(painter: _CrossPaint(cross))),
      if (jailed)
        Positioned(
          right: -4,
          bottom: -4,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1A1405),
              border: Border.all(color: const Color(0xFFE5B96C), width: 1.2),
            ),
            child: const Icon(
              Icons.lock_rounded,
              color: Color(0xFFE5B96C),
              size: 11,
            ),
          ),
        ),
    ],
  );
}

/// Garis diagonal halus di atas ubin pemain yang sudah tersingkir.
class _HatchPaint extends CustomPainter {
  const _HatchPaint();
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: .035)
      ..strokeWidth = 1.2;
    for (double x = -s.height; x < s.width; x += 11) {
      c.drawLine(Offset(x, s.height), Offset(x + s.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(_HatchPaint o) => false;
}

/// Jeruji tipis di atas potret pemain yang sedang dikurung.
class _BarsPaint extends CustomPainter {
  const _BarsPaint();
  @override
  void paint(Canvas c, Size s) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & s,
      const Radius.circular(10),
    );
    c.save();
    c.clipRRect(r);
    c.drawRect(
      Offset.zero & s,
      Paint()..color = Colors.black.withValues(alpha: .22),
    );
    final p = Paint()
      ..color = const Color(0xFFE5B96C).withValues(alpha: .6)
      ..strokeWidth = 1.8;
    const n = 4;
    for (var i = 1; i <= n; i++) {
      final x = s.width * i / (n + 1);
      c.drawLine(Offset(x, 0), Offset(x, s.height), p);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_BarsPaint o) => false;
}

/// Tanda silang merah yang tergores bergantian dengan kilap dan percikan di ujung.
class _CrossPaint extends CustomPainter {
  const _CrossPaint(this.t);
  final double t;

  void _stroke(Canvas c, Offset a, Offset b, double k) {
    if (k <= 0) return;
    final end = Offset.lerp(a, b, k)!;
    c.drawLine(
      a,
      end,
      Paint()
        ..color = const Color(0xFFE85F64).withValues(alpha: .55)
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    c.drawLine(
      a,
      end,
      Paint()
        ..color = const Color(0xFF3A0A0C)
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    c.drawLine(
      a,
      end,
      Paint()
        ..color = const Color(0xFFE85F64)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    c.drawLine(
      a,
      end,
      Paint()
        ..color = const Color(0xFFFFB0B0)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
    if (k < 1) {
      c.drawCircle(end, 3.2, Paint()..color = Colors.white);
    }
  }

  @override
  void paint(Canvas c, Size s) {
    final a = Offset(s.width * .14, s.height * .18),
        b = Offset(s.width * .86, s.height * .82);
    _stroke(c, a, b, (t * 2).clamp(0.0, 1.0).toDouble());
    if (t > .5) {
      final d = Offset(s.width * .86, s.height * .18),
          e = Offset(s.width * .14, s.height * .82);
      _stroke(c, d, e, ((t - .5) * 2).clamp(0.0, 1.0).toDouble());
    }
  }

  @override
  bool shouldRepaint(_CrossPaint o) => o.t != t;
}

class _NameStrike extends CustomPainter {
  const _NameStrike(this.t);
  final double t;
  @override
  void paint(Canvas c, Size s) {
    final a = Offset(0, s.height * .55), b = Offset(s.width * t, s.height * .45);
    c.drawLine(
      a,
      b,
      Paint()
        ..color = const Color(0xFFE85F64).withValues(alpha: .5)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    c.drawLine(
      a,
      b,
      Paint()
        ..color = const Color(0xFFE85F64)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_NameStrike o) => o.t != t;
}