// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
import '../lib/data/account_controller.dart';
import '../lib/data/player_profile.dart';
import '../lib/data/profile_repository.dart';
import '../lib/data/supabase_account_repository.dart';
import '../lib/features/account/account_app.dart';
import '../lib/features/account/account_pages.dart';
import '../lib/features/account/account_status_badge.dart';
import '../lib/features/account/google_sign_in_button.dart';
import '../lib/features/account/profile_details_page.dart';
import '../lib/features/account/room_account_status.dart';

const guest = PlayerProfile(
  userId: 'guest',
  googleAccount: false,
  anonymous: true,
  metadata: {},
);
const linked = PlayerProfile(
  userId: 'guest',
  googleAccount: true,
  email: 'private@example.test',
  metadata: {
    'embun_nickname': 'Dhimas',
    'embun_avatar': 'penjaga_hayu',
    'embun_profile_version': 1,
  },
);

class GuestAccounts implements AccountRepository, GuestAccountRepository {
  GuestAccounts([this.value]);
  PlayerProfile? value;
  final events = StreamController<PlayerProfile?>.broadcast(sync: true);
  int creates = 0, links = 0, logins = 0, saves = 0;
  bool fail = false;
  Completer<PlayerProfile>? pending;
  void emit(PlayerProfile? p) {
    value = p;
    events.add(p);
  }

  @override
  PlayerProfile? get current => value;
  @override
  Stream<PlayerProfile?> get changes => events.stream;
  @override
  Future<PlayerProfile?> restore() async => value;
  @override
  Future<PlayerProfile> signInAsGuest() async {
    creates++;
    if (fail) throw StateError('offline');
    if (pending != null) return pending!.future;
    final p = value ?? guest;
    emit(p);
    return p;
  }

  @override
  Future<bool> linkWithGoogle() async {
    links++;
    return true;
  }

  @override
  Future<bool> signInWithGoogle() async {
    logins++;
    return true;
  }

  @override
  Future<PlayerProfile> saveProfile({
    required String userId,
    required String nickname,
    required String avatarId,
  }) async {
    saves++;
    return linked;
  }

  @override
  Future<void> signOut() async => emit(null);
  Future<void> dispose() => events.close();
}

class GuestProfiles implements ProfileRepository {
  @override
  Future<ProfileDetails> load({
    required String userId,
    String? gameId,
    int offset = 0,
  }) async => ProfileDetails(
    userId: userId,
    nickname: 'Tamu Desa',
    avatarId: 'guest',
    title: '',
    completed: 999,
    wargaWins: 999,
    terbisikWins: 999,
    history: const [],
    hasMore: false,
    googleLinked: false,
  );
  @override
  Future<void> equipTitle(String title) async =>
      throw StateError('not allowed');
  @override
  Future<void> requestDeletion() async => throw StateError('not allowed');
}

