import 'package:flutter/material.dart';

import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'ability_panel.dart';

Future<void> showMyInfoDialog(
  BuildContext context, {
  required bool isAntag,
  required String name,
  required String characterStem,
  int? darkSeed,
  Map<String, dynamic>? abilityDef,
  bool abilityUsed = false,
  VoidCallback? onInspectionHistory,
}) => showDialog<void>(
  context: context,
  builder: (_) => _MyInfoDialog(
    isAntag: isAntag,
    name: name,
    characterStem: characterStem,
    darkSeed: darkSeed,
    abilityDef: abilityDef,
    abilityUsed: abilityUsed,
    onInspectionHistory: onInspectionHistory,
  ),
);

class _MyInfoDialog extends StatelessWidget {
  const _MyInfoDialog({
    required this.isAntag,
    required this.name,
    required this.characterStem,
    required this.darkSeed,
    required this.abilityDef,
    required this.abilityUsed,
    this.onInspectionHistory,
  });

  final bool isAntag;
  final String name;
  final String characterStem;
  final int? darkSeed;
  final Map<String, dynamic>? abilityDef;
  final bool abilityUsed;
  final VoidCallback? onInspectionHistory;

  @override
  Widget build(BuildContext context) {
    final accent = isAntag ? EmbunColors.mist : EmbunColors.leaf;
    final ability = abilityDef;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: OrnatePanel(
          accent: accent,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const GameIcon('lock', size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Infoku',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: EmbunColors.cream,
                        ),
                      ),
                    ),
                    const Text(
                      'PRIBADI',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.2,
                        color: Colors.white54,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    PlayerAvatar(
                      path: protagonistPath(characterStem),
                      size: 56,
                      ring: accent,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 22,
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            isAntag ? 'Si Terbisik' : 'Warga Desa',
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (!isAntag)
                            Text(
                              characterTitle(characterStem),
                              style: const TextStyle(color: Colors.white60),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                if (isAntag)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _face(
                          'Wajah asli',
                          darkSeed == null ? null : darkCardPath(darkSeed!),
                          'Si Terbisik',
                          accent,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _face(
                          'Samaran di desa',
                          protagonistPath(characterStem),
                          characterStem == 'default'
                              ? 'Belum dipilih'
                              : characterTitle(characterStem),
                          EmbunColors.gold,
                        ),
                      ),
                    ],
                  )
                else if (ability != null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AbilityCardView(
                        def: ability,
                        used: abilityUsed,
                        width: 66,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${ability['name'] ?? 'Kemampuan'}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: EmbunColors.gold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              abilityUsed
                                  ? 'Sudah terpakai'
                                  : ability['kind'] == 'pasif'
                                  ? 'Pasif'
                                  : 'Sekali pakai · Siap',
                              style: TextStyle(
                                color: abilityUsed ? Colors.white54 : accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${ability['description'] ?? ''}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  const Text(
                    'Kemampuan belum tersedia.',
                    style: TextStyle(color: Colors.white60),
                  ),
                if (onInspectionHistory != null) ...[
                  const Divider(height: 26),
                  TextButton.icon(
                    icon: const GameIcon('logorhistory', size: 22),
                    label: const Text('Catatan pemeriksaan'),
                    onPressed: () {
                      Navigator.pop(context);
                      onInspectionHistory!();
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _face(String label, String? path, String title, Color color) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      const SizedBox(height: 10),
      SizedBox(
        height: 126,
        child: Center(
          child: path == null
              ? GameIcon('persona', size: 54)
              : CardArt(path: path, width: 84, glow: color),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    ],
  );
}
