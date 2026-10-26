import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/game_repository.dart';

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
    required this.isAntag,
    required this.waiting,
    required this.readyCount,
    required this.total,
    required this.onContinue,
  });

  @override
  State<EffectsView> createState() => _EffectsViewState();
}

class _EffectsViewState extends State<EffectsView> {
  List<Map<String, dynamic>> rows = [];
  bool loaded = false;
  int revealed = 0;
  int arrived = 0;
  int shown = 0;
  bool gray = false;
  Timer? timer;

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
    super.dispose();
  }

  void _arrive(Map<String, dynamic> row) {
    if (!mounted) return;
    setState(() {
      arrived++;
      shown = row['leaves_after'] as int;
      if (row['kind'] == 'bad') gray = true;
    });
    if (row['kind'] == 'bad') {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => gray = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = loaded && arrived >= rows.length;
    final bg =
    widget.isAntag ? const Color(0xFF14131A) : const Color(0xFF12201E);
    final treeColor = Color.lerp(
        Colors.blueGrey.shade700, Colors.greenAccent, (shown / 30).clamp(0.0, 1.0));

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: gray ? 0.0 : 1.0),
      duration: const Duration(milliseconds: 500),
      builder: (_, s, child) =>
          ColorFiltered(colorFilter: ColorFilter.matrix(_sat(s)), child: child),
      child: Container(
        color: bg,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text('Hasil persembahan hari ${widget.day}',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.park, size: 150, color: treeColor),
                  Text('$shown',
                      style: const TextStyle(
                          fontSize: 48, fontWeight: FontWeight.bold)),
                  const Text('daun'),
                ],
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
        final riseT = bad ? (t / 0.6).clamp(0.0, 1.0) : (t / 0.8).clamp(0.0, 1.0);
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
        final opacity = t > 0.85 ? (1 - (t - 0.85) / 0.15).clamp(0.0, 1.0) : 1.0;
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
                  color: bad
                      ? const Color(0xFF3A2A44)
                      : const Color(0xFF2E7D5B),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                      color: bad ? Colors.purpleAccent : Colors.lightGreenAccent),
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