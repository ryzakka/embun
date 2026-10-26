import 'package:flutter/material.dart';
import '../../data/lobby_repository.dart';

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
    repo.ensureSignedIn().then((_) => setState(() {}));
  }

  Future<void> _run(Future<String> Function() action) async {
    if (nameCtrl.text.trim().isEmpty) return _toast('Isi namamu dulu');
    setState(() => busy = true);
    try {
      final id = await action();
      setState(() => gameId = id);
    } catch (e) {
      _toast(e.toString());
    } finally {
      setState(() => busy = false);
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
          constraints: const BoxConstraints(maxWidth: 420),
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
        onPressed: busy ? null : () => _run(() => repo.createGame(nameCtrl.text)),
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
          return const Center(child: Text('Ruangan sudah bubar atau memuat...'));
        }
        final game = gs.data!;
        final isHost = game['host_id'] == repo.myId;
        if (game['status'] != 'lobby') {
          return const Center(child: Text('Permainan dimulai! (prolog di sini)'));
        }
        return Column(
          children: [
            Text('Kode: ${game['code']}',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: repo.players(id),
                builder: (context, ps) {
                  final players = ps.data ?? [];
                  return ListView(
                    children: [
                      for (final p in players)
                        ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(p['name']),
                          trailing: p['user_id'] == game['host_id']
                              ? const Text('Host')
                              : null,
                        ),
                    ],
                  );
                },
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
                setState(() => gameId = null);
              },
              child: const Text('Keluar'),
            ),
          ],
        );
      },
    );
  }
}