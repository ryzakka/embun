import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'sfx.dart';
import 'shader_fx.dart';

/// Gaya satu sapuan kain: arah, motif, karakter kibasan, palet, dan lama.
///
/// Pakai salah satu preset, atau [ClothStyle.pick] untuk memilih acak:
///   ClothTransition.route(page, style: ClothStyle.selendangBata)
///   _cloth.currentState?.play(style: ClothStyle.daunHayu.tinted(dark: true))
@immutable
class ClothStyle {
  final String name;

  /// Arah gerak kain. y positif = ke atas layar. Panjangnya tak berpengaruh.
  final Offset wind;

  /// 0 = kawung (kisi belah ketupat), 1 = lurik bergaris, 2 = bunga.
  final int motif;

  /// Kekuatan kibasan tepi kain (1.0 = normal; jaga <= 1.4).
  final double amp;

  /// Kerapatan gelombang tepi (1.0 = normal; besar = riak lebih rapat).
  final double freq;

  final Color baseA, baseB, accent, ribbon;
  final Duration duration;

  const ClothStyle({
    required this.name,
    required this.wind,
    required this.motif,
    required this.baseA,
    required this.baseB,
    required this.accent,
    required this.ribbon,
    this.amp = 1.0,
    this.freq = 1.0,
    this.duration = const Duration(milliseconds: 2000),
  });

  /// Batik indigo-emas, dikibaskan dari kiri bawah ke kanan atas.
  static const batikIndigo = ClothStyle(
    name: 'batik-indigo',
    wind: Offset(1, 0.75),
    motif: 0,
    amp: 1.15,
    duration: Duration(milliseconds: 2000),
    baseA: Color(0xFF121739),
    baseB: Color(0xFF21120D),
    accent: Color(0xFFDBA338),
    ribbon: Color(0xFFCC5C1A),
  );

  /// Selendang bata berlurik, menyambar dari kanan ke kiri.
  static const selendangBata = ClothStyle(
    name: 'selendang-bata',
    wind: Offset(-1, 0.2),
    motif: 1,
    amp: 1.3,
    freq: 0.8,
    duration: Duration(milliseconds: 1800),
    baseA: Color(0xFFA6481B),
    baseB: Color(0xFF5A2410),
    accent: Color(0xFFE8C766),
    ribbon: Color(0xFFF2E3C0),
  );

  /// Kain krem berbunga indigo, naik dari bawah seperti rok yang berputar.
  static const bungaKrem = ClothStyle(
    name: 'bunga-krem',
    wind: Offset(0.35, 1),
    motif: 2,
    amp: 1.1,
    freq: 1.2,
    duration: Duration(milliseconds: 2100),
    baseA: Color(0xFFEBD9AE),
    baseB: Color(0xFFD8BE8A),
    accent: Color(0xFF1E2552),
    ribbon: Color(0xFFB8501A),
  );

  /// Kain hijau berkawung emas, jatuh dari atas seperti tirai. Cocok untuk
  /// adegan Hayu.
  static const daunHayu = ClothStyle(
    name: 'daun-hayu',
    wind: Offset(0.45, -1),
    motif: 0,
    amp: 1.0,
    freq: 0.9,
    duration: Duration(milliseconds: 2000),
    baseA: Color(0xFF0E3326),
    baseB: Color(0xFF1B4D38),
    accent: Color(0xFFE0B64A),
    ribbon: Color(0xFF6FA84A),
  );

  static const _all = [batikIndigo, selendangBata, bungaKrem, daunHayu];

  /// Palet ungu kabut untuk sisi Si Terbisik (sama dengan tema gelap layar).
  static const _darkA = Color(0xFF160D2B);
  static const _darkB = Color(0xFF2E1B4F);
  static const _darkAccent = Color(0xFFB07CE8);
  static const _darkRibbon = Color(0xFF5E3C94);

  /// Gaya yang sama (arah, motif, kibasan) dengan palet ungu bila [dark].
  ClothStyle tinted({required bool dark}) => !dark
      ? this
      : ClothStyle(
    name: '$name-gelap',
    wind: wind,
    motif: motif,
    amp: amp,
    freq: freq,
    duration: duration,
    baseA: _darkA,
    baseB: _darkB,
    accent: _darkAccent,
    ribbon: _darkRibbon,
  );

  static ClothStyle? _last;

  /// Pilih acak, tidak pernah sama dengan pilihan sebelumnya.
  static ClothStyle pick({bool dark = false}) {
    final pool = _all.where((s) => s.name != _last?.name).toList();
    final s = pool[math.Random().nextInt(pool.length)];
    _last = s;
    return s.tinted(dark: dark);
  }
}

/// Transisi kain terhempas antar halaman (dan, lewat [ClothSweepLayer],
/// antar fase di dalam satu halaman).
///
/// Setup:
/// 1. Taruh cloth.frag di shaders/ lalu daftarkan di pubspec.yaml:
///      flutter:
///        shaders:
///          - shaders/cloth.frag
/// 2. Panggil `await ClothTransition.preload();` di main() sebelum runApp.
/// 3. Pakai: Navigator.push(context, ClothTransition.route(const NextScene()));
class ClothTransition {
  static ui.FragmentProgram? _program;
  static ui.FragmentShader? _shader;

  /// true bila shader sudah termuat (kain bisa diputar).
  static bool get isReady => ShaderFx.enabled.value && _program != null;

  /// Instans shader baru (tiap lapisan overlay memegang miliknya sendiri).
  static ui.FragmentShader? createShader() =>
      ShaderFx.enabled.value ? _program?.fragmentShader() : null;

