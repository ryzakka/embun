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

  Color get accent => advanced
      ? (bad ? const Color(0xFFFF5869) : const Color(0xFF7DF9C3))
      : (bad ? const Color(0xFFB486F0) : const Color(0xFFFFD866));
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

  @override
  Color backgroundColor() => Colors.transparent;

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

double _segment(double value, double start, double end) =>
    ((value - start) / (end - start)).clamp(0.0, 1.0).toDouble();

Offset _curve(Offset start, Offset control, Offset end, double t) =>
    start * ((1 - t) * (1 - t)) + control * (2 * (1 - t) * t) + end * (t * t);

void _glow(
  Canvas canvas,
  Offset center,
  double radius,
  Color color,
  double alpha,
) {
  if (radius <= 0 || alpha <= 0) return;
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: alpha.clamp(0.0, 1.0)),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius)),
  );
}

class _CardComponent extends Component {
  final OfferingFlameGame scene;
  final int index;
  _CardComponent(this.scene, this.index) : super(priority: 20);

  @override
  void render(Canvas canvas) {
    final u = scene.timeline.cardTime(scene.progress, index);
    if (u < 0 || u >= 0.86 || scene.viewport.isEmpty) return;
    final h = scene.cardHeight;
    final w = h * 2 / 3;
    final size = scene.viewport;
    final card = scene.cards[index];
    final direction = index.isEven ? 1.0 : -1.0;
    final arrival = Curves.easeOutCubic.transform(_segment(u, 0, 0.26));
    final flip = _segment(u, 0.26, 0.46);
    final thrown = _segment(u, 0.64, 0.86);
    final travel = Curves.easeInCubic.transform(thrown);
    final hover = Offset(size.width / 2, size.height * 0.64);
    final start = Offset(size.width / 2, size.height + h * 0.7);
    final control = Offset(
      size.width / 2 - direction * size.width * 0.30,
      (hover.dy + scene.target.dy) / 2 - size.height * 0.12,
    );
    Offset point(double t) => t > 0
        ? _curve(hover, control, scene.target, t)
        : Offset.lerp(
            start,
            hover,
            arrival,
          )!.translate(0, math.sin(u * math.pi * 7) * 3);

    final face = scene.timeline.faceVisible(scene.progress, index);
    // Same neutral back, dimensions, glow and border for every faction before
    // the flip. No names, rarity or alignment are rendered on a hidden card.
    final accent = face ? card.accent : const Color(0xFFE0CF9F);
    final position = point(travel);
    if (thrown > 0) {
      for (var ghost = 5; ghost >= 1; ghost--) {
        final earlier = Curves.easeInCubic.transform(
          (thrown - ghost * 0.045).clamp(0.0, 1.0),
        );
        _glow(
          canvas,
          point(earlier),
          h * (0.25 - earlier * 0.13),
          accent,
          (1 - ghost / 6) * 0.23,
        );
      }
    }
    _glow(canvas, position, h * 0.85, accent, face ? 0.28 : 0.12);
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(travel * 3.5 * math.pi * direction);
    final shrink = travel > 0 ? 1 - 0.72 * travel : 0.7 + 0.3 * arrival;
    canvas.scale(shrink, shrink);
    canvas.scale(math.max(0.025, math.cos(flip * math.pi).abs()), 1);
    final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    final rounded = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.drawRRect(rounded, Paint()..color = const Color(0xFF18372B));
    final path = face ? card.imagePath : scene.backPath;
    final image = scene._art[path];
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
    canvas.drawRRect(
      rounded,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.restore();
  }
}

class _AmbientComponent extends Component {
  final OfferingFlameGame scene;
  _AmbientComponent(this.scene) : super(priority: 0);

  @override
  void render(Canvas canvas) {
    if (scene.viewport.isEmpty) return;
    final seconds = scene.progress * scene.timeline.totalMs / 1000;
    final width = scene.viewport.width;
    final height = scene.viewport.height;
    _glow(
      canvas,
      scene.target,
      math.min(width, height) * 0.48,
      const Color(0xFFEAC975),
      0.13,
    );
    for (var i = 0; i < 22; i++) {
      final x = width * (0.5 + 0.44 * math.sin(i * 2.399 + seconds * 0.12));
      final y = height * (0.2 + ((i * 0.137 + seconds * 0.018) % 0.7));
      final light = 0.18 + 0.22 * (0.5 + 0.5 * math.sin(seconds * 2 + i));
      canvas.drawCircle(
        Offset(x, y),
        1.1 + i % 3 * 0.45,
        Paint()..color = const Color(0xFFFFEBA1).withValues(alpha: light),
      );
    }
  }
}

class _ImpactComponent extends Component {
  final OfferingFlameGame scene;
  final int index;
  _ImpactComponent(this.scene, this.index) : super(priority: 10);

  @override
  void render(Canvas canvas) {
    final age = scene.timeline.impactAge(scene.progress, index);
    if (age < 0 || age > 1.5 || scene.viewport.isEmpty) return;
    final card = scene.cards[index];
    final t = (age / 1.5).clamp(0.0, 1.0).toDouble();
    final color = card.blocked ? const Color(0xFFBDF2FF) : card.accent;
    final center = scene.target;
    final scale = math.min(scene.viewport.width, scene.viewport.height) / 600;
    final flash = math.max(0.0, 1 - age / 0.22);
    _glow(canvas, center, (70 + 150 * t) * scale, color, flash * 0.65);
    canvas.drawCircle(
      center,
      (20 + 180 * Curves.easeOut.transform(t)) * scale,
      Paint()
        ..color = color.withValues(alpha: (1 - t) * 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (1 - t) * 3 + 0.5,
    );
    if (card.blocked) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 65 * scale),
        math.pi,
        math.pi,
        false,
        Paint()
          ..color = color.withValues(alpha: 1 - t)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * (1 - t),
      );
      return;
    }
    final random = math.Random(index * 311 + (card.bad ? 29 : 7));
    final count = card.bad ? 34 : 27;
    for (var i = 0; i < count; i++) {
      final angle = random.nextDouble() * math.pi * 2;
      final speed = (45 + random.nextDouble() * 170) * scale;
      final radius = (2 + random.nextDouble() * 4) * scale;
      final spin = random.nextDouble() * math.pi;
      final offset = Offset(
        math.cos(angle) * speed * age,
        math.sin(angle) * speed * age +
            (card.bad ? 55 : 22) * age * age * scale,
      );
      final opacity = (1 - t) * (1 - t);
      canvas.save();
      canvas.translate(center.dx + offset.dx, center.dy + offset.dy);
      canvas.rotate(spin + age * (card.bad ? 4 : 2));
      final paint = Paint()..color = color.withValues(alpha: opacity);
      if (card.bad) {
        final shard = Path()
          ..moveTo(-radius, -radius)
          ..lineTo(radius, 0)
          ..lineTo(-radius * 0.3, radius * 1.8)
          ..close();
        canvas.drawPath(shard, paint);
      } else {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: radius * 2.4,
            height: radius,
          ),
          paint,
        );
        canvas.drawLine(
          Offset(-radius, 0),
          Offset(radius, 0),
          Paint()
            ..color = const Color(0xFFFFF6CD).withValues(alpha: opacity)
            ..strokeWidth = 0.65,
        );
      }
      canvas.restore();
    }
  }
}
