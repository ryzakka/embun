import 'package:flutter/material.dart';
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
                constraints: const BoxConstraints(maxWidth: 520),
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

  Widget _panel(Widget child) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.62),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white12),
    ),
    child: child,
  );

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
        final isHost = game['host_id'] == repo.myId;
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: repo.players(id),
          builder: (context, ps) {
            final players = ps.data ?? [];
            final mine = players.where((p) => p['user_id'] == repo.myId);
            final me = mine.isEmpty ? null : mine.first;
            final myCard = (me?['character_card'] as String?) ?? 'default';
            final iReady = me?['ready'] == true;
            final readyN = players.where((p) => p['ready'] == true).length;
            final canStart = players.length >= 3 && readyN == players.length;
            return _panel(
              Column(
                children: [
                  Text('Kode: ${game['code']}',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CardArt(path: protagonistPath(myCard), width: 72),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(me?['name'] as String? ?? '',
                                style: Theme.of(context).textTheme.titleLarge),
                            Text(characterTitle(myCard),
                                style:
                                const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: me == null || iReady
                                  ? null
                                  : () => _pickCard(id, me),
                              icon: Icon(iReady ? Icons.lock : Icons.style),
                              label: Text(
                                  iReady ? 'Kartu terkunci' : 'Ganti kartu'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: iReady
                        ? OutlinedButton.icon(
                      onPressed: me == null
                          ? null
                          : () async {
                        try {
                          await repo.setReady(id, false);
                        } catch (e) {
                          _toast(errMsg(e));
                        }
                      },
                      icon: const Icon(Icons.check_circle,
                          color: Colors.greenAccent),
                      label: const Text('Siap. Ketuk untuk batal'),
                    )
                        : FilledButton(
                      onPressed: me == null
                          ? null
                          : () async {
                        try {
                          await repo.setReady(id, true);
                        } catch (e) {
                          _toast(errMsg(e));
                        }
                      },
                      child: const Text('Siap'),
                    ),
                  ),
                  const Divider(height: 20),
                  Expanded(
                    child: _LobbyBody(
                      gr: _gr,
                      gameId: id,
                      hostId: game['host_id'] as String,
                      players: players,
                    ),
                  ),
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
              ),
            );
          },
        );
      },
    );
  }
}

/// Tab Pemain / Obrolan di lobi. Obrolan memakai tabel yang sama dengan
/// obrolan dalam gim.
class _LobbyBody extends StatefulWidget {
  final GameRepository gr;
  final String gameId;
  final String hostId;
  final List<Map<String, dynamic>> players;
  const _LobbyBody({
    required this.gr,
    required this.gameId,
    required this.hostId,
    required this.players,
  });

  @override
  State<_LobbyBody> createState() => _LobbyBodyState();
}

class _LobbyBodyState extends State<_LobbyBody> {
  int tab = 0; // 0 pemain, 1 obrolan
  int seen = 0;
  late final Stream<List<Map<String, dynamic>>> chat =
  widget.gr.chat(widget.gameId);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: chat,
          builder: (context, s) {
            final count = (s.data ?? [])
                .where((m) => m['user_id'] != widget.gr.myId)
                .length;
            if (tab == 1) seen = count;
            final unread = count - seen;
            return Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('Pemain (${widget.players.length})'),
                    selected: tab == 0,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => tab = 0),
                  ),
                ),
                Badge(
                  isLabelVisible: unread > 0 && tab != 1,
                  label: Text('$unread'),
                  child: ChoiceChip(
                    label: const Text('Obrolan'),
                    selected: tab == 1,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() {
                      tab = 1;
                      seen = count;
                    }),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Expanded(
          child: tab == 0
              ? ListView(
            children: [
              for (final p in widget.players)
                ListTile(
                  dense: true,
                  leading: PlayerAvatar(
                    path: protagonistPath(p['character_card'] as String),
                    size: 40,
                  ),
                  title: Text(p['name'] as String),
                  subtitle:
                  Text(characterTitle(p['character_card'] as String)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (p['user_id'] == widget.hostId)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Text('Host'),
                        ),
                      Icon(
                        p['ready'] == true
                            ? Icons.check_circle
                            : Icons.hourglass_empty,
                        size: 20,
                        color: p['ready'] == true
                            ? Colors.greenAccent
                            : Colors.white38,
                      ),
                    ],
                  ),
                ),
            ],
          )
              : ChatPanel(
            repo: widget.gr,
            gameId: widget.gameId,
            players: widget.players,
            lobby: true,
          ),
        ),
      ],
    );
  }
}