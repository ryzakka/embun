import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ornate.dart';
import 'sfx.dart';
import 'shader_fx.dart';

/// Efek "momen" layar penuh yang sekali putar, lalu hilang sendiri.
///
///  * [MomentFx.fusion]     dua kartu tersedot ke satu titik, hantaman cahaya,
///                          kartu hasil lahir dengan aura dan kilau.
///  * [MomentFx.wellBless]  tetes jatuh ke sumur, riak berlapis, kolom cahaya,
///                          embun beterbangan.
///  * [MomentFx.wellTaint]  tinta hitam menyebar, sulur dan kabut ungu, bulir
///                          hitam naik. Kebalikan dari wellBless.
///
/// Semuanya Flutter murni (CustomPaint di atas OverlayEntry), tanpa berkas
/// .frag baru dan tanpa dependensi baru. Lapisannya tidak menahan sentuhan
/// dan menghapus dirinya sendiri, sama seperti showCardFlight di economy_fx.
///
/// Mode hemat: bila [ShaderFx.enabled] mati atau sistem meminta animasi
/// dikurangi, hanya satu kilatan dan satu cincin (450 ms) yang diputar.
/// Haptic dan suara tetap berjalan.
class MomentFx {
  MomentFx._();

  /// Suara bisa diganti dari main() bila nanti ada aset baru, misalnya:
  ///   MomentFx.wellBlessSound = const Snd('air.mp3', .8);
  static Snd fusionCharge = Snd.fairyGrow;
  static Snd fusionImpact = Snd.slashCahaya;
  static Snd wellBlessSound = Snd.fairyGrow;
  static Snd wellTaintSound = Snd.pagarPenjara;

  /// Gabung kartu. Tiap `*Card` menerima lebar yang dipakai dan mengembalikan
  /// widget kartunya (biasanya CardTile). [dark] memakai palet ungu.
  static void fusion(
      BuildContext context, {
        required Widget Function(double width) advCard,
        required Widget Function(double width) poinCard,
        required Widget Function(double width) resultCard,
        String? label,
        bool dark = false,
      }) => _show(
    context,
    _Spec(
      kind: _Kind.fusion,
      dark: dark,
      label: label,
      advCard: advCard,
      poinCard: poinCard,
      resultCard: resultCard,
    ),
  );

  /// Merawat sumur. [origin] = titik jatuh tetes (koordinat layar global);
  /// null = tengah layar. [label] melayang naik, mis. "+0,15 / hari".
  static void wellBless(
      BuildContext context, {
        Offset? origin,
        String? label,
      }) => _show(
    context,
    _Spec(kind: _Kind.wellBless, origin: origin, label: label),
  );

  /// Mencemari sumur (sisi Si Terbisik).
  static void wellTaint(
      BuildContext context, {
        Offset? origin,
        String? label,
      }) => _show(
    context,
    _Spec(kind: _Kind.wellTaint, dark: true, origin: origin, label: label),
  );

  static void _show(BuildContext context, _Spec spec) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final lite =
        !ShaderFx.enabled.value || MediaQuery.disableAnimationsOf(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: Material(
          type: MaterialType.transparency,
          child: _MomentOverlay(
            spec: spec,
            lite: lite,
            onDone: () {
              if (entry.mounted) entry.remove();
            },
          ),
        ),
      ),
    );
    overlay.insert(entry);
  }
}

// ---------------------------------------------------------------------------
// Pembantu
// ---------------------------------------------------------------------------

double _seg(double v, double a, double b) =>
    ((v - a) / (b - a)).clamp(0.0, 1.0).toDouble();

double _sm(double x) => x * x * (3 - 2 * x);

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Acak deterministik 0..1, supaya gambar tak bergetar antarframe.
double _h(int i, int k) {
  final v = math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
  return v - v.floorToDouble();
}

void _star(Canvas canvas, Offset c, double r, Paint p) {
  final path = Path();
  for (var i = 0; i < 8; i++) {
    final rr = i.isEven ? r : r * 0.32;
    final a = i * math.pi / 4 - math.pi / 2;
    final pt = Offset(c.dx + math.cos(a) * rr, c.dy + math.sin(a) * rr);
    i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
  }
  path.close();
  canvas.drawPath(path, p);
}

Path _tear(Offset c, double s) => Path()
  ..addOval(Rect.fromCircle(center: c, radius: s))
  ..moveTo(c.dx - s * 0.85, c.dy - s * 0.45)
  ..lineTo(c.dx, c.dy - s * 2.7)
  ..lineTo(c.dx + s * 0.85, c.dy - s * 0.45)
  ..close();

