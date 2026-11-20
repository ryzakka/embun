// Portable across destination package names.
// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/account_preview_main.dart';
import '../lib/data/account_controller.dart';
import '../lib/data/player_profile.dart';
import '../lib/data/profile_avatar_catalog.dart';
import '../lib/data/profile_repository.dart';
import '../lib/features/account/account_pages.dart';
import '../lib/features/account/profile_details_page.dart';
import '../lib/features/account/profile_preview_repository.dart';
import '../lib/features/lobby/waiting_room_view.dart';
import '../lib/features/table/final_screen.dart';

class ControlledProfiles implements ProfileRepository {
  final sample = PreviewProfileRepository();
  bool fail = false, failAction = false;
  int loads = 0, requests = 0;
  final offsets = <int>[];
  Completer<ProfileDetails>? pending;
  @override
  Future<ProfileDetails> load({
    required String userId,
    String? gameId,
    int offset = 0,
  }) async {
    loads++;
    offsets.add(offset);
    if (fail) throw StateError('offline');
    if (pending != null) return pending!.future;
    final value = await sample.load(userId: userId);
    return ProfileDetails(
      userId: userId,
      nickname: value.nickname,
      avatarId: value.avatarId,
      title: value.title,
      completed: 3,
      wargaWins: 1,
      terbisikWins: 1,
      hasMore: offset == 0,
      deletionRequest: value.deletionRequest,
      history: offset == 0
          ? value.history
          : [
              ProfileMatch(
                id: 'page-2',
                finishedAt: DateTime(2026),
                side: 'antagonis',
                won: true,
                days: 3,
              ),
            ],
    );
  }

  @override
  Future<void> equipTitle(String title) async {
    if (failAction) throw StateError('offline');
    await sample.equipTitle(title);
  }

  @override
  Future<void> requestDeletion() async {
    requests++;
    if (failAction) throw StateError('offline');
    await sample.requestDeletion();
  }
}

