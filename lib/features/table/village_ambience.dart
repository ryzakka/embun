import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import '../common/scene_flow.dart';
import '../common/shader_fx.dart';

/// Efek sinematik untuk pemilih tempat dan interior tempat di
/// village_visit_view.dart. Semuanya Flutter murni (CustomPaint), tanpa
/// berkas .frag baru, sehingga tidak perlu menyentuh pubspec.yaml.
///
///  * [PlaceBackdrop]  latar Ken Burns, geser mengikuti arah geser pemain,
///                     "mendorong masuk" saat Masuk ditekan, mengendap saat tiba.
///  * [PlaceAmbience]  berkas cahaya + partikel khas tiap tempat + vinyet.
///  * [IrisReveal]     lubang cahaya membuka dari tinta [kSceneInk].
///  * [PlaceTitleCard] kartu judul tempat yang singkat muncul lalu lenyap.
///  * [SweepGlint]     kilau menyapu saat tujuan berganti.
///  * [PulsingGlow]    cahaya berdenyut untuk item terpilih.
///  * [GildedDivider]  garis emas berujung belah ketupat.
///
/// Efek ambience mengikuti saklar [ShaderFx.enabled] dan pengaturan
/// "kurangi animasi" sistem.

enum AmbienceKind { dust, mist, embers, herbs, lanterns }

AmbienceKind ambienceFor(String placeId) => switch (placeId) {
  'riset' => AmbienceKind.dust,
  'sumur' => AmbienceKind.mist,
  'bengkel' => AmbienceKind.embers,
  'pondok' => AmbienceKind.herbs,
  _ => AmbienceKind.lanterns,
};

// ---------------------------------------------------------------------------
// Latar
// ---------------------------------------------------------------------------

class PlaceBackdrop extends StatelessWidget {
  const PlaceBackdrop({
    super.key,
    required this.path,
    this.height,
    this.inside = false,
    this.pushIn = false,
    this.dir = 1,
    this.reduced = false,
  });
  final String? path;

  /// Tinggi bidang gambar; null = seluruh ruang yang tersedia.
  final double? height;

  /// true = interior tempat (mengendap lebih dalam saat tiba).
  final bool inside;

  /// true = kamera mendorong masuk dan menggelap (menunggu server).
  final bool pushIn;

  /// +1 / -1: arah geser terakhir pemain.
  final int dir;
  final bool reduced;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.0, end: pushIn ? 1.0 : 0.0),
    duration: pushIn && !reduced
        ? const Duration(milliseconds: 700)
        : Duration.zero,
    curve: Curves.easeInCubic,
    builder: (context, v, child) => Stack(
      fit: StackFit.expand,
      children: [
        Transform.scale(scale: 1 + .24 * v, child: child),
        if (v > .001)
          IgnorePointer(
            child: ColoredBox(color: kSceneInk.withValues(alpha: .75 * v)),
          ),
      ],
    ),
    child: LayoutBuilder(
      builder: (context, c) => ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: double.infinity,
            height: height ?? c.maxHeight,
            child: AnimatedSwitcher(
              duration: reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 700),
              layoutBuilder: (current, previous) => Stack(
                fit: StackFit.expand,
                children: [...previous, ?current],
              ),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(
                    begin: Offset(.025 * dir, 0),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: _KenBurns(
                key: ValueKey('$path-$inside'),
                path: path,
                inside: inside,
                dir: dir,
                reduced: reduced,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _KenBurns extends StatefulWidget {
  const _KenBurns({
    super.key,
    required this.path,
    required this.inside,
    required this.dir,
    required this.reduced,
  });
  final String? path;
  final bool inside, reduced;
  final int dir;
  @override
  State<_KenBurns> createState() => _KenBurnsState();
}

class _KenBurnsState extends State<_KenBurns> with TickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 28),
  );
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.reduced) {
      _settle.value = 1;
    } else {
      _drift.forward();
      _settle.forward();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    _settle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_drift, _settle]),
    builder: (context, child) {
      final s = Curves.easeOutCubic.transform(_settle.value);
      final arrive = (1 - s) * (widget.inside ? .16 : .04);
      // kBentangZoom: bingkai emas yang tertanam di gambar harus tetap
      // keluar dari layar, jadi skala tidak pernah di bawahnya.
      final scale = kBentangZoom + .06 * _drift.value + arrive;
      final ax = widget.dir * (-.35 + .7 * _drift.value);
      final ay = .15 - .3 * _drift.value;
      return Transform.scale(
        scale: scale,
        alignment: Alignment(ax, ay),
        child: child,
      );
    },
    child: GameImage(path: widget.path, cacheWidth: 1280),
  );
}

