import 'package:flutter/material.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';

const _generalQuick = [
  'Aku beli kartu baik 🌿',
  'Aku belum beli apa-apa',
  'Jangan buru-buru menuduh',
  'Ada yang punya Lentera Kunang?',
  'Siapa yang tadi memberi embun?',
];

List<String> _aboutQuick(String n) => [
  'Aku curiga $n',
  'Aku percaya $n',
  '$n, kamu beli apa?',
  'Terima kasih, $n 🙏',
];

/// Obrolan yang bisa dibuka di semua fase (kecuali layar efek).
Future<void> showChatSheet(
    BuildContext context, {
      required GameRepository repo,
      required String gameId,
      required List<Map<String, dynamic>> players,
    }) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14221F),
      builder: (_) => _ChatSheet(repo: repo, gameId: gameId, players: players),
    );

class _ChatSheet extends StatefulWidget {
  final GameRepository repo;
  final String gameId;
  final List<Map<String, dynamic>> players;
  const _ChatSheet(
      {required this.repo, required this.gameId, required this.players});

  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<_ChatSheet> {
  final ctrl = TextEditingController();
  late final Stream<List<Map<String, dynamic>>> stream =
  widget.repo.chat(widget.gameId);
  String? about; // user_id yang dibicarakan
  String? err;

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    setState(() => err = null);
    try {
      await widget.repo.sendMessage(widget.gameId, t);
    } catch (e) {
      if (mounted) setState(() => err = errMsg(e));
    }
  }

  void _sendTyped() {
    final t = ctrl.text;
    ctrl.clear();
    _send(t);
  }

  String? _nameOf(String? id) {
    for (final p in widget.players) {
      if (p['user_id'] == id) return p['name'] as String;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final inset = mq.viewInsets.bottom;
    final others =
    widget.players.where((p) => p['user_id'] != widget.repo.myId).toList();
    final aboutName = _nameOf(about);
    final phrases =
    aboutName == null ? _generalQuick : _aboutQuick(aboutName);

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SizedBox(
        height: (mq.size.height - inset) * 0.8,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.forum, size: 18),
                  SizedBox(width: 8),
                  Text('Obrolan Desa',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: stream,
                  builder: (context, s) {
                    final msgs = (s.data ?? []).reversed.toList();
                    if (msgs.isEmpty) {
                      return const Center(
                        child: Text('Belum ada yang bicara...',
                            style: TextStyle(color: Colors.white38)),
                      );
                    }
                    return ListView.builder(
                      reverse: true,
                      itemCount: msgs.length,
                      itemBuilder: (_, i) {
                        final m = msgs[i];
                        final mine = m['user_id'] == widget.repo.myId;
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            constraints: const BoxConstraints(maxWidth: 340),
                            decoration: BoxDecoration(
                              color: mine
                                  ? const Color(0xFF2E5A4C)
                                  : const Color(0xFF2A2F36),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${m['name']} · H${m['day']}',
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.white54)),
                                Text(m['body'] as String),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              if (err != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(err!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 12)),
                ),
              const SizedBox(height: 6),
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Text('Tentang:',
                            style: TextStyle(
                                fontSize: 11, color: Colors.white54)),
                      ),
                    ),
                    for (final p in others)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(p['name'] as String),
                          selected: about == p['user_id'],
                          visualDensity: VisualDensity.compact,
                          onSelected: (v) => setState(
                                  () => about = v ? p['user_id'] as String : null),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final q in phrases)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text(q, style: const TextStyle(fontSize: 12)),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _send(q),
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      maxLength: 200,
                      onSubmitted: (_) => _sendTyped(),
                      decoration: const InputDecoration(
                        hintText: 'Tulis sesuatu...',
                        counterText: '',
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                      onPressed: _sendTyped, icon: const Icon(Icons.send)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}