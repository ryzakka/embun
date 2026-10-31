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

double _rnd(int i, int k) {
  final v = math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
  return v - v.floorToDouble();
}

class _Fx {
  final Color main, soft, deep;
  const _Fx(this.main, this.soft, this.deep);
}

const _wargaFx = _Fx(Color(0xFF7FE0A0), Color(0xFFFFE9A0), Color(0xFF07130F));
const _antagFx = _Fx(Color(0xFFB07CE8), Color(0xFFE2C8FF), Color(0xFF0A0714));
const _smokeGrey = Color(0xFF7C7391);
const _neutralMist = Color(0xFF8E9A96);

/// Pengungkapan peran di awal permainan.
///
/// Urutan (identik untuk kedua peran sampai kartu terbuka, supaya tidak ada
/// yang bocor lewat bunyi, getar, atau warna sebelum waktunya):
///
///  1. MUNCUL (otomatis, ~3 dtk): kabut menyelimuti layar, setitik embun
///     berdenyut dua kali, lalu mekar menjadi punggung kartu yang turun
///     melayang.
///  2. TAHAN: pemain menahan kartu. Cincin emas terisi, kartu bergetar makin
///     kuat, percik cahaya berputar masuk, getar haptic menanjak. Dilepas
///     sebelum penuh = cincin surut.
///  3. TERUNGKAP (~2,8 dtk): kilatan, kartu terbalik 3D, cincin kejut.
///     * Warga Desa: berkas cahaya emas-hijau, daun berhamburan, kunang-kunang.
///     * Si Terbisik: layar tersentak, kartu terbelah bayangan merah-ungu
///       (glitch), asap ungu kelam mengepul, vinyet berdenyut, getar ganda.
///  4. Setelah itu kartu tetap terbuka; ketuk kartu untuk menyembunyikan atau
///     melihatnya lagi (jaga-jaga ada yang mengintip). Tombol lanjut muncul.
class RoleReveal extends StatefulWidget {
  /// 'antagonis' atau lainnya (warga). null = belum dimuat dari server.
  final String? role;

  /// Gambar muka kartu pemain (sudah dipilih sesuai peran).
  final String? cardPath;
  final VoidCallback onContinue;

  const RoleReveal({
    super.key,
    required this.role,
    required this.cardPath,
    required this.onContinue,
  });

  @override
  State<RoleReveal> createState() => _RoleRevealState();
}

