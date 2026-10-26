import 'package:flutter/material.dart';
import '../../data/game_repository.dart';

// Harus sama persis dengan daftar putih di fungsi send_emote (SQL).
const kEmotes = ['🙂', '😠', '🤔', '😰', '🙏', '👀', '🔥', '💧'];

class EmotePanel extends StatefulWidget {
  final GameRepository repo;
  final String gameId;
  final int day;
  final List<Map<String, dynamic>> players;

  const EmotePanel({
    super.key,
    required this.repo,
    required this.gameId,
    required this.day,
    required this.players,
  });

  @override
  State<EmotePanel> createState() => _EmotePanelState();
}

class _EmotePanelState extends State<EmotePanel> {
  late final Stream<List<Map<String, dynamic>>> stream =
  widget.repo.emotes(widget.gameId);
  String? target;
  bool busy = false;

  String _name(String? id) {
    for (final p in widget.players) {
      if (p['user_id'] == id) return p['name'] as String;
    }
    return '?';
  }

  Future<void> _send(String emoji) async {
    setState(() => busy = true);
    try {
      await widget.repo.sendEmote(widget.gameId, emoji, target: target);
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
    final others = widget.players
        .where((p) => p['user_id'] != widget.repo.myId)
        .toList();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, s) {
        final today =
        (s.data ?? []).where((e) => e['day'] == widget.day).toList();
        final mine =
            today.where((e) => e['user_id'] == widget.repo.myId).length;
        final left = 5 - mine;
        final recent = today.reversed.take(8).toList();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 30,
              child: recent.isEmpty
                  ? const Align(
                alignment: Alignment.centerLeft,
                child: Text('Belum ada isyarat hari ini',
                    style:
                    TextStyle(fontSize: 12, color: Colors.white54)),
              )
                  : ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recent.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final e = recent[i];
                  final tgt = e['target_id'] as String?;
                  final text =
                      '${_name(e['user_id'] as String?)} ${e['emoji']}'
                      '${tgt == null ? '' : ' → ${_name(tgt)}'}';
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(text, style: const TextStyle(fontSize: 13)),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: const Text('Semua'),
                      selected: target == null,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => target = null),
                    ),
                  ),
                  for (final p in others)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(p['name'] as String),
                        selected: target == p['user_id'],
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) =>
                            setState(() => target = p['user_id'] as String),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final e in kEmotes)
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: busy || left <= 0 ? null : () => _send(e),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Opacity(
                        opacity: left <= 0 ? 0.35 : 1,
                        child: Text(e, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                Text('Sisa $left',
                    style:
                    const TextStyle(fontSize: 12, color: Colors.white60)),
              ],
            ),
          ],
        );
      },
    );
  }
}