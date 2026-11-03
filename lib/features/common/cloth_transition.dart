import 'dart:ui' as ui;
import 'package:flutter/material.dart';

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