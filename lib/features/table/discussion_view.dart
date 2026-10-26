import 'package:flutter/material.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import 'chat_sheet.dart' show sortChat;
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
  List<Map<String, dynamic>> effectLogs = [];
  List<Map<String, dynamic>> mySecrets = [];



  @override
  void initState() {
    super.initState();
    widget.repo.effects(widget.gameId, widget.day).then((r) {
      if (mounted) setState(() => effectLogs = r);
    });
    widget.repo.privateLogs(widget.gameId, widget.day).then((r) {
      if (mounted) setState(() => mySecrets = r);
    });
  }

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
      if (mounted) _toast(errMsg(e));
    }
  }

  Future<void> _send() async {
    final t = ctrl.text.trim();
    if (t.isEmpty) return;
    ctrl.clear();
    try {
      await widget.repo.sendMessage(widget.gameId, t);
    } catch (e) {
      if (mounted) _toast(errMsg(e));
    }
  }

  void _showEffectLogSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14221F),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Catatan Persembahan Hari ${widget.day}',
                style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (effectLogs.isEmpty)
              const Text('Tidak ada efek tercatat.',
                  style: TextStyle(color: Colors.white54))
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: effectLogs.length,
                  separatorBuilder: (_, _) => const Divider(height: 12),
                  itemBuilder: (_, i) {
                    final e = effectLogs[i];
                    final bad = e['kind'] == 'bad';
                    return Row(
                      children: [
                        Icon(
                          bad ? Icons.warning_amber : Icons.eco,
                          size: 18,
                          color: bad ? Colors.purpleAccent : Colors.greenAccent,
                        ),
                        const SizedBox(width: 8),
                        // Jumlah daun per baris sengaja tidak ditampilkan:
                        // akan membocorkan efek yang disamarkan Topeng Warga.
                        Expanded(child: Text(e['label'] as String)),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
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
            TextButton.icon(
              onPressed: _showEffectLogSheet,
              icon: const Icon(Icons.history, size: 16),
              label: const Text('Log Efek', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 6),
            Countdown(deadline: widget.deadline),
          ],
        ),
        if (mySecrets.isNotEmpty)
          for (final s in mySecrets)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF332B10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amberAccent),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb,
                      size: 16, color: Colors.amberAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(s['message'] as String,
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
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
              final msgs = sortChat((s.data ?? [])
                  .where((m) => m['day'] == widget.day)
                  .toList())
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