class _RoleRevealState extends State<RoleReveal> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3000));
  late final AnimationController _charge = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));
  late final AnimationController _burst = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2800));
  late final AnimationController _face = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800));
  late final AnimationController _loop = AnimationController(
      vsync: this, duration: const Duration(seconds: 600))
    ..repeat();

  final Set<int> _fired = {};
  bool _holding = false;
  bool _revealedOnce = false;
  bool _pressActive = false;
  bool _ignoreNextUp = false;

  bool get _antag => widget.role == 'antagonis';
  bool get _ready => widget.role != null && _intro.value >= 0.72;
  _Fx get _fx => _antag ? _antagFx : _wargaFx;
  double get _time => _loop.value * 600;

  @override
  void initState() {
    super.initState();
    _intro.addListener(_onIntroTick);
    _charge.addListener(_onChargeTick);
    _charge.addStatusListener((s) {
      if (s == AnimationStatus.completed) _trigger();
    });
    _intro.forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    _charge.dispose();
    _burst.dispose();
    _face.dispose();
    _loop.dispose();
    super.dispose();
  }

  void _onIntroTick() {
    final t = _intro.value;
    if (t >= 0.20 && _fired.add(0)) HapticFeedback.lightImpact();
    if (t >= 0.38 && _fired.add(1)) HapticFeedback.lightImpact();
    if (t >= 0.52 && _fired.add(2)) HapticFeedback.mediumImpact();
    if (mounted && t >= 0.72 && _fired.add(3)) setState(() {});
  }

  void _onChargeTick() {
    if (!_holding) return;
    final c = _charge.value;
    if (c >= 0.25 && _fired.add(10)) HapticFeedback.selectionClick();
    if (c >= 0.50 && _fired.add(11)) HapticFeedback.selectionClick();
    if (c >= 0.75 && _fired.add(12)) HapticFeedback.lightImpact();
    if (c >= 0.92 && _fired.add(13)) HapticFeedback.mediumImpact();
  }

  void _trigger() {
    if (_revealedOnce || !_holding) return;
    _revealedOnce = true;
    _holding = false;
    _ignoreNextUp = _pressActive;
    HapticFeedback.heavyImpact();
    if (_antag) {
      Future.delayed(const Duration(milliseconds: 150), HapticFeedback.heavyImpact);
      Future.delayed(const Duration(milliseconds: 420), HapticFeedback.mediumImpact);
    } else {
      Future.delayed(const Duration(milliseconds: 220), HapticFeedback.mediumImpact);
    }
    _burst.forward(from: 0);
    _face.duration = const Duration(milliseconds: 800);
    Future.delayed(const Duration(milliseconds: 160), () {
      if (mounted) _face.forward(from: 0);
    });
    setState(() {});
  }

  void _down() {
    _pressActive = true;
    if (_revealedOnce || !_ready) return;
    _holding = true;
    _fired.removeWhere((k) => k >= 10);
    _charge.forward();
  }

  void _up() {
    _pressActive = false;
    if (_revealedOnce) {
      if (_ignoreNextUp) {
        _ignoreNextUp = false;
        return;
      }
      _toggle();
      return;
    }
    _release();
  }

  void _cancel() {
    _pressActive = false;
    if (!_revealedOnce) _release();
  }

  void _release() {
    if (!_holding) return;
    _holding = false;
    _charge.reverse();
  }

  void _toggle() {
    if (_burst.value < 0.7) return;
    _face.duration = const Duration(milliseconds: 450);
    HapticFeedback.selectionClick();
    if (_face.value > 0.5) {
      _face.reverse();
    } else {
      _face.forward();
    }
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation:
      Listenable.merge([_intro, _charge, _burst, _face, _loop]),
      builder: (context, _) => _scene(context),
    );
  }

  Widget _scene(BuildContext context) {
    final mq = MediaQuery.of(context);
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth, h = c.maxHeight;
      final land = w > h * 1.2;
      final aspect = cardAspectFor(widget.cardPath);
      var cardH = (land ? h * 0.72 : h * 0.46).clamp(170.0, 420.0).toDouble();
      var cardW = cardH / aspect;
      final maxW = land ? w * 0.4 : w * 0.66;
      if (cardW > maxW) {
        cardW = maxW;
        cardH = cardW * aspect;
      }
      final center = land ? Offset(w * 0.29, h * 0.5) : Offset(w / 2, h * 0.38);

      final it = _intro.value;
      final bt = _burst.value;
      final ch = _charge.value;
      final mix = _smooth(_seg(bt, 0, 0.25));
      final bEnv = _smooth(_seg(bt, 0.05, 0.3)) * (1 - 0.3 * _seg(bt, 0.7, 1));
      final deep = Color.lerp(_wargaFx.deep, _fx.deep, mix)!;

      final dim = (0.30 +
          0.35 * _smooth(_seg(it, 0, 0.6)) +
          0.10 * ch +
          (_antag ? 0.22 * bEnv : -0.18 * bEnv))
          .clamp(0.0, 0.95)
          .toDouble();

      // Entakan layar saat terungkap (Si Terbisik lebih keras).
      var shake = Offset.zero;
      if (bt > 0.04 && bt < 0.32) {
        final q = (bt * 60).floor();
        final fall = 1 - _seg(bt, 0.04, 0.32);
        final amp = (_antag ? 14.0 : 6.0) * fall;
        shake = Offset((_rnd(q, 11) - 0.5) * amp, (_rnd(q, 12) - 0.5) * amp);
      }

      final pr = _Pr(
        fx: _fx,
        antag: _antag,
        center: center,
        cw: cardW,
        ch: cardH,
        intro: it,
        charge: ch,
        burst: bt,
        time: _time,
        mix: mix,
        deep: deep,
      );

      return Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: deep.withValues(alpha: dim)),
          Transform.translate(
            offset: shake,
            child: Stack(
              fit: StackFit.expand,
              children: [
                IgnorePointer(
                  child: CustomPaint(
                      painter: _BackPainter(pr), size: Size.infinite),
                ),
                Positioned(
                  left: center.dx - cardW / 2,
                  top: center.dy - cardH / 2,
                  width: cardW,
                  height: cardH,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => _down(),
                    onTapUp: (_) => _up(),
                    onTapCancel: _cancel,
                    child: _card(cardW, cardH),
                  ),
                ),
                IgnorePointer(
                  child: CustomPaint(
                      painter: _FrontPainter(pr), size: Size.infinite),
                ),
              ],
            ),
          ),
          if (land)
            Positioned(
              left: w * 0.52,
              right: 24,
              top: 0,
              bottom: 0,
              child: Center(child: _textBlock()),
            )
          else
            Positioned(
              left: 20,
              right: 20,
              bottom: mq.padding.bottom + 18,
              child: _textBlock(),
            ),
        ],
      );
    });
  }

  Widget _back(double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14)],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      // Selalu punggung protagonis: punggung gelap membocorkan peran.
      child: GameImage(path: cardBackPath(), cacheWidth: 700),
    ),
  );

  Widget _card(double cw, double chh) {
    final it = _intro.value;
    final bt = _burst.value;
    final c = _charge.value;
    final time = _time;
    final charging = bt <= 0;

    final entry = Curves.easeOutBack.transform(_seg(it, 0.30, 0.70));
    final opacity = _smooth(_seg(it, 0.28, 0.42));
    final t = Curves.easeInOutCubic.transform(_face.value);
    final ang = t * math.pi;
    final peak = math.sin(t * math.pi);

    final shakeX = charging ? math.sin(time * 70) * c * c * 4 : 0.0;
    final shakeY = charging ? math.cos(time * 83) * c * c * 3 : 0.0;
    final scale = _lerp(0.25, 1.0, entry) *
        (1 + 0.05 * (charging ? c : 0.0)) *
        (1 + 0.14 * math.sin(math.pi * _seg(bt, 0.04, 0.34))) *
        (1 + 0.06 * peak);
    final dy = (1 - entry) * -70 +
        (it >= 1 ? math.sin(time * 1.5) * 5 : 0.0) -
        peak * 16 +
        shakeY;

    Widget core() {
      final showFront = ang > math.pi / 2;
      final faceW = showFront
          ? Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(math.pi),
        child: CardArt(path: widget.cardPath, width: cw, glow: _fx.main),
      )
          : _back(cw, chh);
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateY(ang),
        child: faceW,
      );
    }

    final layers = <Widget>[];
    // Glitch: dua bayangan berwarna yang menyentak (hanya Si Terbisik).
    if (_antag && bt > 0.05 && bt < 0.34) {
      final q = (bt * 55).floor();
      final g = 1 - _seg(bt, 0.2, 0.34);
      for (var k = 0; k < 2; k++) {
        layers.add(Transform.translate(
          offset: Offset((_rnd(q, k + 1) - 0.5) * 30 * g,
              (_rnd(q, k + 4) - 0.5) * 8 * g),
          child: Opacity(
            opacity: (0.5 * g).clamp(0.0, 1.0).toDouble(),
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                  (k == 0 ? EmbunColors.blood : EmbunColors.mist)
                      .withValues(alpha: 0.75),
                  BlendMode.srcATop),
              child: core(),
            ),
          ),
        ));
      }
    }
    layers.add(core());

    return Transform.translate(
      offset: Offset(shakeX, dy),
      child: Transform.rotate(
        angle: (1 - entry) * -0.25,
        child: Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: layers,
            ),
          ),
        ),
      ),
    );
  }

  Widget _textBlock() {
    final it = _intro.value;
    final bt = _burst.value;
    final face = _face.value;
    final fx = _fx;

    final hintIn = _smooth(_seg(it, 0.72, 0.95));
    final String hintText;
    if (_revealedOnce) {
      hintText = 'Ketuk kartu untuk melihatnya lagi';
    } else if (widget.role == null) {
      hintText = 'Menunggu nasib dibagikan...';
    } else if (_charge.value > 0.05) {
      hintText = 'Terus tahan...';
    } else {
      hintText = 'Tahan kartu untuk menyingkap perananmu';
    }
    final hintOpacity = _revealedOnce
        ? _smooth(_seg(bt, 0.85, 1.0)) * (1 - _smooth(_seg(face, 0.0, 0.6)))
        : hintIn;

    final q = (bt * 40).floor();
    final flicker = (_antag && bt < 0.55)
        ? (_rnd(q, 9) > 0.3 ? 1.0 : 0.25)
        : 1.0;
    final titleOpacity = (_smooth(_seg(bt, 0.30, 0.50)) *
        _smooth(_seg(face, 0.5, 1.0)) *
        flicker)
        .clamp(0.0, 1.0)
        .toDouble();
    final spacing = _lerp(10, 0.8, Curves.easeOut.transform(_seg(bt, 0.32, 0.75)));
    final descOpacity = _smooth(_seg(bt, 0.46, 0.68)) * _smooth(_seg(face, 0.5, 1.0));
    final btnOpacity = _smooth(_seg(bt, 0.72, 0.92));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 108,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Opacity(
                opacity: hintOpacity.clamp(0.0, 1.0).toDouble(),
                child: Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_revealedOnce) ...[
                        const GameIcon('touch', size: 24),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(hintText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70)),
                      ),
                    ],
                  ),
                ),
              ),
              Opacity(
                opacity: titleOpacity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GameIcon(_antag ? 'bulirhitam' : 'helaidaun', size: 36),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _antag ? 'Si Terbisik' : 'Warga Desa',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: spacing,
                              color: fx.main,
                              shadows: [
                                Shadow(
                                    color: fx.main.withValues(alpha: 0.7),
                                    blurRadius: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Opacity(
                      opacity: descOpacity.clamp(0.0, 1.0).toDouble(),
                      child: Text(
                        _antag
                            ? 'Kabut menitipkan bulir hitam padamu. Hancurkan Hayu tanpa ketahuan.'
                            : 'Selamatkan Hayu. Waspadai satu pengkhianat di antara kalian.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Opacity(
          opacity: btnOpacity,
          child: IgnorePointer(
            ignoring: btnOpacity < 0.9,
            child: EmbunButton(
              label: 'Aku sudah ingat',
              icon: 'centang',
              onPressed: widget.onContinue,
            ),
          ),
        ),
      ],
    );
  }
}

