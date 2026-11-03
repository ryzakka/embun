import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/fx_shaders.dart';
import '../common/ornate.dart';

double _seg(double v, double a, double b) =>
    ((v - a) / (b - a)).clamp(0.0, 1.0).toDouble();

double _smooth(double x) => x * x * (3 - 2 * x);

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _rnd(int i, int k) {
  final v = math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
  return v - v.floorToDouble();
}

/// Mengisi tiga float berurutan (r, g, b) pada shader mulai dari indeks [i].
void _rgb(ui.FragmentShader s, int i, Color c) {
  s
    ..setFloat(i, c.r)
    ..setFloat(i + 1, c.g)
    ..setFloat(i + 2, c.b);
}

class _Fx {
  final Color main, soft, deep;
  const _Fx(this.main, this.soft, this.deep);

  static _Fx lerp(_Fx a, _Fx b, double t) => _Fx(
    Color.lerp(a.main, b.main, t)!,
    Color.lerp(a.soft, b.soft, t)!,
    Color.lerp(a.deep, b.deep, t)!,
  );
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
///     Kedua peran sama persis di tahap ini: yang terbuka adalah kartu BAIK
///     (kartu karakter), dengan berkas cahaya emas-hijau, daun berhamburan,
///     dan kunang-kunang.
///  3a. GERBANG (hanya Si Terbisik): setelah kartu baik terbuka, [twistGate]
///     dijalankan. Induk memakainya untuk memutar peringatan awan gelap dan
///     pilihan wajah gelap. Putar balik baru mulai setelah gerbang selesai.
///  3b. PUTAR BALIK (hanya Si Terbisik, ~2,6 dtk): sesaat kemudian, detak
///     jantung, kartu baik itu menggelap dan bergetar, layar tersentak,
///     kartu retak bercahaya lalu larut terbakar menjadi kartu gelapnya
///     dengan asap ungu kelam, cincin kejut, dan vinyet berdenyut. Teks ikut
///     berganti dari "Warga Desa" menjadi "Si Terbisik", lengkap dengan
///     keterangan wajah samarannya.
///  4. Setelah itu kartu tetap terbuka; ketuk kartu untuk menyembunyikan atau
///     melihatnya lagi (jaga-jaga ada yang mengintip). Tombol lanjut muncul.
///
/// Efek shader (kabut, asap, berkas cahaya, kilau foil, larut kartu) memakai
/// painter lama sebagai cadangan bila shader dimatikan / gagal dimuat.
class RoleReveal extends StatefulWidget {
  /// 'antagonis' atau lainnya (warga). null = belum dimuat dari server.
  final String? role;

  /// Gambar muka kartu pemain menurut peran: kartu karakter untuk warga,
  /// kartu gelap untuk Si Terbisik.
  final String? cardPath;

  /// Kartu baik samaran Si Terbisik (kartu karakter yang dilihat pemain
  /// lain). Dipakai sebagai muka pertama sebelum kartu gelap terungkap;
  /// diabaikan untuk warga.
  final String? disguisePath;

  /// Nama kartu samaran, mis. "Petani Padi".
  final String? disguiseName;
  final VoidCallback onContinue;

  /// Dijalankan (dan ditunggu) setelah kartu baik Si Terbisik terbuka dan
  /// sebelum putar balik dimulai. null = langsung putar balik.
  final Future<void> Function()? twistGate;

  const RoleReveal({
    super.key,
    required this.role,
    required this.cardPath,
    required this.onContinue,
    this.disguisePath,
    this.disguiseName,
    this.twistGate,
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
  late final AnimationController _twist = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600));
  late final AnimationController _loop = AnimationController(
      vsync: this, duration: const Duration(seconds: 600))
    ..repeat();

  final Set<int> _fired = {};
  bool _holding = false;
  bool _revealedOnce = false;
  bool _pressActive = false;
  bool _ignoreNextUp = false;
  bool _twistStarted = false;

