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

  bool _notesOpen = true;

  /// Catatan sesi: petunjuk desa, bisikan pribadi, dan siapa mempersembahkan
  /// berapa kartu. Satu panel yang bisa dilipat supaya obrolan tetap lega.
  Widget _notesPanel() {
    final clues = _clues;
    final n = clues.length + mySecrets.length + (counts.isEmpty ? 0 : 1);
    if (n == 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: EmbunColors.goldDim.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _notesOpen = !_notesOpen),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  const GameIcon('info', size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Catatan untuk musyawarah',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  Text('$n',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white54)),
                  Icon(
                      _notesOpen
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: Colors.white60),
                ],
              ),
            ),
          ),
          if (_notesOpen)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 190),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final c in clues)
                      NoticeStrip(
                          icon: 'announcement',
                          text: c,
                          accent: Colors.lightBlueAccent),
                    for (final s in mySecrets)
                      NoticeStrip(
                          icon: 'info',
                          text: s['message'] as String,
                          accent: EmbunColors.gold),
                    if (counts.isNotEmpty) _offeringChips(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _offeringChips() => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Persembahan semalam',
            style: TextStyle(fontSize: 11, color: Colors.white54)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in widget.players)
              if (counts[p['user_id']] != null)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    '${_nameOf(p['user_id'] as String)} · '
                        '${counts[p['user_id']]} kartu',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                ),
          ],
        ),
      ],
    ),
  );

  Widget _chatArea() => Container(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.28),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white10),
    ),
    clipBehavior: Clip.antiAlias,
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
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.forum_outlined, size: 34, color: Colors.white24),
                  SizedBox(height: 8),
                  Text('Belum ada yang bicara',
                      style: TextStyle(color: Colors.white54)),
                  SizedBox(height: 2),
                  Text('Mulailah dengan menyebut siapa yang kamu curigai.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: Colors.white38)),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          itemCount: msgs.length,
          itemBuilder: (_, i) {
            final m = msgs[i];
            final mine = m['user_id'] == widget.repo.myId;
            // Pesan lebih lama ada di indeks berikutnya (daftar terbalik).
            final older = i + 1 < msgs.length ? msgs[i + 1] : null;
            final head = older == null || older['user_id'] != m['user_id'];
            return Align(
              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: EdgeInsets.only(top: head ? 10 : 2),
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                constraints: const BoxConstraints(maxWidth: 360),
                decoration: BoxDecoration(
                  color: mine
                      ? const Color(0xFF1F4A38)
                      : const Color(0xFF1B2523),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(!mine && head ? 4 : 14),
                    topRight: Radius.circular(mine && head ? 4 : 14),
                    bottomLeft: const Radius.circular(14),
                    bottomRight: const Radius.circular(14),
                  ),
                  border: Border.all(
                    color: mine
                        ? EmbunColors.gold.withValues(alpha: 0.4)
                        : Colors.white12,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (head && !mine)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(m['name'] as String,
                            style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: EmbunColors.gold)),
                      ),
                    Text(m['body'] as String),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
        const Padding(
          padding: EdgeInsets.fromLTRB(2, 2, 2, 0),
          child: Text(
            'Ada pengkhianat di antara kalian. Siapa yang mencurigakan?',
            style: TextStyle(fontSize: 12, color: Colors.white60),
          ),
        ),
        _notesPanel(),
        const SizedBox(height: 8),
        Expanded(child: _chatArea()),
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
          Container(
            padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                  color: EmbunColors.goldDim.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    maxLength: 200,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Tulis sesuatu...',
                      counterText: '',
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
                MedallionButton(icon: 'kirim', size: 42, onTap: _send),
              ],
            ),
          ),
          const SizedBox(height: 8),
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