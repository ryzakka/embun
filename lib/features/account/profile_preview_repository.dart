import '../../data/profile_repository.dart';

/// Offline fixtures for the explicitly labelled preview entry point only.
class PreviewProfileRepository implements ProfileRepository {
  String title = 'Dermawan Hayu';
  bool deletionPending = false;
  @override
  Future<ProfileDetails> load({
    required String userId,
    String? gameId,
    int offset = 0,
  }) async => ProfileDetails(
    userId: userId,
    nickname: 'Pemain Contoh',
    avatarId: 'penjaga_hayu',
    title: title,
    completed: 2,
    wargaWins: 1,
    terbisikWins: 0,
    history: offset > 0
        ? []
        : [
            ProfileMatch(
              id: 'contoh-1',
              finishedAt: DateTime(2026, 11, 20, 18),
              side: 'warga',
              won: true,
              days: 4,
            ),
            ProfileMatch(
              id: 'contoh-2',
              finishedAt: DateTime(2026, 11, 19, 20),
              side: 'antagonis',
              won: false,
              days: 3,
            ),
          ],
    hasMore: false,
    deletionRequest: deletionPending
        ? {'id': 'CONTOH-LOKAL', 'status': 'pending'}
        : null,
  );
  @override
  Future<void> equipTitle(String title) async {
    this.title = title;
  }

  @override
  Future<void> requestDeletion() async {
    deletionPending = true;
  }
}
