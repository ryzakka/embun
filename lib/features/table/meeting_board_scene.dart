import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../common/ornate.dart';
import 'meeting_board_events.dart';
import 'player_status.dart';
import 'meeting_player_grid.dart';

/// Adegan papan pemain: satu pemain disorot, lalu efek sesuai jenis momen.
/// Konstruktor publik TIDAK berubah dari versi sebelumnya.
///
/// Garis waktu (t = 0..1):
///   0.00-0.14  bidikan menyempit + sorotan menggelap di sekitar sasaran
///   0.16-0.43  peluru/cahaya meluncur (kurungan: jeruji turun)
///   0.40-0.84  hantaman: kilat, gelombang, percikan, retakan, serpihan
///   0.42       data pemain berganti ke kondisi sesudah
///   0.52-0.76  silang tergores (hanya tersingkir)
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
  bool _done = false, _hit = false, _stamped = false;
  // Waktu "berhenti sesaat" (hit-stop) di titik kontak untuk luka dan
  // tersingkir, supaya hantaman terasa berat. Aksi dan kurungan linear.
  late final CurvedAnimation _tl = CurvedAnimation(
    parent: _c,
    curve:
    widget.moment.kind == MeetingMomentKind.wound ||
        widget.moment.eliminated
        ? const _HitStop()
        : Curves.linear,
  );
  final _scroll = ScrollController();
  final _focus = GlobalKey();
  final _root = GlobalKey();
  Rect? _targetRect;
  bool _measuring = false;
  void _captureTarget() {
    if (_targetRect != null || _measuring) return;
    _measuring = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measuring = false;
      if (!mounted) return;
      final a = _focus.currentContext?.findRenderObject(),
          b = _root.currentContext?.findRenderObject();
      if (a is RenderBox && b is RenderBox && a.hasSize) {
        // Pusat dan ukuran dipakai (bukan pojok kiri atas) supaya tidak
        // terpengaruh animasi masuk ubin yang membesar dari tengah.
        final center =
            a.localToGlobal(a.size.center(Offset.zero)) -
                b.localToGlobal(Offset.zero);
        setState(
              () => _targetRect = Rect.fromCenter(
            center: center,
            width: a.size.width,
            height: a.size.height,
          ),
        );
      }
    });
  }

  /// Potret berada di kiri papan; posisinya dihitung oleh grid supaya
  /// selalu sinkron dengan tata letaknya.
  Rect _portraitRect(Rect cell) =>
      MeetingPlayerGrid.portraitRectIn(cell).inflate(4);

  bool _reduced = false;
  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      if (!_hit && _tl.value >= .4) {
        _hit = true;
        if (!_reduced) HapticFeedback.heavyImpact();
      }
      // Cap "TERSINGKIR" mendarat: getaran kedua yang lebih ringan.
      if (!_stamped && widget.moment.eliminated && _tl.value >= .73) {
        _stamped = true;
        if (!_reduced) HapticFeedback.mediumImpact();
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
    _tl.dispose();
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
          final m = widget.moment, t = _reduced ? 1.0 : _tl.value;
          _captureTarget();
          final accent = switch (m.kind) {
            MeetingMomentKind.action => const Color(0xFF8FCBFF),
            MeetingMomentKind.jailed => const Color(0xFFE5B96C),
            MeetingMomentKind.recovered => const Color(0xFF80C991),
            _ => const Color(0xFFE85F64),
          };
          final changed = t >= .42;
          final cross = ((t - .52) / .24).clamp(0.0, 1.0).toDouble();
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
          // Hantaman di t = .40: naik seketika lalu meluruh cepat. Cap
          // tersingkir (t = .73) memberi guncangan kedua.
          final heavy =
              m.kind == MeetingMomentKind.wound || m.eliminated;
          final power = m.eliminated ? 1.8 : heavy ? 1.1 : .55;
          final pulse = _reduced || t < .40
              ? 0.0
              : math.pow(1 - _seg(t, .40, .64), 2).toDouble();
          final slam = _reduced || !m.eliminated || t < .73
              ? 0.0
              : math.pow(1 - _seg(t, .73, .86), 2).toDouble();
          final linger = _reduced || !m.eliminated
              ? 0.0
              : .16 * _seg(t, .46, .70);
          final shake = pulse * power + slam * .9;
          final shakeX = _reduced ? 0.0 : math.sin(t * 130) * 7 * shake;
          final shakeY = _reduced ? 0.0 : math.cos(t * 170) * 4 * shake;
          final approach = _reduced || !heavy ? 0.0 : _ease(_seg(t, 0, .40));
          final punch = _reduced
              ? 1.0
              : 1 + .014 * approach + .024 * pulse * power + .012 * slam;
          final flash = _reduced
              ? 0.0
              : switch (m.kind) {
            MeetingMomentKind.action => pulse * .5,
            MeetingMomentKind.jailed => pulse,
            MeetingMomentKind.recovered => pulse * .6,
            _ => pulse * pulse,
          };
          // Hati yang hilang (luka) atau pulih berada di indeks ini.
          Rect? heartRect;
          if (_targetRect != null &&
              !m.eliminated &&
              strikesOf(m.after) != strikesOf(m.before)) {
            final idx = m.kind == MeetingMomentKind.recovered
                ? livesLeft(m.before)
                : livesLeft(m.after);
            heartRect = MeetingPlayerGrid.heartRectIn(
              _targetRect!,
              idx.clamp(0, kMaxStrikes - 1).toInt(),
            );
          }
          final hard =
              m.kind == MeetingMomentKind.wound ||
                  m.kind == MeetingMomentKind.eliminated;
          return Stack(
            key: _root,
            children: [
              // Latar: cahaya hijau gelap yang redup ke tepi.
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -.55),
                      radius: 1.25,
                      colors: [Color(0xFF10291F), Color(0xFF070F0C)],
                    ),
                  ),
                ),
              ),
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
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: ScaleTransition(
                              scale: Tween(begin: .92, end: 1.0).animate(anim),
                              child: child,
                            ),
                          ),
                          child: Text(
                            title,
                            key: ValueKey(title),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 25,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w900,
                              color: m.eliminated
                                  ? const Color(0xFFE85F64)
                                  : EmbunColors.cream,
                              shadows: [
                                Shadow(
                                  color: accent.withValues(
                                    alpha: changed ? .55 : 0,
                                  ),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
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
                        const SizedBox(height: 8),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 360),
                          curve: Curves.easeOutCubic,
                          width: changed ? 110 : 40,
                          height: 2,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(1),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: .6),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        if (m.caption != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Opacity(
                              opacity: (t / .2).clamp(0.0, 1.0).toDouble(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: .10),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: accent.withValues(alpha: .45),
                                  ),
                                ),
                                child: Text(
                                  m.caption!,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: EmbunColors.cream,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Transform.translate(
                      offset: Offset(shakeX, shakeY),
                      child: Transform.scale(
                        scale: punch,
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
                                focusFlash: flash,
                                shrinkWrap: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 240),
                      opacity: changed ? 1 : .4,
                      child: TextButton(
                        style: TextButton.styleFrom(foregroundColor: accent),
                        onPressed: changed ? _finish : null,
                        child: const Text('Lanjut'),
                      ),
                    ),
                  ),
                ],
              ),
              // Sorotan: sekitar sasaran tetap terang, sisanya menggelap.
              if (!_reduced && _targetRect != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _SpotPaint(t, _portraitRect(_targetRect!))),
                  ),
                ),
              if (!_reduced && _targetRect != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _OperationPaint(
                        t,
                        _portraitRect(_targetRect!),
                        _targetRect!,
                        accent,
                        m.kind,
                        heart: heartRect,
                      ),
                    ),
                  ),
                ),
              // Kilat putih sesaat tepat pada hantaman (impact frame).
              if (!_reduced && hard && t >= .40 && t < .52)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: Colors.white.withValues(
                        alpha:
                        (m.eliminated ? .45 : .28) *
                            math.pow(1 - _seg(t, .40, .52), 3).toDouble(),
                      ),
                    ),
                  ),
                ),
              // Denyut merah di tepi layar; pada tersingkir tetap menggelap.
              if (!_reduced && (pulse > 0 || linger > 0) && hard)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            Colors.transparent,
                            Colors.redAccent.withValues(
                              alpha: (pulse * .42 * (m.eliminated ? 1.3 : 1) + linger)
                                  .clamp(0.0, .8)
                                  .toDouble(),
                            ),
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