// ====================================================================
// Pelukis efek
// ====================================================================

class _Pr {
  final _Fx fx;
  final bool antag;
  final Offset center;
  final double cw, ch;
  final double intro, charge, burst, time, mix;
  final Color deep;
  const _Pr({
    required this.fx,
    required this.antag,
    required this.center,
    required this.cw,
    required this.ch,
    required this.intro,
    required this.charge,
    required this.burst,
    required this.time,
    required this.mix,
    required this.deep,
  });

  double get r => math.max(cw, ch);
  double get halfDiag => math.sqrt(cw * cw + ch * ch) / 2;
  double get bEnv =>
      _smooth(_seg(burst, 0.05, 0.3)) * (1 - 0.3 * _seg(burst, 0.7, 1));
  // Emas sebelum terungkap, lalu berubah ke warna peran.
  Color get col => Color.lerp(EmbunColors.gold, fx.main, mix)!;
}

/// Lapisan di belakang kartu: kabut, embun, aura, cincin pengisian, berkas
/// cahaya (warga) atau asap kelam (Si Terbisik).
class _BackPainter extends CustomPainter {
  final _Pr p;
  const _BackPainter(this.p);

  @override
  void paint(Canvas canvas, Size size) {
    _mist(canvas, size);
    _orb(canvas);
    _aura(canvas);
    _charging(canvas);
    if (p.burst > 0) {
      if (p.antag) {
        _smoke(canvas);
      } else {
        _rays(canvas, size);
      }
    }
  }

