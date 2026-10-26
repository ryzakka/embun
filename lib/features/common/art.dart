import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';

const _placeholder = ColoredBox(color: Color(0x33000000));

class GameImage extends StatelessWidget {
  final String? path;
  final BoxFit fit;
  final Alignment alignment;
  final int? cacheWidth;
  const GameImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.cacheWidth,
  });

  @override
  Widget build(BuildContext context) {
    final p = path;
    if (p == null) return _placeholder;
    return Image.asset(
      p,
      fit: fit,
      alignment: alignment,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _placeholder,
    );
  }
}

Widget _fadeLayout(Widget? current, List<Widget> previous) => Stack(
  fit: StackFit.expand,
  children: [...previous, ?current],
);

/// Latar bentangan yang memudar saat gambar berganti.
class Backdrop extends StatelessWidget {
  final String? path;
  final bool dark;
  final double dim;
  const Backdrop({
    super.key,
    required this.path,
    this.dark = false,
    this.dim = 0.7,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 1200),
          layoutBuilder: _fadeLayout,
          child: GameImage(key: ValueKey(path), path: path, cacheWidth: 1280),
        ),
        ColoredBox(
          color: (dark ? const Color(0xFF1A1030) : const Color(0xFF07130F))
              .withValues(alpha: dim),
        ),
      ],
    );
  }
}

/// Potret pohon 16:9, menyesuaikan ruang yang tersedia.
class TreePortrait extends StatelessWidget {
  final int leaves;
  final String? pathOverride;
  const TreePortrait({super.key, required this.leaves, this.pathOverride});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      var w = c.maxWidth.isFinite ? c.maxWidth : 640.0;
      if (w > 640) w = 640;
      var h = w * 9 / 16;
      if (c.maxHeight.isFinite && h > c.maxHeight) {
        h = c.maxHeight;
        w = h * 16 / 9;
      }
      final path = pathOverride ?? treePath(leaves);
      return Center(
        child: SizedBox(
          width: w,
          height: h,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 900),
                layoutBuilder: _fadeLayout,
                child: GameImage(key: ValueKey(path), path: path, cacheWidth: 1000),
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// Avatar bulat dari bagian atas kartu karakter.
class PlayerAvatar extends StatelessWidget {
  final String? path;
  final double size;
  final Color ring;
  const PlayerAvatar({
    super.key,
    required this.path,
    this.size = 40,
    this.ring = Colors.white38,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: 2),
      ),
      child: ClipOval(
        child: path == null
            ? Icon(Icons.person, size: size * 0.6)
            : GameImage(
          path: path,
          alignment: const Alignment(0, -0.6),
          cacheWidth: (size * 3).round(),
        ),
      ),
    );
  }
}

/// Kartu karakter potret (rasio 3:4).
class CardArt extends StatelessWidget {
  final String? path;
  final double width;
  final Color? glow;
  const CardArt({super.key, required this.path, this.width = 100, this.glow});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width * 4 / 3,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: (glow ?? Colors.black).withValues(alpha: 0.55),
            blurRadius: glow == null ? 8 : 26,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: GameImage(path: path, cacheWidth: (width * 2).round()),
      ),
    );
  }
}