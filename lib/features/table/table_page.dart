import 'dart:async';
import 'dart:math' show sin;
import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../../data/game_repository.dart';
import '../../data/errors.dart';
import '../../data/lobby_repository.dart';
import '../common/art.dart';
import '../lobby/lobby_page.dart';
import 'card_burst.dart';
import 'chat_sheet.dart';
import 'countdown.dart';
import 'day_view.dart';
import 'discussion_view.dart';
import 'effects_view.dart';
import 'emote_panel.dart';
import 'offering_view.dart';
import 'player_sheet.dart';
import 'village_strip.dart';
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

  // Aliran bersama (satu langganan, dibagikan ke widget anak).
  List<Map<String, dynamic>>? emotes; // null = belum ada data pertama
  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> trades = [];
  List<Map<String, dynamic>> chatMsgs = [];
  Map<String, DateTime> lastSeen = {};
  int _chatSeen = 0;

  Map<String, Map<String, dynamic>> defs = {};
  bool busy = false;
  bool _leaving = false;
  bool disguiseMode = false; // Mode samaran layar untuk Si Terbisik
  int burst = 0;
  int? darkSeed;
  Future<Map<String, Map<String, dynamic>>>? secretsFuture;
  Future<Map<String, dynamic>?>? recapFuture;
  Future<Map<String, String>>? usernamesFuture;
  Map<String, String> usernames = {}; // user_id -> username asli (akhir game)

  bool get isAntag => widget.role == 'antagonis';
  bool get showAsAntag => isAntag && !disguiseMode;

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

    final id = widget.gameId;
    _subs.add(lobby.game(id).listen(_onGame, onError: (_) {}));
    _subs.add(lobby.players(id).listen((p) {
      if (mounted) setState(() => players = p);
    }, onError: (_) {}));
    _subs.add(repo.myState(id).listen((s) {
      if (mounted) setState(() => myState = s);
    }, onError: (_) {}));
    _subs.add(repo.myHand(id).listen((h) {
      if (mounted) setState(() => hand = h);
    }, onError: (_) {}));
    _subs.add(repo.emotes(id).listen((e) {
      if (mounted) setState(() => emotes = e);
    }, onError: (_) {}));
    _subs.add(repo.villageEvents(id).listen((e) {
      if (mounted) setState(() => events = e);
    }, onError: (_) {}));
    _subs.add(repo.trades(id).listen((t) {
      if (mounted) setState(() => trades = t);
    }, onError: (_) {}));
    _subs.add(repo.chat(id).listen((c) {
      if (mounted) setState(() => chatMsgs = c);
    }, onError: (_) {}));
    _subs.add(repo.presence(id).listen((rows) {
      if (!mounted) return;
      final m = <String, DateTime>{};
      for (final r in rows) {
        final t = DateTime.tryParse((r['last_seen'] as String?) ?? '');
        if (t != null) m[r['user_id'] as String] = t;
      }
      setState(() => lastSeen = m);
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

  void _onGame(Map<String, dynamic>? g) {
    if (!mounted) return;
    if (g == null) {
      if (game != null) _backToLobby('Permainan sudah dibubarkan');
      return;
    }
    setState(() => game = g);
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _guard(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) _toast(errMsg(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _backToLobby([String? msg]) {
    if (_leaving || !mounted) return;
    _leaving = true;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LobbyPage()),
    );
    if (msg != null) messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _confirmExit(bool isHost) async {
    final title = isHost ? 'Sudahi permainan?' : 'Tinggalkan permainan?';
    final msg = isHost
        ? 'Permainan berakhir untuk semua pemain.'
        : isAntag
        ? 'Kamu adalah Si Terbisik. Jika kamu pergi, warga langsung menang.'
        : 'Kamu tidak bisa kembali ke permainan ini.';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isHost ? 'Sudahi' : 'Tinggalkan'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => busy = true);
    try {
      if (isHost) {
        await lobby.endGame(widget.gameId);
      } else {
        await lobby.leave(widget.gameId);
        _backToLobby();
      }
    } catch (e) {
      if (mounted) _toast(errMsg(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // ---------- sheet ----------

  void _showPlayersSheet(int day) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14221F),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Daftar Warga Desa',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in players)
                    ListTile(
                      dense: true,
                      leading: PlayerAvatar(
                        path: protagonistPath(p['character_card'] as String),
                        size: 36,
                      ),
                      title: Text(p['name'] as String),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (p['jailed_day'] == day)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(Icons.lock,
                                  size: 18, color: Colors.redAccent),
                            ),
                          Icon(
                            p['ready'] == true
                                ? Icons.check_circle
                                : Icons.schedule,
                            size: 18,
                            color: p['ready'] == true
                                ? Colors.greenAccent
                                : Colors.white38,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _othersChatCount() =>
      chatMsgs.where((m) => m['user_id'] != repo.myId).length;

  Future<void> _openChat() async {
    setState(() => _chatSeen = _othersChatCount());
    await showChatSheet(context,
        repo: repo, gameId: widget.gameId, players: players);
    if (mounted) setState(() => _chatSeen = _othersChatCount());
  }

  void _openEmotes(int day) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF14221F),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: EmotePanel(
          repo: repo,
          gameId: widget.gameId,
          day: day,
          players: players,
        ),
      ),
    );
  }

  void _openPlayer(Map<String, dynamic> p, String phase) {
    showPlayerSheet(
      context,
      repo: repo,
      gameId: widget.gameId,
      player: p,
      hand: hand,
      defs: defs,
      balance: (myState?['balance'] as num?)?.toDouble() ?? 0,
      socialOpen: phase == 'day',
    );
  }

  /// "Online" relatif terhadap detak terbaru siapa pun, supaya tahan selisih
  /// jam antara perangkat dan server.
  Set<String> _online() {
    if (lastSeen.isEmpty) return {};
    final newest =
    lastSeen.values.reduce((a, b) => a.isAfter(b) ? a : b);
    return {
      for (final e in lastSeen.entries)
        if (newest.difference(e.value).inSeconds <= 25) e.key,
    };
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  DateTime? _deadline(Map<String, dynamic> g) {
    final raw = g['phase_deadline'];
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  // ---------- build ----------

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
                dark: showAsAntag,
                leaves: (game?['leaves'] as int?) ?? 30,
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
    final worms = (g['lingering_worms'] as int?) ?? 0;
    final cycle = (g['cycle_len'] as int?) ?? 3;
    final deadline = _deadline(g);
    final isHost = g['host_id'] == repo.myId;

    final me = players.where((p) => p['user_id'] == repo.myId);
    final meRow = me.isEmpty ? null : me.first;
    final iAmReady = meRow?['ready'] == true;
    final readyCount = players.where((p) => p['ready'] == true).length;
    final jailed = meRow?['jailed_day'] == day;
    final myCardId = (meRow?['character_card'] as String?) ?? 'default';

    if (g['status'] == 'finished') return _result(g);

    if (phase == 'effects') {
      return Stack(
        fit: StackFit.expand,
        children: [
          EffectsView(
            key: ValueKey('fx$day'),
            repo: repo,
            gameId: widget.gameId,
            day: day,
            finalLeaves: leaves,
            isAntag: showAsAntag,
            waiting: iAmReady,
            readyCount: readyCount,
            total: players.length,
            onContinue: () =>
                _guard(() => repo.advanceAfterEffects(widget.gameId)),
          ),
          Positioned(
            left: 4,
            top: 4,
            child: SafeArea(
              child: IconButton(
                tooltip: isHost ? 'Sudahi permainan' : 'Tinggalkan permainan',
                onPressed: busy ? null : () => _confirmExit(isHost),
                icon: Icon(
                  isHost ? Icons.stop_circle_outlined : Icons.logout,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Backdrop(path: landscapePath(leaves), dark: showAsAntag, dim: 0.74),
        SafeArea(
          child: Row(
            children: [
              SizedBox(
                  width: 120,
                  child: _sidebar(
                      day, cycle, leaves, worms, deadline, isHost)),
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

  Widget _sidebar(int day, int cycle, int leaves, int worms,
      DateTime? deadline, bool isHost) =>
      Container(
        color: Colors.black38,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('HARI',
                          style: TextStyle(fontSize: 12, letterSpacing: 2)),
                      Text('$day',
                          style: const TextStyle(
                              fontSize: 64, fontWeight: FontWeight.bold)),
                      Text(
                        day % cycle == 0
                            ? 'Malam persembahan'
                            : 'Persembahan ${cycle - day % cycle} hari lagi',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 10, color: Colors.white60),
                      ),
                      const SizedBox(height: 14),
                      Icon(Icons.eco,
                          size: 36,
                          color: showAsAntag
                              ? Colors.blueGrey
                              : Colors.greenAccent),
                      Text('$leaves', style: const TextStyle(fontSize: 28)),
                      const Text('daun', style: TextStyle(fontSize: 12)),
                      if (worms > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('🐛 $worms mlm',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.purpleAccent)),
                        ),
                      ],
                      const SizedBox(height: 18),
                      const Icon(Icons.hourglass_bottom,
                          size: 16, color: Colors.white54),
                      Countdown(
                        deadline: deadline,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
              child: TextButton(
                onPressed: busy ? null : () => _confirmExit(isHost),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isHost ? Icons.stop_circle_outlined : Icons.logout,
                        size: 18),
                    const SizedBox(height: 2),
                    Text(
                      isHost ? 'Sudahi\npermainan' : 'Tinggalkan\npermainan',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
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
    } else if (phase == 'offering') {
      body = iAmReady
          ? _waiting(readyCount, players.length, 'Menunggu warga lain...')
          : OfferingView(
        key: ValueKey('off$day'),
        repo: repo,
        gameId: widget.gameId,
        leaves: leaves,
        isAntag: isAntag,
        hand: hand,
        defs: defs,
        players: players,
        onSubmitted: (n) => setState(() => burst = n),
      );
    } else {
      body = DayView(
        key: ValueKey('day$day'),
        repo: repo,
        gameId: widget.gameId,
        day: day,
        priceMod: (g['price_mod'] as int?) ?? 0,
        extraBuy: (g['extra_buy'] as int?) ?? 0,
        hand: hand,
        defs: defs,
        balance: balance,
        jailed: jailed,
        iAmReady: iAmReady,
        readyCount: readyCount,
        total: players.length,
        players: players,
        events: events,
        trades: trades,
      );
    }

    final showStrip =
        phase == 'day' || phase == 'discussion' || phase == 'voting';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _currencyBar(balance, rate, myCardId, day, readyCount,
              showChat: phase != 'discussion'),
          if (verdict != null && phase == 'day') ...[
            const SizedBox(height: 8),
            _verdictCard(verdict),
          ],
          if (showStrip) ...[
            const SizedBox(height: 4),
            VillageStrip(
              myId: repo.myId,
              players: players,
              emotes: emotes,
              online: _online(),
              day: day,
              onTapPlayer: (p) => _openPlayer(p, phase),
              onEmoteButton: () => _openEmotes(day),
            ),
          ],
          const SizedBox(height: 8),
          Expanded(child: body),
        ],
      ),
    );
  }

  /// Vonis hari sebelumnya: palu diketuk. Kartu membesar lalu menghantam
  /// ke ukuran asli, kilat emas di titik ketukan, lalu bergetar mereda.
  Widget _verdictCard(String text) => TweenAnimationBuilder<double>(
    key: ValueKey(text),
    tween: Tween<double>(begin: 0, end: 1),
    duration: const Duration(milliseconds: 1300),
    builder: (context, t, _) {
      final slam =
      Curves.easeOutBack.transform((t / 0.35).clamp(0.0, 1.0).toDouble());
      final flash = (1 - (t - 0.35).abs() / 0.18).clamp(0.0, 1.0).toDouble();
      final after = ((t - 0.35) / 0.65).clamp(0.0, 1.0).toDouble();
      final dx = t > 0.35 ? sin(after * 60) * 6 * (1 - after) : 0.0;
      return Opacity(
        opacity: (t / 0.15).clamp(0.0, 1.0).toDouble(),
        child: Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.scale(
            scale: 1.18 - 0.18 * slam,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.amber
                        .withValues(alpha: 0.6 + 0.4 * flash)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.7 * flash),
                    blurRadius: 24 * flash,
                    spreadRadius: 2 * flash,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Transform.rotate(
                    angle: -0.9 * (1 - slam),
                    child: const Icon(Icons.gavel,
                        size: 20, color: Colors.amber),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(text, style: const TextStyle(fontSize: 13))),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _currencyBar(
      double balance, double rate, String myCardId, int day, int readyCount,
      {required bool showChat}) {
    final seed = darkSeed;
    final avatar = showAsAntag
        ? (seed == null ? null : darkCardPath(seed))
        : protagonistPath(myCardId);
    final unread =
    (_othersChatCount() - _chatSeen).clamp(0, 99).toInt();
    return Row(
      children: [
        PlayerAvatar(
          path: avatar,
          size: 46,
          ring: showAsAntag ? const Color(0xFFB07CE8) : const Color(0xFF6FBF73),
        ),
        const SizedBox(width: 12),
        Icon(showAsAntag ? Icons.circle : Icons.water_drop,
            size: 26,
            color: showAsAntag
                ? const Color(0xFF8A74A8)
                : const Color(0xFF7FD3F7)),
        const SizedBox(width: 6),
        Text(_fmt(balance),
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Text(showAsAntag ? 'bulir hitam' : 'tetes embun',
            style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 12),
        Text('+${_fmt(rate)}/hari',
            style: const TextStyle(fontSize: 12, color: Colors.white60)),
        const Spacer(),
        if (showChat)
          Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: IconButton(
              tooltip: 'Obrolan',
              onPressed: _openChat,
              icon: const Icon(Icons.chat_bubble_outline, size: 20),
            ),
          ),
        if (isAntag)
          IconButton(
            tooltip: disguiseMode ? 'Matikan Samaran' : 'Samarkan Layar',
            onPressed: () => setState(() => disguiseMode = !disguiseMode),
            icon: Icon(
              disguiseMode ? Icons.visibility_off : Icons.visibility,
              size: 20,
              color: disguiseMode ? Colors.amberAccent : Colors.white54,
            ),
          ),
        ActionChip(
          avatar: const Icon(Icons.people, size: 16),
          label: Text('$readyCount/${players.length}'),
          visualDensity: VisualDensity.compact,
          onPressed: () => _showPlayersSheet(day),
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

  // ---------- hasil + rekap ----------

  Widget _result(Map<String, dynamic> g) {
    final wargaMenang = g['winner'] == 'warga';
    final bubar = g['winner'] == 'dibatalkan';
    final leaves = g['leaves'] as int;
    final day = g['day'] as int;
    final verdict = g['verdict_day'] == day ? g['verdict'] as String? : null;
    secretsFuture ??= lobby.allSecrets(widget.gameId);
    recapFuture ??= repo.recap(widget.gameId).catchError((_) => null);
    usernamesFuture ??= repo.usernames(widget.gameId).then((m) {
      if (mounted) setState(() => usernames = m);
      return m;
    }).catchError((_) => <String, String>{});
    final sakura =
    leaves >= 30 ? AssetCatalog.I.file(pohonDir, 'pohon0-sakura') : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        Backdrop(
            path: landscapePath(leaves), dark: !wargaMenang && !bubar, dim: 0.6),
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
                      bubar
                          ? 'Permainan disudahi'
                          : wargaMenang
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
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _antagReveal(secrets),
                            if (!bubar) _recapSection(secrets),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => _backToLobby(),
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

  Widget _antagReveal(Map<String, Map<String, dynamic>> secrets) {
    final entry = secrets.entries.where((e) => e.value['role'] == 'antagonis');
    if (entry.isEmpty) return const SizedBox(height: 8);
    final antagId = entry.first.key;
    final seed = (entry.first.value['dark_seed'] as int?) ?? 0;
    final who = players.where((p) => p['user_id'] == antagId);
    final name = who.isEmpty ? '?' : who.first['name'] as String;
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
                style:
                const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            if (usernames[antagId] != null)
              Text('yaitu ${usernames[antagId]}',
                  style: const TextStyle(fontSize: 16, color: Colors.white70)),
          ],
        ),
      ],
    );
  }

  String _nameOf(String? id) {
    if (id == null) return '—';
    for (final p in players) {
      if (p['user_id'] == id) return p['name'] as String;
    }
    return '?';
  }

  String _cardName(String id) => (defs[id]?['name'] as String?) ?? id;

  Widget _recapSection(Map<String, Map<String, dynamic>> secrets) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: recapFuture,
      builder: (context, s) {
        final r = s.data;
        if (r == null) return const SizedBox.shrink();
        List<Map<String, dynamic>> list(String k) =>
            List<Map<String, dynamic>>.from((r[k] as List?) ?? const []);
        final offs = list('offerings');
        final buys = list('purchases');
        final votes = list('votes');

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 18),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Rekap permainan',
                      style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                for (final p in players)
                  _recapTile(p, secrets, offs, buys, votes),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _recapTile(
      Map<String, dynamic> p,
      Map<String, Map<String, dynamic>> secrets,
      List<Map<String, dynamic>> offs,
      List<Map<String, dynamic>> buys,
      List<Map<String, dynamic>> votes,
      ) {
    final uid = p['user_id'] as String;
    final antag = secrets[uid]?['role'] == 'antagonis';

    // key = hari*10 + urutan (beli, persembahan, suara) agar urut stabil.
    final lines = <MapEntry<int, String>>[];
    for (final b in buys.where((b) => b['user_id'] == uid)) {
      lines.add(MapEntry((b['day'] as int) * 10,
          'Membeli ${_cardName(b['card_id'] as String)}'));
    }
    final byDay = <int, List<Map<String, dynamic>>>{};
    for (final o in offs.where((o) => o['user_id'] == uid)) {
      byDay.putIfAbsent(o['day'] as int, () => []).add(o);
    }
    byDay.forEach((d, os) {
      final names = os.map((o) => _cardName(o['card_id'] as String)).join(' + ');
      final withTarget = os.where((o) => o['target_id'] != null);
      final tgt = withTarget.isEmpty
          ? ''
          : ' (Lentera ke ${_nameOf(withTarget.first['target_id'] as String?)})';
      lines.add(MapEntry(d * 10 + 1, 'Persembahan: $names$tgt'));
    });
    for (final v in votes.where((v) => v['user_id'] == uid)) {
      final t = v['target_id'] as String?;
      lines.add(MapEntry((v['day'] as int) * 10 + 2,
          t == null ? 'Tidak memilih' : 'Memilih ${_nameOf(t)}'));
    }
    lines.sort((a, b) => a.key.compareTo(b.key));

    return ExpansionTile(
      initiallyExpanded: antag,
      leading: PlayerAvatar(
        path: protagonistPath(p['character_card'] as String),
        size: 34,
        ring: antag ? const Color(0xFFB07CE8) : Colors.white38,
      ),
      title: Text(p['name'] as String),
      subtitle: Text(
        '${usernames[uid] != null ? '${usernames[uid]} · ' : ''}'
            '${antag ? 'Si Terbisik' : 'Warga Desa'}',
        style: TextStyle(
          fontSize: 12,
          color: antag ? const Color(0xFFB07CE8) : Colors.white60,
        ),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lines.isEmpty)
          const Text('Tidak ada catatan.',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('Hari ${l.key ~/ 10}: ${l.value}',
                style: const TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}