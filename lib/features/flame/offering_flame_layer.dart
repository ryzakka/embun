// ignore_for_file: use_null_aware_elements
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Only public card artwork and presentation properties enter this renderer.
/// There is deliberately no repository, player ID, RPC or game-state mutation.
class OfferingFlameCard {
  final String name;
  final String? imagePath;
  final bool bad;
  final bool advanced;
  final bool blocked;

  const OfferingFlameCard({
    required this.name,
    this.imagePath,
    this.bad = false,
    this.advanced = false,
    this.blocked = false,
  });

  /// Main colour of the card once its face is revealed.
  Color get accent => advanced
      ? (bad ? const Color(0xFFFF5869) : const Color(0xFF7DF9C3))
      : (bad ? const Color(0xFFB486F0) : const Color(0xFFFFD866));

  /// Bright highlight tone (rays, sparks, sheen).
  Color get secondary => advanced
      ? (bad ? const Color(0xFFFFC2B8) : const Color(0xFFD6FFE9))
      : (bad ? const Color(0xFFE6D2FF) : const Color(0xFFFFF3C4));

  /// Deep tone (halo, smoke, lingering light).
  Color get deep => advanced
      ? (bad ? const Color(0xFFB3122A) : const Color(0xFF1FA67A))
      : (bad ? const Color(0xFF5B2A9E) : const Color(0xFFFF9F2E));

  /// Petal / leaf palette for good cards.
  List<Color> get palette => advanced
      ? const [Color(0xFF7DF9C3), Color(0xFFD6FFE9), Color(0xFF3DDC84)]
      : const [
    Color(0xFFFFD866),
    Color(0xFFFFF0B0),
    Color(0xFFFFB347),
    Color(0xFFFFE9A0),
  ];
}

/// Flutter's existing AnimationController remains the only ceremony clock.
/// Sampling time instead of accumulating dt prevents duplicate impacts after
/// resize, skipped frames or browser resume.
class OfferingFlameTimeline {
  final int count;
  final int perCardMs;
  final int leadMs;
  final int tailMs;

  const OfferingFlameTimeline({
    required this.count,
    required this.perCardMs,
    this.leadMs = 900,
    this.tailMs = 1800,
  });

  int get totalMs => leadMs + count * perCardMs + tailMs;
  double cardTime(double progress, int index) =>
      (progress.clamp(0.0, 1.0) * totalMs - leadMs - index * perCardMs) /
          perCardMs;
  bool faceVisible(double progress, int index) =>
      cardTime(progress, index) >= 0.36;
  double impactAge(double progress, int index) =>
      (cardTime(progress, index) - 0.86) * perCardMs / 1000;

  /// 0..1 progress of the final "Hayu weighs the offering" tail.
  double tailProgress(double progress) =>
      ((progress.clamp(0.0, 1.0) * totalMs - leadMs - count * perCardMs) /
          tailMs)
          .clamp(0.0, 1.0)
          .toDouble();
}

typedef OfferingImageLoader = Future<ui.Image?> Function(String path);

/// Transparent Flame canvas. Flutter retains the tree, official result labels,
/// counters, sound/haptics, scene transitions and tap-to-skip handling.
class OfferingFlameLayer extends StatefulWidget {
  final Animation<double> clock;
  final List<OfferingFlameCard> cards;
  final String? backPath;
  final int perCardMs;
  final VoidCallback onReady;
  final VoidCallback onFailure;
  final OfferingImageLoader? imageLoader;

  const OfferingFlameLayer({
    super.key,
    required this.clock,
    required this.cards,
    required this.perCardMs,
    required this.onReady,
    required this.onFailure,
    this.backPath,
    this.imageLoader,
  });

  @override
  State<OfferingFlameLayer> createState() => _OfferingFlameLayerState();
}

class _OfferingFlameLayerState extends State<OfferingFlameLayer> {
  late final OfferingFlameGame _game;
  bool _reportedFailure = false;

  @override
  void initState() {
    super.initState();
    _game = OfferingFlameGame(
      clock: widget.clock,
      cards: widget.cards,
      perCardMs: widget.perCardMs,
      backPath: widget.backPath,
      imageLoader: widget.imageLoader,
      onReady: () => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_reportedFailure) widget.onReady();
      }),
    );
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: IgnorePointer(
      child: GameWidget<OfferingFlameGame>(
        game: _game,
        autofocus: false,
        loadingBuilder: (_) => const SizedBox.expand(),
        errorBuilder: (_, error) {
          if (!_reportedFailure) {
            _reportedFailure = true;
            debugPrint('Flame persembahan gagal dimuat: $error');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) widget.onFailure();
            });
          }
          return const SizedBox.expand();
        },
      ),
    ),
  );
}

class OfferingFlameGame extends FlameGame {
  final Animation<double> clock;
  final List<OfferingFlameCard> cards;
  final String? backPath;
  final VoidCallback onReady;
  final OfferingImageLoader? imageLoader;
  final OfferingFlameTimeline timeline;
  final Map<String, ui.Image?> _art = {};
  bool _released = false;

  // Per-frame cached scene state (refreshed in render, read by components).
  Color _aura = const Color(0xFFFFD866);
  double _energy = 0;
  Offset _shake = Offset.zero;