  static Future<void> preload() async {
    try {
      _program ??= await ui.FragmentProgram.fromAsset('shaders/cloth.frag');
      _shader ??= _program!.fragmentShader();
    } catch (e) {
      debugPrint('Shader kain gagal dimuat, memakai fade: $e');
    }
  }

  static Route<T> route<T>(
      Widget page, {
        ClothStyle style = ClothStyle.batikIndigo,
        Duration? duration,
      }) {
    // Efek visual dimatikan: rute biasa seperti semula.
    if (!ShaderFx.enabled.value) {
      return MaterialPageRoute<T>(builder: (_) => page);
    }
    final d = duration ?? style.duration;
    final seconds = d.inMilliseconds / 1000.0;
    final seed = math.Random().nextDouble();

    return PageRouteBuilder<T>(
      transitionDuration: d,
      reverseTransitionDuration: d,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (context, animation, secondary, child) {
        final shader = _shader;
        if (shader == null) {
          return FadeTransition(opacity: animation, child: child);
        }
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = animation.value;
            return Stack(
              fit: StackFit.expand,
              children: [
                // Halaman baru baru DIBANGUN saat kain menutup penuh (t >= 0.5),
                // supaya initState-nya (cerita, timer, musik) tidak berjalan
                // tersembunyi di balik kain.
                if (t >= 0.5) child,
                IgnorePointer(
                  child: CustomPaint(
                    painter: _ClothPainter(shader, style, seed, t, t * seconds),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Lapisan kain untuk pergantian fase DI DALAM satu halaman (bukan rute).
///
/// Pasang sebagai anak TERAKHIR sebuah Stack, supaya kain menutupi semuanya:
///
///   final _cloth = GlobalKey<ClothSweepLayerState>();
///   ...
///   Positioned.fill(child: ClothSweepLayer(key: _cloth)),
///
/// Lalu panggil `_cloth.currentState?.play(onCovered: ..., style: ...)`.
/// [onCovered] dipanggil tepat saat kain menutup layar penuh: di situlah isi
/// layar boleh diganti tanpa terlihat pemain. Selama kain berjalan, sentuhan
/// ke layar di bawahnya ditahan.
class ClothSweepLayer extends StatefulWidget {
  const ClothSweepLayer({super.key});

  @override
  State<ClothSweepLayer> createState() => ClothSweepLayerState();
}

class ClothSweepLayerState extends State<ClothSweepLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: ClothStyle.batikIndigo.duration);
  ui.FragmentShader? _shader;
  ClothStyle _style = ClothStyle.batikIndigo;
  double _seed = 0;
  final List<VoidCallback> _onCovered = [];
  bool _covered = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(_tick);
  }

  @override
  void dispose() {
    _c.dispose();
    _shader?.dispose();
    Sfx.I.release(this);
    super.dispose();
  }

  void _tick() {
    if (_covered || _c.value < 0.5) return;
    _covered = true;
    HapticFeedback.mediumImpact();
    final cbs = List<VoidCallback>.of(_onCovered);
    _onCovered.clear();
    for (final cb in cbs) {
      cb();
    }
  }

  /// Memutar kain dengan [style] (acak bila kosong). Mengembalikan false bila
  /// kain TIDAK diputar (shader belum termuat, atau kain sudah lewat titik
  /// tutup): pemanggil harus mengganti isi layar sendiri, sekarang juga.
  /// [onCovered] tidak dipanggil saat false.
  bool play({VoidCallback? onCovered, ClothStyle? style}) {
    if (!mounted || !ShaderFx.enabled.value) return false;
    _shader ??= ClothTransition.createShader();
    if (_shader == null) return false;
    if (_c.isAnimating) {
      if (_covered) return false;
      if (onCovered != null) _onCovered.add(onCovered);
      return true;
    }
    _covered = false;
    _onCovered.clear();
    if (onCovered != null) _onCovered.add(onCovered);
    _style = style ?? ClothStyle.pick();
    _seed = math.Random().nextDouble();
    _c.duration = _style.duration;
    Sfx.I.playAny(Snd.winds, owner: this, tag: 'cloth', replace: true);
    _c.forward(from: 0);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    if (shader == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _c.value;
        if (v <= 0.001 || v >= 0.999) return const SizedBox.shrink();
        final seconds = _style.duration.inMilliseconds / 1000.0;
        return AbsorbPointer(
          child: SizedBox.expand(
            child: CustomPaint(
              painter: _ClothPainter(shader, _style, _seed, v, v * seconds),
            ),
          ),
        );
      },
    );
  }
}

class _ClothPainter extends CustomPainter {
  _ClothPainter(this.shader, this.style, this.seed, this.progress, this.time);

  final ui.FragmentShader shader;
  final ClothStyle style;
  final double seed;
  final double progress;
  final double time;

  void _rgb(int i, Color c) {
    shader
      ..setFloat(i, c.r)
      ..setFloat(i + 1, c.g)
      ..setFloat(i + 2, c.b);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.001 || progress >= 0.999) return;
    // Urutan harus sama dengan deklarasi uniform di shaders/cloth.frag.
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, progress)
      ..setFloat(3, time)
      ..setFloat(4, style.wind.dx)
      ..setFloat(5, style.wind.dy)
      ..setFloat(6, style.motif.toDouble())
      ..setFloat(7, style.amp)
      ..setFloat(8, style.freq)
      ..setFloat(9, seed);
    _rgb(10, style.baseA);
    _rgb(13, style.baseB);
    _rgb(16, style.accent);
    _rgb(19, style.ribbon);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_ClothPainter old) =>
      old.progress != progress ||
          old.time != time ||
          old.style != style ||
          old.seed != seed;
}