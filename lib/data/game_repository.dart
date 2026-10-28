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
    final rows = await _db
        .from('effect_log')
    // Kolom delta/leaves_after sengaja tidak diminta (dan dicabut hak
    // bacanya di server): akan membocorkan efek Topeng Warga.
        .select('id, game_id, day, seq, kind, label')
        .eq('game_id', gameId)
        .eq('day', day)
        .order('seq');
    return List<Map<String, dynamic>>.from(rows);
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

  Stream<List<Map<String, dynamic>>> chat(String gameId) => _db
      .from('chat_messages')
      .stream(primaryKey: ['id'])
      .eq('game_id', gameId)
      .order('created_at');

  Future<void> sendMessage(String gameId, String body) =>
      _db.rpc('send_message', params: {'p_game': gameId, 'p_body': body});

  Future<void> readyToVote(String gameId) =>
      _db.rpc('ready_to_vote', params: {'p_game': gameId});

  Future<void> submitVote(String gameId, String? target) =>
      _db.rpc('submit_vote', params: {'p_game': gameId, 'p_target': target});

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
          .timeout(const Duration(seconds: 2));
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }

  /// Null bila permainan belum selesai.
  Future<Map<String, dynamic>?> recap(String gameId) async {
    final r = await _db.rpc('game_recap', params: {'p_game': gameId});
    return r == null ? null : Map<String, dynamic>.from(r as Map);
  }
}