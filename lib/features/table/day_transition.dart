import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/fx_shaders.dart';
import '../common/scene_flow.dart';
import '../common/sfx.dart';

double _seg(double t, double a, double b) =>
    ((t - a) / (b - a)).clamp(0.0, 1.0).toDouble();

double _bump(double t, double c, double w) =>
    max(0.0, 1 - (t - c).abs() / w);

double _hillY(double x, double w, double h) =>
    h * 0.80 +
        sin(x / w * pi * 2 + 0.6) * h * 0.018 +
        sin(x / w * pi * 5 + 1.3) * h * 0.007;

double _hill2Y(double x, double w, double h) =>
    h * 0.89 + sin(x / w * pi * 3 + 2.0) * h * 0.016;

/// Adegan sinematik peralihan hari (4,4 detik gerak + jeda baca). Menyambung dari NightScene:
/// dunia yang sama (bulan, bukit, rumah desa, pohon Hayu) tetapi sekarang
/// fajar menyingsing. Empat babak berurutan (t = 0..1), tiap babak hanya satu
/// "bintang utama" supaya mata tidak terbagi:
///
///  1. 0.00-0.30  MALAM SUNYI. Bulan tenggelam, bintang memudar, jendela
///                rumah menyala bergantian. Tulisan "HARI" dan angka kemarin
///                muncul pelan.
///  2. 0.12-0.62  FAJAR. Matahari terbit, langit beralih ke warna pagi, lalu
///                lanskap Hayu muncul menggantikan siluet (zoom perlahan).
///  3. 0.30-0.60  ANGKA. Angka kemarin melebur jadi angka hari ini (mendarat
///                di t = 0.50 dengan satu kilat lembut dan satu cincin).
///  4. 0.58-0.94  INFO BERURUTAN, tidak bertabrakan: persembahan (0.58-0.68),
///                jumlah daun + bilah Hayu (0.68-0.80), vonis (0.82-0.94).
///  setelah 1.00  jeda baca (lama menyesuaikan panjang teks vonis), lalu
///                adegan melebur ke layar hari
///
/// Adegan ini MASUK dari warna dasar [kSceneInk] (sama dengan akhir adegan
/// malam / kurungan / pengusiran sebelumnya) dan baru keluar dengan melebur
/// ke layar meja.
///
/// Pohon Hayu pada siluet mengikuti kesehatan: rimbun saat daun banyak,
/// jarang dan berwarna kelabu saat daun sedikit. Malam persembahan (hari
/// kelipatan siklus) memakai palet bara jingga, Si Terbisik yang tidak
/// menyamar memakai palet ungu. Ketuk untuk melewati.
class DayTransition extends StatefulWidget {
  final int day;
  final int leaves;
  final int cycle;
  final String? verdict;
  final bool dark;
  final VoidCallback onDone;

  const DayTransition({
    super.key,
    required this.day,
    required this.leaves,
    required this.cycle,
    required this.onDone,
    this.verdict,
    this.dark = false,
  });

  @override
  State<DayTransition> createState() => _DayTransitionState();
}