  OfferingFlameGame({
    required this.clock,
    required List<OfferingFlameCard> cards,
    required int perCardMs,
    required this.onReady,
    this.backPath,
    this.imageLoader,
  }) : cards = List.unmodifiable(cards),
        timeline = OfferingFlameTimeline(
          count: cards.length,
          perCardMs: perCardMs,
        );

  double get progress => clock.value.clamp(0.0, 1.0).toDouble();
  @visibleForTesting
  int get loadedImageCount => _art.values.whereType<ui.Image>().length;
  Size get viewport => Size(canvasSize.x, canvasSize.y);
  Offset get target => Offset(viewport.width / 2, viewport.height * 0.50);
  double get cardHeight => (viewport.height * 0.30).clamp(110.0, 230.0);

  /// Scale factor so effects look the same on phones and wide browsers.
  double get unit =>
      (math.min(viewport.width, viewport.height) / 600).clamp(0.45, 1.6);

  /// Aura colour: gold, drifting to violet as bad cards land.
  Color get aura => _aura;

  /// 0..1: how many offerings have already landed (smoothed).
  double get energy => _energy;

  @override
  Color backgroundColor() => Colors.transparent;

  void _refresh() {
    final n = cards.length;
    var goodW = 0.0, badW = 0.0;
    var dx = 0.0, dy = 0.0;
    final u = unit;
    for (var i = 0; i < n; i++) {
      final ct = timeline.cardTime(progress, i);
      final w = _segment(ct, 0.86, 1.10);
      if (w > 0) {
        if (cards[i].bad && !cards[i].blocked) {
          badW += w;
        } else {
          goodW += w;
        }
      }
      final age = timeline.impactAge(progress, i);
      if (age >= 0 && age < 0.7) {
        final c = cards[i];
        final amp = c.blocked ? 2.5 : (c.bad ? 15.0 : 3.5);
        final k = 1 - age / 0.7;
        final a = amp * u * k * k;
        dx += math.sin(age * 85 + i) * a;
        dy += math.cos(age * 63 + i * 2) * a * 0.55;
      }
    }
    final total = goodW + badW;
    _energy = n == 0 ? 0 : (total / n).clamp(0.0, 1.0).toDouble();
    final mix = total == 0 ? 0.0 : badW / total;
    _aura = Color.lerp(const Color(0xFFFFD866), const Color(0xFFB486F0), mix)!;
    _shake = Offset(dx, dy);
  }

  @override
  void render(Canvas canvas) {
    _refresh();
    canvas.save();
    canvas.translate(_shake.dx, _shake.dy);
    super.render(canvas);
    canvas.restore();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final paths = {
      if (backPath != null) backPath!,
      for (final card in cards)
        if (card.imagePath != null) card.imagePath!,
    }.toList();
    // Bound parallel decoding and decoded image sizes for mobile browsers.
    for (var start = 0; start < paths.length; start += 4) {
      await Future.wait(paths.skip(start).take(4).map(_loadImage));
      if (_released) return;
    }
    add(_AmbientComponent(this));
    for (var i = 0; i < cards.length; i++) {
      add(_CardComponent(this, i));
      add(_ImpactComponent(this, i));
    }
    onReady();
  }

  Future<void> _loadImage(String path) async {
    ui.Image? decoded;
    try {
      if (imageLoader != null) {
        decoded = await imageLoader!(path);
      } else {
        final data = await rootBundle.load(path);
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          targetWidth: 384,
        );
        try {
          decoded = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      }
    } catch (error) {
      debugPrint('Gambar Flame belum tersedia: $path ($error)');
    }
    if (_released) {
      decoded?.dispose();
    } else {
      _art[path] = decoded;
    }
  }

  @override
  void onRemove() {
    _released = true;
    for (final image in _art.values) {
      image?.dispose();
    }
    _art.clear();
    super.onRemove();
  }
}

// ---------------------------------------------------------------- helpers

const _ice = Color(0xFFBDF2FF);
const _neutral = Color(0xFFE0CF9F);
const _neutralBright = Color(0xFFFFF3D0);
const _neutralDeep = Color(0xFFB8913F);

double _segment(double value, double start, double end) =>
    ((value - start) / (end - start)).clamp(0.0, 1.0).toDouble();

double _a(double x) => x < 0 ? 0.0 : (x > 1 ? 1.0 : x);

double _smooth(double x) {
  final t = _a(x);
  return t * t * (3 - 2 * t);
}

Offset _curve(Offset start, Offset control, Offset end, double t) =>
    start * ((1 - t) * (1 - t)) + control * (2 * (1 - t) * t) + end * (t * t);

/// Soft radial glow, additive by default so overlapping light blooms.
void _glow(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double alpha, {
      bool add = true,
    }) {
  final al = _a(alpha);
  if (radius <= 0 || al <= 0) return;
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..blendMode = add ? BlendMode.plus : BlendMode.srcOver
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: al),
          color.withValues(alpha: al * 0.32),
          color.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.42, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius)),
  );
}

