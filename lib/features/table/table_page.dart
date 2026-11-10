import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/asset_catalog.dart';
import '../../data/game_repository.dart';
import '../../data/hayu_effects.dart';
import '../../data/embun_data.dart';
import '../../data/errors.dart';
import '../../data/lobby_repository.dart';
import '../common/art.dart';
import '../common/cloth_transition.dart';
import '../common/ornate.dart';
import '../common/sfx.dart';
import '../common/scene_flow.dart';
import '../lobby/lobby_page.dart';
import 'chat_sheet.dart';
import 'chat_spotlight.dart';
import 'day_chrome.dart';
import 'day_transition.dart';
import 'day_view.dart';
import 'discussion_view.dart';
import 'effects_view.dart';
import 'economy_fx.dart';
import 'gift_fx.dart';
import 'jail_verdict_scene.dart';
import 'eviction_verdict_scene.dart';
import 'emote_panel.dart';
import 'ending_cinematic.dart';
import 'final_screen.dart';
import 'offering_ceremony.dart';
import 'offering_transition.dart';
import 'offering_view.dart';
import 'research_view.dart';
import '../guide/guide_page.dart';
import 'ability_panel.dart';
import 'vote_reveal_scene.dart';
import 'night_scene.dart';
import 'night_plan_dialog.dart';
import 'night_choice.dart';
import 'my_info_sheet.dart';
import 'player_sheet.dart';
import 'parts_strip.dart';
import 'phase_title.dart';
import 'player_status.dart';
import 'village_strip.dart';
import 'voting_view.dart';

class TablePage extends StatefulWidget {
  final String gameId;
  final String role;
  final DayTab initialDayTab;
  final bool showOpeningScenes;
  final VoidCallback? onExit;

  const TablePage({
    super.key,
    required this.gameId,
    required this.role,
    this.initialDayTab = DayTab.market,
    this.showOpeningScenes = true,
    this.onExit,
  });

  @override
  State<TablePage> createState() => _TablePageState();
}

class _TablePageState extends State<TablePage> {
  late final repo = EmbunData.maybeOf(context)?.game ?? GameRepository();
  late final lobby = EmbunData.maybeOf(context)?.lobby ?? LobbyRepository();
  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _beat;

  Map<String, dynamic>? game;
  List<Map<String, dynamic>> players = [];
  Map<String, dynamic>? myState;
  List<Map<String, dynamic>> hand = [];

  // Aliran bersama (satu langganan, dibagikan ke widget anak).
  List<Map<String, dynamic>>? emotes; // null = belum ada data pertama
  List<Map<String, dynamic>> events = [];

  // ---- animasi memberi / menerima (lihat gift_fx.dart) ----
  final GlobalKey _balanceKey = GlobalKey();
  final GlobalKey _mejaKey = GlobalKey();
  final GlobalKey _stripKey = GlobalKey();
  final GlobalKey _playersKey = GlobalKey();
  final Map<String, GlobalKey> _avatarKeys = {};
  final Set<String> _eventIds = {};
  bool _eventsPrimed = false;
  DateTime? _giveSeenAt; // peristiwa 'give' baru terlihat (siapa pun pelakunya)
  DateTime? _ownGiveAt; // aku sendiri baru memberi embun
  final Map<String, String> _tradeStatus = {};
  bool _tradesPrimed = false;
  String? _swapOther; // lawan tukar kartu yang baru selesai
  DateTime? _swapAt;
  bool _handPrimed = false;
  ({List<Map<String, dynamic>> added, List<Map<String, dynamic>> removed, DateTime at})?
  _pendingDiff;
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

  // Pembukaan suara (siapa memilih siapa) setelah voting. Berjalan SEBELUM
  // adegan kurungan/fajar/akhir, yang ditahan selama adegan ini tampil.
  // _voteReveal['rows'] null = data masih diambil (layar gelap sebentar).
  Map<String, dynamic>? _voteReveal;
  int? _lastRevealDay;

  // Adegan pengusiran: pemain yang dituduh mayoritas untuk kedua kalinya
  // keluar dari desa. Dimulai bersama pembukaan suara, tampil SETELAH suara
  // dibuka dan SEBELUM adegan kurungan / fajar / akhir.
  // _evict['row'] null = data masih diambil (layar gelap sebentar).
  Map<String, dynamic>? _evict;

  // Layar malam di antara dua hari biasa (pengumuman serangan Si Terbisik).
  // Sama seperti pembukaan suara: menahan adegan fajar sampai selesai.
  Map<String, dynamic>? _nightScene;
  int? _lastNightDay;
  bool _nightArmed = false; // Si Terbisik: sudah menyiapkan serangan malam ini
  int? _lastIntroDay;
  int? _lastOfferDay;
  bool _offerSeeded = false;

  Map<String, Map<String, dynamic>> defs = {};
  bool busy = false;
  bool _leaving = false;
  bool disguiseMode = false; // Mode samaran layar untuk Si Terbisik
  int? _ceremonyDay; // hari yang adegan pelemparan kartunya sudah selesai
  bool _ceremonyCovered = false; // adegan itu sudah menampilkan hasil tiap kartu

  // Kain terhempas di pergantian fase (lihat ClothSweepLayer). Matikan salah
  // satunya dengan false bila tidak diinginkan.
  static const _clothAfterCeremony = true; // pelemparan kartu -> hasil efek
  static const _clothToDiscussion = true; // hasil efek -> diskusi

  // Gaya kain tiap momen. Ganti dengan ClothStyle.pick(dark: showAsAntag)
  // bila ingin gaya acak. Sisi Si Terbisik otomatis berpalet ungu.
  static const _styleToEffects = ClothStyle.daunHayu;
  static const _styleToDiscussion = ClothStyle.bungaKrem;
  final _cloth = GlobalKey<ClothSweepLayerState>();

  /// Fase lama yang ditahan di layar sampai kain menutup penuh. Server
  /// mengganti fase seketika, sedangkan kain butuh ~0,75 dtk untuk menutup.
  Map<String, dynamic>? _heldGame;
  int? darkSeed;

  // Kemampuan acak warga (hanya terlihat oleh pemiliknya).
  Map<String, Map<String, dynamic>> abilityDefs = {};
  String abilityId = 'biasa';
  bool abilityUsed = false;
  bool _abilityKnown = false;
  bool _abilityRevealed = false;
  final ValueNotifier<int> _marketTick = ValueNotifier<int>(0);
  Future<Map<String, Map<String, dynamic>>>? secretsFuture;
  Future<Map<String, dynamic>?>? recapFuture;
  Future<Map<String, String>>? usernamesFuture;
  late bool _endingSeen = !widget.showOpeningScenes;
  Map<String, String> usernames = {}; // user_id -> username asli (akhir game)

  bool get isAntag => widget.role == 'antagonis';
  bool get _duo => game?['antagonist_count'] == 2;

  final _terbisikChatAccess = ValueNotifier<bool>(false);
  String? _terbisikPartnerId;

  void _syncTerbisikChat() {
    final me = _meRow;
    _terbisikChatAccess.value = isAntag &&
        _duo &&
        game?['status'] == 'playing' &&
        me != null &&
        !isOut(me);
  }

  Future<void> _openTerbisikChat() => showChatSheet(
        context,
        repo: repo,
        gameId: widget.gameId,
        players: players,
        terbisikAccess: _terbisikChatAccess,
        partnerName: _terbisikPartnerId == null
            ? null
            : _nameOf(_terbisikPartnerId),
      );

  /// Adegan yang harus selesai dulu sebelum fajar / adegan persembahan.
  bool get _holdIntro =>
      _voteReveal != null || _evict != null || _nightScene != null;

  /// Pemain yang masih di desa (yang sudah keluar tidak dihitung).
  List<Map<String, dynamic>> get _alive =>
      players.where((p) => !isOut(p)).toList();

  Map<String, dynamic>? get _meRow {
    for (final p in players) {
      if (p['user_id'] == repo.myId) return p;
    }
    return null;
  }
  bool get showAsAntag => isAntag && !disguiseMode;

