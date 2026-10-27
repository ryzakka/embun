import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../../data/lobby_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import '../prologue/prologue_page.dart';
import '../table/chat_sheet.dart';
import '../table/table_page.dart';

class LobbyPage extends StatefulWidget {
  const LobbyPage({super.key});
  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  final repo = LobbyRepository();
  final _gr = GameRepository();
  final nameCtrl = TextEditingController();
  final codeCtrl = TextEditingController();
  String? gameId;
  bool busy = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      await repo.ensureSignedIn();
      final g = await repo.activeGame();
      if (!mounted) return;
      if (g != null) {
        final id = g['id'] as String;
        if (g['status'] == 'lobby') {
          setState(() => gameId = id);
          return;
        }
        final role = await repo.myRole(id);
        if (!mounted) return;
        if (role != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => TablePage(gameId: id, role: role),
            ),
          );
          return;
        }
      }
      setState(() {});
    } catch (e) {
      if (mounted) _toast(errMsg(e));
    }
  }

  Future<void> _run(Future<String> Function(String card) action) async {
    if (nameCtrl.text.trim().isEmpty) return _toast('Isi namamu dulu');
    setState(() => busy = true);
    try {
      final id = await action(randomProtagonist());
      if (mounted) setState(() => gameId = id);
    } catch (e) {
      _toast(errMsg(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Backdrop(path: sceneryPath('rumahdesa-hijau'), dim: 0.55),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: gameId == null ? 520 : 1100),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: gameId == null ? _entry() : _room(gameId!),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(Widget child) =>
      _Glass(padding: const EdgeInsets.all(20), child: child);

  Widget _entry() => SingleChildScrollView(
    child: _panel(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 190,
            child: GameImage(
                path: logoPath('ikon-transparent'),
                fit: BoxFit.contain,
                cacheWidth: 800),
          ),
          const SizedBox(height: 2),
          const Text('Balai Pertemuan Desa',
              style: TextStyle(
                  color: EmbunColors.goldDim, letterSpacing: 2, fontSize: 13)),
          const SizedBox(height: 18),
          TextField(
            controller: nameCtrl,
            maxLength: 20,
            decoration: const InputDecoration(
              labelText: 'Namamu',
              prefixIcon: Padding(
                padding: EdgeInsets.all(6),
                child: GameIcon('identity', size: 30),
              ),
            ),
          ),
          const SizedBox(height: 6),
          EmbunButton(
            label: 'Buat Ruangan',
            icon: 'roomcreate',
            expand: true,
            onPressed: busy
                ? null
                : () => _run((card) => repo.createGame(nameCtrl.text, card)),
          ),
          const Divider(height: 32),
          TextField(
            controller: codeCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Kode ruangan',
              prefixIcon: Padding(
                padding: EdgeInsets.all(6),
                child: GameIcon('roomcode', size: 30),
              ),
            ),
          ),
          const SizedBox(height: 10),
          EmbunButton(
            label: 'Gabung',
            icon: 'joinroom',
            kind: EmbunButtonKind.secondary,
            expand: true,
            onPressed: busy
                ? null
                : () => _run((card) =>
                repo.joinGame(codeCtrl.text, nameCtrl.text, card)),
          ),
        ],
      ),
    ),
  );

  Future<void> _pickCard(String id, Map<String, dynamic> me) async {
    if (me['ready'] == true) return; // terkunci selama siap
    final stems = AssetCatalog.I.stems(protagonisDir);
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF12201E),
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.75,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SectionHeader(icon: 'mydeck', title: 'Pilih kartu karakter'),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 130,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: stems.length,
                itemBuilder: (_, i) {
                  final s = stems[i];
                  final sel = s == me['character_card'];
                  return GestureDetector(
                    onTap: () => Navigator.pop(ctx, s),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel ? EmbunColors.gold : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: GameImage(
                            path: protagonistPath(s), cacheWidth: 260),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (chosen != null && chosen != me['character_card']) {
      try {
        await repo.updateCharacter(id, me['name'] as String, chosen);
      } catch (e) {
        if (mounted) _toast(errMsg(e));
      }
    }
  }

  Widget _room(String id) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: repo.game(id),
      builder: (context, gs) {
        final game = gs.data;
        if (game == null) {
          // Sudah menerima data tetapi barisnya hilang: ruangan dibubarkan.
          if (gs.connectionState != ConnectionState.waiting) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || gameId != id) return;
              setState(() => gameId = null);
              _toast('Ruangan sudah dibubarkan');
            });
          }
          return const EmbunLoading();
        }
        if (game['status'] != 'lobby') {
          if (!_navigated) {
            _navigated = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => PrologueFlow(gameId: id, repo: repo),
                ),
              );
            });
          }
          return const EmbunLoading();
        }
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: repo.players(id),
          builder: (context, ps) {
            final players = ps.data ?? [];
            final mine = players.where((p) => p['user_id'] == repo.myId);
            final me = mine.isEmpty ? null : mine.first;
            return _RoomShell(
              gr: _gr,
              gameId: id,
              players: players,
              room: _roomContent(id, game, players, me),
            );
          },
        );
      },
    );
  }

  Future<void> _setReady(String id, bool v) async {
    try {
      await repo.setReady(id, v);
    } catch (e) {
      _toast(errMsg(e));
    }
  }

  Widget _roomContent(String id, Map<String, dynamic> game,
      List<Map<String, dynamic>> players, Map<String, dynamic>? me) {
    final isHost = game['host_id'] == repo.myId;
    final hostId = game['host_id'] as String;
    final myCard = (me?['character_card'] as String?) ?? 'default';
    final iReady = me?['ready'] == true;
    final readyN = players.where((p) => p['ready'] == true).length;
    final canStart = players.length >= 3 && readyN == players.length;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: 48,
                child: GameImage(
                    path: logoPath('logoteks-transparent'),
                    fit: BoxFit.contain,
                    cacheWidth: 600),
              ),
              const SizedBox(height: 10),
              _codeHeader(game['code'] as String),
              const SizedBox(height: 14),
              _meCard(id, me, myCard, iReady),
              const SizedBox(height: 12),
              iReady
                  ? EmbunButton(
                label: 'Siap. Ketuk untuk batal',
                icon: 'centang',
                kind: EmbunButtonKind.secondary,
                expand: true,
                onPressed: me == null ? null : () => _setReady(id, false),
              )
                  : EmbunButton(
                label: 'Siap',
                icon: 'centang',
                expand: true,
                onPressed: me == null ? null : () => _setReady(id, true),
              ),
              const SizedBox(height: 20),
              SectionHeader(
                icon: 'persona',
                title: 'Pemain ${players.length}/8 · siap $readyN',
              ),
              const SizedBox(height: 10),
              for (final p in players) _playerTile(p, hostId),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (isHost)
          EmbunButton(
            label: canStart
                ? 'Mulai'
                : players.length < 3
                ? 'Menunggu pemain (min. 3)'
                : 'Menunggu semua siap ($readyN/${players.length})',
            icon: 'start',
            expand: true,
            onPressed: canStart
                ? () async {
              try {
                await repo.startGame(id);
              } catch (e) {
                _toast(errMsg(e));
              }
            }
                : null,
          ),
        const SizedBox(height: 8),
        EmbunButton(
          label: isHost ? 'Bubarkan ruangan' : 'Keluar',
          icon: isHost ? 'bubarkan' : 'keluar',
          kind: EmbunButtonKind.secondary,
          expand: true,
          height: 44,
          onPressed: () async {
            // Keluar dulu agar penghapusan ruangan tidak memicu
            // pesan "dibubarkan" untuk host sendiri.
            setState(() => gameId = null);
            try {
              await repo.leave(id);
            } catch (e) {
              if (!mounted) return;
              setState(() => gameId = id);
              _toast(errMsg(e));
            }
          },
        ),
      ],
    );
  }

  Widget _codeHeader(String code) => Container(
    padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: EmbunColors.goldDim.withValues(alpha: 0.4)),
    ),
    child: Row(
      children: [
        const GameIcon('roomcode', size: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kode ruangan',
                  style: TextStyle(fontSize: 11, color: Colors.white60)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  code,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                    color: EmbunColors.gold,
                  ),
                ),
              ),
            ],
          ),
        ),
        MedallionButton(
          icon: 'salin',
          label: 'Salin',
          size: 40,
          onTap: () {
            Clipboard.setData(ClipboardData(text: code));
            _toast('Kode disalin');
          },
        ),
      ],
    ),
  );

  Widget _meCard(
      String id, Map<String, dynamic>? me, String myCard, bool iReady) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: EmbunColors.goldDim.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            CardArt(path: protagonistPath(myCard), width: 78),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(me?['name'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: EmbunColors.gold)),
                  Text(characterTitle(myCard),
                      style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 10),
                  EmbunButton(
                    label: iReady ? 'Kartu terkunci' : 'Ganti kartu',
                    icon: iReady ? 'lock' : 'customization',
                    kind: EmbunButtonKind.secondary,
                    height: 46,
                    onPressed:
                    me == null || iReady ? null : () => _pickCard(id, me),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _playerTile(Map<String, dynamic> p, String hostId) {
    final ready = p['ready'] == true;
    final isMe = p['user_id'] == repo.myId;
    final isHostP = p['user_id'] == hostId;
    final card = p['character_card'] as String;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ready
              ? EmbunColors.leaf.withValues(alpha: 0.7)
              : EmbunColors.goldDim.withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        leading: PlayerAvatar(
          path: protagonistPath(card),
          size: 44,
          ring: isMe ? EmbunColors.gold : EmbunColors.goldDim,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(p['name'] as String,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (isHostP)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.fromLTRB(2, 1, 8, 1),
                decoration: BoxDecoration(
                  color: EmbunColors.gold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GameIcon('host', size: 20),
                    SizedBox(width: 3),
                    Text('Host',
                        style: TextStyle(
                            fontSize: 11, color: EmbunColors.gold)),
                  ],
                ),
              ),
          ],
        ),
        subtitle: Text(characterTitle(card)),
        trailing: GameIcon(ready ? 'centang' : 'wait', size: 32),
      ),
    );
  }
}

