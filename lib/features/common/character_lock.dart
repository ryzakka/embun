import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../data/character_catalog.dart';

class CharacterLock extends StatelessWidget {
  const CharacterLock({super.key, required this.id, required this.child});
  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: CharacterCatalog.revision,
    builder: (context, revision, _) {
      final locked = !CharacterCatalog.isEnabled(id);
      if (!locked) return child;
      return Semantics(
        label: '${characterDefinitions[id]?.title ?? 'Karakter'} terkunci',
        enabled: false,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            alignment: Alignment.center,
            children: [
              ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Colors.grey,
                    BlendMode.saturation,
                  ),
                  child: Opacity(opacity: .45, child: child),
                ),
              ),
              const Positioned.fill(
                child: ColoredBox(color: Color(0x66050C0A)),
              ),
              const Padding(
                padding: EdgeInsets.all(6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      color: Color(0xFFE7BC5E),
                      size: 24,
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Terkunci',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
