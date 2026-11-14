import 'dart:async';
import 'dart:math';
import '../../data/inspection.dart';

import '../../data/announcement_repository.dart';
import '../../data/game_repository.dart';
import '../../data/game_rules.dart';
import '../../data/lobby_repository.dart';
import 'preview_catalog.dart';

typedef PreviewRow = Map<String, dynamic>;

/// State for one local preview. It implements the repository contracts without
/// constructing Supabase clients, saving preferences, or using player data.
class PreviewSession
    implements GameRepository, LobbyRepository, AnnouncementRepository {
  PreviewSession() {
    prepare();
  }

  static const gameId = 'preview-game';
  static const roomCode = 'HAYUU';

  final List<PreviewRow> _visits = [];
  final List<PreviewRow> _inspectionReports = [];
  final Random _inspectionRandom = Random();
  double _wellBonus = 0;
  bool _trapWaiting = false;
  @override
  Future<PreviewRow> villageStatus(String gameId) async => {
    'limit': 2,
    'used': _visits.where((v) => v['invitation_id'] == null).length,
    'current': _visits.where((v) => v['closed_at'] == null).lastOrNull,
    'well_cost': 8,
    'well_step': .15,
    'well_cap': 1.5,
    'well_bonus': _wellBonus,
    'care_other_fee': 12,
    'own_trap_waiting': _trapWaiting,
  };
  @override
  Future<PreviewRow> enterVillagePlace(
    String gameId,
    String place, {
    String? invitation,
  }) async {
    final state = await villageStatus(gameId);
    if (invitation == null && (state['used'] as int) >= 2) {
      throw StateError('Dua kunjungan sudah terpakai');
    }
    if (place == 'pondok' &&
        !_hand.any(
          (h) => h['card_id'] == (_dark ? 'surat_sakit' : 'surat_dokter'),
        )) {
      throw StateError('Perlu surat perawatan');
    }
    _visits.add({
      'id': 'visit-${++_sequence}',
      'day': day,
      'place': place,
      'invitation_id': invitation,
      'action_used': false,
    });
    return villageStatus(gameId);
  }

  @override
  Future<PreviewRow> leaveVillagePlace(String gameId) async {
    final v = _visits.where((v) => v['closed_at'] == null).lastOrNull;
    if (v != null) v['closed_at'] = _stamp;
    return villageStatus(gameId);
  }

  @override
  Future<PreviewRow> contributeWell(String gameId) async {
    final v = _visits.where((v) => v['closed_at'] == null).last;
    if (v['action_used'] == true || v['place'] != 'sumur' || _balance < 8) {
      throw StateError('Tindakan tidak tersedia');
    }
    _balance -= 8;
    _wellBonus = (_wellBonus + (_dark ? -.15 : .15)).clamp(-1.5, 1.5);
    _game['village_rate_bonus'] = _wellBonus;
    v['action_used'] = true;
    _update();
    return villageStatus(gameId);
  }

  @override
  Future<PreviewRow> useClinicLetter(
    String gameId,
    String handId, {
    String? target,
  }) async {
    final v = _visits.where((v) => v['closed_at'] == null).last;
    if (v['action_used'] == true || v['place'] != 'pondok') {
      throw StateError('Layanan sudah digunakan');
    }
    if (!_dark && target != myId) _balance -= 12;
    _trapWaiting = _dark;
    _hand.removeWhere((h) => h['id'] == handId);
    v['action_used'] = true;
    _update();
    return villageStatus(gameId);
  }

  @override
  Future<void> finishVillageVisits(String gameId) async {
    _ready(true);
  }

  final _changes = StreamController<void>.broadcast();
  final List<PreviewRow> _players = [];
  final List<PreviewRow> _hand = [];
  final List<PreviewRow> _guards = [];
  final List<PreviewRow> _chat = [];
  final List<PreviewRow> _secretChat = [];
  final List<PreviewRow> _emotes = [];
  final List<PreviewRow> _trades = [];
  final _bought = <String>{};
  final _researched = <String>{};
  late PreviewRow _game;
  bool _active = false;
  bool _holdPrologue = false;
  bool _charChosen = true;
  bool _darkChosen = true;
  String? _pickedAbility;
  int? _abilitySlot;
  List<String> _abilityOffers = [];
  bool _usedAbility = false;
  PreviewRow? _meetingPoll;
  final List<PreviewRow> _meetingEvents = [];
  int _seed = 0;
  int _sequence = 0;
  int _seen = 0;
  double _balance = 74.7;
  String role = 'warga';
  PreviewRow? _nightPlan;

  @override
  String get myId => 'preview-me';
  bool get _dark => role == 'antagonis';
  int get day => _game['day'] as int;
  int get leaves => _game['leaves'] as int;
  int get antagonistCount => _game['antagonist_count'] as int;
  String get _stamp => DateTime.now().toUtc().toIso8601String();
  List<PreviewRow> get roster => List.unmodifiable(_players);
  List<PreviewRow> get hand => List.unmodifiable(_hand);
  PreviewRow get me => _players.first;
  PreviewRow get other => _players[1];
  String get _ability =>
      _pickedAbility ??
      switch (_game['phase']) {
        'voting' => 'palu_hakim',
        'discussion' => 'arloji_khayal',
        _ => 'jangan_bohong',
      };

  void dispose() => _changes.close();

  void prepare({
    String phase = 'day',
    String role = 'warga',
    int antagonists = 2,
    String? winner,
    bool waitingRoom = false,
    bool pickCharacter = false,
    bool pickDark = false,
    bool holdPrologue = false,
    bool jailed = false,
    bool eliminated = false,
    bool locked = false,
  }) {
    this.role = role;
    _active = waitingRoom;
    _holdPrologue = holdPrologue;
    _charChosen = !pickCharacter;
    _darkChosen = !pickDark;
    _pickedAbility = null;
    _abilitySlot = null;
    _abilityOffers = (previewAbilities.keys.toList()..shuffle())
        .take(3)
        .toList();
    _usedAbility = false;
    _meetingPoll = null;
    _meetingEvents.clear();
    _seed = 0;
    _sequence = 0;
    _balance = 74.7;
    _nightPlan = null;
    final offeringDay = const {
      'offering',
      'effects',
      'discussion',
      'voting',
    }.contains(phase);
    _game = {
      'id': gameId,
      'code': roomCode,
      'host_id': myId,
      'status': winner != null
          ? 'finished'
          : waitingRoom
          ? 'lobby'
          : 'playing',
      'phase': phase,
      'visits_enabled': phase == 'visits',
      'village_rate_bonus': 0,
      'day': waitingRoom
          ? 0
          : winner != null
          ? 12
          : offeringDay
          ? 6
          : 5,
      'phase_deadline': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 3))
          .toIso8601String(),
      'prologue_until': holdPrologue ? _stamp : null,
      'leaves': winner == 'antagonis' ? 8 : 17,
      if (offeringDay && phase != 'offering') 'leaves_before_effects': 16,
      'max_day': 12,
      'lingering_worms': 1,
      'cycle_len': kCycleDays,
      'cycles': 4,
      'win_leaves': 20,
      'is_public': true,
      'antagonist_count': antagonists,
      'hayu_rules_version': 2,
      'akar_score': offeringDay && phase != 'offering' ? 5 : 4,
      'batang_score': offeringDay && phase != 'offering' ? 6 : 3,
      'tanah_score': offeringDay && phase != 'offering' ? -5 : -3,
      'akar_c': 'subur',
      'batang_c': 'subur',
      'tanah_c': offeringDay && phase != 'offering' ? 'rusak' : 'layu',
      'verdict': winner == 'dibatalkan'
          ? 'Host menyudahi permainan.'
          : winner == 'warga'
          ? 'Terbisik terakhir tertangkap.'
          : null,
      'verdict_day': winner != null ? 12 : null,
      'winner': winner,
      'end_reason': winner == 'warga' ? 'tertangkap' : null,
    };
    const names = [
      'Arsiparis',
      'Peselancar',
      'Mata-mata',
      'Penatu',
      'Peternak Telur',
    ];
    const cards = [
      'pria-arsiparis',
      'pria-peselancar',
      'pria-matamata',
      'wanita-penatu',
      'pria-peternaktelur',
    ];
    _players
      ..clear()
      ..addAll([
        for (var i = 0; i < names.length; i++)
          {
            'user_id': i == 0 ? myId : 'preview-p$i',
            'name': names[i],
            'character_card': cards[i],
            'ready': i == 0 ? locked : i % 2 == 1,
            'strikes': i == 0
                ? (eliminated
                      ? 2
                      : jailed
                      ? 1
                      : 0)
                : i % 2,
            if (i == 0 && jailed) 'jailed_day': day,
            if (i == 0 && jailed) 'jailed_until': day + 1,
            if (i == 0 && eliminated) 'out_day': day - 1,
            'joined_at': _stamp,
          },
      ]);
    _visits.clear();
    _inspectionReports.clear();
    _wellBonus = 0;
    _trapWaiting = false;
    _guards.clear();
    _hand.clear();
    final base = _dark ? 'embun_samaran' : 'embun_biasa';
    _addCard(base);
    for (final kind in [
      'persembahan',
      'poin',
      'lanjutan',
      'siang',
      'malam',
      'perawatan',
    ]) {
      final pool = _pool(kind).where((d) => d['id'] != base);
      for (final d in pool.take(kind == 'persembahan' ? 3 : 2)) {
        _addCard(d['id'] as String);
      }
    }
    if (!_dark) {
      _addCard('perlindungan_malam');
      _addCard('stetoskop');
    }
    _bought.clear();
    _researched.clear();
    _chat
      ..clear()
      ..add(_message(other, 'Akar Hayu sudah pulih. Kita jaga daunnya.', day));
    _secretChat
      ..clear()
      ..add(_message(other, 'Aku punya Pompa Embun untuk malam ini.', day));
    _emotes.clear();
    _trades
      ..clear()
      ..add({
        'id': 'preview-trade',
        'from_id': other['user_id'],
        'to_id': myId,
        'day': day,
        'give_card_id': 'air_suci',
        'status': 'pending',
      });
    if (phase == 'discussion' && !_dark) {
      _inspectionReports.add({
        'id': 'preview-inspection-intro',
        'game_id': gameId,
        'inspector_id': myId,
        'target_id': other['user_id'],
        'target_name': other['name'],
        'kind': 'heartbeat',
        'chance': 85,
        'outcome': 'antagonis',
        'day': day,
        'message':
            'Stetoskop 85%: pemeriksaan ${other['name']} menunjukkan Si Terbisik.',
      });
    }
  }

  Stream<T> _watch<T>(T Function() read) => Stream<T>.multi((sink) {
    final sub = _changes.stream.listen((_) => sink.add(read()));
    sink.onCancel = sub.cancel;
    sink.add(read());
  });

  void _update() => _changes.add(null);

  Iterable<PreviewRow> _pool(String kind) => previewCards.values.where(
    (d) => d['side'] == role && d['kind'] == kind && d['purchasable'] == true,
  );

  void _addCard(String id, {bool charged = false}) {
    _hand.add({
      'id': 'preview-card-${++_sequence}',
      'card_id': id,
      'user_id': myId,
      'acquired_day': day,
      'charged': charged,
      'inspection_level': 0,
    });
  }

  PreviewRow _message(PreviewRow sender, String body, int day) => {
    'id': 'preview-message-${++_sequence}',
    'user_id': sender['user_id'],
    'name': sender['name'],
    'body': body,
    'day': day,
    'created_at': _stamp,
  };

  void _ready(bool ready) {
    _players[0] = {...me, 'ready': ready};
    _update();
  }

  void _phase(String phase, {int? nextDay}) {
    _game = {
      ..._game,
      'phase': phase,
      'visits_enabled': phase == 'visits',
      'village_rate_bonus': 0,
      if (nextDay != null) 'day': nextDay,
      'phase_deadline': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 3))
          .toIso8601String(),
    };
    _ready(false);
  }

  @override
  Future<void> ensureSignedIn() async {}

  @override
  Future<PreviewRow?> activeGame() async => _active ? {..._game} : null;

  @override
  Stream<PreviewRow?> game(String gameId) =>
      _watch(() => _game['status'] == 'closed' ? null : {..._game});

  @override
  Stream<List<PreviewRow>> players(String gameId) => _watch(() => roster);

  @override
  Future<String> createGame(
    String name,
    String card, {
    bool isPublic = false,
    int cycles = 4,
    int antagonistCount = 1,
  }) async {
    prepare(waitingRoom: true, antagonists: antagonistCount, role: role);
    _game.addAll({'is_public': isPublic, 'cycles': cycles});
    _players[0] = {...me, 'name': name, 'character_card': card};
    _chat
      ..clear()
      ..add(_message(other, 'Halo, ini ruangan contoh.', 0));
    _update();
    return gameId;
  }

  @override
  Future<String> joinGame(String code, String name, String card) async {
    final normalized = code.trim().toUpperCase();
    final room = (await publicGames())
        .where((row) => row['code'] == normalized)
        .firstOrNull;
    if (room == null) throw StateError('Kode ruangan contoh tidak ditemukan.');
    final id = await createGame(
      name,
      card,
      isPublic: true,
      antagonistCount: room['antagonist_count'] as int,
    );
    _game = {..._game, 'code': normalized};
    return id;
  }

  @override
  Future<List<PreviewRow>> publicGames() async => [
    {
      'code': 'HAYUU',
      'host_name': 'Lembah Hayu',
      'players': 3,
      'age_s': 12,
      'antagonist_count': 1,
    },
    {
      'code': 'KABUT',
      'host_name': 'Kabut di Desa',
      'players': 5,
      'age_s': 38,
      'antagonist_count': 2,
    },
    {
      'code': 'EMBUN',
      'host_name': 'Pagi Berembun',
      'players': 7,
      'age_s': 83,
      'antagonist_count': 2,
    },
  ];

  @override
  Future<void> setRoomPublic(String gameId, bool value) async {
    _game = {..._game, 'is_public': value};
    _update();
  }

  @override
  Future<void> setReady(String gameId, bool ready) async {
    if (ready && _game['status'] == 'lobby') {
      for (var i = 1; i < _players.length; i++) {
        _players[i] = {..._players[i], 'ready': true};
      }
    }
    _ready(ready);
  }

  @override
  Future<void> startGame(String gameId) async {
    final minimum = minPlayersFor(antagonistCount);
    if (roster.length < minimum || roster.any((p) => p['ready'] != true)) {
      throw StateError('Minimal $minimum pemain dan semuanya harus siap.');
    }
    _charChosen = false;
    _darkChosen = false;
    _pickedAbility = null;
    _abilitySlot = null;
    _abilityOffers = (previewAbilities.keys.toList()..shuffle())
        .take(3)
        .toList();
    _game = {..._game, 'status': 'playing', 'prologue_until': _stamp};
    _phase('day', nextDay: 1);
  }

  @override
  Future<void> leave(String gameId) => endGame(gameId);

  @override
  Future<void> endGame(String gameId) async {
    _active = false;
    _game = {..._game, 'status': 'closed'};
    _update();
  }

  @override
  Future<void> updateCharacter(String gameId, String name, String card) async {
    _players[0] = {...me, 'name': name, 'character_card': card};
    _update();
  }

  @override
  Future<String> chooseCharacter(String gameId, String card) async {
    _charChosen = true;
    final name = (me['name'] as String);
    await updateCharacter(gameId, name, card);
    return name;
  }

  @override
  Future<PreviewRow> myAbilityDraft(String gameId) async {
    if (_dark) throw StateError('Pilihan biru hanya untuk warga');
    return {
      'count': _abilityOffers.length,
      'chosen': _pickedAbility != null,
      'selected_slot': _abilitySlot,
      'ability': _pickedAbility == null
          ? null
          : previewAbilities[_pickedAbility],
    };
  }

  @override
  Future<PreviewRow> chooseAbility(String gameId, int slot) async {
    if (_dark) throw StateError('Pilihan biru hanya untuk warga');
    if (_abilitySlot != null && _abilitySlot != slot) {
      throw StateError('Pilihan kemampuan sudah terkunci');
    }
    if (slot < 1 || slot > _abilityOffers.length) {
      throw StateError('Pilihan tidak valid');
    }
    _abilitySlot = slot;
    _pickedAbility = _abilityOffers[slot - 1];
    return myAbilityDraft(gameId);
  }

  @override
  Future<void> chooseDark(String gameId, int seed) async {
    _darkChosen = true;
    _seed = seed;
  }

  @override
  Future<void> finishPrologue(String gameId) async {
    if (_holdPrologue || _game['prologue_until'] == null) return;
    _game = {..._game, 'prologue_until': null};
    _update();
  }

  @override
  Future<void> storySkip(String gameId, bool skip) async {
    _game = {
      ..._game,
      'story_skipped': skip,
      'story_skips': skip ? roster.length : 0,
    };
    _update();
  }

  @override
  Future<String?> terbisikPartner(String gameId) async =>
      _dark && antagonistCount == 2 ? other['user_id'] as String : null;

  @override
  Future<String?> myRole(String gameId) async => role;

  @override
  Future<PreviewRow?> mySecret(String gameId) async => {
    'role': role,
    'dark_seed': _seed,
    'ability': _ability,
    'ability_used': _usedAbility,
    'char_chosen': _charChosen,
    'dark_chosen': _darkChosen,
  };

  @override
  Future<Map<String, PreviewRow>> allSecrets(String gameId) async => {
    for (var i = 0; i < roster.length; i++)
      roster[i]['user_id'] as String: {
        'role': i == 0
            ? role
            : (i == 1 && (!_dark || antagonistCount == 2)) ||
                  (i == roster.length - 1 && !_dark && antagonistCount == 2)
            ? 'antagonis'
            : 'warga',
        'dark_seed': i,
        'ability': i == 0 ? _ability : 'biasa',
      },
  };

  @override
  Future<Map<String, PreviewRow>> cardDefs() async => previewCards;

  @override
  Future<Map<String, PreviewRow>> abilityDefs() async => previewAbilities;

  @override
  Future<List<PreviewRow>> offers(String gameId, int day) async => [
    for (final d in [
      ..._pool('persembahan').take(3),
      ..._pool(_dark ? 'malam' : 'siang').take(1),
    ])
      {'card_id': d['id'], 'bought': _bought.contains(d['id'])},
  ];

  @override
  Stream<PreviewRow?> myState(String gameId) =>
      _watch(() => {'balance': _balance, 'rate': 3.0});

  @override
  Stream<List<PreviewRow>> myHand(String gameId) => _watch(() => hand);

  @override
  Future<List<PreviewRow>> handNow(String gameId) async => hand;

  @override
  Future<PreviewRow> upgradeInspectionCard(
    String gameId,
    String handId,
    int expectedLevel,
  ) async {
    final visit = _visits.where((v) => v['closed_at'] == null).lastOrNull;
    if (gameId != PreviewSession.gameId ||
        _game['phase'] != 'visits' ||
        visit?['place'] != 'bengkel' ||
        _dark ||
        me['ready'] == true ||
        me['out_day'] != null) {
      throw StateError('Tingkatkan Stetoskop saat berkunjung ke Bengkel Desa.');
    }
    final card = _hand
        .where((h) => h['id'] == handId && h['card_id'] == 'stetoskop')
        .firstOrNull;
    if (card == null || StethoscopeRules.level(card) != expectedLevel) {
      throw StateError('Kartu atau tingkatnya sudah berubah.');
    }
    final cost = StethoscopeRules.nextCost(card);
    if (cost == null) throw StateError('Stetoskop sudah 100%.');
    if (_balance < cost) throw StateError('Embunmu tidak cukup.');
    card['inspection_level'] = expectedLevel + 1;
    _balance -= cost;
    _update();
    return {
      'hand_id': handId,
      'inspection_level': expectedLevel + 1,
      'chance': StethoscopeRules.chance(card),
      'cost': cost,
      'balance': _balance,
    };
  }

  @override
  Future<List<PreviewRow>> inspectionReports(
    String gameId, {
    bool unreadOnly = false,
  }) async => [
    for (final row in _inspectionReports)
      if (row['inspector_id'] == myId &&
          (!unreadOnly || row['seen_at'] == null))
        Map<String, dynamic>.from(row),
  ];

  @override
  Future<void> markInspectionReportRead(String reportId) async {
    final report = _inspectionReports
        .where((r) => r['id'] == reportId && r['inspector_id'] == myId)
        .firstOrNull;
    if (report != null) report['seen_at'] ??= _stamp;
  }

  @override
  Future<PreviewRow> fuseCards(String gameId, String handId) async {
    final visit = _visits.where((v) => v['closed_at'] == null).lastOrNull;
    if (_game['phase'] != 'visits' || visit?['place'] != 'bengkel') {
      throw StateError('Kunjungi Bengkel Desa untuk menggabungkan kartu.');
    }
    final item = _hand.firstWhere((h) => h['id'] == handId);
    final points = _hand.indexWhere(
      (h) => previewCards[h['card_id']]?['kind'] == 'poin',
    );
    if (points < 0) throw StateError('Belum ada kartu poin.');
    item['charged'] = true;
    _hand.removeAt(points);
    _update();
    return {'message': 'Kartu lanjutan aktif.', 'hand_id': handId};
  }

  @override
  Future<void> finishDay(String gameId, {String? card}) async => _ready(true);

  @override
  Future<void> submitOffering(
    String gameId,
    List<String> handIds, {
    String? target,
  }) async {
    final selected = _hand.where((h) => handIds.contains(h['id'])).toList();
    final targetPlayer = _players
        .where((p) => p['user_id'] == target)
        .firstOrNull;
    _hand.removeWhere((h) => handIds.contains(h['id']));
    if (targetPlayer != null) {
      final secrets = await allSecrets(gameId);
      for (final card in selected) {
        final kind =
            (previewCards[card['card_id']]?['effect'] as Map?)?['inspect'];
        if (!const {
          'heartbeat',
          'hand',
          'purchase',
          'offering',
        }.contains(kind)) {
          continue;
        }
        final chance = kind == 'heartbeat'
            ? StethoscopeRules.chance(card)
            : null;
        String outcome = 'number';
        if (kind == 'heartbeat') {
          final secret = secrets[target];
          outcome =
              _inspectionRandom.nextDouble() < ((chance ?? 30) / 100) &&
                  secret != null
              ? '${secret['role']}'
              : 'unknown';
        } else if (kind == 'offering') {
          outcome = 'baik';
        }
        final value = kind == 'hand'
            ? 3
            : kind == 'purchase'
            ? 2
            : null;
        final row = <String, dynamic>{
          'id': 'preview-inspection-${++_sequence}',
          'game_id': gameId,
          'inspector_id': myId,
          'target_id': target,
          'target_name': targetPlayer['name'],
          'kind': kind,
          'chance': chance,
          'outcome': outcome,
          'value': value,
          'day': day,
          'message': '',
        };
        final report = InspectionReport.fromRow(row);
        row['message'] =
            '${report.source}: ${report.targetName} — ${report.headline}.';
        _inspectionReports.add(row);
      }
    }
    _ready(true);
  }

  @override
  Future<List<PreviewRow>> effects(String gameId, int day) async => [
    {
      'id': 1,
      'seq': 1,
      'kind': 'good',
      'label': 'Air Suci · +1 daun',
      'card_seq': 1,
    },
    {
      'id': 2,
      'seq': 2,
      'kind': 'good',
      'label': 'Akar Hayu menyubur',
      'card_seq': 1,
    },
    {'id': 3, 'seq': 3, 'kind': 'bad', 'label': 'Kabut menggerogoti 2 daun'},
    {'id': 4, 'seq': 4, 'kind': 'good', 'label': 'Hayu tumbuh · +2 daun'},
  ];

  @override
  Future<int?> leavesBefore(String gameId) async => 16;

  @override
  Future<List<String>> revealedCards(String gameId, int day) async => [
    'air_suci',
    'embun_biasa',
    'embun_samaran',
  ];

  @override
  Future<Map<String, int>> offeringCounts(String gameId, int day) async => {
    for (final p in roster) p['user_id'] as String: 1,
  };

  @override
  Future<int?> fogFor(int players) async => 2;

  @override
  Future<List<PreviewRow>> privateLogs(String gameId, int day) async => [
    for (final report in _inspectionReports)
      if (report['day'] == day) {'message': report['message']},
    if (_dark)
      {'message': 'Bisikan: Tersampaikan kepada Peselancar.'}
    else
      {
        'message':
            'Desas-desus: kamu mendengar bahwa Penjahit adalah Si Terbisik.',
      },
    {'message': 'Firasatmu tertuju pada Peselancar.'},
  ];

  @override
  Future<void> advanceAfterEffects(String gameId) async => _phase('discussion');

  @override
  Stream<List<PreviewRow>> chat(String gameId, {bool terbisik = false}) =>
      _watch(() {
        if (!terbisik) return List.of(_chat);
        return _dark && antagonistCount == 2 ? List.of(_secretChat) : [];
      });

  @override
  Future<void> sendMessage(
    String gameId,
    String body, {
    bool terbisik = false,
  }) async {
    if (terbisik && (!_dark || antagonistCount != 2)) {
      throw StateError('Kanal ini khusus mode Dua Terbisik.');
    }
    (terbisik ? _secretChat : _chat).add(_message(me, body, day));
    _update();
  }

  @override
  Future<void> readyToVote(String gameId) async => _phase('voting');

  @override
  Future<void> submitVote(
    String gameId,
    String? target, {
    bool hammer = false,
  }) async {
    _usedAbility = _usedAbility || hammer;
    _ready(true);
  }

  @override
  Future<void> tick(String gameId) async {}

  @override
  Future<void> syncClock() async {}

  @override
  Stream<List<PreviewRow>> emotes(String gameId) =>
      _watch(() => List.of(_emotes));

  @override
  Future<void> sendEmote(String gameId, String emoji, {String? target}) async {
    _emotes.add({
      'id': 'preview-emote-${++_sequence}',
      'day': day,
      'user_id': myId,
      'emoji': emoji,
      'target_id': target,
      'created_at': _stamp,
    });
    _update();
  }

  @override
  Future<PreviewRow> researchStock(String gameId) async => {
    'items': [
      for (final d in [
        ..._pool('poin'),
        ..._pool('lanjutan'),
        ..._pool('perawatan'),
      ])
        {
          'card_id': d['id'],
          'price': ((d['cost'] as num) * 1.2).ceil(),
          'bought': _researched.contains(d['id']),
        },
    ],
    'limit': 2,
    'bought': _researched.length,
  };

  void _buy(String card, Set<String> purchases) {
    if (!purchases.add(card)) return;
    _balance -= (previewCards[card]?['cost'] as num?)?.toDouble() ?? 0;
    _addCard(card);
    _update();
  }

  @override
  Future<void> buyResearch(String gameId, String card) async =>
      _buy(card, _researched);

  @override
  Future<void> finishResearch(String gameId) async => _phase('day');

  @override
  Future<void> buyCard(String gameId, String card) async => _buy(card, _bought);

  @override
  Future<void> giveEmbun(String gameId, String to, int amount) async {
    _balance -= amount;
    _update();
  }

  @override
  Future<void> proposeTrade(String gameId, String to, String handId) async {
    final item = _hand.firstWhere((h) => h['id'] == handId);
    _trades.add({
      'id': 'preview-trade-${++_sequence}',
      'from_id': myId,
      'to_id': to,
      'day': day,
      'give_card_id': item['card_id'],
      'status': 'pending',
    });
    _update();
  }

  @override
  Future<void> respondTrade(
    String tradeId,
    bool accept, {
    String? returnHand,
  }) async {
    final i = _trades.indexWhere((t) => t['id'] == tradeId);
    if (i < 0) return;
    if (accept) {
      _hand.removeWhere((h) => h['id'] == returnHand);
      _addCard(_trades[i]['give_card_id'] as String);
    }
    _trades[i] = {..._trades[i], 'status': accept ? 'accepted' : 'declined'};
    _update();
  }

  @override
  Stream<List<PreviewRow>> villageEvents(String gameId) => _watch(
    () => [
      {
        'id': 'preview-event',
        'day': day,
        'kind': 'kabar',
        'text': 'Embun turun lebih deras pagi ini.',
      },
    ],
  );

  @override
  Stream<List<PreviewRow>> trades(String gameId) =>
      _watch(() => List.of(_trades));

  @override
  Stream<List<PreviewRow>> presence(String gameId) => _watch(
    () => [
      for (final p in roster) {'user_id': p['user_id'], 'last_seen': _stamp},
    ],
  );

  @override
  Future<Map<String, String>> usernames(String gameId) async => {
    for (var i = 0; i < roster.length; i++)
      roster[i]['user_id'] as String: 'Penguji ${i + 1}',
  };

  @override
  Future<List<PreviewRow>> jailedAt(String gameId, int day) async =>
      roster.where((p) => p['jailed_day'] == day).toList();

  @override
  Future<List<PreviewRow>> evictedAt(String gameId, int day) async =>
      roster.where((p) => p['out_day'] == day).toList();

  List<PreviewRow> get voteRows => [
    for (var i = 0; i < roster.length; i++)
      {
        'seq': i + 1,
        'voter_id': roster[i]['user_id'],
        'voter_name': roster[i]['name'],
        'voter_card': roster[i]['character_card'],
        'target_id': i == 1 ? roster.last['user_id'] : other['user_id'],
        'target_name': i == 1 ? roster.last['name'] : other['name'],
        'target_card': i == 1
            ? roster.last['character_card']
            : other['character_card'],
        'weight': i == 0 ? 2 : 1,
      },
  ];

  @override
  Future<List<PreviewRow>> voteReveal(String gameId, int day) async => voteRows;

  List<PreviewRow> nightRows(String effect, {bool actor = false}) => [
    if (effect != 'bow_final')
      {
        'kind': 'public',
        'scene': 'attack',
        'text': 'Kabut bergerak di sekitar desa.',
      },
    {
      'kind': 'private',
      'user_id': myId,
      'scene': 'impact',
      'text': effect == 'guard'
          ? 'Perisai yang kamu pasang untuk ${other['name']} menahan serangan malam.'
          : effect == 'shield'
          ? 'Perisai Malam menahan serangan yang menyasarmu.'
          : actor
          ? 'Aksimu mengenai sasaran.'
          : 'Serangan malam mengenaimu.',
      'impact': {
        'effect': effect,
        'view': effect == 'guard'
            ? 'guardian'
            : actor
            ? 'actor'
            : 'target',
        if (effect == 'guard') 'target_name': other['name'],
        'delta': effect == 'pump' ? (actor ? 6 : -6) : -1,
        if (effect == 'burn' || effect == 'theft') 'card': 'air_suci',
      },
    },
  ];

  @override
  Future<List<PreviewRow>> nightReports(String gameId, int day) async =>
      nightRows('pump', actor: _dark);

  @override
  Future<PreviewRow?> nightPlan(String gameId, int day) async => _nightPlan;

  @override
  Future<PreviewRow> useDayCard(
    String gameId,
    String handId, {
    String? target,
  }) async {
    final hand = _hand.firstWhere((h) => h['id'] == handId);
    final effect = previewCards[hand['card_id']]?['effect'];
    if (effect is Map && effect['day'] == 'guard') {
      final targetId = effect['guard_target'] == true ? target ?? myId : myId;
      final player = _players.firstWhere((p) => p['user_id'] == targetId);
      if (_guards.any(
        (g) => g['user_id'] == targetId && g['kind'] == effect['guard'],
      )) {
        throw StateError(
          'Perlindungan sejenis masih aktif pada pemain pilihanmu',
        );
      }
      _guards.add({
        'user_id': targetId,
        'kind': effect['guard'],
        'until_day': ((day - 1) ~/ 3 + 1) * 3,
        'direction': targetId == myId ? 'self' : 'outgoing',
      });
      _hand.remove(hand);
      _update();
      return {
        'mode': 'guard',
        'message': targetId == myId
            ? 'Perlindunganmu aktif sampai akhir sesi ini.'
            : 'Perisai Malam menjaga ${player['name']} sampai akhir sesi ini.',
      };
    }
    _hand.remove(hand);
    _update();
    return {
      'mode': 'preview',
      'message': 'Efek kartu diperagakan di sesi contoh.',
    };
  }

  @override
  Future<List<PreviewRow>> myGuards(String gameId) async => List.of(_guards);

  @override
  Future<void> nightContinue(String gameId) async =>
      _phase('research', nextDay: day + 1);

  @override
  Future<void> armNightCard(
    String gameId, {
    String? handId,
    String? target,
  }) async {
    _nightPlan = handId == null
        ? null
        : {'hand_id': handId, 'target_id': target};
  }

  @override
  Future<PreviewRow> meetingStatus(String gameId) async => {
    'poll': _meetingPoll,
    'events': List.of(_meetingEvents),
    'can_vote': me['out_day'] == null,
    'heritage': false,
    'voted': me['ready'] == true,
    'eligible_total': roster.where((p) => p['out_day'] == null).length,
    'locked_voters': [for (final v in voteRows) v['voter_id']],
  };

  @override
  Future<PreviewRow> submitMeetingOpinion(
    String gameId,
    String pollId,
    String choice,
  ) async {
    if (_meetingPoll == null || _meetingPoll!['closed'] == true)
      throw StateError('Sidang sudah ditutup');
    if (_meetingPoll!['my_choice'] != null)
      throw StateError('Jawaban sudah terkunci');
    _meetingPoll = {
      ..._meetingPoll!,
      'my_choice': choice,
      'closed': true,
      'can_answer': false,
      'answered': roster.length,
      'counts': {
        'curiga': 2 + (choice == 'curiga' ? 1 : 0),
        'ragu': choice == 'ragu' ? 1 : 0,
        'percaya': roster.length - 3 + (choice == 'percaya' ? 1 : 0),
      },
    };
    return meetingStatus(gameId);
  }

  @override
  Future<PreviewRow> useAbility(
    String gameId, {
    String? target,
    String? option,
  }) async {
    if (_usedAbility) throw StateError('Kemampuan sudah terpakai');
    _usedAbility = true;
    if (_ability == 'sidang_terbuka') {
      _meetingPoll = {
        'id': 'preview-poll',
        'target': roster.where((p) => p['user_id'] == target).first['name'],
        'closed': false,
        'closes_at': DateTime.now()
            .toUtc()
            .add(const Duration(seconds: 25))
            .toIso8601String(),
        'total': roster.length,
        'answered': 0,
        'counts': null,
        'my_choice': null,
        'can_answer': true,
      };
      _meetingEvents.add({
        'id': 'preview-poll-event',
        'text': 'Rapat: Sidang Terbuka dimulai.',
      });
    }
    return {
      'result': 'ok',
      'message': 'Kemampuan dipakai dalam sesi contoh.',
      if (_ability == 'buktikan_tuduhan') 'correct': true,
    };
  }

  @override
  Future<PreviewRow?> recap(String gameId) async => {
    'offerings': [
      for (var i = 0; i < roster.length; i++)
        {
          'day': 3,
          'user_id': roster[i]['user_id'],
          'card_id': i < 3 ? 'air_suci' : 'embun_samaran',
        },
      for (final p in roster)
        {'day': 6, 'user_id': p['user_id'], 'card_id': 'embun_biasa'},
    ],
    'purchases': [
      for (var i = 0; i < roster.length; i++)
        {'day': 2 + i, 'user_id': roster[i]['user_id'], 'card_id': 'air_suci'},
    ],
    'votes': [
      for (final d in [3, 6, 9])
        for (final v in voteRows)
          {
            'day': d,
            'user_id': v['voter_id'],
            'target_id': v['target_id'],
            'weight': v['weight'],
          },
    ],
  };

  @override
  Future<List<PreviewRow>> fetch() async => [
    {
      'id': 2,
      'kind': 'pengumuman',
      'title': 'Selamat datang di Desa Hayu',
      'body':
          'Contoh pengumuman desa.\n\nJaga Hayu dan ajak warga bermusyawarah.',
      'pinned': true,
      'published_at': _stamp,
    },
    {
      'id': 1,
      'kind': 'pembaruan',
      'title': 'Dua Terbisik',
      'body': 'Mode baru untuk minimal lima pemain.',
      'version': '2.7.17',
      'pinned': false,
      'published_at': _stamp,
    },
  ];

  @override
  Future<List<PreviewRow>> updates() async => [];

  @override
  Future<int?> lastSeen() async => _seen;

  @override
  Future<void> markSeen(int id) async => _seen = id;

  @override
  Future<int> unreadCount() async => 0;
}
