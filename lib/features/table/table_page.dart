import 'dart:async';
import 'dart:math' show sin;
import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../../data/game_repository.dart';
import '../../data/errors.dart';
import '../../data/lobby_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import '../lobby/lobby_page.dart';
import 'card_burst.dart';
import 'chat_sheet.dart';
import 'chat_spotlight.dart';
import 'countdown.dart';
import 'day_transition.dart';
import 'day_view.dart';
import 'discussion_view.dart';
import 'effects_view.dart';
import 'emote_panel.dart';
import 'offering_transition.dart';
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
  List<Map<String, dynamic>>? chatMsgs; // null = belum ada data pertama
  Map<String, DateTime> lastSeen = {};
  int _chatSeen = 0;

  // Efek obrolan dramatis di luar sheet obrolan (layar meja + diskusi).
  bool chatFx = true;
  bool _chatOpen = false; // sheet obrolan punya adegannya sendiri

  // Adegan peralihan layar penuh. _dayIntro['kind'] = 'day' (fajar hari
  // baru) atau 'offering' (menuju Hayu). _lastIntroDay / _lastOfferDay
  // mencegah adegan diputar ulang (mis. saat masuk kembali di tengah
  // permainan).
  Map<String, dynamic>? _dayIntro;
  int? _lastIntroDay;
  int? _lastOfferDay;
  bool _offerSeeded = false;

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

  /// Hari yang vonisnya sudah ditutup pemain (kartu vonis memakan tempat,
  /// jadi bisa disembunyikan dengan satu ketukan).
  int? _verdictHiddenDay;

  /// Di bawah lebar ini (ponsel) sidebar hari diganti header ringkas di atas.
  static const _narrowBreakpoint = 720.0;

  /// Di atas lebar ini (desktop lebar) isi dipusatkan dengan lebar maksimum
  /// supaya kartu dan kolom tidak melebar berlebihan di layar ultra-lebar.
  static const _wideBreakpoint = 1100.0;
  static const _maxContentWidth = 1280.0;

  bool get _narrow => MediaQuery.sizeOf(context).width < _narrowBreakpoint;
  bool get _wide => MediaQuery.sizeOf(context).width >= _wideBreakpoint;

  /// Layar sangat pendek (ponsel miring): rapatkan jarak antarbagian.
  bool get _short => MediaQuery.sizeOf(context).height < 480;

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
    // Stream tangan hanya dipakai sebagai PEMICU. Isinya tidak dipercaya:
    // peristiwa hapus tidak sampai, jadi kartu yang sudah dipersembahkan
    // atau ditukar tertinggal di sana. Daftar asli diambil dari database.
    _subs.add(repo.myHand(id).listen((_) => _refreshHand(), onError: (_) {}));
    _refreshHand();
    _subs.add(repo.emotes(id).listen((e) {
      if (mounted) setState(() => emotes = e);
    }, onError: (_) {}));
    _subs.add(repo.villageEvents(id).listen((e) {
      if (mounted) setState(() => events = e);
    }, onError: (_) {}));
    _subs.add(repo.trades(id).listen((t) {
      if (mounted) setState(() => trades = t);
      _refreshHand(); // tukar kartu mengubah pemilik kartu
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
    _refreshHand();
  }

  bool _handBusy = false;
  bool _handAgain = false;

  /// Ambil tangan kartu yang sebenarnya. Panggilan yang menumpuk digabung.
  Future<void> _refreshHand() async {
    if (_handBusy) {
      _handAgain = true;
      return;
    }
    _handBusy = true;
    try {
      do {
        _handAgain = false;
        final h = await repo.handNow(widget.gameId);
        if (!mounted) return;
        setState(() => hand = h);
      } while (_handAgain);
    } catch (_) {
      // Biarkan daftar lama; percobaan berikutnya menyusul.
    } finally {
      _handBusy = false;
    }
  }

  void _onGame(Map<String, dynamic>? g) {
    if (!mounted) return;
    if (g == null) {
      if (game != null) _backToLobby('Permainan sudah dibubarkan');
      return;
    }
    final changed = game?['day'] != g['day'] || game?['phase'] != g['phase'];
    setState(() {
      game = g;
      _checkDayIntro(g);
      _checkOfferIntro(g);
    });
    // Ganti fase/hari: kartu bisa bertambah (persembahan) atau terpakai.
    if (changed) _refreshHand();
  }

  /// Putar adegan menuju Hayu saat fase 'offering' dimulai. Data pertama
  /// dianggap riwayat, jadi masuk kembali saat fase persembahan tidak
  /// memutarnya lagi.
  void _checkOfferIntro(Map<String, dynamic> g) {
    if (g['status'] == 'finished') return;
    final day = g['day'] as int;
    final phase = (g['phase'] as String?) ?? 'day';
    if (!_offerSeeded) {
      _offerSeeded = true;
      if (phase == 'offering') _lastOfferDay = day;
      return;
    }
    if (phase != 'offering' || day == _lastOfferDay) return;
    _lastOfferDay = day;
    _dayIntro = {
      'kind': 'offering',
      'day': day,
      'leaves': (g['leaves'] as int?) ?? 30,
    };
  }

  /// Putar adegan peralihan hari saat hari baru dimulai (fase 'day').
  /// Data pertama dianggap riwayat, kecuali hari 1 yang baru dimulai.
  void _checkDayIntro(Map<String, dynamic> g) {
    if (g['status'] == 'finished') return;
    final day = g['day'] as int;
    final phase = (g['phase'] as String?) ?? 'day';
    if (_lastIntroDay == null) {
      _lastIntroDay = day;
      if (!(day == 1 && phase == 'day')) return;
    } else {
      if (phase != 'day' || day == _lastIntroDay) return;
      _lastIntroDay = day;
    }
    _dayIntro = {
      'kind': 'day',
      'day': day,
      'leaves': (g['leaves'] as int?) ?? 30,
      'cycle': (g['cycle_len'] as int?) ?? 3,
      'verdict': (g['verdict_day'] == day - 1 && g['verdict'] != null)
          ? g['verdict'] as String
          : null,
    };
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
            const SectionHeader(icon: 'persona', title: 'Daftar Warga Desa'),
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
                              child: GameIcon('lock', size: 26),
                            ),
                          GameIcon(p['ready'] == true ? 'centang' : 'wait',
                              size: 28),
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

  int _othersChatCount() => (chatMsgs ?? const <Map<String, dynamic>>[])
      .where((m) => m['user_id'] != repo.myId)
      .length;

  Future<void> _openChat() async {
    setState(() {
      _chatSeen = _othersChatCount();
      _chatOpen = true;
    });
    await showChatSheet(context,
        repo: repo, gameId: widget.gameId, players: players);
    if (mounted) {
      setState(() {
        _chatOpen = false;
        _chatSeen = _othersChatCount();
      });
    }
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

  /// Adegan obrolan hanya tampil di fase hari biasa dan diskusi, saat efek
  /// menyala dan sheet obrolan sedang tertutup.
  bool _spotlightOn(Map<String, dynamic>? g) {
    if (g == null || g['status'] == 'finished') return false;
    final phase = (g['phase'] as String?) ?? 'day';
    return chatFx &&
        !_chatOpen &&
        _dayIntro == null &&
        (phase == 'day' || phase == 'discussion');
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
              ? const EmbunLoading(text: 'Memasuki desa...')
              : _content(g),
          // Dipasang di sini (bukan di _content) supaya tetap hidup antar
          // fase dan tidak memutar ulang pesan lama.
          Positioned.fill(
            child: ChatSpotlightLayer(
              messages: chatMsgs,
              players: players,
              myId: repo.myId,
              enabled: _spotlightOn(g),
              // Tanpa sidebar di ponsel: adegan memakai lebar penuh dan
              // lebih pendek supaya tidak menutupi kartu terlalu banyak.
              leftInset: _narrow ? 12 : 137,
              topInset: _narrow ? 172 : 190,
              bottomInset: _narrow ? 96 : 130,
              sceneHeight: _narrow ? 190 : 240,
            ),
          ),
          if (_dayIntro != null)
            Positioned.fill(
              child: _dayIntro!['kind'] == 'offering'
                  ? OfferingTransition(
                key: ValueKey('offer${_dayIntro!['day']}'),
                day: _dayIntro!['day'] as int,
                leaves: _dayIntro!['leaves'] as int,
                dark: showAsAntag,
                onDone: () {
                  if (mounted) setState(() => _dayIntro = null);
                },
              )
                  : DayTransition(
                key: ValueKey('intro${_dayIntro!['day']}'),
                day: _dayIntro!['day'] as int,
                leaves: _dayIntro!['leaves'] as int,
                cycle: _dayIntro!['cycle'] as int,
                verdict: _dayIntro!['verdict'] as String?,
                dark: showAsAntag,
                onDone: () {
                  if (mounted) setState(() => _dayIntro = null);
                },
              ),
            ),
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
            left: 8,
            top: 8,
            child: SafeArea(
              child: Tooltip(
                message: isHost ? 'Sudahi permainan' : 'Tinggalkan permainan',
                child: MedallionButton(
                  icon: isHost ? 'bubarkan' : 'keluar',
                  size: 40,
                  onTap: busy ? null : () => _confirmExit(isHost),
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
          child: _narrow
              ? _panel(g, day, phase, leaves, iAmReady, readyCount, jailed,
              myCardId, deadline,
              narrow: true, cycle: cycle, worms: worms, isHost: isHost)
              : Row(
            children: [
              SizedBox(
                width: _wide ? 128 : 104,
                child: _sidebar(
                    day, cycle, leaves, worms, deadline, isHost),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                // Isi dipusatkan dan dibatasi lebarnya di layar lebar.
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                        maxWidth: _maxContentWidth),
                    child: _panel(g, day, phase, leaves, iAmReady,
                        readyCount, jailed, myCardId, deadline,
                        narrow: false,
                        cycle: cycle,
                        worms: worms,
                        isHost: isHost),
                  ),
                ),
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
                      const GameIcon('hari', size: 40),
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
                      const GameIcon('helaidaun', size: 44),
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
                    GameIcon(isHost ? 'bubarkan' : 'keluar', size: 30),
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
      DateTime? deadline, {
        required bool narrow,
        required int cycle,
        required int worms,
        required bool isHost,
      }) {
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
        players: players,
        events: events,
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
        onSubmitted: (n) {
          setState(() => burst = n);
          _refreshHand();
        },
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
        dark: showAsAntag,
      );
    }

    final showStrip =
        phase == 'day' || phase == 'discussion' || phase == 'voting';

    final gap = _short ? 6.0 : (narrow ? 8.0 : 12.0);
    final showVerdict = verdict != null &&
        phase == 'day' &&
        _dayIntro == null &&
        _verdictHiddenDay != day;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: narrow ? 10 : (_wide ? 24 : 16),
        vertical: narrow ? 8 : 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (narrow)
            _phoneHeader(
              balance: balance,
              rate: rate,
              myCardId: myCardId,
              day: day,
              cycle: cycle,
              leaves: leaves,
              worms: worms,
              deadline: deadline,
              isHost: isHost,
              showChat: phase != 'discussion',
            )
          else
            _currencyBar(balance, rate, myCardId, day, readyCount,
                showChat: phase != 'discussion'),
          // Vonis: ringkas, bisa ditutup, dan tidak menumpuk dengan bilah desa.
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: showVerdict
                ? Padding(
              padding: EdgeInsets.only(top: gap),
              child: _verdictCard(verdict!, day,
                  compact: narrow || _short),
            )
                : const SizedBox(width: double.infinity),
          ),
          if (showStrip) ...[
            SizedBox(height: gap),
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
          SizedBox(height: gap),
          // Selama adegan peralihan, isi hari ditahan supaya animasi Kabar Pagi
          // dan vonis baru diputar saat adegan selesai.
          Expanded(child: _dayIntro == null ? body : const SizedBox.shrink()),
        ],
      ),
    );
  }

  /// Vonis hari sebelumnya: palu diketuk. Kartu membesar lalu menghantam
  /// ke ukuran asli, kilat emas di titik ketukan, lalu bergetar mereda.
  Widget _verdictCard(String text, int day, {bool compact = false}) =>
      TweenAnimationBuilder<double>(
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
                  padding: compact
                      ? const EdgeInsets.fromLTRB(10, 6, 4, 6)
                      : const EdgeInsets.fromLTRB(14, 10, 6, 10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
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
                        child: GameIcon('vote', size: compact ? 26 : 32),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          text,
                          maxLines: compact ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: compact ? 12 : 13, height: 1.3),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tutup',
                        visualDensity: VisualDensity.compact,
                        constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        color: Colors.white54,
                        onPressed: () => setState(() => _verdictHiddenDay = day),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );

  /// Header ringkas untuk ponsel: menggantikan sidebar hari dan bar mata
  /// uang. Baris 1: avatar, saldo, obrolan, menu. Baris 2: hari, daun,
  /// ulat, hitung mundur, daftar warga. Aksi sekunder ada di menu titik tiga.
  Widget _phoneHeader({
    required double balance,
    required double rate,
    required String myCardId,
    required int day,
    required int cycle,
    required int leaves,
    required int worms,
    required DateTime? deadline,
    required bool isHost,
    required bool showChat,
  }) {
    final seed = darkSeed;
    final avatar = showAsAntag
        ? (seed == null ? null : darkCardPath(seed))
        : protagonistPath(myCardId);
    final accent =
    showAsAntag ? const Color(0xFFB07CE8) : const Color(0xFF6FBF73);
    final unread = (_othersChatCount() - _chatSeen).clamp(0, 99).toInt();
    final readyCount = players.where((p) => p['ready'] == true).length;
    final due = day % cycle == 0
        ? 'Malam persembahan'
        : 'Persembahan ${cycle - day % cycle} hari lagi';

    PopupMenuItem<String> item(String v, String i, String t, {Color? c}) =>
        PopupMenuItem<String>(
          value: v,
          child: Row(
            children: [
              GameIcon(i, size: 26),
              const SizedBox(width: 10),
              Text(t, style: TextStyle(color: c)),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 6),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PlayerAvatar(path: avatar, size: 40, ring: accent),
              const SizedBox(width: 10),
              GameIcon(showAsAntag ? 'bulirhitam' : 'bulirembun', size: 28),
              const SizedBox(width: 6),
              // Saldo di atas, laju per hari tepat di bawahnya (hemat lebar).
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_fmt(balance),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 22,
                            height: 1.05,
                            fontWeight: FontWeight.bold)),
                    Text('+${_fmt(rate)}/hari',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white60)),
                  ],
                ),
              ),
              const Spacer(),
              if (showChat)
                Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: IconButton(
                    tooltip: 'Obrolan',
                    visualDensity: VisualDensity.compact,
                    onPressed: _openChat,
                    icon: const GameIcon('discuss', size: 30),
                  ),
                ),
              PopupMenuButton<String>(
                tooltip: 'Menu',
                icon: const GameIcon('menu', size: 30),
                padding: EdgeInsets.zero,
                onSelected: (v) {
                  switch (v) {
                    case 'players':
                      _showPlayersSheet(day);
                    case 'fx':
                      setState(() => chatFx = !chatFx);
                    case 'mask':
                      setState(() => disguiseMode = !disguiseMode);
                    case 'exit':
                      if (!busy) _confirmExit(isHost);
                  }
                },
                itemBuilder: (_) => [
                  item('players', 'persona', 'Daftar warga'),
                  item(
                      'fx',
                      'showaddgraphic',
                      chatFx ? 'Matikan efek obrolan' : 'Nyalakan efek obrolan',
                      c: chatFx ? Colors.amberAccent : null),
                  if (isAntag)
                    item(
                        'mask',
                        disguiseMode ? 'hide' : 'show',
                        disguiseMode ? 'Matikan samaran' : 'Samarkan layar',
                        c: disguiseMode ? Colors.amberAccent : null),
                  const PopupMenuDivider(),
                  item(
                      'exit',
                      isHost ? 'bubarkan' : 'keluar',
                      isHost ? 'Sudahi permainan' : 'Tinggalkan permainan',
                      c: Colors.redAccent),
                ],
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(0, 4, 6, 4),
            child: Divider(height: 1, color: Colors.white10),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Row(
              children: [
                // Kiri: hari, daun, ulat. Boleh menyusut di layar sempit.
                Expanded(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('HARI $day',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const GameIcon('helaidaun', size: 20),
                          const SizedBox(width: 3),
                          Text('$leaves',
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                      if (worms > 0)
                        Text('🐛 $worms',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.purpleAccent)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Countdown(
                    deadline: deadline, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                ActionChip(
                  avatar: const GameIcon('persona', size: 18),
                  label: Text('$readyCount/${players.length}',
                      style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onPressed: () => _showPlayersSheet(day),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(due,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Colors.white54)),
          ),
        ],
      ),
    );
  }

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
        GameIcon(showAsAntag ? 'bulirhitam' : 'bulirembun', size: 34),
        const SizedBox(width: 6),
        Text(_fmt(balance),
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        // Label dan laju menyusut lebih dulu bila lebar terbatas.
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(showAsAntag ? 'bulir hitam' : 'tetes embun',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13)),
              Text('+${_fmt(rate)}/hari',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                  const TextStyle(fontSize: 12, color: Colors.white60)),
            ],
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: chatFx ? 'Matikan efek obrolan' : 'Nyalakan efek obrolan',
          visualDensity: VisualDensity.compact,
          onPressed: () => setState(() => chatFx = !chatFx),
          icon: Opacity(
            opacity: chatFx ? 1 : 0.4,
            child: const GameIcon('showaddgraphic', size: 30),
          ),
        ),
        if (showChat)
          Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: IconButton(
              tooltip: 'Obrolan',
              onPressed: _openChat,
              icon: const GameIcon('discuss', size: 30),
            ),
          ),
        if (isAntag)
          IconButton(
            tooltip: disguiseMode ? 'Matikan Samaran' : 'Samarkan Layar',
            onPressed: () => setState(() => disguiseMode = !disguiseMode),
            icon: GameIcon(disguiseMode ? 'hide' : 'show', size: 30),
          ),
        ActionChip(
          avatar: const GameIcon('persona', size: 22),
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
        const GameIcon('wait', size: 72),
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
                      height: 48,
                      child: GameImage(
                          path: logoPath('logoteks-transparent'),
                          fit: BoxFit.contain,
                          cacheWidth: 600),
                    ),
                    const SizedBox(height: 10),
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
                    EmbunButton(
                      label: 'Kembali ke balai',
                      icon: 'home',
                      onPressed: () => _backToLobby(),
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
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Si Terbisik ternyata...',
                  style: TextStyle(color: Colors.white70)),
              Text(name,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              if (usernames[antagId] != null)
                Text('yaitu ${usernames[antagId]}',
                    style:
                    const TextStyle(fontSize: 16, color: Colors.white70)),
            ],
          ),
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
          : ' (sasaran: ${_nameOf(withTarget.first['target_id'] as String?)})';
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