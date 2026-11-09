import 'package:flutter/material.dart';
import '../common/art.dart';
import 'dart:math' as math;

/// Judul pembuka fase (title-musyawarah, title-pasarriset): tampil sendirian
/// di tengah selama ~2,2 detik di atas isi fase, lalu memudar. Hanya diputar
/// sekali per [id] (tidak diulang saat layar dibangun ulang); ketuk untuk
/// melewati.
class PhaseTitle extends StatefulWidget {
  final String id;
  final String icon;
  final Widget child;
  const PhaseTitle(
      {super.key, required this.id, required this.icon, required this.child});

  @override
  State<PhaseTitle> createState() => _PhaseTitleState();
}

class _PhaseTitleState extends State<PhaseTitle>
    with SingleTickerProviderStateMixin {
  static final Set<String> _seen = {};
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200));
  bool _show = false;

  @override
  void initState() {
    super.initState();
    if (_seen.add(widget.id)) {
      _show = true;
      _c.addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          setState(() => _show = false);
        }
      });
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_show)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _show = false),
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final t = _c.value;
                  // masuk 0-0.22, tahan, keluar 0.78-1
                  final e = (math.min(t / 0.22, (1 - t) / 0.22))
                      .clamp(0.0, 1.0)
                      .toDouble();
                  final grow = Curves.easeOutCubic
                      .transform((t / 0.45).clamp(0.0, 1.0).toDouble());
                  return LayoutBuilder(builder: (context, box) {
                    final availableHeight = math.max(0.0, box.maxHeight - 8);
                    final w = math.min(
                      math.min(340.0, box.maxWidth * 0.82),
                      availableHeight * 2.2,
                    );
                    return ColoredBox(
                      color: Colors.black.withValues(alpha: 0.7 * e),
                      child: Center(
                        child: Opacity(
                          opacity: e,
                          child: Transform.scale(
                            scale: 0.9 + 0.1 * grow,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: w,
                                  height: w / 2.2,
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(colors: [
                                      const Color(0xFFE8C766)
                                          .withValues(alpha: 0.22),
                                      Colors.transparent,
                                    ]),
                                  ),
                                  child: GameIcon(widget.icon,
                                      width: w, height: w / 2.2),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: w * 0.7 * grow,
                                  height: 1.5,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [
                                      Colors.transparent,
                                      const Color(0xFFE8C766)
                                          .withValues(alpha: 0.9),
                                      Colors.transparent,
                                    ]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  });
                },
              ),
            ),
          ),
      ],
    );
  }
}