/// Panel kaca gelap yang dipakai bersama oleh layar masuk, ruangan, dan obrolan.
class _Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Glass({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) =>
      OrnatePanel(padding: padding, child: child);
}

/// Tata letak ruangan yang responsif:
/// - layar lebar (>= 820 px): ruangan di kiri, obrolan di kanan;
/// - ponsel: dua halaman yang digeser (ruangan, lalu obrolan di kanan).
class _RoomShell extends StatefulWidget {
  final GameRepository gr;
  final String gameId;
  final List<Map<String, dynamic>> players;
  final Widget room;
  const _RoomShell({
    required this.gr,
    required this.gameId,
    required this.players,
    required this.room,
  });

  @override
  State<_RoomShell> createState() => _RoomShellState();
}

class _RoomShellState extends State<_RoomShell> {
  static const _wideBreakpoint = 820.0;
  final _pc = PageController();
  int page = 0;
  int seen = 0;
  late final Stream<List<Map<String, dynamic>>> chat =
  widget.gr.chat(widget.gameId);

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Widget _chatPane() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionHeader(icon: 'discuss', title: 'Obrolan Desa'),
      const SizedBox(height: 8),
      Expanded(
        child: ChatPanel(
          repo: widget.gr,
          gameId: widget.gameId,
          players: widget.players,
          lobby: true,
        ),
      ),
    ],
  );

  void _goto(int i) => _pc.animateToPage(i,
      duration: const Duration(milliseconds: 280), curve: Curves.easeOut);

  Widget _tabs(int unread) => Row(
    children: [
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          avatar: const GameIcon('persona', size: 26),
          label: Text('Ruangan (${widget.players.length})'),
          selected: page == 0,
          visualDensity: VisualDensity.compact,
          onSelected: (_) => _goto(0),
        ),
      ),
      Badge(
        isLabelVisible: unread > 0 && page != 1,
        label: Text('$unread'),
        child: ChoiceChip(
          avatar: const GameIcon('discuss', size: 26),
          label: const Text('Obrolan'),
          selected: page == 1,
          visualDensity: VisualDensity.compact,
          onSelected: (_) => _goto(1),
        ),
      ),
      const Spacer(),
      if (page == 0)
        const Text('Geser untuk obrolan',
            style: TextStyle(fontSize: 11, color: Colors.white54)),
      if (page == 0)
        const GameIcon('skip2', size: 22),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= _wideBreakpoint) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _Glass(child: widget.room)),
            const SizedBox(width: 16),
            SizedBox(width: 380, child: _Glass(child: _chatPane())),
          ],
        );
      }
      return StreamBuilder<List<Map<String, dynamic>>>(
        stream: chat,
        builder: (context, s) {
          final count = (s.data ?? [])
              .where((m) => m['user_id'] != widget.gr.myId)
              .length;
          if (page == 1) seen = count;
          final unread = count - seen;
          return Column(
            children: [
              _tabs(unread),
              const SizedBox(height: 8),
              Expanded(
                child: PageView(
                  controller: _pc,
                  onPageChanged: (i) => setState(() {
                    page = i;
                    if (i == 1) seen = count;
                  }),
                  children: [
                    _KeepAlive(child: _Glass(child: widget.room)),
                    _KeepAlive(child: _Glass(child: _chatPane())),
                  ],
                ),
              ),
            ],
          );
        },
      );
    });
  }
}

class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});
  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}