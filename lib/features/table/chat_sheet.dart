import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Warna sorot pemain. Publik karena dipakai juga oleh ChatSpotlightLayer.
Color chatAccent(String? id, bool mine) {
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
            height: (mq.size.height - inset) * 0.88,
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

/// Isi obrolan. Setiap pesan baru memicu adegan sinematik: potret karakter
/// pengirim menghantam masuk di atas daftar pesan, lengkap dengan sinar,
/// partikel, kilatan, dan dialog yang diketik. Ketuk adegan untuk melewati;
/// tombol ✨ di kolom ketik mematikan/menyalakan efek.
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

  // Antrean adegan
  final List<Map<String, dynamic>> _queue = [];
  Map<String, dynamic>? _spot;
  Timer? _spotTimer;
  bool _busy = false;
  bool fx = true;

  String? about; // user_id yang dibicarakan
  String? err;
  bool showJump = false;

  @override
  void initState() {
    super.initState();
    _sub = widget.repo.chat(widget.gameId).listen(_onData, onError: (_) {});
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
    if (fresh.isNotEmpty && fx) _enqueue(fresh);
  }

  void _enqueue(List<Map<String, dynamic>> msgs) {
    _queue.addAll(msgs);
    if (_queue.length > 3) _queue.removeRange(0, _queue.length - 3);
    if (!_busy) _next();
  }

  void _next() {
    if (!mounted) return;
    if (_queue.isEmpty) {
      _busy = false;
      _spotTimer?.cancel();
      // Biarkan adegan terakhir tertahan sebentar, lalu memudar.
      _spotTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _spot = null);
      });
      return;
    }
    _spotTimer?.cancel();
    final m = _queue.removeAt(0);
    _busy = true;
    setState(() => _spot = m);
    final len = (m['body'] as String).length;
    var ms = (2000 + len * 40).clamp(2400, 4600).toInt();
    if (_queue.isNotEmpty) ms -= 700;
    _spotTimer = Timer(Duration(milliseconds: ms), _next);
  }

  void _skip() {
    if (_queue.isEmpty) {
      _spotTimer?.cancel();
      _busy = false;
      setState(() => _spot = null);
    } else {
      _next();
    }
  }

  void _toggleFx() {
    setState(() {
      fx = !fx;
      if (!fx) {
        _queue.clear();
        _spotTimer?.cancel();
        _busy = false;
        _spot = null;
      }
    });
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
    final accent = chatAccent(uid, mine);
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
    final spot = _spot;
    final spotUid = spot?['user_id'] as String?;
    final spotMine = spotUid == widget.repo.myId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LayoutBuilder(builder: (context, lc) {
            final maxW = (lc.maxWidth - 36) * 0.82;
            // Adegan menutup area pesan; disembunyikan bila terlalu sempit.
            final showScene = fx && spot != null && lc.maxHeight >= 150;
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: rev.isEmpty
                        ? const Center(
                      child: Text('Belum ada yang bicara...',
                          style: TextStyle(color: Colors.white38)),
                    )
                        : ListView.builder(
                      controller: scroll,
                      reverse: true,
                      padding: const EdgeInsets.only(bottom: 4),
                      itemCount: rev.length,
                      itemBuilder: (_, i) =>
                          _message(rev[i], rev, i, maxW),
                    ),
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
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      layoutBuilder: (cur, prev) => Stack(
                        fit: StackFit.expand,
                        children: [...prev, ?cur],
                      ),
                      child: showScene
                          ? CutScene(
                        key: const ValueKey('cut'),
                        msg: spot,
                        card: _cardOf(spotUid),
                        mine: spotMine,
                        accent: chatAccent(spotUid, spotMine),
                        onSkip: _skip,
                      )
                          : const SizedBox.shrink(key: ValueKey('none')),
                    ),
                  ),
                ],
              ),
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
            IconButton(
              tooltip: fx ? 'Matikan efek dramatis' : 'Nyalakan efek dramatis',
              onPressed: _toggleFx,
              icon: Icon(
                Icons.auto_awesome,
                size: 20,
                color: fx ? Colors.amberAccent : Colors.white38,
              ),
            ),
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

// ====================== ADEGAN SINEMATIK ======================

enum _Mood { calm, shout, ask, suspect }