/// Four-pointed twinkling star with a soft halo.
void _star(Canvas canvas, Offset c, double r, Color color, double alpha) {
  final al = _a(alpha);
  if (r <= 0 || al <= 0) return;
  final path = Path();
  for (var i = 0; i < 8; i++) {
    final rr = i.isEven ? r : r * 0.26;
    final ang = i * math.pi / 4 - math.pi / 2;
    final p = Offset(c.dx + math.cos(ang) * rr, c.dy + math.sin(ang) * rr);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  path.close();
  canvas.drawPath(
    path,
    Paint()
      ..blendMode = BlendMode.plus
      ..color = color.withValues(alpha: al),
  );
  _glow(canvas, c, r * 2.4, color, al * 0.55);
}

/// Fan of tapering light beams from [origin].
void _rays(
    Canvas canvas,
    Offset origin,
    int count,
    double rot,
    double length,
    double halfAngle,
    Color color,
    double alpha,
    ) {
  final al = _a(alpha);
  if (length <= 0 || al <= 0) return;
  for (var i = 0; i < count; i++) {
    final ang = rot + i * 2 * math.pi / count;
    final half = halfAngle * (i.isEven ? 1.0 : 0.6);
    final len = length * (i % 3 == 0 ? 1.0 : 0.72);
    final dir = Offset(math.cos(ang), math.sin(ang));
    final path = Path()
      ..moveTo(origin.dx, origin.dy)
      ..lineTo(
        origin.dx + math.cos(ang - half) * len,
        origin.dy + math.sin(ang - half) * len,
      )
      ..lineTo(
        origin.dx + math.cos(ang + half) * len,
        origin.dy + math.sin(ang + half) * len,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.linear(origin, origin + dir * len, [
          color.withValues(alpha: al),
          color.withValues(alpha: 0),
        ]),
    );
  }
}

class _Bit {
  final double angle, speed, size, spin, phase;
  final int tone;
  const _Bit(this.angle, this.speed, this.size, this.spin, this.phase, this.tone);
}

List<_Bit> _bits(
    math.Random r,
    int n,
    double minSpeed,
    double maxSpeed,
    double minSize,
    double maxSize,
    ) => List.generate(
  n,
      (i) => _Bit(
    r.nextDouble() * 2 * math.pi,
    minSpeed + r.nextDouble() * (maxSpeed - minSpeed),
    minSize + r.nextDouble() * (maxSize - minSize),
    r.nextDouble() * math.pi * 2,
    r.nextDouble() * math.pi * 2,
    i,
  ),
);

// ------------------------------------------------------------ ambient

/// Living backdrop: god rays, breathing aura, fireflies, spiralling motes,
/// and a heartbeat while Hayu weighs the offerings.
class _AmbientComponent extends Component {
  final OfferingFlameGame scene;
  _AmbientComponent(this.scene) : super(priority: 0);

  late final List<_Bit> _flies = _bits(math.Random(41), 38, 0.4, 1.4, 1.0, 2.6);
  late final List<_Bit> _swirl = _bits(math.Random(77), 30, 0.5, 1.0, 1.4, 3.0);

  @override
  void render(Canvas canvas) {
    final s = scene;
    if (s.viewport.isEmpty) return;
    final w = s.viewport.width, h = s.viewport.height;
    final minDim = math.min(w, h);
    final total = s.timeline.totalMs;
    final ms = s.progress * total;
    final sec = ms / 1000;
    final intro = _smooth(_segment(ms, 0, 900));
    final energy = s.energy;
    final aura = s.aura;
    final unit = s.unit;
    final target = s.target;
    final beat = math.pow(math.max(0.0, math.sin(sec * 2.4)), 8).toDouble();
    final tail = s.timeline.tailProgress(s.progress);

    // God rays pouring from above.
    final rayA = (0.055 + 0.08 * energy + 0.07 * tail) * intro;
    for (var i = 0; i < 9; i++) {
      final origin = Offset(w / 2 + (i - 4) * w * 0.035, -h * 0.06);
      final ang =
          math.pi / 2 + (i - 4) * 0.15 + math.sin(sec * 0.28 + i * 1.7) * 0.05;
      final half = 0.030 + 0.016 * math.sin(sec * 0.7 + i * 1.3);
      final len = h * 1.25;
      final dir = Offset(math.cos(ang), math.sin(ang));
      final path = Path()
        ..moveTo(origin.dx, origin.dy)
        ..lineTo(
          origin.dx + math.cos(ang - half) * len,
          origin.dy + math.sin(ang - half) * len,
        )
        ..lineTo(
          origin.dx + math.cos(ang + half) * len,
          origin.dy + math.sin(ang + half) * len,
        )
        ..close();
      final sway = 0.65 + 0.35 * math.sin(sec * 0.9 + i * 2.1);
      canvas.drawPath(
        path,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.linear(origin, origin + dir * len, [
            Color.lerp(aura, const Color(0xFFFFF4C8), 0.4)!.withValues(
              alpha: _a(rayA * sway),
            ),
            aura.withValues(alpha: 0),
          ]),
      );
    }

    // Breathing aura around Hayu.
    _glow(
      canvas,
      target,
      minDim * (0.42 + 0.26 * energy + 0.04 * beat),
      aura,
      (0.15 + 0.24 * energy + 0.10 * tail) * intro * (0.88 + 0.12 * beat),
    );
    _glow(
      canvas,
      target,
      minDim * 0.17 * (1 + 0.25 * beat + 0.5 * energy),
      const Color(0xFFFFF4C8),
      (0.08 + 0.18 * energy) * intro,
    );

    // Fireflies drifting upward and twinkling.
    final flyCol = Color.lerp(const Color(0xFFFFEBA1), aura, 0.35 + 0.45 * energy)!;
    for (final b in _flies) {
      final bx = (b.angle / (2 * math.pi));
      final by = (b.spin / (2 * math.pi));
      final x = w * (bx + 0.04 * math.sin(sec * b.speed * 0.8 + b.phase));
      final y = h * (((by - sec * 0.02 * b.speed) % 1.0 + 1.0) % 1.0);
      final tw = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(sec * 2.2 * b.speed + b.phase));
      final p = Offset(x, y);
      _glow(canvas, p, b.size * 5.5 * unit, flyCol, 0.20 * tw * intro);
      canvas.drawCircle(
        p,
        b.size * 0.8 * unit,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = Colors.white.withValues(alpha: _a(0.85 * tw * intro)),
      );
    }

    // Motes spiralling into Hayu; stronger as energy builds.
    final maxR = math.max(w, h) * 0.55;
    for (final b in _swirl) {
      final period = 3.4 + b.speed * 3.2;
      final f = (sec / period + b.phase / (2 * math.pi)) % 1.0;
      final e = Curves.easeInCubic.transform(f);
      final r0 = maxR * (0.45 + 0.55 * (b.spin / (2 * math.pi)));
      final rr = r0 * (1 - e) + 14 * unit;
      final ang = b.angle + f * 2.6;
      final pos = target + Offset(math.cos(ang) * rr, math.sin(ang) * rr * 0.7);
      final al = math.sin(f * math.pi) * (0.55 + 0.45 * energy) * intro;
      _glow(canvas, pos, b.size * 4.2 * unit, flyCol, 0.28 * al);
      canvas.drawCircle(
        pos,
        b.size * 0.75 * unit,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = Colors.white.withValues(alpha: _a(0.9 * al)),
      );
    }

    // Hayu weighs: slow heartbeat rings and swelling light.
    if (tail > 0) {
      _glow(
        canvas,
        target,
        minDim * 0.55,
        aura,
        0.30 * tail * (0.6 + 0.4 * beat),
      );
      for (var k = 0; k < 3; k++) {
        final phase = (sec * 0.9 + k / 3) % 1.0;
        final e = Curves.easeOutCubic.transform(phase);
        canvas.drawCircle(
          target,
          minDim * (0.08 + 0.50 * e),
          Paint()
            ..blendMode = BlendMode.plus
            ..style = PaintingStyle.stroke
            ..strokeWidth = (1 - phase) * 3 + 0.6
            ..color = aura.withValues(alpha: _a((1 - phase) * 0.45 * tail)),
        );
      }
    }
  }
}

