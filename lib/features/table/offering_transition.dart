import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';

double _seg(double t, double a, double b) =>
    ((t - a) / (b - a)).clamp(0.0, 1.0).toDouble();

double _bump(double t, double c, double w) =>
    max(0.0, 1 - (t - c).abs() / w);

/// Adegan menuju Hayu saat fase persembahan dimulai (4,8 detik).
/// Linimasa (t = 0..1):
///
///  0.00-0.07  layar menggelap, bilah sinema menutup
///  0.03-0.30  bulan purnama membesar di langit malam; kabut bergeser
///  0.05-0.66  butiran embun/kunang-kunang berpusar dari tepi layar menuju
///             Hayu (makin dekat makin cepat)
///  0.20-0.62  potret Hayu muncul sambil kamera mendekat (zoom 1,35 -> 1)
///             dalam aura yang warnanya mengikuti kesehatan Hayu
///  0.52/0.64/0.76  tiga detak jantung Hayu: pohon berdenyut, riak
///             cahaya, getar haptic "lub-dub"
///  0.50-0.62  judul "MALAM PERSEMBAHAN"
///  0.62-0.74  kalimat pembuka (berbeda untuk Si Terbisik)
///  0.68-0.82  jumlah daun dihitung naik, bilah kesehatan terisi
///  0.86       detak besar: kilatan, gelombang kejut, getar haptic berat
///  0.93-1.00  seluruh adegan memudar, tampil layar persembahan
///
/// [dark] = Si Terbisik yang tidak menyamar: palet ungu dan kalimat kabut.
/// Ketuk untuk melewati.
class OfferingTransition extends StatefulWidget {
  final int day;
  final int leaves;
  final bool dark;
  final VoidCallback onDone;

  const OfferingTransition({
    super.key,
    required this.day,
    required this.leaves,
    required this.onDone,
    this.dark = false,
  });

  @override
  State<OfferingTransition> createState() => _OfferingTransitionState();
}

