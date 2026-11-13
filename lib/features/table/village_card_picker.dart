import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'card_tile.dart';
import 'player_status.dart';

/// Pemain selalu memakai kartu karakter publik; peran rahasia tidak dibaca.
class VillageCardOption {
  const VillageCardOption({
    required this.id,
    required this.title,
    this.path,
    this.subtitle,
    this.lives,
  });
  final String id, title;
  final String? path, subtitle;
  final int? lives;
  factory VillageCardOption.player(
    Map<String, dynamic> player, {
    String? myId,
  }) => VillageCardOption(
    id: player['user_id'] as String,
    title: player['name'] as String? ?? 'Pemain',
    path: protagonistPath(player['character_card'] as String? ?? ''),
    subtitle: player['user_id'] == myId ? 'Kamu' : 'Warga desa',
    lives: livesLeft(player),
  );
  factory VillageCardOption.item(
    Map<String, dynamic> hand,
    Map<String, Map<String, dynamic>> defs,
  ) {
    final def = defs[hand['card_id']];
    return VillageCardOption(
      id: hand['id'] as String,
      title: def?['name'] as String? ?? 'Kartu',
      path: cardArtPath(def),
      subtitle: hand['charged'] == true
          ? 'Aktif'
          : kindLabel[def?['kind']] ?? 'Item',
    );
  }
}

class VillageChoiceCard extends StatelessWidget {
  const VillageChoiceCard({
    super.key,
    required this.option,
    this.width = 126,
    this.selected = false,
    this.onTap,
    this.caption,
  });
  final VillageCardOption option;
  final double width;
  final bool selected;
  final VoidCallback? onTap;
  final String? caption;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Semantics(
      label:
          '${option.title}${option.subtitle == null ? '' : ', ${option.subtitle}'}',
      selected: selected,
      button: onTap != null,
      child: Tooltip(
        message: option.title,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? EmbunColors.gold
                            : Colors.white.withValues(alpha: .18),
                        width: selected ? 2 : 1,
                      ),
                      boxShadow: [
                        if (selected)
                          BoxShadow(
                            color: EmbunColors.gold.withValues(alpha: .16),
                            blurRadius: 16,
                          ),
                      ],
                    ),
                    child: AspectRatio(
                      aspectRatio: 2 / 3,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: option.path == null
                                ? ColoredBox(
                                    color: EmbunColors.panelHi,
                                    child: Icon(
                                      option.lives == null
                                          ? Icons.style_outlined
                                          : Icons.person_outline,
                                      size: 36,
                                      color: EmbunColors.goldDim,
                                    ),
                                  )
                                : GameImage(
                                    path: option.path,
                                    fit: BoxFit.contain,
                                  ),
                          ),
                          if (selected)
                            const Positioned(
                              right: 4,
                              top: 4,
                              child: Icon(
                                Icons.check_circle,
                                color: EmbunColors.gold,
                                size: 22,
                              ),
                            ),
                          if (option.lives != null)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: ColoredBox(
                                color: const Color(0xD907130F),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 5,
                                  ),
                                  child: Center(
                                    child: LivesRow(
                                      lives: option.lives!,
                                      size: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    option.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  if (caption ?? option.subtitle case final String detail)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        detail,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: selected ? EmbunColors.gold : Colors.white60,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<String?> showVillageCardPicker(
  BuildContext context, {
  required String title,
  required List<VillageCardOption> options,
  String? selected,
  String confirmLabel = 'Gunakan pilihan',
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  constraints: const BoxConstraints(maxWidth: 920),
  builder: (context) => _CardGallery(
    title: title,
    options: options,
    selected: selected,
    confirmLabel: confirmLabel,
  ),
);

class _CardGallery extends StatefulWidget {
  const _CardGallery({
    required this.title,
    required this.options,
    this.selected,
    required this.confirmLabel,
  });
  final String title, confirmLabel;
  final List<VillageCardOption> options;
  final String? selected;
  @override
  State<_CardGallery> createState() => _CardGalleryState();
}

class _CardGalleryState extends State<_CardGallery> {
  late String? _selected = widget.selected;
  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .9,
    child: Material(
      color: EmbunColors.bg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup pilihan',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final cols = math.max(2, ((box.maxWidth - 24) / 150).floor());
                final width = ((box.maxWidth - 32 - (cols - 1) * 12) / cols)
                    .clamp(70.0, 160.0);
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 18,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final option in widget.options)
                        VillageChoiceCard(
                          option: option,
                          width: width,
                          selected: option.id == _selected,
                          onTap: () => setState(() => _selected = option.id),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: widget.options.any((o) => o.id == _selected)
                  ? () => Navigator.pop(context, _selected)
                  : null,
              child: Text(widget.confirmLabel),
            ),
          ),
        ],
      ),
    ),
  );
}
