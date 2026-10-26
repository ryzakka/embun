import 'package:flutter/material.dart';
import '../../data/game_repository.dart';
import 'countdown.dart';

class DiscussionView extends StatefulWidget {
  final GameRepository repo;
  final String gameId;
  final int day;
  final DateTime? deadline;
  final bool iAmReady;
  final int readyCount;
  final int total;

  const DiscussionView({
    super.key,
    required this.repo,
    required this.gameId,
    required this.day,
    required this.deadline,
    required this.iAmReady,
    required this.readyCount,
    required this.total,
  });

  @override
  State<DiscussionView> createState() => _DiscussionViewState();
}

class _DiscussionViewState extends State<DiscussionView> {
  final ctrl = TextEditingController();
  late final Stream<List<Map<String, dynamic>>> chatStream =
  widget.repo.chat(widget.gameId);

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _ready() async {
    try {
      await widget.repo.readyToVote(widget.gameId);
    } catch (e) {
      if (mounted) _toast(e.toString());
    }
  }

  Future<void> _send() async {
    final t = ctrl.text.trim();
    if (t.isEmpty) return;
    ctrl.clear();
    try {
      await widget.repo.sendMessage(widget.gameId, t);
    } catch (e) {
      if (mounted) _toast(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.forum, size: 20),
            const SizedBox(width: 8),
            const Text('Musyawarah Senja',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            Countdown(deadline: widget.deadline),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Ada pengkhianat di antara kalian. Siapa yang mencurigakan?',
          style: TextStyle(fontSize: 12, color: Colors.white60),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: chatStream,
            builder: (context, s) {
              final msgs = (s.data ?? [])
                  .where((m) => m['day'] == widget.day)
                  .toList()
                  .reversed
                  .toList();
              if (msgs.isEmpty) {
                return const Center(
                    child: Text('Belum ada yang bicara...',
                        style: TextStyle(color: Colors.white38)));
              }
              return ListView.builder(
                reverse: true,
                itemCount: msgs.length,
                itemBuilder: (_, i) {
                  final m = msgs[i];
                  final mine = m['user_id'] == widget.repo.myId;
                  return Align(
                    alignment:
                    mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      constraints: const BoxConstraints(maxWidth: 360),
                      decoration: BoxDecoration(
                        color: mine
                            ? const Color(0xFF2E5A4C)
                            : const Color(0xFF2A2F36),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m['name'] as String,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white54)),
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
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                maxLength: 200,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  hintText: 'Tulis sesuatu...',
                  counterText: '',
                  isDense: true,
                ),
              ),
            ),
            IconButton(onPressed: _send, icon: const Icon(Icons.send)),
          ],
        ),
        const SizedBox(height: 4),
        FilledButton(
          onPressed: widget.iAmReady ? null : _ready,
          child: Text(widget.iAmReady
              ? 'Menunggu... ${widget.readyCount}/${widget.total} siap'
              : 'Siap memilih'),
        ),
      ],
    );
  }
}