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

  Future<void> submitOffering(String gameId, List<String> handIds) =>
      _db.rpc('submit_offering',
          params: {'p_game': gameId, 'p_hand_ids': handIds});

  Future<List<Map<String, dynamic>>> effects(String gameId, int day) async {
    final rows = await _db
        .from('effect_log')
        .select()
        .eq('game_id', gameId)
        .eq('day', day)
        .order('seq');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> advanceAfterEffects(String gameId) =>
      _db.rpc('advance_after_effects', params: {'p_game': gameId});
}