class _DayTransitionState extends State<DayTransition>
    with SingleTickerProviderStateMixin {
  static const _night = kSceneInk;
  static const _land = 0.50;

  /// Bagian bergerak (t = 0..1 pada linimasa di atas).
  static const _playMs = 4400;

  /// Jeda baca setelah semua teks tampil. Vonis hari sebelumnya baru muncul
  /// di t = 0.78-0.90, jadi ia butuh waktu baca penuh sesudahnya.
  late final int _holdMs = widget.verdict == null
      ? 1800
      : max(2200, readMs(widget.verdict, min: 2600) - 600);
  late final int _totalMs = _playMs + _holdMs + kSceneFadeOutMs;

  late final AnimationController c = AnimationController(
      vsync: this, duration: Duration(milliseconds: _totalMs));
  final Set<int> _fired = {};
  bool _done = false;

  /// Kabut fajar + bulir cahaya (prologue_fx.frag). Null = painter lama.
  ui.FragmentShader? _fogFx;

  /// Berkas cahaya matahari dari cakrawala (divine.frag mode 0). Null = tanpa.
  ui.FragmentShader? _sunFx;

  bool get _offering => widget.day % widget.cycle == 0;

  Color get _warm => widget.dark
      ? const Color(0xFFB07CE8)
      : _offering
      ? const Color(0xFFFF9A52)
      : const Color(0xFFFFC857);

  Color get _cool => widget.dark
      ? const Color(0xFF2A1745)
      : _offering
      ? const Color(0xFF3A2438)
      : const Color(0xFF24365E);

  @override
  void initState() {
    super.initState();
    _fogFx = FxShaders.make(FxShaders.prologue);
    _sunFx = FxShaders.make(FxShaders.divine);
    c.addListener(() {
      final t = c.value * _totalMs / _playMs;
      if (t >= 0.04 && _fired.add(0)) {
        HapticFeedback.lightImpact();
        Sfx.I.playAny(Snd.winds, owner: this, tag: 'dawn-wind');
      }
      if (t >= _land && _fired.add(1)) {
        HapticFeedback.mediumImpact();
        Sfx.I.play(Snd.fairyGrow, owner: this, tag: 'dawn-land');
      }
      if (t >= 0.68 && _fired.add(2)) HapticFeedback.selectionClick();
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
    _fogFx?.dispose();
    _sunFx?.dispose();
    Sfx.I.release(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final warm = _warm;
    final offering = _offering;
    final subtitle = offering
        ? 'Malam persembahan'
        : 'Persembahan ${widget.cycle - widget.day % widget.cycle} hari lagi';
    final vit = (widget.leaves / 30).clamp(0.0, 1.0).toDouble();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: LayoutBuilder(builder: (context, box) {
        final h = box.maxHeight;
        final numSize = (h * 0.28).clamp(64.0, 120.0).toDouble();

        return AnimatedBuilder(
          animation: c,
          builder: (context, _) {
            final ms = c.value * _totalMs;
            // t > 1 selama jeda baca: gerak lembut (bintang, kabut, butiran)
            // tetap hidup, sementara semua tahap bersyarat sudah tuntas.
            final t = ms / _playMs;

            // Hanya keluarnya yang melebur ke layar meja; masuknya lewat
            // tirai gelap di paling atas, supaya tak ada kilasan layar meja.
            final master =
                1 - fadeMs(ms, _totalMs - kSceneFadeOutMs.toDouble(), _totalMs.toDouble());
            final veilIn = 1 - fadeMs(ms, 0, kSceneFadeInMs.toDouble());
            final sky = Curves.easeInOut.transform(_seg(t, 0.12, 0.55));
            final reveal = Curves.easeInOut.transform(_seg(t, 0.38, 0.62));
            final kb = Curves.easeOutCubic.transform(_seg(t, 0.3, 1.0));
            final zoom = 1.0 + 0.08 * (1 - kb);
            final flash = _bump(t, _land, 0.04) * 0.30;

            // --- angka kemarin melebur jadi angka hari ini ---
            final labelT = Curves.easeOut.transform(_seg(t, 0.04, 0.16));
            final pvIn = _seg(t, 0.08, 0.18);
            final pvOut = Curves.easeIn.transform(_seg(t, 0.30, 0.42));
            final inK = Curves.easeOutCubic.transform(_seg(t, 0.40, _land));
            final numOpacity = _seg(t, 0.40, 0.46);

            final shadows = [
              const Shadow(color: Colors.black, blurRadius: 10),
              const Shadow(color: Colors.black, blurRadius: 3),
            ];

            final label = Opacity(
              opacity: labelT,
              child: Transform.translate(
                offset: Offset(0, (1 - labelT) * -10),
                child: Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Text('HARI',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 14,
                        color: Colors.white70,
                        shadows: shadows,
                      )),
                ),
              ),
            );

            final numberBox = SizedBox(
              width: numSize * 2.4,
              height: numSize * 1.05,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  if (widget.day > 1)
                    Opacity(
                      opacity: (pvIn * (1 - pvOut)).clamp(0.0, 1.0).toDouble(),
                      child: Transform.translate(
                        offset: Offset(0, -14 * pvOut),
                        child: Transform.scale(
                          scale: 1 - 0.12 * pvOut,
                          child: Text('${widget.day - 1}',
                              style: TextStyle(
                                fontSize: numSize,
                                height: 1.0,
                                fontWeight: FontWeight.w900,
                                color: Colors.white38,
                              )),
                        ),
                      ),
                    ),
                  Opacity(
                    opacity: numOpacity,
                    child: Transform.scale(
                      scale: 1.22 - 0.22 * inK,
                      child: Text('${widget.day}',
                          style: TextStyle(
                            fontSize: numSize,
                            height: 1.0,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            shadows: [
                              Shadow(color: warm, blurRadius: 32),
                              const Shadow(color: Colors.black, blurRadius: 8),
                            ],
                          )),
                    ),
                  ),
                ],
              ),
            );

            final line = Container(
              width: 170 * Curves.easeOut.transform(_seg(t, _land, 0.60)),
              height: 3,
              decoration: BoxDecoration(
                color: warm,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [BoxShadow(color: warm, blurRadius: 10)],
              ),
            );

            final st = _seg(t, 0.58, 0.68);
            final sub = Opacity(
              opacity: st,
              child: Transform.translate(
                offset: Offset(0, (1 - st) * 14),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: offering ? FontWeight.w800 : FontWeight.w500,
                    letterSpacing: 1,
                    color: offering ? Colors.amberAccent : Colors.white70,
                    shadows: shadows,
                  ),
                ),
              ),
            );

            final lvT = _seg(t, 0.68, 0.80);
            final lvE = Curves.easeOut.transform(lvT);
            final shownLeaves = (widget.leaves * lvE).round();
            final barColor = widget.dark
                ? const Color(0xFFB07CE8)
                : Color.lerp(Colors.redAccent, Colors.greenAccent, vit)!;
            final leavesBlock = Opacity(
              opacity: lvT,
              child: Transform.translate(
                offset: Offset(0, (1 - lvT) * 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const GameIcon('helaidaun', size: 30),
                        const SizedBox(width: 6),
                        Text('$shownLeaves daun',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              shadows: shadows,
                            )),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 180,
                      height: 6,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Stack(
                          children: [
                            const Positioned.fill(
                                child: ColoredBox(color: Colors.white12)),
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor:
                              (vit * lvE).clamp(0.0, 1.0).toDouble(),
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

            final vt = _seg(t, 0.82, 0.94);
            final paper = sceneryPath('kertaslusuh');
            const ink = Color(0xFF3A2A12);
            final verdictBox = widget.verdict == null
                ? const SizedBox.shrink()
                : Opacity(
              opacity: vt,
              child: Transform.translate(
                offset: Offset(0, (1 - vt) * 14),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: EdgeInsets.symmetric(
                      horizontal: 14, vertical: paper == null ? 8 : 12),
                  decoration: paper == null
                      ? BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                    border:
                    Border.all(color: warm.withValues(alpha: 0.6)),
                  )
                      : BoxDecoration(
                    image: DecorationImage(
                        image: ResizeImage(AssetImage(paper), width: 900),
                        fit: BoxFit.cover),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF6B4E1E).withValues(alpha: 0.8)),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 10),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const GameIcon('vote', size: 26),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(widget.verdict!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                color: paper == null ? null : ink,
                                fontWeight:
                                paper == null ? null : FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
            );

            final content = Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      label,
                      numberBox,
                      const SizedBox(height: 8),
                      line,
                      const SizedBox(height: 12),
                      sub,
                      const SizedBox(height: 14),
                      leavesBlock,
                      if (widget.verdict != null) ...[
                        const SizedBox(height: 14),
                        verdictBox,
                      ],
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
                  // langit malam -> fajar
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.lerp(_night, _cool, sky)!,
                          Color.lerp(
                              _night, Color.lerp(_cool, warm, 0.6)!, sky)!,
                          Color.lerp(
                              _night, Color.lerp(_cool, warm, 0.95)!, sky)!,
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                  // bintang, bulan tenggelam, matahari terbit, sinar
                  CustomPaint(
                    painter: _SkyPainter(
                      t: t,
                      warm: warm,
                      seed: widget.day,
                      // Pendar bulat lama dikurangi bila berkas shader menyala.
                      glow: _sunFx == null ? 1.0 : 0.5,
                    ),
                  ),
                  // siluet desa + Hayu (menyambung dari layar malam)
                  if (reveal < 0.99)
                    Opacity(
                      opacity: (1 - reveal).clamp(0.0, 1.0).toDouble(),
                      child: CustomPaint(
                        painter: _GroundPainter(
                          t: t,
                          warm: warm,
                          vit: vit,
                          dark: widget.dark,
                          leaves: widget.leaves,
                        ),
                      ),
                    ),
                  // lanskap Hayu: muncul + zoom perlahan + terhentak
                  Opacity(
                    opacity: reveal * 0.82,
                    child: Transform.scale(
                      scale: zoom,
                      child: Backdrop(
                        path: (widget.leaves >= 12
                            ? firstScenery(const ['langit-fajar'])
                            : null) ??
                            landscapePath(widget.leaves),
                        dark: widget.dark,
                        dim: 0.5,
                      ),
                    ),
                  ),
                  // kabut malam + butiran cahaya fajar
                  CustomPaint(
                    painter: _fogFx == null
                        ? _MotesPainter(t: t, warm: warm, seed: widget.day)
                        : _DawnFogPainter(
                        shader: _fogFx!, t: t, sec: ms / 1000, warm: warm),
                  ),
                  // berkas cahaya dari matahari yang terbit
                  if (_sunFx != null)
                    CustomPaint(
                      painter: _SunRaysPainter(
                          shader: _sunFx!,
                          t: t,
                          sec: ms / 1000,
                          reveal: reveal,
                          warm: warm),
                    ),
                  // vinyet agar teks terbaca
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 0.95,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                        ],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                  CustomPaint(
                    painter: _RingPainter(t: t, warm: warm, seed: widget.day),
                  ),
                  content,
                  if (flash > 0.01)
                    ColoredBox(
                        color: Colors.white.withValues(
                            alpha: flash.clamp(0.0, 1.0).toDouble())),
                  // petunjuk lewati
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 14,
                    child: Opacity(
                      opacity: _seg(t, 0.3, 0.45) * 0.7,
                      child: const Text('Ketuk untuk lewati',
                          textAlign: TextAlign.center,
                          style:
                          TextStyle(fontSize: 11, color: Colors.white54)),
                    ),
                  ),
                  sceneVeil(veilIn),
                ],
              ),
            );
          },
        );
      }),
    );
  }
}