class _Pal {
  final Color core, ringA, ringB, flash, sparkA, sparkB, auraA, auraB;
  final double dim;
  const _Pal({
    required this.core,
    required this.ringA,
    required this.ringB,
    required this.flash,
    required this.sparkA,
    required this.sparkB,
    required this.auraA,
    required this.auraB,
    required this.dim,
  });

  // Sama dengan palet CardBurst supaya gayanya serumpun.
  static const light = _Pal(
    core: Color(0xFFFFD866),
    ringA: Color(0xFFFFE08A),
    ringB: Color(0xFF9DF0B8),
    flash: Color(0xFFFFF6D6),
    sparkA: Color(0xFFFFE08A),
    sparkB: Color(0xFFBFF5D0),
    auraA: Color(0xFFFFE9A0),
    auraB: Color(0xFF7FE0A0),
    dim: .46,
  );
  static const dark = _Pal(
    core: Color(0xFFB07CE8),
    ringA: Color(0xFFB07CE8),
    ringB: Color(0xFF6A3FA0),
    flash: Color(0xFFE6D6FF),
    sparkA: Color(0xFFD9B8FF),
    sparkB: Color(0xFF8A5CC0),
    auraA: Color(0xFFD9B8FF),
    auraB: Color(0xFF5A2E8C),
    dim: .6,
  );
}

enum _Kind { fusion, wellBless, wellTaint }

class _Spec {
  final _Kind kind;
  final bool dark;
  final String? label;
  final Offset? origin;
  final Widget Function(double)? advCard, poinCard, resultCard;
  final int seed = math.Random().nextInt(1000);
  _Spec({
    required this.kind,
    this.dark = false,
    this.label,
    this.origin,
    this.advCard,
    this.poinCard,
    this.resultCard,
  });

  double get totalMs => kind == _Kind.fusion ? _fTotal : _wTotal;
}

// Garis waktu (ms).
const _fTotal = 2800.0, _fPull0 = 600.0, _fImpact = 1250.0, _fOut = 2350.0;
const _wTotal = 2600.0, _wOut = 2150.0;

// ---------------------------------------------------------------------------
// Lapisan
// ---------------------------------------------------------------------------

class _MomentOverlay extends StatefulWidget {
  final _Spec spec;
  final bool lite;
  final VoidCallback onDone;
  const _MomentOverlay({
    required this.spec,
    required this.lite,
    required this.onDone,
  });

  @override
  State<_MomentOverlay> createState() => _MomentOverlayState();
}