  /// Hari yang vonisnya sudah ditutup pemain (kartu vonis memakan tempat,
  /// jadi bisa disembunyikan dengan satu ketukan).
  int? _verdictHiddenDay;
  int? _kabarHiddenDay;

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
    Sfx.I.music(Snd.bgmMeja, owner: this);
    repo.cardDefs().then((d) {
      if (mounted) setState(() => defs = d);
    });
    lobby.mySecret(widget.gameId).then((s) {
      if (mounted && s != null) {
        setState(() => darkSeed = s['dark_seed'] as int?);
      }
    });
    repo.abilityDefs().then((d) {
      if (mounted) setState(() => abilityDefs = d);
    }).catchError((_) {});
    _loadAbility(reveal: true);

    final id = widget.gameId;
    _subs.add(lobby.game(id).listen(_onGame, onError: (_) {}));
    _subs.add(lobby.players(id).listen((p) {
      if (!mounted) return;
      setState(() => players = p);
      _syncTerbisikChat();
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
      _noteEvents(e);
    }, onError: (_) {}));
    _subs.add(repo.trades(id).listen((t) {
      if (mounted) setState(() => trades = t);
      _noteTrades(t);
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
    _marketTick.dispose();
    _terbisikChatAccess.dispose();
    Sfx.I.release(this);
    _beat?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  // ===================== animasi memberi / menerima =====================

  GlobalKey _avatarKey(String id) =>
      _avatarKeys.putIfAbsent(id, () => GlobalKey());

  bool get _fxBlocked => _dayIntro != null || _holdIntro;

  /// Persegi avatar pemain di deretan desa; bila tak tampil, jatuh ke deretan
  /// desa secara umum, lalu ke tengah atas layar.
  Rect _avatarRect(String? id) {
    final r = id == null ? null : globalRectOf(_avatarKeys[id]);
    if (r != null) return r;
    final strip = globalRectOf(_stripKey) ?? globalRectOf(_playersKey);
    if (strip != null) return Rect.fromCenter(center: strip.center, width: 38, height: 38);
    final s = MediaQuery.sizeOf(context);
    return Rect.fromCenter(center: Offset(s.width / 2, 120), width: 38, height: 38);
  }

  Rect _mejaRect() => globalRectOf(_mejaKey) ?? screenFallbackRect(context);

  /// Peristiwa desa baru: catat saat 'give' muncul (isinya tak dipakai, supaya
  /// pemberi embun tetap rahasia). Data pertama dianggap riwayat.
  void _noteEvents(List<Map<String, dynamic>> list) {
    var fresh = false;
    for (final e in list) {
      final id = '${e['id']}';
      if (_eventIds.add(id) && _eventsPrimed && e['kind'] == 'give') {
        fresh = true;
      }
    }
    _eventsPrimed = true;
    if (!fresh) return;
    final own = _ownGiveAt;
    if (own != null &&
        DateTime.now().difference(own) < const Duration(seconds: 6)) {
      return; // kemungkinan besar pemberianku sendiri
    }
    _giveSeenAt = DateTime.now();
  }

  /// Dipanggil BalanceFx saat saldo berubah. true = tetes bawaan dibisukan
  /// karena lapisan pemberian yang memainkannya.
  bool _quietBalance(double delta) {
    final now = DateTime.now();
    if (delta > 0) {
      final seen = _giveSeenAt;
      if (seen != null &&
          now.difference(seen) < const Duration(seconds: 5) &&
          !_fxBlocked) {
        _giveSeenAt = null;
        _scheduleEmbunArrival(delta);
        return true;
      }
      return false;
    }
    final own = _ownGiveAt;
    return own != null && now.difference(own) < const Duration(seconds: 6);
  }

  /// Embun masuk dari desa (pemberi dirahasiakan): tetes dari deretan avatar
  /// menuju saldo. Dijadwalkan setelah frame karena dipicu saat membangun.
  void _scheduleEmbunArrival(double delta) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _fxBlocked) return;
      final to = globalRectOf(_balanceKey);
      if (to == null) return;
      final strip = globalRectOf(_stripKey) ?? globalRectOf(_playersKey);
      final from = strip == null
          ? to.shift(const Offset(0, 90))
          : Rect.fromCenter(center: strip.center, width: 8, height: 8);
      showEmbunFlow(context,
          from: from,
          to: to,
          amount: delta.ceil().clamp(1, 9),
          dark: showAsAntag);
    });
  }

  /// Aku memberi embun: tetes terbang dari saldo ke avatar penerima.
  void _fxGiveEmbun(String targetId, int amount) {
    _ownGiveAt = DateTime.now();
    Future.delayed(const Duration(milliseconds: 320), () {
      if (!mounted || _fxBlocked) return;
      final from = globalRectOf(_balanceKey);
      if (from == null) return;
      showEmbunFlow(context,
          from: from,
          to: _avatarRect(targetId),
          amount: amount,
          dark: showAsAntag,
          label: '+$amount');
    });
  }

  /// Aku menawarkan tukar kartu: salinan kartu terbang ke avatar lawan.
  void _fxOfferCard(String targetId, Map<String, dynamic> handRow) {
    Future.delayed(const Duration(milliseconds: 320), () {
      if (!mounted || _fxBlocked) return;
      showCardGift(context,
          def: defs[handRow['card_id']],
          from: _mejaRect(),
          to: _avatarRect(targetId),
          mode: GiftMode.offer,
          label: 'Tawaran ke ${_nameOf(targetId)}',
          dark: showAsAntag);
    });
  }

  /// Status tawaran tukar berubah dari 'pending' menjadi apa pun (terima /
  /// tolak) pada tawaran yang melibatkanku: catat lawannya. Bila kartu benar-
  /// benar berpindah, selisih tangan (lihat _noteHand) yang memicu animasi.
  void _noteTrades(List<Map<String, dynamic>> list) {
    final me = repo.myId;
    for (final r in list) {
      final id = '${r['id']}';
      final st = (r['status'] as String?) ?? '';
      final prev = _tradeStatus[id];
      _tradeStatus[id] = st;
      if (!_tradesPrimed) continue;
      if (prev == 'pending' && st != 'pending') {
        final from = r['from_id'] as String?;
        final to = r['to_id'] as String?;
        if (from == me || to == me) {
          _swapOther = from == me ? to : from;
          _swapAt = DateTime.now();
        }
      }
    }
    _tradesPrimed = true;
    _trySwap();
  }

  /// Bandingkan tangan sebelum / sesudah. Daftar pertama dianggap riwayat.
  void _noteHand(List<Map<String, dynamic>> before, List<Map<String, dynamic>> after) {
    if (!_handPrimed) {
      _handPrimed = true;
      return;
    }
    final b = {for (final h in before) '${h['id']}'};
    final a = {for (final h in after) '${h['id']}'};
    final added = after.where((h) => !b.contains('${h['id']}')).toList();
    final removed = before.where((h) => !a.contains('${h['id']}')).toList();
    if (added.isEmpty && removed.isEmpty) return;
    _pendingDiff = (added: added, removed: removed, at: DateTime.now());
    _trySwap();
  }

  /// Cocokkan selisih tangan dengan tawaran tukar yang baru dijawab (urutan
  /// kedatangan stream tawaran dan tangan bisa mana pun).
  void _trySwap() {
    final d = _pendingDiff;
    final at = _swapAt;
    final other = _swapOther;
    final now = DateTime.now();
    if (d != null && now.difference(d.at) > const Duration(seconds: 8)) {
      _pendingDiff = null;
      return;
    }
    if (at != null && now.difference(at) > const Duration(seconds: 8)) {
      _swapAt = null;
      _swapOther = null;
      return;
    }
    if (d == null || at == null || other == null) return;
    if (d.at.difference(at).abs() > const Duration(seconds: 6)) return;
    _pendingDiff = null;
    _swapAt = null;
    _swapOther = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _playSwap(d.added, d.removed, other);
    });
  }

  /// Kartu keluar dari Mejaku ke lawan (satu per satu), lalu kartu dari lawan
  /// melayang dan masuk ke Mejaku. Tukar kartu bersifat terbuka, jadi nama
  /// lawan boleh tampil.
  void _playSwap(List<Map<String, dynamic>> added,
      List<Map<String, dynamic>> removed, String otherId) {
    if (_fxBlocked) return;
    final name = _nameOf(otherId);
    var delay = 0;
    for (final r in removed.take(2)) {
      final def = defs[r['card_id']];
      Future.delayed(Duration(milliseconds: delay), () {
        if (!mounted || _fxBlocked) return;
        showCardGift(context,
            def: def,
            from: _mejaRect(),
            to: _avatarRect(otherId),
            mode: GiftMode.send,
            label: 'Untuk $name',
            dark: showAsAntag);
      });
      delay += 500;
    }
    if (removed.isNotEmpty) delay += 500;
    for (final a in added.take(3)) {
      final def = defs[a['card_id']];
      Future.delayed(Duration(milliseconds: delay), () {
        if (!mounted || _fxBlocked) return;
        showCardGift(context,
            def: def,
            from: _avatarRect(otherId),
            to: _mejaRect(),
            mode: GiftMode.receive,
            label: 'Dari $name',
            dark: showAsAntag);
      });
      delay += 600;
    }
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
        final before = hand;
        setState(() => hand = h);
        _noteHand(before, h);
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
      _terbisikChatAccess.value = false;
      if (game != null) _backToLobby('Permainan sudah dibubarkan');
      return;
    }
    final changed = game?['day'] != g['day'] || game?['phase'] != g['phase'];
    final prev = game;
    final holdOld = _startClothToDiscussion(prev, g);
    setState(() {
      game = g;
      if (holdOld) _heldGame = prev;
      _checkVoteReveal(prev, g);
      _checkNight(prev, g);
      _checkDayIntro(g);
      _checkOfferIntro(g);
    });
    _syncTerbisikChat();
    if (prev == null && _duo && isAntag) {
      lobby.terbisikPartner(widget.gameId).then((id) {
        if (mounted) setState(() => _terbisikPartnerId = id);
      }).catchError((_) {});
    }
    // Ganti fase/hari: kartu bisa bertambah (persembahan) atau terpakai.
    if (changed) _refreshHand();
  }

  /// Hasil efek selesai dan fase berganti ke diskusi: putar kain, dan tahan
  /// tampilan hasil efek sampai kain menutup penuh. true = fase lama ditahan.
  bool _startClothToDiscussion(
      Map<String, dynamic>? prev, Map<String, dynamic> g) {
    if (!_clothToDiscussion || prev == null) return false;
    if (prev['status'] != 'playing' || g['status'] != 'playing') return false;
    if (prev['phase'] != 'effects' || g['phase'] != 'discussion') return false;
    // Hanya bila hasil efek memang sedang tampil (adegan lempar sudah usai).
    if (prev['day'] != g['day'] || _ceremonyDay != prev['day']) return false;
    return _cloth.currentState?.play(
      style: _styleToDiscussion.tinted(dark: showAsAntag),
      onCovered: () {
        if (mounted) setState(() => _heldGame = null);
      },
    ) ??
        false;
  }

  // ===================== malam di antara hari biasa =====================

  /// Putar laporan ketika hari biasa berakhir, atau ketika panah menentukan
  /// pemenang. Masuk kembali sesudahnya tidak memutarnya lagi.
  void _checkNight(Map<String, dynamic>? prev, Map<String, dynamic> g) {
    if (isAntag &&
        (prev == null ||
            prev['day'] != g['day'] ||
            prev['phase'] != g['phase'])) {
      _loadNightPlan();
    }
    if (prev == null || prev['status'] != 'playing') return;
    final prevDay = prev['day'] as int;
    final phase = prev['phase'];
    final finished = g['status'] == 'finished';
    final finalBow = finished && phase == 'day' && g['end_reason'] == 'panah';
    final nightFinished =
        finished && phase == 'night' && g['winner'] != 'dibatalkan';
    final nextDay = g['status'] == 'playing' &&
        (phase == 'day' || phase == 'night') &&
        g['day'] == prevDay + 1;
    if (!finalBow && !nightFinished && !nextDay) return;
    if (_lastNightDay == prevDay) return;
    _lastNightDay = prevDay;
    _nightScene = {'day': prevDay, 'rows': null, 'finalBow': finalBow};
    _loadNight(prevDay, finalBow: finalBow);
  }

  Future<void> _loadNight(int day,
      {required bool finalBow, int attempt = 0}) async {
    var rows = <Map<String, dynamic>>[];
    try {
      rows = await repo.nightReports(widget.gameId, day);
      if (finalBow) {
        rows = rows.where((row) {
          final impact = row['impact'];
          return row['user_id'] == repo.myId &&
              impact is Map &&
              impact['effect'] == 'bow_final';
        }).toList();
      }
    } catch (_) {}
    if (!mounted) return;
    if (!finalBow && rows.isEmpty && attempt < 1) {
      await Future.delayed(const Duration(milliseconds: 600));
      return _loadNight(day, finalBow: finalBow, attempt: attempt + 1);
    }
    setState(() {
      final cur = _nightScene;
      if (cur == null || cur['day'] != day) return;
      if (rows.isEmpty) {
        _nightScene = null; // tak ada data (mis. migrasi belum dijalankan)
      } else {
        cur['rows'] = rows;
      }
    });
  }

  Widget _nightLayer() {
    final v = _nightScene!;
    final rows = v['rows'] as List<Map<String, dynamic>>?;
    // Warna yang sama dengan dasar semua adegan (kSceneInk), supaya layar
    // penantian data tidak berbeda nuansa dari adegan yang menyusul.
    if (rows == null) return const ColoredBox(color: kSceneInk);
    final finalBow = v['finalBow'] == true;
    return NightScene(
      key: ValueKey('night${v['day']}'),
      day: v['day'] as int,
      rows: rows,
      defs: defs,
      finalBow: finalBow,
      finalBowBackdrop: finalBow ? landscapePath(game!['leaves'] as int) : null,
      onDone: () {
        if (mounted) setState(() => _nightScene = null);
      },
    );
  }

  Future<void> _loadNightPlan() async {
    if (!isAntag) return;
    final day = (game?['day'] as int?) ?? 0;
    try {
      final p = await repo.nightPlan(widget.gameId, day);
      if (mounted) setState(() => _nightArmed = p != null);
    } catch (_) {}
  }

  Future<void> _openNightPlan() async {
    final day = (game?['day'] as int?) ?? 0;
    await showNightPlanDialog(
      context,
      repo: repo,
      gameId: widget.gameId,
      day: day,
      hand: hand,
      defs: defs,
      others: _alive.where((p) => p['user_id'] != repo.myId).toList(),
      onChanged: _loadNightPlan,
    );
    await _loadNightPlan();
    // Kartu sudah dilancarkan: malam langsung dijalankan.
    if (mounted && _nightOn && _nightArmed) await _continueNight();
  }

  /// Fase malam: hari biasa sudah berakhir, malam belum dijalankan.
  bool get _nightOn =>
      game?['status'] == 'playing' && game?['phase'] == 'night';

  /// Si Terbisik selesai menentukan malam; server menjalankannya sekarang.
  Future<void> _continueNight() =>
      _guard(() => repo.nightContinue(widget.gameId));

  Widget _nightChoiceLayer() {
    final g = game!;
    final hasCards = hand.any((h) => defs[h['card_id']]?['kind'] == 'malam');
    final me = _meRow;
    final canAct = isAntag && me != null && !isOut(me);
    return NightChoice(
      key: ValueKey('nc${g['day']}:$canAct'),
      isAntag: canAct,
      sharedNight: _duo,
      hasCards: hasCards,
      onTerbisikChat: showAsAntag && _terbisikChatAccess.value
          ? _openTerbisikChat
          : null,
      deadline: _deadline(g),
      busy: busy,
      onUseCard: _openNightPlan,
      onContinue: _continueNight,
    );
  }

  /// Voting baru saja selesai (fase 'voting' berganti hari baru, atau permainan
  /// berakhir): putar pembukaan suara untuk hari yang baru lewat. Riwayat
  /// (masuk kembali sesudahnya) tidak memutarnya lagi.
  void _checkVoteReveal(Map<String, dynamic>? prev, Map<String, dynamic> g) {
    if (prev == null) return;
    if (prev['status'] != 'playing' || prev['phase'] != 'voting') return;
    final prevDay = prev['day'] as int;
    final finished = g['status'] == 'finished';
    final moved = ((g['day'] as int?) ?? prevDay) > prevDay;
    if (!(finished || moved)) return;
    if (g['winner'] == 'dibatalkan') return; // dibatalkan, bukan hasil voting
    if (_lastRevealDay == prevDay) return;
    _lastRevealDay = prevDay;
    _voteReveal = {'day': prevDay, 'rows': null};
    _loadVoteReveal(prevDay);

    // Tuduhan kedua = keluar dari desa. Hanya bila teks vonis menyebutnya,
    // supaya vote biasa tidak menambah permintaan ke server.
    final verdict = g['verdict_day'] == prevDay ? g['verdict'] : null;
    if (verdict is String && verdict.contains('keluar dari desa')) {
      final m = RegExp(r'\((\d+) suara').firstMatch(verdict);
      _evict = {
        'day': prevDay,
        'row': null,
        'votes': m == null ? null : int.tryParse(m.group(1)!),
      };
      _loadEvict(prevDay);
    }
  }

  Future<void> _loadEvict(int day, [int attempt = 0]) async {
    final rows = await repo.evictedAt(widget.gameId, day);
    if (!mounted) return;
    if (rows.isEmpty && attempt < 1) {
      await Future.delayed(const Duration(milliseconds: 600));
      return _loadEvict(day, attempt + 1);
    }
    setState(() {
      final cur = _evict;
      if (cur == null || cur['day'] != day) return;
      if (rows.isEmpty) {
        _evict = null; // tidak ketemu: lewati adegan
      } else {
        cur['row'] = rows.first;
      }
    });
  }

  Widget _evictLayer() {
    final e = _evict!;
    final row = e['row'] as Map<String, dynamic>?;
    if (row == null) return const ColoredBox(color: kSceneInk);
    return EvictionVerdictScene(
      key: ValueKey('evict${e['day']}'),
      name: row['name'] as String,
      card: row['character_card'] as String?,
      isMe: row['user_id'] == repo.myId,
      votes: e['votes'] as int?,
      onDone: () {
        if (mounted) setState(() => _evict = null);
      },
    );
  }

  Future<void> _loadVoteReveal(int day, [int attempt = 0]) async {
    var rows = <Map<String, dynamic>>[];
    try {
      rows = await repo.voteReveal(widget.gameId, day);
    } catch (_) {}
    if (!mounted) return;
    if (rows.isEmpty && attempt < 1) {
      await Future.delayed(const Duration(milliseconds: 600));
      return _loadVoteReveal(day, attempt + 1);
    }
    setState(() {
      final cur = _voteReveal;
      if (cur == null || cur['day'] != day) return;
      if (rows.isEmpty) {
        _voteReveal = null; // tidak ada data (mis. migrasi belum dijalankan)
      } else {
        cur['rows'] = rows;
      }
    });
  }

  Widget _voteRevealLayer() {
    final v = _voteReveal!;
    final rows = v['rows'] as List<Map<String, dynamic>>?;
    if (rows == null) return const ColoredBox(color: kSceneInk);
    return VoteRevealScene(
      key: ValueKey('votes${v['day']}'),
      day: v['day'] as int,
      rows: rows,
      myId: repo.myId,
      onDone: () {
        if (mounted) setState(() => _voteReveal = null);
      },
    );
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
      if ((phase != 'research' && phase != 'day') || day == _lastIntroDay) return;
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
      // Siapa yang dikurung diambil dari server; sementara itu layar gelap.
      'jailPending': day > 1,
      'jail': null,
    };
    if (day > 1) _resolveJail(day);
  }

  /// Ambil pemain yang dikurung hari ini; bila ada, putar adegan vonis
  /// sebelum adegan fajar.
  Future<void> _resolveJail(int day) async {
    final rows = await repo.jailedAt(widget.gameId, day);
    if (!mounted) return;
    final cur = _dayIntro;
    if (cur == null || cur['kind'] != 'day' || cur['day'] != day) return;
    setState(() {
      cur['jailPending'] = false;
      cur['jail'] = rows.isEmpty ? null : rows.first;
      // Vonis vote dan Kawat Berduri bisa mengurung dua pemain di hari yang
      // sama: adegannya diputar bergantian.
      cur['jailQueue'] =
      rows.length > 1 ? rows.sublist(1) : <Map<String, dynamic>>[];
    });
  }

  bool get _jailHolds {
    final d = _dayIntro;
    return d != null &&
        d['kind'] == 'day' &&
        (d['jailPending'] == true || d['jail'] != null);
  }

  Widget _jailLayer() {
    final intro = _dayIntro!;
    final j = intro['jail'] as Map<String, dynamic>?;
    if (j == null) return const ColoredBox(color: kSceneInk);
    return JailVerdictScene(
      key: ValueKey('jail${intro['day']}-${j['user_id']}'),
      name: j['name'] as String,
      card: j['character_card'] as String?,
      isMe: j['user_id'] == repo.myId,
      onDone: () {
        if (!mounted) return;
        setState(() {
          final q =
              (intro['jailQueue'] as List<dynamic>?) ?? const <dynamic>[];
          if (q.isEmpty) {
            intro['jail'] = null;
          } else {
            intro['jail'] = q.first;
            intro['jailQueue'] = q.sublist(1);
          }
        });
      },
    );
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
    if (widget.onExit case final onExit?) {
      onExit();
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LobbyPage(startAtMenu: true)),
    );
    if (msg != null) messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _confirmExit(bool isHost) async {
    final title = isHost ? 'Sudahi permainan?' : 'Tinggalkan permainan?';
    final msg = isHost
        ? 'Permainan berakhir untuk semua pemain.'
        : isAntag && !_duo
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

  void _showPlayersSheet(int day, String phase) {
    final villageOpen = phase == 'day' || phase == 'research' || phase == 'discussion';
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14221F),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              icon: 'persona',
              title: 'Daftar Warga Desa',
              trailing: villageOpen
                  ? IconButton(
                      tooltip: 'Isyarat',
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openEmotes(day);
                      },
                      icon: const Icon(Icons.emoji_emotions_outlined),
                    )
                  : null,
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in players)
                    ListTile(
                      dense: true,
                      onTap: villageOpen && p['user_id'] != repo.myId && !isOut(p)
                          ? () {
                              Navigator.pop(ctx);
                              _openPlayer(p, phase);
                            }
                          : null,
                      leading: Opacity(
                        opacity: isOut(p) ? 0.4 : 1,
                        child: PlayerAvatar(
                          path: protagonistPath(p['character_card'] as String),
                          size: 36,
                          ring: isJailed(p, day)
                              ? EmbunColors.blood
                              : Colors.white38,
                        ),
                      ),
                      title: Text(
                        p['name'] as String,
                        style: TextStyle(
                            color: isOut(p) ? Colors.white38 : null),
                      ),
                      subtitle: isOut(p)
                          ? null
                          : Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: LivesRow(lives: livesLeft(p), size: 14),
                        ),
                      ),
                      trailing: isOut(p)
                          ? const StatusTag(
                          text: 'Keluar',
                          color: Colors.white54,
                          asset: 'keluar',
                          fontSize: 11)
                          : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isJailed(p, day))
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: StatusTag(
                                  text: 'Dikurung',
                                  color: EmbunColors.blood,
                                  asset: 'lock',
                                  fontSize: 11),
                            ),
                          GameIcon(
                              p['ready'] == true ? 'centang' : 'wait',
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

  // ===================== kemampuan warga =====================

  /// Memuat kemampuan milikku dari server. Si Terbisik tidak punya kemampuan
  /// (ia memakai kartu), jadi tidak ada yang ditampilkan untuknya.
  Future<void> _loadAbility({bool reveal = false}) async {
    if (isAntag) return;
    try {
      final s = await lobby.mySecret(widget.gameId);
      if (!mounted || s == null) return;
      setState(() {
        abilityId = (s['ability'] as String?) ?? 'biasa';
        abilityUsed = s['ability_used'] == true;
        _abilityKnown = true;
      });
      if (reveal) _tryRevealAbility();
    } catch (_) {
      // Kolom belum ada (migrasi belum dijalankan): sembunyikan saja.
    }
  }

  /// Pengungkapan di awal permainan, setelah adegan pembuka selesai.
  void _tryRevealAbility([int attempt = 0]) {
    if (_abilityRevealed || !_abilityKnown || isAntag) return;
    if (((game?['day'] as int?) ?? 0) > 1) {
      _abilityRevealed = true;
      return;
    }
    Future.delayed(Duration(milliseconds: attempt == 0 ? 2800 : 1500), () {
      if (!mounted || _abilityRevealed) return;
      if (_dayIntro != null && attempt < 8) {
        _tryRevealAbility(attempt + 1);
        return;
      }
      _abilityRevealed = true;
      _openAbility(intro: true);
    });
  }

  Future<void> _openAbility({bool intro = false}) async {
    if (isAntag) return;
    await _loadAbility(); // data segar (mis. Lidah Manis baru terpakai)
    final def = abilityDefs[abilityId];
    if (!mounted || def == null) return;
    final day = (game?['day'] as int?) ?? 0;
    final me = _meRow;
    await showAbilityDialog(
      context,
      def: def,
      used: abilityUsed,
      repo: repo,
      gameId: widget.gameId,
      phase: (game?['phase'] as String?) ?? '',
      jailed: me != null && isJailed(me, day),
      others: _alive.where((p) => p['user_id'] != repo.myId).toList(),
      everyone: _alive,
      day: day,
      intro: intro,
      onUsed: () {
        _loadAbility();
        _refreshHand();
        _marketTick.value++;
      },
    );
  }

  /// Tombol kemampuan di bar atas (hanya untuk warga). Titik kecil muncul
  /// selama kemampuan sekali pakai belum dipakai.
  Widget _abilityButton() {
    final def = abilityDefs[abilityId];
    if (isAntag || !_abilityKnown || def == null) return const SizedBox.shrink();
    final ready = !abilityUsed && abilityIsManual(abilityId);
    return Badge(
      isLabelVisible: ready,
      smallSize: 10,
      backgroundColor: EmbunColors.gold,
      child: IconButton(
        tooltip: '${def['name']}',
        visualDensity: VisualDensity.compact,
        onPressed: () => _openAbility(),
        icon: Icon(
          abilityIcon(abilityId),
          size: 26,
          color: abilityUsed ? Colors.white38 : abilityAccent(abilityId),
        ),
      ),
    );
  }

  void _openGuide() => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const GuidePage()));

  /// Infoku: karakter, kemampuan (warga), dan wajah asli + samaran (Si
  /// Terbisik). Memakai data yang sudah dimuat meja; kemampuan dimuat ulang
  /// dulu supaya status "terpakai" segar.
  Future<void> _openMyInfo() async {
    await _loadAbility();
    if (!mounted) return;
    await showMyInfoDialog(
      context,
      isAntag: isAntag,
      name: (_meRow?['name'] as String?) ?? '',
      characterStem: (_meRow?['character_card'] as String?) ?? 'default',
      darkSeed: darkSeed,
      abilityDef: isAntag ? null : abilityDefs[abilityId],
      abilityUsed: abilityUsed,
    );
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
          players: _alive,
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
      day: (game?['day'] as int?) ?? 0,
      iAmJailed: _meRow != null &&
          isJailed(_meRow!, (game?['day'] as int?) ?? 0),
      onGiveEmbun: _fxGiveEmbun,
      onOfferCard: _fxOfferCard,
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
        _heldGame == null &&
        _dayIntro == null &&
        (phase == 'day' || phase == 'discussion');
  }

  /// Ada adegan layar penuh yang berjalan: musik meja diredam (adegan punya
  /// suaranya sendiri). Saat game selesai, peredaman diurus EndingCinematic.
  bool _sceneDuck(Map<String, dynamic>? g) {
    if (g == null) return false;
    if (g['status'] == 'finished') return _nightScene != null;
    return (_dayIntro != null && !_holdIntro) ||
        _evict != null ||
        _voteReveal != null ||
        _nightOn ||
        _nightScene != null ||
        _heldGame != null ||
        g['phase'] == 'effects';
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    final g = game;
    Sfx.I.setDuck(this, _sceneDuck(g));
    return Scaffold(
      backgroundColor: const Color(0xFF0B1512),
      body: Stack(
        fit: StackFit.expand,
        children: [
          g == null
              ? const EmbunLoading(text: 'Memasuki desa...')
              : _content(_heldGame ?? g),
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
              topInset: _narrow ? 140 : 190,
              bottomInset: _narrow ? 96 : 130,
              sceneHeight: _narrow ? 190 : 240,
            ),
          ),
          if (_dayIntro != null && !_holdIntro && _jailHolds)
            Positioned.fill(child: _jailLayer()),
          if (_dayIntro != null && !_holdIntro && !_jailHolds)
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
          // Pengusiran: tampil setelah suara dibuka (di bawah lapisan itu,
          // jadi baru mulai berputar begitu pembukaan suara selesai).
          if (_evict != null && _voteReveal == null)
            Positioned.fill(child: _evictLayer()),
          // Paling atas: menahan adegan lain sampai semua suara dibuka.
          if (_voteReveal != null) Positioned.fill(child: _voteRevealLayer()),
          if (_nightOn && _nightScene == null)
            Positioned.fill(child: _nightChoiceLayer()),
          if (_nightScene != null) Positioned.fill(child: _nightLayer()),
          // Paling atas: kain menutupi semua lapisan lain.
          Positioned.fill(child: ClothSweepLayer(key: _cloth)),
        ],
      ),
    );
  }

  Widget _content(Map<String, dynamic> g) {
    final day = g['day'] as int;
    final phase = (g['phase'] as String?) ?? 'day';
    final leaves = g['leaves'] as int;
    final cycle = (g['cycle_len'] as int?) ?? 3;
    final deadline = _deadline(g);
    final isHost = g['host_id'] == repo.myId;

    final meRow = _meRow;
    final alive = _alive;
    final iAmReady = meRow?['ready'] == true;
    final readyCount = alive.where((p) => p['ready'] == true).length;
    final jailed = meRow != null && isJailed(meRow, day);

    if (g['status'] == 'finished') return _result(g);

    if (phase == 'effects' && widget.showOpeningScenes && _ceremonyDay != day) {
      // Semua kartu persembahan dilempar ke Hayu dulu, baru hasilnya.
      return OfferingCeremony(
        key: ValueKey('cer$day'),
        repo: repo,
        gameId: widget.gameId,
        day: day,
        fallbackLeaves: leaves,
        defs: defs,
        dark: showAsAntag,
        winLeaves: (g['win_leaves'] as int?) ?? 20,
        onDone: (covered) {
          if (!mounted) return;
          void toEffects() {
            if (mounted) {
              setState(() {
                _ceremonyDay = day;
                _ceremonyCovered = covered;
              });
            }
          }

          final played = _clothAfterCeremony &&
              (_cloth.currentState?.play(
                style: _styleToEffects.tinted(dark: showAsAntag),
                onCovered: toEffects,
              ) ??
                  false);
          if (!played) toEffects();
        },
      );
    }

    if (phase == 'effects') {
      return Stack(
        fit: StackFit.expand,
        children: [
          EffectsView(
            key: ValueKey('fx$day'),
            skipBound: _ceremonyCovered,
            repo: repo,
            gameId: widget.gameId,
            day: day,
            finalLeaves: leaves,
            isAntag: showAsAntag,
            waiting: iAmReady,
            readyCount: readyCount,
            total: alive.length,
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
        Backdrop(
          path: phaseScenery(phase, day, leaves),
          dark: showAsAntag,
          dim: phase == 'day' || phase == 'research' ? 0.60 : 0.74,
        ),
        if (phase == 'day' || phase == 'research')
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x60102018),
                  Color(0x00102018),
                  Color(0xDC07130F),
                ],
                stops: [0, 0.45, 1],
              ),
            ),
          ),
        SafeArea(
          child: _narrow
              ? _panel(g, day, phase, leaves, iAmReady, readyCount, jailed,
              deadline,
              narrow: true, cycle: cycle, isHost: isHost)
              : Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints:
              const BoxConstraints(maxWidth: _maxContentWidth),
              child: _panel(g, day, phase, leaves, iAmReady,
                  readyCount, jailed, deadline,
                  narrow: false,
                  cycle: cycle,
                  isHost: isHost),
            ),
          ),
        ),
      ],
    );
  }

  /// Judul pembuka fase (sekali per fase per hari).
  Widget _withPhaseTitle(String phase, int day, Widget body) {
    switch (phase) {
      case 'discussion':
        return PhaseTitle(
            id: 'discussion-$day', icon: 'title-musyawarah', child: body);
      case 'research':
        return PhaseTitle(
            id: 'research-$day', icon: 'title-pasarriset', child: body);
      default:
        return body;
    }
  }

  Widget _panel(
      Map<String, dynamic> g,
      int day,
      String phase,
      int leaves,
      bool iAmReady,
      int readyCount,
      bool jailed,
      DateTime? deadline, {
        required bool narrow,
        required int cycle,
        required bool isHost,
      }) {
    final balance = (myState?['balance'] as num?)?.toDouble() ?? 0;
    final alive = _alive;
    final meRow = _meRow;
    final iAmOut = meRow != null && isOut(meRow);
    final hayu = HayuEffects.fromGame(
      g,
      playerState: meRow == null || iAmOut || disguiseMode ? null : myState,
      isAntagonist: isAntag,
    );
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
        total: alive.length,
        players: players,
        events: events,
        readOnly: iAmOut,
      );
    } else if (phase == 'voting') {
      // VotingView dipertahankan (kuncinya tetap) setelah suara dikunci,
      // supaya layar "Suaramu terkunci" dan pilihanmu tidak hilang.
      body = iAmOut
          ? _waiting(readyCount, alive.length,
          'Kamu hanya menonton pemungutan suara...')
          : VotingView(
        key: ValueKey('vote$day'),
        repo: repo,
        gameId: widget.gameId,
        players: alive,
        day: day,
        locked: iAmReady,
        readyCount: readyCount,
        total: alive.length,
        hasHammer: !isAntag && abilityId == 'palu_hakim' && !abilityUsed,
        onHammerUsed: () => _loadAbility(),
      );
    } else if (phase == 'offering') {
      body = OfferingView(
        key: ValueKey('off$day'),
        repo: repo,
        gameId: widget.gameId,
        leaves: leaves,
        isAntag: isAntag,
        // Kartu serangan malam (ungu) dan kartu siang (kuning) tidak bisa
        // dipersembahkan.
        hand: hand.where((h) {
          final k = defs[h['card_id']]?['kind'];
          // Kartu poin tak bisa dipersembahkan; kartu lanjutan hanya bila
          // sudah digabung dengan poin (aktif).
          if (k == 'poin') return false;
          if (k == 'lanjutan' && h['charged'] != true) return false;
          return k != 'malam' && k != 'siang';
        }).toList(),
        defs: defs,
        players: alive,
        submitted: iAmReady,
        readyCount: readyCount,
        total: alive.length,
        onSubmitted: _refreshHand,
        out: iAmOut,
        deadline: deadline,
        winLeaves: (g['win_leaves'] as int?) ?? 20,
      );
    } else if (iAmOut) {
      body = _spectatorBody();
    } else if (phase == 'research') {
      body = ResearchView(
        key: ValueKey('res$day'),
        repo: repo,
        gameId: widget.gameId,
        day: day,
        defs: defs,
        balance: balance,
        jailed: jailed,
        iAmReady: iAmReady,
        readyCount: readyCount,
        total: alive.length,
        dark: showAsAntag,
        onBought: _refreshHand,
      );
    } else {
      body = DayView(
        initialTab: widget.initialDayTab,
        marketTick: _marketTick,
        mejaKey: _mejaKey,
        balanceKey: _balanceKey,
        key: ValueKey('day$day'),
        repo: repo,
        gameId: widget.gameId,
        day: day,
        priceMod: (g['price_mod'] as int?) ?? 0,
        // Jatah tambahan dari kejadian desa + dari Keranjang Baru (pribadi).
        extraBuy: ((g['extra_buy'] as int?) ?? 0) +
            (myState?['extra_buy_day'] == day
                ? ((myState?['extra_buy_n'] as int?) ?? 0)
                : 0),
        hand: hand,
        defs: defs,
        balance: balance,
        jailed: jailed,
        iAmReady: iAmReady,
        readyCount: readyCount,
        total: alive.length,
        players: alive,
        events: events,
        trades: trades,
        dark: showAsAntag,
        isAntag: isAntag,
        onHandChanged: _refreshHand,
      );
    }

    // Saat voting, daftar tersangka sudah memuat semua pemain: deretan desa
    // disembunyikan supaya ruang vertikal tidak habis.
    final showStrip =
        phase == 'day' || phase == 'research' || phase == 'discussion';

    final gap = _short ? 3.0 : (narrow ? 5.0 : 7.0);
    final village = showStrip
        ? KeyedSubtree(
            key: _stripKey,
            child: VillageStrip(
              compact: true,
              slim: true,
              myId: repo.myId,
              players: players,
              emotes: emotes,
              online: _online(),
              day: day,
              onTapPlayer: (p) => _openPlayer(p, phase),
              onEmoteButton: () => _openEmotes(day),
              collapsedBuilder: (emoji, sender) => _playersShortcut(
                day, phase, readyCount, alive.length,
                emoji: emoji, sender: sender,
              ),
              avatarKeyFor: _avatarKey,
            ),
          )
        : null;
    final showVerdict =
        verdict != null &&
        phase == 'day' &&
        _dayIntro == null &&
        _verdictHiddenDay != day;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: narrow ? 8 : (_wide ? 24 : 16),
        vertical: _short ? 4 : (narrow ? 6 : 14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tableHud(
            balance: balance,
            hayu: hayu,
            day: day,
            cycle: cycle,
            deadline: deadline,
            isHost: isHost,
            players: _playersShortcut(day, phase, readyCount, alive.length),
            showChat: phase != 'discussion',
            showDue: phase != 'voting',
            phase: phase,
            village: village,
          ),
          // Satu slot pemberitahuan: status diri > vonis > kabar pagi.
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _noticeSlot(
              me: meRow,
              day: day,
              out: iAmOut,
              jailed: jailed,
              verdict: showVerdict ? verdict : null,
              kabar: (phase == 'day' && _dayIntro == null && _kabarHiddenDay != day)
                  ? _kabarText(day)
                  : null,
              compact: narrow || _short,
              gap: gap,
            ),
          ),
          SizedBox(height: gap),
          // Selama adegan peralihan, isi hari ditahan supaya animasi Kabar Pagi
          // dan vonis baru diputar saat adegan selesai.
          Expanded(
              child: _dayIntro == null
                  ? _withPhaseTitle(phase, day, body)
                  : const SizedBox.shrink()),
        ],
      ),
    );
  }

  String? _kabarText(int day) {
    final k = events
        .where((e) => e['kind'] == 'kabar' && e['day'] == day)
        .toList();
    return k.isEmpty ? null : '${k.last['text']}';
  }

  /// Slot pemberitahuan tunggal. Hanya yang paling penting tampil sebagai
  /// satu baris; sisanya ("+N") dibuka lewat ketukan.
  Widget _noticeSlot({
    required Map<String, dynamic>? me,
    required int day,
    required bool out,
    required bool jailed,
    required String? verdict,
    required String? kabar,
    required bool compact,
    required double gap,
  }) {
    final items = <_Notice>[];
    if (me != null && (out || jailed || strikesOf(me) > 0)) {
      final until = jailUntil(me);
      if (out) {
        items.add(_Notice(
          color: Colors.white54,
          leading: const GameIcon('show', size: 22),
          short: 'Kamu sudah keluar dari desa',
          long: 'Kamu hanya menonton sampai permainan selesai.',
        ));
      } else if (jailed) {
        items.add(_Notice(
          color: EmbunColors.blood,
          leading: const GameIcon('lock', size: 22),
          short: 'Dikurung sampai musyawarah hari ${until ?? day} · '
              'tak bisa membeli',
          long: 'Tidak bisa membeli kartu. Kamu masih bisa menerima kartu, '
              'mempersembahkan, bicara, dan memilih. '
              '${isAntag ? 'Dituduh sekali lagi, kamu tertangkap.' : 'Dituduh sekali lagi, kamu keluar dari desa.'}',
          trailing: LivesRow(lives: livesLeft(me), size: 16),
        ));
      } else {
        items.add(_Notice(
          color: EmbunColors.gold,
          leading: const GameIcon('alert', size: 22),
          short: 'Kamu pernah dituduh sekali',
          long: isAntag
              ? (_duo
                  ? 'Dituduh mayoritas sekali lagi, kamu tersingkir dari desa.'
                  : 'Dituduh mayoritas sekali lagi, Si Terbisik tertangkap dan warga menang.')
              : 'Dituduh mayoritas sekali lagi, kamu keluar dari desa.',
          trailing: LivesRow(lives: livesLeft(me), size: 16),
        ));
      }
    }
    if (verdict != null) {
      items.add(_Notice(
        color: Colors.amber,
        leading: const GameIcon('vote', size: 22),
        short: verdict,
        long: verdict,
        onHide: () => setState(() => _verdictHiddenDay = day),
      ));
    }
    if (kabar != null) {
      items.add(_Notice(
        color: EmbunColors.leaf,
        leading: const GameIcon('announcement', size: 22),
        short: 'Kabar Pagi: $kabar',
        long: kabar,
        onHide: () => setState(() => _kabarHiddenDay = day),
      ));
    }
    if (items.isEmpty) return const SizedBox(width: double.infinity);
    final top = items.first;
    return Padding(
      key: ValueKey('notice-${top.short}'),
      padding: EdgeInsets.only(top: gap),
      child: _noticeLine(
        color: top.color,
        compact: compact,
        leading: top.leading,
        text: top.short,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (top.trailing != null) top.trailing!,
            if (items.length > 1) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('+${items.length - 1}',
                    style: const TextStyle(fontSize: 11, color: Colors.white70)),
              ),
            ],
          ],
        ),
        onTap: () => _showNotices(items),
      ),
    );
  }

  void _showNotices(List<_Notice> items) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF121812),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          children: [
            for (final n in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        width: 3,
                        height: 40,
                        margin: const EdgeInsets.only(right: 10),
                        color: n.color),
                    n.leading,
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.short == n.long ? 'Vonis' : n.short,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: n.color)),
                          if (n.short != n.long)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(n.long,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      height: 1.35,
                                      color: Colors.white70)),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(n.long,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      height: 1.35,
                                      color: Colors.white70)),
                            ),
                          if (n.onHide != null)
                            TextButton(
                              style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 28)),
                              onPressed: () {
                                Navigator.pop(ctx);
                                n.onHide!();
                              },
                              child: const Text('Sembunyikan'),
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

  /// Baris pemberitahuan seragam: datar, satu baris, bilah warna di kiri.
  /// Dipakai untuk status diri dan vonis supaya tidak ada kotak besar bertumpuk.
  Widget _noticeLine({
    required Color color,
    required bool compact,
    required Widget leading,
    required String text,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return DecoratedBox(
      decoration: tableEdge(color),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: compact ? 27 : 31,
            child: Row(
              children: [
                const SizedBox(width: 5),
                leading,
                const SizedBox(width: 8),
                Expanded(
                  child: Text(text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: compact ? 12 : 13,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 6),
                  trailing,
                ],
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tampilan pemain yang sudah keluar pada fase hari / persembahan.
  Widget _spectatorBody() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GameIcon('show', size: 56),
          const SizedBox(height: 12),
          const Text('Kamu menonton dari luar desa',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: const Text(
              'Kamu tidak bisa membeli, mempersembahkan, memilih, atau '
                  'bicara lagi. Ikuti terus nasib Hayu sampai permainan berakhir.',
              textAlign: TextAlign.center,
              style:
              TextStyle(fontSize: 13, height: 1.35, color: Colors.white60),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _playersShortcut(
    int day,
    String phase,
    int ready,
    int total, {
    String? emoji,
    String? sender,
  }) {
    final label = 'Daftar warga, $ready dari $total siap'
        '${sender == null ? '' : ', isyarat dari $sender'}';
    return Semantics(
      label: label,
      button: true,
      excludeSemantics: true,
      onTap: () => _showPlayersSheet(day, phase),
      child: SizedBox(
        width: 49,
        height: 42,
        child: InkWell(
          key: _playersKey,
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showPlayersSheet(day, phase),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (emoji == null)
                      const GameIcon('persona', size: 17)
                    else
                      Text(emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 3),
                    Text(
                      '$ready/$total',
                      style: dayMetricValue.copyWith(
                        fontSize: 12,
                        color: EmbunColors.cream,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tableHud({
    required double balance,
    required HayuEffects hayu,
    required int day,
    required int cycle,
    required DateTime? deadline,
    required bool isHost,
    required Widget players,
    required bool showChat,
    bool showDue = true,
    required String phase,
    Widget? village,
  }) {
    final unread = (_othersChatCount() - _chatSeen).clamp(0, 99).toInt();
    final cycleLength = cycle > 0 ? cycle : 3;
    final offeringIn = showDue ? (cycleLength - day % cycleLength) % cycleLength : null;
    final canOpenAbility = !isAntag && _abilityKnown && abilityDefs[abilityId] != null;
    final canChatAsTerbisik = showAsAntag && _terbisikChatAccess.value;
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

    void openHayu() => showPartsSheet(
      context, effects: hayu, offeringIn: offeringIn,
    );
    final income = hayu.income;
    final disguisedRate = disguiseMode ? (myState?['rate'] as num?) : null;
    final incomeLabel = income != null
        ? '${hayuAmount(income.total, signed: true)} besok'
        : disguisedRate == null
            ? '—'
            : '${hayuAmount(disguisedRate, signed: true)}/hari';
    final currencyLabel = showAsAntag ? 'BULIR HITAM' : 'TETES EMBUN';
    final balanceTone =
        showAsAntag ? const Color(0xFFE4CDFF) : const Color(0xFFFFDE8D);
    final balanceMetric = LayoutBuilder(
      builder: (context, box) {
        final iconSize = box.maxWidth < 112 || _short ? 23.0 : 28.0;
        Widget balanceText(String text, TextStyle style) => FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(text, style: style),
        );

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GameIcon(showAsAntag ? 'bulirhitam' : 'bulirembun', size: iconSize),
            const SizedBox(width: 5),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  balanceText(
                    currencyLabel,
                    dayOverline.copyWith(
                      fontSize: 9,
                      letterSpacing: 0.85,
                      height: 1.1,
                      color: balanceTone,
                    ),
                  ),
                  BalanceFx(
                    key: _balanceKey,
                    quiet: _quietBalance,
                    balance: balance,
                    day: day,
                    dark: showAsAntag,
                    ready: myState != null,
                    hold: _dayIntro != null || _holdIntro,
                    builder: (_, shown) => balanceText(
                      hayuAmount(shown),
                      dayMetricValue.copyWith(
                        fontSize: _short ? 23 : 27,
                        color: balanceTone,
                      ),
                    ),
                  ),
                  balanceText(
                    incomeLabel,
                    dayCaption.copyWith(
                      fontSize: 10.5,
                      height: 1.1,
                      color: showAsAntag
                          ? const Color(0xFFC7ACED)
                          : const Color(0xFFA4CEAE),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
    final tools = <Widget>[
      if (showChat)
        Badge(
          isLabelVisible: unread > 0,
          label: Text('$unread'),
          child: IconButton(
            tooltip: 'Obrolan',
            visualDensity: VisualDensity.compact,
            onPressed: _openChat,
            icon: const GameIcon('discuss', size: 25),
          ),
        ),
    ];
    final wideTools = <Widget>[
      if (canChatAsTerbisik)
        IconButton(
          tooltip: 'Obrolan Terbisik',
          visualDensity: VisualDensity.compact,
          onPressed: _openTerbisikChat,
          icon: const Icon(Icons.lock_outline, color: EmbunColors.mist),
        ),
      if (canOpenAbility) _abilityButton(),
    ];
    final menu = PopupMenuButton<String>(
      tooltip: 'Menu',
      icon: const GameIcon('menu', size: 25),
      padding: EdgeInsets.zero,
      onSelected: (v) {
        switch (v) {
          case 'back_preview':
            widget.onExit?.call();
          case 'guide':
            _openGuide();
          case 'me':
            _openMyInfo();
          case 'players':
            _showPlayersSheet(day, phase);
          case 'ability':
            _openAbility();
          case 'terbisik_chat':
            _openTerbisikChat();
          case 'fx':
            setState(() => chatFx = !chatFx);
          case 'sound':
            Sfx.I.muted.value = !Sfx.I.muted.value;
          case 'mask':
            setState(() => disguiseMode = !disguiseMode);
          case 'exit':
            if (!busy) _confirmExit(isHost);
        }
      },
      itemBuilder: (_) => [
        if (widget.onExit != null)
          const PopupMenuItem(
            value: 'back_preview',
            child: Row(
              children: [
                Icon(Icons.grid_view, size: 20, color: EmbunColors.gold),
                SizedBox(width: 12),
                Text('Panel pratinjau'),
              ],
            ),
          ),
        item('me', 'persona', 'Infoku'),
        item('players', 'persona', 'Daftar warga'),
        if (canOpenAbility) item('ability', 'item', 'Kemampuan'),
        if (canChatAsTerbisik) item('terbisik_chat', 'lock', 'Obrolan Terbisik'),
        item('guide', 'question', 'Panduan'),
        item(
          'fx',
          'showaddgraphic',
          chatFx ? 'Matikan efek obrolan' : 'Nyalakan efek obrolan',
          c: chatFx ? Colors.amberAccent : null,
        ),
        item(
          'sound',
          'announcement',
          Sfx.I.muted.value ? 'Nyalakan suara' : 'Matikan suara',
          c: Sfx.I.muted.value ? null : Colors.amberAccent,
        ),
        if (isAntag)
          item(
            'mask',
            disguiseMode ? 'hide' : 'show',
            disguiseMode ? 'Matikan samaran' : 'Samarkan layar',
            c: disguiseMode ? Colors.amberAccent : null,
          ),
        const PopupMenuDivider(),
        item(
          'exit',
          isHost ? 'bubarkan' : 'keluar',
          isHost ? 'Sudahi permainan' : 'Tinggalkan permainan',
          c: Colors.redAccent,
        ),
      ],
    );
    return DayTableHeader(
      accent: showAsAntag ? EmbunColors.mist : EmbunColors.gold,
      day: day,
      offeringIn: offeringIn,
      deadline: deadline,
      short: _short,
      balance: Semantics(
        hint: 'Buka rincian pemasukan',
        child: InkWell(
          onTap: openHayu,
          borderRadius: BorderRadius.circular(8),
          child: balanceMetric,
        ),
      ),
      tools: tools,
      wideTools: wideTools,
      menu: menu,
      menuAttention: canOpenAbility && !abilityUsed && abilityIsManual(abilityId),
      parts: PartsStrip(effects: hayu, onTap: openHayu),
      players: players,
      village: village,
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
    // Voting yang mengakhiri permainan: buka suara dulu, baru sinematik akhir.
    if (_voteReveal != null || _evict != null || _nightScene != null) {
      return const ColoredBox(color: Color(0xFF05080F));
    }
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
    if (!bubar && !_endingSeen) {
      return EndingCinematic(
        key: const ValueKey('ending'),
        myId: repo.myId,
        wargaMenang: wargaMenang,
        leaves: leaves,
        verdict: verdict,
        endReason: g['end_reason'] as String?,
        secrets: secretsFuture!,
        usernames: usernamesFuture!,
        players: players,
        onDone: () {
          if (mounted) setState(() => _endingSeen = true);
        },
      );
    }
    if (!bubar) {
      return FinalResultScreen(
        key: const ValueKey('final'),
        wargaMenang: wargaMenang,
        leaves: leaves,
        day: day,
        verdict: verdict,
        endReason: g['end_reason'] as String?,
        players: players,
        defs: defs,
        abilityDefs: abilityDefs,
        usernames: usernames,
        myId: repo.myId,
        secrets: secretsFuture!,
        recap: recapFuture!,
        detailsBuilder: _recapSection,
        onExit: () => _backToLobby(),
      );
    }
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
    final entries = secrets.entries.where((e) => e.value['role'] == 'antagonis');
    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _revealedAntagonist(e.key, (e.value['dark_seed'] as int?) ?? 0),
          ),
      ],
    );
  }

  Widget _revealedAntagonist(String antagId, int seed) {
    final who = players.where((p) => p['user_id'] == antagId);
    final name = who.isEmpty ? '?' : who.first['name'] as String;
    // Kartu baik samaran yang selama ini dilihat pemain lain.
    final disCard = who.isEmpty ? null : who.first['character_card'] as String?;
    final disPath = disCard == null ? null : protagonistPath(disCard);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (disPath != null) ...[
          Opacity(
            opacity: 0.75,
            child: CardArt(
              path: disPath,
              width: 70,
              glow: const Color(0xFFFFD866),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.arrow_forward_rounded,
                size: 22, color: Color(0xFFB07CE8)),
          ),
        ],
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
              if (disCard != null)
                Text('menyamar sebagai ${characterTitle(disCard)}',
                    style:
                    const TextStyle(fontSize: 13, color: Colors.white60)),
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
        if (r == null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              s.connectionState == ConnectionState.waiting
                  ? 'Memuat catatan pertandingan…'
                  : 'Catatan pertandingan tidak tersedia.',
              style: const TextStyle(color: Colors.white70),
            ),
          );
        }
        List<Map<String, dynamic>> list(String k) =>
            List<Map<String, dynamic>>.from((r[k] as List?) ?? const []);
        final offs = list('offerings');
        final buys = list('purchases');
        final votes = list('votes');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final p in players) ...[
              const Divider(height: 1, color: Colors.white12),
              _recapTile(p, secrets, offs, buys, votes),
            ],
          ],
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
    final role = secrets[uid]?['role'];
    final antag = role == 'antagonis';
    // Kemampuan warga dibuka saat permainan berakhir (yang sudah keluar dari
    // desa tidak punya catatan rahasia lagi).
    final abName = antag
        ? null
        : abilityDefs['${secrets[uid]?['ability']}']?['name'] as String?;

    // key = hari*10 + urutan (beli, persembahan, suara) agar urut stabil.
    final lines = <MapEntry<int, String>>[];
    for (final b in buys.where((b) => b['user_id'] == uid)) {
      final verb = b['bonus'] == true ? 'Mendapat gratis' : 'Membeli';
      lines.add(MapEntry((b['day'] as int) * 10,
          '$verb ${_cardName(b['card_id'] as String)}'));
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
      final weight = v['weight'] == 2 ? ' (2 suara)' : '';
      lines.add(MapEntry((v['day'] as int) * 10 + 2,
          t == null ? 'Tidak memilih' : 'Memilih ${_nameOf(t)}$weight'));
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
            '${role == null ? 'Peran tidak diketahui' : antag ? 'Si Terbisik' : 'Warga Desa'}'
            '${abName == null ? '' : ' · $abName'}',
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

class _Notice {
  final Color color;
  final Widget leading;
  final String short;
  final String long;
  final Widget? trailing;
  final VoidCallback? onHide;
  const _Notice({
    required this.color,
    required this.leading,
    required this.short,
    required this.long,
    this.trailing,
    this.onHide,
  });
}