/// Bintang yang memudar, bulan yang tenggelam (posisinya sama dengan layar
/// malam), matahari terbit, dan sinar yang berputar.
class _SkyPainter extends CustomPainter {
  final double t;
  final Color warm;
  final int seed;

  /// Pengali pendar bulat di sekitar matahari (1 = penuh).
  final double glow;
  _SkyPainter({
    required this.t,
    required this.warm,
    required this.seed,
    this.glow = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // bintang
    final starFade = 1 - Curves.easeIn.transform(_seg(t, 0.05, 0.55));
    if (starFade > 0) {
      final rnd = Random(seed * 97 + 5);
      for (var i = 0; i < 60; i++) {
        final x = rnd.nextDouble() * w;
        final y = rnd.nextDouble() * h * 0.62;
        final r = 0.8 + rnd.nextDouble() * 1.8;
        final ph = rnd.nextDouble() * 2 * pi;
        final tw = 0.55 + 0.45 * sin(t * 14 + ph);
        canvas.drawCircle(
          Offset(x, y),
          r,
          Paint()
            ..color = Colors.white.withValues(
                alpha: (starFade * tw).clamp(0.0, 1.0).toDouble()),
        );
      }
    }

    // bulan tenggelam ke balik bukit
    final moonT = 1 - Curves.easeIn.transform(_seg(t, 0.04, 0.5));
    if (moonT > 0.01) {
      final r = min(w, h) * 0.11;
      final mc = Offset(w * 0.74, h * (0.2 + 0.62 * (1 - moonT)));
      final tint = const Color(0xFFF3E9B8);
      canvas.drawCircle(
        mc,
        r * 3.4,
        Paint()
          ..shader = RadialGradient(colors: [
            tint.withValues(alpha: 0.30 * moonT),
            tint.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: mc, radius: r * 3.4)),
      );
      canvas.drawCircle(
        mc,
        r,
        Paint()
          ..color = const Color(0xFFF6EDBF)
              .withValues(alpha: (0.95 * moonT).clamp(0.0, 1.0).toDouble()),
      );
      for (final k in const [
        [-0.3, -0.25, 0.22],
        [0.28, 0.12, 0.16],
        [-0.08, 0.42, 0.12],
      ]) {
        canvas.drawCircle(mc + Offset(k[0] * r, k[1] * r), k[2] * r,
            Paint()..color = Colors.black.withValues(alpha: 0.08 * moonT));
      }
    }

    // matahari terbit dari balik bukit
    final sunT = Curves.easeOutCubic.transform(_seg(t, 0.15, 0.62));
    final r = min(w, h) * 0.14;
    final c = Offset(w * 0.45, h * (0.98 - 0.52 * sunT));

    canvas.drawCircle(
      c,
      r * 5.5,
      Paint()
        ..shader = RadialGradient(colors: [
          warm.withValues(alpha: 0.65 * sunT * glow),
          warm.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: c, radius: r * 5.5)),
    );

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = Color.lerp(warm, Colors.white, 0.55)!
            .withValues(alpha: sunT.clamp(0.0, 1.0).toDouble()),
    );
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => old.t != t;
}

/// Siluet bukit, rumah desa, dan pohon Hayu. Rumah terbangun (jendela
/// menyala), tepi bukit berpendar disinari matahari, burung melintas.
/// Pohon mengikuti kesehatan Hayu: jarang dan kelabu bila daun sedikit.
class _GroundPainter extends CustomPainter {
  final double t;
  final Color warm;
  final double vit;
  final bool dark;
  final int leaves;
  _GroundPainter({
    required this.t,
    required this.warm,
    required this.vit,
    required this.dark,
    required this.leaves,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final sunT = Curves.easeOutCubic.transform(_seg(t, 0.15, 0.62));
    final dawn = _seg(t, 0.3, 0.7);
    final u = min(w, h);

    // ---- bukit belakang ----
    final ridge = Path()..moveTo(0, _hillY(0, w, h));
    final hill = Path()..moveTo(0, h);
    hill.lineTo(0, _hillY(0, w, h));
    for (double x = 6; x <= w + 6; x += 6) {
      final y = _hillY(x, w, h);
      ridge.lineTo(x, y);
      hill.lineTo(x, y);
    }
    hill.lineTo(w, h);
    hill.close();

    final topCol = Color.lerp(const Color(0xFF0B1630),
        Color.lerp(const Color(0xFF1A2438), warm, 0.4)!, sunT)!;
    canvas.drawPath(
      hill,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, h * 0.75), Offset(0, h),
            [topCol, const Color(0xFF050A14)]),
    );
    // tepi bukit berpendar
    canvas.drawPath(
      ridge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
        ..color = warm.withValues(alpha: 0.65 * sunT),
    );