double _seg(double t, double a, double b) =>
    ((t - a) / (b - a)).clamp(0.0, 1.0).toDouble();

double _ease(double x) =>
    Curves.easeOutCubic.transform(x.clamp(0.0, 1.0).toDouble());

/// Menggelapkan layar kecuali sekitar sasaran supaya mata langsung ke sana.
class _SpotPaint extends CustomPainter {
  _SpotPaint(this.t, this.rect);
  final double t;
  final Rect rect;
  @override
  void paint(Canvas c, Size size) {
    final s = _seg(t, 0, .12) * (1 - _seg(t, .80, .96));
    if (s <= 0) return;
    final r = math.max(size.width, size.height) * .8;
    c.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.transparent, Colors.black.withValues(alpha: .6 * s)],
          stops: const [.30, 1.0],
        ).createShader(Rect.fromCircle(center: rect.center, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_SpotPaint old) => old.t != t || old.rect != rect;
}

/// Semua efek yang bergantung pada jenis momen, digambar di atas papan.
class _OperationPaint extends CustomPainter {
  _OperationPaint(this.t, this.rect, this.cell, this.color, this.kind,
      {this.heart});
  final double t;
  final Rect rect; // potret (sasaran efek)
  final Rect cell; // seluruh papan pemain
  final Rect? heart; // hati yang hilang / pulih (luka dan pulih)
  final Color color;
  final MeetingMomentKind kind;