// ---------------------------------------------------------------------------
// Ambience: berkas cahaya, partikel, vinyet
// ---------------------------------------------------------------------------

class PlaceAmbience extends StatefulWidget {
  const PlaceAmbience({
    super.key,
    required this.kind,
    required this.tint,
    this.dark = false,
    this.inside = false,
  });
  final AmbienceKind kind;
  final Color tint;
  final bool dark, inside;
  @override
  State<PlaceAmbience> createState() => _PlaceAmbienceState();
}

class _PlaceAmbienceState extends State<PlaceAmbience>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  );
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: ShaderFx.enabled,
    builder: (context, on, _) {
      if (!on || _reduced) return const SizedBox.shrink();
      return RepaintBoundary(
        child: IgnorePointer(
          child: SizedBox.expand(
            child: CustomPaint(
              painter: _AmbiencePainter(
                anim: _c,
                kind: widget.kind,
                tint: widget.tint,
                dark: widget.dark,
                inside: widget.inside,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _AmbiencePainter extends CustomPainter {
  _AmbiencePainter({
    required this.anim,
    required this.kind,
    required this.tint,
    required this.dark,
    required this.inside,
  }) : super(repaint: anim);

  final Animation<double> anim;
  final AmbienceKind kind;
  final Color tint;
  final bool dark, inside;

  static const _tau = math.pi * 2;

  /// Semua gerak memakai kelipatan BULAT dari v (0..1 per 60 detik) supaya
  /// putaran berulang tanpa lompatan.
  double get v => anim.value;
  double _wave(double cycles, double phase) =>
      math.sin(_tau * (v * cycles + phase));
  static double _fr(double x) => x - x.floorToDouble();
  static double _h(int i, int salt) =>
      _fr(math.sin(i * 127.1 + salt * 311.7) * 43758.5453);

  Color get _soft => Color.lerp(tint, Colors.white, dark ? .3 : .45)!;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _shafts(canvas, size);
    switch (kind) {
      case AmbienceKind.dust:
        _dust(canvas, size, 34, _soft);
      case AmbienceKind.mist:
        _mist(canvas, size);
        _dust(canvas, size, 16, _soft);
      case AmbienceKind.embers:
        _heat(canvas, size);
        _embers(canvas, size);
      case AmbienceKind.herbs:
        _fireflies(canvas, size);
      case AmbienceKind.lanterns:
        _bokeh(canvas, size);
        _dust(canvas, size, 22, _soft);
    }
    _vignette(canvas, size);
  }

  void _shafts(Canvas c, Size s) {
    for (var i = 0; i < 3; i++) {
      final base = s.width * (.12 + .32 * i + .06 * _h(i, 1));
      final sway = _wave(1, i * .33) * s.width * .02;
      final breathe = .5 + .5 * _wave(2, i * .27);
      final w = s.width * (.10 + .05 * _h(i, 2));
      final a = (inside ? .10 : .07) * (.55 + .45 * breathe);
      c.save();
      c.translate(base + sway, -s.height * .15);
      c.rotate(-.38);
      c.drawRect(
        Rect.fromLTWH(-w / 2, 0, w, s.height * 1.7),
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.linear(
            Offset(-w / 2, 0),
            Offset(w / 2, 0),
            [
              tint.withValues(alpha: 0),
              tint.withValues(alpha: a),
              tint.withValues(alpha: 0),
            ],
            const [0, .5, 1],
          ),
      );
      c.restore();
    }
  }

  void _dust(Canvas c, Size s, int n, Color color) {
    final p = Paint();
    for (var i = 0; i < n; i++) {
      final cyc = 1 + i % 3;
      final y = 1 - _fr(_h(i, 2) + v * cyc);
      final x = _h(i, 1) + .03 * _wave(2.0 + i % 3, _h(i, 4));
      final r = .7 + 2.0 * _h(i, 3) * _h(i, 3);
      final fade = math.sin(math.pi * y);
      final tw = .35 + .65 * (.5 + .5 * _wave(6.0 + i % 5, _h(i, 5)));
      final a = (fade * tw * (inside ? .8 : .62)).clamp(0.0, 1.0);
      final o = Offset(x * s.width, y * s.height);
      p.color = color.withValues(alpha: a * .9);
      c.drawCircle(o, r, p);
      p.color = color.withValues(alpha: a * .16);
      c.drawCircle(o, r * 4, p);
    }
  }

  void _mist(Canvas c, Size s) {
    final col = dark ? tint : Color.lerp(tint, Colors.white, .4)!;
    for (var i = 0; i < 5; i++) {
      final cx = (-.3 + 1.6 * _fr(_h(i, 1) + v)) * s.width;
      final cy =
          s.height * (.5 + .4 * _h(i, 2)) + _wave(2, _h(i, 6)) * s.height * .012;
      final rx = s.width * (.34 + .2 * _h(i, 3));
      c.save();
      c.translate(cx, cy);
      c.scale(1, .24);
      c.drawCircle(
        Offset.zero,
        rx,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.radial(Offset.zero, rx, [
            col.withValues(alpha: inside ? .13 : .10),
            col.withValues(alpha: 0),
          ]),
      );
      c.restore();
    }
  }

  void _heat(Canvas c, Size s) {
    final fl = .75 + .25 * math.sin(_tau * (v * 37 + .35 * math.sin(_tau * v * 11)));
    c.drawRect(
      Rect.fromLTWH(0, s.height * .45, s.width, s.height * .55),
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.linear(
          Offset(0, s.height),
          Offset(0, s.height * .45),
          [tint.withValues(alpha: .26 * fl), tint.withValues(alpha: 0)],
        ),
    );
  }

  void _embers(Canvas c, Size s) {
    final p = Paint()..blendMode = BlendMode.plus;
    for (var i = 0; i < 30; i++) {
      final cyc = 2 + i % 3;
      final prog = _fr(_h(i, 2) + v * cyc);
      final y = 1.02 - prog * 1.1;
      final x = _h(i, 1) + .04 * (.4 + prog) * _wave(2.0 + i % 3, _h(i, 4));
      final r = .8 + 1.9 * _h(i, 3);
      final fade = (1 - prog) * math.min(1.0, prog * 8);
      final fl = .6 + .4 * _wave(11.0 + i % 5, _h(i, 5));
      final a = (fade * fl * .9).clamp(0.0, 1.0);
      final col = i.isEven ? tint : _soft;
      final o = Offset(x * s.width, y * s.height);
      p.color = col.withValues(alpha: a);
      c.drawCircle(o, r, p);
      p.color = col.withValues(alpha: a * .2);
      c.drawCircle(o, r * 4.5, p);
    }
  }

  void _fireflies(Canvas c, Size s) {
    final breath = .5 + .5 * _wave(2, 0);
    c.drawCircle(
      Offset(s.width * .3, s.height * .6),
      s.width * .5,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(
          Offset(s.width * .3, s.height * .6),
          s.width * .5,
          [
            tint.withValues(alpha: .05 + .05 * breath),
            tint.withValues(alpha: 0),
          ],
        ),
    );
    final p = Paint()..blendMode = BlendMode.plus;
    for (var i = 0; i < 22; i++) {
      final x = _h(i, 1) + .05 * _wave(1.0 + i % 3, _h(i, 4));
      final y = .25 + .7 * _h(i, 2) + .035 * _wave(2.0 + i % 2, _h(i, 6));
      final pulse = math
          .pow(.5 + .5 * _wave(3.0 + i % 4, _h(i, 5)), 3)
          .toDouble();
      final r = 1.4 + 1.8 * _h(i, 3);
      final o = Offset(x * s.width, y * s.height);
      p.color = _soft.withValues(alpha: .25 + .75 * pulse);
      c.drawCircle(o, r, p);
      p.color = tint.withValues(alpha: .22 * pulse);
      c.drawCircle(o, r * 5, p);
    }
  }

  void _bokeh(Canvas c, Size s) {
    final fill = Paint()..blendMode = BlendMode.plus;
    final ring = Paint()
      ..blendMode = BlendMode.plus
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final col = Color.lerp(tint, Colors.white, .2)!;
    for (var i = 0; i < 10; i++) {
      final o = Offset(
        _h(i, 1) * s.width,
        (_h(i, 2) + .04 * _wave(1.0 + i % 2, _h(i, 4))) * s.height,
      );
      final r = 16 + 34 * _h(i, 3);
      final a = .035 + .04 * (.5 + .5 * _wave(2.0 + i % 3, _h(i, 5)));
      fill.color = col.withValues(alpha: a);
      ring.color = col.withValues(alpha: a * 1.6);
      c.drawCircle(o, r, fill);
      c.drawCircle(o, r, ring);
    }
  }

  void _vignette(Canvas c, Size s) {
    final breathe = .5 + .5 * _wave(2, 0);
    final a = (inside ? .52 : .40) + .06 * breathe;
    final edge = dark ? const Color(0xFF0B0617) : Colors.black;
    final r = math.sqrt(s.width * s.width + s.height * s.height) / 2;
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = ui.Gradient.radial(
          s.center(Offset.zero),
          r,
          [edge.withValues(alpha: 0), edge.withValues(alpha: a)],
          const [.5, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_AmbiencePainter old) =>
      old.kind != kind ||
          old.tint != tint ||
          old.dark != dark ||
          old.inside != inside;
}

// ---------------------------------------------------------------------------
// Masuk: lubang cahaya dari tinta
// ---------------------------------------------------------------------------

class IrisReveal extends StatelessWidget {
  const IrisReveal({
    super.key,
    required this.accent,
    this.reduced = false,
    this.duration = const Duration(milliseconds: 1500),
    this.center = Alignment.center,
  });
  final Color accent;
  final bool reduced;
  final Duration duration;
  final Alignment center;

  @override
  Widget build(BuildContext context) {
    if (reduced) return const SizedBox.shrink();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: const Interval(.1, 1.0, curve: Curves.easeInOutCubic),
      builder: (context, t, _) => t >= .999
          ? const SizedBox.shrink()
          : IgnorePointer(
        child: SizedBox.expand(
          child: CustomPaint(painter: _IrisPainter(t, accent, center)),
        ),
      ),
    );
  }
}

class _IrisPainter extends CustomPainter {
  const _IrisPainter(this.t, this.accent, this.center);
  final double t;
  final Color accent;
  final Alignment center;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(
      size.width * (center.x + 1) / 2,
      size.height * (center.y + 1) / 2,
    );
    final maxR = [
      (c - Offset.zero).distance,
      (c - Offset(size.width, 0)).distance,
      (c - Offset(0, size.height)).distance,
      (c - Offset(size.width, size.height)).distance,
    ].reduce(math.max);
    const f = .35;
    final aU = t * (1 + f) - f;
    final a = aU.clamp(0.0, 1.0).toDouble();
    final b = (aU + f).clamp(0.0, 1.0).toDouble();
    final m = (a + b) / 2;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          maxR,
          [
            kSceneInk.withValues(alpha: 0),
            kSceneInk.withValues(alpha: 0),
            accent.withValues(alpha: .28),
            kSceneInk,
            kSceneInk,
          ],
          [0, a, m, b, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_IrisPainter old) => old.t != t || old.accent != accent;
}

// ---------------------------------------------------------------------------
// Kartu judul tempat
// ---------------------------------------------------------------------------

class PlaceTitleCard extends StatelessWidget {
  const PlaceTitleCard({
    super.key,
    required this.kicker,
    required this.title,
    required this.accent,
    this.reduced = false,
  });
  final String kicker, title;
  final Color accent;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    if (reduced) return const SizedBox.shrink();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 2800),
      builder: (context, v, _) {
        if (v >= .999) return const SizedBox.shrink();
        final inn = fadeMs(v * 1000, 150, 420);
        final out = 1 - fadeMs(v * 1000, 720, 950);
        final a = (inn * out).clamp(0.0, 1.0).toDouble();
        final e = Curves.easeOutCubic.transform(inn);
        return IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: .75,
                    center: const Alignment(0, -.3),
                    colors: [
                      Colors.black.withValues(alpha: .42 * a),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Align(
                alignment: const Alignment(0, -.3),
                child: Opacity(
                  opacity: a,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          kicker,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4 + 6 * (1 - e),
                            color: accent,
                            shadows: _titleShadow,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                              letterSpacing: .5 + 12 * (1 - e),
                              color: EmbunColors.cream,
                              shadows: _titleShadow,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GildedDivider(color: accent, width: 220, centered: true),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

const _titleShadow = [
  Shadow(color: Color(0xE6000000), blurRadius: 18, offset: Offset(0, 2)),
];

// ---------------------------------------------------------------------------
// Kilau sapuan saat tujuan berganti
// ---------------------------------------------------------------------------

class SweepGlint extends StatelessWidget {
  const SweepGlint({super.key, required this.tint, this.dir = 1});
  final Color tint;
  final int dir;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeInOutCubic,
      builder: (context, v, _) => v >= .999
          ? const SizedBox.shrink()
          : IgnorePointer(
        child: SizedBox.expand(
          child: CustomPaint(painter: _GlintPainter(v, tint, dir)),
        ),
      ),
    );
  }
}

class _GlintPainter extends CustomPainter {
  const _GlintPainter(this.v, this.tint, this.dir);
  final double v;
  final Color tint;
  final int dir;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final bw = w * .22, skew = h * .35;
    final p = dir >= 0 ? v : 1 - v;
    final x = -bw * 1.5 + (w + bw * 3) * p;
    final a = math.sin(math.pi * v) * .2;
    final col = Color.lerp(tint, Colors.white, .5)!;
    final path = Path()
      ..moveTo(x, 0)
      ..lineTo(x + bw, 0)
      ..lineTo(x + bw - skew, h)
      ..lineTo(x - skew, h)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.linear(
          Offset(x, 0),
          Offset(x + bw, 0),
          [
            col.withValues(alpha: 0),
            col.withValues(alpha: a),
            col.withValues(alpha: 0),
          ],
          const [0, .5, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_GlintPainter old) => old.v != v || old.tint != tint;
}

// ---------------------------------------------------------------------------
// Cahaya berdenyut untuk item terpilih
// ---------------------------------------------------------------------------

class PulsingGlow extends StatefulWidget {
  const PulsingGlow({
    super.key,
    required this.child,
    required this.color,
    this.active = true,
    this.radius = 12,
    this.blur = 18,
  });
  final Widget child;
  final Color color;
  final bool active;
  final double radius, blur;
  @override
  State<PulsingGlow> createState() => _PulsingGlowState();
}

class _PulsingGlowState extends State<PulsingGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  bool _reduced = false;

  void _sync() {
    if (widget.active && !_reduced) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(PulsingGlow old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) {
      final t = Curves.easeInOut.transform(_reduced ? .5 : _c.value);
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: widget.active
              ? [
            BoxShadow(
              color: widget.color.withValues(alpha: .18 + .30 * t),
              blurRadius: widget.blur * (.8 + .4 * t),
              spreadRadius: 1,
            ),
          ]
              : null,
        ),
        child: child,
      );
    },
    child: widget.child,
  );
}

// ---------------------------------------------------------------------------
// Garis emas berhias
// ---------------------------------------------------------------------------

class GildedDivider extends StatelessWidget {
  const GildedDivider({
    super.key,
    required this.color,
    this.width = 180,
    this.centered = false,
  });
  final Color color;
  final double width;

  /// true = belah ketupat di tengah, garis ke dua arah; false = di kiri.
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduced ? 1.0 : 0.0, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: width,
        height: 10,
        child: CustomPaint(painter: _DividerPainter(color, v, centered)),
      ),
    );
  }
}

class _DividerPainter extends CustomPainter {
  const _DividerPainter(this.color, this.v, this.centered);
  final Color color;
  final double v;
  final bool centered;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final cx = centered ? size.width / 2 : 5.0;
    const gap = 9.0;
    Paint line(Offset from, Offset to) => Paint()
      ..strokeWidth = 1.2
      ..shader = ui.Gradient.linear(from, to, [
        color.withValues(alpha: .9),
        color.withValues(alpha: 0),
      ]);
    final reach = centered ? size.width / 2 : size.width - cx;
    final end = reach * v;
    if (end > gap) {
      final r0 = Offset(cx + gap, cy), r1 = Offset(cx + end, cy);
      canvas.drawLine(r0, r1, line(r0, r1));
      if (centered) {
        final l0 = Offset(cx - gap, cy), l1 = Offset(cx - end, cy);
        canvas.drawLine(l0, l1, line(l0, l1));
      }
    }
    canvas.drawPath(
      Path()
        ..moveTo(cx, cy - 4)
        ..lineTo(cx + 4, cy)
        ..lineTo(cx, cy + 4)
        ..lineTo(cx - 4, cy)
        ..close(),
      Paint()..color = color.withValues(alpha: v.clamp(0.0, 1.0).toDouble()),
    );
  }

  @override
  bool shouldRepaint(_DividerPainter old) =>
      old.v != v || old.color != color || old.centered != centered;
}