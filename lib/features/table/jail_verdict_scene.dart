import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/ornate.dart';

double _seg(double v, double a, double b) =>
    ((v - a) / (b - a)).clamp(0.0, 1.0).toDouble();

double _smooth(double x) => x * x * (3 - 2 * x);

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Adegan vonis: pemain yang dituduh mayoritas (atau terkena kartu kurungan)
/// dikurung sampai musyawarah berikutnya.
///
/// Aset (assets/bentang/): `tertunjuk` (tangan-tangan menunjuk, PNG
/// transparan) dan `keterasingan` (ladang orang-orangan sawah).
///
///  0.00-0.05  fade dari hitam; ladang keterasingan masih tertutup gelap
///  0.05-0.26  tangan-tangan menyempit dari jauh dan menunjuk ke tengah;
///             potret si tertuduh muncul dengan pendar merah
///  0.26       tangan "menghantam" (getar, haptic ganda), nama muncul
///  0.44-0.54  tangan mundur dan menghilang
///  0.46-0.58  enam jeruji besi jatuh satu per satu (memantul) ke potret
///  0.58       gembok menghantam, kilatan merah, cincin kejut, getar kuat;
///             potret memudar jadi abu-abu; tulisan DIKURUNG
///  0.62-0.84  kegelapan tersingkap menampakkan ladang keterasingan; potret
///             mengecil dan bergeser sendirian ke sudut; kabut dan abu
///  0.93-1.00  memudar ke hitam
///
/// Ketuk untuk melewati. [isMe] mengubah kata ganti menjadi "Kamu".
class JailVerdictScene extends StatefulWidget {
  final String name;
  final String? card; // id kartu karakter (protagonistPath)
  final bool isMe;
  final VoidCallback onDone;

  const JailVerdictScene({
    super.key,
    required this.name,
    required this.card,
    required this.onDone,
    this.isMe = false,
  });

  @override
  State<JailVerdictScene> createState() => _JailVerdictSceneState();
}