  // ---- shader (null bila dimatikan / gagal dimuat -> painter lama) ----
  ui.FragmentShader? _atmo; // kabut + asap
  ui.FragmentShader? _raysFx; // berkas cahaya
  ui.FragmentShader? _foil; // kilau foil di muka kartu
  ui.FragmentShader? _morph; // larut kartu baik -> kartu gelap (Si Terbisik)
  ui.Image? _imgA; // kartu baik samaran
  ui.Image? _imgB; // kartu gelap
  bool _loadingMorph = false;
  final double _seed = math.Random().nextDouble();

  bool get _antag => widget.role == 'antagonis';
  bool get _ready => widget.role != null && _intro.value >= 0.72;

  /// Larut kartu aktif: shader + kedua gambar siap + ada kartu samaran.
  bool get _morphOn =>
      _antag &&
          _morph != null &&
          _imgA != null &&
          _imgB != null &&
          widget.disguisePath != null;

  /// Kemajuan putar balik (0..1); selalu 0 untuk warga.
  double get _tw => _twist.value;

  /// Si Terbisik sudah lewat titik tukar: muka kartu jadi kartu gelap.
  bool get _swapped => _antag && _tw >= 0.36;

  /// Warna efek: warga sepanjang tahap 3; Si Terbisik beralih ke ungu
  /// selama putar balik.
  _Fx get _fx => _antag
      ? _Fx.lerp(_wargaFx, _antagFx, _smooth(_seg(_tw, 0.30, 0.55)))
      : _wargaFx;
  double get _time => _loop.value * 600;

  @override
  void initState() {
    super.initState();
    _intro.addListener(_onIntroTick);
    _charge.addListener(_onChargeTick);
    _charge.addStatusListener((s) {
      if (s == AnimationStatus.completed) _trigger();
    });
    _burst.addStatusListener((s) {
      if (s == AnimationStatus.completed && _antag) _startTwist();
    });
    _twist.addListener(_onTwistTick);
    // Shader yang sama untuk kedua peran (tidak membocorkan apa pun).
    _atmo = FxShaders.make(FxShaders.atmosphere);
    _raysFx = FxShaders.make(FxShaders.divine);
    _foil = FxShaders.make(FxShaders.divine);
    _loadMorph();
    _intro.forward();
  }

  @override
  void didUpdateWidget(RoleReveal old) {
    super.didUpdateWidget(old);
    // Peran / gambar kartu baru tiba dari server.
    _loadMorph();
  }

  @override
  void dispose() {
    _intro.dispose();
    _charge.dispose();
    _burst.dispose();
    _twist.dispose();
    _face.dispose();
    _loop.dispose();
    _atmo?.dispose();
    _raysFx?.dispose();
    _foil?.dispose();
    _morph?.dispose();
    super.dispose();
  }

  /// Hanya Si Terbisik: muat kedua kartu sebagai gambar sampler untuk shader
  /// larut. Selama belum siap, adegan memakai efek glitch lama.
  Future<void> _loadMorph() async {
    if (!_antag || _loadingMorph) return;
    final a = widget.disguisePath;
    final b = widget.cardPath;
    if (a == null || b == null) return;
    if (_imgA != null && _imgB != null) return;
    _morph ??= FxShaders.make(FxShaders.cardMorph);
    if (_morph == null) return;
    _loadingMorph = true;
    final imgs = await Future.wait([FxShaders.image(a), FxShaders.image(b)]);
    _loadingMorph = false;
    if (!mounted) return;
    setState(() {
      _imgA = imgs[0];
      _imgB = imgs[1];
    });
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

  /// Setelah kartu baik terbuka: jalankan gerbang induk (peringatan awan
  /// gelap + pilih wajah gelap) bila ada, jeda sejenak, lalu putar balik.
  void _startTwist() {
    if (_twistStarted) return;
    _twistStarted = true;
    () async {
      final gate = widget.twistGate;
      if (gate != null) await gate();
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 450));
      if (mounted) _twist.forward(from: 0);
    }();
  }

