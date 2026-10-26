import 'package:supabase_flutter/supabase_flutter.dart';

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
        .select()
        .eq('game_id', gameId)
        .eq('day', day)
        .order('seq');
    return List<Map<String, dynamic>>.from(rows);
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
  Future<void> tick(String gameId) =>
      _db.rpc('tick', params: {'p_game': gameId});

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

  /// Null bila permainan belum selesai.
  Future<Map<String, dynamic>?> recap(String gameId) async {
    final r = await _db.rpc('game_recap', params: {'p_game': gameId});
    return r == null ? null : Map<String, dynamic>.from(r as Map);
  }
}