// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/data/profile_repository.dart';
import '../lib/features/account/player_account_avatar.dart';
import '../lib/features/account/profile_avatar.dart';
import '../lib/features/lobby/waiting_room_view.dart';
import '../lib/features/table/chat_sheet.dart';
import '../lib/features/table/final_screen.dart';
import '../lib/features/common/art.dart';
import '../lib/features/preview/preview_session.dart';

const roster = <String, RoomAccountProfile>{
  'a': RoomAccountProfile(
    userId: 'a',
    nickname: 'Ayu Lestari',
    googleLinked: true,
    avatarId: 'peramu_bunga',
  ),
  'b': RoomAccountProfile(
    userId: 'b',
    nickname: 'Budi Santoso',
    googleLinked: false,
  ),
};
const players = <Map<String, dynamic>>[
  {
    'user_id': 'a',
    'name': 'Ayu Lestari',
    'character_card': 'pria-petanipadi',
    'ready': true,
    'strikes': 0,
  },
  {
    'user_id': 'b',
    'name': 'Budi Santoso',
    'character_card': 'pria-peternaktelur',
    'ready': false,
    'strikes': 0,
  },
];

class ChatFixture extends PreviewSession {
  @override
  String get myId => 'a';
  @override
  Stream<List<Map<String, dynamic>>> chat(
    String gameId, {
    bool terbisik = false,
  }) => Stream.value([
    {
      'id': '1',
      'user_id': 'b',
      'name': 'Budi Santoso',
      'body': 'Halo desa',
      'day': 1,
      'created_at': '2026-11-20T10:00:00Z',
    },
  ]);
}

void main() {
  for (final tab in ['Peringkat', 'Gelar']) {
    testWidgets('ending $tab identifies the player with an account avatar', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: FinalResultScreen(
            wargaMenang: true,
            leaves: 30,
            day: 3,
            players: players,
            defs: const {
              'baik': {'side': 'warga', 'name': 'Kartu Baik'},
            },
            abilityDefs: const {},
            usernames: const {'a': 'Ayu Lestari', 'b': 'Budi Santoso'},
            accountProfiles: roster,
            myId: 'b',
            secrets: Future.value({
              'a': {'role': 'warga'},
              'b': {'role': 'warga'},
            }),
            recap: Future.value({
              'offerings': [
                {'day': 1, 'user_id': 'b', 'card_id': 'baik'},
              ],
              'purchases': [],
              'votes': [],
            }),
            detailsBuilder: (_) => const SizedBox.shrink(),
            onExit: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.ensureVisible(find.text(tab).last);
      await tester.tap(find.text(tab).last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(PlayerAccountAvatar), findsWidgets);
      expect(find.text('BS'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  test('initials use first and last name, with safe empty fallback', () {
    expect(accountInitials(' Budi   Santoso '), 'BS');
    expect(accountInitials('ayu'), 'A');
    expect(accountInitials('Budi Agus Santoso'), 'BS');
    expect(accountInitials(''), '?');
    expect(accountInitials('\u202EBudi\u202C Santoso'), 'BS');
    expect(accountInitials('Élodie Martin'), 'ÉM');
  });
  testWidgets('guest initials ignore an avatar ID and have no profile image', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PlayerAccountAvatar(
          name: 'Budi Santoso',
          googleLinked: false,
          avatarId: 'peramu_bunga',
        ),
      ),
    );
    expect(find.text('BS'), findsOneWidget);
    expect(find.byType(ProfileAvatar), findsNothing);
  });
  testWidgets('linked account renders chosen avatar and G badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PlayerAccountAvatar(
          name: 'Ayu Lestari',
          googleLinked: true,
          avatarId: 'peramu_bunga',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).avatarId,
      'peramu_bunga',
    );
    expect(find.byTooltip('Terhubung ke Google'), findsOneWidget);
  });
  testWidgets(
    'waiting-room row uses account avatars and initials, separate from character selection',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? opened;
      var edited = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: WaitingRoomView(
              code: 'ABC123',
              isPublic: false,
              antagonistCount: 1,
              hostId: 'a',
              viewerId: 'a',
              players: players,
              accountProfiles: roster,
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
                opened = id;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PlayerAvatar), findsNothing);
      expect(find.text('BS'), findsOneWidget);
      expect(
        tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).avatarId,
        'peramu_bunga',
      );
      await tester.ensureVisible(find.byType(PlayerAccountAvatar).last);
      await tester.tap(find.byType(PlayerAccountAvatar).last);
      expect(opened, 'b');
      expect(edited, false);
      expect(tester.takeException(), isNull);
    },
  );
  for (final lobby in [true, false]) {
    testWidgets(
      'chat ${lobby ? 'lobby uses initials' : 'in play keeps character portrait even with account data'}',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: ChatPanel(
                repo: ChatFixture(),
                gameId: 'room',
                players: players,
                lobby: lobby,
                accountProfiles: roster,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Halo desa'), findsOneWidget);
        expect(
          find.byType(PlayerAccountAvatar),
          lobby ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(PlayerAvatar),
          lobby ? findsNothing : findsOneWidget,
        );
        if (lobby) expect(find.text('BS'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'ending player list presents account names and character names separately',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: FinalResultScreen(
            wargaMenang: true,
            leaves: 30,
            day: 3,
            players: const [
              {
                'user_id': 'b',
                'name': 'Peternak Telur',
                'character_card': 'pria-peternaktelur',
                'strikes': 0,
              },
            ],
            defs: const {},
            abilityDefs: const {},
            usernames: const {'b': 'Budi Santoso'},
            accountProfiles: roster,
            myId: 'b',
            secrets: Future.value({
              'b': {'role': 'warga'},
            }),
            recap: Future.value(null),
            detailsBuilder: (_) => const SizedBox.shrink(),
            onExit: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.ensureVisible(find.text('Pemain').last);
      await tester.tap(find.text('Pemain').last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('BS'), findsOneWidget);
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.textContaining('Peternak Telur'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
