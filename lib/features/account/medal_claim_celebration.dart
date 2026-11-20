import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/profile_medals.dart';
import '../common/ornate.dart';

const _impact = .45; // detik: medali "menghantam"
const _burst = 2.8; // detik: durasi ledakan

Future<ui.FragmentProgram?>? _program;
Future<ui.FragmentProgram?> _loadProgram() =>
    _program ??= ui.FragmentProgram.fromAsset('shaders/medal_claim.frag')
        .then<ui.FragmentProgram?>((p) => p)
        .catchError((_) => null);

double _fade(double s, double start, double length) =>
    ((s - start) / length).clamp(0.0, 1.0);

class MedalClaimCelebration extends StatefulWidget {
  const MedalClaimCelebration({
    super.key,
    required this.medal,
    required this.art,
  });
  final ProfileMedal medal;
  final Widget art;
  @override
  State<MedalClaimCelebration> createState() => _MedalClaimCelebrationState();
}

class _MedalClaimCelebrationState extends State<MedalClaimCelebration>
    with SingleTickerProviderStateMixin {
  static const _total = 24; // detik; setelah itu animasi berhenti
  late final _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: _total),
  );
  ui.FragmentShader? _shader;
  bool _started = false, _still = false, _hit = false;

  double get _seconds => _still ? 99 : _clock.value * _total;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _loadProgram().then((program) {
      if (!mounted || program == null) return;
      setState(() => _shader = program.fragmentShader());
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _still = true;
    } else {
      _clock.addListener(_tick);
      _clock.forward();
    }
  }

  void _tick() {
    if (!_hit && _seconds >= _impact) {
      _hit = true;
      HapticFeedback.heavyImpact();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Dialog.fullscreen(
      key: const ValueKey('medal-claim-celebration'),
      backgroundColor: const Color(0xF2071410),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth, h = box.maxHeight;
          final side = math.min(math.min(w * .8, 260.0), h * .36);
          const alignY = -.12;
          final center = Offset(w / 2, h / 2 + alignY * (h - side) / 2);
          return AnimatedBuilder(
            animation: _clock,
            builder: (context, _) {
              final s = _seconds;
              final progress = s < _impact
                  ? -1.0
                  : ((s - _impact) / _burst).clamp(0.0, 1.0);
              final shader = _shader;
              final CustomPainter? painter = progress < 0
                  ? null
                  : shader != null
                  ? _ShaderPainter(shader, center, progress, s)
                  : _MedalGlow(progress, center: center, radius: side * .75);
              final slam = Curves.easeOutCubic.transform(
                (s / _impact).clamp(0.0, 1.0),
              );
              final since = s - _impact;
              final shake = since > 0
                  ? math.sin(since * 70) * 10 * math.exp(-since * 8)
                  : 0.0;
              return Stack(
                children: [
                  if (painter != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: RepaintBoundary(
                          child: CustomPaint(painter: painter),
                        ),
                      ),
                    ),
                  Positioned(
                    top: pad.top + 24,
                    left: 16,
                    right: 16,
                    child: Opacity(
                      opacity: _fade(s, .5, .4),
                      child: Semantics(
                        liveRegion: true,
                        child: const Text(
                          'Medali baru diraih!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: EmbunColors.gold,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: const Alignment(0, alignY),
                    child: Transform.translate(
                      offset: Offset(
                        shake,
                        since > 0 ? math.sin(s * 2) * 3 : 0,
                      ),
                      child: Transform.scale(
                        scale: 2.6 - 1.6 * slam,
                        child: Opacity(
                          opacity: _fade(s, 0, .12),
                          child: SizedBox.square(
                            dimension: side,
                            child: FittedBox(child: widget.art),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        0,
                        24,
                        pad.bottom + 20,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 420,
                          maxHeight: h * .5,
                        ),
                        child: SingleChildScrollView(
                          child: Opacity(
                            opacity: _fade(s, 1.0, .5),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.medal.name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: EmbunColors.gold,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.medal.series.requirement(
                                    widget.medal.target,
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Sudah ditambahkan ke koleksimu.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 20),
                                FilledButton(
                                  key: const ValueKey('close-medal-celebration'),
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Lanjutkan'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ShaderPainter extends CustomPainter {
  const _ShaderPainter(this.shader, this.center, this.progress, this.seconds);
  final ui.FragmentShader shader;
  final Offset center;
  final double progress, seconds;
  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, center.dx)
      ..setFloat(3, center.dy)
      ..setFloat(4, progress)
      ..setFloat(5, seconds);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _ShaderPainter old) => true;
}

/// Cadangan bila shader tidak dapat dimuat.
class _MedalGlow extends CustomPainter {
  const _MedalGlow(this.t, {this.center, this.radius});
  final double t;
  final Offset? center;
  final double? radius;
  @override
  void paint(Canvas canvas, Size size) {
    final center = this.center ?? size.center(Offset.zero);
    final radius = this.radius ?? size.shortestSide * .49;
    final strength = (.35 + .3 * math.sin(t * math.pi)).clamp(0.0, 1.0);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            EmbunColors.gold.withValues(alpha: strength),
            const Color(0xFF79C48F).withValues(alpha: strength * .25),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6 + t * .4;
      final inner = Offset(math.cos(angle), math.sin(angle)) * (radius * .5);
      final outer = Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawLine(
        center + inner,
        center + outer,
        Paint()
          ..color = EmbunColors.gold.withValues(alpha: .10 + .12 * (1 - t))
          ..strokeWidth = 3,
      );
    }
    for (var i = 0; i < 28; i++) {
      final angle = i * 2.39996;
      final spread = (.35 + .65 * Curves.easeOut.transform(t));
      final distance = radius * (.5 + (i % 7) / 13) * spread;
      final point =
          center + Offset(math.cos(angle), math.sin(angle)) * distance;
      final shimmer = (.35 + .65 * math.sin(t * 9 + i).abs());
      final paint = Paint()
        ..color = (i.isEven ? EmbunColors.gold : Colors.white).withValues(
          alpha: shimmer * (.7 - .3 * t),
        );
      final r = 1.5 + (i % 3);
      canvas.drawLine(
        point - Offset(r, 0),
        point + Offset(r, 0),
        paint..strokeWidth = 1.2,
      );
      canvas.drawLine(point - Offset(0, r), point + Offset(0, r), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MedalGlow old) => old.t != t;
}