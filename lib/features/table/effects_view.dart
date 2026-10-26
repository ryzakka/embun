import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../../data/game_repository.dart';
import '../common/art.dart';

List<double> _sat(double s) {
  final inv = 1 - s;
  final r = 0.2126 * inv, g = 0.7152 * inv, b = 0.0722 * inv;
  return [
    r + s, g, b, 0, 0,
    r, g + s, b, 0, 0,
    r, g, b + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

class EffectsView extends StatefulWidget {
  final GameRepository repo;
  final String gameId;
  final int day;
  final int finalLeaves;
  final bool isAntag;
  final bool waiting;
  final int readyCount;
  final int total;
  final Future<void> Function() onContinue;

  const EffectsView({
    super.key,
    required this.repo,
    required this.gameId,
    required this.day,
    required this.finalLeaves,
    required this.isAntag,
    required this.waiting,
    required this.readyCount,
    required this.total,
    required this.onContinue,
  });

  @override
  State<EffectsView> createState() => _EffectsViewState();
}

class _EffectsViewState extends State<EffectsView>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> rows = [];
  bool loaded = false;
  int revealed = 0;
  int arrived = 0;
  late int shown = widget.finalLeaves;
  bool gray = false;
  Timer? timer;

  // Denyut hantaman tiap gelembung tiba (baik: cincin cahaya; buruk: retak
  // dan pohon terguncang).
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));
  bool _lastBad = false;

  @override
  void initState() {
    super.initState();
    widget.repo.effects(widget.gameId, widget.day).then((r) {
      if (!mounted) return;
      setState(() {
        rows = r;
        loaded = true;
        if (r.isNotEmpty) {
          shown = (r.first['leaves_after'] as int) - (r.first['delta'] as int);
        }
      });
      if (r.isEmpty) return;
      setState(() => revealed = 1);
      timer = Timer.periodic(const Duration(milliseconds: 1400), (t) {
        if (!mounted || revealed >= rows.length) {
          t.cancel();
          return;
        }
        setState(() => revealed++);
      });
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _arrive(Map<String, dynamic> row) {
    if (!mounted) return;
    final isBad = row['kind'] == 'bad';
    _lastBad = isBad;
    _pulse.forward(from: 0);
    if (isBad) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    setState(() {
      arrived++;
      // Hitungan daun baru berubah setelah SEMUA gelembung tiba, supaya
      // Topeng Warga tidak bocor lewat angka yang turun saat label "+1 daun".
      if (arrived >= rows.length) shown = widget.finalLeaves;
      if (isBad) gray = true;
    });
    if (isBad) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => gray = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = loaded && arrived >= rows.length;
    final sakura = shown >= 30
        ? AssetCatalog.I.file(pohonDir, 'pohon0-sakura')
        : null;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: gray ? 0.0 : 1.0),
      duration: const Duration(milliseconds: 500),
      builder: (_, s, child) =>
          ColorFiltered(colorFilter: ColorFilter.matrix(_sat(s)), child: child),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Backdrop(path: landscapePath(shown), dark: widget.isAntag, dim: 0.5),
          SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 52, 24, 84),
                  child: Column(
                    children: [
                      Expanded(
                          child:
                          AnimatedBuilder(
                              animation: _pulse,
                              builder: (_, child) {
                                // Guncangan hanya untuk gelembung buruk.
                                final k = _lastBad
                                    ? sin(_pulse.value * 70) *
                                    10 *
                                    (1 - _pulse.value)
                                    : 0.0;
                                return Transform.translate(
                                    offset: Offset(k, 0), child: child);
                              },
                              child: TreePortrait(
                                  leaves: shown, pathOverride: sakura))),
                      const SizedBox(height: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 450),
                        transitionBuilder: (w, a) => ScaleTransition(
                          scale: Tween<double>(begin: 1.6, end: 1.0).animate(
                              CurvedAnimation(
                                  parent: a, curve: Curves.easeOutBack)),
                          child: FadeTransition(opacity: a, child: w),
                        ),
                        child: Text('$shown daun',
                            key: ValueKey(shown),
                            style: const TextStyle(
                                fontSize: 30, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text('Hasil persembahan hari ${widget.day}',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => _pulse.isAnimating
                          ? CustomPaint(
                          painter: _PulsePainter(
                              t: _pulse.value,
                              bad: _lastBad,
                              seed: arrived))
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
                for (var i = 0; i < revealed && i < rows.length; i++)
                  IgnorePointer(
                    child: _Bubble(
                      key: ValueKey('b$i'),
                      row: rows[i],
                      onArrive: () => _arrive(rows[i]),
                    ),
                  ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: !done
                        ? const SizedBox(height: 40)
                        : widget.waiting
                        ? Text(
                        'Menunggu warga lain... ${widget.readyCount}/${widget.total}')
                        : FilledButton(
                      onPressed: widget.onContinue,
                      child: const Text('Lanjut'),
                    ),
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

class _Bubble extends StatefulWidget {
  final Map<String, dynamic> row;
  final VoidCallback onArrive;
  const _Bubble({super.key, required this.row, required this.onArrive});

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> with SingleTickerProviderStateMixin {
  late final AnimationController c;
  bool arrived = false;

  bool get bad => widget.row['kind'] == 'bad';
  double get dx => (((widget.row['seq'] as int) * 37) % 100) / 100 * 1.2 - 0.6;

  @override
  void initState() {
    super.initState();
    c = AnimationController(
        vsync: this, duration: Duration(milliseconds: bad ? 3200 : 2000));
    c.addListener(() {
      final end = bad ? 0.6 : 0.8;
      if (!arrived && c.value >= end) {
        arrived = true;
        widget.onArrive();
      }
    });
    c.forward();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (_, __) {
        final t = c.value;
        final riseT =
        bad ? (t / 0.6).clamp(0.0, 1.0) : (t / 0.8).clamp(0.0, 1.0);
        final curve = bad ? Curves.easeInOut : Curves.easeOutCubic;
        final y = 0.9 - 1.3 * curve.transform(riseT);
        var x = dx;
        var scale = 1.0;
        if (bad && t > 0.6 && t < 0.9) {
          final k = (t - 0.6) / 0.3;
          x += sin(k * 70) * 0.06;
          scale = 1.12;
        } else if (!bad) {
          scale = 1.0 + 0.1 * sin(riseT * pi);
        }
        final opacity =
        t > 0.85 ? (1 - (t - 0.85) / 0.15).clamp(0.0, 1.0) : 1.0;
        return Align(
          alignment: Alignment(x, y),
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color:
                  bad ? const Color(0xFF3A2A44) : const Color(0xFF2E7D5B),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                      color:
                      bad ? Colors.purpleAccent : Colors.lightGreenAccent),
                ),
                child: Text(widget.row['label'] as String,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ),
        );
      },
    );
  }
}
/// Denyut hantaman di pohon: cincin cahaya dan kilau untuk efek baik;
/// vinyet gelap dan retakan bercahaya ungu untuk efek buruk.
class _PulsePainter extends CustomPainter {
  final double t;
  final bool bad;
  final int seed;
  _PulsePainter({required this.t, required this.bad, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.42);
    final e = Curves.easeOutCubic.transform(t);
    final fade = (1 - t).clamp(0.0, 1.0).toDouble();
    final rnd = Random(seed * 131 + 7);

    if (bad) {
      final rect = Offset.zero & size;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            radius: 0.9,
            colors: [
              Colors.transparent,
              const Color(0xFF1A1030).withValues(alpha: 0.6 * fade),
            ],
            stops: const [0.35, 1.0],
          ).createShader(rect),
      );
      canvas.drawCircle(
        c,
        30 + 200 * e,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * fade + 0.5
          ..color = const Color(0xFFB07CE8).withValues(alpha: fade),
      );
      final crack = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.5
        ..color = const Color(0xFFE6D6FF).withValues(alpha: fade);
      for (var k = 0; k < 9; k++) {
        final ang = rnd.nextDouble() * 2 * pi;
        final len = (70 + rnd.nextDouble() * 130) * e;
        final path = Path()..moveTo(c.dx, c.dy);
        var p = c;
        const steps = 4;
        for (var i = 1; i <= steps; i++) {
          final f = i / steps;
          final jitter = (rnd.nextDouble() - 0.5) * 24;
          p = c +
              Offset(cos(ang), sin(ang)) * (len * f) +
              Offset(-sin(ang), cos(ang)) * jitter;
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, crack);
      }
    } else {
      for (var ring = 0; ring < 2; ring++) {
        final rs = ((t - ring * 0.15) / (1 - ring * 0.15)).clamp(0.0, 1.0);
        if (rs <= 0) continue;
        final re = Curves.easeOutCubic.transform(rs.toDouble());
        canvas.drawCircle(
          c,
          24 + 170 * re,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5 * (1 - rs) + 0.5
            ..color = Color.lerp(const Color(0xFFFFE08A),
                const Color(0xFF9DF0B8), ring.toDouble())!
                .withValues(alpha: (1 - rs).clamp(0.0, 1.0).toDouble()),
        );
      }
      for (var k = 0; k < 12; k++) {
        final ang = rnd.nextDouble() * 2 * pi;
        final dist = (50 + rnd.nextDouble() * 120) * e;
        final p = c + Offset(cos(ang), sin(ang)) * dist + Offset(0, -30 * e);
        canvas.drawCircle(
          p,
          1 + 3 * fade,
          Paint()
            ..color = (k.isEven
                ? const Color(0xFFFFF2B0)
                : const Color(0xFFBFF5D0))
                .withValues(alpha: fade),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PulsePainter old) => old.t != t;
}