  Offset get o => rect.center;

  @override
  void paint(Canvas c, Size size) {
    _brackets(c);
    switch (kind) {
      case MeetingMomentKind.jailed:
        _jail(c);
      case MeetingMomentKind.recovered:
        _heal(c, size);
      case MeetingMomentKind.action:
        _projectile(
          c,
          from: Offset(size.width - 18, math.max(24, o.dy - 100)),
          ctrl: Offset(size.width * .6, o.dy - 80),
          heavy: false,
        );
        _impactSoft(c);
      case MeetingMomentKind.wound:
      case MeetingMomentKind.eliminated:
        _projectile(
          c,
          from: Offset(size.width - 18, math.max(24, o.dy - 100)),
          ctrl: Offset(size.width * .6, o.dy - 80),
          heavy: true,
        );
        _impactHard(c, kind == MeetingMomentKind.eliminated);
    }
  }

  // ---- bidikan: empat sudut menyempit ke ubin sasaran ----
  void _brackets(Canvas c) {
    if (t >= .44) return;
    final a = _seg(t, 0, .14);
    final fade = 1 - _seg(t, .36, .44);
    final alpha = a * fade;
    if (alpha <= 0) return;
    final r = cell.inflate((1 - _ease(a)) * 46 + 6);
    const len = 18.0;
    final path = Path();
    void corner(Offset p, double dx, double dy) {
      path.moveTo(p.dx + dx * len, p.dy);
      path.lineTo(p.dx, p.dy);
      path.lineTo(p.dx, p.dy + dy * len);
    }

    corner(r.topLeft, 1, 1);
    corner(r.topRight, -1, 1);
    corner(r.bottomLeft, 1, -1);
    corner(r.bottomRight, -1, -1);
    c.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: .5 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    c.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  // ---- peluru berjejak yang makin cepat ke sasaran ----
  void _projectile(
      Canvas c, {
        required Offset from,
        required Offset ctrl,
        required bool heavy,
      }) {
    if (t < .16 || t >= .40) return;
    final p = _seg(t, .16, .40);
    final head = Curves.easeInCubic.transform(p);
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, o.dx, o.dy);
    final metric = path.computeMetrics().first;
    final tail = math.max(0.0, head - .30);
    final trail = metric.extractPath(metric.length * tail, metric.length * head);
    c.drawPath(
      trail,
      Paint()
        ..color = color.withValues(alpha: .7)
        ..strokeWidth = heavy ? 18 : 12
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    c.drawPath(
      trail,
      Paint()
        ..color = color
        ..strokeWidth = heavy ? 7 : 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    c.drawPath(
      trail,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    // butir percikan di sepanjang jejak
    final r = math.Random(11);
    for (var i = 0; i < 8; i++) {
      final jx = (r.nextDouble() - .5) * 14, jy = (r.nextDouble() - .5) * 14;
      final pj = head - i * .025;
      if (pj <= 0) continue;
      final pos = metric.getTangentForOffset(metric.length * pj)?.position;
      if (pos == null) continue;
      c.drawCircle(
        pos + Offset(jx, jy),
        2.2 * (1 - i / 8),
        Paint()..color = Colors.white.withValues(alpha: (1 - i / 8) * .8),
      );
    }
    final at = metric.getTangentForOffset(metric.length * head)?.position;
    if (at != null) {
      c.drawCircle(at, 14, Paint()..color = color.withValues(alpha: .5));
      c.drawCircle(at, 6, Paint()..color = Colors.white);
    }
  }

  // ---- bagian-bagian hantaman ----
  void _flash(Canvas c, double p, {double radius = 130, Color? tint}) {
    final k = (1 - p) * (1 - p);
    if (k <= 0) return;
    final rad = 40 + radius * _ease(p);
    final col = tint ?? color;
    c.drawCircle(
      o,
      rad,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: .9 * k),
            col.withValues(alpha: .55 * k),
            col.withValues(alpha: 0),
          ],
          stops: const [0, .35, 1],
        ).createShader(Rect.fromCircle(center: o, radius: rad)),
    );
  }

