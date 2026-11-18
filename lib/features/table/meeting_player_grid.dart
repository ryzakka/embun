import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'player_status.dart';

/// Public portraits and public status only. A target whitelist is supplied by
/// the ability owner; selecting a plate never sends an action by itself.
///
/// Tampilan "papan nama desa": dua kolom papan hijau tua bersudut tersayat
/// (kiri-atas dan kanan-bawah dipotong), potret di kiri, nama + nyawa + status
/// di kanan. Pembicara ditandai batang suara emas dan papan yang menyala,
/// yang dikurung berjeruji dan berpapan amber, yang keluar memudar kelabu
/// dengan label merah. Parameter publik TIDAK berubah dari versi sebelumnya.
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

  /// Ukuran potret dan jarak potret dari tepi kiri papan.
  static const double portraitW = 48, portraitH = 58, portraitInset = 7;

  /// Tinggi dasar satu papan (bertambah mengikuti skala teks).
  static const double cellHeight = 68;

  /// Posisi potret di dalam [cell] (rect papan dari [focusAnchor]).
  /// Dipakai adegan papan untuk mengarahkan sorotan dan efek.
  static Rect portraitRectIn(Rect cell) => Rect.fromLTWH(
    cell.left + portraitInset,
    cell.center.dy - portraitH / 2,
    portraitW,
    portraitH,
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final reduced = MediaQuery.disableAnimationsOf(context);
      final cols = box.maxWidth >= 600 ? 3 : 2;
      final height = cellHeight + math.max(0, scale - 1) * 20;
      return GridView.builder(
        key: const ValueKey('meeting-player-grid'),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
        itemCount: players.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisExtent: height,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemBuilder: (context, i) {
          final p = players[i];
          final id = '${p['user_id']}';
          final out = isOut(p), jailed = isJailed(p, day);
          final me = id == myId;
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
              : me && !out
              ? EmbunColors.mist
              : const Color(0xFF547360);
          final cross = focused && focusCross != null
              ? focusCross!
              : out
              ? 1.0
              : 0.0;
          final flash = focused ? (focusFlash ?? 0.0) : 0.0;
          Widget tile = RepaintBoundary(
            child: _PlayerPlate(
              player: p,
              id: id,
              me: me,
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
          // Masuk hampir serempak dan tidak menggeser posisi, supaya titik
          // sasaran efek di adegan papan tetap akurat.
          if (!reduced) {
            tile = TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 240 + math.min(i, 5) * 20),
              curve: Curves.easeOutCubic,
              builder: (context, v, child) => Opacity(
                opacity: v.clamp(0.0, 1.0).toDouble(),
                child: Transform.scale(scale: 0.95 + 0.05 * v, child: child),
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

/// Papan bersudut tersayat: kiri-atas dan kanan-bawah dipotong lebar,
/// dua sudut lainnya hanya sedikit. Memberi siluet khas, bukan kotak biasa.
ShapeBorder _plateShape(Color border, double width) => BeveledRectangleBorder(
  borderRadius: const BorderRadius.only(
    topLeft: Radius.circular(16),
    bottomRight: Radius.circular(16),
    topRight: Radius.circular(4),
    bottomLeft: Radius.circular(4),
  ),
  side: BorderSide(color: border, width: width),
);

class _PlayerPlate extends StatelessWidget {
  const _PlayerPlate({
    required this.player,
    required this.id,
    required this.me,
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
  final bool me, out, jailed, targeting, enabled, selected, focused, speaking;
  final Color accent;
  final double cross, flash;
  final GlobalKey? anchor;
  final VoidCallback? onTap;

  static const _gold = Color(0xFFE5B96C);
  static const _red = Color(0xFFE85F64);
  static const _sky = Color(0xFF8FCBFF);

  @override
  Widget build(BuildContext context) {
    final p = player;
    final lives = livesLeft(p);
    final stateText = out
        ? 'tersingkir'
        : jailed
        ? 'dikurung'
        : '$lives nyawa';
    final glow = selected || focused || speaking;
    final nameColor = out
        ? Colors.white54
        : selected
        ? _sky
        : EmbunColors.cream;
    final plate = out
        ? const [Color(0xFF1B201D), Color(0xFF111513)]
        : selected
        ? const [Color(0xFF1B3A4A), Color(0xFF11262F)]
        : jailed
        ? const [Color(0xFF3A2F18), Color(0xFF241C0F)]
        : speaking
        ? const [Color(0xFF34391C), Color(0xFF1F2310)]
        : const [Color(0xFF1C3D2E), Color(0xFF12281E)];
    final shape = _plateShape(
      accent.withValues(alpha: glow || jailed || (me && !out) ? .95 : .55),
      1.6,
    );

    return Semantics(
      key: anchor,
      label:
      '${p['name']}${me ? ', kamu' : ''}, $stateText${speaking ? ', sedang bicara' : ''}',
      selected: selected,
      button: enabled,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: targeting && !enabled && !selected
            ? .42
            : out
            ? .78
            : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: ShapeDecoration(
            shape: shape,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: plate,
            ),
            shadows: glow
                ? [
              BoxShadow(
                color: accent.withValues(alpha: .38),
                blurRadius: 14,
              ),
            ]
                : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: ValueKey('meeting-player-$id'),
              customBorder: shape,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  MeetingPlayerGrid.portraitInset,
                  4,
                  8,
                  4,
                ),
                child: Row(
                  children: [
                    _Portrait(
                      cardId: '${p['character_card'] ?? 'default'}',
                      out: out,
                      jailed: jailed,
                      selected: selected,
                      focused: focused,
                      speaking: speaking,
                      accent: accent,
                      cross: cross,
                      flash: flash,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nama mengecil sendiri bila panjang.
                          Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (me && !out) ...[
                                      const Icon(
                                        Icons.person_rounded,
                                        size: 14,
                                        color: EmbunColors.mist,
                                      ),
                                      const SizedBox(width: 3),
                                    ],
                                    Text(
                                      '${p['name'] ?? 'Pemain'}',
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        height: 1.15,
                                        fontWeight: FontWeight.w800,
                                        color: nameColor,
                                      ),
                                    ),
                                  ],
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
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: out
                                ? const StatusTag(
                              text: 'Keluar',
                              color: _red,
                              icon: Icons.close_rounded,
                            )
                                : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                LivesRow(lives: lives, size: 14),
                                if (jailed) ...[
                                  const SizedBox(width: 6),
                                  const StatusTag(
                                    text: 'Dikurung',
                                    color: _gold,
                                    icon: Icons.lock_rounded,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (speaking) ...[
                      const SizedBox(width: 4),
                      const _VoiceBars(),
                    ],
                    if (selected) ...[
                      const SizedBox(width: 4),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.4, end: 1.0),
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutBack,
                        builder: (context, v, child) =>
                            Transform.scale(scale: v, child: child),
                        child: const Icon(
                          Icons.check_circle,
                          color: _sky,
                          size: 20,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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
    required this.selected,
    required this.focused,
    required this.speaking,
    required this.accent,
    required this.cross,
    required this.flash,
  });
  final String cardId;
  final bool out, jailed, selected, focused, speaking;
  final Color accent;
  final double cross, flash;

  @override
  Widget build(BuildContext context) {
    final glow = selected || focused || speaking;
    return SizedBox(
      width: MeetingPlayerGrid.portraitW,
      height: MeetingPlayerGrid.portraitH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: accent.withValues(alpha: glow || jailed ? .95 : .5),
                  width: 1.4,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7.6),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColorFiltered(
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
                        path: protagonistPath(cardId),
                        fit: BoxFit.cover,
                        cacheWidth: 160,
                      ),
                    ),
                    if (jailed) const CustomPaint(painter: _BarsPaint()),
                    if (flash > 0)
                      ColoredBox(
                        color: Color.lerp(
                          Colors.white,
                          accent,
                          .35,
                        )!.withValues(alpha: (flash * .55).clamp(0.0, .65)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (cross > 0)
            Positioned.fill(child: CustomPaint(painter: _CrossPaint(cross))),
        ],
      ),
    );
  }
}

/// Tiga batang suara emas yang bergerak; diam bila animasi dimatikan.
class _VoiceBars extends StatefulWidget {
  const _VoiceBars();
  @override
  State<_VoiceBars> createState() => _VoiceBarsState();
}

class _VoiceBarsState extends State<_VoiceBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 20,
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 3.5,
              height:
              6 + 12 * (.5 + .5 * math.sin(2 * math.pi * (_c.value + i * .27))),
              margin: EdgeInsets.only(left: i == 0 ? 0 : 2),
              decoration: BoxDecoration(
                color: EmbunColors.gold,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Jeruji tipis di atas potret pemain yang sedang dikurung.
class _BarsPaint extends CustomPainter {
  const _BarsPaint();
  @override
  void paint(Canvas c, Size s) {
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