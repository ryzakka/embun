import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'chat_sheet.dart' show sortChat;
import 'day_chrome.dart';
import 'meeting_player_grid.dart';
import 'player_status.dart';

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
  final VoidCallback? onAbility;
  final ValueChanged<Map<String, dynamic>>? onPlayerTap;
  final ValueChanged<Rect?>? onChatBounds;

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
    this.onAbility,
    this.onPlayerTap,
    this.onChatBounds,
  });

  @override
  State<DiscussionView> createState() => _DiscussionViewState();
}

class _DiscussionViewState extends State<DiscussionView> {
  final ctrl = TextEditingController();
  late final Stream<List<Map<String, dynamic>>> chatStream = widget.repo.chat(
    widget.gameId,
  );
  List<Map<String, dynamic>> _messages = [];
  final _seenChat = <String>{};
  bool _chatPrimed = false, _chatTab = false, _wideLayout = false;
  int _unread = 0;
  String? _speaker;
  StreamSubscription<List<Map<String, dynamic>>>? _chatSub;
  Timer? _speakerTimer;
  final _chatBox = GlobalKey();
  Rect? _lastBounds;
  bool _measuring = false;
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
    _chatSub = chatStream.listen((rows) {
      if (!mounted) return;
      final relevant = sortChat(
        rows.where((m) => m['day'] == widget.day).toList(),
      );
      final fresh = relevant
          .where((m) => !_seenChat.contains('${m['id']}'))
          .toList();
      _seenChat.addAll(relevant.map((m) => '${m['id']}'));
      if (_chatPrimed && fresh.isNotEmpty) {
        _speaker = '${fresh.last['user_id']}';
        if (!_chatTab && !_wideLayout)
          _unread += fresh
              .where((m) => m['user_id'] != widget.repo.myId)
              .length;
        _speakerTimer?.cancel();
        _speakerTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _speaker = null);
        });
      }
      _chatPrimed = true;
      setState(() => _messages = relevant.reversed.toList());
    }, onError: (_) {});
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
    _chatSub?.cancel();
    _speakerTimer?.cancel();
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
    if (widget.readOnly) return;
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

  void _measureChat() {
    if (_measuring) return;
    _measuring = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measuring = false;
      if (!mounted) return;
      final box = _chatBox.currentContext?.findRenderObject();
      final bounds = box is RenderBox && box.hasSize
          ? box.localToGlobal(Offset.zero) & box.size
          : null;
      if (bounds == _lastBounds) return;
      _lastBounds = bounds;
      widget.onChatBounds?.call(bounds);
    });
  }

  Widget _chatArea() {
    final msgs = _messages;
    if (msgs.isEmpty)
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
              SizedBox(height: 4),
              Text(
                'Sampaikan petunjuk atau kecurigaanmu.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(10),
      itemCount: msgs.length,
      itemBuilder: (context, i) {
        final m = msgs[i], mine = m['user_id'] == widget.repo.myId;
        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 390),
            margin: const EdgeInsets.only(bottom: 7),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: mine ? const Color(0xFF1F4A38) : const Color(0xFF1B2523),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: mine
                    ? EmbunColors.gold.withValues(alpha: .35)
                    : Colors.white12,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${m['name']}',
                  style: const TextStyle(
                    color: EmbunColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text('${m['body']}'),
              ],
            ),
          ),
        );
      },
    );
  }

  void _inspect(Map<String, dynamic> p) {
    if (widget.onPlayerTap != null) {
      widget.onPlayerTap!(p);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${p['name']}'),
        content: Text(
          isOut(p)
              ? 'Sudah tersingkir'
              : isJailed(p, widget.day)
              ? 'Sedang dikurung'
              : 'Masih di desa · ${livesLeft(p)} nyawa',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _board() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
        child: Text(
          '${widget.players.where((p) => !isOut(p)).length} bertahan · ${widget.players.where(isOut).length} tersingkir',
          style: dayCaption,
        ),
      ),
      Expanded(
        child: MeetingPlayerGrid(
          players: widget.players,
          day: widget.day,
          myId: widget.repo.myId,
          speakingId: _speaker,
          onInspect: _inspect,
        ),
      ),
    ],
  );

  Widget _composer(bool chatVisible) {
    if (widget.readOnly)
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          'Kamu sudah keluar dari desa. Kamu hanya bisa menonton.',
          textAlign: TextAlign.center,
          style: dayCaption,
        ),
      );
    return Container(
      decoration: tableEdge(EmbunColors.gold, top: true),
      padding: const EdgeInsets.all(5),
      child: Row(
        children: [
          if (chatVisible) ...[
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
          ] else
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text('Buka Obrolan untuk berdiskusi', style: dayCaption),
              ),
            ),
          SizedBox(
            width: 124,
            child: EmbunButton(
              label: widget.iAmReady
                  ? 'Siap ${widget.readyCount}/${widget.total}'
                  : 'Siap memilih',
              height: 42,
              expand: true,
              onPressed: widget.iAmReady ? null : _ready,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _measureChat();
    final clues = _clues,
        notes = clues.length + _visibleNotes.length + (counts.isEmpty ? 0 : 1);
    final spotlight =
        _visibleNotes.where(_isRumor).firstOrNull ??
        _visibleNotes.where(_isReport).firstOrNull;
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
              if (widget.onAbility != null)
                IconButton(
                  tooltip: 'Kemampuan',
                  onPressed: widget.onAbility,
                  icon: const Icon(
                    Icons.auto_awesome,
                    color: EmbunColors.gold,
                    size: 22,
                  ),
                ),
              if (notes > 0)
                Badge(
                  label: Text('$notes'),
                  child: IconButton(
                    tooltip: 'Catatan musyawarah',
                    onPressed: () => _showNotes(clues),
                    icon: const GameIcon('info', size: 22),
                  ),
                ),
              IconButton(
                tooltip: 'Log persembahan',
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
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth >= 760;
              _wideLayout = wide;
              final chat = SizedBox.expand(key: _chatBox, child: _chatArea());
              if (wide)
                return Row(
                  children: [
                    Expanded(flex: 5, child: _board()),
                    const VerticalDivider(width: 14),
                    Expanded(flex: 4, child: chat),
                  ],
                );
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          key: const ValueKey('discussion-players-tab'),
                          onPressed: () => setState(() => _chatTab = false),
                          child: Text(
                            'Pemain',
                            style: TextStyle(
                              color: !_chatTab
                                  ? EmbunColors.gold
                                  : Colors.white54,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          key: const ValueKey('discussion-chat-tab'),
                          onPressed: () => setState(() {
                            _chatTab = true;
                            _unread = 0;
                          }),
                          child: Badge(
                            isLabelVisible: _unread > 0,
                            label: Text('$_unread'),
                            child: Text(
                              'Obrolan',
                              style: TextStyle(
                                color: _chatTab
                                    ? EmbunColors.gold
                                    : Colors.white54,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Expanded(child: _chatTab ? chat : _board()),
                ],
              );
            },
          ),
        ),
        LayoutBuilder(
          builder: (context, box) => _composer(box.maxWidth >= 760 || _chatTab),
        ),
      ],
    );
  }
}
