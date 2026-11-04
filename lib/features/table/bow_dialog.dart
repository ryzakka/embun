import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'player_status.dart';

/// Dialog pemilihan sasaran Busur Terakhir. Mengembalikan user_id sasaran,
/// atau null bila dibatalkan. Peringatan risiko selalu tampil: salah sasaran
/// berarti pemakainya yang kehilangan satu nyawa.
Future<String?> showBowTargetDialog(
    BuildContext context, {
      required List<Map<String, dynamic>> players,
      required String myId,
    }) =>
    showDialog<String>(
      context: context,
      builder: (_) => _BowTargetDialog(
        others: [
          for (final p in players)
            if (!isOut(p) && p['user_id'] != myId) p,
        ],
      ),
    );

class _BowTargetDialog extends StatefulWidget {
  final List<Map<String, dynamic>> others;
  const _BowTargetDialog({required this.others});

  @override
  State<_BowTargetDialog> createState() => _BowTargetDialogState();
}

class _BowTargetDialogState extends State<_BowTargetDialog> {
  String? target;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: OrnatePanel(
          accent: EmbunColors.gold,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Bidik siapa?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: EmbunColors.gold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bila sasaranmu Si Terbisik, nyawanya berkurang 1. Bila '
                      'ia warga, panah berbalik dan KAMU yang kehilangan 1 '
                      'nyawa. Desa akan mendengar nama yang terkena saat malam '
                      'tiba, tanpa tahu tembakanmu tepat atau meleset.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12.5, height: 1.4, color: Colors.white70),
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final p in widget.others)
                      ChoiceChip(
                        avatar: PlayerAvatar(
                          path: protagonistPath(p['character_card'] as String),
                          size: 24,
                        ),
                        label: Text(p['name'] as String),
                        selected: target == p['user_id'],
                        showCheckmark: false,
                        selectedColor: EmbunColors.gold.withValues(alpha: 0.28),
                        onSelected: (_) =>
                            setState(() => target = p['user_id'] as String),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                EmbunButton(
                  label: 'Lepaskan panah',
                  icon: 'centang',
                  expand: true,
                  onPressed:
                  target == null ? null : () => Navigator.pop(context, target),
                ),
                const SizedBox(height: 8),
                EmbunButton(
                  label: 'Batal',
                  icon: 'silang',
                  kind: EmbunButtonKind.secondary,
                  expand: true,
                  height: 46,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}