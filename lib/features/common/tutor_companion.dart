import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import 'art.dart';
import 'shader_fx.dart';

enum TutorPose {
  greeting('menyapa'),
  question('tanya'),
  panic('panik'),
  heavyWater('emberberatair'),
  encourage('ayo'),
  offering('persembahan'),
  combine('gabungair'),
  shopping('belanjakebanyakan'),
  confused('kebingunganataukesal'),
  counting('menghitung'),
  choosing('menunjukmemilih'),
  thinking('berfikir'),
  tired('lesu');

  const TutorPose(this.assetName);
  final String assetName;
  String? get path => AssetCatalog.I.file(
    'assets/kartu/CharPopUp',
    'popupchar-tutor-$assetName',
  );
}

/// A grounded illustration beside the heading, within normal document flow.
/// Missing assets leave the original heading visible without an empty panel.
class TutorCompanion extends StatelessWidget {
  const TutorCompanion({
    super.key,
    required this.pose,
    required this.child,
    this.accent = const Color(0xFFE7BC5E),
    this.compact = false,
    this.large = false,
  });

  final TutorPose pose;
  final Widget child;
  final Color accent;
  final bool compact, large;

  @override
  Widget build(BuildContext context) {
    final path = pose.path;
    if (path == null) return child;
    return LayoutBuilder(
      builder: (context, box) {
        final width = math.min(
          compact
              ? 64.0
              : large
              ? 150.0
              : 90.0,
          box.maxWidth * .32,
        );
        final reduced =
            MediaQuery.disableAnimationsOf(context) || !ShaderFx.enabled.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: accent.withValues(alpha: .28)),
            ),
            gradient: LinearGradient(
              colors: [accent.withValues(alpha: .08), Colors.transparent],
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ExcludeSemantics(
                child: SizedBox(
                  width: width,
                  height: width * 1.45,
                  child: ClipRect(
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (bounds) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [0, .87, 1],
                      ).createShader(bounds),
                      child: AnimatedSwitcher(
                        duration: Duration(milliseconds: reduced ? 0 : 250),
                        child: SizedBox.expand(
                          key: ValueKey(path),
                          child: GameImage(
                            path: path,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            cacheWidth: large ? 460 : 280,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: compact ? 9 : 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The same decorative trio for everyone; never identifies the real attacker.
class AntagonistCanopy extends StatelessWidget {
  const AntagonistCanopy({super.key, this.visibility = 1});
  final double visibility;

  @override
  Widget build(BuildContext context) {
    final path = AssetCatalog.I.file(
      'assets/kartu/CharPopUp',
      'popupchar-anta-munculdariatas',
    );
    if (path == null || visibility <= 0 || !ShaderFx.enabled.value) {
      return const SizedBox.shrink();
    }
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.topCenter,
          child: LayoutBuilder(
            builder: (context, box) {
              final height = math.min(
                box.maxHeight * .46,
                box.maxWidth * 941 / 1672,
              );
              return Opacity(
                opacity: visibility.clamp(0.0, 1.0) * .78,
                child: SizedBox(
                  width: box.maxWidth,
                  height: height,
                  child: GameImage(
                    path: path,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    cacheWidth: 1400,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
