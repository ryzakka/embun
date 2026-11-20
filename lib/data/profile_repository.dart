import 'package:supabase_flutter/supabase_flutter.dart';

/// Display titles use the existing ending vocabulary. They are selectable
/// labels for now, not achievements or a promise of an earned reward.
const profileTitles = [
  'Mata Elang',
  'Paling Dicurigai',
  'Salah Sasaran',
  'Dermawan Hayu',
  'Pembelanja Ulung',
  'Dalang Kabut',
  'Tak Pernah Meleset',
  'Paling Ragu',
  'Bayang Lolos',
];

class ProfileMatch {
  const ProfileMatch({
    required this.id,
    required this.finishedAt,
    required this.side,
    required this.won,
    required this.days,
  });
  final String id;
  final DateTime finishedAt;
  final String side;
  final bool won;
  final int days;
  factory ProfileMatch.fromJson(Map<String, dynamic> json) => ProfileMatch(
    id: json['game_id'] as String,
    finishedAt: DateTime.parse(json['finished_at'] as String).toLocal(),
    side: json['side'] as String,
    won: json['won'] == true,
    days: (json['days'] as num).toInt(),
  );
}

class ProfileDetails {
  const ProfileDetails({
    required this.userId,
    required this.nickname,
    required this.avatarId,
    required this.title,
    required this.completed,
    required this.wargaWins,
    required this.terbisikWins,
    required this.history,
    required this.hasMore,
    this.deletionRequest,
  });
  final String userId, nickname, avatarId, title;
  final int completed, wargaWins, terbisikWins;
  final List<ProfileMatch> history;
  final bool hasMore;
  final Map<String, dynamic>? deletionRequest;

  factory ProfileDetails.fromJson(Map<String, dynamic> json) => ProfileDetails(
    userId: json['user_id'] as String,
    nickname: json['nickname'] as String? ?? 'Pemain Embun',
    avatarId: json['avatar_id'] as String? ?? 'penjaga_hayu',
    title: json['title'] as String? ?? '',
    completed: (json['completed'] as num).toInt(),
    wargaWins: (json['warga_wins'] as num).toInt(),
    terbisikWins: (json['terbisik_wins'] as num).toInt(),
    history: (json['history'] as List)
        .map((e) => ProfileMatch.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    hasMore: json['has_more'] == true,
    deletionRequest: json['deletion_request'] is Map
        ? Map<String, dynamic>.from(json['deletion_request'] as Map)
        : null,
  );
}

abstract interface class ProfileRepository {
  Future<ProfileDetails> load({
    required String userId,
    String? gameId,
    int offset = 0,
  });
  Future<void> equipTitle(String title);
  Future<void> requestDeletion();
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this.client);
  final SupabaseClient client;

  @override
  Future<ProfileDetails> load({
    required String userId,
    String? gameId,
    int offset = 0,
  }) async {
    final data = await client
        .rpc(
          'embun_profile_get',
          params: {'p_user': userId, 'p_game': gameId, 'p_offset': offset},
        )
        .timeout(const Duration(seconds: 15));
    return ProfileDetails.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<void> equipTitle(String title) async {
    await client
        .rpc('embun_profile_title', params: {'p_title': title})
        .timeout(const Duration(seconds: 15));
  }

  @override
  Future<void> requestDeletion() async {
    await client
        .rpc('embun_profile_request_deletion')
        .timeout(const Duration(seconds: 15));
  }
}