  void _onTwistTick() {
    final t = _twist.value;
    if (t >= 0.02 && _fired.add(20)) HapticFeedback.mediumImpact();
    if (t >= 0.14 && _fired.add(21)) HapticFeedback.mediumImpact();
    if (t >= 0.28 && _fired.add(22)) HapticFeedback.heavyImpact();
    if (t >= 0.36 && _fired.add(23)) {
      HapticFeedback.heavyImpact();
      Future.delayed(
          const Duration(milliseconds: 150), HapticFeedback.heavyImpact);
      Future.delayed(
          const Duration(milliseconds: 420), HapticFeedback.mediumImpact);
    }
  }

  void _trigger() {
    if (_revealedOnce || !_holding) return;
    _revealedOnce = true;
    _holding = false;
    _ignoreNextUp = _pressActive;
    // Sama untuk kedua peran: getar khusus Si Terbisik baru muncul saat
    // putar balik, supaya tidak ada yang bocor lebih awal.
    HapticFeedback.heavyImpact();
    Future.delayed(
        const Duration(milliseconds: 220), HapticFeedback.mediumImpact);
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
    if (_antag && _twist.value < 0.85) return;
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
      Listenable.merge([_intro, _charge, _burst, _twist, _face, _loop]),
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
      final tw = _tw;
      final mix = _smooth(_seg(bt, 0, 0.25));
      final bEnv = _smooth(_seg(bt, 0.05, 0.3)) * (1 - 0.3 * _seg(bt, 0.7, 1));
      final twEnv =
          _smooth(_seg(tw, 0.05, 0.4)) * (1 - 0.3 * _seg(tw, 0.75, 1));
      final twMix = _smooth(_seg(tw, 0.2, 0.5));
      final fx = _fx;
      final deep = Color.lerp(_wargaFx.deep, fx.deep, twMix)!;

      // Terang saat kartu baik terbuka; Si Terbisik kembali menggelap
      // ketika putar balik.
      final dim = (0.30 +
          0.35 * _smooth(_seg(it, 0, 0.6)) +
          0.10 * ch -
          0.18 * bEnv * (1 - twMix) +
          0.22 * twEnv)
          .clamp(0.0, 0.95)
          .toDouble();

      // Entakan layar: ringan saat kartu baik terbuka; Si Terbisik
      // bergetar naik lalu tersentak keras saat putar balik.
      var shake = Offset.zero;
      if (bt > 0.04 && bt < 0.32) {
        final q = (bt * 60).floor();
        final fall = 1 - _seg(bt, 0.04, 0.32);
        final amp = 6.0 * fall;
        shake = Offset((_rnd(q, 11) - 0.5) * amp, (_rnd(q, 12) - 0.5) * amp);
      }
      if (_antag && tw > 0 && tw < 0.62) {
        final q = (tw * 60).floor();
        final ramp = tw < 0.30 ? 3.0 * _seg(tw, 0, 0.30) : 0.0;
        final hit = tw >= 0.30 ? 14.0 * (1 - _seg(tw, 0.30, 0.62)) : 0.0;
        final amp = ramp + hit;
        shake += Offset((_rnd(q, 13) - 0.5) * amp, (_rnd(q, 14) - 0.5) * amp);
      }

      final pr = _Pr(
        fx: fx,
        antag: _antag,
        twist: tw,
        center: center,
        cw: cardW,
        ch: cardH,
        intro: it,
        charge: ch,
        burst: bt,
        time: _time,
        mix: mix,
        deep: deep,
        atmo: _atmo,
        rays: _raysFx,
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

  /// Lapisan shader larut kartu di atas bidang kartu (hanya Si Terbisik,
  /// selama putar balik). Di ujungnya ia menjadi kartu gelap murni, jadi
  /// saat dilepas tidak ada lompatan.
  Widget _morphLayer(double cw, double chh, double tw) {
    return IgnorePointer(
      child: SizedBox(
        width: cw,
        height: chh,
        child: CustomPaint(
          painter: _MorphPainter(
            shader: _morph!,
            a: _imgA!,
            b: _imgB!,
            prog: _seg(tw, 0.0, 0.62),
            time: _time,
            seed: _seed,
            edge: _antagFx.main,
            hot: _antagFx.soft,
          ),
        ),
      ),
    );
  }

  /// Kilau foil yang menyapu muka kartu setelah terbuka. Emas untuk kartu
  /// baik (kedua peran sama), beralih ungu bersama [_fx] saat putar balik.
  Widget? _foilLayer(double cw, double chh) {
    final sh = _foil;
    if (sh == null) return null;
    final tw = _tw;
    var env = _smooth(_seg(_burst.value, 0.55, 0.9)) *
        _smooth(_seg(_face.value, 0.6, 1.0));
    env *= 1 - 0.5 * _smooth(_seg(tw, 0.05, 0.4)) * (1 - _seg(tw, 0.75, 1.0));
    if (env <= 0.01) return null;
    final f = _fx;
    return IgnorePointer(
      child: SizedBox(
        width: cw,
        height: chh,
        child: CustomPaint(
          painter: _FoilPainter(
              shader: sh, time: _time, env: env, soft: f.soft, hue: f.main),
        ),
      ),
    );
  }

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

    final tw = _tw;
    final twTremble = _antag && tw > 0
        ? math.sin(time * 90) *
        3 *
        _seg(tw, 0, 0.34) *
        (1 - _seg(tw, 0.34, 0.5))
        : 0.0;
    final shakeX =
        (charging ? math.sin(time * 70) * c * c * 4 : 0.0) + twTremble;
    final shakeY = charging ? math.cos(time * 83) * c * c * 3 : 0.0;
    final scale = _lerp(0.25, 1.0, entry) *
        (1 + 0.05 * (charging ? c : 0.0)) *
        (1 + 0.14 * math.sin(math.pi * _seg(bt, 0.04, 0.34))) *
        (1 + 0.10 * math.sin(math.pi * _seg(tw, 0.28, 0.55))) *
        (1 + 0.06 * peak);
    final dy = (1 - entry) * -70 +
        (it >= 1 ? math.sin(time * 1.5) * 5 : 0.0) -
        peak * 16 +
        shakeY;

    Widget core() {
      final showFront = ang > math.pi / 2;
      // Si Terbisik: muka pertama adalah kartu baik samarannya; kartu gelap
      // baru muncul di titik tukar putar balik.
      final hasDis = _antag && widget.disguisePath != null;
      final facePath =
      (hasDis && !_swapped) ? widget.disguisePath : widget.cardPath;
      Widget art = CardArt(path: facePath, width: cw, glow: _fx.main);
      if (_antag && tw > 0 && !_swapped && !_morphOn) {
        // Kartu baik menggelap sebelum retak (cadangan bila shader mati).
        art = ColorFiltered(
          colorFilter: ColorFilter.mode(
              const Color(0xFF0A0714)
                  .withValues(alpha: 0.55 * _smooth(_seg(tw, 0.0, 0.34))),
              BlendMode.srcATop),
          child: art,
        );
      }
      final faceW = showFront
          ? Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(math.pi),
        child: art,
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
    // Glitch lama: dua bayangan berwarna yang menyentak. Hanya dipakai bila
    // shader larut tidak tersedia.
    if (!_morphOn && _antag && tw > 0.26 && tw < 0.62) {
      final q = (tw * 55).floor();
      final g = _seg(tw, 0.26, 0.32) * (1 - _seg(tw, 0.42, 0.62));
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
    if (_morphOn && tw > 0 && tw < 0.66) {
      layers.add(_morphLayer(cw, chh, tw));
    }
    final foil = _foilLayer(cw, chh);
    if (foil != null) layers.add(foil);

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

    final tw = _tw;
    final dark = _swapped;
    final faceF = _smooth(_seg(face, 0.5, 1.0));
    final q = (tw * 40).floor();
    // Judul sempat padam tepat di titik tukar, lalu berkedip.
    var flicker = 1.0;
    if (_antag && tw > 0.30 && tw < 0.72) {
      flicker = tw < 0.40 ? 0.12 : (_rnd(q, 9) > 0.3 ? 1.0 : 0.25);
    }
    final titleOpacity = (_smooth(_seg(bt, 0.30, 0.50)) * faceF * flicker)
        .clamp(0.0, 1.0)
        .toDouble();
    final spacing = dark
        ? _lerp(10, 0.8, Curves.easeOut.transform(_seg(tw, 0.38, 0.75)))
        : _lerp(10, 0.8, Curves.easeOut.transform(_seg(bt, 0.32, 0.75)));
    var descOpacity = _smooth(_seg(bt, 0.46, 0.68)) * faceF;
    if (_antag && tw > 0) {
      descOpacity = tw < 0.36
          ? descOpacity * (1 - _smooth(_seg(tw, 0.20, 0.36)))
          : _smooth(_seg(tw, 0.50, 0.72)) * faceF;
    }
    final badgeOpacity = (_antag && widget.disguisePath != null)
        ? _smooth(_seg(tw, 0.68, 0.92)) * faceF
        : 0.0;
    final btnOpacity = _antag
        ? _smooth(_seg(tw, 0.72, 0.95))
        : _smooth(_seg(bt, 0.72, 0.92));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _antag ? 150 : 108,
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
                        GameIcon(dark ? 'bulirhitam' : 'helaidaun', size: 36),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            dark ? 'Si Terbisik' : 'Warga Desa',
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
                        dark
                            ? 'Kabut menitipkan bulir hitam padamu. Hancurkan Hayu tanpa ketahuan.'
                            : 'Selamatkan Hayu. Waspadai satu pengkhianat di antara kalian.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(height: 1.35),
                      ),
                    ),
                    if (badgeOpacity > 0.01)
                      Opacity(
                        opacity: badgeOpacity.clamp(0.0, 1.0).toDouble(),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(5, 4, 12, 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.38),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color:
                                  EmbunColors.gold.withValues(alpha: 0.55)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PlayerAvatar(
                                  path: widget.disguisePath,
                                  size: 30,
                                  ring: EmbunColors.gold,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    widget.disguiseName == null
                                        ? 'Di mata desa, kamu warga biasa'
                                        : 'Di mata desa, kamu ${widget.disguiseName}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 12.5, color: Colors.white70),
                                  ),
                                ),
                              ],
                            ),
                          ),
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

  /// Putar balik Si Terbisik (0..1); 0 untuk warga.
  final double twist;
  final Color deep;

  /// Shader kabut + asap; null = pakai gradasi lama.
  final ui.FragmentShader? atmo;

  /// Shader berkas cahaya; null = pakai segitiga lama.
  final ui.FragmentShader? rays;

  const _Pr({
    required this.fx,
    required this.antag,
    required this.twist,
    required this.center,
    required this.cw,
    required this.ch,
    required this.intro,
    required this.charge,
    required this.burst,
    required this.time,
    required this.mix,
    required this.deep,
    this.atmo,
    this.rays,
  });

  double get r => math.max(cw, ch);
  double get halfDiag => math.sqrt(cw * cw + ch * ch) / 2;
  double get bEnv =>
      _smooth(_seg(burst, 0.05, 0.3)) * (1 - 0.3 * _seg(burst, 0.7, 1));
  double get twEnv =>
      _smooth(_seg(twist, 0.05, 0.4)) * (1 - 0.3 * _seg(twist, 0.75, 1));

  /// Kehangatan tahap kartu baik; memudar begitu putar balik dimulai.
  double get warm => antag ? 1 - _smooth(_seg(twist, 0.25, 0.5)) : 1.0;

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
    if (p.atmo != null) {
      _atmoPass(canvas, size);
    } else {
      _mist(canvas, size);
    }
    _orb(canvas);
    _aura(canvas);
    _charging(canvas);
    if (p.burst > 0) {
      if (p.rays != null) {
        _raysShader(canvas, size);
      } else {
        _rays(canvas, size);
      }
    }
    if (p.atmo == null && p.antag && p.twist > 0) _smoke(canvas);
  }

  /// Kabut volumetrik + asap kelam dalam satu lintasan shader.
  void _atmoPass(Canvas canvas, Size size) {
    final sh = p.atmo!;
    final mi = _smooth(_seg(p.intro, 0, 0.45));
    final pull = math.max(_smooth(_seg(p.intro, 0.3, 0.7)), p.charge);
    final mist = mi * (1 + 0.3 * p.bEnv + 1.4 * p.twEnv);
    // Kabut tersibak dari sekitar kartu saat terungkap (sama untuk kedua
    // peran); kembali pekat bersama putar balik.
    final clear = _smooth(_seg(p.burst, 0.05, 0.4)) * p.warm;
    final smoke = p.antag ? p.twist : 0.0;
    sh
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, p.time)
      ..setFloat(3, p.center.dx)
      ..setFloat(4, p.center.dy)
      ..setFloat(5, mist)
      ..setFloat(6, pull)
      ..setFloat(7, clear)
      ..setFloat(8, smoke)
      ..setFloat(9, p.cw)
      ..setFloat(10, p.ch);
    _rgb(sh, 11, p.col);
    _rgb(sh, 14, _neutralMist);
    _rgb(sh, 17, EmbunColors.mist);
    _rgb(sh, 20, _smokeGrey);
    canvas.drawRect(Offset.zero & size, Paint()..shader = sh);
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
          (1 + 0.3 * p.bEnv + 1.4 * p.twEnv))
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
    final tp = p.twist > 0 ? math.sin(math.pi * _seg(p.twist, 0, 0.6)) : 0.0;
    final a = ((0.16 +
        0.26 * p.charge +
        0.55 * pulse +
        0.25 * p.bEnv +
        0.45 * tp) *
        ai)
        .clamp(0.0, 1.0)
        .toDouble();
    final ar = p.r * (0.85 + 0.35 * p.charge + 0.5 * pulse + 0.35 * tp);
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

  /// Berkas cahaya volumetrik (shader), dilukis aditif.
  void _raysShader(Canvas canvas, Size size) {
    final env = p.bEnv * p.warm;
    if (env <= 0) return;
    final sh = p.rays!;
    sh
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, p.time)
      ..setFloat(3, 0) // mode 0 = berkas cahaya
      ..setFloat(4, env)
      ..setFloat(5, p.center.dx)
      ..setFloat(6, p.center.dy)
      ..setFloat(7, 0);
    _rgb(sh, 8, p.fx.soft);
    _rgb(sh, 11, p.fx.main);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = sh
        ..blendMode = BlendMode.plus,
    );
  }

  void _rays(Canvas canvas, Size size) {
    final env = p.bEnv * p.warm;
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
      final st = 0.28 + 0.30 * _rnd(i, 1);
      final u = _seg(p.twist, st, st + 0.50);
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
    _twistFlash(canvas, size);
    _rings(canvas, size, p.burst, const [0.08, 0.16, 0.26], _wargaFx.main);
    if (p.antag) {
      _rings(canvas, size, p.twist, const [0.32, 0.42, 0.54], _antagFx.main);
    }
    _particles(canvas, p.burst, false);
    if (p.antag) _particles(canvas, _seg(p.twist, 0.30, 1.0), true);
    _motes(canvas, size);
    _vignette(canvas, size);
  }

  void _flash(Canvas canvas, Size size) {
    final bt = p.burst;
    if (bt <= 0) return;
    final a = (_seg(bt, 0, 0.04) * (1 - _smooth(_seg(bt, 0.04, 0.22))) * 0.9)
        .clamp(0.0, 1.0)
        .toDouble();
    if (a <= 0) return;
    final c = Color.lerp(Colors.white, _wargaFx.soft, 0.4)!;
    canvas.drawRect(Offset.zero & size,
        Paint()..color = c.withValues(alpha: a));
  }

  /// Kilatan ungu di titik tukar kartu baik -> kartu gelap.
  void _twistFlash(Canvas canvas, Size size) {
    final tw = p.twist;
    if (!p.antag || tw <= 0) return;
    final a = (_seg(tw, 0.30, 0.36) * (1 - _smooth(_seg(tw, 0.36, 0.56))) * 0.85)
        .clamp(0.0, 1.0)
        .toDouble();
    if (a <= 0) return;
    final c = Color.lerp(Colors.white, _antagFx.soft, 0.55)!;
    canvas.drawRect(Offset.zero & size,
        Paint()..color = c.withValues(alpha: a));
  }

  void _rings(Canvas canvas, Size size, double prog, List<double> starts,
      Color color) {
    if (prog <= 0) return;
    final maxR = size.longestSide * 0.6;
    for (final s in starts) {
      final u = _seg(prog, s, s + 0.36);
      if (u <= 0 || u >= 1) continue;
      final e = Curves.easeOutCubic.transform(u);
      canvas.drawCircle(
        p.center,
        _lerp(p.ch * 0.3, maxR, e),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * (1 - u) + 1
          ..color = color.withValues(alpha: 0.8 * (1 - u)),
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

  /// Daun berhamburan (kartu baik) atau serpihan bulir hitam ([shards]).
  void _particles(Canvas canvas, double bt, bool shards) {
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
      if (!shards) {
        fill.color = Color.lerp(_wargaFx.main, EmbunColors.gold, _rnd(i, 7))!
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
    // Emas dulu; Si Terbisik berubah jadi bara ungu saat putar balik.
    final c = Color.lerp(_wargaFx.soft, EmbunColors.mist,
        p.antag ? _smooth(_seg(p.twist, 0.30, 0.60)) : 0.0)!;
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
      final te = p.twEnv;
      v += 0.35 * te + 0.10 * te * math.sin(p.time * 2.6);
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

/// Larut kartu baik -> kartu gelap lewat shader card_morph.frag. Dilukis
/// persis di atas bidang kartu (ukuran widget = ukuran kartu).
class _MorphPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final ui.Image a;
  final ui.Image b;
  final double prog;
  final double time;
  final double seed;
  final Color edge;
  final Color hot;
  const _MorphPainter({
    required this.shader,
    required this.a,
    required this.b,
    required this.prog,
    required this.time,
    required this.seed,
    required this.edge,
    required this.hot,
  });

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, prog)
      ..setFloat(3, time)
      ..setFloat(4, 10) // radius sudut kartu, sama dengan CardArt
      ..setFloat(5, seed)
      ..setImageSampler(0, a)
      ..setImageSampler(1, b);
    _rgb(shader, 6, edge);
    _rgb(shader, 9, hot);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _MorphPainter old) => true;
}

/// Kilau foil yang menyapu muka kartu (mode 1 pada divine.frag), aditif.
class _FoilPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double time;
  final double env;
  final Color soft;
  final Color hue;
  const _FoilPainter({
    required this.shader,
    required this.time,
    required this.env,
    required this.soft,
    required this.hue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time)
      ..setFloat(3, 1) // mode 1 = kilau foil
      ..setFloat(4, env)
      ..setFloat(5, 0)
      ..setFloat(6, 0)
      ..setFloat(7, 10);
    _rgb(shader, 8, soft);
    _rgb(shader, 11, hue);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = shader
        ..blendMode = BlendMode.plus,
    );
  }

  @override
  bool shouldRepaint(covariant _FoilPainter old) => true;
}