class _MomentOverlayState extends State<_MomentOverlay>
    with SingleTickerProviderStateMixin {
  late final double _total = widget.lite ? 450 : widget.spec.totalMs;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _total.round()),
  );
  final Set<int> _fired = {};
  Offset _shift = Offset.zero;

  @override
  void initState() {
    super.initState();
    _c.addListener(_tick);
    switch (widget.spec.kind) {
      case _Kind.fusion:
        Sfx.I.play(
          MomentFx.fusionCharge,
          tag: 'fx-fusion',
          replace: true,
          volume: .9,
        );
      case _Kind.wellBless:
        Sfx.I.play(MomentFx.wellBlessSound, tag: 'fx-well', replace: true);
      case _Kind.wellTaint:
        Sfx.I.play(MomentFx.wellTaintSound, tag: 'fx-well', replace: true);
    }
    _c.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
    // Overlay root bisa bergeser dari (0,0); koreksi sekali setelah frame pertama.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ro = context.findRenderObject();
      if (ro is RenderBox && ro.attached) {
        setState(() => _shift = ro.localToGlobal(Offset.zero));
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _once(double ms, int id, double at, VoidCallback f) {
    if (ms >= at && _fired.add(id)) f();
  }

  void _tick() {
    final ms = _c.value * _total;
    if (widget.lite) {
      _once(ms, 0, 0, HapticFeedback.lightImpact);
      _once(ms, 1, 150, HapticFeedback.mediumImpact);
      return;
    }
    switch (widget.spec.kind) {
      case _Kind.fusion:
        _once(ms, 0, 0, HapticFeedback.lightImpact);
        _once(ms, 1, _fPull0, HapticFeedback.mediumImpact);
        _once(ms, 2, _fImpact, () {
          HapticFeedback.heavyImpact();
          Sfx.I.play(
            MomentFx.fusionImpact,
            tag: 'fx-fusion-hit',
            replace: true,
            volume: .9,
          );
        });
        _once(ms, 3, _fImpact + 110, HapticFeedback.lightImpact);
      case _Kind.wellBless:
        _once(ms, 0, 460, HapticFeedback.selectionClick);
        _once(ms, 1, 660, HapticFeedback.lightImpact);
        _once(ms, 2, 860, HapticFeedback.lightImpact);
      case _Kind.wellTaint:
        _once(ms, 0, 460, HapticFeedback.heavyImpact);
        _once(ms, 1, 570, HapticFeedback.mediumImpact);
        _once(ms, 2, 860, HapticFeedback.lightImpact);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      return AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final ms = _c.value * _total;
          if (widget.lite) return _lite(w, h);
          return switch (widget.spec.kind) {
            _Kind.fusion => _fusion(w, h, ms),
            _ => _well(w, h, ms),
          };
        },
      );
    },
  );

  // ---- mode hemat ----------------------------------------------------------

  Widget _lite(double w, double h) {
    final s = widget.spec;
    final color = switch (s.kind) {
      _Kind.fusion => s.dark ? EmbunColors.mist : EmbunColors.gold,
      _Kind.wellBless => EmbunColors.leaf,
      _Kind.wellTaint => EmbunColors.mist,
    };
    final center = s.kind == _Kind.fusion
        ? Offset(w * .5, h * .42)
        : _wellOrigin(w, h);
    return CustomPaint(
      size: Size(w, h),
      painter: _LitePainter(_c.value, color, center),
    );
  }

  Offset _wellOrigin(double w, double h) {
    final o = widget.spec.origin;
    if (o == null) return Offset(w * .5, h * .42);
    final l = o - _shift;
    return Offset(
      l.dx.clamp(24.0, math.max(24.0, w - 24)).toDouble(),
      l.dy.clamp(80.0, math.max(80.0, h - 60)).toDouble(),
    );
  }

  // ---- gabung kartu --------------------------------------------------------

  Widget _fusion(double w, double h, double ms) {
    final s = widget.spec;
    final pal = s.dark ? _Pal.dark : _Pal.light;
    final c = Offset(w * .5, h * .42);
    final cw = math.min(128.0, math.min(w * .30, h * .22));
    final ch = cw * 1.5;
    final spread = cw * .84;
    final out = 1 - _sm(_seg(ms, _fOut, _fTotal));
    final enter = _sm(_seg(ms, 0, 380));
    final charge = _seg(ms, 380, _fPull0);
    final pull = Curves.easeInCubic.transform(_seg(ms, _fPull0, _fImpact));

    Offset posOf(int side) {
      final home = c + Offset(side * spread, 0);
      final jitter = Offset(
        math.sin(ms * .045 + side) * 2.6 * charge,
        math.cos(ms * .05 + side * 2) * 2.2 * charge,
      );
      final rise = Offset(0, 70 * (1 - enter));
      return Offset.lerp(home + jitter + rise, c, pull)!;
    }

    final a = posOf(-1), b = posOf(1);

    Widget card(int side, Offset p, Widget Function(double)? builder) {
      if (builder == null) return const SizedBox.shrink();
      final ang = side * (.10 * (1 - pull) + pull * math.pi * 3);
      final scale = (.9 + .1 * enter) * (1 + .12 * charge) * (1 - .6 * pull);
      final glow = (.25 + .6 * charge + .15 * pull).clamp(0.0, 1.0);
      return Positioned(
        left: p.dx - cw / 2,
        top: p.dy - ch / 2,
        child: SizedBox(
          width: cw,
          child: Opacity(
            opacity: enter,
            child: Transform.rotate(
              angle: ang,
              child: Transform.scale(
                scale: scale,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: pal.core.withValues(alpha: .7 * glow),
                        blurRadius: 10 + 24 * glow,
                        spreadRadius: 1 + 3 * glow,
                      ),
                    ],
                  ),
                  child: builder(cw),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Kartu hasil.
    final res = _seg(ms, _fImpact, _fImpact + 700);
    final rw = cw * 1.4, rh = rw * 1.5;
    final resScale = .25 + .75 * Curves.easeOutBack.transform(res);
    final resA = _sm(_seg(ms, _fImpact, _fImpact + 160)) * out;
    final float = Offset(0, -4 * math.sin(ms * .004));
    final resGlow = (.5 + .5 * math.sin(ms * .008)).clamp(0.0, 1.0);

    final flashT = ms - _fImpact;
    final flash = (flashT >= 0 && flashT < 300) ? .75 * (1 - flashT / 300) : 0.0;
    final labelA = _sm(_seg(ms, _fImpact + 450, _fImpact + 750)) * out;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Colors.black.withValues(
            alpha: pal.dim * _sm(_seg(ms, 0, 350)) * out,
          ),
        ),
        CustomPaint(
          painter: _FusionPainter(
            ms: ms,
            fade: out,
            cw: cw,
            pal: pal,
            c: c,
            a: a,
            b: b,
            seed: s.seed,
          ),
        ),
        if (ms < _fImpact) ...[
          card(-1, a, s.advCard),
          card(1, b, s.poinCard),
        ],
        if (ms >= _fImpact && s.resultCard != null)
          Positioned(
            left: c.dx - rw / 2 + float.dx,
            top: c.dy - rh / 2 + float.dy,
            child: SizedBox(
              width: rw,
              child: Opacity(
                opacity: resA.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: resScale,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: pal.core.withValues(
                            alpha: .55 + .25 * resGlow,
                          ),
                          blurRadius: 26 + 16 * resGlow,
                          spreadRadius: 2 + 3 * resGlow,
                        ),
                      ],
                    ),
                    child: s.resultCard!(rw),
                  ),
                ),
              ),
            ),
          ),
        if (labelA > .01)
          Positioned(
            left: 0,
            right: 0,
            top: c.dy + rh / 2 + 18,
            child: Opacity(
              opacity: labelA.clamp(0.0, 1.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'KARTU AKTIF',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w800,
                      color: pal.flash,
                      shadows: [
                        Shadow(color: pal.core, blurRadius: 12),
                        const Shadow(color: Colors.black, blurRadius: 4),
                      ],
                    ),
                  ),
                  if (s.label != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        s.label!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: EmbunColors.cream,
                          shadows: [
                            Shadow(color: pal.core, blurRadius: 14),
                            const Shadow(color: Colors.black, blurRadius: 5),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (flash > .01)
          ColoredBox(color: pal.flash.withValues(alpha: flash.clamp(0.0, 1.0))),
      ],
    );
  }

  // ---- sumur ---------------------------------------------------------------

  Widget _well(double w, double h, double ms) {
    final s = widget.spec;
    final taint = s.kind == _Kind.wellTaint;
    final o = _wellOrigin(w, h);
    final out = 1 - _sm(_seg(ms, _wOut, _wTotal));
    final dim = (taint ? .40 : .20) * _sm(_seg(ms, 0, 300)) * out;
    final labelColor = taint ? EmbunColors.blood : EmbunColors.leaf;
    final glowColor = taint ? EmbunColors.mist : EmbunColors.gold;
    final la = _sm(_seg(ms, 900, 1100)) * (1 - _sm(_seg(ms, 2000, 2500)));
    final rise = 46 * Curves.easeOutCubic.transform(_seg(ms, 900, 2000));

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Colors.black.withValues(alpha: dim)),
        CustomPaint(
          painter: _WellPainter(
            ms: ms,
            fade: out,
            taint: taint,
            c: o,
            seed: s.seed,
          ),
        ),
        if (s.label != null && la > .01)
          Positioned(
            left: o.dx,
            top: o.dy - 70 - rise,
            child: FractionalTranslation(
              translation: const Offset(-.5, -1),
              child: Opacity(
                opacity: la.clamp(0.0, 1.0),
                child: Text(
                  s.label!,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .5,
                    color: labelColor,
                    shadows: [
                      Shadow(color: glowColor, blurRadius: 16),
                      const Shadow(color: Colors.black, blurRadius: 5),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Painter: mode hemat
// ---------------------------------------------------------------------------

class _LitePainter extends CustomPainter {
  final double u;
  final Color color;
  final Offset c;
  const _LitePainter(this.u, this.color, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    if (u <= 0 || u >= 1) return;
    final e = Curves.easeOutCubic.transform(u);
    final rg = 20 + 140 * e;
    canvas.drawCircle(
      c,
      rg,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: .5 * (1 - u)),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: rg)),
    );
    canvas.drawCircle(
      c,
      18 + 110 * e,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * (1 - u) + .5
        ..color = color.withValues(alpha: .8 * (1 - u)),
    );
  }

  @override
  bool shouldRepaint(covariant _LitePainter old) => old.u != u;
}

// ---------------------------------------------------------------------------
// Painter: gabung kartu
// ---------------------------------------------------------------------------

class _FusionPainter extends CustomPainter {
  final double ms, fade, cw;
  final _Pal pal;
  final Offset c, a, b;
  final int seed;
  const _FusionPainter({
    required this.ms,
    required this.fade,
    required this.cw,
    required this.pal,
    required this.c,
    required this.a,
    required this.b,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double r(int i, int k) => _h(i + seed, k);
    const soft = MaskFilter.blur(BlurStyle.normal, 5);

    // 1. Butir tenaga berputar masuk ke titik pusat.
    if (ms < _fImpact) {
      final prog = _seg(ms, 150, _fImpact);
      for (var i = 0; i < 30; i++) {
        final f = _seg(prog, .35 * r(i, 1), 1.0);
        if (f <= 0) continue;
        final r0 = 120 + 190 * r(i, 2);
        final ang =
            r(i, 3) * 2 * math.pi +
                f * (3.2 + 2 * r(i, 4)) * (i.isEven ? 1 : -1);
        final rad = r0 * (1 - Curves.easeInCubic.transform(f));
        final pos = c + Offset(math.cos(ang), math.sin(ang)) * rad;
        final al = math.sin(f * math.pi).clamp(0.0, 1.0).toDouble() * fade;
        final sz = (2 + 3 * r(i, 5)) * (1 - .4 * f);
        final col = i.isEven ? pal.sparkA : pal.sparkB;
        canvas.drawCircle(
          pos,
          sz * 2.4,
          Paint()
            ..color = col.withValues(alpha: .32 * al)
            ..maskFilter = soft,
        );
        canvas.drawCircle(
          pos,
          sz,
          Paint()..color = col.withValues(alpha: .95 * al),
        );
      }
    }

    // 2. Benang cahaya yang menghubungkan kedua kartu.
    final link = _seg(ms, 500, _fImpact);
    if (link > 0 && ms < _fImpact) {
      final mid =
          Offset.lerp(a, b, .5)! +
              Offset(0, -36 * math.sin(link * math.pi) - 10 * math.sin(ms * .03));
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 + 10 * link
          ..color = pal.core.withValues(alpha: .28 * link * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.6 + 2.2 * link
          ..color = pal.flash.withValues(alpha: .85 * link * fade),
      );
    }

    // 3. Inti cahaya membesar selagi kartu bertemu.
    final pull = _seg(ms, _fPull0, _fImpact);
    if (ms < _fImpact && pull > 0) {
      final rr = 24 + 110 * Curves.easeIn.transform(pull);
      canvas.drawCircle(
        c,
        rr,
        Paint()
          ..shader = RadialGradient(
            colors: [
              pal.flash.withValues(alpha: .75 * pull * fade),
              pal.core.withValues(alpha: .28 * pull * fade),
              pal.core.withValues(alpha: 0),
            ],
            stops: const [0, .4, 1],
          ).createShader(Rect.fromCircle(center: c, radius: rr)),
      );
    }

    // 4. Hantaman: cincin kejut bertingkat dan berkas sinar.
    final s = (ms - _fImpact) / 1200;
    if (s > 0 && s < 1) {
      for (var ring = 0; ring < 3; ring++) {
        final rs = ((s - ring * .12) / (1 - ring * .12)).clamp(0.0, 1.0);
        if (rs <= 0) continue;
        final re = Curves.easeOutCubic.transform(rs);
        canvas.drawCircle(
          c,
          24 + (230 + 40 * ring) * re * (cw / 110),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = (8 * (1 - rs)).clamp(.5, 8.0).toDouble()
            ..color = Color.lerp(
              pal.ringA,
              pal.ringB,
              ring / 2,
            )!.withValues(alpha: (1 - rs) * fade),
        );
      }
      final e = Curves.easeOutCubic.transform(s);
      final ray = Paint()..color = pal.flash.withValues(alpha: .55 * (1 - s) * fade);
      for (var i = 0; i < 14; i++) {
        final ang = i * 2 * math.pi / 14 + .15 * s;
        final len = (80 + 200 * r(i, 6)) * e;
        final dir = Offset(math.cos(ang), math.sin(ang));
        final perp = Offset(-dir.dy, dir.dx);
        final base = c + dir * 30;
        final tip = c + dir * (30 + len);
        final half = 5.0 * (1 - s);
        canvas.drawPath(
          Path()
            ..moveTo(base.dx + perp.dx * half, base.dy + perp.dy * half)
            ..lineTo(tip.dx, tip.dy)
            ..lineTo(base.dx - perp.dx * half, base.dy - perp.dy * half)
            ..close(),
          ray,
        );
      }
    }

    // 5. Aura kartu hasil berdenyut, dengan berkas cahaya berputar pelan.
    final aT = _seg(ms, _fImpact, _fImpact + 700);
    if (aT > 0) {
      final grow = Curves.easeOutCubic.transform(aT);
      final pulse = .88 + .12 * math.sin(ms * .008);
      final rad = (70 + 150 * grow) * pulse * (cw / 110);
      canvas.drawCircle(
        c,
        rad,
        Paint()
          ..shader = RadialGradient(
            colors: [
              pal.auraA.withValues(alpha: .62 * fade * grow),
              pal.auraB.withValues(alpha: .26 * fade * grow),
              pal.auraB.withValues(alpha: 0),
            ],
            stops: const [0, .5, 1],
          ).createShader(Rect.fromCircle(center: c, radius: rad)),
      );
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(ms * .0004);
      final len = cw * 3.2;
      final wedge = Paint()
        ..color = pal.flash.withValues(alpha: .10 * grow * fade);
      for (var k = 0; k < 10; k++) {
        final a1 = k * 2 * math.pi / 10, a2 = a1 + .09;
        canvas.drawPath(
          Path()
            ..moveTo(0, 0)
            ..lineTo(math.cos(a1) * len, math.sin(a1) * len)
            ..lineTo(math.cos(a2) * len, math.sin(a2) * len)
            ..close(),
          wedge,
        );
      }
      canvas.restore();
    }

    // 6. Kilau naik dari kartu hasil.
    for (var i = 0; i < 30; i++) {
      final st = _fImpact + 100 + 600 * r(i, 7);
      final f = _seg(ms, st, st + 1100);
      if (f <= 0 || f >= 1) continue;
      final pos =
          c +
              Offset((r(i, 8) - .5) * cw * 2.2, cw * .9 * (r(i, 9) - .2)) +
              Offset(math.sin(f * 6 + i) * 10, -150 * f * (.5 + r(i, 10)));
      final al = math.sin(f * math.pi).clamp(0.0, 1.0).toDouble() * fade;
      _star(
        canvas,
        pos,
        3 + 4 * r(i, 11),
        Paint()
          ..color = (i.isEven ? pal.sparkA : Colors.white).withValues(
            alpha: .9 * al,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FusionPainter old) =>
      old.ms != ms || old.fade != fade || old.c != c;
}

// ---------------------------------------------------------------------------
// Painter: sumur
// ---------------------------------------------------------------------------

class _WellPainter extends CustomPainter {
  final double ms, fade;
  final bool taint;
  final Offset c;
  final int seed;
  const _WellPainter({
    required this.ms,
    required this.fade,
    required this.taint,
    required this.c,
    required this.seed,
  });

  static const _starts = [0.0, 200.0, 400.0];
  static const _fall = 460.0;
  static const _maxR = [150.0, 195.0, 245.0];
  static const _ink = Color(0xFF120A22);
  static const _mist = Color(0xFFB07CE8);

  @override
  void paint(Canvas canvas, Size size) {
    double r(int i, int k) => _h(i + seed, k);
    const soft = MaskFilter.blur(BlurStyle.normal, 5);
    final ringCols = taint
        ? const [Color(0xFFB07CE8), Color(0xFF6A3FA0), Color(0xFFD9B8FF)]
        : const [Color(0xFFBDF2E4), Color(0xFF7FE0A0), Color(0xFFFFE08A)];

    // Vinyet gelap (hanya cemar).
    if (taint) {
      final vin = _sm(_seg(ms, 350, 900)) * (1 - _sm(_seg(ms, 1900, 2500)));
      if (vin > .01) {
        final rect = Offset.zero & size;
        canvas.drawRect(
          rect,
          Paint()
            ..shader = RadialGradient(
              center: Alignment(
                c.dx / size.width * 2 - 1,
                c.dy / size.height * 2 - 1,
              ),
              radius: 1.0,
              colors: [
                Colors.transparent,
                const Color(0xFF07040F).withValues(alpha: .62 * vin * fade),
              ],
              stops: const [.35, 1],
            ).createShader(rect),
        );
      }
    }

    // Pendar permukaan air.
    final pool = _sm(_seg(ms, 450, 950)) * (1 - _sm(_seg(ms, 1950, 2500)));
    if (pool > .01) {
      final pc = taint ? _mist : const Color(0xFF8FE8D0);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(1, .38);
      canvas.drawCircle(
        Offset.zero,
        190,
        Paint()
          ..shader = RadialGradient(
            colors: [
              pc.withValues(alpha: .5 * pool * fade),
              pc.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: 190)),
      );
      canvas.restore();
    }

    // Kolom cahaya naik dari sumur (hanya rawat).
    if (!taint) {
      final colT = _seg(ms, 650, 2250);
      final hc =
          size.height * .5 * Curves.easeOutCubic.transform(_seg(ms, 650, 1350));
      if (colT > 0 && colT < 1 && hc > 2) {
        final env = math.pow(math.sin(colT * math.pi), .7).toDouble();
        final wb = 26 + 16 * env;
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - wb * .45, c.dy)
            ..lineTo(c.dx + wb * .45, c.dy)
            ..lineTo(c.dx + wb * 1.7, c.dy - hc)
            ..lineTo(c.dx - wb * 1.7, c.dy - hc)
            ..close(),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                const Color(0xFFFFE08A).withValues(alpha: .55 * env * fade),
                const Color(0xFF7FE0A0).withValues(alpha: .22 * env * fade),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromLTRB(c.dx - wb * 2, c.dy - hc, c.dx + wb * 2, c.dy),
            )
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
      }
    }

    // Noda tinta yang melebar (hanya cemar).
    if (taint) {
      final grow =
          30 +
              70 * Curves.easeOutCubic.transform(_seg(ms, 460, 1400)) +
              38 * Curves.easeOutCubic.transform(_seg(ms, 660, 1700)) +
              38 * Curves.easeOutCubic.transform(_seg(ms, 860, 2000));
      final appear = _sm(_seg(ms, 460, 560)) * (1 - _sm(_seg(ms, 2000, 2550)));
      if (appear > .01) {
        final path = Path();
        const n = 60;
        for (var k = 0; k <= n; k++) {
          final ang = k / n * 2 * math.pi;
          final wob =
              1 +
                  .20 * math.sin(3 * ang + r(1, 1) * 6) +
                  .11 * math.sin(5 * ang + r(2, 2) * 6) +
                  .07 * math.sin(9 * ang + r(3, 3) * 6);
          final p = Offset(
            c.dx + math.cos(ang) * grow * wob,
            c.dy + math.sin(ang) * grow * wob * .4,
          );
          k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        path.close();
        canvas.drawPath(
          path,
          Paint()..color = _ink.withValues(alpha: .93 * appear * fade),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..color = _mist.withValues(alpha: .22 * appear * fade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = _mist.withValues(alpha: .75 * appear * fade),
        );
      }

      // Sulur tinta merayap keluar.
      final tFade = 1 - _sm(_seg(ms, 1900, 2500));
      for (var i = 0; i < 9; i++) {
        final ang = i * 2 * math.pi / 9 + r(i, 4) * .5;
        final len = 120 + 110 * r(i, 5);
        final st = 700 + 80 * r(i, 6);
        final g = Curves.easeOutCubic.transform(_seg(ms, st, st + 900));
        if (g <= 0) continue;
        final dir = Offset(math.cos(ang), math.sin(ang));
        final perp = Offset(-dir.dy, dir.dx);
        final path = Path();
        Offset last = c;
        for (var j = 0; j <= 18; j++) {
          final t = g * j / 18;
          final wig = math.sin(t * math.pi * 1.5 + i) * len * .12;
          final p = c + dir * (len * t) + perp * wig;
          last = Offset(p.dx, c.dy + (p.dy - c.dy) * .42);
          j == 0 ? path.moveTo(c.dx, c.dy) : path.lineTo(last.dx, last.dy);
        }
        final al = (.7 - .3 * g) * tFade * fade;
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 2.6
            ..color = _mist.withValues(alpha: al),
        );
        canvas.drawCircle(
          last,
          2.8,
          Paint()..color = _mist.withValues(alpha: al),
        );
      }

      // Kabut ungu naik pelan.
      for (var i = 0; i < 9; i++) {
        final f = _seg(ms, 600 + 700 * r(i, 1), 600 + 700 * r(i, 1) + 1500);
        if (f <= 0 || f >= 1) continue;
        final pos = Offset(
          c.dx + (r(i, 2) - .5) * 200 + math.sin(f * 3 + i) * 14,
          c.dy - 20 - 150 * f * (.4 + r(i, 3)),
        );
        canvas.drawCircle(
          pos,
          24 + 26 * r(i, 4),
          Paint()
            ..color = const Color(0xFF5A2E8C).withValues(
              alpha: .16 * math.sin(f * math.pi) * fade,
            )
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
        );
      }
    }

    // Riak berlapis di permukaan.
    for (var i = 0; i < 3; i++) {
      final li = _starts[i] + _fall;

      // Kilat kecil saat tetes menyentuh.
      final hit = _seg(ms, li, li + 160);
      if (hit > 0 && hit < 1) {
        canvas.drawCircle(
          c,
          8 + 22 * hit,
          Paint()
            ..color = ringCols[i].withValues(alpha: .6 * (1 - hit) * fade),
        );
      }

      for (var ring = 0; ring < 2; ring++) {
        final rs = (ms - li - ring * 170) / 1500;
        if (rs <= 0 || rs >= 1) continue;
        final e = Curves.easeOutCubic.transform(rs);
        final rx = 14 + _maxR[i] * e * (ring == 0 ? 1 : .72);
        final rect = Rect.fromCenter(
          center: c,
          width: rx * 2,
          height: rx * .72,
        );
        canvas.drawOval(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..color = ringCols[i].withValues(alpha: .18 * (1 - rs) * fade)
            ..maskFilter = soft,
        );
        canvas.drawOval(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.6 * (1 - rs) + .6
            ..color = ringCols[i].withValues(alpha: .85 * (1 - rs) * fade),
        );
      }

      // Percikan.
      final sec = (ms - li) / 1000;
      if (sec > 0 && sec < .75) {
        for (var k = 0; k < 7; k++) {
          final vx = (r(i * 10 + k, 1) - .5) * 200;
          final vy = 120 + 160 * r(i * 10 + k, 2);
          final pos = c + Offset(vx * sec, -vy * sec + 520 * sec * sec);
          final al = (1 - sec / .75) * fade;
          final rad = 1.6 + 1.6 * r(i * 10 + k, 3);
          if (taint) {
            canvas.drawCircle(
              pos,
              rad,
              Paint()..color = _ink.withValues(alpha: .95 * al),
            );
            canvas.drawCircle(
              pos,
              rad,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1
                ..color = _mist.withValues(alpha: .9 * al),
            );
          } else {
            canvas.drawCircle(
              pos,
              rad,
              Paint()..color = const Color(0xFFBDF2E4).withValues(alpha: .9 * al),
            );
          }
        }
      }
    }

    // Butir naik dari sumur: embun berkilau, atau bulir hitam.
    for (var i = 0; i < 30; i++) {
      final st = 650 + 950 * r(i, 1);
      final f = _seg(ms, st, st + 1250);
      if (f <= 0 || f >= 1) continue;
      final e = Curves.easeOutCubic.transform(f);
      final pos = Offset(
        c.dx + (r(i, 2) - .5) * 170 * (.35 + f) + math.sin(f * 5 + i) * 9,
        c.dy - (30 + 250 * r(i, 3)) * e,
      );
      final al = math.sin(f * math.pi).clamp(0.0, 1.0).toDouble() * fade;
      final sz = 2.4 + 3.4 * r(i, 4);
      if (taint) {
        canvas.drawCircle(
          pos,
          sz * .8,
          Paint()..color = const Color(0xFF1B1030).withValues(alpha: .95 * al),
        );
        canvas.drawCircle(
          pos,
          sz * .8,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3
            ..color = _mist.withValues(alpha: .9 * al),
        );
      } else {
        final col = switch (i % 3) {
          0 => const Color(0xFFFFE08A),
          1 => const Color(0xFFBDF2E4),
          _ => const Color(0xFF9DF0B8),
        };
        canvas.drawCircle(
          pos,
          sz * 2.4,
          Paint()
            ..color = col.withValues(alpha: .30 * al)
            ..maskFilter = soft,
        );
        canvas.drawCircle(
          pos,
          sz,
          Paint()..color = col.withValues(alpha: .95 * al),
        );
        canvas.drawCircle(
          pos.translate(-sz * .3, -sz * .3),
          sz * .35,
          Paint()..color = Colors.white.withValues(alpha: .7 * al),
        );
        if (i % 5 == 0) {
          _star(
            canvas,
            pos,
            sz * 2.2,
            Paint()..color = Colors.white.withValues(alpha: .75 * al),
          );
        }
      }
    }

    // Tetes yang jatuh.
    final top = math.max(-40.0, c.dy - size.height * .55);
    for (var i = 0; i < 3; i++) {
      final p = _seg(ms, _starts[i], _starts[i] + _fall);
      if (p <= 0 || p >= 1) continue;
      final e = Curves.easeIn.transform(p);
      final pos = Offset(c.dx + (i - 1) * 7.0, _lerp(top, c.dy, e));
      final sz = 5.2 + i * .6;
      for (var k = 3; k >= 1; k--) {
        canvas.drawPath(
          _tear(pos.translate(0, -k * 11.0 * e), sz * (1 - k * .16)),
          Paint()
            ..color = (taint ? _mist : const Color(0xFFBDF2E4)).withValues(
              alpha: .16 * (4 - k) * fade,
            ),
        );
      }
      final path = _tear(pos, sz);
      if (taint) {
        canvas.drawPath(path, Paint()..color = _ink.withValues(alpha: fade));
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = _mist.withValues(alpha: .95 * fade),
        );
      } else {
        canvas.drawPath(
          path,
          Paint()..color = const Color(0xFFBDF2E4).withValues(alpha: .95 * fade),
        );
        canvas.drawCircle(
          pos.translate(-sz * .3, -sz * .2),
          sz * .3,
          Paint()..color = Colors.white.withValues(alpha: .8 * fade),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WellPainter old) =>
      old.ms != ms || old.fade != fade || old.c != c;
}