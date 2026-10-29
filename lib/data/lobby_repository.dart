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

  /// Khusus host: bubarkan ruangan (lobi) atau sudahi permainan (berjalan).
  Future<void> endGame(String id) =>
      _db.rpc('end_game', params: {'p_game': id});

  Future<void> setReady(String gameId, bool ready) =>
      _db.rpc('set_ready', params: {'p_game': gameId, 'p_ready': ready});

  Future<void> updateCharacter(String gameId, String name, String card) =>
      _db.rpc('update_character',
          params: {'p_game': gameId, 'p_name': name, 'p_card': card});

  Stream<List<Map<String, dynamic>>> players(String gameId) => _db
      .from('game_players')
      .stream(primaryKey: ['game_id', 'user_id'])
      .eq('game_id', gameId)
      .order('joined_at');

  /// null = baris game sudah tidak ada (ruangan dibubarkan).
  Stream<Map<String, dynamic>?> game(String gameId) => _db
      .from('games')
      .stream(primaryKey: ['id'])
      .eq('id', gameId)
      .map((rows) => rows.isEmpty ? null : rows.first);

  /// Permainan terbaru yang belum selesai DAN diikuti pemain ini.
  Future<Map<String, dynamic>?> activeGame() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return null;
    final rows = await _db
        .from('game_players')
        .select('joined_at, games!inner(*)')
        .eq('user_id', uid)
        .neq('games.status', 'finished')
        .order('joined_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first['games'] as Map);
  }

  Future<String?> myRole(String gameId) async =>
      (await mySecret(gameId))?['role'] as String?;

  /// Peran, benih kartu gelap, dan kemampuan milik sendiri.
  Future<Map<String, dynamic>?> mySecret(String gameId) async {
    final uid = _db.auth.currentUser!.id;
    Future<Map<String, dynamic>?> q(String cols) async {
      final row = await _db
          .from('player_secrets')
          .select(cols)
          .eq('game_id', gameId)
          .eq('user_id', uid)
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    }

    try {
      return await q('role, dark_seed, ability, ability_used');
    } catch (_) {
      // Kolom kemampuan belum ada (migrasi v4 belum dijalankan): pakai yang lama.
      return q('role, dark_seed');
    }
  }

  /// Hanya terbaca setelah permainan selesai (diatur RLS).
  Future<Map<String, Map<String, dynamic>>> allSecrets(String gameId) async {
    List<Map<String, dynamic>> rows;
    try {
      rows = List<Map<String, dynamic>>.from(await _db
          .from('player_secrets')
          .select('user_id, role, dark_seed, ability')
          .eq('game_id', gameId));
    } catch (_) {
      rows = List<Map<String, dynamic>>.from(await _db
          .from('player_secrets')
          .select('user_id, role, dark_seed')
          .eq('game_id', gameId));
    }
    return {
      for (final r in rows)
        r['user_id'] as String: Map<String, dynamic>.from(r)
    };
  }

  String? get myId => _db.auth.currentUser?.id;
}