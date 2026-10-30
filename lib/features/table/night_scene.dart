import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../common/ornate.dart';

/// Layar malam di antara dua hari biasa, diputar SEBELUM adegan fajar.
///
/// [rows] berasal dari `night_reports`: pengumuman untuk semua pemain
/// (user_id kosong, kind 'attack' atau 'calm') dan baris pribadi bila aku
/// menjadi korban (user_id = aku, kind 'private'). Sasaran dan jenis serangan
/// tidak pernah diumumkan ke semua orang.
class NightScene extends StatefulWidget {
  /// Hari yang baru berakhir.
  final int day;
  final List<Map<String, dynamic>> rows;
  final VoidCallback onDone;

  const NightScene({
    super.key,
    required this.day,
    required this.rows,
    required this.onDone,
  });

  @override
  State<NightScene> createState() => _NightSceneState();
}

class _NightSceneState extends State<NightScene>
    with TickerProviderStateMixin {
  static const _intro = 1500; // ms sebelum baris pertama
  static const _perLine = 1250; // jeda antar baris
  static const _hold = 2000; // jeda setelah baris terakhir

  late final List<Map<String, dynamic>> _lines;
  late final int _total;
  late final AnimationController _tl; // garis waktu
  late final AnimationController _sky; // bintang berkelip
  final List<Timer> _timers = [];
  bool _done = false;

  bool get _attack => _lines.any((l) => l['kind'] == 'attack');

  @override
  void initState() {
    super.initState();
    final pub = [
      for (final r in widget.rows)
        if (r['user_id'] == null) r
    ];
    final priv = [
      for (final r in widget.rows)
        if (r['user_id'] != null) r
    ];
    _lines = [...pub, ...priv];
    _total = _intro + _lines.length * _perLine + _hold;

    _tl = AnimationController(
        vsync: this, duration: Duration(milliseconds: _total))
      ..forward().whenComplete(_finish);
    _sky = AnimationController(
        vsync: this, duration: const Duration(seconds: 7))
      ..repeat();

    // Getar tiap baris muncul: berat untuk serangan, ringan untuk yang lain.
    for (var i = 0; i < _lines.length; i++) {
      _timers.add(Timer(Duration(milliseconds: _intro + i * _perLine), () {
        if (!mounted) return;
        final k = _lines[i]['kind'];
        if (k == 'attack') {
          HapticFeedback.heavyImpact();
        } else if (k == 'private') {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.selectionClick();
        }
      }));
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _tl.dispose();
    _sky.dispose();
    super.dispose();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  double _lineAlpha(int i, double ms) =>
      ((ms - (_intro + i * _perLine)) / 520).clamp(0.0, 1.0).toDouble();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF040813),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF040813), Color(0xFF0A1330), Color(0xFF16254A)],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _sky,
            builder: (_, _) => CustomPaint(
              painter: _StarsPainter(_sky.value),
              size: Size.infinite,
            ),
          ),
          SafeArea(
            child: AnimatedBuilder(
              animation: _tl,
              builder: (context, _) {
                final ms = _tl.value * _total;
                final titleA = (ms / 700).clamp(0.0, 1.0).toDouble();
                return Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 6, 8, 0),
                        child: TextButton.icon(
                          onPressed: _finish,
                          icon: const Icon(Icons.fast_forward_rounded, size: 20),
                          label: const Text('Lewati'),
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.white54),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Opacity(
                                  opacity: titleA,
                                  child: Transform.scale(
                                    scale: 0.85 + 0.15 * titleA,
                                    child: const SizedBox(
                                      width: 120,
                                      height: 120,
                                      child: CustomPaint(painter: _MoonPainter()),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Opacity(
                                  opacity: titleA,
                                  child: Column(
                                    children: [
                                      const Text(
                                        'MALAM',
                                        style: TextStyle(
                                          fontSize: 26,
                                          letterSpacing: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFE8EDFF),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Hari ${widget.day} berlalu',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.white54),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 26),
                                for (var i = 0; i < _lines.length; i++)
                                  _line(_lines[i], _lineAlpha(i, ms)),
                              ],
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
        ],
      ),
    );
  }

  Widget _line(Map<String, dynamic> l, double a) {
    final kind = '${l['kind']}';
    final text = '${l['text']}';
    final Color color;
    final IconData icon;
    String? tag;
    switch (kind) {
      case 'attack':
        color = EmbunColors.blood;
        icon = Icons.warning_amber_rounded;
      case 'private':
        color = EmbunColors.gold;
        icon = Icons.lock_rounded;
        tag = 'Hanya kamu yang tahu';
      default:
        color = const Color(0xFF8FD6B0);
        icon = Icons.bedtime_rounded;
    }
    return Opacity(
      opacity: a,
      child: Transform.translate(
        offset: Offset(0, 14 * (1 - a)),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.7), width: 1.4),
            boxShadow: kind == 'attack'
                ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 24)]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (tag != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(tag,
                            style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 0.6,
                                fontWeight: FontWeight.w800,
                                color: color)),
                      ),
                    Text(text,
                        style: const TextStyle(
                            fontSize: 15.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bintang kecil yang berkelip pelan (posisi tetap, kedip bergantung waktu).
class _StarsPainter extends CustomPainter {
  final double t;
  _StarsPainter(this.t);

  static final List<List<double>> _stars = () {
    final r = math.Random(11);
    return [
      for (var i = 0; i < 70; i++)
        [r.nextDouble(), r.nextDouble() * 0.7, 0.6 + r.nextDouble() * 1.4,
          r.nextDouble() * math.pi * 2, 0.6 + r.nextDouble() * 1.4],
    ];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (final s in _stars) {
      final tw = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(t * math.pi * 2 * s[4] + s[3]));
      p.color = Colors.white.withValues(alpha: 0.75 * tw);
      canvas.drawCircle(Offset(s[0] * size.width, s[1] * size.height), s[2], p);
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter old) => old.t != t;
}

/// Bulan sabit dengan pendar lembut.
class _MoonPainter extends CustomPainter {
  const _MoonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.34;

    canvas.drawCircle(
      c,
      r * 1.9,
      Paint()
        ..shader = RadialGradient(colors: [
          const Color(0xFFF3E9B8).withValues(alpha: 0.30),
          const Color(0xFFF3E9B8).withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: c, radius: r * 1.9)),
    );

    final full = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    final cut = Path()
      ..addOval(Rect.fromCircle(center: c.translate(r * 0.55, -r * 0.2), radius: r * 0.86));
    canvas.drawPath(
      Path.combine(PathOperation.difference, full, cut),
      Paint()..color = const Color(0xFFF6EDBF),
    );
  }

  @override
  bool shouldRepaint(covariant _MoonPainter old) => false;
}