  void _mist(Canvas canvas, Size size) {
    final mi = _smooth(_seg(p.intro, 0, 0.45));
    final pull = math.max(_smooth(_seg(p.intro, 0.3, 0.7)), p.charge);
    final paint = Paint();
    for (var i = 0; i < 16; i++) {
      final ang = _rnd(i, 1) * 2 * math.pi + p.time * 0.06 * (i.isEven ? 1 : -1);
      final dist =
          size.longestSide * (0.18 + 0.42 * _rnd(i, 2)) * (1 - 0.35 * pull);
      final pos = p.center +
          Offset(math.cos(ang) * dist, math.sin(ang) * dist * 0.75);
      final r = size.shortestSide * (0.28 + 0.32 * _rnd(i, 3));
      final a = ((0.07 + 0.07 * _rnd(i, 4)) *
          mi *
          (1 + (p.antag ? 1.4 : 0.3) * p.bEnv))
          .clamp(0.0, 1.0)
          .toDouble();
      final base = i % 3 == 0 ? _neutralMist : p.col;
      paint.shader = RadialGradient(
        colors: [base.withValues(alpha: a), base.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: pos, radius: r));
      canvas.drawCircle(pos, r, paint);
    }
  }

  /// Titik embun yang berdenyut dua kali sebelum menjadi kartu.
  void _orb(Canvas canvas) {
    final it = p.intro;
    final orbIn = _smooth(_seg(it, 0.05, 0.25));
    final orbOut = 1 - _smooth(_seg(it, 0.5, 0.7));
    if (orbIn <= 0 || orbOut <= 0) return;
    double beat(double at) =>
        it < at ? 0.0 : math.exp(-(it - at) / 0.05 * 4);
    final b = math.min(1.0, beat(0.20) + beat(0.38) + 0.8 * beat(0.52));
    final orbR = 10 + 8 * b + 40 * _smooth(_seg(it, 0.45, 0.6));
    final a = (0.9 * orbIn * orbOut).clamp(0.0, 1.0).toDouble();
    final paint = Paint()
      ..shader = RadialGradient(colors: [
        Colors.white.withValues(alpha: a),
        EmbunColors.gold.withValues(alpha: a * 0.55),
        EmbunColors.gold.withValues(alpha: 0),
      ], stops: const [
        0.0,
        0.35,
        1.0
      ]).createShader(Rect.fromCircle(center: p.center, radius: orbR * 2.5));
    canvas.drawCircle(p.center, orbR * 2.5, paint);
  }