  void _rings(Canvas c, double p, {Color? tint}) {
    final col = tint ?? color;
    for (var i = 0; i < 2; i++) {
      final q = _seg(p, i * .12, 1);
      if (q <= 0 || q >= 1) continue;
      final r = 12 + (i == 0 ? 150 : 105) * _ease(q);
      c.drawCircle(
        o,
        r,
        Paint()
          ..color = (i == 0 ? Colors.white : col).withValues(
            alpha: (1 - q) * (i == 0 ? .9 : .7),
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = (4 - 3 * q) * (i == 0 ? 1 : .8) + .5,
      );
    }
    // ubin ikut berdenyut keluar
    final q = _seg(p, 0, .7);
    if (q > 0 && q < 1) {
      c.drawPath(
        _plate(cell.inflate(30 * _ease(q))),
        Paint()
          ..color = col.withValues(alpha: (1 - q) * .5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _rays(Canvas c, double p) {
    if (p >= 1) return;
    final r = math.Random(3);
    final inner = 12 + 120 * _ease(p);
    for (var i = 0; i < 14; i++) {
      final a = i * math.pi * 2 / 14 + (r.nextDouble() - .5) * .25;
      final l = 16 + r.nextDouble() * 34;
      final dir = Offset(math.cos(a), math.sin(a));
      c.drawLine(
        o + dir * inner,
        o + dir * (inner + l * (1 - p)),
        Paint()
          ..color = color.withValues(alpha: 1 - p)
          ..strokeWidth = 2.2 * (1 - p) + .6
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _sparks(
      Canvas c,
      Offset origin,
      double p,
      int n,
      int seed,
      double speed,
      Color col,
      ) {
    final r = math.Random(seed);
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < n; i++) {
      final a = r.nextDouble() * math.pi * 2;
      final v = speed * (.45 + r.nextDouble() * .75);
      final life = .55 + r.nextDouble() * .45;
      final q = p / life;
      if (q >= 1 || q <= 0) continue;
      final dir = Offset(math.cos(a), math.sin(a));
      final sag = Offset(0, 40 * q * q);
      final head = origin + dir * (v * _ease(q)) + sag;
      final tail = head - dir * (14 * (1 - q) + 2);
      paint
        ..color = Color.lerp(
          Colors.white,
          col,
          q,
        )!.withValues(alpha: (1 - q).clamp(0.0, 1.0).toDouble())
        ..strokeWidth = 2.2 * (1 - q) + .6;
      c.drawLine(tail, head, paint);
    }
  }

  void _cracks(Canvas c, double p) {
    final grow = _ease(_seg(p, 0, .35));
    final fade = 1 - _seg(p, .55, 1);
    if (grow <= 0 || fade <= 0) return;
    final r = math.Random(7);
    c.save();
    c.clipRRect(
      RRect.fromRectAndRadius(rect.inflate(4), const Radius.circular(16)),
    );
    final glow = Paint()
      ..color = color.withValues(alpha: .6 * fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final line = Paint()
      ..color = Colors.white.withValues(alpha: .9 * fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (var i = 0; i < 7; i++) {
      var ang = i * math.pi * 2 / 7 + (r.nextDouble() - .5) * .5;
      final len = 40 + r.nextDouble() * 70;
      const segs = 5;
      var pos = o;
      final path = Path()..moveTo(pos.dx, pos.dy);
      for (var s = 0; s < segs; s++) {
        ang += (r.nextDouble() - .5) * .9;
        pos += Offset(math.cos(ang), math.sin(ang)) * (len / segs * grow);
        path.lineTo(pos.dx, pos.dy);
      }
      c.drawPath(path, glow);
      c.drawPath(path, line);
    }
    c.restore();
  }

  void _debris(Canvas c, double p) {
    if (p >= 1) return;
    final r = math.Random(17);
    for (var i = 0; i < 22; i++) {
      final a = -math.pi / 2 + (r.nextDouble() - .5) * 2.2;
      final v = 90 + r.nextDouble() * 160;
      final sz = 3 + r.nextDouble() * 4;
      final rot0 = r.nextDouble() * 6;
      final px = o.dx + math.cos(a) * v * p;
      final py = o.dy + math.sin(a) * v * p + 520 * p * p;
      c.save();
      c.translate(px, py);
      c.rotate(rot0 + p * 8);
      c.drawRect(
        Rect.fromCenter(center: Offset.zero, width: sz * 1.6, height: sz),
        Paint()
          ..color = Color.lerp(
            color,
            const Color(0xFF3A0A0C),
            i.isEven ? .0 : .6,
          )!.withValues(alpha: 1 - p),
      );
      c.restore();
    }
  }

  void _settle(Canvas c) {
    final q = _seg(t, .74, .92);
    if (q <= 0 || q >= 1) return;
    c.drawPath(
      _plate(cell.inflate(26 * (1 - _ease(q)))),
      Paint()
        ..color = color.withValues(alpha: (1 - q) * .8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  // ---- hantaman keras: luka (sabetan + hati pecah), tersingkir (cap) ----
  void _impactHard(Canvas c, bool eliminated) {
    if (t < .40) return;
    final p = _seg(t, .40, .84);
    _flash(c, p, radius: eliminated ? 190 : 120);
    _rings(c, p);
    if (eliminated) _rays(c, p);
    _sparks(c, o, p, eliminated ? 36 : 20, 5, eliminated ? 260 : 200, color);
    _cracks(c, p);
    if (eliminated) {
      _debris(c, p);
      _settle(c);
      _stamp(c);
    } else {
      _slash(c);
      _heartBreak(c);
    }
  }

  // ---- hantaman lembut: aksi musyawarah ----
  void _impactSoft(Canvas c) {
    if (t < .40) return;
    final p = _seg(t, .40, .84);
    _flash(c, p, radius: 90);
    _rings(c, p);
    _sparks(c, o, p, 12, 9, 120, color);
  }

  // ---- pulih: cahaya naik dari bawah, partikel melayang ke atas ----
  void _spark4(Canvas c, Offset p, double s, Color col, double a) {
    final pa = Paint()
      ..color = col.withValues(alpha: a)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    c.drawLine(p + Offset(-s * 2, 0), p + Offset(s * 2, 0), pa);
    c.drawLine(p + Offset(0, -s * 2), p + Offset(0, s * 2), pa);
    c.drawCircle(p, s * .7, Paint()..color = Colors.white.withValues(alpha: a));
  }

  void _heal(Canvas c, Size size) {
    _projectile(
      c,
      from: Offset(o.dx - 30, size.height + 20),
      ctrl: Offset(o.dx + 60, o.dy + 160),
      heavy: false,
    );
    if (t < .40) return;
    final p = _seg(t, .40, .90);
    // pendar hijau di seluruh ubin
    c.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(14)),
      Paint()
        ..color = color.withValues(
          alpha: .28 * (1 - p) * math.sin(math.min(1.0, p * 3) * math.pi / 2),
        ),
    );
    _flash(c, p, radius: 100);
    _rings(c, p);
    _heartHeal(c);
    final r = math.Random(21);
    for (var i = 0; i < 18; i++) {
      final x = rect.left + r.nextDouble() * rect.width;
      final y0 = rect.bottom - r.nextDouble() * rect.height * .6;
      final rise = 60 + r.nextDouble() * 80;
      final delay = r.nextDouble() * .35;
      final sz = 2 + r.nextDouble() * 3;
      final q = _seg(p, delay, 1);
      if (q <= 0 || q >= 1) continue;
      final y = y0 - rise * _ease(q);
      _spark4(c, Offset(x, y), sz, color, math.sin(q * math.pi));
    }
  }

  // ---- kurungan: jeruji emas jatuh ke ubin, gembok muncul ----
  void _jail(Canvas c) {
    if (t < .18 || t > .96) return;
    final fade = 1 - _seg(t, .72, .94);
    if (fade <= 0) return;
    final area = rect.inflate(2);
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(area, const Radius.circular(14)));
    const n = 4;
    for (var i = 0; i < n; i++) {
      final x = area.left + area.width * (i + .5) / n;
      final t0 = .20 + i * .02;
      final k = _seg(t, t0, t0 + .14);
      if (k <= 0) continue;
      final drop = Curves.bounceOut.transform(k);
      final top = area.top - area.height * (1 - drop);
      final bar = Rect.fromLTWH(x - 2.5, top, 5, area.height + 4);
      c.drawRect(
        bar,
        Paint()
          ..shader = LinearGradient(
            colors: [
              const Color(0xFF6B5320).withValues(alpha: fade),
              const Color(0xFFF1D58A).withValues(alpha: fade),
              const Color(0xFF8A6A2A).withValues(alpha: fade),
            ],
          ).createShader(bar),
      );
    }
    c.restore();
    if (t >= .34) {
      final p = _seg(t, .34, .80);
      _flash(c, p, radius: 90);
      _rings(c, p);
      _sparks(c, o, p, 14, 13, 120, color);
    }
    final lk = Curves.elasticOut.transform(_seg(t, .38, .60));
    if (lk > 0) {
      final icon = Icons.lock_rounded;
      final tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: 38 * lk,
            color: Colors.white.withValues(alpha: fade),
            shadows: [
              Shadow(
                color: color.withValues(alpha: .9 * fade),
                blurRadius: 16,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, o - Offset(tp.width / 2, tp.height / 2));
      tp.dispose();
    }
  }

  // ---- bentuk papan: kiri-atas & kanan-bawah dipotong (sama dengan grid) ----
  Path _plate(Rect r) {
    const big = 16.0, small = 4.0;
    return Path()
      ..moveTo(r.left + big, r.top)
      ..lineTo(r.right - small, r.top)
      ..lineTo(r.right, r.top + small)
      ..lineTo(r.right, r.bottom - big)
      ..lineTo(r.right - big, r.bottom)
      ..lineTo(r.left + small, r.bottom)
      ..lineTo(r.left, r.bottom - small)
      ..lineTo(r.left, r.top + big)
      ..close();
  }

  void _glyph(
      Canvas c,
      IconData icon,
      Offset center,
      double size,
      Color col, {
        double alpha = 1,
        double angle = 0,
        Offset shift = Offset.zero,
        int half = 0,
        List<Shadow>? shadows,
      }) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: size,
          color: col.withValues(alpha: alpha.clamp(0.0, 1.0).toDouble()),
          shadows: shadows,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    c.save();
    c.translate(center.dx + shift.dx, center.dy + shift.dy);
    c.rotate(angle);
    if (half < 0) c.clipRect(Rect.fromLTRB(-size, -size, 0, size));
    if (half > 0) c.clipRect(Rect.fromLTRB(0, -size, size, size));
    tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
    c.restore();
    tp.dispose();
  }

  // ---- luka: tiga goresan cakar menyilang potret ----
  void _blade(Canvas c, Offset a, Offset b, double k, double w, double fade) {
    if (k <= 0) return;
    final end = Offset.lerp(a, b, k)!;
    c.drawLine(
      a,
      end,
      Paint()
        ..color = color.withValues(alpha: .55 * fade)
        ..strokeWidth = w * 2.6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    c.drawLine(
      a,
      end,
      Paint()
        ..color = color.withValues(alpha: fade)
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round,
    );
    c.drawLine(
      a,
      end,
      Paint()
        ..color = Colors.white.withValues(alpha: fade)
        ..strokeWidth = w * .4
        ..strokeCap = StrokeCap.round,
    );
  }

  void _slash(Canvas c) {
    if (t < .40) return;
    final p = _seg(t, .40, .82);
    final k = Curves.easeOutCubic.transform(_seg(p, 0, .2));
    final fade = 1 - _seg(p, .4, 1);
    if (k <= 0 || fade <= 0) return;
    c.save();
    c.clipRect(rect.inflate(10));
    const widths = [3.0, 4.6, 3.0];
    for (var i = 0; i < 3; i++) {
      final dx = (i - 1) * rect.width * .26;
      _blade(
        c,
        Offset(rect.left + rect.width * .15 + dx, rect.top - 6),
        Offset(rect.right - rect.width * .15 + dx, rect.bottom + 6),
        _seg(k, i * .12, 1),
        widths[i],
        fade,
      );
    }
    c.restore();
  }

  // ---- luka: hati yang hilang membengkak lalu pecah dua ----
  void _heartBreak(Canvas c) {
    final h = heart;
    if (h == null || t < .40) return;
    final p = _seg(t, .40, .88);
    final ctr = h.center;
    const red = Color(0xFFE85F64);
    final swell = _seg(p, 0, .25);
    final split = _seg(p, .25, 1);
    final big = 14 * 1.9;
    if (split <= 0) {
      final s = 14 + (big - 14) * Curves.easeOut.transform(swell);
      c.drawCircle(
        ctr,
        10 + 16 * swell,
        Paint()
          ..color = red.withValues(alpha: .35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      _glyph(
        c,
        Icons.favorite_rounded,
        ctr,
        s,
        red,
        shadows: [Shadow(color: Colors.white.withValues(alpha: .8), blurRadius: 8)],
      );
      return;
    }
    final e = _ease(split);
    final a = 1 - _seg(split, .45, 1);
    for (final side in const [-1, 1]) {
      _glyph(
        c,
        Icons.favorite_rounded,
        ctr,
        big,
        red,
        alpha: a,
        half: side,
        angle: side * .9 * e,
        shift: Offset(side * 20 * e, -8 * e + 46 * e * e),
      );
    }
    _sparks(c, ctr, split, 12, 31, 60, red);
  }

  // ---- pulih: hati yang kembali berdenyut membesar lalu menetap ----
  void _heartHeal(Canvas c) {
    final h = heart;
    if (h == null || t < .40) return;
    final p = _seg(t, .40, .90);
    final ctr = h.center;
    const red = Color(0xFFE85F64);
    final pop = math.sin(math.min(1.0, p * 1.6) * math.pi);
    c.drawCircle(
      ctr,
      8 + 30 * _ease(p),
      Paint()
        ..color = color.withValues(alpha: .45 * (1 - p))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    _glyph(
      c,
      Icons.favorite_rounded,
      ctr,
      14 * (1 + 1.1 * pop),
      red,
      alpha: 1 - _seg(p, .7, 1),
      shadows: [Shadow(color: color, blurRadius: 12)],
    );
    _sparks(c, ctr, p, 10, 41, 46, color);
  }

  // ---- tersingkir: cap merah menghantam papan dari jarak dekat ----
  void _stamp(Canvas c) {
    if (t < .62) return;
    final q = Curves.easeInCubic.transform(_seg(t, .62, .73));
    final a = (q * 2).clamp(0.0, 1.0).toDouble();
    const red = Color(0xFFE85F64);
    final tp = TextPainter(
      text: TextSpan(
        text: 'TERSINGKIR',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.6,
          color: red.withValues(alpha: a),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final box = Rect.fromCenter(
      center: Offset.zero,
      width: tp.width + 26,
      height: tp.height + 14,
    );
    c.save();
    c.translate(cell.center.dx, cell.center.dy);
    c.rotate(-.14);
    c.scale(2.6 - 1.6 * q);
    c.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(6)),
      Paint()..color = const Color(0xFF240A0C).withValues(alpha: .86 * a),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(6)),
      Paint()
        ..color = red.withValues(alpha: a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(box.deflate(4.5), const Radius.circular(3)),
      Paint()
        ..color = red.withValues(alpha: .7 * a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
    c.restore();
    tp.dispose();
  }

  @override
  bool shouldRepaint(_OperationPaint old) =>
      old.t != t ||
          old.rect != rect ||
          old.cell != cell ||
          old.heart != heart ||
          old.color != color ||
          old.kind != kind;
}
/// Memetakan waktu agar berhenti sesaat di titik kontak (hit-stop):
/// 0..34% -> 0..40% (sedikit dipercepat), 34..40% -> ditahan, sisanya normal.
class _HitStop extends Curve {
  const _HitStop();
  @override
  double transformInternal(double x) {
    if (x < .34) return x / .34 * .40;
    if (x < .40) return .40 + (x - .34) / .06 * .005;
    return .405 + (x - .40) / .60 * .595;
  }
}