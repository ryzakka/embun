import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../common/art.dart';

const _generalQuick = [
  'Aku beli kartu baik 🌿',
  'Aku belum beli apa-apa',
  'Jangan buru-buru menuduh',
  'Ada yang punya Lentera Kunang?',
  'Siapa yang tadi memberi embun?',
];

const _lobbyQuick = [
  'Halo semuanya 👋',
  'Aku siap!',
  'Tunggu sebentar ya',
  'Ayo mulai!',
];

List<String> _aboutQuick(String n) => [
  'Aku curiga $n',
  'Aku percaya $n',
  '$n, kamu beli apa?',
  'Terima kasih, $n 🙏',
];

// Warna sorot tiap pemain (stabil menurut user_id). Milikku selalu emas.
const _palette = [
  Color(0xFF7FD3F7),
  Color(0xFF7FE0A0),
  Color(0xFFE0A07F),
  Color(0xFFB07CE8),
  Color(0xFFE07F9F),
  Color(0xFFD3E07F),
];

Color _accent(String? id, bool mine) {
  if (mine) return Colors.amberAccent;
  if (id == null) return Colors.white70;
  final h = id.codeUnits.fold<int>(0, (a, b) => a + b);
  return _palette[h % _palette.length];
}

DateTime _ts(Map<String, dynamic> m) =>
    DateTime.tryParse((m['created_at'] as String?) ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

/// Urutkan pesan dari yang terlama ke terbaru. Urutan dari stream tidak
/// bisa diandalkan, jadi selalu diurutkan sendiri di sisi klien.
List<Map<String, dynamic>> sortChat(List<Map<String, dynamic>> list) {
  final c = [...list];
  c.sort((a, b) {
    final r = _ts(a).compareTo(_ts(b));
    if (r != 0) return r;
    return ((a['id'] as String?) ?? '').compareTo((b['id'] as String?) ?? '');
  });
  return c;
}

String _hhmm(DateTime t) {
  final l = t.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:'
      '${l.minute.toString().padLeft(2, '0')}';
}

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
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        final inset = mq.viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: inset),
          child: SizedBox(
            height: (mq.size.height - inset) * 0.85,
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
                    child: ChatPanel(
                        repo: repo, gameId: gameId, players: players),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

/// Isi obrolan: panggung sorot (potret karakter pembicara muncul dramatis
/// tiap ada pesan baru), riwayat pesan, frasa cepat, dan kolom ketik.
/// Dipakai di sheet saat bermain dan di tab Obrolan lobi ([lobby] = true).
class ChatPanel extends StatefulWidget {
  final GameRepository repo;
  final String gameId;
  final List<Map<String, dynamic>> players;
  final bool lobby;
  const ChatPanel({
    super.key,
    required this.repo,
    required this.gameId,
    required this.players,
    this.lobby = false,
  });

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final ctrl = TextEditingController();
  final focus = FocusNode();
  final scroll = ScrollController();
  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  List<Map<String, dynamic>> data = [];
  final Set<String> _known = {};
  bool _primed = false; // data pertama = riwayat, tidak disorot

  // Antrean sorotan
  final List<Map<String, dynamic>> _queue = [];
  Map<String, dynamic>? _spot;
  Timer? _spotTimer;
  bool _busy = false;

  String? about; // user_id yang dibicarakan
  String? err;
  bool showJump = false;

  @override
  void initState() {
    super.initState();
    _sub = widget.repo
        .chat(widget.gameId)
        .listen(_onData, onError: (_) {});
    scroll.addListener(() {
      if (!scroll.hasClients) return;
      // Daftar dibalik: offset 0 = pesan terbaru di bawah.
      final away = scroll.offset > 160;
      if (away != showJump) setState(() => showJump = away);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _spotTimer?.cancel();
    ctrl.dispose();
    focus.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _onData(List<Map<String, dynamic>> rows) {
    // Di dalam game, pesan lobi (hari 0) disembunyikan: nama aslinya
    // tertulis di sana dan bisa membocorkan identitas.
    final all = rows.where((m) => widget.lobby || m['day'] != 0).toList();
    final fresh = <Map<String, dynamic>>[];
    for (final m in sortChat(all)) {
      final id = m['id'] as String;
      if (_known.add(id) && _primed) fresh.add(m);
    }
    _primed = true;
    if (!mounted) return;
    setState(() => data = all);
    if (fresh.isNotEmpty) _enqueue(fresh);
  }

  void _enqueue(List<Map<String, dynamic>> msgs) {
    _queue.addAll(msgs);
    if (_queue.length > 4) _queue.removeRange(0, _queue.length - 4);
    if (!_busy) _next();
  }

  void _next() {
    if (!mounted) return;
    if (_queue.isEmpty) {
      _busy = false;
      // Biarkan pembicara terakhir tampil sebentar, lalu panggung menutup.
      _spotTimer?.cancel();
      _spotTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _spot = null);
      });
      return;
    }
    _spotTimer?.cancel();
    final m = _queue.removeAt(0);
    _busy = true;
    setState(() => _spot = m);
    final len = (m['body'] as String).length;
    var ms = (1600 + len * 45).clamp(2200, 5200).toInt();
    if (_queue.isNotEmpty) ms -= 600;
    _spotTimer = Timer(Duration(milliseconds: ms), _next);
  }

  void _toLatest() {
    if (!scroll.hasClients) return;
    scroll.animateTo(0,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _send(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    setState(() => err = null);
    try {
      await widget.repo.sendMessage(widget.gameId, t);
      _toLatest();
    } catch (e) {
      if (mounted) setState(() => err = errMsg(e));
    }
  }

  void _sendTyped() {
    final t = ctrl.text;
    ctrl.clear();
    _send(t);
    focus.requestFocus();
  }

  String? _nameOf(String? id) {
    for (final p in widget.players) {
      if (p['user_id'] == id) return p['name'] as String;
    }
    return null;
  }

  String? _cardOf(String? id) {
    for (final p in widget.players) {
      if (p['user_id'] == id) return p['character_card'] as String?;
    }
    return null;
  }

  Widget _message(Map<String, dynamic> m, List<Map<String, dynamic>> rev,
      int i, double maxW) {
    final uid = m['user_id'] as String?;
    final mine = uid == widget.repo.myId;
    final accent = _accent(uid, mine);
    // rev[0] = terbaru; rev[i + 1] = pesan sebelumnya (lebih lama).
    final older = i + 1 < rev.length ? rev[i + 1] : null;
    final newer = i > 0 ? rev[i - 1] : null;
    final groupStart = older == null || older['user_id'] != uid;
    final groupEnd = newer == null || newer['user_id'] != uid;
    final day = m['day'] as int?;
    final when = _ts(m);
    final stamp =
    widget.lobby || day == 0 ? _hhmm(when) : 'H$day · ${_hhmm(when)}';

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: BoxConstraints(maxWidth: maxW),
      decoration: BoxDecoration(
        color: mine ? const Color(0xFF2E5A4C) : const Color(0xFF2A2F36),
        border: Border.all(color: accent.withValues(alpha: mine ? 0.0 : 0.25)),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(!mine && groupStart ? 4 : 14),
          topRight: Radius.circular(mine && groupStart ? 4 : 14),
          bottomLeft: const Radius.circular(14),
          bottomRight: const Radius.circular(14),
        ),
      ),
      child: Text(m['body'] as String, style: const TextStyle(height: 1.3)),
    );

    final col = Column(
      crossAxisAlignment:
      mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (!mine && groupStart)
          Padding(
            padding: const EdgeInsets.only(bottom: 2, left: 2),
            child: Text(m['name'] as String,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accent)),
          ),
        bubble,
        if (groupEnd)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 2, right: 2),
            child: Text(stamp,
                style: const TextStyle(fontSize: 10, color: Colors.white38)),
          ),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(top: groupStart ? 8 : 2),
      child: Row(
        mainAxisAlignment:
        mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mine)
            SizedBox(
              width: 36,
              child: groupStart
                  ? PlayerAvatar(
                path: protagonistPath(_cardOf(uid) ?? 'default'),
                size: 30,
                ring: accent,
              )
                  : null,
            ),
          Flexible(child: col),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final others =
    widget.players.where((p) => p['user_id'] != widget.repo.myId).toList();
    final aboutName = _nameOf(about);
    final phrases = widget.lobby
        ? _lobbyQuick
        : (aboutName == null ? _generalQuick : _aboutQuick(aboutName));
    final rev = sortChat(data).reversed.toList();

    return LayoutBuilder(builder: (context, c) {
      // Panggung menyesuaikan tinggi yang tersedia; hilang bila terlalu sempit
      // (mis. keyboard terbuka di ponsel pendek).
      final stageH = c.maxHeight >= 520
          ? 168.0
          : c.maxHeight >= 400
          ? 120.0
          : 0.0;
      final spot = _spot;
      final spotUid = spot?['user_id'] as String?;
      final spotMine = spotUid == widget.repo.myId;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: spot == null || stageH == 0
                ? const SizedBox(width: double.infinity)
                : Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                height: stageH,
                width: double.infinity,
                child: _Stage(
                  msg: spot,
                  card: _cardOf(spotUid),
                  mine: spotMine,
                  accent: _accent(spotUid, spotMine),
                  height: stageH,
                ),
              ),
            ),
          ),
          Expanded(
            child: rev.isEmpty
                ? const Center(
              child: Text('Belum ada yang bicara...',
                  style: TextStyle(color: Colors.white38)),
            )
                : LayoutBuilder(builder: (context, lc) {
              final maxW = (lc.maxWidth - 36) * 0.82;
              return Stack(
                children: [
                  ListView.builder(
                    controller: scroll,
                    reverse: true,
                    padding: const EdgeInsets.only(bottom: 4),
                    itemCount: rev.length,
                    itemBuilder: (_, i) =>
                        _message(rev[i], rev, i, maxW),
                  ),
                  if (showJump)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: FloatingActionButton.small(
                        heroTag: null,
                        onPressed: _toLatest,
                        child: const Icon(Icons.keyboard_arrow_down),
                      ),
                    ),
                ],
              );
            }),
          ),
          if (err != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(err!,
                  style:
                  const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),
          const SizedBox(height: 6),
          if (!widget.lobby) ...[
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
                        onSelected: (v) => setState(() =>
                        about = v ? p['user_id'] as String : null),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
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
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  focusNode: focus,
                  maxLength: 200,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendTyped(),
                  decoration: InputDecoration(
                    hintText: 'Tulis sesuatu...',
                    counterText: '',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                onPressed: _sendTyped,
                icon: const Icon(Icons.send, size: 20),
              ),
            ],
          ),
        ],
      );
    });
  }
}

