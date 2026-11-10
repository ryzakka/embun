import 'package:supabase_flutter/supabase_flutter.dart';
import 'server_clock.dart';

class GameRepository {
  final _db = Supabase.instance.client;
  String get myId => _db.auth.currentUser!.id;

  Future<Map<String, Map<String, dynamic>>> cardDefs() async {
    final rows = await _db.from('card_definitions').select();
    return {
      for (final r in rows) r['id'] as String: Map<String, dynamic>.from(r)
    };
  }

  Future<List<Map<String, dynamic>>> offers(String gameId, int day) async {
    final rows = await _db
        .from('market_offers')
        .select()
        .eq('game_id', gameId)
        .eq('user_id', myId)
        .eq('day', day)
        .order('slot');
    return List<Map<String, dynamic>>.from(rows);
  }

  Stream<Map<String, dynamic>?> myState(String gameId) => _db
      .from('player_state')
      .stream(primaryKey: ['game_id', 'user_id'])
      .eq('game_id', gameId)
      .map((rows) {
    for (final r in rows) {
      if (r['user_id'] == myId) return r;
    }
    return null;
  });

  Stream<List<Map<String, dynamic>>> myHand(String gameId) => _db
      .from('hand_cards')
      .stream(primaryKey: ['id'])
      .eq('game_id', gameId)
      .map((rows) => rows.where((r) => r['user_id'] == myId).toList());