    // ---- rumah desa terbangun ----
    final bw = u * 0.055, bh = bw * 0.8, rh = bw * 0.5;
    const hx = [0.50, 0.61, 0.73, 0.85];
    final wake = _seg(t, 0.05, 0.28) * (1 - _seg(t, 0.45, 0.7));
    for (var i = 0; i < hx.length; i++) {
      final x = w * hx[i];
      final by = _hillY(x, w, h) + 2;
      canvas.drawRect(Rect.fromLTWH(x - bw / 2, by - bh, bw, bh),
          Paint()..color = const Color(0xFF040810));
      canvas.drawPath(
        Path()
          ..moveTo(x - bw * 0.62, by - bh)
          ..lineTo(x, by - bh - rh)
          ..lineTo(x + bw * 0.62, by - bh)
          ..close(),
        Paint()..color = const Color(0xFF03060D),
      );
      // tiap rumah bangun bergantian
      final lit = (_seg(t, 0.05 + i * 0.05, 0.12 + i * 0.05)) *
          (1 - _seg(t, 0.45 + i * 0.03, 0.62 + i * 0.03)) *
          (0.85 + 0.15 * sin(t * 40 + i * 2));
      if (lit > 0.01 && wake >= 0) {
        final win = Rect.fromCenter(
            center: Offset(x, by - bh * 0.5),
            width: bw * 0.3,
            height: bw * 0.3);
        canvas.drawCircle(
          win.center,
          bw * 1.2,
          Paint()
            ..shader = ui.Gradient.radial(win.center, bw * 1.2, [
              const Color(0xFFFFC857).withValues(alpha: 0.32 * lit),
              const Color(0xFFFFC857).withValues(alpha: 0),
            ]),
        );
        canvas.drawRect(win,
            Paint()..color = const Color(0xFFFFD27A).withValues(alpha: lit));
      }
    }

