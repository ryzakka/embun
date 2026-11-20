import 'dart:async';
import 'package:flutter/material.dart';
import 'data/account_controller.dart';
import 'data/asset_catalog.dart';
import 'data/player_profile.dart';
import 'features/account/account_app.dart';
import 'features/account/account_pages.dart';
import 'features/account/profile_preview_repository.dart';
import 'features/account/profile_details_page.dart';
import 'features/account/account_status_badge.dart';

/// A separate offline entry point. Never used by lib/main.dart.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AssetCatalog.load();
  runApp(const AccountPreviewApp());
}

class PreviewAccountRepository
    implements AccountRepository, GuestAccountRepository {
  final _stream = StreamController<PlayerProfile?>.broadcast(sync: true);
  PlayerProfile? _current;
  @override
  PlayerProfile? get current => _current;
  @override
  Stream<PlayerProfile?> get changes => _stream.stream;
  @override
  Future<PlayerProfile?> restore() async => _current;
  void _emit(PlayerProfile? profile) {
    _current = profile;
    _stream.add(profile);
  }

  @override
  Future<PlayerProfile> signInAsGuest() async {
    final value =
        current ??
        const PlayerProfile(
          userId: 'local-guest',
          googleAccount: false,
          anonymous: true,
          metadata: {},
        );
    _emit(value);
    return value;
  }

  @override
  Future<bool> linkWithGoogle() async {
    _emit(
      PlayerProfile(
        userId: current?.userId ?? 'local-preview',
        googleAccount: true,
        email: 'contoh@example.test',
        metadata: const {'full_name': 'Pemain Embun'},
      ),
    );
    return true;
  }

  @override
  Future<bool> signInWithGoogle() async {
    _emit(
      const PlayerProfile(
        userId: 'local-preview',
        googleAccount: true,
        email: 'contoh@example.test',
        metadata: {'full_name': 'Pemain Embun'},
      ),
    );
    return true;
  }

  @override
  Future<PlayerProfile> saveProfile({
    required String userId,
    required String nickname,
    required String avatarId,
  }) async {
    final profile = PlayerProfile(
      userId: userId,
      googleAccount: true,
      email: current?.email,
      metadata: {
        'embun_nickname': nickname,
        'embun_avatar': avatarId,
        'embun_profile_version': 1,
      },
    );
    _emit(profile);
    return profile;
  }

  @override
  Future<void> signOut() async => _emit(null);
  Future<void> dispose() => _stream.close();
}

class AccountPreviewApp extends StatefulWidget {
  const AccountPreviewApp({super.key});
  @override
  State<AccountPreviewApp> createState() => _AccountPreviewAppState();
}

class _AccountPreviewAppState extends State<AccountPreviewApp> {
  final _repo = PreviewAccountRepository();
  final _profiles = PreviewProfileRepository();
  late final _account = AccountController(_repo);
  @override
  void initState() {
    super.initState();
    _account.start();
  }

  @override
  void dispose() {
    _account.dispose();
    _repo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AccountApplication(
    account: _account,
    builder: (_, child) => Banner(
      message: 'PRATINJAU LOKAL',
      location: BannerLocation.topEnd,
      child: child ?? const SizedBox.shrink(),
    ),
    home: AnimatedBuilder(
      animation: _account,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AccountAvatarBadge(
                    linked: _account.googleAccount,
                    child: _account.guest
                        ? const CircleAvatar(child: Icon(Icons.person_outline))
                        : ProfileAvatar(avatarId: _account.profile!.avatarId),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Halo, ${_account.guest ? 'Tamu' : _account.profile!.nickname}',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Profil pratinjau disimpan di memori. Google dan Supabase tidak dihubungi.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProfilePage(
                          account: _account,
                          detailsRepository: _profiles,
                        ),
                      ),
                    ),
                    child: Text(_account.guest ? 'Informasi tamu' : 'Profilku'),
                  ),
                  TextButton(
                    onPressed: () => showPlayerProfile(
                      context,
                      gameId: 'preview-room',
                      userId: 'preview-other',
                      repository: _profiles,
                    ),
                    child: const Text('Contoh profil pemain lain'),
                  ),
                  TextButton(
                    onPressed: _account.logout,
                    child: const Text('Keluar akun'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
