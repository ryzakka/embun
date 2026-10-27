import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/server_clock.dart';
import '../common/art.dart';
import '../common/ornate.dart';

class Countdown extends StatefulWidget {
  final DateTime? deadline;
  final TextStyle? style;
  const Countdown({super.key, required this.deadline, this.style});

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.deadline;
    if (d == null) return const SizedBox.shrink();
    var left = d.difference(ServerClock.now()).inSeconds;
    if (left < 0) left = 0;
    final m = left ~/ 60;
    final s = (left % 60).toString().padLeft(2, '0');
    final urgent = left <= 10;
    final accent = urgent ? EmbunColors.blood : EmbunColors.gold;
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 2, 12, 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GameIcon('timer', size: 28),
          const SizedBox(width: 6),
          Text(
            '$m:$s',
            style: (widget.style ?? const TextStyle())
                .copyWith(fontWeight: FontWeight.bold, color: accent),
          ),
        ],
      ),
    );
  }
}