class _JailVerdictSceneState extends State<JailVerdictScene>
    with SingleTickerProviderStateMixin {
  static const _totalMs = 6600;
  static const _night = Color(0xFF05080F);

  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: _totalMs));
  final Set<int> _fired = {};
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onTick);
    _c.forward().whenComplete(_finish);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    widget.onDone();
  }

  void _onTick() {
    final t = _c.value;
    if (t >= 0.10 && _fired.add(0)) HapticFeedback.lightImpact();
    if (t >= 0.26 && _fired.add(1)) {
      HapticFeedback.heavyImpact();
      Future.delayed(
          const Duration(milliseconds: 110), HapticFeedback.heavyImpact);
    }
    if (t >= 0.50 && _fired.add(2)) HapticFeedback.mediumImpact();
    if (t >= 0.58 && _fired.add(3)) {
      HapticFeedback.heavyImpact();
      Future.delayed(
          const Duration(milliseconds: 140), HapticFeedback.heavyImpact);
    }
    if (t >= 0.66 && _fired.add(4)) HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: Material(
        color: _night,
        child: LayoutBuilder(builder: (context, box) {
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) =>
                _scene(context, box.maxWidth, box.maxHeight),
          );
        }),
      ),
    );
  }

  Widget _scene(BuildContext context, double w, double h) {
    final t = _c.value;
    final sec = t * _totalMs / 1000;
    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).padding.bottom;

    double pulse(double at, double len) =>
        t < at ? 0.0 : math.exp(-(t - at) / len * 5);

    // Getar saat tangan menghantam, jeruji jatuh, dan gembok mengunci.
    final sh = 5 * pulse(0.26, 0.05) +
        6 * pulse(0.50, 0.05) +
        9 * pulse(0.58, 0.06);
    final shake = Offset(math.sin(sec * 80) * sh, math.cos(sec * 67) * sh * 0.7);

    // Ukuran.
    final handsW = math.min(w * 1.25, h * 1.5);
    final handsH = handsW / 1.5;
    final ph = handsH * 0.5;
    final pw = ph * 3 / 4;

    // Latar keterasingan.
    final scrimA = _lerp(0.9, 0.2, _smooth(_seg(t, 0.62, 0.84)));

    // Tangan.
    final hIn = _smooth(_seg(t, 0.05, 0.16));
    final hMove = Curves.easeOutCubic.transform(_seg(t, 0.05, 0.26));
    final recoil = _smooth(_seg(t, 0.44, 0.54));
    final handScale = _lerp(1.7, 1.0, hMove) *
        (1 + 0.25 * recoil) *
        (1 - 0.04 * pulse(0.26, 0.04));
    final handOpacity = hIn * (1 - recoil);
    final tremble = math.sin(sec * 40) *
        0.004 *
        (_seg(t, 0.26, 0.34) * (1 - _seg(t, 0.40, 0.44)));

    // Potret.
    final pIn = _seg(t, 0.10, 0.24);
    final pScaleIn = _lerp(0.8, 1.0, Curves.easeOutBack.transform(pIn));
    final move = _smooth(_seg(t, 0.64, 0.84));
    final groupScale = pScaleIn * _lerp(1.0, 0.58, move);
    final groupOffset = Offset(_lerp(0, -w * 0.20, move), _lerp(0, h * 0.16, move));
    final sat = _lerp(1.0, 0.25, _smooth(_seg(t, 0.50, 0.60)));

    // Pendar merah di belakang potret.
    final glowA = 0.38 *
        _smooth(_seg(t, 0.06, 0.22)) *
        (1 - _smooth(_seg(t, 0.56, 0.70))) *
        (0.8 + 0.2 * math.sin(sec * 5));

    final lockE = Curves.easeOutBack.transform(_seg(t, 0.56, 0.64));
    final lockOn = _seg(t, 0.56, 0.58);

    final redFlash = 0.40 * pulse(0.58, 0.05);
    final whiteFlash = 0.16 * pulse(0.26, 0.04);

    final fadeIn = 1 - _smooth(_seg(t, 0.0, 0.04));
    final fadeOut = _smooth(_seg(t, 0.93, 1.0));

    final who = widget.isMe ? 'Kamu' : widget.name;
    final cardPath =
    widget.card == null ? null : protagonistPath(widget.card!);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Ladang keterasingan (Ken Burns), awalnya tertutup gelap.
        Transform.scale(
          scale: 1.08 + 0.12 * t,
          alignment: const Alignment(-0.3, 0.4),
          child: GameImage(path: sceneryPath('keterasingan'), cacheWidth: 1600),
        ),
        ColoredBox(color: _night.withValues(alpha: scrimA)),

        // Kabut dan abu (setelah jeruji).
        IgnorePointer(
          child: CustomPaint(
            painter: _FogPainter(
                sec: sec, env: _smooth(_seg(t, 0.60, 0.85)) * 0.5),
            size: Size.infinite,
          ),
        ),

        // Pendar merah.
        if (glowA > 0.01)
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.05),
                  radius: 0.85,
                  colors: [
                    EmbunColors.blood.withValues(alpha: glowA),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

        // Isi yang ikut bergetar.
        Transform.translate(
          offset: shake,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Tangan.
              if (handOpacity > 0.01)
                Align(
                  alignment: const Alignment(0, -0.05),
                  child: Opacity(
                    opacity: handOpacity,
                    child: Transform.rotate(
                      angle: tremble,
                      child: Transform.scale(
                        scale: handScale,
                        child: SizedBox(
                          width: handsW,
                          height: handsH,
                          child: GameImage(
                            path: sceneryPath('tertunjuk'),
                            fit: BoxFit.contain,
                            cacheWidth: 1536,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Potret + jeruji + gembok.
              Align(
                alignment: const Alignment(0, -0.05),
                child: Transform.translate(
                  offset: groupOffset,
                  child: Transform.scale(
                    scale: groupScale,
                    child: Opacity(
                      opacity: _smooth(pIn),
                      child: SizedBox(
                        width: pw,
                        height: ph,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            _portrait(cardPath, pw, ph, sat),
                            _bars(t, pw, ph),
                            if (t >= 0.56)
                              IgnorePointer(
                                child: CustomPaint(
                                  painter: _RingPainter(
                                    p: _seg(t, 0.58, 0.72),
                                    r0: pw * 0.4,
                                    r1: pw * 1.7,
                                  ),
                                  size: Size(pw, ph),
                                ),
                              ),
                            Opacity(
                              opacity: lockOn,
                              child: Transform.scale(
                                scale: _lerp(2.6, 1.0, lockE),
                                child: GameIcon('lock', size: pw * 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Vinyet.
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.0,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.75),
                ],
                stops: const [0.5, 1.0],
              ),
            ),
          ),
        ),

        // Kilatan.
        if (redFlash > 0.01)
          IgnorePointer(
            child: ColoredBox(
                color: EmbunColors.blood.withValues(alpha: redFlash)),
          ),
        if (whiteFlash > 0.01)
          IgnorePointer(
            child: ColoredBox(
                color: Colors.white.withValues(alpha: whiteFlash)),
          ),

        // Teks atas: "SUARA TELAH BULAT" lalu "DIKURUNG".
        Positioned(
          left: 20,
          right: 20,
          top: topPad + 26,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Opacity(
                opacity: _smooth(_seg(t, 0.06, 0.14)) *
                    (1 - _smooth(_seg(t, 0.52, 0.58))),
                child: const Text(
                  'SUARA TELAH BULAT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 6,
                    fontWeight: FontWeight.bold,
                    color: EmbunColors.blood,
                  ),
                ),
              ),
              Opacity(
                opacity: _smooth(_seg(t, 0.58, 0.64)),
                child: Transform.scale(
                  scale: _lerp(1.8, 1.0,
                      Curves.easeOutCubic.transform(_seg(t, 0.58, 0.66))),
                  child: Text(
                    'DIKURUNG',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      letterSpacing: 9,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFFFE3DC),
                      shadows: [
                        Shadow(
                            color: EmbunColors.blood.withValues(alpha: 0.9),
                            blurRadius: 22),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Nama + keterangan.
        Positioned(
          left: 20,
          right: 20,
          bottom: botPad + 34,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: _smooth(_seg(t, 0.24, 0.32)),
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - _smooth(_seg(t, 0.24, 0.32)))),
                  child: Text(
                    who,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: EmbunColors.cream,
                      shadows: [
                        Shadow(
                            color: EmbunColors.blood.withValues(alpha: 0.8),
                            blurRadius: 18),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Stack(
                alignment: Alignment.topCenter,
                children: [
                  Opacity(
                    opacity: _smooth(_seg(t, 0.30, 0.38)) *
                        (1 - _smooth(_seg(t, 0.56, 0.62))),
                    child: const Text(
                      'dituduh oleh seisi desa',
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ),
                  Opacity(
                    opacity: _smooth(_seg(t, 0.68, 0.76)),
                    child: const Text(
                      'dikurung sampai musyawarah berikutnya',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Fade masuk / keluar.
        if (fadeIn > 0)
          IgnorePointer(
              child: ColoredBox(color: Colors.black.withValues(alpha: fadeIn))),
        if (fadeOut > 0)
          IgnorePointer(
              child: ColoredBox(color: _night.withValues(alpha: fadeOut))),
      ],
    );
  }

  Widget _portrait(String? path, double pw, double ph, double sat) {
    final inv = 1 - sat;
    const r = 0.2126, g = 0.7152, b = 0.0722;
    final filter = ColorFilter.matrix(<double>[
      inv * r + sat, inv * g, inv * b, 0, 0, //
      inv * r, inv * g + sat, inv * b, 0, 0, //
      inv * r, inv * g, inv * b + sat, 0, 0, //
      0, 0, 0, 1, 0,
    ]);
    return Container(
      width: pw,
      height: ph,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: EmbunColors.blood, width: 2),
        boxShadow: [
          BoxShadow(
              color: EmbunColors.blood.withValues(alpha: 0.55),
              blurRadius: 24),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ColorFiltered(
          colorFilter: filter,
          child: path == null
              ? const ColoredBox(
            color: Color(0xFF1A1218),
            child: Center(child: GameIcon('character', size: 48)),
          )
              : GameImage(path: path, cacheWidth: 600),
        ),
      ),
    );
  }

  /// Enam jeruji besi jatuh dari atas bergiliran dan memantul.
  Widget _bars(double t, double pw, double ph) {
    const n = 6;
    final cross = _smooth(_seg(t, 0.53, 0.58));
    Widget bar(double dy, double x) => Positioned(
      left: x - 4,
      top: dy,
      width: 8,
      height: ph,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1E24), Color(0xFF9A9AA6), Color(0xFF1E1E24)],
          ),
          boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 4)],
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: pw,
        height: ph,
        child: Stack(
          children: [
            for (var i = 0; i < n; i++)
              if (t >= 0.46 + i * 0.012)
                bar(
                  -ph *
                      (1 -
                          Curves.bounceOut.transform(_seg(
                              t, 0.46 + i * 0.012, 0.53 + i * 0.012))),
                  pw * (i + 0.5) / n,
                ),
            if (cross > 0) ...[
              for (final y in [0.18, 0.82])
                Positioned(
                  left: 0,
                  right: 0,
                  top: ph * y - 3.5,
                  height: 7,
                  child: Opacity(
                    opacity: cross,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF9A9AA6),
                            Color(0xFF2A2A30),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _RingPainter extends CustomPainter {
  final double p;
  final double r0, r1;
  const _RingPainter({required this.p, required this.r0, required this.r1});

  @override
  void paint(Canvas canvas, Size size) {
    if (p <= 0 || p >= 1) return;
    final e = Curves.easeOutCubic.transform(p);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * (1 - p) + 1
      ..color = EmbunColors.blood.withValues(alpha: 0.8 * (1 - p));
    canvas.drawCircle(size.center(Offset.zero), _lerp(r0, r1, e), paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.p != p;
}

/// Pita kabut tipis yang bergeser pelan + abu yang jatuh miring.
class _FogPainter extends CustomPainter {
  final double sec;
  final double env;
  const _FogPainter({required this.sec, required this.env});

  @override
  void paint(Canvas canvas, Size size) {
    if (env <= 0.01) return;
    final w = size.width, h = size.height;
    for (var i = 0; i < 3; i++) {
      final bandW = w * 2.4;
      final x = -w * 0.7 + math.sin(sec * (0.25 + i * 0.07) + i) * w * 0.35;
      final y = h * (0.52 + i * 0.13);
      final rect = Rect.fromLTWH(x, y - h * 0.09, bandW, h * 0.18);
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFFC9C2D6).withValues(alpha: 0.16 * env),
            Colors.transparent,
          ],
        ).createShader(rect);
      canvas.drawRect(rect, paint);
    }
    final ash = Paint();
    for (var i = 0; i < 38; i++) {
      final a = (i * 0.6180339) % 1.0;
      final b = (i * 0.7548776) % 1.0;
      final f = (sec * (0.03 + 0.05 * b) + a) % 1.0;
      final x = w * ((a + 0.2 * math.sin(sec * 0.6 + i)) % 1.0) + f * w * 0.08;
      final y = h * f;
      final al = (env * math.sin(f * math.pi)).clamp(0.0, 1.0).toDouble();
      ash.color = const Color(0xFFB9A89A).withValues(alpha: al * 0.7);
      canvas.drawCircle(Offset(x, y), 1.2 + 1.6 * b, ash);
    }
  }

  @override
  bool shouldRepaint(covariant _FogPainter old) => true;
}