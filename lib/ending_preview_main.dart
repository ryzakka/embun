import 'package:flutter/material.dart';
import 'data/asset_catalog.dart';
import 'data/medal_claims.dart';
import 'data/profile_repository.dart';
import 'features/account/medal_claim_scope.dart';
import 'features/account/profile_details_page.dart';
import 'features/common/ornate.dart';
import 'features/table/final_screen.dart';

/// Explicit offline preview. Never imported by the production entry point.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AssetCatalog.load();
  runApp(const EndingPreviewApp());
}

const previewNames = [
  'Ayu',
  'Bima',
  'Citra',
  'Damar',
  'Elang',
  'Farah',
  'Galih',
  'Hana',
];
const previewAccounts = <String, RoomAccountProfile>{
  'p0': RoomAccountProfile(
    userId: 'p0',
    nickname: 'Ayu',
    googleLinked: true,
    avatarId: 'penjaga_hayu',
    title: 'Mata Elang',
    medalsAvailable: true,
    medalIds: ['penjaga_desa_1', 'jejak_pengelana_1'],
  ),
  'p1': RoomAccountProfile(
    userId: 'p1',
    nickname: 'Bima',
    googleLinked: true,
    avatarId: 'penjaga_hayu',
    title: 'Dermawan Hayu',
    medalsAvailable: true,
    medalIds: ['penjaga_desa_5', 'penguasa_bisikan_2', 'jejak_pengelana_6'],
  ),
  'p2': RoomAccountProfile(
    userId: 'p2',
    nickname: 'Citra',
    googleLinked: true,
    avatarId: 'penjaga_hayu',
    medalsAvailable: true,
    medalIds: ['penjaga_desa_3', 'jejak_pengelana_4'],
  ),
  'p3': RoomAccountProfile(
    userId: 'p3',
    nickname: 'Damar',
    googleLinked: true,
    avatarId: 'penjaga_hayu',
    medalsAvailable: true,
    medalIds: ['jejak_pengelana_2'],
  ),
  'p4': RoomAccountProfile(
    userId: 'p4',
    nickname: 'Elang',
    googleLinked: true,
    avatarId: 'penjaga_hayu',
    medalsAvailable: true,
    medalIds: ['penjaga_desa_7', 'jejak_pengelana_8'],
  ),
  'p5': RoomAccountProfile(
    userId: 'p5',
    nickname: 'Farah',
    googleLinked: true,
    avatarId: 'penjaga_hayu',
    medalsAvailable: true,
    medalIds: ['penjaga_desa_2'],
  ),
  'p6': RoomAccountProfile(
    userId: 'p6',
    nickname: 'Galih',
    googleLinked: true,
    avatarId: 'penjaga_hayu',
    title: 'Dalang Kabut',
    medalsAvailable: true,
    medalIds: ['penguasa_bisikan_7', 'jejak_pengelana_8'],
  ),
  'p7': RoomAccountProfile(userId: 'p7', nickname: 'Hana', googleLinked: false),
};

class _Profiles implements ProfileRepository {
  @override
  Future<ProfileDetails> load({
    required String userId,
    String? gameId,
    int offset = 0,
  }) async {
    final p = previewAccounts[userId]!;
    return ProfileDetails(
      userId: userId,
      nickname: p.nickname,
      avatarId: p.avatarId ?? 'penjaga_hayu',
      title: p.title,
      completed: 12,
      wargaWins: 10,
      terbisikWins: 0,
      history: const [],
      hasMore: false,
      googleLinked: p.googleLinked,
    );
  }

  @override
  Future<void> equipTitle(String title) async {}
  @override
  Future<void> requestDeletion() async {}
}

class _Receipts implements MedalReceiptRepository {
  final _claimed = <String>{'penjaga_desa_1', 'jejak_pengelana_1'};
  @override
  Future<MedalReceipts> load(String userId) async =>
      MedalReceipts(initialized: true, claimed: {..._claimed});
  @override
  Future<void> save(
    String userId,
    Set<String> ids, {
    bool initialize = false,
  }) async => _claimed.addAll(ids);
}

class EndingPreviewApp extends StatefulWidget {
  const EndingPreviewApp({super.key, this.reduceMotion = false});
  final bool reduceMotion;
  @override
  State<EndingPreviewApp> createState() => _EndingPreviewAppState();
}

class _EndingPreviewAppState extends State<EndingPreviewApp> {
  final _profiles = _Profiles();
  late final _claims = MedalClaimsController(
    userId: 'p0',
    profiles: _profiles,
    receipts: _Receipts(),
  );
  int _revision = 0;
  late final _secrets = Future.value({
    for (var i = 0; i < previewNames.length; i++)
      'p$i': <String, dynamic>{
        'role': i >= 6 ? 'antagonis' : 'warga',
        'dark_seed': i,
      },
  });
  late final _recap = Future<Map<String, dynamic>?>.value({
    'offerings': [
      for (var day = 1; day <= 4; day++)
        for (var i = 0; i < previewNames.length; i++)
          if (i != 3 || day < 3)
            {'user_id': 'p$i', 'card_id': i >= 6 ? 'red' : 'green', 'day': day},
    ],
    'purchases': [
      for (var day = 1; day <= 3; day++)
        for (var i = 0; i < previewNames.length; i++)
          {
            'user_id': 'p$i',
            'card_id': i >= 6 ? 'red' : 'green',
            'day': day,
            'bonus': i == 3 && day == 2,
          },
    ],
    'votes': [
      for (var day = 1; day <= 3; day++)
        for (var i = 0; i < previewNames.length; i++)
          {
            'user_id': 'p$i',
            'day': day,
            'target_id': i == 3
                ? null
                : i >= 6
                ? 'p0'
                : day == 1
                ? 'p1'
                : 'p6',
            'weight': i == 0 ? 2 : 1,
          },
    ],
  });
  @override
  void dispose() {
    _claims.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = protagonistStems();
    return MedalClaimScope(
      controller: _claims,
      child: MaterialApp(
        theme: embunTheme(),
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: widget.reduceMotion),
          child: Banner(
            message: 'PRATINJAU LOKAL',
            location: BannerLocation.topEnd,
            child: child!,
          ),
        ),
        home: Builder(
          builder: (context) => FinalResultScreen(
            key: ValueKey(_revision),
            wargaMenang: true,
            leaves: 30,
            day: 4,
            endReason: 'daun_penuh',
            myId: 'p0',
            players: [
              for (var i = 0; i < previewNames.length; i++)
                {
                  'user_id': 'p$i',
                  'name': previewNames[i],
                  'character_card': cards.isEmpty
                      ? 'default'
                      : cards[i % cards.length],
                  'strikes': i == 3 ? 2 : 0,
                },
            ],
            defs: const {
              'green': {'side': 'warga', 'name': 'Persembahan Hayu', 'cost': 3},
              'red': {
                'side': 'antagonis',
                'name': 'Persembahan Kabut',
                'cost': 4,
              },
            },
            abilityDefs: const {},
            usernames: {
              for (var i = 0; i < previewNames.length; i++)
                'p$i': previewNames[i],
            },
            secrets: _secrets,
            recap: _recap,
            accountProfiles: previewAccounts,
            detailsBuilder: (_) => const Text(
              'Catatan contoh. Pratinjau ini tidak terhubung ke Supabase.',
            ),
            onViewProfile: (id) => showPlayerProfile(
              context,
              gameId: 'preview-room',
              userId: id,
              repository: _profiles,
            ),
            onExit: () => setState(() => _revision++),
          ),
        ),
      ),
    );
  }
}