// --------------------------------------------------------------- card

/// A single offering: rises as a neutral card back, flips in a burst of
/// light, hovers with orbiting stars and a sheen, then is hurled as a comet.
///
/// Before the flip every card is identical (same colour, glow, size) so
/// nothing about its faction leaks early.
class _CardComponent extends Component {
  final OfferingFlameGame scene;
  final int index;
  _CardComponent(this.scene, this.index) : super(priority: 20);

  @override
  void render(Canvas canvas) {
    final s = scene;
    final u = s.timeline.cardTime(s.progress, index);
    if (u < 0 || u >= 0.86 || s.viewport.isEmpty) return;
    final h = s.cardHeight;
    final w = h * 2 / 3;
    final size = s.viewport;
    final unit = s.unit;
    final card = s.cards[index];
    final direction = index.isEven ? 1.0 : -1.0;
    final arrival = Curves.easeOutCubic.transform(_segment(u, 0, 0.26));
    final flip = _segment(u, 0.26, 0.46);
    final thrown = _segment(u, 0.64, 0.86);
    final travel = Curves.easeInCubic.transform(thrown);
    final hover = Offset(size.width / 2, size.height * 0.64);
    final start = Offset(size.width / 2, size.height + h * 0.7);
    final control = Offset(
      size.width / 2 - direction * size.width * 0.30,
      (hover.dy + s.target.dy) / 2 - size.height * 0.12,
    );
    Offset point(double t) => t > 0
        ? _curve(hover, control, s.target, t)
        : Offset.lerp(
      start,
      hover,
      arrival,
    )!.translate(0, math.sin(u * math.pi * 7) * 3);
    double scaleAt(double t) => t > 0
        ? 1 - 0.72 * t
        : 0.7 + 0.3 * arrival + 0.12 * math.sin(flip * math.pi);

    final face = s.timeline.faceVisible(s.progress, index);
    final accent = face ? card.accent : _neutral;
    final second = face ? card.secondary : _neutralBright;
    final deep = face ? card.deep : _neutralDeep;
    final position = point(travel);
    final shrink = scaleAt(travel);
    final reveal = face ? _smooth(_segment(u, 0.36, 0.48)) : 0.0;
    final beat = 0.5 + 0.5 * math.sin(u * 38);

    // --- comet trail while thrown
    if (thrown > 0) {
      const samples = 16;
      Offset prev = position;
      for (var k = 1; k <= samples; k++) {
        final tk = Curves.easeInCubic.transform(
          (thrown - k * 0.026).clamp(0.0, 1.0).toDouble(),
        );
        final p = point(tk);
        final f = 1 - k / samples;
        final tone = Color.lerp(second, accent, k / samples)!;
        final width = h * 0.26 * f * scaleAt(tk);
        canvas.drawLine(
          prev,
          p,
          Paint()
            ..blendMode = BlendMode.plus
            ..strokeCap = StrokeCap.round
            ..strokeWidth = math.max(1.0, width)
            ..color = tone.withValues(alpha: _a(0.34 * f)),
        );
        canvas.drawLine(
          prev,
          p,
          Paint()
            ..blendMode = BlendMode.plus
            ..strokeCap = StrokeCap.round
            ..strokeWidth = math.max(0.8, width * 0.28)
            ..color = Colors.white.withValues(alpha: _a(0.5 * f)),
        );
        if (k % 2 == 0) {
          _glow(canvas, p, h * 0.30 * f * scaleAt(tk), accent, 0.20 * f);
        }
        prev = p;
      }
    }

    // --- halo and rays behind the card
    final fadeOut = 1 - _segment(u, 0.70, 0.86) * 0.4;
    _glow(canvas, position, h * 1.55 * shrink, deep, (face ? 0.20 : 0.07) * fadeOut);
    _glow(
      canvas,
      position,
      h * 0.9 * shrink * (1 + 0.06 * beat),
      accent,
      face ? 0.36 : 0.14,
    );
    if (reveal > 0.01) {
      _rays(
        canvas,
        position,
        10,
        u * 5.0 * direction,
        h * (0.95 + 0.5 * reveal) * shrink,
        0.075,
        second,
        0.30 * reveal * (1 - thrown),
      );
    }

    // --- flip burst: shock rings and radial sparks at the reveal
    if (u >= 0.34 && u < 0.64) {
      final b = _segment(u, 0.36, 0.64);
      if (u >= 0.36) {
        _glow(canvas, position, h * 1.3, second, math.pow(1 - b, 2).toDouble() * 0.55);
        for (var r = 0; r < 2; r++) {
          final pb = _segment(b, r * 0.12, 0.85 + r * 0.12);
          if (pb <= 0 || pb >= 1) continue;
          canvas.drawCircle(
            position,
            h * (0.30 + 1.0 * Curves.easeOutCubic.transform(pb)),
            Paint()
              ..blendMode = BlendMode.plus
              ..style = PaintingStyle.stroke
              ..strokeWidth = (1 - pb) * 4 + 0.8
              ..color = (r == 0 ? second : accent).withValues(
                alpha: _a((1 - pb) * 0.85),
              ),
          );
        }
        final eb = Curves.easeOutCubic.transform(b);
        for (var j = 0; j < 18; j++) {
          final ang = j / 18 * 2 * math.pi + index;
          final dir = Offset(math.cos(ang), math.sin(ang));
          final d0 = h * (0.45 + 0.75 * eb) * (0.7 + 0.3 * ((j * 7) % 5) / 4);
          canvas.drawLine(
            position + dir * d0,
            position + dir * (d0 + h * 0.10 * (1 - b)),
            Paint()
              ..blendMode = BlendMode.plus
              ..strokeCap = StrokeCap.round
              ..strokeWidth = 2.2 * (1 - b) + 0.6
              ..color = (j.isEven ? second : accent).withValues(
                alpha: _a(1 - b),
              ),
          );
        }
      }
    }

    // --- the card itself
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(travel * 3.5 * math.pi * direction);
    canvas.scale(shrink, shrink);
    canvas.scale(math.max(0.025, math.cos(flip * math.pi).abs()), 1);
    final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    final rounded = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.drawRRect(rounded, Paint()..color = const Color(0xFF18372B));
    final path = face ? card.imagePath : s.backPath;
    final image = s._art[path];
    if (image != null) {
      canvas.save();
      canvas.clipRRect(rounded);
      paintImage(
        canvas: canvas,
        rect: rect,
        image: image,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
      canvas.restore();
    } else if (face) {
      final text = TextPainter(
        text: TextSpan(
          text: card.name,
          style: TextStyle(
            color: accent,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 3,
        ellipsis: '…',
      )..layout(maxWidth: w - 16);
      text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
    } else {
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w * 0.25, height: h * 0.24),
        Paint()..color = accent.withValues(alpha: 0.6),
      );
    }

    // Light sheen sweeping across the revealed face.
    final sh = _segment(u, 0.47, 0.68);
    if (face && sh > 0 && sh < 1) {
      canvas.save();
      canvas.clipRRect(rounded);
      final cx = _lerpD(-w * 0.95, w * 0.95, Curves.easeInOut.transform(sh));
      final band = Path()
        ..moveTo(cx - w * 0.12, -h / 2)
        ..lineTo(cx + w * 0.16, -h / 2)
        ..lineTo(cx + w * 0.16 - h * 0.22, h / 2)
        ..lineTo(cx - w * 0.12 - h * 0.22, h / 2)
        ..close();
      canvas.drawPath(
        band,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = Colors.white.withValues(alpha: 0.34 * math.sin(sh * math.pi)),
      );
      canvas.restore();
    }

    // Glowing edge, brighter once the face is shown.
    if (face) {
      canvas.drawRRect(
        rounded,
        Paint()
          ..blendMode = BlendMode.plus
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
          ..color = accent.withValues(alpha: 0.55 + 0.35 * beat),
      );
    }
    canvas.drawRRect(
      rounded,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = face ? 2.0 : 1.4,
    );
    canvas.restore();

    // --- orbiting stars around the revealed card
    if (reveal > 0.02) {
      for (var i = 0; i < 9; i++) {
        final dirS = i.isEven ? 1.0 : -1.0;
        final ang = i * 2 * math.pi / 9 + u * 9 * dirS;
        final ring = 0.80 + 0.12 * (i % 3);
        final p = position +
            Offset(
              math.cos(ang) * w * ring * shrink,
              math.sin(ang) * h * 0.58 * (0.9 + 0.1 * (i % 3)) * shrink,
            );
        final tw = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(u * 46 + i * 1.7));
        _star(
          canvas,
          p,
          (3.2 + 2.6 * (i % 3)) * unit * (0.6 + 0.4 * shrink),
          i % 2 == 0 ? second : accent,
          reveal * (1 - thrown) * tw,
        );
      }
    }
  }
}

