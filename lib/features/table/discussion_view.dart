import 'package:flutter/material.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
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
  final List<Map<String, dynamic>> players;
  final List<Map<String, dynamic>> events;

  /// Sudah keluar dari desa: boleh membaca obrolan, tidak boleh menulis.
  final bool readOnly;

  const DiscussionView({
    super.key,
    required this.repo,
    required this.gameId,
    required this.day,
    required this.deadline,
    required this.iAmReady,
    required this.readyCount,
    required this.total,
    this.players = const [],
    this.events = const [],
    this.readOnly = false,
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
  Map<String, int> counts = {};

  static const _clueMarks = ['Bisik angin:', 'Kabar burung:'];

  /// Petunjuk dari kabar pagi pada siklus ini (3 hari terakhir).
  List<String> get _clues => [
    for (final e in widget.events)
      if (e['kind'] == 'kabar' &&
          (e['day'] as int? ?? 0) >= widget.day - 2 &&
          _clueMarks.any((m) => '${e['text']}'.startsWith(m)))
        '${e['text']}'
  ];

  String _nameOf(String id) {
    for (final p in widget.players) {
      if (p['user_id'] == id) return p['name'] as String;
    }
    return '?';
  }



  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  void _loadLogs() {
    widget.repo.effects(widget.gameId, widget.day).then((r) {
      if (mounted) setState(() => effectLogs = r);
    }).catchError((_) {});
    widget.repo.privateLogs(widget.gameId, widget.day).then((r) {
      if (mounted) setState(() => mySecrets = r);
    }).catchError((_) {});
    widget.repo.offeringCounts(widget.gameId, widget.day).then((r) {
      if (mounted) setState(() => counts = r);
    });
  }

  @override
  void didUpdateWidget(covariant DiscussionView old) {
    super.didUpdateWidget(old);
    if (old.day != widget.day) _loadLogs();
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
      if (mounted) {
        // Kembalikan tulisan yang gagal terkirim (kecuali sudah mengetik lagi).
        if (ctrl.text.isEmpty) ctrl.text = t;
        _toast(errMsg(e));
      }
    }
  }

  void _showEffectLogSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
                icon: 'logorhistory',
                title: 'Catatan Persembahan Hari ${widget.day}'),
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
                        GameIcon(bad ? 'alert' : 'helaidaun', size: 30),
                        const SizedBox(width: 10),
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
        SectionHeader(
          icon: 'discuss',
          title: 'Musyawarah Senja',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MedallionButton(
                icon: 'logorhistory',
                label: 'Log',
                size: 34,
                onTap: _showEffectLogSheet,
              ),
              const SizedBox(width: 6),
              Countdown(deadline: widget.deadline),
            ],
          ),
        ),
        for (final c in _clues)
          NoticeStrip(
              icon: 'announcement', text: c, accent: Colors.lightBlueAccent),
        if (counts.isNotEmpty) ...[
          const SizedBox(height: 6),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: GameIcon('donations', size: 30),
                ),
                for (final p in widget.players)
                  if (counts[p['user_id']] != null)
                    Container(
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: counts[p['user_id']]! >= 2
                              ? EmbunColors.gold
                              : EmbunColors.goldDim.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        '${_nameOf(p['user_id'] as String)} '
                            '${counts[p['user_id']]} kartu',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
              ],
            ),
          ),
        ],
        for (final s in mySecrets)
          NoticeStrip(
              icon: 'info', text: s['message'] as String, accent: EmbunColors.gold),
        const SizedBox(height: 6),
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
                            ? const Color(0xFF1F4A38)
                            : const Color(0xFF1B2523),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: mine
                              ? EmbunColors.gold.withValues(alpha: 0.4)
                              : Colors.white12,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m['name'] as String,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: mine
                                      ? EmbunColors.gold
                                      : EmbunColors.goldDim)),
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
        if (widget.readOnly)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Kamu sudah keluar dari desa. Kamu hanya bisa menonton.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          )
        else ...[
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
              const SizedBox(width: 8),
              MedallionButton(icon: 'kirim', size: 44, onTap: _send),
            ],
          ),
          const SizedBox(height: 6),
          EmbunButton(
            label: widget.iAmReady
                ? 'Menunggu... ${widget.readyCount}/${widget.total} siap'
                : 'Siap memilih',
            icon: widget.iAmReady ? 'wait' : 'vote',
            expand: true,
            onPressed: widget.iAmReady ? null : _ready,
          ),
        ],
      ],
    );
  }
}