    // ---- pohon Hayu ----
    final tx = w * 0.20;
    final baseY = _hillY(tx, w, h);
    final th = h * 0.06;
    final ch = h * 0.045;
    final trunkW = h * 0.011;
    final canopyBase = baseY - th;
    final nightTree = const Color(0xFF06101A);
    final aliveCol = vit >= 0.95
        ? const Color(0xFF8A4A62) // sakura: rona merah muda gelap
        : Color.lerp(const Color(0xFF3A3640), const Color(0xFF1F5A3A), vit)!;
    final treeCol = Color.lerp(nightTree, aliveCol, dawn * 0.85)!;

    // aura Hayu menyala seiring fajar
    final auraA = (0.10 + 0.22 * vit) * dawn * (1 - _seg(t, 0.62, 0.7));
    final ac = Offset(tx, canopyBase - ch * 0.4);
    final auraCol = dark ? const Color(0xFFB07CE8) : const Color(0xFF7FE0A0);
    canvas.drawCircle(
      ac,
      ch * 3.6,
      Paint()
        ..shader = ui.Gradient.radial(ac, ch * 3.6, [
          auraCol.withValues(alpha: auraA.clamp(0.0, 1.0)),
          auraCol.withValues(alpha: 0),
        ]),
    );

    final trunkPaint = Paint()..color = nightTree;
    canvas.drawPath(
      Path()
        ..moveTo(tx - trunkW, baseY + 2)
        ..lineTo(tx - trunkW * 0.55, canopyBase)
        ..lineTo(tx + trunkW * 0.55, canopyBase)
        ..lineTo(tx + trunkW, baseY + 2)
        ..close(),
      trunkPaint,
    );
    // dahan telanjang, tampak jelas bila daun sedikit
    final branch = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = trunkW * 0.55
      ..color = nightTree;
    const br = [
      [-1.0, 1.5],
      [1.0, 1.6],
      [-0.5, 2.0],
      [0.55, 2.1],
    ];
    for (final b in br) {
      canvas.drawLine(
          Offset(tx, canopyBase),
          Offset(tx + b[0] * ch * 1.3, canopyBase - b[1] * ch),
          branch);
    }

