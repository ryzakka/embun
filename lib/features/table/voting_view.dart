import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../../data/game_repository.dart';
import '../common/art.dart';

class VotingView extends StatefulWidget {
  final GameRepository repo;
  final String gameId;
  final List<Map<String, dynamic>> players;

  const VotingView({
    super.key,
    required this.repo,
    required this.gameId,
    required this.players,
  });

  @override
  State<VotingView> createState() => _VotingViewState();
}

class _VotingViewState extends State<VotingView> {
  String? target;
  bool busy = false;

  Future<void> _submit(String? t) async {
    setState(() => busy = true);
    try {
      await widget.repo.submitVote(widget.gameId, t);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final others =
    widget.players.where((p) => p['user_id'] != widget.repo.myId).toList();
    final need = widget.players.length ~/ 2 + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Siapa Si Terbisik?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(
          'Butuh $need suara. Menuduh warga yang salah akan mengurungnya '
              'sehari dan Hayu kehilangan 1 daun.',
          style: const TextStyle(fontSize: 12, color: Colors.white60),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: [
              for (final p in others)
                Builder(builder: (_) {
                  final card = p['character_card'] as String;
                  final id = p['user_id'] as String;
                  return ListTile(
                    selected: target == id,
                    selectedTileColor: Colors.amber.withOpacity(0.15),
                    leading: PlayerAvatar(
                      path: protagonistPath(card),
                      size: 46,
                      ring: target == id ? Colors.amber : Colors.white38,
                    ),
                    title: Text(p['name'] as String),
                    subtitle: Text(characterTitle(card)),
                    trailing: target == id
                        ? const Icon(Icons.check_circle, color: Colors.amber)
                        : null,
                    onTap: busy ? null : () => setState(() => target = id),
                  );
                }),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: busy || target == null ? null : () => _submit(target),
              child: const Text('Kunci suara'),
            ),
            OutlinedButton(
              onPressed: busy ? null : () => _submit(null),
              child: const Text('Tidak memilih'),
            ),
          ],
        ),
      ],
    );
  }
}