/// Panggung sorot ala visual novel: potret karakter meluncur masuk dari sisi
/// pembicara dengan cahaya warna pemain, plakat nama, dan teks yang diketik
/// huruf demi huruf. Pesan sendiri tampil di kanan, pesan orang lain di kiri.
class _Stage extends StatefulWidget {
  final Map<String, dynamic> msg;
  final String? card;
  final bool mine;
  final Color accent;
  final double height;
  const _Stage({
    required this.msg,
    required this.card,
    required this.mine,
    required this.accent,
    required this.height,
  });

  @override
  State<_Stage> createState() => _StageState();
}

class _StageState extends State<_Stage> with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650));
  late final AnimationController _type = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    _play();
  }

  @override
  void didUpdateWidget(covariant _Stage old) {
    super.didUpdateWidget(old);
    if (old.msg['id'] != widget.msg['id']) _play();
  }

  void _play() {
    final n = (widget.msg['body'] as String).runes.length;
    _type.duration =
        Duration(milliseconds: (n * 32).clamp(300, 2200).toInt());
    _in.forward(from: 0);
    _type.forward(from: 0);
  }

  @override
  void dispose() {
    _in.dispose();
    _type.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final mine = widget.mine;
    final cardW = (widget.height - 12) * 3 / 4;
    final body = widget.msg['body'] as String;
    final runes = body.runes.toList();

    final portrait = SlideTransition(
      position: Tween<Offset>(
          begin: Offset(mine ? 0.7 : -0.7, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: _in, curve: Curves.easeOutCubic)),
      child: FadeTransition(
        opacity: CurvedAnimation(
            parent: _in, curve: const Interval(0, 0.6, curve: Curves.easeOut)),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.82, end: 1.0).animate(
              CurvedAnimation(parent: _in, curve: Curves.easeOutBack)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: CardArt(
              path: protagonistPath(widget.card ?? 'default'),
              width: cardW,
              glow: accent,
            ),
          ),
        ),
      ),
    );

    final dialog = FadeTransition(
      opacity: CurvedAnimation(
          parent: _in, curve: const Interval(0.25, 1, curve: Curves.easeOut)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: mine ? Alignment.centerRight : Alignment.centerLeft,
            end: mine ? Alignment.centerLeft : Alignment.centerRight,
            colors: [
              accent.withValues(alpha: 0.22),
              Colors.black.withValues(alpha: 0.78),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.7)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (widget.msg['name'] as String).toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 1.6,
              ),
            ),
            Container(
              width: 36,
              height: 2,
              margin: const EdgeInsets.symmetric(vertical: 5),
              color: accent,
            ),
            AnimatedBuilder(
              animation: _type,
              builder: (_, __) {
                final n = (runes.length * _type.value).ceil();
                return Text(
                  String.fromCharCodes(runes.take(n)),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, height: 1.35),
                );
              },
            ),
          ],
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(mine ? 0.85 : -0.85, 0.1),
            radius: 1.0,
            colors: [accent.withValues(alpha: 0.28), Colors.transparent],
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: mine
              ? [Expanded(child: dialog), const SizedBox(width: 10), portrait]
              : [portrait, const SizedBox(width: 10), Expanded(child: dialog)],
        ),
      ),
    );
  }
}