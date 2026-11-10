import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/asset_catalog.dart';
import '../../data/hayu_parts.dart';
import '../common/art.dart';
import '../common/ornate.dart';

typedef _PartChange = ({HayuPart part, String label, bool weakened});

const _partLabels = {
  'akar hayu menyegar': (HayuPart.akar, false),
  'akar hayu membusuk': (HayuPart.akar, true),
  'batang hayu menguat': (HayuPart.batang, false),
  'batang hayu retak': (HayuPart.batang, true),
  'tanah di kaki hayu menyubur': (HayuPart.tanah, false),
  'tanah di kaki hayu tercemar': (HayuPart.tanah, true),
};

final _leafDeltaPattern = RegExp(
  r'([+\-−–])\s*(\d+)\s*daun\b',
  caseSensitive: false,
);

/// Pembacaan label yang memang sudah diumumkan kepada semua pemain.
int _publicLeafDelta(String label) {
  final match = _leafDeltaPattern.firstMatch(label);
  if (match == null) return 0;
  final value = int.tryParse(match[2]!) ?? 0;
  return match[1] == '+' ? value : -value;
}

class HayuReaction {
  final int gained;
  final int lost;
  final List<_PartChange> _parts;

  const HayuReaction._(this.gained, this.lost, this._parts);

  bool get isEmpty => gained == 0 && lost == 0 && _parts.isEmpty;

  factory HayuReaction.fromPublicRows(Iterable<Map<String, dynamic>> rows) {
    var gained = 0;
    var lost = 0;
    final parts = <HayuPart, _PartChange>{};
    for (final row in rows) {
      final label = row['label'];
      if (label is! String) continue;
      final delta = _publicLeafDelta(label);
      gained += math.max(0, delta);
      lost += math.max(0, -delta);
      final normalized = label.trim().toLowerCase();
      final part = _partLabels[normalized.replaceFirst(' (berlanjut)', '')];
      if (part == null) continue;
      parts[part.$1] = (part: part.$1, label: label, weakened: part.$2);
    }
    return HayuReaction._(gained, lost, parts.values.toList());
  }
}

class HayuReactionLayer extends StatelessWidget {
  final HayuReaction reaction;
  final double progress;

  const HayuReactionLayer({
    super.key,
    required this.reaction,
    required this.progress,
  });

  static const _fresh = Color(0xFFA5ECC1);
  static const _withered = Color(0xFFF0C39B);

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final t = progress;
    final opacity = still
        ? 1.0
        : (t / 0.14).clamp(0.0, 1.0) *
              (1 - ((t - 0.70) / 0.30).clamp(0.0, 1.0));
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final h = box.maxHeight;
            final crown = Offset(w / 2, h * (h < 420 ? 0.46 : 0.43));
            final spread = math.min(w * 0.34, 230.0);
            return Stack(
              children: [
                if (!still) ...[
                  _leafMotion(reaction.gained, crown, spread, t, growing: true),
                  _leafMotion(reaction.lost, crown, spread, t, growing: false),
                ],
                Align(
                  alignment: Alignment(
                    w >= 760 ? 0.64 : 0,
                    h < 420 ? 0.44 : 0.56,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Semantics(
                        container: true,
                        liveRegion: true,
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 6,
                          runSpacing: 5,
                          children: [
                            if (reaction.gained > 0)
                              _label(
                                HayuPart.daun,
                                '+${reaction.gained} daun',
                                _fresh,
                              ),
                            if (reaction.lost > 0)
                              _label(
                                HayuPart.daun,
                                '−${reaction.lost} daun',
                                _withered,
                              ),
                            for (final change in reaction._parts)
                              _label(
                                change.part,
                                change.label,
                                change.weakened ? _withered : _fresh,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _leafMotion(
    int amount,
    Offset crown,
    double spread,
    double t, {
    required bool growing,
  }) {
    final count = math.min(amount, 8);
    if (count == 0) return const SizedBox.shrink();
    // Jumlah label tetap utuh. Gerak daun dibatasi agar tajuk tetap terlihat.
    final direction = growing ? 1.0 : -1.0;
    return ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < count; i++)
            _movingLeaf(
              crown +
                  Offset(
                    (count == 1 ? direction * 0.27 : i / (count - 1) - 0.5) *
                        spread,
                    (i % 3) * 9.0,
                  ),
              ((t - i * 0.034) / 0.72).clamp(0.0, 1.0),
              i,
              growing,
            ),
        ],
      ),
    );
  }

  Widget _movingLeaf(Offset anchor, double t, int index, bool growing) {
    final rise = Curves.easeOutCubic.transform(t);
    final sway = math.sin(t * math.pi) * (index.isEven ? 13 : -13);
    final dy = growing ? 9 - 44 * rise : 7 + 70 * t * t;
    final accent = growing ? _fresh : _withered;
    return Positioned(
      left: anchor.dx + sway - 12,
      top: anchor.dy + dy - 12,
      child: Opacity(
        opacity: math.sin(t * math.pi).clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: (index.isEven ? 1 : -1) * (growing ? 0.38 : 0.94) * t,
          child: Transform.scale(
            scale: growing ? 0.35 + 0.65 * rise : 1 - 0.30 * t,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.42),
                    blurRadius: 13,
                  ),
                ],
              ),
              child: const GameIcon('helaidaun', size: 24),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(HayuPart part, String label, Color accent) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xEA10211B),
      border: Border.all(color: accent.withValues(alpha: 0.75)),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: accent.withValues(alpha: 0.26), blurRadius: 14),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(4, 3, 9, 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 24,
            child: GameImage(
              path: sceneryPath('pohonindikator-${part.name}'),
              fit: BoxFit.contain,
              cacheWidth: 72,
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: EmbunColors.cream,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