double _lerpD(double a, double b, double t) => a + (b - a) * t;

// -------------------------------------------------------------- impact

/// The moment an offering strikes Hayu.
/// Good: white-gold flash, shock rings, god rays, petals, sparks and rising
/// embers. Bad: violet flash, cracks of light, shards, smoke, falling
/// sparks, darkening vignette and a screen shake. Blocked: an icy dome.
class _ImpactComponent extends Component {
  final OfferingFlameGame scene;
  final int index;
  _ImpactComponent(this.scene, this.index) : super(priority: 30);

  OfferingFlameCard get card => scene.cards[index];

  late final math.Random _r = math.Random(
    index * 311 + (card.bad ? 29 : 7),
  );
  late final List<_Bit> _petals = (card.bad || card.blocked)
      ? const <_Bit>[]
      : _bits(_r, 46, 70, 250, 5, 11);
  late final List<_Bit> _shards = (card.bad && !card.blocked)
      ? _bits(_r, 40, 90, 300, 4, 10)
      : const <_Bit>[];
  late final List<_Bit> _smoke = (card.bad && !card.blocked)
      ? _bits(_r, 9, 30, 110, 0, 1)
      : const <_Bit>[];
  late final List<_Bit> _cracks = (card.bad && !card.blocked)
      ? _bits(_r, 11, 260, 480, 0, 1)
      : const <_Bit>[];
  late final List<_Bit> _sparks = _bits(
    _r,
    card.blocked ? 22 : 64,
    90,
    420,
    1.2,
    3.0,
  );
  late final List<_Bit> _rise = _bits(_r, card.bad ? 20 : 30, 60, 220, 1.6, 3.4);

