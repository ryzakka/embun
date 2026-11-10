import 'package:flutter/material.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'chat_sheet.dart' show sortChat;
import 'day_chrome.dart';

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
  final bool showBisikanReports;

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
    this.showBisikanReports = true,
  });

  @override
  State<DiscussionView> createState() => _DiscussionViewState();
}

class _DiscussionViewState extends State<DiscussionView> {
  final ctrl = TextEditingController();
  late final Stream<List<Map<String, dynamic>>> chatStream = widget.repo.chat(
    widget.gameId,
  );
  List<Map<String, dynamic>> effectLogs = [];
  List<String> mySecrets = [];
  bool _privateNotesFailed = false;
  int _logRequest = 0;
  Map<String, int> counts = {};

  static const _clueMarks = ['Bisik angin:', 'Kabar burung:'];
  static const _rumorPrefix = 'Desas-desus: ';
  static const _reportPrefix = 'Bisikan: ';

  bool _isRumor(String note) => note.startsWith(_rumorPrefix);
  bool _isReport(String note) => note.startsWith(_reportPrefix);

  List<String> get _visibleNotes => widget.showBisikanReports
      ? mySecrets
      : mySecrets.where((note) => !_isReport(note)).toList();

  String _privateNoteText(String note) =>
      _isReport(note) ? note.substring(_reportPrefix.length) : note;

  /// Petunjuk dari kabar pagi pada siklus ini (3 hari terakhir).
  List<String> get _clues => [
    for (final e in widget.events)
      if (e['kind'] == 'kabar' &&
          (e['day'] as int? ?? 0) >= widget.day - 2 &&
          _clueMarks.any((m) => '${e['text']}'.startsWith(m)))
        '${e['text']}',
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
    final request = ++_logRequest;
    bool current() => mounted && request == _logRequest;
    widget.repo
        .effects(widget.gameId, widget.day)
        .then((r) {
          if (current()) setState(() => effectLogs = r);
        })
        .catchError((_) {});
    _loadPrivateNotes(request);
    widget.repo.offeringCounts(widget.gameId, widget.day).then((r) {
      if (current()) setState(() => counts = r);
    });
  }

  Future<void> _loadPrivateNotes(int request) async {
    try {
      final rows = await widget.repo.privateLogs(widget.gameId, widget.day);
      if (!mounted || request != _logRequest) return;
      setState(() {
        mySecrets = [for (final row in rows) row['message'] as String];
        _privateNotesFailed = false;
      });
    } catch (_) {
      if (mounted && request == _logRequest) {
        setState(() => _privateNotesFailed = true);
      }
    }
  }

  @override
  void didUpdateWidget(covariant DiscussionView old) {
    super.didUpdateWidget(old);
    if (old.day != widget.day) {
      effectLogs = [];
      mySecrets = [];
      counts = {};
      _privateNotesFailed = false;
      _loadLogs();
    }
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
              title: 'Catatan Persembahan Hari ${widget.day}',
            ),
            const SizedBox(height: 10),
            if (effectLogs.isEmpty)
              const Text(
                'Tidak ada efek tercatat.',
                style: TextStyle(color: Colors.white54),
              )
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

