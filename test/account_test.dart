// Portable patch: the destination project's package name may differ.
// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// The app already depends on Supabase, which supplies this HTTP test client.
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../lib/account_preview_main.dart';
import '../lib/data/account_controller.dart';
import '../lib/data/player_profile.dart';
import '../lib/data/supabase_account_repository.dart';
import '../lib/features/account/account_app.dart';
import '../lib/features/account/account_pages.dart';
import '../lib/features/lobby/room_entry_view.dart';
import '../lib/features/lobby/public_rooms_page.dart';
import '../lib/features/preview/preview_session.dart';

PlayerProfile profile({
  String id = 'a',
  String name = 'Dhimas',
  bool complete = true,
  bool google = true,
}) => PlayerProfile(
  userId: id,
  googleAccount: google,
  email: '$id@example.test',
  metadata: {
    'full_name': 'Nama Google',
    if (complete) ...{
      'embun_nickname': name,
      'embun_avatar': 'leaf',
      'embun_profile_version': 1,
    },
  },
);

class FakeAccounts implements AccountRepository {
  FakeAccounts([this.value]);
  PlayerProfile? value;
  final events = StreamController<PlayerProfile?>.broadcast(sync: true);
  Completer<PlayerProfile?>? restoreWait;
  Completer<bool>? launchWait;
  Completer<PlayerProfile>? saveWait;
  bool launched = true, failSave = false, failLogout = false;
  int launches = 0, saves = 0;
  @override
  PlayerProfile? get current => value;
  @override
  Stream<PlayerProfile?> get changes => events.stream;
  void emit(PlayerProfile? p) {
    value = p;
    events.add(p);
  }

  @override
  Future<PlayerProfile?> restore() async =>
      restoreWait == null ? value : await restoreWait!.future;
  @override
  Future<bool> signInWithGoogle() async {
    launches++;
    return launchWait == null ? launched : await launchWait!.future;
  }

  @override
  Future<PlayerProfile> saveProfile({
    required String userId,
    required String nickname,
    required String avatarId,
  }) async {
    saves++;
    if (failSave) throw StateError('offline');
    if (saveWait != null) return saveWait!.future;
    final p = PlayerProfile(
      userId: userId,
      googleAccount: true,
      metadata: {
        ...?value?.metadata,
        'embun_nickname': nickname,
        'embun_avatar': avatarId,
        'embun_profile_version': 1,
      },
    );
    emit(p);
    return p;
  }

