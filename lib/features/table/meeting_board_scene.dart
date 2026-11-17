import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../common/ornate.dart';
import 'meeting_board_events.dart';
import 'meeting_player_grid.dart';

class MeetingBoardScene extends StatefulWidget {
  const MeetingBoardScene({
    super.key,
    required this.moment,
    required this.players,
    required this.onDone,
    this.myId,
  });
  final MeetingMoment moment;
  final List<Map<String, dynamic>> players;
  final VoidCallback onDone;
  final String? myId;
  @override
  State<MeetingBoardScene> createState() => _MeetingBoardSceneState();
}

class _MeetingBoardSceneState extends State<MeetingBoardScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.moment.eliminated ? 3800 : 2900),
  );
  bool _done = false, _hit = false;
  final _scroll = ScrollController();
  final _focus = GlobalKey();
  final _root = GlobalKey();
  Offset? _targetPoint;
  bool _measuring = false;
  void _captureTarget() {
    if (_targetPoint != null || _measuring) return;
    _measuring = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measuring = false;
      if (!mounted) return;
      final a = _focus.currentContext?.findRenderObject(),
          b = _root.currentContext?.findRenderObject();
      if (a is RenderBox && b is RenderBox && a.hasSize) {
        final point =
            a.localToGlobal(a.size.center(Offset.zero)) -
            b.localToGlobal(Offset.zero);
        setState(() => _targetPoint = point);
      }
    });
  }

  bool _reduced = false;
  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      if (!_hit && _c.value >= .4) {
        _hit = true;
        if (!_reduced) HapticFeedback.heavyImpact();
      }
    });
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _finish();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (!_c.isAnimating && _c.value == 0) {
      if (_reduced) _c.duration = const Duration(milliseconds: 1600);
      _c.forward();
    }
  }

  void _finish() {
    if (!mounted || _done) return;
    _done = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF070F0C),
    child: SafeArea(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final m = widget.moment, t = _reduced ? 1.0 : _c.value;
          _captureTarget();
          final accent = switch (m.kind) {
            MeetingMomentKind.action => const Color(0xFF8FCBFF),
            MeetingMomentKind.jailed => const Color(0xFFE5B96C),
            MeetingMomentKind.recovered => const Color(0xFF80C991),
            _ => const Color(0xFFE85F64),
          };
          final changed = t >= .42;
          final cross = ((t - .52) / .24).clamp(0.0, 1.0);
          final title = m.kind == MeetingMomentKind.action
              ? 'AKSI MUSYAWARAH'
              : m.kind == MeetingMomentKind.jailed
              ? 'DALAM KURUNGAN'
              : m.kind == MeetingMomentKind.recovered
              ? 'KEMBALI BERTAHAN'
              : t < .42
              ? 'PERHATIKAN PEMAIN INI'
              : m.eliminated
              ? 'TERSINGKIR'
              : 'TERKENA LUKA';
          final display = [
            for (final p in widget.players)
              if (p['user_id'] == m.playerId)
                (changed ? m.after : m.before)
              else
                p,
          ];
          final pulse = math.max(0.0, 1 - (_c.value - .42).abs() / .1);
          final shake = _reduced ? 0.0 : math.sin(t * 130) * 5 * pulse;
          return Stack(
            key: _root,
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                    child: Column(
                      children: [
                        const Text(
                          'PAPAN PEMAIN',
                          style: TextStyle(
                            color: EmbunColors.gold,
                            fontSize: 11,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            color: m.eliminated
                                ? const Color(0xFFE85F64)
                                : EmbunColors.cream,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${m.after['name']}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: EmbunColors.gold,
                          ),
                        ),
                        if (m.caption != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              m.caption!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Transform.translate(
                      offset: Offset(shake, 0),
                      child: SingleChildScrollView(
                        controller: _scroll,
                        child: Column(
                          children: [
                            // The focused tile is shown first only in the cinematic; ordinary
                            // discussion keeps stable player order.
                            MeetingPlayerGrid(
                              focusAnchor: _focus,
                              focusColor: accent,
                              players: [
                                ...display.where(
                                  (p) => p['user_id'] == m.playerId,
                                ),
                                ...display.where(
                                  (p) => p['user_id'] != m.playerId,
                                ),
                              ],
                              day: m.day,
                              myId: widget.myId,
                              focusId: m.playerId,
                              focusCross: m.eliminated && changed
                                  ? cross
                                  : null,
                              shrinkWrap: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextButton(
                      onPressed: changed ? _finish : null,
                      child: const Text('Lanjut'),
                    ),
                  ),
                ],
              ),
              if (!_reduced &&
                  _targetPoint != null &&
                  m.kind != MeetingMomentKind.jailed)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _OperationPaint(t, _targetPoint!, accent),
                    ),
                  ),
                ),
              if (!_reduced && pulse > 0 && m.kind != MeetingMomentKind.action)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            Colors.transparent,
                            Colors.redAccent.withValues(alpha: pulse * .28),
                          ],
                          stops: const [.2, 1],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _OperationPaint extends CustomPainter {
  _OperationPaint(this.t, this.target, this.color);
  final double t;
  final Offset target;
  final Color color;
  @override
  void paint(Canvas c, Size size) {
    if (t >= .16 && t < .43) {
      final p = ((t - .16) / .27).clamp(0.0, 1.0);
      final from = Offset(size.width - 18, math.max(24, target.dy - 100));
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(
          size.width * .6,
          target.dy - 80,
          target.dx,
          target.dy,
        );
      final metric = path.computeMetrics().first;
      final trail = metric.extractPath(
        metric.length * math.max(0, p - .22),
        metric.length * p,
      );
      c.drawPath(
        trail,
        Paint()
          ..color = color.withValues(alpha: .65)
          ..strokeWidth = 14
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      c.drawPath(
        trail,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke,
      );
      final at = metric.getTangentForOffset(metric.length * p)?.position;
      if (at != null) c.drawCircle(at, 6, Paint()..color = color);
    }
    if (t >= .4 && t < .68) {
      final p = ((t - .4) / .28).clamp(0.0, 1.0), r = 12 + 82 * p;
      c.drawCircle(
        target,
        r,
        Paint()
          ..color = color.withValues(alpha: 1 - p)
          ..strokeWidth = 3 * (1 - p) + .5
          ..style = PaintingStyle.stroke,
      );
      for (var i = 0; i < 12; i++) {
        final a = i * math.pi / 6;
        final dir = Offset(math.cos(a), math.sin(a));
        c.drawLine(
          target + dir * (r * .6),
          target + dir * r,
          Paint()
            ..color = color.withValues(alpha: 1 - p)
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_OperationPaint old) =>
      old.t != t || old.target != target || old.color != color;
}
