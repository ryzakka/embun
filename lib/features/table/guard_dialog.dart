import 'package:flutter/material.dart';

import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'player_status.dart';

/// Memilih penerima Perisai Malam, termasuk diri sendiri.
Future<String?> showGuardTargetDialog(
  BuildContext context, {
  required List<Map<String, dynamic>> players,
  required String myId,
}) => showDialog<String>(
  context: context,
  builder: (_) => _GuardTargetDialog(
    players: players.where((p) => !isOut(p)).toList(),
    myId: myId,
  ),
);

class _GuardTargetDialog extends StatefulWidget {
  final List<Map<String, dynamic>> players;
  final String myId;

  const _GuardTargetDialog({required this.players, required this.myId});

  @override
  State<_GuardTargetDialog> createState() => _GuardTargetDialogState();
}

class _GuardTargetDialogState extends State<_GuardTargetDialog> {
  String? _target;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: OrnatePanel(
        accent: EmbunColors.leaf,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.shield_rounded,
                color: EmbunColors.leaf,
                size: 36,
              ),
              const SizedBox(height: 8),
              const Text(
                'Lindungi siapa?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: EmbunColors.gold,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Perisai menahan serangan malam yang menyasar pemain pilihanmu '
                'sampai akhir sesi. Nama penjaga dirahasiakan dari penerima.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 16),
              for (final player in widget.players)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Semantics(
                    selected: _target == player['user_id'],
                    child: OutlinedButton(
                      onPressed: () =>
                          setState(() => _target = player['user_id'] as String),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(12),
                        foregroundColor: Colors.white,
                        backgroundColor: _target == player['user_id']
                            ? EmbunColors.leaf.withValues(alpha: 0.18)
                            : Colors.transparent,
                        side: BorderSide(
                          color: _target == player['user_id']
                              ? EmbunColors.leaf
                              : Colors.white24,
                        ),
                      ),
                      child: Row(
                        children: [
                          PlayerAvatar(
                            path: protagonistPath(
                              player['character_card'] as String? ?? 'default',
                            ),
                            size: 36,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${player['name'] ?? 'Pemain'}'
                              '${player['user_id'] == widget.myId ? ' (kamu)' : ''}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _target == player['user_id']
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            color: _target == player['user_id']
                                ? EmbunColors.leaf
                                : Colors.white38,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              EmbunButton(
                label: 'Pasang perisai',
                icon: 'centang',
                expand: true,
                onPressed: _target == null
                    ? null
                    : () => Navigator.pop(context, _target),
              ),
              const SizedBox(height: 8),
              EmbunButton(
                label: 'Batal',
                icon: 'silang',
                expand: true,
                kind: EmbunButtonKind.secondary,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
