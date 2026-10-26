import 'package:supabase_flutter/supabase_flutter.dart';

final _db = Supabase.instance.client;

class LobbyRepository {
  Future<void> ensureSignedIn() async {
    if (_db.auth.currentSession != null) return;
    try {
      await _db.auth.signInAnonymously();
    } on AuthException catch (e) {
      throw Exception('Gagal masuk anonim: ${e.message}');
    }
  }

  Future<String> createGame(String name) async {
    await ensureSignedIn();
    return await _db.rpc('create_game', params: {'p_name': name}) as String;
  }

  Future<String> joinGame(String code, String name) async {
    await ensureSignedIn();
    return await _db.rpc('join_game',
        params: {'p_code': code, 'p_name': name}) as String;
  }

  Future<void> startGame(String id) =>
      _db.rpc('start_game', params: {'p_game': id});

  Future<void> leave(String id) =>
      _db.rpc('leave_game', params: {'p_game': id});

  Stream<List<Map<String, dynamic>>> players(String gameId) => _db
      .from('game_players')
      .stream(primaryKey: ['game_id', 'user_id'])
      .eq('game_id', gameId)
      .order('joined_at');

  Stream<Map<String, dynamic>> game(String gameId) => _db
      .from('games')
      .stream(primaryKey: ['id'])
      .eq('id', gameId)
      .where((rows) => rows.isNotEmpty)
      .map((rows) => rows.first);

  String? get myId => _db.auth.currentUser?.id;
}