_Mood _moodOf(String t) {
  final l = t.toLowerCase();
  if (l.contains('curiga') ||
      l.contains('bohong') ||
      l.contains('pengkhianat') ||
      l.contains('terbisik') ||
      l.contains('👀')) {
    return _Mood.suspect;
  }
  if (t.contains('!')) return _Mood.shout;
  if (t.contains('?')) return _Mood.ask;
  return _Mood.calm;
}

/// Adegan satu pesan. Urutan (1,1 detik):
///  0.00-0.50  potret menghantam masuk dari sisi pembicara (membesar lalu
///             mengecil dengan pantulan), latar menggelap, sinar menyebar
///  0.42-0.50  kilatan cahaya saat potret mendarat
///  0.45-0.90  guncangan (kuat bila seru "!", sedang bila curiga)
///  0.30-0.70  plakat nama miring meluncur, lalu kotak dialog
///  0.50-0.80  simbol "!" / "?" / "👀" muncul membal di dekat kepala
/// Setelah itu potret "bernapas" (naik turun), cahaya berdenyut, dan embun
/// melayang naik. Teks diketik huruf demi huruf.
///
/// Publik karena dipakai juga oleh ChatSpotlightLayer (layar meja/diskusi).
class CutScene extends StatefulWidget {
  final Map<String, dynamic> msg;
  final String? card;
  final bool mine;
  final Color accent;
  final VoidCallback onSkip;
  const CutScene({
    super.key,
    required this.msg,
    required this.card,
    required this.mine,
    required this.accent,
    required this.onSkip,
  });

  @override
  State<CutScene> createState() => CutSceneState();
}

