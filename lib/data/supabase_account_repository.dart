import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'account_controller.dart';
import 'player_profile.dart';

class SupabaseAccountRepository implements AccountRepository {
  SupabaseAccountRepository(this.client);
  final SupabaseClient client;
  static const mobileRedirect = String.fromEnvironment(
    'EMBUN_AUTH_REDIRECT',
    defaultValue: 'com.ryzakka.embun://login-callback/',
  );

  static PlayerProfile? profileOf(User? user) {
    if (user == null) return null;
    final providers = user.appMetadata['providers'];
    final google =
        !user.isAnonymous &&
        (user.identities?.any((i) => i.provider == 'google') == true ||
            user.appMetadata['provider'] == 'google' ||
            providers is List && providers.contains('google'));
    return PlayerProfile(
      userId: user.id,
      googleAccount: google,
      email: user.email,
      metadata: Map<String, dynamic>.unmodifiable(user.userMetadata ?? {}),
    );
  }

  @override
  PlayerProfile? get current => profileOf(client.auth.currentSession?.user);
  @override
  Stream<PlayerProfile?> get changes => client.auth.onAuthStateChange.map(
    (state) => profileOf(state.session?.user),
  );

  @override
  Future<PlayerProfile?> restore() async {
    final session = client.auth.currentSession;
    if (session != null && session.isExpired) {
      await client.auth.refreshSession().timeout(const Duration(seconds: 15));
    }
    return current;
  }

  @override
  Future<bool> signInWithGoogle() => client.auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: kIsWeb
        ? webAccountRedirect(Uri.base).toString()
        : mobileRedirect,
    authScreenLaunchMode: LaunchMode.externalApplication,
    queryParams: const {'prompt': 'select_account'},
  );

  @override
  Future<PlayerProfile> saveProfile({
    required String userId,
    required String nickname,
    required String avatarId,
  }) async {
    if (current?.userId != userId || current?.googleAccount != true) {
      throw const AuthException('Sesi akun berubah.');
    }
    final validation = nicknameError(nickname);
    if (validation != null || !profileAvatarIds.contains(avatarId)) {
      throw ArgumentError(validation ?? 'Avatar tidak valid.');
    }
    final response = await client.auth.updateUser(
      UserAttributes(
        data: {
          'embun_nickname': normalizeNickname(nickname),
          'embun_avatar': avatarId,
          'embun_profile_version': 1,
        },
      ),
    );
    final result = profileOf(response.user);
    if (result == null ||
        result.userId != userId ||
        current?.userId != userId) {
      throw const AuthException('Sesi akun berubah saat menyimpan profil.');
    }
    return result;
  }

  @override
  Future<void> signOut() => client.auth.signOut(scope: SignOutScope.local);
}