class _OfferingTransitionState extends State<OfferingTransition>
    with SingleTickerProviderStateMixin {
  static const beats = [0.52, 0.64, 0.76];
  static const finale = 0.86;

  late final AnimationController c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 4800));
  final Set<int> _fired = {};
  bool _done = false;

  static double pulseAt(double t) {
    var p = 0.0;
    for (final b in beats) {
      p = max(p, max(_bump(t, b, 0.03), 0.6 * _bump(t, b + 0.04, 0.03)));
    }
    return p;
  }

  @override
  void initState() {
    super.initState();
    c.addListener(() {
      final t = c.value;
      for (var i = 0; i < beats.length; i++) {
        if (t >= beats[i] && _fired.add(i)) {
          HapticFeedback.mediumImpact();
          Future.delayed(
              const Duration(milliseconds: 120), HapticFeedback.lightImpact);
        }
      }
      if (t >= finale && _fired.add(99)) {
        HapticFeedback.heavyImpact();
        Future.delayed(
            const Duration(milliseconds: 130), HapticFeedback.heavyImpact);
      }
    });
    c.forward().whenComplete(_finish);
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    widget.onDone();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final vit = (widget.leaves / 30).clamp(0.0, 1.0).toDouble();
    final aura = Color.lerp(
      dark ? const Color(0xFF4A3A66) : const Color(0xFF7A6A92),
      dark ? const Color(0xFFB07CE8) : const Color(0xFFFFE08A),
      vit,
    )!;
    final orb = dark ? const Color(0xFFD9B8FF) : const Color(0xFF9FE3FF);
    final skyTop = dark ? const Color(0xFF0D0618) : const Color(0xFF04070D);
    final skyBot = dark ? const Color(0xFF1E0F36) : const Color(0xFF0B1A2E);
    final subtitle = dark
        ? 'Kabut memandangmu. Berpura-puralah menyumbang.'
        : 'Hayu menunggu pemberianmu';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        final treeW = min(min(w * 0.6, 460.0), h * 0.42 * 16 / 9).toDouble();
        final treeH = treeW * 9 / 16;
        final center = Offset(w / 2, h / 2 - 65);

        return AnimatedBuilder(
          animation: c,
          builder: (context, _) {
            final t = c.value;
            final pulse = pulseAt(t);
            final fin = _bump(t, finale, 0.04);

            final master = min(_seg(t, 0, 0.07), 1 - _seg(t, 0.93, 1.0));
            final barH = h * 0.09 * Curves.easeOut.transform(_seg(t, 0, 0.15));
            final landT = Curves.easeIn.transform(_seg(t, 0.2, 0.6));
            final flash = _bump(t, finale, 0.025) * 0.45;

            // --- Hayu: kamera mendekat + denyut ---
            final treeE = Curves.easeOutCubic.transform(_seg(t, 0.2, 0.62));
            final treeScale =
                (1.35 - 0.35 * treeE) * (1 + 0.035 * pulse + 0.05 * fin);
            final treeOpacity = _seg(t, 0.2, 0.4);

            final shadows = [
              const Shadow(color: Colors.black, blurRadius: 10),
              const Shadow(color: Colors.black, blurRadius: 3),
            ];

            final tt = _seg(t, 0.5, 0.62);
            final title = Opacity(
              opacity: tt,
              child: Transform.translate(
                offset: Offset(0, (1 - tt) * 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('HARI ${widget.day}',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 6,
                          color: Colors.white60,
                          shadows: shadows,
                        )),
                    const SizedBox(height: 4),
                    Text('MALAM PERSEMBAHAN',
                        style: TextStyle(
                          fontSize: 22,
                          letterSpacing: 5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: aura, blurRadius: 24),
                            const Shadow(color: Colors.black, blurRadius: 8),
                          ],
                        )),
                  ],
                ),
              ),
            );

            final st = _seg(t, 0.62, 0.74);
            final sub = Opacity(
              opacity: st,
              child: Transform.translate(
                offset: Offset(0, (1 - st) * 12),
                child: Text(subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: dark ? const Color(0xFFD9B8FF) : Colors.white70,
                      shadows: shadows,
                    )),
              ),
            );

            final lvT = _seg(t, 0.68, 0.82);
            final lvE = Curves.easeOut.transform(lvT);
            final shownLeaves = (widget.leaves * lvE).round();
            final barColor = dark
                ? const Color(0xFFB07CE8)
                : Color.lerp(Colors.redAccent, Colors.greenAccent, vit)!;
            final health = Opacity(
              opacity: lvT,
              child: Transform.translate(
                offset: Offset(0, (1 - lvT) * 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.eco,
                            size: 20,
                            color: dark ? Colors.blueGrey : Colors.greenAccent),
                        const SizedBox(width: 6),
                        Text('$shownLeaves daun',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              shadows: shadows,
                            )),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 200,
                      height: 6,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Stack(
                          children: [
                            const Positioned.fill(
                                child: ColoredBox(color: Colors.white12)),
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: (vit * lvE).clamp(0.0, 1.0).toDouble(),
                              child: SizedBox.expand(
                                  child: ColoredBox(color: barColor)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );

            final tree = Opacity(
              opacity: treeOpacity,
              child: Transform.scale(
                scale: treeScale,
                child: SizedBox(
                  width: treeW,
                  height: treeH,
                  child: TreePortrait(leaves: widget.leaves),
                ),
              ),
            );

            final content = Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: max(treeW, 380.0)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      tree,
                      const SizedBox(height: 14),
                      title,
                      const SizedBox(height: 8),
                      sub,
                      const SizedBox(height: 12),
                      health,
                    ],
                  ),
                ),
              ),
            );

            return Opacity(
              opacity: master.clamp(0.0, 1.0).toDouble(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [skyTop, skyBot],
                      ),
                    ),
                  ),
                  // bintang, bulan purnama, kabut
                  CustomPaint(
                    painter: _NightPainter(t: t, dark: dark, seed: widget.day),
                  ),
                  // lanskap sangat redup sebagai latar
                  Opacity(
                    opacity: landT * 0.5,
                    child: Transform.scale(
                      scale: 1.1 - 0.1 * t,
                      child: Backdrop(
                        path: landscapePath(widget.leaves),
                        dark: dark,
                        dim: 0.78,
                      ),
                    ),
                  ),
                  // aura Hayu, embun yang berpusar, riak detak
                  CustomPaint(
                    painter: _SpiritPainter(
                      t: t,
                      center: center,
                      aura: aura,
                      orb: orb,
                      treeW: treeW,
                      pulse: pulse,
                      seed: widget.day,
                    ),
                  ),
                  content,
                  if (flash > 0.01)
                    ColoredBox(
                        color: Color.lerp(Colors.white, aura, 0.3)!.withValues(
                            alpha: flash.clamp(0.0, 1.0).toDouble())),
                  Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                        height: barH,
                        width: w,
                        child: const ColoredBox(color: Colors.black)),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                        height: barH,
                        width: w,
                        child: const ColoredBox(color: Colors.black)),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: barH + 8,
                    child: Opacity(
                      opacity: _seg(t, 0.3, 0.45) * 0.7,
                      child: const Text('Ketuk untuk lewati',
                          textAlign: TextAlign.center,
                          style:
                          TextStyle(fontSize: 11, color: Colors.white54)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }
}