void main() {
  test(
    'restored guest can play without setting up a persistent profile',
    () async {
      final repo = GuestAccounts(guest);
      final account = AccountController(repo);
      await account.start();
      expect(account.guest, true);
      expect(account.ready, true);
      expect(account.googleAccount, false);
      expect(account.identity, 'guest');
      expect(await account.save('Tamu', 'penjaga_hayu'), false);
      expect(repo.saves, 0);
      account.dispose();
      await repo.dispose();
    },
  );
  test('failed anonymous sign-in never admits the player', () async {
    final repo = GuestAccounts()..fail = true;
    final account = AccountController(repo);
    await account.start();
    await account.continueAsGuest();
    expect(account.ready, false);
    expect(account.error, isNotNull);
    account.dispose();
    await repo.dispose();
  });
  test(
    'late guest response cannot overwrite another accepted account',
    () async {
      final repo = GuestAccounts()..pending = Completer<PlayerProfile>();
      final account = AccountController(repo);
      await account.start();
      final operation = account.continueAsGuest();
      repo.emit(
        const PlayerProfile(userId: 'other', googleAccount: true, metadata: {}),
      );
      repo.pending!.complete(guest);
      await operation;
      expect(account.identity, 'other');
      expect(account.guest, false);
      account.dispose();
      await repo.dispose();
    },
  );
  test(
    'linking launches OAuth while retaining guest until verified callback',
    () async {
      final repo = GuestAccounts(guest);
      final account = AccountController(repo);
      await account.start();
      await account.login();
      expect(repo.links, 1);
      expect(repo.logins, 0);
      expect(account.guest, true);
      expect(account.waitingForGoogle, true);
      account.cancelLoginWait();
      await account.login(useExistingAccount: true);
      expect(repo.logins, 1);
      expect(account.guest, true);
      repo.emit(linked);
      expect(account.googleAccount, true);
      expect(account.waitingForGoogle, false);
      account.dispose();
      await repo.dispose();
    },
  );
  test('anonymous auth stays unlinked even with spoofed Google metadata', () {
    final user = User(
      id: 'g',
      appMetadata: const {'provider': 'google'},
      userMetadata: const {'provider': 'google'},
      aud: 'authenticated',
      createdAt: '2026-11-20T00:00:00Z',
      isAnonymous: true,
    );
    final p = SupabaseAccountRepository.profileOf(user)!;
    expect(p.anonymous, true);
    expect(p.googleAccount, false);
  });
  test(
    'Supabase guest adapter creates then reuses anonymous session',
    () async {
      var requests = 0;
      final user = User(
        id: 'g',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-11-20T00:00:00Z',
        isAnonymous: true,
      );
      final client = SupabaseClient(
        'https://example.test',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests++;
          expect(request.url.path, '/auth/v1/signup');
          return http.Response(
            jsonEncode({
              'access_token': 'test.token.value',
              'refresh_token': 'local-only',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': user.toJson(),
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final repo = SupabaseAccountRepository(client);
      expect((await repo.signInAsGuest()).anonymous, true);
      expect((await repo.signInAsGuest()).userId, 'g');
      expect(requests, 1);
      await client.dispose();
    },
  );
  testWidgets('login offers guest path and admits it without ProfilePage', (
    tester,
  ) async {
    final repo = GuestAccounts();
    final account = AccountController(repo);
    await account.start();
    await tester.pumpWidget(
      AccountApplication(account: account, home: const Text('ARENA MENU')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('continue-guest')));
    await tester.tap(find.byKey(const ValueKey('continue-guest')));
    await tester.pumpAndSettle();
    expect(find.text('ARENA MENU'), findsOneWidget);
    expect(find.byType(ProfilePage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    account.dispose();
    await repo.dispose();
  });
  testWidgets('linking same UID clears guest routes and opens Google setup', (
    tester,
  ) async {
    final repo = GuestAccounts(guest);
    final account = AccountController(repo);
    await account.start();
    await tester.pumpWidget(
      AccountApplication(
        account: account,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('GUEST ROUTE')),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    repo.emit(
      const PlayerProfile(
        userId: 'guest',
        googleAccount: true,
        metadata: {'full_name': 'Nama Google'},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('GUEST ROUTE'), findsNothing);
    expect(find.byType(ProfilePage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    account.dispose();
    await repo.dispose();
  });
  testWidgets(
    'guest details show notice and never show stats or private controls',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfileDetailsPanel(
                repository: GuestProfiles(),
                userId: 'g',
                gameId: 'room',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Pengguna belum menautkan akun Google.'),
        findsOneWidget,
      );
      expect(find.text('Statistik pertandingan'), findsNothing);
      expect(find.text('999'), findsNothing);
      expect(find.text('Pasang gelar'), findsNothing);
      expect(find.text('Keluar akun'), findsNothing);
      expect(find.byType(GoogleLogo), findsNothing);
    },
  );
  testWidgets(
    'guest account page offers linking without avatar editor on small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = GuestAccounts(guest);
      final account = AccountController(repo);
      await account.start();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: ProfilePage(account: account),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bermain sebagai tamu'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-nickname')), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('link-google')));
      await tester.tap(find.byKey(const ValueKey('link-google')));
      await tester.pumpAndSettle();
      expect(repo.links, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      account.dispose();
      await repo.dispose();
    },
  );
  testWidgets(
    'linked badge has Google G and guest badge has only guest marker',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Row(
            children: [
              AccountStatusBadge(linked: true),
              AccountStatusBadge(linked: false),
            ],
          ),
        ),
      );
      expect(find.byType(GoogleLogo), findsOneWidget);
      expect(find.byTooltip('Terhubung ke Google'), findsOneWidget);
      expect(find.byTooltip('Belum menautkan akun Google'), findsOneWidget);
    },
  );
  testWidgets('roster badges retry on member change and unknown is not guest', (
    tester,
  ) async {
    var loads = 0;
    Future<Map<String, RoomAccountProfile>> load(String id) async {
      loads++;
      return const {
        'a': RoomAccountProfile(userId: 'a', nickname: 'A', googleLinked: true),
        'b': RoomAccountProfile(
          userId: 'b',
          nickname: 'B',
          googleLinked: false,
        ),
      };
    }

    Widget frame(List<String> ids) => MaterialApp(
      home: RoomAccountStatus(
        gameId: 'room',
        playerIds: ids,
        loader: load,
        builder: (links) => Text(links.containsKey('a') ? 'known' : 'unknown'),
      ),
    );
    await tester.pumpWidget(frame(['a']));
    await tester.pumpAndSettle();
    expect(loads, 1);
    await tester.pumpWidget(frame(['a']));
    await tester.pumpAndSettle();
    expect(loads, 1);
    await tester.pumpWidget(frame(['a', 'b']));
    await tester.pumpAndSettle();
    expect(loads, 2);
  });
}