  @override
  void render(Canvas canvas) {
    final s = scene;
    final age = s.timeline.impactAge(s.progress, index);
    if (age < 0 || age > 2.1 || s.viewport.isEmpty) return;
    final c = card;
    final unit = s.unit;
    final center = s.target;
    final blocked = c.blocked;
    final bad = c.bad && !blocked;
    final color = blocked ? _ice : c.accent;
    final second = blocked ? Colors.white : c.secondary;
    final deep = blocked ? const Color(0xFF2E9BC9) : c.deep;
    final viewRect = Offset.zero & s.viewport;
    final fade = _a(1 - age / 1.6);
    final burst = Curves.easeOutCubic.transform(_segment(age, 0, 0.9));

    // Whole-screen flash.
    final flash = math.max(0.0, 1 - age / 0.16);
    if (flash > 0) {
      canvas.drawRect(
        viewRect,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = Color.lerp(Colors.white, color, 0.3)!.withValues(
            alpha: flash * (blocked ? 0.22 : (bad ? 0.30 : 0.42)),
          ),
      );
    }

    // Core bloom.
    _glow(canvas, center, (80 + 280 * burst) * unit, color, _a(1 - age / 0.8) * 0.85);
    _glow(
      canvas,
      center,
      90 * unit * (1 + burst),
      Colors.white,
      math.max(0.0, 1 - age / 0.28) * 0.9,
    );

    // Three staggered shock rings.
    for (var r = 0; r < 3; r++) {
      final pr = _segment(age - r * 0.09, 0, 1.0);
      if (pr <= 0 || pr >= 1) continue;
      canvas.drawCircle(
        center,
        (30 + 340 * Curves.easeOutCubic.transform(pr)) * unit,
        Paint()
          ..blendMode = BlendMode.plus
          ..style = PaintingStyle.stroke
          ..strokeWidth = ((1 - pr) * (7 - r * 1.8) + 0.6) * unit.clamp(0.7, 1.4)
          ..color = (r == 0 ? second : (r == 1 ? color : deep)).withValues(
            alpha: _a((1 - pr) * 0.85),
          ),
      );
    }

    if (blocked) {
      _paintShield(canvas, center, unit, age, color);
      _paintSparks(canvas, center, unit, age, second, color, 40);
      return;
    }

    // Light that lingers on Hayu.
    _glow(canvas, center, 240 * unit, deep, fade * 0.30);

    if (!bad) {
      _rays(
        canvas,
        center,
        14,
        age * 0.6,
        (180 + 430 * burst) * unit,
        0.045,
        second,
        fade * 0.5,
      );
    } else {
      // Darkening vignette.
      final vig = _a(1 - age / 1.3);
      if (vig > 0) {
        canvas.drawRect(
          viewRect,
          Paint()
            ..shader = RadialGradient(
              radius: 0.9,
              colors: [
                Colors.transparent,
                const Color(0xFF1A0B2E).withValues(alpha: 0.55 * vig),
              ],
              stops: const [0.30, 1.0],
            ).createShader(viewRect),
        );
      }
      _paintCracks(canvas, center, unit, age, second, color);
    }

    if (c.advanced) _paintSpiral(canvas, center, unit, age, second, color);

    _paintSparks(canvas, center, unit, age, second, color, bad ? 60 : 64);

    if (!bad) {
      _paintPetals(canvas, center, unit, age, c.palette, second);
    } else {
      _paintSmoke(canvas, center, unit, age, deep);
      _paintShards(canvas, center, unit, age, second);
    }

    _paintRise(canvas, center, unit, age, second, color);
  }

