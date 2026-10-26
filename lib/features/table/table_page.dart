import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../../data/game_repository.dart';
import '../../data/lobby_repository.dart';
import '../common/art.dart';
import '../lobby/lobby_page.dart';
import 'card_tile.dart';
import 'countdown.dart';
import 'discussion_view.dart';
import 'effects_view.dart';
import 'emote_panel.dart';
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
  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _beat;

  Map<String, dynamic>? game;
  List<Map<String, dynamic>> players = [];
  Map<String, dynamic>? myState;
  List<Map<String, dynamic>> hand = [];

  Map<String, Map<String, dynamic>> defs = {};
  List<Map<String, dynamic>> offers = [];
  int? syncedDay;
  int? _offersFor;
  bool showMarket = false;
  String? selected;
  bool busy = false;
  int burst = 0;
  int? darkSeed;
  Future<Map<String, Map<String, dynamic>>>? secretsFuture;

  bool get isAntag => widget.role == 'antagonis';

  @override
  void initState() {
    super.initState();
    repo.cardDefs().then((d) {
      if (mounted) setState(() => defs = d);
    });
    lobby.mySecret(widget.gameId).then((s) {
      if (mounted && s != null) {
        setState(() => darkSeed = s['dark_seed'] as int?);
      }
    });

    _subs.add(lobby.game(widget.gameId).listen(_onGame, onError: (_) {}));
    _subs.add(lobby.players(widget.gameId).listen((p) {
      if (mounted) setState(() => players = p);
    }, onError: (_) {}));
    _subs.add(repo.myState(widget.gameId).listen((s) {
      if (mounted) setState(() => myState = s);
    }, onError: (_) {}));
    _subs.add(repo.myHand(widget.gameId).listen((h) {
      if (mounted) setState(() => hand = h);
    }, onError: (_) {}));

    _heartbeat();
    _beat = Timer.periodic(const Duration(seconds: 6), (_) => _heartbeat());
  }

  @override
  void dispose() {
    _beat?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  void _heartbeat() {
    repo.tick(widget.gameId).catchError((_) {});
  }

  void _onGame(Map<String, dynamic> g) {
    if (!mounted) return;
    final day = g['day'] as int;
    final phase = (g['phase'] as String?) ?? 'day';
    setState(() {
      game = g;
      if (syncedDay != day) {
        syncedDay = day;
        showMarket = false;
        selected = null;
        offers = [];
      }
    });
    if (phase == 'day') _loadOffers(day);
  }

  void _loadOffers(int day) {
    if (_offersFor == day) return;
    _offersFor = day;
    repo.offers(widget.gameId, day).then((o) {
      if (mounted && syncedDay == day) setState(() => offers = o);
    });
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

  DateTime? _deadline(Map<String, dynamic> g) {
    final raw = g['phase_deadline'];
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  @override
  Widget build(BuildContext context) {
    final g = game;
    return Scaffold(
      backgroundColor: const Color(0xFF0B1512),
      body: Stack(
        fit: StackFit.expand,
        children: [
          g == null
              ? const Center(child: CircularProgressIndicator())
              : _content(g),
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
    );
  }

  Widget _content(Map<String, dynamic> g) {
    final day = g['day'] as int;
    final phase = (g['phase'] as String?) ?? 'day';
    final leaves = g['leaves'] as int;
    final deadline = _deadline(g);

    final me = players.where((p) => p['user_id'] == repo.myId);
    final meRow = me.isEmpty ? null : me.first;
    final iAmReady = meRow?['ready'] == true;
    final readyCount = players.where((p) => p['ready'] == true).length;
    final jailed = meRow?['jailed_day'] == day;
    final myCardId = (meRow?['character_card'] as String?) ?? 'default';

    if (g['status'] == 'finished') return _result(g);

    if (phase == 'effects') {
      return EffectsView(
        key: ValueKey('fx$day'),
        repo: repo,
        gameId: widget.gameId,
        day: day,
        finalLeaves: leaves,
        isAntag: isAntag,
        waiting: iAmReady,
        readyCount: readyCount,
        total: players.length,
        onContinue: () =>
            _guard(() => repo.advanceAfterEffects(widget.gameId)),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Backdrop(path: landscapePath(leaves), dark: isAntag, dim: 0.74),
        SafeArea(
          child: Row(
            children: [
              SizedBox(
                  width: 120, child: _sidebar(day, leaves, deadline)),
              const VerticalDivider(width: 1),
              Expanded(
                child: _panel(g, day, phase, leaves, iAmReady, readyCount,
                    jailed, myCardId, deadline),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sidebar(int day, int leaves, DateTime? deadline) => Container(
    color: Colors.black38,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('HARI',
            style: TextStyle(fontSize: 12, letterSpacing: 2)),
        Text('$day',
            style: const TextStyle(
                fontSize: 64, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Icon(Icons.eco,
            size: 36,
            color: isAntag ? Colors.blueGrey : Colors.greenAccent),
        Text('$leaves', style: const TextStyle(fontSize: 28)),
        const Text('daun', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 18),
        const Icon(Icons.hourglass_bottom,
            size: 16, color: Colors.white54),
        Countdown(
          deadline: deadline,
          style: const TextStyle(fontSize: 18),
        ),
      ],
    ),
  );

  Widget _panel(
      Map<String, dynamic> g,
      int day,
      String phase,
      int leaves,
      bool iAmReady,
      int readyCount,
      bool jailed,
      String myCardId,
      DateTime? deadline,
      ) {
    final balance = (myState?['balance'] as num?)?.toDouble() ?? 0;
    final rate = (myState?['rate'] as num?)?.toDouble() ?? 0;
    final verdict = (g['verdict_day'] == day - 1 && g['verdict'] != null)
        ? g['verdict'] as String
        : null;

    Widget body;
    if (phase == 'discussion') {
      body = DiscussionView(
        key: ValueKey('disc$day'),
        repo: repo,
        gameId: widget.gameId,
        day: day,
        deadline: deadline,
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
        key: ValueKey('off$day'),
        repo: repo,
        gameId: widget.gameId,
        leaves: leaves,
        isAntag: isAntag,
        hand: hand,
        defs: defs,
        onSubmitted: (n) => setState(() => burst = n),
      );
    } else {
      body = showMarket ? _market(balance) : _hand(day, jailed);
    }

    final showEmotes = phase == 'day' && (iAmReady || !showMarket);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _currencyBar(balance, rate, myCardId),
          if (verdict != null && phase == 'day') ...[
            const SizedBox(height: 8),
            _verdictCard(verdict),
          ],
          const SizedBox(height: 12),
          Expanded(child: body),
          if (showEmotes) ...[
            const SizedBox(height: 8),
            EmotePanel(
              key: ValueKey('emo$day'),
              repo: repo,
              gameId: widget.gameId,
              day: day,
              players: players,
            ),
          ],
        ],
      ),
    );
  }

  Widget _verdictCard(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
    ),
    child: Row(
      children: [
        const Icon(Icons.gavel, size: 18, color: Colors.amber),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );

  Widget _currencyBar(double balance, double rate, String myCardId) {
    final seed = darkSeed;
    final avatar = isAntag
        ? (seed == null ? null : darkCardPath(seed))
        : protagonistPath(myCardId);
    return Row(
      children: [
        PlayerAvatar(
          path: avatar,
          size: 46,
          ring: isAntag ? const Color(0xFFB07CE8) : const Color(0xFF6FBF73),
        ),
        const SizedBox(width: 12),
        Icon(isAntag ? Icons.circle : Icons.water_drop,
            size: 26,
            color:
            isAntag ? const Color(0xFF8A74A8) : const Color(0xFF7FD3F7)),
        const SizedBox(width: 6),
        Text(_fmt(balance),
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Text(isAntag ? 'bulir hitam' : 'tetes embun',
            style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 12),
        Text('+${_fmt(rate)}/hari',
            style: const TextStyle(fontSize: 12, color: Colors.white60)),
      ],
    );
  }

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
        child: SingleChildScrollView(
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

  Widget _result(Map<String, dynamic> g) {
    final wargaMenang = g['winner'] == 'warga';
    final leaves = g['leaves'] as int;
    final day = g['day'] as int;
    final verdict = g['verdict_day'] == day ? g['verdict'] as String? : null;
    secretsFuture ??= lobby.allSecrets(widget.gameId);
    final sakura =
    leaves >= 30 ? AssetCatalog.I.file(pohonDir, 'pohon0-sakura') : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        Backdrop(path: landscapePath(leaves), dark: !wargaMenang, dim: 0.6),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 260,
                      child:
                      TreePortrait(leaves: leaves, pathOverride: sakura),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      wargaMenang
                          ? 'Hayu mekar kembali!'
                          : 'Hayu layu, desa kembali redup...',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    if (verdict != null)
                      Text(verdict, textAlign: TextAlign.center),
                    Text('Daun akhir: $leaves'),
                    const SizedBox(height: 16),
                    FutureBuilder<Map<String, Map<String, dynamic>>>(
                      future: secretsFuture,
                      builder: (context, s) {
                        final secrets = s.data;
                        if (secrets == null) return const SizedBox(height: 8);
                        final entry = secrets.entries
                            .where((e) => e.value['role'] == 'antagonis');
                        if (entry.isEmpty) return const SizedBox(height: 8);
                        final antagId = entry.first.key;
                        final seed =
                            (entry.first.value['dark_seed'] as int?) ?? 0;
                        final who =
                        players.where((p) => p['user_id'] == antagId);
                        final name =
                        who.isEmpty ? '?' : who.first['name'] as String;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CardArt(
                              path: darkCardPath(seed),
                              width: 90,
                              glow: const Color(0xFFB07CE8),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Si Terbisik ternyata...',
                                    style: TextStyle(color: Colors.white70)),
                                Text(name,
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LobbyPage()),
                      ),
                      child: const Text('Kembali ke balai'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}