  @override
  Future<void> signOut() async {
    if (failLogout) throw StateError('offline');
    emit(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('profile model', () {
    test('Google name seeds once, saved nickname wins on later sign-ins', () {
      expect(profile(complete: false).initialNickname, 'Nama Google');
      expect(profile().initialNickname, 'Dhimas');
      expect(profile().complete, isTrue);
      expect(profile(google: false).complete, isFalse);
    });
    test(
      'nickname validates visible length, whitespace and control characters',
      () {
        expect(nicknameError('   '), isNotNull);
        expect(nicknameError('Dhi\nmas'), isNotNull);
        expect(nicknameError('Dhi\u202Emas'), isNotNull);
        expect(nicknameError('a' * 21), isNotNull);
        expect(nicknameError('🌿' * 20), isNull);
        expect(normalizeNickname('  Dhi   Mas  '), 'Dhi Mas');
        expect(
          PlayerProfile(
            userId: 'a',
            googleAccount: true,
            metadata: {'full_name': 'a' * 30},
          ).initialNickname.length,
          20,
        );
      },
    );
    test('redirect keeps deployment path and removes OAuth codes/tokens', () {
      expect(
        webAccountRedirect(
          Uri.parse('https://embun.example/game/?code=secret#token=hidden'),
        ).toString(),
        'https://embun.example/game/',
      );
      expect(
        webAccountRedirect(Uri.parse('http://localhost:7357/')).toString(),
        'http://localhost:7357/',
      );
      expect(
        () => webAccountRedirect(Uri.parse('javascript:alert(1)')),
        throwsArgumentError,
      );
    });
    test('identity trust uses provider identity, never editable metadata', () {
      User user({
        bool anonymous = false,
        Map<String, dynamic> app = const {},
      }) => User(
        id: 'a',
        appMetadata: app,
        userMetadata: {'provider': 'google', 'embun_nickname': 'Fake'},
        aud: 'authenticated',
        createdAt: '2026-01-01',
        isAnonymous: anonymous,
      );
      expect(
        SupabaseAccountRepository.profileOf(user())!.googleAccount,
        isFalse,
      );
      expect(
        SupabaseAccountRepository.profileOf(
          user(app: {'provider': 'google'}),
        )!.googleAccount,
        isTrue,
      );
      expect(
        SupabaseAccountRepository.profileOf(
          user(anonymous: true, app: {'provider': 'google'}),
        )!.googleAccount,
        isFalse,
      );
    });
  });

  group('account flow', () {
    late FakeAccounts repo;
    late AccountController account;
    setUp(() {
      repo = FakeAccounts();
      account = AccountController(repo);
    });
    tearDown(() async {
      account.dispose();
      await repo.events.close();
    });

    test('restored complete profile is ready without another login', () async {
      repo.value = profile();
      await account.start();
      expect(account.ready, isTrue);
      expect(repo.launches, 0);
      expect(account.restoring, isFalse);
    });
    test('Google success still requires profile setup once', () async {
      await account.start();
      repo.emit(profile(complete: false));
      expect(account.googleAccount, isTrue);
      expect(account.ready, isFalse);
      expect(await account.save('  Dhi   Mas  ', 'water'), isTrue);
      expect(account.ready, isTrue);
      expect(account.profile!.nickname, 'Dhi Mas');
      expect(account.profile!.avatarId, 'water');
    });
    test(
      'browser launch waits for auth; cancellation and retry are possible',
      () async {
        await account.start();
        await account.login();
        expect(account.waitingForGoogle, isTrue);
        expect(account.ready, isFalse);
        account.cancelLoginWait();
        expect(account.waitingForGoogle, isFalse);
        await account.login();
        expect(repo.launches, 2);
        repo.emit(profile());
        expect(account.ready, isTrue);
        expect(account.waitingForGoogle, isFalse);
      },
    );
    testWidgets('pending OAuth times out without falsely logging in', (
      tester,
    ) async {
      final timed = AccountController(
        repo,
        loginWait: const Duration(seconds: 2),
      );
      await timed.start();
      await timed.login();
      await tester.pump(const Duration(seconds: 3));
      expect(timed.waitingForGoogle, isFalse);
      expect(timed.ready, isFalse);
      expect(timed.error, isNotNull);
      timed.dispose();
    });
    test(
      'failed launch is recoverable and duplicate taps open one browser',
      () async {
        await account.start();
        repo.launched = false;
        await account.login();
        expect(account.error, isNotNull);
        expect(account.busy, isFalse);
        repo.launchWait = Completer<bool>();
        final pending = account.login();
        await account.login();
        expect(repo.launches, 2);
        repo.launchWait!.complete(true);
        await pending;
        expect(account.waitingForGoogle, isTrue);
      },
    );
    test(
      'new auth event wins over a delayed restore of another account',
      () async {
        repo.restoreWait = Completer<PlayerProfile?>();
        final pending = account.start();
        repo.emit(profile(id: 'b'));
        repo.restoreWait!.complete(profile(id: 'a'));
        await pending;
        expect(account.identity, 'b');
      },
    );
    test(
      'failed profile save keeps previous name and can be retried',
      () async {
        repo.value = profile();
        await account.start();
        repo.failSave = true;
        expect(await account.save('Nama Baru', 'sun'), isFalse);
        expect(account.profile!.nickname, 'Dhimas');
        expect(account.error, isNotNull);
        repo.failSave = false;
        expect(await account.save('Nama Baru', 'sun'), isTrue);
      },
    );
    test(
      'old save response cannot overwrite a newly signed-in account',
      () async {
        repo.value = profile();
        await account.start();
        repo.saveWait = Completer<PlayerProfile>();
        final pending = account.save('Lama', 'sun');
        repo.emit(profile(id: 'b', name: 'Baru'));
        repo.saveWait!.complete(profile(name: 'Lama'));
        expect(await pending, isFalse);
        expect(account.identity, 'b');
        expect(account.profile!.nickname, 'Baru');
      },
    );
    test(
      'stream errors are handled without destroying a valid profile',
      () async {
        repo.value = profile();
        await account.start();
        repo.events.addError(StateError('offline'));
        expect(account.ready, isTrue);
        expect(account.error, isNotNull);
      },
    );
    test(
      'logout failure is shown; successful logout clears identity',
      () async {
        repo.value = profile();
        await account.start();
        repo.failLogout = true;
        await account.logout();
        expect(account.ready, isTrue);
        expect(account.error, isNotNull);
        repo.failLogout = false;
        await account.logout();
        expect(account.identity, isNull);
      },
    );
  });

  test('Supabase adapter writes only profile metadata to auth/user', () async {
    final requests = <http.Request>[];
    final user = User(
      id: 'a',
      appMetadata: {'provider': 'google'},
      userMetadata: {'full_name': 'Nama Google', 'unrelated': 'preserved'},
      aud: 'authenticated',
      email: 'a@example.test',
      createdAt: '2026-01-01',
    );
    final client = SupabaseClient(
      'https://account-test.invalid',
      'public-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            ...user.toJson(),
            'user_metadata': {...?user.userMetadata, ...body['data'] as Map},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await client.auth.recoverSession(
      jsonEncode(
        Session(
          accessToken: 'test.token.value',
          refreshToken: 'local-only',
          tokenType: 'bearer',
          user: user,
        ).toJson(),
      ),
    );
    final repo = SupabaseAccountRepository(client);
    final saved = await repo.saveProfile(
      userId: 'a',
      nickname: '  Dhimas  ',
      avatarId: 'moon',
    );
    expect(requests.length, 1);
    expect(requests.single.method, 'PUT');
    expect(requests.single.url.path, '/auth/v1/user');
    expect((jsonDecode(requests.single.body) as Map)['data'], {
      'embun_nickname': 'Dhimas',
      'embun_avatar': 'moon',
      'embun_profile_version': 1,
    });
    expect(saved.nickname, 'Dhimas');
    expect(saved.metadata['unrelated'], 'preserved');
    await expectLater(
      repo.saveProfile(userId: 'b', nickname: 'Other', avatarId: 'leaf'),
      throwsA(isA<AuthException>()),
    );
    expect(requests.length, 1);
    await client.dispose();
  });

  testWidgets('first setup and next visit use saved profile', (tester) async {
    final repo = FakeAccounts();
    final account = AccountController(repo);
    await account.start();
    await tester.pumpWidget(
      AccountApplication(
        account: account,
        home: const Scaffold(body: Text('MENU SIAP')),
      ),
    );
    expect(find.byKey(const ValueKey('google-login')), findsOneWidget);
    repo.emit(profile(complete: false));
    await tester.pumpAndSettle();
    expect(find.text('Kenalan dulu, yuk'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('profile-nickname')),
      'Dhimas',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('save-profile')));
    await tester.tap(find.byKey(const ValueKey('save-profile')));
    await tester.pumpAndSettle();
    expect(find.text('MENU SIAP'), findsOneWidget);
    expect(repo.saves, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    account.dispose();
    final nextVisit = AccountController(repo);
    await nextVisit.start();
    await tester.pumpWidget(
      AccountApplication(
        account: nextVisit,
        home: const Scaffold(body: Text('MENU SIAP')),
      ),
    );
    expect(find.text('MENU SIAP'), findsOneWidget);
    expect(find.byType(ProfilePage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    nextVisit.dispose();
    await repo.events.close();
  });

  testWidgets(
    'token/profile updates keep routes, changing user resets all routes',
    (tester) async {
      final repo = FakeAccounts(profile());
      final account = AccountController(repo);
      await account.start();
      await tester.pumpWidget(
        AccountApplication(
          account: account,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const Scaffold(body: Text('PERTANDINGAN AKUN A')),
                  ),
                ),
                child: const Text('BUKA'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('BUKA'));
      await tester.pumpAndSettle();
      repo.emit(profile(name: 'Nama Baru'));
      await tester.pumpAndSettle();
      expect(find.text('PERTANDINGAN AKUN A'), findsOneWidget);
      repo.emit(profile(id: 'b'));
      await tester.pumpAndSettle();
      expect(find.text('PERTANDINGAN AKUN A'), findsNothing);
      expect(find.text('BUKA'), findsOneWidget);
      await account.logout();
      await tester.pumpAndSettle();
      expect(find.text('BUKA'), findsNothing);
      expect(find.byKey(const ValueKey('google-login')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      account.dispose();
      await repo.events.close();
    },
  );

  testWidgets('login/profile layout supports small screen and large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 600);
    final repo = FakeAccounts();
    final account = AccountController(repo);
    await account.start();
    await tester.pumpWidget(
      AccountApplication(
        account: account,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: const SizedBox.shrink(),
      ),
    );
    expect(tester.takeException(), isNull);
    repo.emit(profile(complete: false));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('save-profile')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('save-profile')).hitTestable(),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    account.dispose();
    await repo.events.close();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('create room skips name slide and keeps remaining five steps', (
    tester,
  ) async {
    final name = TextEditingController(text: 'Dhimas');
    final key = GlobalKey<CreateRoomViewState>();
    String? created;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CreateRoomView(
            key: key,
            nameCtrl: name,
            profileName: 'Dhimas',
            isPublic: true,
            cycles: 4,
            antagonistCount: 1,
            busy: false,
            onVisibilityChanged: (_) {},
            onDurationChanged: (_) {},
            onAntagonistCountChanged: (_) {},
            onCreate: (value) => created = value,
            onBack: () {},
          ),
        ),
      ),
    );
    expect(find.text('Tema kartu karakter'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(key.currentState!.goBackSlide(), isFalse);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Buat Ruangan').hitTestable(), findsWidgets);
    await tester.tap(find.text('Buat Ruangan').last);
    await tester.pump();
    expect(created, 'Dhimas');
    await tester.pumpWidget(const SizedBox.shrink());
    name.dispose();
  });

  testWidgets('join by code displays saved name without editable name field', (
    tester,
  ) async {
    final name = TextEditingController(text: 'Dhimas'),
        code = TextEditingController();
    String? joined;
    await tester.pumpWidget(
      MaterialApp(
        home: PublicRoomsPage(
          repo: PreviewSession(),
          nameCtrl: name,
          profileName: 'Dhimas',
          codeCtrl: code,
          onJoin: (value) async {
            joined = value;
            return 'Tes lokal selesai';
          },
          onCreate: () {},
        ),
      ),
    );
    expect(find.text('Bermain sebagai Dhimas'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'HAYUU');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(joined, 'HAYUU');
    await tester.pumpWidget(const SizedBox.shrink());
    name.dispose();
    code.dispose();
  });

  testWidgets(
    'offline preview can login, edit profile and logout without Supabase',
    (tester) async {
      await tester.pumpWidget(const AccountPreviewApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('google-login')));
      await tester.pumpAndSettle();
      expect(find.byType(ProfilePage), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('profile-nickname')),
        'Pemain Lokal',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('save-profile')));
      await tester.tap(find.byKey(const ValueKey('save-profile')));
      await tester.pumpAndSettle();
      expect(find.text('Halo, Pemain Lokal'), findsOneWidget);
      await tester.tap(find.text('Profilku'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('profile-nickname')),
        'Nama Baru',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('save-profile')));
      await tester.tap(find.byKey(const ValueKey('save-profile')));
      await tester.pumpAndSettle();
      expect(find.text('Halo, Nama Baru'), findsOneWidget);
      await tester.tap(find.text('Keluar akun'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('google-login')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
