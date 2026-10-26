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

/// Isi obrolan (daftar pesan, frasa cepat, kolom ketik). Dipakai di sheet
/// saat bermain dan langsung di tab Obrolan saat di lobi ([lobby] = true).
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
  late final Stream<List<Map<String, dynamic>>> stream =
  widget.repo.chat(widget.gameId);
  String? about; // user_id yang dibicarakan
  String? err;
  bool showJump = false;

  @override
  void initState() {
    super.initState();
    scroll.addListener(() {
      if (!scroll.hasClients) return;
      // Daftar dibalik: offset 0 = pesan terbaru di bawah.
      final away = scroll.offset > 160;
      if (away != showJump) setState(() => showJump = away);
    });
  }

  @override
  void dispose() {
    ctrl.dispose();
    focus.dispose();
    scroll.dispose();
    super.dispose();
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

  Widget _message(
      Map<String, dynamic> m, List<Map<String, dynamic>> rev, int i, double maxW) {
    final mine = m['user_id'] == widget.repo.myId;
    // rev[0] = terbaru; rev[i + 1] = pesan sebelumnya (lebih lama).
    final older = i + 1 < rev.length ? rev[i + 1] : null;
    final newer = i > 0 ? rev[i - 1] : null;
    final groupStart = older == null || older['user_id'] != m['user_id'];
    final groupEnd = newer == null || newer['user_id'] != m['user_id'];
    final day = m['day'] as int?;
    final when = _ts(m);
    final stamp = widget.lobby || day == 0
        ? _hhmm(when)
        : 'H$day · ${_hhmm(when)}';

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: BoxConstraints(maxWidth: maxW),
      decoration: BoxDecoration(
        color: mine ? const Color(0xFF2E5A4C) : const Color(0xFF2A2F36),
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
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white60)),
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
              width: 34,
              child: groupStart
                  ? PlayerAvatar(
                path: protagonistPath(_cardOf(m['user_id'] as String?) ??
                    'default'),
                size: 28,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, s) {
              // Terlama -> terbaru, lalu dibalik: indeks 0 = terbaru,
              // tampil di dasar daftar (reverse: true).
              // Di dalam game, pesan lobi (hari 0) disembunyikan: nama aslinya
              // tertulis di sana dan bisa membocorkan identitas.
              final all = (s.data ?? [])
                  .where((m) => widget.lobby || m['day'] != 0)
                  .toList();
              final rev = sortChat(all).reversed.toList();
              if (rev.isEmpty) {
                return const Center(
                  child: Text('Belum ada yang bicara...',
                      style: TextStyle(color: Colors.white38)),
                );
              }
              return LayoutBuilder(builder: (context, c) {
                final maxW = (c.maxWidth - 34) * 0.82;
                return Stack(
                  children: [
                    ListView.builder(
                      controller: scroll,
                      reverse: true,
                      padding: const EdgeInsets.only(bottom: 4),
                      itemCount: rev.length,
                      itemBuilder: (_, i) => _message(rev[i], rev, i, maxW),
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
              });
            },
          ),
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
                        style:
                        TextStyle(fontSize: 11, color: Colors.white54)),
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
  }
}