  void _paintSparks(
      Canvas canvas,
      Offset center,
      double unit,
      double age,
      Color second,
      Color color,
      int maxCount,
      ) {
    final bad = card.bad && !card.blocked;
    var n = 0;
    for (final b in _sparks) {
      if (n++ >= maxCount) break;
      final life = 0.9 + 0.8 * (b.phase / (2 * math.pi));
      final al = _a(1 - age / life);
      if (al <= 0) continue;
      final d = b.speed * unit * (1 - math.exp(-3.2 * age)) / 3.2;
      final grav = (bad ? 170.0 : 70.0) * age * age * unit;
      final dir = Offset(math.cos(b.angle), math.sin(b.angle));
      final head = center + dir * d + Offset(0, grav);
      final len = (8 + 22 * al) * unit;
      canvas.drawLine(
        head,
        head - dir * len,
        Paint()
          ..blendMode = BlendMode.plus
          ..strokeCap = StrokeCap.round
          ..strokeWidth = (b.size * al + 0.5) * unit.clamp(0.7, 1.4)
          ..color = (b.tone.isEven ? second : color).withValues(alpha: al),
      );
      if (b.tone % 4 == 0) {
        _glow(canvas, head, 7 * unit, second, al * 0.5);
      }
    }
  }

  void _paintPetals(
      Canvas canvas,
      Offset center,
      double unit,
      double age,
      List<Color> palette,
      Color vein,
      ) {
    final al = _smooth(1 - (age - 0.15) / 1.8);
    if (al <= 0) return;
    final burst = Curves.easeOutCubic.transform(_segment(age, 0, 0.9));
    for (final b in _petals) {
      final d = b.speed * unit * (1 - math.exp(-2.6 * age)) / 2.6;
      final pos = center +
          Offset(
            math.cos(b.angle) * d +
                math.sin(age * 3 + b.phase) * 16 * unit * _a(age),
            math.sin(b.angle) * d * 0.8 +
                (24 * age + 34 * age * age) * unit -
                40 * unit * burst,
          );
      final sz = b.size * unit;
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(b.spin + age * (1.5 + b.phase * 0.3));
      canvas.scale(1, 0.35 + 0.65 * math.cos(age * 4 + b.phase).abs());
      final petal = Path()
        ..moveTo(0, -sz)
        ..quadraticBezierTo(sz * 0.95, -sz * 0.3, 0, sz)
        ..quadraticBezierTo(-sz * 0.95, -sz * 0.3, 0, -sz);
      final col = palette[b.tone % palette.length];
      canvas.drawPath(petal, Paint()..color = col.withValues(alpha: al));
      canvas.drawLine(
        Offset(0, -sz * 0.8),
        Offset(0, sz * 0.8),
        Paint()
          ..color = vein.withValues(alpha: al * 0.7)
          ..strokeWidth = 0.7,
      );
      canvas.restore();
      if (b.tone % 5 == 0) _glow(canvas, pos, sz * 2.4, col, al * 0.22);
    }
  }

  void _paintShards(
      Canvas canvas,
      Offset center,
      double unit,
      double age,
      Color edge,
      ) {
    final al = _smooth(1 - (age - 0.1) / 1.5);
    if (al <= 0) return;
    for (final b in _shards) {
      final d = b.speed * unit * (1 - math.exp(-3.0 * age)) / 3.0;
      final pos = center +
          Offset(math.cos(b.angle) * d, math.sin(b.angle) * d + 140 * age * age * unit);
      final sz = b.size * unit;
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(b.spin + age * 5);
      final shard = Path()
        ..moveTo(0, -sz)
        ..lineTo(sz * 0.55, 0)
        ..lineTo(0, sz * 1.5)
        ..lineTo(-sz * 0.55, 0)
        ..close();
      canvas.drawPath(
        shard,
        Paint()..color = const Color(0xFF1E0F38).withValues(alpha: al),
      );
      canvas.drawPath(
        shard,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = edge.withValues(alpha: al * 0.85),
      );
      canvas.restore();
    }
  }

  void _paintSmoke(
      Canvas canvas,
      Offset center,
      double unit,
      double age,
      Color deep,
      ) {
    final slow = Curves.easeOut.transform(_segment(age, 0, 1.4));
    for (final b in _smoke) {
      final al = _a(1 - age / 1.5) * 0.34;
      if (al <= 0) continue;
      final pos = center +
          Offset(math.cos(b.angle), math.sin(b.angle)) * b.speed * unit * slow * 1.6 +
          Offset(0, -20 * unit * slow);
      _glow(
        canvas,
        pos,
        (36 + 110 * slow) * unit * (0.7 + 0.5 * b.size),
        Color.lerp(deep, const Color(0xFF0E0618), 0.55)!,
        al,
        add: false,
      );
    }
  }