/// Bintang berkelip, bulan purnama yang membesar, dan kabut yang bergeser.
class _NightPainter extends CustomPainter {
  final double t;
  final bool dark;
  final int seed;
  _NightPainter({required this.t, required this.dark, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    final rnd = Random(seed * 71 + 11);
    final starA = _seg(t, 0, 0.1);
    for (var i = 0; i < 52; i++) {
      final x = rnd.nextDouble() * w;
      final y = rnd.nextDouble() * h * 0.7;
      final r = 0.8 + rnd.nextDouble() * 1.8;
      final ph = rnd.nextDouble() * 2 * pi;
      final tw = 0.5 + 0.5 * sin(t * 12 + ph);
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = Colors.white
              .withValues(alpha: (0.8 * starA * tw).clamp(0.0, 1.0).toDouble()),
      );
    }

    // bulan purnama di belakang Hayu
    final moonT = Curves.easeOut.transform(_seg(t, 0.03, 0.3));
    if (moonT > 0.01) {
      final mc = Offset(w * 0.5, h * 0.3);
      final mr = min(w, h) * 0.17 * (0.7 + 0.3 * moonT);
      final tint = dark ? const Color(0xFFD9B8FF) : const Color(0xFFDCE6FF);
      canvas.drawCircle(
        mc,
        mr * 3.2,
        Paint()
          ..shader = RadialGradient(colors: [
            tint.withValues(alpha: 0.35 * moonT),
            tint.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: mc, radius: mr * 3.2)),
      );
      canvas.drawCircle(
        mc,
        mr,
        Paint()
          ..color = Color.lerp(tint, Colors.white, 0.6)!
              .withValues(alpha: (0.92 * moonT).clamp(0.0, 1.0).toDouble()),
      );
      for (final k in const [
        [-0.3, -0.2, 0.22],
        [0.25, 0.1, 0.16],
        [-0.05, 0.38, 0.12],
      ]) {
        canvas.drawCircle(
          mc + Offset(k[0] * mr, k[1] * mr),
          k[2] * mr,
          Paint()..color = Colors.black.withValues(alpha: 0.07 * moonT),
        );
      }
    }

    // kabut
    final fog = 0.09 * _seg(t, 0, 0.15) * (1 - _seg(t, 0.85, 1.0));
    final fp = Paint()
      ..color = Colors.white.withValues(alpha: fog)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    for (var i = 0; i < 5; i++) {
      final dir = i.isEven ? 1.0 : -1.0;
      final x = (i * 0.27 + t * 0.15 * dir) % 1.3 - 0.15;
      canvas.drawCircle(
          Offset(w * x, h * (0.6 + 0.07 * i)), max(w, h) * 0.2, fp);
    }
  }

