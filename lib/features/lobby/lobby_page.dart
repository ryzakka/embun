import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../../data/lobby_repository.dart';
import '../common/art.dart';
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
          Text('Embun',
              style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 4),
          const Text('Balai Pertemuan Desa',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          TextField(
            controller: nameCtrl,
            maxLength: 20,
            decoration: const InputDecoration(labelText: 'Namamu'),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy
                  ? null
                  : () => _run(
                      (card) => repo.createGame(nameCtrl.text, card)),
              child: const Text('Buat Ruangan'),
            ),
          ),
          const Divider(height: 32),
          TextField(
            controller: codeCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Kode ruangan'),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: busy
                  ? null
                  : () => _run((card) =>
                  repo.joinGame(codeCtrl.text, nameCtrl.text, card)),
              child: const Text('Gabung'),
            ),
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
              padding: EdgeInsets.all(14),
              child: Text('Pilih kartu karakter',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                          color: sel ? Colors.amberAccent : Colors.transparent,
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
          return const Center(child: CircularProgressIndicator());
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
          return const Center(child: CircularProgressIndicator());
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
              _codeHeader(game['code'] as String),
              const SizedBox(height: 14),
              _meCard(id, me, myCard, iReady),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: iReady
                    ? OutlinedButton.icon(
                  onPressed: me == null ? null : () => _setReady(id, false),
                  icon: const Icon(Icons.check_circle,
                      color: Colors.greenAccent),
                  label: const Text('Siap. Ketuk untuk batal'),
                )
                    : FilledButton(
                  onPressed: me == null ? null : () => _setReady(id, true),
                  child: const Text('Siap'),
                ),
              ),
              const Divider(height: 28),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Pemain ${players.length}/8 · siap $readyN',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              for (final p in players) _playerTile(p, hostId),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (isHost)
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canStart
                  ? () async {
                try {
                  await repo.startGame(id);
                } catch (e) {
                  _toast(errMsg(e));
                }
              }
                  : null,
              child: Text(canStart
                  ? 'Mulai'
                  : players.length < 3
                  ? 'Menunggu pemain (min. 3)'
                  : 'Menunggu semua siap ($readyN/${players.length})'),
            ),
          ),
        TextButton(
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
          child: Text(isHost ? 'Bubarkan ruangan' : 'Keluar'),
        ),
      ],
    );
  }

  Widget _codeHeader(String code) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
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
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Salin kode',
          icon: const Icon(Icons.copy, size: 20),
          onPressed: () {
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
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CardArt(path: protagonistPath(myCard), width: 72),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(me?['name'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge),
                  Text(characterTitle(myCard),
                      style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed:
                    me == null || iReady ? null : () => _pickCard(id, me),
                    icon: Icon(iReady ? Icons.lock : Icons.style, size: 18),
                    label: Text(iReady ? 'Kartu terkunci' : 'Ganti kartu'),
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
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ready
              ? Colors.greenAccent.withValues(alpha: 0.6)
              : Colors.white12,
        ),
      ),
      child: ListTile(
        dense: true,
        leading: PlayerAvatar(
          path: protagonistPath(card),
          size: 40,
          ring: isMe ? Colors.amber : Colors.white38,
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
                padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Host',
                    style: TextStyle(fontSize: 10, color: Colors.amberAccent)),
              ),
          ],
        ),
        subtitle: Text(characterTitle(card)),
        trailing: Icon(
          ready ? Icons.check_circle : Icons.hourglass_empty,
          size: 20,
          color: ready ? Colors.greenAccent : Colors.white38,
        ),
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
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white12),
    ),
    child: child,
  );
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
      const Row(
        children: [
          Icon(Icons.forum, size: 18),
          SizedBox(width: 8),
          Text('Obrolan Desa', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
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
          avatar: const Icon(Icons.groups, size: 16),
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
          avatar: const Icon(Icons.forum, size: 16),
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
        const Icon(Icons.chevron_right, size: 16, color: Colors.white54),
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