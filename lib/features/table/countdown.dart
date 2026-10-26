import 'dart:async';
import 'package:flutter/material.dart';

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
    var left = d.difference(DateTime.now()).inSeconds;
    if (left < 0) left = 0;
    final m = left ~/ 60;
    final s = (left % 60).toString().padLeft(2, '0');
    return Text(
      '$m:$s',
      style: (widget.style ?? const TextStyle())
          .copyWith(color: left <= 10 ? Colors.redAccent : null),
    );
  }
}