  /// Tangan kartu yang sebenarnya, langsung dari database. Stream realtime
  /// tidak mengirim peristiwa hapus untuk tabel ber-RLS, jadi kartu yang
  /// sudah dipersembahkan atau ditukar tetap "tertinggal" di daftar stream.
  /// Gunakan ini sebagai sumber kebenaran.
  Future<List<Map<String, dynamic>>> handNow(String gameId) async {
    final rows = await _db
        .from('hand_cards')
        .select()
        .eq('game_id', gameId)
        .eq('user_id', myId)
        .order('acquired_day')
        .order('id');
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Gabungkan kartu lanjutan (Regenerasi / Rekayasa) dengan satu kartu poin
  /// di tangan. Hasil: {message, hand_id}. Kartu menjadi aktif (charged).
  Future<Map<String, dynamic>> fuseCards(String gameId, String handId) async {
    final r = await _db.rpc('fuse_cards',
        params: {'p_game': gameId, 'p_hand_id': handId});
    return Map<String, dynamic>.from(r as Map);
  }

  Future<void> finishDay(String gameId, {String? card}) =>
      _db.rpc('finish_day', params: {'p_game': gameId, 'p_card': card});

  Future<void> submitOffering(String gameId, List<String> handIds,
      {String? target}) =>
      _db.rpc('submit_offering', params: {
        'p_game': gameId,
        'p_hand_ids': handIds,
        'p_target': target,
      });

  Future<List<Map<String, dynamic>>> effects(String gameId, int day) async {
    // Kolom delta/leaves_after sengaja tidak diminta (dan dicabut hak
    // bacanya di server): akan membocorkan efek Topeng Warga.
    // card_seq = nomor kartu (urutan lempar) yang menghasilkan efek; kolomnya
    // baru, jadi bila belum ada di server, ulangi tanpa kolom itu.
    try {
      final rows = await _db
          .from('effect_log')
          .select('id, game_id, day, seq, kind, label, card_seq')
          .eq('game_id', gameId)
          .eq('day', day)
          .order('seq');
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      final rows = await _db
          .from('effect_log')
          .select('id, game_id, day, seq, kind, label')
          .eq('game_id', gameId)
          .eq('day', day)
          .order('seq');
      return List<Map<String, dynamic>>.from(rows);
    }
  }

  /// Jumlah daun sebelum efek hari ini diterapkan (awal hitungan animasi).
  /// Null bila kolomnya belum ada atau belum terisi.
  Future<int?> leavesBefore(String gameId) async {
    try {
      final r = await _db
          .from('games')
          .select('leaves_before_effects')
          .eq('id', gameId)
          .maybeSingle();
      return r?['leaves_before_effects'] as int?;
    } catch (_) {
      return null;
    }
  }

  /// Semua kartu yang dipersembahkan pada malam [day], urutan acak dan TANPA
  /// nama pemilik (dipakai adegan pelemparan ke Hayu). Kosong bila tabelnya
  /// belum ada / belum terisi.
  Future<List<String>> revealedCards(String gameId, int day) async {
    try {
      final rows = await _db
          .from('offering_reveal')
          .select('seq, card_id')
          .eq('game_id', gameId)
          .eq('day', day)
          .order('seq');
      return [for (final r in rows) r['card_id'] as String];
    } catch (_) {
      return [];
    }
  }

  /// Jumlah kartu yang diserahkan tiap pemain pada malam [day]
  /// (terbuka setelah efek; nama kartu tetap rahasia).
  Future<Map<String, int>> offeringCounts(String gameId, int day) async {
    try {
      final rows = await _db
          .from('offering_counts')
          .select('user_id, n_cards')
          .eq('game_id', gameId)
          .eq('day', day);
      return {
        for (final r in rows) r['user_id'] as String: r['n_cards'] as int
      };
    } catch (_) {
      return {};
    }
  }

  /// Banyak daun yang digerogoti kabut tiap malam untuk [players] pemain.
  Future<int?> fogFor(int players) async {
    try {
      final r = await _db
          .from('game_balance')
          .select('fog')
          .eq('players', players)
          .maybeSingle();
      return r?['fog'] as int?;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> privateLogs(
      String gameId, int day) async {
    final rows = await _db
        .from('private_logs')
        .select()
        .eq('game_id', gameId)
        .eq('day', day)
        .eq('user_id', myId);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> advanceAfterEffects(String gameId) =>
      _db.rpc('advance_after_effects', params: {'p_game': gameId});

  Stream<List<Map<String, dynamic>>> chat(String gameId, {bool terbisik = false}) => _db
      .from(terbisik ? 'terbisik_messages' : 'chat_messages')
      .stream(primaryKey: ['id'])
      .eq('game_id', gameId)
      .order('created_at');

  Future<void> sendMessage(String gameId, String body, {bool terbisik = false}) =>
      _db.rpc(terbisik ? 'send_terbisik_message' : 'send_message',
          params: {'p_game': gameId, 'p_body': body});

  Future<void> readyToVote(String gameId) =>
      _db.rpc('ready_to_vote', params: {'p_game': gameId});

  /// [hammer] = pakai Patuhilah Padaku (suara bernilai 2). Hanya sah bila
  /// pemain memegang kemampuannya dan [target] tidak kosong.
  Future<void> submitVote(String gameId, String? target,
      {bool hammer = false}) =>
      _db.rpc('submit_vote', params: {
        'p_game': gameId,
        'p_target': target,
        'p_hammer': hammer,
      });

  /// Detak jantung + penegakan tenggat fase.
  Future<void> tick(String gameId) {
    if (ServerClock.needsSync) {
      ServerClock.markSyncing();
      syncClock().catchError((_) {});
    }
    return _db.rpc('tick', params: {'p_game': gameId});
  }

  /// Hitung selisih jam perangkat dengan server (titik tengah permintaan).
  Future<void> syncClock() async {
    final t0 = DateTime.now();
    final r = await _db.rpc('server_now');
    final t1 = DateTime.now();
    final server = DateTime.parse(r as String);
    ServerClock.offset =
        server.difference(t0.add(Duration(microseconds: t1.difference(t0).inMicroseconds ~/ 2)));
  }

  Stream<List<Map<String, dynamic>>> emotes(String gameId) => _db
      .from('emotes')
      .stream(primaryKey: ['id'])
      .eq('game_id', gameId)
      .order('created_at');

  Future<void> sendEmote(String gameId, String emoji, {String? target}) =>
      _db.rpc('send_emote',
          params: {'p_game': gameId, 'p_emoji': emoji, 'p_target': target});

  // ---- v2 ----
  Future<Map<String, dynamic>> researchStock(String gameId) async {
    final r = await _db.rpc('research_stock', params: {'p_game': gameId});
    return Map<String, dynamic>.from(r as Map);
  }

  Future<void> buyResearch(String gameId, String card) =>
      _db.rpc('buy_research_card', params: {'p_game': gameId, 'p_card': card});

  Future<void> finishResearch(String gameId) =>
      _db.rpc('finish_research', params: {'p_game': gameId});

  Future<void> buyCard(String gameId, String card) =>
      _db.rpc('buy_card', params: {'p_game': gameId, 'p_card': card});

  Future<void> giveEmbun(String gameId, String to, int amount) => _db.rpc(
      'give_embun',
      params: {'p_game': gameId, 'p_to': to, 'p_amount': amount});

  Future<void> proposeTrade(String gameId, String to, String handId) =>
      _db.rpc('propose_trade',
          params: {'p_game': gameId, 'p_to': to, 'p_hand_id': handId});

  Future<void> respondTrade(String tradeId, bool accept, {String? returnHand}) =>
      _db.rpc('respond_trade', params: {
        'p_trade': tradeId,
        'p_accept': accept,
        'p_return_hand': returnHand,
      });

  Stream<List<Map<String, dynamic>>> villageEvents(String gameId) => _db
      .from('village_events')
      .stream(primaryKey: ['id'])
      .eq('game_id', gameId)
      .order('created_at');

  /// RLS hanya menyerahkan tawaran yang melibatkan pemain ini.
  Stream<List<Map<String, dynamic>>> trades(String gameId) => _db
      .from('trade_offers')
      .stream(primaryKey: ['id'])
      .eq('game_id', gameId);

  Stream<List<Map<String, dynamic>>> presence(String gameId) => _db
      .from('player_presence')
      .stream(primaryKey: ['game_id', 'user_id'])
      .eq('game_id', gameId);

  /// Username asli pemain. Baru terbaca setelah permainan selesai (RLS).
  Future<Map<String, String>> usernames(String gameId) async {
    final rows = await _db
        .from('player_usernames')
        .select('user_id, username')
        .eq('game_id', gameId);
    return {
      for (final r in rows) r['user_id'] as String: r['username'] as String
    };
  }

  /// Pemain yang mulai dikurung pada [day] (vonis vote atau kartu malam
  /// persembahan). Kurungan berlanjut sampai vote berikutnya.
  /// Kosong bila tidak ada, atau bila gagal memuat.
  Future<List<Map<String, dynamic>>> jailedAt(String gameId, int day) async {
    try {
      final rows = await _db
          .from('game_players')
          .select('user_id, name, character_card')
          .eq('game_id', gameId)
          .eq('jailed_day', day)
          .isFilter('out_day', null)
          .order('user_id')
          .timeout(const Duration(seconds: 2));
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }

  /// Pemain yang keluar dari desa pada [day] (vonis tuduhan kedua).
  /// Barisnya tetap ada di game_players (out_day terisi), jadi bisa dibaca
  /// semua anggota. Kosong bila tidak ada, atau bila gagal memuat.
  Future<List<Map<String, dynamic>>> evictedAt(String gameId, int day) async {
    try {
      final rows = await _db
          .from('game_players')
          .select('user_id, name, character_card')
          .eq('game_id', gameId)
          .eq('out_day', day)
          .timeout(const Duration(seconds: 2));
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }

  /// Semua suara satu putaran voting, urutan server (yang tidak memilih di
  /// akhir). Hanya terisi setelah voting selesai (tabel vote_reveal).
  Future<List<Map<String, dynamic>>> voteReveal(String gameId, int day) async {
    final rows = await _db
        .from('vote_reveal')
        .select()
        .eq('game_id', gameId)
        .eq('day', day)
        .order('seq');
    return List<Map<String, dynamic>>.from(rows);
  }

  // ---- serangan malam ----
  /// Laporan malam hari [day]: pengumuman untuk semua + baris pribadi milikku.
  Future<List<Map<String, dynamic>>> nightReports(String gameId, int day) async {
    final rows = await _db
        .from('night_reports')
        .select()
        .eq('game_id', gameId)
        .eq('day', day)
        .order('id');
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Rencana serangan malam milikku (Si Terbisik) untuk hari [day], atau null.
  Future<Map<String, dynamic>?> nightPlan(String gameId, int day) async {
    final r = await _db
        .from('night_plan')
        .select()
        .eq('game_id', gameId)
        .eq('day', day)
        .eq('user_id', myId)
        .maybeSingle();
    return r == null ? null : Map<String, dynamic>.from(r);
  }

  /// Memakai kartu kuning (hari biasa). Hasil: {mode, message}.
  Future<Map<String, dynamic>> useDayCard(String gameId, String handId,
      {String? target}) async {
    final r = await _db.rpc('use_day_card',
        params: {'p_game': gameId, 'p_hand_id': handId, 'p_target': target});
    return Map<String, dynamic>.from(r as Map);
  }

  /// Perlindungan / cermin yang sedang aktif milikku. Kosong bila gagal.
  Future<List<Map<String, dynamic>>> myGuards(String gameId) async {
    try {
      final rows = await _db
          .from('player_guards')
          .select()
          .eq('game_id', gameId)
          .eq('user_id', myId);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }

  /// Si Terbisik selesai menentukan malam (pakai kartu atau tidak): malam
  /// dijalankan sekarang, tanpa menunggu tenggat.
  Future<void> nightContinue(String gameId) =>
      _db.rpc('night_continue', params: {'p_game': gameId});

  /// Siapkan kartu serangan malam. Tanpa [handId] = batalkan rencana.
  Future<void> armNightCard(String gameId, {String? handId, String? target}) =>
      _db.rpc('arm_night_card',
          params: {'p_game': gameId, 'p_hand_id': handId, 'p_target': target});

  // ---- kemampuan warga ----
  Future<Map<String, Map<String, dynamic>>> abilityDefs() async {
    final rows = await _db.from('ability_definitions').select();
    return {
      for (final r in rows) r['id'] as String: Map<String, dynamic>.from(r)
    };
  }

  /// Memakai kemampuan sekali pakai. Hasil: {result, message, ...}.
  Future<Map<String, dynamic>> useAbility(String gameId,
      {String? target, String? option}) async {
    final r = await _db.rpc('use_ability',
        params: {'p_game': gameId, 'p_target': target, 'p_option': option});
    return Map<String, dynamic>.from(r as Map);
  }

  /// Null bila permainan belum selesai.
  Future<Map<String, dynamic>?> recap(String gameId) async {
    final r = await _db.rpc('game_recap', params: {'p_game': gameId});
    return r == null ? null : Map<String, dynamic>.from(r as Map);
  }
}