  void _aura(Canvas canvas) {
    final ai = _smooth(_seg(p.intro, 0.45, 0.7));
    if (ai <= 0) return;
    final pulse = p.burst > 0 ? math.sin(math.pi * _seg(p.burst, 0, 0.5)) : 0.0;
    final a = ((0.16 + 0.26 * p.charge + 0.55 * pulse + 0.25 * p.bEnv) * ai)
        .clamp(0.0, 1.0)
        .toDouble();
    final ar = p.r * (0.85 + 0.35 * p.charge + 0.5 * pulse);
    final paint = Paint()
      ..shader = RadialGradient(colors: [
        p.col.withValues(alpha: a),
        p.col.withValues(alpha: 0),
      ]).createShader(Rect.fromCircle(center: p.center, radius: ar * 1.4));
    canvas.drawCircle(p.center, ar * 1.4, paint);
  }

  /// Cincin yang terisi selama ditahan dan percik yang berputar masuk.
  void _charging(Canvas canvas) {
    final fade = 1 - _seg(p.burst, 0, 0.15);
    if (p.charge < 0.02 || fade <= 0) return;
    final radius = p.halfDiag + 14;
    final rect = Rect.fromCircle(center: p.center, radius: radius);
    canvas.drawCircle(
      p.center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = EmbunColors.goldDim.withValues(alpha: 0.35 * fade),
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * p.charge,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3)
        ..color = EmbunColors.gold.withValues(alpha: 0.95 * fade),
    );
    final sp = Paint();
    for (var i = 0; i < 14; i++) {
      final u = (p.time * 0.8 + _rnd(i, 1)) % 1.0;
      final ang = _rnd(i, 2) * 2 * math.pi + u * 2.4;
      final rad = radius * (1.25 - 1.0 * u);
      final pos = p.center + Offset.fromDirection(ang, rad);
      final a = (p.charge * math.sin(math.pi * u) * fade)
          .clamp(0.0, 1.0)
          .toDouble();
      sp.color = Colors.white.withValues(alpha: a);
      canvas.drawCircle(pos, 1.6 + 2.0 * _rnd(i, 3), sp);
    }
  }

  void _rays(Canvas canvas, Size size) {
    final env = p.bEnv;
    if (env <= 0) return;
    final len = size.longestSide * 0.9;
    final paint = Paint();
    for (var i = 0; i < 14; i++) {
      final ang = i * 2 * math.pi / 14 + p.time * 0.12;
      final w = 0.07 + 0.05 * _rnd(i, 6);
      final l = len * (0.6 + 0.4 * _rnd(i, 7));
      final path = Path()
        ..moveTo(p.center.dx, p.center.dy)
        ..lineTo(p.center.dx + math.cos(ang - w) * l,
            p.center.dy + math.sin(ang - w) * l)
        ..lineTo(p.center.dx + math.cos(ang + w) * l,
            p.center.dy + math.sin(ang + w) * l)
        ..close();
      paint.shader = RadialGradient(colors: [
        p.fx.soft.withValues(alpha: 0.30 * env),
        p.fx.soft.withValues(alpha: 0),
      ]).createShader(Rect.fromCircle(center: p.center, radius: l));
      canvas.drawPath(path, paint);
    }
  }

  void _smoke(Canvas canvas) {
    final paint = Paint();
    for (var i = 0; i < 22; i++) {
      final st = 0.04 + 0.30 * _rnd(i, 1);
      final u = _seg(p.burst, st, st + 0.62);
      if (u <= 0 || u >= 1) continue;
      final start = p.center +
          Offset((_rnd(i, 2) - 0.5) * p.cw, p.ch * (0.15 + 0.35 * _rnd(i, 3)));
      final pos = start +
          Offset(math.sin(u * 3 + i) * p.cw * 0.25,
              -u * p.ch * (0.7 + 0.9 * _rnd(i, 4)));
      final r = p.cw * (0.18 + 0.34 * u) * (0.7 + 0.7 * _rnd(i, 5));
      final a = math.sin(u * math.pi) * 0.6;
      final col = i % 3 == 0
          ? const Color(0xFF05020A)
          : (i.isEven ? EmbunColors.mist : _smokeGrey);
      paint.shader = RadialGradient(
        colors: [col.withValues(alpha: a), col.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: pos, radius: r));
      canvas.drawCircle(pos, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BackPainter old) => true;
}

/// Lapisan di depan kartu: kilatan, cincin kejut, daun / serpihan bulir hitam,
/// kunang-kunang atau bara, dan vinyet.
class _FrontPainter extends CustomPainter {
  final _Pr p;
  const _FrontPainter(this.p);

  @override
  void paint(Canvas canvas, Size size) {
    _flash(canvas, size);
    _rings(canvas, size);
    _particles(canvas);
    _motes(canvas, size);
    _vignette(canvas, size);
  }

  void _flash(Canvas canvas, Size size) {
    final bt = p.burst;
    if (bt <= 0) return;
    final a = (_seg(bt, 0, 0.04) * (1 - _smooth(_seg(bt, 0.04, 0.22))) *
        (p.antag ? 0.8 : 0.9))
        .clamp(0.0, 1.0)
        .toDouble();
    if (a <= 0) return;
    final c = Color.lerp(Colors.white, p.fx.soft, 0.4)!;
    canvas.drawRect(Offset.zero & size,
        Paint()..color = c.withValues(alpha: a));
  }

  void _rings(Canvas canvas, Size size) {
    if (p.burst <= 0) return;
    const starts = [0.08, 0.16, 0.26];
    final maxR = size.longestSide * 0.6;
    for (final s in starts) {
      final u = _seg(p.burst, s, s + 0.36);
      if (u <= 0 || u >= 1) continue;
      final e = Curves.easeOutCubic.transform(u);
      canvas.drawCircle(
        p.center,
        _lerp(p.ch * 0.3, maxR, e),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * (1 - u) + 1
          ..color = p.fx.main.withValues(alpha: 0.8 * (1 - u)),
      );
    }
  }

  Path _leaf(double s) => Path()
    ..moveTo(0, -s)
    ..quadraticBezierTo(s * 0.8, -s * 0.2, 0, s)
    ..quadraticBezierTo(-s * 0.8, -s * 0.2, 0, -s)
    ..close();

  Path _shard(double s) => Path()
    ..moveTo(0, -s)
    ..lineTo(s * 0.6, 0)
    ..lineTo(0, s)
    ..lineTo(-s * 0.6, 0)
    ..close();

  void _particles(Canvas canvas) {
    final bt = p.burst;
    if (bt <= 0) return;
    final fill = Paint();
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < 26; i++) {
      final st = 0.08 + 0.22 * _rnd(i, 1);
      final u = _seg(bt, st, st + 0.72);
      if (u <= 0 || u >= 1) continue;
      final e = Curves.easeOutCubic.transform(u);
      final ang = _rnd(i, 2) * 2 * math.pi;
      final dist = p.cw * (0.7 + 1.7 * _rnd(i, 3)) * e;
      final pos = p.center +
          Offset.fromDirection(ang, dist) +
          Offset(math.sin(u * 5 + i) * 6, -u * u * p.ch * 0.5);
      final alpha =
      (math.min(1.0, u * 8) * (1 - u)).clamp(0.0, 1.0).toDouble();
      final s = 6 + 9 * _rnd(i, 4);
      final rot = _rnd(i, 5) * 2 * math.pi + u * 6 * (_rnd(i, 6) - 0.5);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(rot);
      if (!p.antag) {
        fill.color = Color.lerp(p.fx.main, EmbunColors.gold, _rnd(i, 7))!
            .withValues(alpha: alpha);
        canvas.drawPath(_leaf(s), fill);
      } else {
        fill.color = const Color(0xFF0B0612).withValues(alpha: alpha);
        edge.color = EmbunColors.mist.withValues(alpha: alpha);
        final path = _shard(s * 0.8);
        canvas.drawPath(path, fill);
        canvas.drawPath(path, edge);
      }
      canvas.restore();
    }
  }

  /// Kunang-kunang emas (warga) atau bara ungu (Si Terbisik) yang terus naik.
  void _motes(Canvas canvas, Size size) {
    final env = _smooth(_seg(p.burst, 0.55, 1.0));
    if (env <= 0) return;
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final c = p.antag ? EmbunColors.mist : p.fx.soft;
    for (var i = 0; i < 16; i++) {
      final u = (p.time * 0.12 + _rnd(i, 1)) % 1.0;
      final x = p.center.dx +
          (_rnd(i, 2) - 0.5) * size.width * 0.9 +
          math.sin(p.time * 0.8 + i) * 10;
      final y = size.height * (1.05 - 1.1 * u);
      final a = (env * math.sin(math.pi * u) * 0.8).clamp(0.0, 1.0).toDouble();
      paint.color = c.withValues(alpha: a);
      canvas.drawCircle(Offset(x, y), 1.5 + 2.2 * _rnd(i, 3), paint);
    }
  }

  void _vignette(Canvas canvas, Size size) {
    final env = p.bEnv;
    var v = 0.25 * _smooth(_seg(p.intro, 0, 0.6)) + 0.12 * env;
    if (p.antag) {
      v += 0.35 * env + 0.10 * env * math.sin(p.time * 2.6);
    }
    v = v.clamp(0.0, 1.0).toDouble();
    if (v <= 0.01) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [Colors.transparent, p.deep.withValues(alpha: v)],
          stops: const [0.5, 1.0],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _FrontPainter old) => true;
}