  @override
  bool shouldRepaint(covariant _NightPainter old) => old.t != t;
}

/// Aura Hayu, embun yang berpusar menuju pohon, riak tiap detak, dan
/// gelombang kejut pada detak besar.
class _SpiritPainter extends CustomPainter {
  final double t;
  final Offset center;
  final Color aura;
  final Color orb;
  final double treeW;
  final double pulse;
  final int seed;
  _SpiritPainter({
    required this.t,
    required this.center,
    required this.aura,
    required this.orb,
    required this.treeW,
    required this.pulse,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // aura
    final auraT = Curves.easeOut.transform(_seg(t, 0.2, 0.55));
    final ar = treeW * (0.75 + 0.08 * pulse);
    canvas.drawCircle(
      center,
      ar,
      Paint()
        ..shader = RadialGradient(colors: [
          aura.withValues(
              alpha: (0.5 * auraT * (0.8 + 0.2 * pulse)).clamp(0.0, 1.0).toDouble()),
          aura.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: center, radius: ar)),
    );

    // embun berpusar menuju Hayu
    final rnd = Random(seed * 13 + 1);
    final maxR = max(size.width, size.height) * 0.55;
    for (var i = 0; i < 28; i++) {
      final a0 = rnd.nextDouble() * 2 * pi;
      final r0 = maxR * (0.5 + rnd.nextDouble() * 0.5);
      final s0 = 0.05 + rnd.nextDouble() * 0.22;
      final e0 = s0 + 0.30 + rnd.nextDouble() * 0.08;
      final sz = 2.2 + rnd.nextDouble() * 3.2;
      final f = _seg(t, s0, e0);
      if (f <= 0 || f >= 1) continue;
      final e = Curves.easeInCubic.transform(f);
      final r = r0 * (1 - e) + 10;
      final ang = a0 + f * 2.6;
      final pos = center + Offset(cos(ang), sin(ang)) * r;
      final al = sin(f * pi).clamp(0.0, 1.0).toDouble();
      final col = Color.lerp(orb, aura, (i % 3) / 2)!;
      canvas.drawCircle(pos, sz * 2.6, Paint()..color = col.withValues(alpha: 0.18 * al));
      canvas.drawCircle(
        pos,
        sz,
        Paint()
          ..color = Color.lerp(col, Colors.white, 0.5)!.withValues(alpha: 0.9 * al),
      );
    }

    // riak tiap detak jantung
    for (final b in _OfferingTransitionState.beats) {
      final s = _seg(t, b, b + 0.13);
      if (s <= 0 || s >= 1) continue;
      final e = Curves.easeOutCubic.transform(s);
      canvas.drawCircle(
        center,
        treeW * 0.3 + treeW * 0.9 * e,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (4 * (1 - s)).clamp(0.5, 4.0).toDouble()
          ..color = aura.withValues(alpha: (0.6 * (1 - s)).clamp(0.0, 1.0).toDouble()),
      );
    }

    // detak besar: gelombang kejut
    final fs = _seg(t, _OfferingTransitionState.finale, 0.97);
    if (fs > 0 && fs < 1) {
      final e = Curves.easeOutCubic.transform(fs);
      canvas.drawCircle(
        center,
        treeW * 0.3 + max(size.width, size.height) * 0.7 * e,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (9 * (1 - fs)).clamp(0.5, 9.0).toDouble()
          ..color = Color.lerp(aura, Colors.white, 0.5)!
              .withValues(alpha: (1 - fs).clamp(0.0, 1.0).toDouble()),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpiritPainter old) => old.t != t;
}