    const crown = [
      [0.0, 0.2, 1.0],
      [-0.9, 0.0, 0.7],
      [0.9, 0.05, 0.75],
      [-0.4, 0.9, 0.7],
      [0.45, 0.85, 0.65],
    ];
    final count = (1 + vit * 4).round().clamp(1, 5);
    final fill = Paint()..color = treeCol;
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = warm.withValues(alpha: 0.5 * sunT);
    for (var i = 0; i < count; i++) {
      final c = crown[i];
      final p = Offset(tx + c[0] * ch, canopyBase - c[1] * ch);
      canvas.drawCircle(p, c[2] * ch, fill);
      canvas.drawCircle(p, c[2] * ch, rim);
    }

    // ---- bukit depan ----
    final front = Path()..moveTo(0, h);
    for (double x = 0; x <= w + 6; x += 6) {
      front.lineTo(x, _hill2Y(x, w, h));
    }
    front.lineTo(w, h);
    front.close();
    canvas.drawPath(front, Paint()..color = const Color(0xFF03060D));
  }

  @override
  bool shouldRepaint(covariant _GroundPainter old) => old.t != t;
}

/// Kabut malam yang bergeser dan memudar saat fajar, lalu butiran cahaya
/// yang melayang naik.
class _MotesPainter extends CustomPainter {
  final double t;
  final Color warm;
  final int seed;
  _MotesPainter({required this.t, required this.warm, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    final fog = 0.09 * (1 - _seg(t, 0.3, 0.62)) * _seg(t, 0, 0.1);
    if (fog > 0.003) {
      final p = Paint()
        ..color = Colors.white.withValues(alpha: fog)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 38);
      for (var i = 0; i < 5; i++) {
        final dir = i.isEven ? 1.0 : -1.0;
        final x = (i * 0.27 + t * 0.35 * dir) % 1.3 - 0.15;
        canvas.drawCircle(
            Offset(w * x, h * (0.55 + 0.09 * i)), max(w, h) * 0.2, p);
      }
    }

    final mt = _seg(t, 0.5, 0.7);
    if (mt > 0) {
      final rnd = Random(seed * 53 + 9);
      for (var i = 0; i < 12; i++) {
        final x0 = rnd.nextDouble();
        final sp = 0.5 + rnd.nextDouble();
        final sz = 1.5 + rnd.nextDouble() * 3.5;
        final ph = rnd.nextDouble();
        final f = (t * 1.3 * sp + ph) % 1.0;
        final y = h * (1.05 - f * 1.1);
        final x = w * x0 + sin((f + ph) * 2 * pi) * 16;
        final a = (sin(f * pi) * 0.7 * mt).clamp(0.0, 1.0).toDouble();
        canvas.drawCircle(
          Offset(x, y),
          sz,
          Paint()
            ..color = (i.isEven ? warm : Colors.white).withValues(alpha: a),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MotesPainter old) => old.t != t;
}

/// Satu cincin lembut yang melebar saat angka hari mendarat.
class _RingPainter extends CustomPainter {
  final double t;
  final Color warm;
  final int seed;
  _RingPainter({required this.t, required this.warm, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final s = _seg(t, _DayTransitionState._land, 0.88);
    if (s <= 0 || s >= 1) return;
    final c = Offset(size.width / 2, size.height * 0.46);
    final re = Curves.easeOutCubic.transform(s);
    canvas.drawCircle(
      c,
      30 + 420 * re,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (5 * (1 - s)).clamp(0.5, 5.0).toDouble()
        ..color = warm.withValues(alpha: 0.7 * (1 - s).clamp(0.0, 1.0)),
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.t != t;
}

void _setRgb(ui.FragmentShader s, int i, Color c) {
  s
    ..setFloat(i, c.r)
    ..setFloat(i + 1, c.g)
    ..setFloat(i + 2, c.b);
}

/// Kabut fajar dan bulir cahaya dari shaders/prologue_fx.frag, menggantikan
/// [_MotesPainter]. Urutan setFloat HARUS sama dengan deklarasi uniform di
/// berkas shader itu. Berkas cahayanya (uRays) sengaja 0: sumbernya di shader
/// itu tetap di atas layar, jadi sinar matahari dipegang [_SunRaysPainter].
/// Denyut (uPulse) dan gelombang kejut (uShock) adalah efek benih hitam
/// berwarna ungu; keduanya dimatikan.
class _DawnFogPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double t, sec;
  final Color warm;
  const _DawnFogPainter({
    required this.shader,
    required this.t,
    required this.sec,
    required this.warm,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // Kabut malam menipis menjelang matahari naik; bulir muncul setelahnya.
    final fog = 0.55 * _seg(t, 0.0, 0.12) * (1 - _seg(t, 0.30, 0.66));
    final motes = 0.9 * _seg(t, 0.5, 0.7);
    final fogCol = Color.lerp(
        const Color(0xFF9AA8CC), warm, 0.45 * _seg(t, 0.3, 0.6))!;
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, sec)
      ..setFloat(3, t.clamp(0.0, 1.0).toDouble())
      ..setFloat(4, fog)
      ..setFloat(5, 0) // uRays
      ..setFloat(6, motes)
      ..setFloat(7, 0.45) // uLightX: sejajar dengan matahari
      ..setFloat(8, -1) // uShock: mati
      ..setFloat(9, 1) // uIntro
      ..setFloat(10, 0) // uPulse: mati
      ..setFloat(11, 0); // uDark
    _setRgb(shader, 12, fogCol);
    _setRgb(shader, 15, warm);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _DawnFogPainter old) =>
      old.t != t || old.sec != sec;
}

/// Berkas cahaya volumetrik dari matahari yang naik (shaders/divine.frag,
/// mode 0, dilukis aditif). Pusatnya mengikuti piringan matahari di
/// [_SkyPainter]. Setelah lanskap muncul, cahaya meredup supaya tidak
/// bertabrakan dengan matahari pada gambar latar.
class _SunRaysPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double t, sec, reveal;
  final Color warm;
  const _SunRaysPainter({
    required this.shader,
    required this.t,
    required this.sec,
    required this.reveal,
    required this.warm,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final sunT = Curves.easeOutCubic.transform(_seg(t, 0.15, 0.62));
    final env = 0.9 * sunT * (1 - 0.65 * reveal);
    if (env <= 0.01) return;
    final c = Offset(size.width * 0.45, size.height * (0.98 - 0.52 * sunT));
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, sec)
      ..setFloat(3, 0) // uMode 0 = berkas cahaya
      ..setFloat(4, env)
      ..setFloat(5, c.dx)
      ..setFloat(6, c.dy)
      ..setFloat(7, 0);
    _setRgb(shader, 8, Color.lerp(warm, Colors.white, 0.35)!);
    _setRgb(shader, 11, warm);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = shader
        ..blendMode = BlendMode.plus,
    );
  }

  @override
  bool shouldRepaint(covariant _SunRaysPainter old) =>
      old.t != t || old.sec != sec || old.reveal != reveal;
}