  void _showNotes(List<String> clues) {
    final privateNotes = _visibleNotes;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            const SectionHeader(icon: 'info', title: 'Catatan musyawarah'),
            if (privateNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('CATATAN PRIBADI', style: dayOverline),
              for (final secret in privateNotes)
                NoticeStrip(
                  icon: 'lock',
                  text: _isReport(secret)
                      ? 'Laporan Bisikan\n${_privateNoteText(secret)}'
                      : secret,
                  accent: _isReport(secret)
                      ? EmbunColors.mist
                      : EmbunColors.gold,
                ),
            ],
            if (clues.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('PETUNJUK DESA', style: dayOverline),
              for (final clue in clues)
                NoticeStrip(
                  icon: 'announcement',
                  text: clue,
                  accent: Colors.lightBlueAccent,
                ),
            ],
            if (counts.isNotEmpty) _offeringChips(),
          ],
        ),
      ),
    );
  }

  Widget _privateSpotlight(String note, List<String> clues) {
    final isReport = _isReport(note);
    final accent = isReport ? EmbunColors.mist : EmbunColors.gold;
    return Padding(
      padding: const EdgeInsets.fromLTRB(3, 6, 3, 2),
      child: Material(
        color: accent.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: accent.withValues(alpha: 0.35)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _showNotes(clues),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
            child: Row(
              children: [
                Icon(Icons.lock_outline, color: accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isReport ? 'Laporan Bisikan' : 'Kabar pribadi',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                      Text(
                        _privateNoteText(note),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: dayCaption.copyWith(color: EmbunColors.cream),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: accent, size: 19),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _offeringChips() => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Persembahan semalam',
          style: TextStyle(fontSize: 11, color: Colors.white54),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in widget.players)
              if (counts[p['user_id']] != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
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

  Widget _chatArea() => StreamBuilder<List<Map<String, dynamic>>>(
    stream: chatStream,
    builder: (context, s) {
      final msgs = sortChat(
        (s.data ?? []).where((m) => m['day'] == widget.day).toList(),
      ).reversed.toList();
      if (msgs.isEmpty) {
        return const Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GameIcon('discuss', size: 34),
                SizedBox(height: 8),
                Text(
                  'Belum ada yang bicara',
                  style: TextStyle(color: Colors.white54),
                ),
                SizedBox(height: 2),
                Text(
                  'Mulailah dengan menyebut siapa yang kamu curigai.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: Colors.white38),
                ),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              constraints: const BoxConstraints(maxWidth: 360),
              decoration: BoxDecoration(
                color: mine ? const Color(0xFF1F4A38) : const Color(0xFF1B2523),
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
                      child: Text(
                        m['name'] as String,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: EmbunColors.gold,
                        ),
                      ),
                    ),
                  Text(m['body'] as String),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final clues = _clues;
    final privateNotes = _visibleNotes;
    final notes = clues.length + privateNotes.length + (counts.isEmpty ? 0 : 1);
    final spotlight =
        privateNotes.where(_isRumor).firstOrNull ??
        privateNotes.where(_isReport).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: tableEdge(EmbunColors.gold),
          child: Row(
            children: [
              const GameIcon('discuss', size: 25),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'Musyawarah Senja',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              if (notes > 0)
                Badge(
                  label: Text('$notes'),
                  child: IconButton(
                    tooltip: 'Catatan musyawarah',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _showNotes(clues),
                    icon: const GameIcon('info', size: 22),
                  ),
                ),
              IconButton(
                tooltip: 'Log persembahan',
                visualDensity: VisualDensity.compact,
                onPressed: _showEffectLogSheet,
                icon: const GameIcon('logorhistory', size: 23),
              ),
            ],
          ),
        ),
        if (spotlight != null)
          _privateSpotlight(spotlight, clues)
        else if (_privateNotesFailed)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _loadPrivateNotes(_logRequest),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Muat ulang catatan pribadi'),
            ),
          ),
        Expanded(child: _chatArea()),
        if (widget.readOnly)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Kamu sudah keluar dari desa. Kamu hanya bisa menonton.',
              textAlign: TextAlign.center,
              style: dayCaption,
            ),
          )
        else
          Container(
            decoration: tableEdge(EmbunColors.gold, top: true),
            padding: const EdgeInsets.fromLTRB(4, 4, 2, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    maxLength: 200,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Tulis pesan…',
                      counterText: '',
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Kirim pesan',
                  onPressed: _send,
                  icon: const GameIcon('kirim', size: 23),
                ),
                const SizedBox(width: 5),
                SizedBox(
                  width: 124,
                  child: EmbunButton(
                    label: widget.iAmReady
                        ? 'Siap ${widget.readyCount}/${widget.total}'
                        : 'Siap memilih',
                    height: 40,
                    expand: true,
                    onPressed: widget.iAmReady ? null : _ready,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
