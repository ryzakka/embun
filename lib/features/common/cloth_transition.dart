import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'sfx.dart';

/// Transisi kain batik terhempas: kiri-bawah -> kanan-atas.
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
  static bool get isReady => _program != null;

  /// Instans shader baru (tiap lapisan overlay memegang miliknya sendiri).
  static ui.FragmentShader? createShader() => _program?.fragmentShader();

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
        Duration duration = const Duration(milliseconds: 1500),
      }) {
    final seconds = duration.inMilliseconds / 1000.0;

    return PageRouteBuilder<T>(
      transitionDuration: duration,
      reverseTransitionDuration: duration,
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
                    painter: _ClothPainter(shader, t, t * seconds),
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
/// Lalu panggil `_cloth.currentState?.play(onCovered: ...)`. [onCovered]
/// dipanggil tepat saat kain menutup layar penuh: di situlah isi layar
/// boleh diganti tanpa terlihat pemain. Selama kain berjalan, sentuhan ke
/// layar di bawahnya ditahan.
class ClothSweepLayer extends StatefulWidget {
  final Duration duration;
  const ClothSweepLayer({
    super.key,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<ClothSweepLayer> createState() => ClothSweepLayerState();
}

class ClothSweepLayerState extends State<ClothSweepLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: widget.duration);
  ui.FragmentShader? _shader;
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

  /// Memutar kain. Mengembalikan false bila kain TIDAK diputar (shader belum
  /// termuat, atau kain sudah lewat titik tutup): pemanggil harus mengganti
  /// isi layar sendiri, sekarang juga. [onCovered] tidak dipanggil saat false.
  bool play({VoidCallback? onCovered}) {
    if (!mounted) return false;
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
    Sfx.I.playAny(Snd.winds, owner: this, tag: 'cloth', replace: true);
    _c.forward(from: 0);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    if (shader == null) return const SizedBox.shrink();
    final seconds = widget.duration.inMilliseconds / 1000.0;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _c.value;
        if (v <= 0.001 || v >= 0.999) return const SizedBox.shrink();
        return AbsorbPointer(
          child: SizedBox.expand(
            child: CustomPaint(painter: _ClothPainter(shader, v, v * seconds)),
          ),
        );
      },
    );
  }
}

class _ClothPainter extends CustomPainter {
  _ClothPainter(this.shader, this.progress, this.time);

  final ui.FragmentShader shader;
  final double progress;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.001 || progress >= 0.999) return;
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, progress)
      ..setFloat(3, time);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_ClothPainter old) =>
      old.progress != progress || old.time != time;
}