  void _paintCracks(
      Canvas canvas,
      Offset center,
      double unit,
      double age,
      Color spark,
      Color color,
      ) {
    final grow = Curves.easeOutCubic.transform(_segment(age, 0, 0.35));
    final al = _a(1 - (age - 0.4) / 1.4);
    if (al <= 0) return;
    for (final b in _cracks) {
      final len = b.speed * unit * grow;
      final dir = Offset(math.cos(b.angle), math.sin(b.angle));
      final perp = Offset(-dir.dy, dir.dx);
      final path = Path()..moveTo(center.dx, center.dy);
      const steps = 6;
      for (var i = 1; i <= steps; i++) {
        final f = i / steps;
        final jitter = math.sin(b.phase * 12.9898 + i * 78.233) * 22 * unit * f;
        final q = center + dir * (len * f) + perp * jitter;
        path.lineTo(q.dx, q.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..blendMode = BlendMode.plus
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 8 * unit
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
          ..color = color.withValues(alpha: al * 0.55),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 2.4 * unit.clamp(0.7, 1.3)
          ..color = spark.withValues(alpha: al),
      );
    }
  }

  void _paintSpiral(
      Canvas canvas,
      Offset center,
      double unit,
      double age,
      Color second,
      Color color,
      ) {
    final out = Curves.easeOutCubic.transform(_segment(age, 0, 0.8));
    final fade = _a(1 - age / 1.5);
    for (var arm = 0; arm < 3; arm++) {
      for (var j = 0; j < 14; j++) {
        final r = (16 + j * 17) * unit * out;
        final ang = arm * 2 * math.pi / 3 + j * 0.34 + age * 3.2;
        final pos = center + Offset(math.cos(ang), math.sin(ang)) * r;
        _glow(
          canvas,
          pos,
          (7 - j * 0.3) * unit,
          j.isEven ? second : color,
          fade * (1 - j / 15) * 0.9,
        );
      }
    }
  }

  void _paintRise(
      Canvas canvas,
      Offset center,
      double unit,
      double age,
      Color second,
      Color color,
      ) {
    final k = math.sin(math.pi * _a(age / 2.1));
    if (k <= 0) return;
    for (final b in _rise) {
      final pos = center +
          Offset(
            math.cos(b.angle) * b.speed * 0.9 * unit +
                math.sin(age * 2 + b.phase) * 12 * unit,
            math.sin(b.angle) * b.speed * 0.35 * unit -
                (40 + b.size * 14) * age * unit,
          );
      _glow(canvas, pos, b.size * 3.4 * unit, b.tone.isEven ? second : color, 0.30 * k);
      canvas.drawCircle(
        pos,
        b.size * 0.7 * unit,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = Colors.white.withValues(alpha: _a(0.85 * k)),
      );
    }
  }

  void _paintShield(
      Canvas canvas,
      Offset center,
      double unit,
      double age,
      Color color,
      ) {
    final fade = _a(1 - age / 1.5);
    if (fade <= 0) return;
    final r = 140 * unit * (0.9 + 0.1 * Curves.easeOut.transform(_segment(age, 0, 0.3)));
    final rect = Rect.fromCircle(center: center, radius: r);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: 0.06 * fade),
            color.withValues(alpha: 0.38 * fade),
          ],
          stops: const [0.0, 0.62, 1.0],
        ).createShader(rect),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    final hs = 22.0 * unit;
    final hp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = color.withValues(alpha: 0.32 * fade);
    for (var row = -7; row <= 7; row++) {
      for (var col = -7; col <= 7; col++) {
        final cx = center.dx + col * hs * 1.732 + (row.isOdd ? hs * 0.866 : 0);
        final cy = center.dy + row * hs * 1.5;
        if ((Offset(cx, cy) - center).distance > r + hs) continue;
        final hex = Path();
        for (var v = 0; v < 6; v++) {
          final a = math.pi / 6 + v * math.pi / 3;
          final px = cx + math.cos(a) * hs * 0.92;
          final py = cy + math.sin(a) * hs * 0.92;
          v == 0 ? hex.moveTo(px, py) : hex.lineTo(px, py);
        }
        hex.close();
        canvas.drawPath(hex, hp);
      }
    }
    canvas.restore();
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4 * unit.clamp(0.7, 1.3)
        ..color = Colors.white.withValues(alpha: 0.8 * fade),
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..blendMode = BlendMode.plus
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10 * unit
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..color = color.withValues(alpha: 0.45 * fade),
    );
    // Ricochet ripple where the attack bounced off.
    final ang = (index * 2.399) % (2 * math.pi);
    final hit = center + Offset(math.cos(ang), math.sin(ang)) * r;
    final pb = _segment(age, 0.0, 0.7);
    canvas.drawCircle(
      hit,
      (10 + 52 * Curves.easeOut.transform(pb)) * unit,
      Paint()
        ..blendMode = BlendMode.plus
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * (1 - pb) + 0.5
        ..color = Colors.white.withValues(alpha: 0.9 * (1 - pb)),
    );
    _glow(canvas, hit, 60 * unit, Colors.white, (1 - pb) * 0.7);
  }
}