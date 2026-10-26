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

  Future<String> createGame(String name, String card) async {
    await ensureSignedIn();
    return await _db.rpc('create_game',
        params: {'p_name': name, 'p_card': card}) as String;
  }

  Future<String> joinGame(String code, String name, String card) async {
    await ensureSignedIn();
    return await _db.rpc('join_game',
        params: {'p_code': code, 'p_name': name, 'p_card': card}) as String;
  }

  Future<void> startGame(String id) =>
      _db.rpc('start_game', params: {'p_game': id});

  Future<void> leave(String id) =>
      _db.rpc('leave_game', params: {'p_game': id});

  Future<void> updateCharacter(String gameId, String name, String card) =>
      _db.rpc('update_character',
          params: {'p_game': gameId, 'p_name': name, 'p_card': card});

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

  Future<Map<String, dynamic>?> activeGame() async {
    final rows = await _db
        .from('games')
        .select()
        .neq('status', 'finished')
        .order('created_at', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  }

  Future<String?> myRole(String gameId) async =>
      (await mySecret(gameId))?['role'] as String?;

  /// Peran dan benih kartu gelap milik sendiri.
  Future<Map<String, dynamic>?> mySecret(String gameId) async {
    final row = await _db
        .from('player_secrets')
        .select('role, dark_seed')
        .eq('game_id', gameId)
        .eq('user_id', _db.auth.currentUser!.id)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  /// Hanya terbaca setelah permainan selesai (diatur RLS).
  Future<Map<String, Map<String, dynamic>>> allSecrets(String gameId) async {
    final rows = await _db
        .from('player_secrets')
        .select('user_id, role, dark_seed')
        .eq('game_id', gameId);
    return {
      for (final r in rows)
        r['user_id'] as String: Map<String, dynamic>.from(r)
    };
  }

  String? get myId => _db.auth.currentUser?.id;
}