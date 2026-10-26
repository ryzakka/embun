import 'package:flutter/material.dart';
import '../../data/game_repository.dart';
import '../../data/lobby_repository.dart';
import '../lobby/lobby_page.dart';
import 'card_tile.dart';
import 'discussion_view.dart';
import 'effects_view.dart';
import 'offering_view.dart';
import 'voting_view.dart';

class TablePage extends StatefulWidget {
  final String gameId;
  final String role;
  const TablePage({super.key, required this.gameId, required this.role});

  @override
  State<TablePage> createState() => _TablePageState();
}

class _TablePageState extends State<TablePage> {
  final repo = GameRepository();
  final lobby = LobbyRepository();
  Map<String, Map<String, dynamic>> defs = {};
  List<Map<String, dynamic>> offers = [];
  int? syncedDay;
  bool showMarket = false;
  String? selected;
  bool busy = false;
  int burst = 0;

  bool get isAntag => widget.role == 'antagonis';

  @override
  void initState() {
    super.initState();
    repo.cardDefs().then((d) {
      if (mounted) setState(() => defs = d);
    });
  }

  void _syncDay(int day, String phase) {
    if (syncedDay == day) return;
    syncedDay = day;
    showMarket = false;
    selected = null;
    offers = [];
    if (phase == 'day') {
      repo.offers(widget.gameId, day).then((o) {
        if (mounted && syncedDay == day) setState(() => offers = o);
      });
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _guard(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      isAntag ? const Color(0xFF14131A) : const Color(0xFF12201E),
      body: SafeArea(
        child: Stack(
          children: [
            StreamBuilder<Map<String, dynamic>>(
              stream: lobby.game(widget.gameId),
              builder: (context, gs) {
                if (!gs.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final game = gs.data!;
                final day = game['day'] as int;
                final phase = (game['phase'] as String?) ?? 'day';
                final leaves = game['leaves'] as int;
                _syncDay(day, phase);

                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: lobby.players(widget.gameId),
                  builder: (context, ps) {
                    final players = ps.data ?? [];
                    final me = players.where((p) => p['user_id'] == repo.myId);
                    final myRow = me.isEmpty ? null : me.first;
                    final iAmReady = myRow?['ready'] == true;
                    final readyCount =
                        players.where((p) => p['ready'] == true).length;
                    final jailed = myRow?['jailed_day'] == day;

                    if (game['status'] == 'finished') return _result(game);

                    if (phase == 'effects') {
                      return EffectsView(
                        key: ValueKey('fx$day'),
                        repo: repo,
                        gameId: widget.gameId,
                        day: day,
                        isAntag: isAntag,
                        waiting: iAmReady,
                        readyCount: readyCount,
                        total: players.length,
                        onContinue: () => _guard(
                                () => repo.advanceAfterEffects(widget.gameId)),
                      );
                    }

                    return Row(
                      children: [
                        SizedBox(width: 120, child: _sidebar(day, leaves)),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: _panel(game, day, phase, leaves, players,
                              iAmReady, readyCount, jailed),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            if (burst > 0)
              IgnorePointer(
                child: CardBurst(
                  count: burst,
                  onDone: () {
                    if (mounted) setState(() => burst = 0);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sidebar(int day, int leaves) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Text('HARI', style: TextStyle(fontSize: 12, letterSpacing: 2)),
      Text('$day',
          style:
          const TextStyle(fontSize: 64, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      Icon(Icons.eco,
          size: 36,
          color: isAntag ? Colors.blueGrey : Colors.greenAccent),
      Text('$leaves', style: const TextStyle(fontSize: 28)),
      const Text('daun', style: TextStyle(fontSize: 12)),
    ],
  );

  Widget _panel(
      Map<String, dynamic> game,
      int day,
      String phase,
      int leaves,
      List<Map<String, dynamic>> players,
      bool iAmReady,
      int readyCount,
      bool jailed,
      ) {
    final verdict = (game['verdict_day'] == day - 1 && game['verdict'] != null)
        ? game['verdict'] as String
        : null;

    return StreamBuilder<Map<String, dynamic>?>(
      stream: repo.myState(widget.gameId),
      builder: (context, ss) {
        final st = ss.data;
        final balance = (st?['balance'] as num?)?.toDouble() ?? 0;
        final rate = (st?['rate'] as num?)?.toDouble() ?? 0;

        Widget body;
        if (phase == 'discussion') {
          body = DiscussionView(
            key: ValueKey('disc$day'),
            repo: repo,
            gameId: widget.gameId,
            day: day,
            iAmReady: iAmReady,
            readyCount: readyCount,
            total: players.length,
          );
        } else if (phase == 'voting') {
          body = iAmReady
              ? _waiting(readyCount, players.length, 'Menunggu suara lain...')
              : VotingView(
            key: ValueKey('vote$day'),
            repo: repo,
            gameId: widget.gameId,
            players: players,
          );
        } else if (iAmReady) {
          body = _waiting(readyCount, players.length, 'Menunggu warga lain...');
        } else if (phase == 'offering') {
          body = OfferingView(
            repo: repo,
            gameId: widget.gameId,
            leaves: leaves,
            isAntag: isAntag,
            defs: defs,
            onSubmitted: (n) => setState(() => burst = n),
          );
        } else {
          body = showMarket ? _market(balance) : _hand(day, jailed);
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _currencyBar(balance, rate),
              if (verdict != null && phase == 'day') ...[
                const SizedBox(height: 8),
                _verdictCard(verdict),
              ],
              const SizedBox(height: 12),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }

  Widget _verdictCard(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.amber.withOpacity(0.12),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.amber.withOpacity(0.5)),
    ),
    child: Row(
      children: [
        const Icon(Icons.gavel, size: 18, color: Colors.amber),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );

  Widget _currencyBar(double balance, double rate) => Row(
    children: [
      Icon(isAntag ? Icons.circle : Icons.water_drop,
          size: 26,
          color: isAntag
              ? const Color(0xFF6A5A7A)
              : const Color(0xFF7FD3F7)),
      const SizedBox(width: 8),
      Text(_fmt(balance),
          style:
          const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
      const SizedBox(width: 8),
      Text(isAntag ? 'bulir hitam' : 'tetes embun',
          style: const TextStyle(fontSize: 13)),
      const SizedBox(width: 12),
      Text('+${_fmt(rate)}/hari',
          style: const TextStyle(fontSize: 12, color: Colors.white54)),
    ],
  );

  Widget _hand(int day, bool jailed) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (jailed)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(Icons.lock, size: 16, color: Colors.redAccent),
              SizedBox(width: 6),
              Text('Kamu dikurung hari ini: tidak bisa berbelanja.',
                  style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      const Text('Kartu di mejamu'),
      const SizedBox(height: 8),
      Expanded(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: repo.myHand(widget.gameId),
          builder: (context, hs) {
            final hand = hs.data ?? [];
            return SingleChildScrollView(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in hand)
                    CardTile(
                      def: defs[c['card_id']],
                      fallbackName: c['card_id'] as String,
                    ),
                ],
              ),
            );
          },
        ),
      ),
      FilledButton(
        onPressed: jailed
            ? (busy
            ? null
            : () => _guard(() => repo.finishDay(widget.gameId)))
            : () => setState(() => showMarket = true),
        child: Text('Akhiri hari $day'),
      ),
    ],
  );

  Widget _market(double balance) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pasar Embun: pilih satu kartu, atau lewati'),
        const SizedBox(height: 8),
        Expanded(
          child: offers.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final o in offers)
                  Builder(builder: (_) {
                    final id = o['card_id'] as String;
                    final cost = (defs[id]?['cost'] as int?) ?? 0;
                    final ok = cost <= balance;
                    return CardTile(
                      def: defs[id],
                      fallbackName: id,
                      showCost: true,
                      selected: selected == id,
                      dim: !ok,
                      onTap: ok
                          ? () => setState(() => selected = id)
                          : null,
                    );
                  }),
              ],
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: busy || selected == null
                  ? null
                  : () => _guard(
                      () => repo.finishDay(widget.gameId, card: selected)),
              child: const Text('Beli dan akhiri hari'),
            ),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => _guard(() => repo.finishDay(widget.gameId)),
              child: const Text('Lewati, akhiri hari'),
            ),
            TextButton(
              onPressed: () => setState(() => showMarket = false),
              child: const Text('Kembali'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _waiting(int ready, int total, String text) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(text),
        Text('$ready/$total siap'),
      ],
    ),
  );

  Widget _result(Map<String, dynamic> game) {
    final wargaMenang = game['winner'] == 'warga';
    final verdict = game['verdict'] as String?;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(wargaMenang ? Icons.park : Icons.cloud,
                size: 110,
                color: wargaMenang ? Colors.greenAccent : Colors.blueGrey),
            const SizedBox(height: 16),
            Text(
              wargaMenang
                  ? 'Hayu mekar kembali!'
                  : 'Hayu layu, desa kembali redup...',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (verdict != null) Text(verdict, textAlign: TextAlign.center),
            Text('Daun akhir: ${game['leaves']}'),
            Text(isAntag ? 'Perananmu: Si Terbisik' : 'Perananmu: Warga Desa'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LobbyPage()),
              ),
              child: const Text('Kembali ke balai'),
            ),
          ],
        ),
      ),
    );
  }
}