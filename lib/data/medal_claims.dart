import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_medals.dart';
import 'profile_repository.dart';
import 'supabase_account_repository.dart';

const medalReceiptVersionKey = 'embun_medal_receipts_version';
String medalReceiptKey(String id) => 'embun_medal_received_$id';

class MedalReceipts {
  const MedalReceipts({required this.initialized, required this.claimed});
  final bool initialized;
  final Set<String> claimed;

  factory MedalReceipts.fromMetadata(Map<String, dynamic> metadata) =>
      MedalReceipts(
        initialized: metadata[medalReceiptVersionKey] == 1,
        claimed: {
          for (final medal in profileMedals)
            if (metadata[medalReceiptKey(medal.id)] == true) medal.id,
        },
      );
}

/// Cosmetic acknowledgements only. Eligibility always comes from server stats.
abstract interface class MedalReceiptRepository {
  Future<MedalReceipts> load(String userId);
  Future<void> save(String userId, Set<String> ids, {bool initialize = false});
}

class SupabaseMedalReceiptRepository implements MedalReceiptRepository {
  SupabaseMedalReceiptRepository(this.client);
  final SupabaseClient client;

  void _check(String userId) {
    final current = SupabaseAccountRepository.profileOf(
      client.auth.currentUser,
    );
    if (current?.userId != userId || current?.googleAccount != true) {
      throw StateError('Sesi akun berubah.');
    }
  }

  @override
  Future<MedalReceipts> load(String userId) async {
    _check(userId);
    final response = await client.auth.getUser().timeout(
      const Duration(seconds: 15),
    );
    _check(userId);
    if (response.user?.id != userId) throw StateError('Sesi akun berubah.');
    return MedalReceipts.fromMetadata(response.user?.userMetadata ?? {});
  }

  @override
  Future<void> save(
    String userId,
    Set<String> ids, {
    bool initialize = false,
  }) async {
    _check(userId);
    final known = profileMedals.map((m) => m.id).toSet();
    if (!known.containsAll(ids)) throw ArgumentError('Medali tidak dikenal.');
    // Auth merges these root keys. Each medal has its own monotonic key so
    // claims from different tabs/devices cannot overwrite a shared ID list.
    final response = await client.auth
        .updateUser(
          UserAttributes(
            data: {
              if (initialize) medalReceiptVersionKey: 1,
              for (final id in ids) medalReceiptKey(id): true,
            },
          ),
        )
        .timeout(const Duration(seconds: 15));
    _check(userId);
    if (response.user?.id != userId) throw StateError('Sesi akun berubah.');
  }
}

class MedalClaimsController extends ChangeNotifier {
  MedalClaimsController({
    required this.userId,
    required this.profiles,
    required this.receipts,
  });
  final String userId;
  final ProfileRepository profiles;
  final MedalReceiptRepository receipts;
  ProfileDetails? profile;
  final Set<String> _claimed = {};
  bool initialized = false, loading = false, _disposed = false;
  String? claimingId, error;
  Future<void>? _refreshing;

  bool get active => !_disposed;
  bool owns(ProfileDetails value) =>
      value.googleLinked && value.userId == userId;
  bool isClaimed(ProfileMedal medal) =>
      initialized && _claimed.contains(medal.id);
  List<ProfileMedal> get pending => !initialized || profile == null
      ? const []
      : earnedMedals(profile!).where((m) => !isClaimed(m)).toList();
  bool get hasPending => pending.isNotEmpty;

  Future<void> refresh({ProfileDetails? details}) {
    if (_disposed || claimingId != null) return Future.value();
    final running = _refreshing;
    if (running != null) {
      return details == null
          ? running
          : running.then((_) => refresh(details: details));
    }
    return _refreshing ??= _refresh(
      details,
    ).whenComplete(() => _refreshing = null);
  }

  Future<void> _refresh(ProfileDetails? details) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final value = details ?? await profiles.load(userId: userId);
      if (_disposed) return;
      if (!owns(value)) throw StateError('Profil akun tidak sesuai.');
      final saved = await receipts.load(userId);
      if (_disposed) return;
      final claimed = {...saved.claimed};
      if (!saved.initialized) {
        // One migration snapshot: already earned medals remain received.
        claimed.addAll(earnedMedals(value).map((m) => m.id));
        await receipts.save(userId, claimed, initialize: true);
        if (_disposed) return;
      }
      profile = value;
      _claimed.addAll(claimed);
      initialized = true;
    } catch (_) {
      if (!_disposed) error = 'Status medali belum dapat dimuat. Coba lagi.';
    } finally {
      if (!_disposed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> claim(ProfileMedal medal) async {
    if (_disposed || claimingId != null) return false;
    await _refreshing;
    final canonical = profileMedals.where((m) => m.id == medal.id).firstOrNull;
    final value = profile;
    if (_disposed ||
        claimingId != null ||
        !initialized ||
        value == null ||
        canonical == null ||
        !owns(value) ||
        !canonical.unlocked(value) ||
        isClaimed(medal)) {
      return false;
    }
    claimingId = medal.id;
    error = null;
    notifyListeners();
    try {
      // Another device may have received this medal since the last lobby poll.
      final latest = await receipts.load(userId);
      if (_disposed) return false;
      _claimed.addAll(latest.claimed);
      if (isClaimed(medal)) return false;
      await receipts.save(userId, {medal.id});
      if (_disposed) return false;
      _claimed.add(medal.id);
      return true;
    } catch (_) {
      if (!_disposed) {
        error = 'Klaim belum tersimpan. Periksa koneksi lalu coba lagi.';
      }
      return false;
    } finally {
      if (!_disposed) {
        claimingId = null;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