Widget frame(Widget child) => MaterialApp(
  theme: ThemeData.dark(),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test('catalog contains ten distinct PNGs and retains legacy preferences', () {
    expect(profileAvatars.length, 10);
    expect(profileAvatars.values.map((e) => e.$1).toSet().length, 10);
    for (final id in [...profileAvatars.keys, 'leaf', 'moon']) {
      final p = PlayerProfile(
        userId: 'me',
        googleAccount: true,
        metadata: {'embun_avatar': id},
      );
      expect(p.avatarId, id);
    }
    expect(
      const PlayerProfile(
        userId: 'me',
        googleAccount: true,
        metadata: {'embun_avatar': '../invalid'},
      ).avatarId,
      'penjaga_hayu',
    );
  });

  test(
    'server JSON preserves role, outcome, counts and private optional fields',
    () {
      final p = ProfileDetails.fromJson({
        'user_id': 'a',
        'nickname': 'Dhimas',
        'avatar_id': 'penjaga_hayu',
        'title': 'Mata Elang',
        'completed': 1,
        'warga_wins': 0,
        'terbisik_wins': 1,
        'has_more': false,
        'history': [
          {
            'game_id': 'g',
            'finished_at': '2026-11-20T10:00:00Z',
            'side': 'antagonis',
            'won': true,
            'days': 3,
          },
        ],
      });
      expect(p.terbisikWins, 1);
      expect(p.history.single.won, true);
      expect(p.history.single.side, 'antagonis');
      expect(p.deletionRequest, isNull);
    },
  );

  test('all ten avatar images are actually bundled', () async {
    for (final id in profileAvatars.keys) {
      final path = await profileAvatarAsset(rootBundle, id);
      expect(path, isNotNull);
      final data = await rootBundle.load(path!);
      expect(data.lengthInBytes, greaterThan(100));
    }
  });

  testWidgets(
    'public profile has statistics and history, with no account controls',
    (tester) async {
      await tester.pumpWidget(
        frame(
          ProfileDetailsPanel(
            repository: PreviewProfileRepository(),
            userId: 'other',
            gameId: 'room',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pemain Contoh'), findsOneWidget);
      expect(find.text('Menang · Warga Desa'), findsWidgets);
      expect(find.text('Kalah · Si Terbisik'), findsOneWidget);
      expect(find.text('Pasang gelar'), findsNothing);
      expect(find.text('Keluar akun'), findsNothing);
      expect(find.textContaining('Email Google'), findsNothing);
      expect(find.text('Minta penghapusan akun / data'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'load failure shows retry, never substitutes fake zero statistics',
    (tester) async {
      final repo = ControlledProfiles()..fail = true;
      await tester.pumpWidget(
        frame(ProfileDetailsPanel(repository: repo, userId: 'me', owner: true)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Statistik pertandingan'), findsNothing);
      expect(find.text('Coba lagi'), findsOneWidget);
      repo.fail = false;
      await tapVisible(tester, find.text('Coba lagi'));
      expect(repo.loads, 2);
      expect(find.text('Statistik pertandingan'), findsOneWidget);
    },
  );

  testWidgets('pagination appends next history page', (tester) async {
    final repo = ControlledProfiles();
    await tester.pumpWidget(
      frame(ProfileDetailsPanel(repository: repo, userId: 'me')),
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Muat riwayat berikutnya'));
    expect(repo.offsets, [0, 2]);
    expect(find.text('Kalah · Si Terbisik'), findsOneWidget);
    expect(find.text('Menang · Si Terbisik'), findsWidgets);
    expect(find.text('Muat riwayat berikutnya'), findsNothing);
  });

  testWidgets('equipped title saves and is confirmed by repository reload', (
    tester,
  ) async {
    final repo = ControlledProfiles();
    await tester.pumpWidget(
      frame(ProfileDetailsPanel(repository: repo, userId: 'me', owner: true)),
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.text('Mata Elang').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Pasang gelar'));
    expect(repo.sample.title, 'Mata Elang');
    expect(repo.loads, 2);
    expect(find.text('Gelar berhasil dipasang.'), findsOneWidget);
  });

  testWidgets(
    'deletion cancellation does not create request; confirmed repeat is disabled',
    (tester) async {
      final repo = ControlledProfiles();
      await tester.pumpWidget(
        frame(ProfileDetailsPanel(repository: repo, userId: 'me', owner: true)),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Minta penghapusan akun / data'));
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(repo.requests, 0);
      await tapVisible(tester, find.text('Minta penghapusan akun / data'));
      await tester.tap(find.text('Ajukan permintaan'));
      await tester.pumpAndSettle();
      expect(repo.requests, 1);
      expect(
        find.textContaining('Nomor permintaan: CONTOH-LOKAL'),
        findsOneWidget,
      );
      expect(find.text('Minta penghapusan akun / data'), findsNothing);
    },
  );

  testWidgets(
    'failed deletion request stays retryable and never claims success',
    (tester) async {
      final repo = ControlledProfiles()..failAction = true;
      await tester.pumpWidget(
        frame(ProfileDetailsPanel(repository: repo, userId: 'me', owner: true)),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Minta penghapusan akun / data'));
      await tester.tap(find.text('Ajukan permintaan'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Belum berhasil disimpan'), findsOneWidget);
      expect(find.textContaining('Nomor permintaan:'), findsNothing);
    },
  );

  testWidgets('disposed pending load does not update unmounted screen', (
    tester,
  ) async {
    final repo = ControlledProfiles()..pending = Completer<ProfileDetails>();
    await tester.pumpWidget(
      frame(ProfileDetailsPanel(repository: repo, userId: 'me')),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    repo.pending!.complete(await repo.sample.load(userId: 'me'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('ten avatar assets can be selected and saved with nickname', (
    tester,
  ) async {
    final repo = PreviewAccountRepository();
    final account = AccountController(repo);
    await account.start();
    await account.login();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: ProfilePage(account: account, firstSetup: true),
      ),
    );
    await tester.pumpAndSettle();
    for (final id in profileAvatars.keys) {
      expect(find.byKey(ValueKey('avatar-$id')), findsOneWidget);
    }
    await tapVisible(tester, find.byKey(const ValueKey('avatar-perawat_desa')));
    await tester.enterText(
      find.byKey(const ValueKey('profile-nickname')),
      'Dhimas',
    );
    await tapVisible(tester, find.byKey(const ValueKey('save-profile')));
    expect(account.profile!.avatarId, 'perawat_desa');
    expect(account.profile!.nickname, 'Dhimas');
    await tester.pumpWidget(const SizedBox.shrink());
    account.dispose();
    await repo.dispose();
  });

  testWidgets(
    'small screen with large text can scroll through profile and public sheet',
    (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final profiles = PreviewProfileRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showPlayerProfile(
                  context,
                  gameId: 'room',
                  userId: 'other',
                  repository: profiles,
                ),
                child: const Text('Lihat profil'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Lihat profil'));
      await tester.pumpAndSettle();
      expect(find.text('Profil pemain'), findsOneWidget);
      await tester.ensureVisible(find.text('Kalah · Si Terbisik'));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Tutup profil'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'waiting room profile action keeps character editing separate on phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? selected;
      var edited = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: WaitingRoomView(
              googleLinks: const {'me': true, 'other': false},
              code: 'ABC123',
              isPublic: false,
              antagonistCount: 1,
              hostId: 'me',
              viewerId: 'me',
              players: const [
                {
                  'user_id': 'me',
                  'name': 'Nama Panjang Pemain Sendiri',
                  'ready': false,
                  'character_card': 'default',
                },
                {
                  'user_id': 'other',
                  'name': 'Pemain Lain',
                  'ready': true,
                  'character_card': 'default',
                },
              ],
              chatMessages: const Stream.empty(),
              chat: const SizedBox(),
              onVisibilityChanged: (_) async {},
              onReady: (_) async {},
              onStart: () async {},
              onLeave: () async {},
              onEditCharacter: (_) async {
                edited = true;
              },
              onViewProfile: (id) {
                selected = id;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byTooltip('Lihat profil pemain').first);
      expect(selected, 'me');
      expect(find.byTooltip('Terhubung ke Google'), findsOneWidget);
      expect(find.byTooltip('Belum menautkan akun Google'), findsOneWidget);
      expect(edited, false);
      await tapVisible(tester, find.byTooltip('Ganti karakter'));
      expect(edited, true);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('own profile remains usable at 320 pixels and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = PreviewAccountRepository();
    final account = AccountController(repo);
    await account.start();
    await account.login();
    await account.save('Dhimas', 'penjaga_hayu');
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: ProfilePage(
          account: account,
          detailsRepository: PreviewProfileRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Gelar yang dipasang'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Minta penghapusan akun / data'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('contoh@example.test'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    account.dispose();
    await repo.dispose();
  });

  testWidgets('ending player tab exposes read-only profile callback', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: FinalResultScreen(
          googleLinks: const {'me': true},
          wargaMenang: true,
          leaves: 30,
          day: 3,
          players: const [
            {
              'user_id': 'me',
              'name': 'Nama Tokoh',
              'character_card': 'default',
              'strikes': 0,
            },
          ],
          defs: const {},
          abilityDefs: const {},
          usernames: const {'me': 'Dhimas'},
          myId: 'me',
          secrets: Future.value({
            'me': {'role': 'warga'},
          }),
          recap: Future.value(null),
          detailsBuilder: (_) => const SizedBox.shrink(),
          onExit: () {},
          onViewProfile: (id) {
            selected = id;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.text('Pemain').last);
    await tester.tap(find.text('Pemain').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.byTooltip('Lihat profil pemain'));
    await tester.tap(find.byTooltip('Lihat profil pemain'));
    expect(selected, 'me');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
