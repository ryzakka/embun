import 'package:flutter/material.dart';
import '../../data/character_cards.dart';
import '../../data/lobby_repository.dart';
import '../prologue/prologue_page.dart';

class LobbyPage extends StatefulWidget {
  const LobbyPage({super.key});
  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  final repo = LobbyRepository();
  final nameCtrl = TextEditingController();
  final codeCtrl = TextEditingController();
  String? gameId;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    repo.ensureSignedIn().then((_) {
      if (mounted) setState(() {});
    }).catchError((e) {
      if (mounted) _toast(e.toString());
    });
  }

  Future<void> _run(Future<String> Function() action) async {
    if (nameCtrl.text.trim().isEmpty) return _toast('Isi namamu dulu');
    setState(() => busy = true);
    try {
      final id = await action();
      if (mounted) setState(() => gameId = id);
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Balai Pertemuan')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: gameId == null ? _entry() : _room(gameId!),
          ),
        ),
      ),
    );
  }

  Widget _entry() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextField(
        controller: nameCtrl,
        maxLength: 20,
        decoration: const InputDecoration(labelText: 'Namamu'),
      ),
      FilledButton(
        onPressed:
        busy ? null : () => _run(() => repo.createGame(nameCtrl.text)),
        child: const Text('Buat Ruangan'),
      ),
      const Divider(height: 32),
      TextField(
        controller: codeCtrl,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(labelText: 'Kode ruangan'),
      ),
      OutlinedButton(
        onPressed: busy
            ? null
            : () => _run(() => repo.joinGame(codeCtrl.text, nameCtrl.text)),
        child: const Text('Gabung'),
      ),
    ],
  );

  Widget _room(String id) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: repo.game(id),
      builder: (context, gs) {
        if (!gs.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final game = gs.data!;
        if (game['status'] != 'lobby') {
          return PrologueFlow(gameId: id, repo: repo);
        }
        final isHost = game['host_id'] == repo.myId;
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: repo.players(id),
          builder: (context, ps) {
            final players = ps.data ?? [];
            final me = players.where((p) => p['user_id'] == repo.myId);
            final myRow = me.isEmpty ? null : me.first;
            return Column(
              children: [
                Text('Kode: ${game['code']}',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text('Pilih kartu karakter',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in characterCards)
                      ChoiceChip(
                        avatar: Icon(c.icon, size: 18, color: c.color),
                        label: Text(c.title),
                        selected: myRow?['character_card'] == c.id,
                        onSelected: myRow == null
                            ? null
                            : (_) => repo.updateCharacter(
                            id, myRow['name'] as String, c.id),
                      ),
                  ],
                ),
                const Divider(height: 24),
                Expanded(
                  child: ListView(
                    children: [
                      for (final p in players)
                        ListTile(
                          leading: Icon(cardById(p['character_card']).icon,
                              color: cardById(p['character_card']).color),
                          title: Text(p['name']),
                          subtitle: Text(cardById(p['character_card']).title),
                          trailing: p['user_id'] == game['host_id']
                              ? const Text('Host')
                              : null,
                        ),
                    ],
                  ),
                ),
                if (isHost)
                  FilledButton(
                    onPressed: () async {
                      try {
                        await repo.startGame(id);
                      } catch (e) {
                        _toast(e.toString());
                      }
                    },
                    child: const Text('Mulai (min. 3 pemain)'),
                  ),
                TextButton(
                  onPressed: () async {
                    await repo.leave(id);
                    if (mounted) setState(() => gameId = null);
                  },
                  child: const Text('Keluar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}