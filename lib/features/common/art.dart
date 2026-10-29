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
            ? GameIcon('character', size: size * 0.8)
            : path!.startsWith(protagonisDir)
            ? _FaceCrop(path: path!, size: size)
            : GameImage(
          path: path,
          alignment: const Alignment(0, -0.6),
          cacheWidth: (size * 3).round(),
        ),
      ),
    );
  }
}

/// Potongan wajah dari kartu protagonis 2:3: kartu diperbesar ke arah wajah
/// (sekitar 27% dari atas) sehingga bingkai berhias dan plat nama tidak ikut
/// tampak di avatar bulat.
class _FaceCrop extends StatelessWidget {
  final String path;
  final double size;
  const _FaceCrop({required this.path, required this.size});

  static const _windowW = 0.62; // lebar jendela = 62% lebar kartu
  static const _faceY = 0.27; // pusat wajah dari atas kartu

  @override
  Widget build(BuildContext context) {
    final cw = size / _windowW;
    final ch = cw * kProtagonistAspect;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: (size - cw) / 2,
            top: size / 2 - _faceY * ch,
            width: cw,
            height: ch,
            child: GameImage(path: path, cacheWidth: (cw * 2).round()),
          ),
        ],
      ),
    );
  }
}

/// Kartu karakter potret. Rasio mengikuti jenis kartu ([cardAspectFor]):
/// protagonis 2:3, kartu gelap 3:4.
class CardArt extends StatelessWidget {
  final String? path;
  final double width;
  final Color? glow;
  const CardArt({super.key, required this.path, this.width = 100, this.glow});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width * cardAspectFor(path),
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

/// Ikon emas-hijau dari assets/ikon. Untuk ikon persegi cukup isi [size].
/// Untuk gambar lebar (cap, judul) isi [width] dan [height].
class GameIcon extends StatelessWidget {
  final String name;
  final double size;
  final double? width;
  final double? height;
  const GameIcon(this.name,
      {super.key, this.size = 20, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    final w = width ?? size;
    final h = height ?? size;
    final p = ikonPath(name);
    return SizedBox(
      width: w,
      height: h,
      child: p == null
          ? null
          : GameImage(path: p, fit: BoxFit.contain, cacheWidth: (w * 3).round()),
    );
  }
}
/// Layar muat: ikon aplikasi berdenyut pelan di atas indikator tipis.
class EmbunLoading extends StatefulWidget {
  final String? text;
  const EmbunLoading({super.key, this.text});

  @override
  State<EmbunLoading> createState() => _EmbunLoadingState();
}

class _EmbunLoadingState extends State<EmbunLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _c,
          builder: (_, child) {
            final t = Curves.easeInOut.transform(_c.value);
            return Opacity(
              opacity: 0.7 + 0.3 * t,
              child: Transform.scale(scale: 0.96 + 0.06 * t, child: child),
            );
          },
          child: SizedBox(
            width: 96,
            height: 96,
            child: GameImage(
                path: logoPath('ikonapp-transparent'),
                fit: BoxFit.contain,
                cacheWidth: 288),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 120,
          child: LinearProgressIndicator(
              minHeight: 3, borderRadius: BorderRadius.circular(2)),
        ),
        if (widget.text != null) ...[
          const SizedBox(height: 10),
          Text(widget.text!,
              style: const TextStyle(fontSize: 12, color: Colors.white60)),
        ],
      ],
    ),
  );
}