class CutSceneState extends State<CutScene> with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));
  late final AnimationController _loop = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600))
    ..repeat();
  late final AnimationController _type = AnimationController(vsync: this);
  Timer? _typeDelay;

  _Mood mood = _Mood.calm;
  Color fx = Colors.white;
  int seed = 0;

  @override
  void initState() {
    super.initState();
    _play();
  }

  @override
  void didUpdateWidget(covariant CutScene old) {
    super.didUpdateWidget(old);
    if (old.msg['id'] != widget.msg['id']) _play();
  }

  void _play() {
    final body = widget.msg['body'] as String;
    mood = _moodOf(body);
    fx = switch (mood) {
      _Mood.suspect => const Color(0xFFFF6B6B),
      _Mood.shout => Color.lerp(widget.accent, Colors.white, 0.35)!,
      _ => widget.accent,
    };
    seed = (widget.msg['id'] as String).hashCode;

    _enter.forward(from: 0);
    _type.stop();
    _type.value = 0;
    _type.duration = Duration(
        milliseconds: (body.runes.length * 34).clamp(300, 2200).toInt());
    _typeDelay?.cancel();
    _typeDelay = Timer(const Duration(milliseconds: 450), () {
      if (mounted) _type.forward(from: 0);
    });

    if (!widget.mine) {
      if (mood == _Mood.shout || mood == _Mood.suspect) {
        Future.delayed(const Duration(milliseconds: 450),
            HapticFeedback.heavyImpact);
      } else {
        HapticFeedback.selectionClick();
      }
    }
  }

  @override
  void dispose() {
    _typeDelay?.cancel();
    _enter.dispose();
    _loop.dispose();
    _type.dispose();
    super.dispose();
  }

  String get _glyph => switch (mood) {
    _Mood.shout => '!',
    _Mood.ask => '?',
    _Mood.suspect => '👀',
    _Mood.calm => '',
  };

  @override
  Widget build(BuildContext context) {
    final mine = widget.mine;
    final name = (widget.msg['name'] as String).toUpperCase();
    final body = widget.msg['body'] as String;
    final runes = body.runes.toList();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onSkip,
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight;
        var portraitH = (h * 0.84).clamp(100.0, 420.0).toDouble();
        var cardW = portraitH * 3 / 4;
        if (cardW > w * 0.58) cardW = w * 0.58;
        final cardH = cardW * 4 / 3;
        final sideGap = w * 0.05;

        return AnimatedBuilder(
          animation: Listenable.merge([_enter, _loop, _type]),
          builder: (context, _) {
            final t = _enter.value;
            final l = _loop.value;
            final breathe = sin(l * 2 * pi);

            // --- gerak potret ---
            final slideT = (t / 0.5).clamp(0.0, 1.0).toDouble();
            final slide = Curves.easeOutBack.transform(slideT);
            final dx = (1 - slide) * (mine ? 1 : -1) * cardW * 1.6;
            final impactScale =
                1 + 0.32 * (1 - Curves.easeOutCubic.transform(slideT));
            final fade = (t / 0.2).clamp(0.0, 1.0).toDouble();
            final shakeT = ((t - 0.45) / 0.45).clamp(0.0, 1.0).toDouble();
            final amp = switch (mood) {
              _Mood.shout => 12.0,
              _Mood.suspect => 7.0,
              _ => 0.0,
            };
            final shake = t > 0.45 ? sin(shakeT * 70) * amp * (1 - shakeT) : 0.0;
            final tilt = (mine ? 1 : -1) * 0.035 * Curves.easeOut.transform(slideT);

            // --- latar ---
            final dim = Curves.easeOut
                .transform((t / 0.25).clamp(0.0, 1.0).toDouble());
            final rayCount = mood == _Mood.shout ? 20 : 12;
            final rayStrength = switch (mood) {
              _Mood.shout => 1.5,
              _Mood.suspect => 1.1,
              _ => 0.85,
            };
            final rayCenter =
            Offset(w * (mine ? 0.72 : 0.28), h * 0.42);

            // --- kilatan ---
            final flashPeak = switch (mood) {
              _Mood.shout => 0.6,
              _Mood.suspect => 0.4,
              _ => 0.18,
            };
            final flash =
                max(0.0, 1 - ((t - 0.46).abs() / 0.07)) * flashPeak;

            // --- plakat & dialog ---
            final bt = Curves.easeOutCubic
                .transform(((t - 0.3) / 0.4).clamp(0.0, 1.0).toDouble());
            final dt = ((t - 0.35) / 0.3).clamp(0.0, 1.0).toDouble();
            final typed = (runes.length * _type.value).ceil();
            final typingDone = _type.value >= 1;

            // --- simbol ---
            final gt = Curves.elasticOut
                .transform(((t - 0.5) / 0.3).clamp(0.0, 1.0).toDouble());

            final portrait = Transform.translate(
              offset: Offset(dx + shake, breathe * 4),
              child: Transform.rotate(
                angle: tilt,
                child: Transform.scale(
                  scale: impactScale * (1 + 0.012 * breathe),
                  child: Opacity(
                    opacity: fade,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: -cardW * 0.3,
                          right: -cardW * 0.3,
                          top: -cardH * 0.12,
                          bottom: -cardH * 0.12,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(colors: [
                                fx.withValues(
                                    alpha: 0.38 + 0.14 * breathe),
                                fx.withValues(alpha: 0),
                              ]),
                            ),
                          ),
                        ),
                        CardArt(
                          path: protagonistPath(widget.card ?? 'default'),
                          width: cardW,
                          glow: fx,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );

            final banner = Transform.translate(
              offset: Offset((1 - bt) * (mine ? 1 : -1) * 140, 0),
              child: Opacity(
                opacity: bt,
                child: Transform(
                  transform: Matrix4.skewX(-0.22),
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        fx,
                        Color.lerp(fx, Colors.black, 0.45)!,
                      ]),
                      boxShadow: [
                        BoxShadow(
                            color: fx.withValues(alpha: 0.6), blurRadius: 12),
                      ],
                    ),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            );

            final dialog = Opacity(
              opacity: dt,
              child: Transform.translate(
                offset: Offset(0, (1 - dt) * 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: h * 0.42),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        end: mine
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        colors: [
                          fx.withValues(alpha: 0.28),
                          Colors.black.withValues(alpha: 0.88),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: fx.withValues(alpha: 0.85)),
                      boxShadow: [
                        BoxShadow(
                            color: fx.withValues(alpha: 0.35), blurRadius: 16),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: Text(
                            String.fromCharCodes(runes.take(typed)),
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: mood == _Mood.shout ? 18 : 15,
                              fontWeight: mood == _Mood.shout
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                        ),
                        if (typingDone)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Opacity(
                              opacity: 0.4 + 0.6 * ((breathe + 1) / 2),
                              child: Icon(Icons.arrow_drop_down,
                                  color: fx, size: 22),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );

            return ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // latar gelap
                  Opacity(
                    opacity: dim,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(mine ? 0.45 : -0.45, -0.1),
                          radius: 1.15,
                          colors: [
                            Color.lerp(Colors.black, fx, 0.2)!
                                .withValues(alpha: 0.86),
                            Colors.black.withValues(alpha: 0.93),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // sinar
                  Opacity(
                    opacity: dim,
                    child: CustomPaint(
                      painter: _RaysPainter(
                        rot: l * 2 * pi * 0.25,
                        color: fx,
                        count: rayCount,
                        strength: rayStrength,
                        center: rayCenter,
                      ),
                    ),
                  ),
                  // embun melayang
                  CustomPaint(
                    painter: _ParticlesPainter(t: l, color: fx, seed: seed),
                  ),
                  // potret
                  Positioned(
                    top: max(4.0, (h - cardH) * 0.12),
                    left: mine ? null : sideGap,
                    right: mine ? sideGap : null,
                    child: portrait,
                  ),
                  // simbol suasana
                  if (_glyph.isNotEmpty)
                    Positioned(
                      top: 6,
                      left: mine ? null : sideGap + cardW - 6,
                      right: mine ? sideGap + cardW - 6 : null,
                      child: Transform.rotate(
                        angle: sin(l * 2 * pi) * 0.12,
                        child: Transform.scale(
                          scale: gt,
                          child: Text(
                            _glyph,
                            style: TextStyle(
                              fontSize: 46,
                              fontWeight: FontWeight.w900,
                              color: fx,
                              shadows: [
                                Shadow(color: fx, blurRadius: 18),
                                const Shadow(
                                    color: Colors.black, blurRadius: 4),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  // plakat nama + dialog
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: mine
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                              left: mine ? 0 : 8, right: mine ? 8 : 0),
                          child: banner,
                        ),
                        const SizedBox(height: 4),
                        dialog,
                      ],
                    ),
                  ),
                  // kilatan
                  if (flash > 0.01)
                    IgnorePointer(
                      child: ColoredBox(
                        color: Color.lerp(Colors.white, fx, 0.25)!
                            .withValues(alpha: flash.clamp(0.0, 1.0).toDouble()),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      }),
    );
  }
}

/// Sinar menyebar dari belakang potret, berputar pelan.
class _RaysPainter extends CustomPainter {
  final double rot;
  final Color color;
  final int count;
  final double strength;
  final Offset center;
  _RaysPainter({
    required this.rot,
    required this.color,
    required this.count,
    required this.strength,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.longestSide * 1.2;
    final paint = Paint()
      ..shader = ui.Gradient.radial(center, r, [
        color.withValues(alpha: (0.3 * strength).clamp(0.0, 1.0).toDouble()),
        color.withValues(alpha: 0),
      ]);
    final half = pi / count * 0.45;
    for (var i = 0; i < count; i++) {
      final a = rot + i * 2 * pi / count;
      final p = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + cos(a - half) * r, center.dy + sin(a - half) * r)
        ..lineTo(center.dx + cos(a + half) * r, center.dy + sin(a + half) * r)
        ..close();
      canvas.drawPath(p, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RaysPainter old) => true;
}

/// Tetes embun / kunang-kunang yang melayang naik.
class _ParticlesPainter extends CustomPainter {
  final double t;
  final Color color;
  final int seed;
  _ParticlesPainter({required this.t, required this.color, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(seed);
    for (var i = 0; i < 18; i++) {
      final x0 = rnd.nextDouble();
      final sp = 0.5 + rnd.nextDouble();
      final sz = 1.5 + rnd.nextDouble() * 3.5;
      final ph = rnd.nextDouble();
      final f = (t * sp + ph) % 1.0;
      final y = size.height * (1.05 - f * 1.1);
      final x = size.width * x0 + sin((f + ph) * 2 * pi) * 14;
      final a = (sin(f * pi) * 0.65).clamp(0.0, 1.0).toDouble();
      canvas.drawCircle(
        Offset(x, y),
        sz,
        Paint()..color = color.withValues(alpha: a),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter old) => true;
}