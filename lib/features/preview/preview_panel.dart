import 'package:flutter/material.dart';

import '../../data/asset_catalog.dart';
import '../../data/embun_data.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import '../guide/guide_page.dart';
import '../guide/tutorial_page.dart';
import '../lobby/announcements_page.dart';
import '../lobby/lobby_page.dart';
import '../lobby/more_games_sheet.dart';
import '../lobby/public_rooms_page.dart';
import '../prologue/character_pick.dart';
import '../prologue/dark_omen.dart';
import '../prologue/prologue_page.dart';
import '../table/ability_panel.dart';
import '../table/bow_dialog.dart';
import '../table/card_tile.dart';
import '../table/chat_sheet.dart';
import '../table/day_transition.dart';
import '../table/day_view.dart';
import '../table/emote_panel.dart';
import '../table/eviction_verdict_scene.dart';
import '../table/jail_verdict_scene.dart';
import '../table/my_info_sheet.dart';
import '../table/night_plan_dialog.dart';
import '../table/night_scene.dart';
import '../table/offering_transition.dart';
import '../table/parts_strip.dart';
import '../table/player_sheet.dart';
import '../table/table_page.dart';
import '../table/vote_reveal_scene.dart';
import 'preview_catalog.dart';
import 'preview_session.dart';

enum _Screen {
  title('Layar judul'),
  menu('Menu utama'),
  create('Buat ruangan'),
  join('Masuk dengan kode'),
  publicRooms('Ruangan publik'),
  waiting('Ruang tunggu'),
  news('Pengumuman dan pembaruan'),
  settings('Pengaturan suara dan efek visual'),
  otherGames('Gim lainnya'),
  tutorial('Tutorial'),
  rules('Panduan · Cara bermain'),
  characters('Panduan · Karakter'),
  items('Panduan · Kartu item dan filter Hayu'),
  abilities('Panduan · Kemampuan'),
  story('Cerita prolog'),
  shuffle('Kocok kartu karakter'),
  character('Pilih kartu karakter'),
  role('Pengungkapan peran'),
  omen('Peringatan awan gelap'),
  darkFace('Pilih wajah gelap'),
  prologueWait('Menunggu pemain selesai prolog'),
  market('Pasar Pagi · Toko'),
  hand('Meja kartu'),
  merge('Gabung kartu'),
  hall('Balai · Tawaran tukar'),
  research('Pasar Riset'),
  offering('Pilih kartu persembahan'),
  ceremony('Adegan melempar persembahan'),
  effects('Hasil persembahan dan reaksi Hayu'),
  discussion('Musyawarah'),
  voting('Voting · Pilih sasaran'),
  lockedVote('Voting · Suara terkunci'),
  night('Malam · Pilih aksi'),
  jailed('Meja · Dalam kurungan'),
  spectator('Meja · Sudah tersingkir'),
  chat('Obrolan Desa'),
  secretChat('Obrolan Terbisik'),
  emotes('Panel isyarat'),
  player('Detail pemain · Beri embun dan tukar'),
  myInfo('Infoku'),
  ability('Kartu kemampuan biru'),
  card('Detail kartu persembahan'),
  parts('Kondisi bagian Hayu'),
  nightPlan('Rencana serangan malam'),
  bowTarget('Sasaran Busur Terakhir'),
  dawn('Peralihan fajar'),
  offeringIntro('Peralihan ke persembahan'),
  jail('Vonis kurungan'),
  evict('Vonis pengusiran'),
  revealVote('Pembukaan suara'),
  pump('Serangan · Pencurian embun'),
  burn('Serangan · Bakar kartu'),
  theft('Serangan · Curi kartu'),
  mirror('Serangan · Pantulan cermin'),
  shield('Serangan · Perlindungan'),
  bowHit('Serangan · Panah mengenai Terbisik'),
  bowMiss('Serangan · Panah salah sasaran'),
  finalBow('Serangan · Panah penentu'),
  ending('Sinematik akhir · Warga menang'),
  endingDark('Sinematik akhir · Terbisik menang'),
  recap('Rekap dan statistik'),
  cancelled('Permainan dibubarkan');

  const _Screen(this.label);
  final String label;
}

const _sections = [
  (
    'Lobi dan ruangan',
    [
      _Screen.title,
      _Screen.menu,
      _Screen.create,
      _Screen.join,
      _Screen.publicRooms,
      _Screen.waiting,
      _Screen.news,
      _Screen.settings,
      _Screen.otherGames,
    ],
  ),
  (
    'Panduan dan tutorial',
    [
      _Screen.tutorial,
      _Screen.rules,
      _Screen.characters,
      _Screen.items,
      _Screen.abilities,
    ],
  ),
  (
    'Prolog',
    [
      _Screen.story,
      _Screen.shuffle,
      _Screen.character,
      _Screen.role,
      _Screen.omen,
      _Screen.darkFace,
      _Screen.prologueWait,
    ],
  ),
  (
    'Meja dan fase permainan',
    [
      _Screen.market,
      _Screen.hand,
      _Screen.merge,
      _Screen.hall,
      _Screen.research,
      _Screen.offering,
      _Screen.ceremony,
      _Screen.effects,
      _Screen.discussion,
      _Screen.voting,
      _Screen.lockedVote,
      _Screen.night,
      _Screen.jailed,
      _Screen.spectator,
    ],
  ),
  (
    'Dialog dan panel',
    [
      _Screen.chat,
      _Screen.secretChat,
      _Screen.emotes,
      _Screen.player,
      _Screen.myInfo,
      _Screen.ability,
      _Screen.card,
      _Screen.parts,
      _Screen.nightPlan,
      _Screen.bowTarget,
    ],
  ),
  (
    'Adegan permainan',
    [
      _Screen.dawn,
      _Screen.offeringIntro,
      _Screen.jail,
      _Screen.evict,
      _Screen.revealVote,
      _Screen.pump,
      _Screen.burn,
      _Screen.theft,
      _Screen.mirror,
      _Screen.shield,
      _Screen.bowHit,
      _Screen.bowMiss,
      _Screen.finalBow,
    ],
  ),
  (
    'Akhir permainan',
    [_Screen.ending, _Screen.endingDark, _Screen.recap, _Screen.cancelled],
  ),
];

/// A preview owns both its repositories and its navigation stack. Routes
/// pushed by the ordinary game screens stay within the sample session.
class PreviewExperience extends StatefulWidget {
  const PreviewExperience({super.key});

  @override
  State<PreviewExperience> createState() => _PreviewExperienceState();
}

class _PreviewExperienceState extends State<PreviewExperience> {
  final _session = PreviewSession();
  final _navigator = GlobalKey<NavigatorState>();

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EmbunData(
    game: _session,
    lobby: _session,
    announcements: _session,
    child: ScaffoldMessenger(
      child: NavigatorPopHandler<Object?>(
        onPopWithResult: (result) => _navigator.currentState?.maybePop(result),
        child: Navigator(
          key: _navigator,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => _PreviewPanel(
              session: _session,
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    ),
  );
}

class _PreviewPanel extends StatefulWidget {
  const _PreviewPanel({required this.session, required this.onClose});

  final PreviewSession session;
  final VoidCallback onClose;

  @override
  State<_PreviewPanel> createState() => _PreviewPanelState();
}

class _PreviewPanelState extends State<_PreviewPanel> {
  static const _gameId = PreviewSession.gameId;
  PreviewSession get _session => widget.session;

  String _query = '';
  bool _dark = false;
  int _antagonists = 2;

  Future<void> _open(_Screen screen) async {
    final role = switch (screen) {
      _Screen.secretChat ||
      _Screen.nightPlan ||
      _Screen.omen ||
      _Screen.darkFace => 'antagonis',
      _Screen.ability || _Screen.bowTarget => 'warga',
      _ => _dark ? 'antagonis' : 'warga',
    };
    _session.prepare(
      role: role,
      antagonists: screen == _Screen.secretChat ? 2 : _antagonists,
      phase: switch (screen) {
        _Screen.research => 'research',
        _Screen.offering => 'offering',
        _Screen.ceremony || _Screen.effects => 'effects',
        _Screen.discussion => 'discussion',
        _Screen.voting || _Screen.lockedVote => 'voting',
        _Screen.night || _Screen.nightPlan => 'night',
        _ => 'day',
      },
      winner: switch (screen) {
        _Screen.ending || _Screen.recap => 'warga',
        _Screen.endingDark => 'antagonis',
        _Screen.cancelled => 'dibatalkan',
        _ => null,
      },
      waitingRoom: screen == _Screen.waiting,
      pickCharacter: const {
        _Screen.character,
        _Screen.story,
        _Screen.shuffle,
      }.contains(screen),
      holdPrologue: screen == _Screen.prologueWait,
      jailed: screen == _Screen.jailed,
      eliminated: screen == _Screen.spectator,
      locked: screen == _Screen.lockedVote,
    );

    if (screen == _Screen.otherGames) {
      await showMoreGames(context);
      return;
    }
    if (screen == _Screen.settings) {
      await showLobbySettings(context);
      return;
    }
    FocusScope.of(context).unfocus();
    await _push(screen);
    if (screen != _Screen.join && screen != _Screen.publicRooms) return;
    final joined = await _session.activeGame();
    if (mounted && joined != null) await _push(_Screen.waiting);
  }

  Future<void> _push(_Screen screen) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (routeContext) {
        void close() => Navigator.of(routeContext).pop();
        return _PreviewFrame(onClose: close, child: _page(screen, close));
      },
    ),
  );

  Widget _page(_Screen screen, VoidCallback close) {
    final me = _session.me;
    final dark = _session.role == 'antagonis';
    final day = _session.day;
    final leaves = _session.leaves;
    final name = me['name'] as String;
    final card = me['character_card'] as String;
    switch (screen) {
      case _Screen.title:
        return const LobbyPage();
      case _Screen.menu:
      case _Screen.waiting:
        return const LobbyPage(startAtMenu: true);
      case _Screen.create:
        return const LobbyPage(startAtCreate: true);
      case _Screen.join:
      case _Screen.publicRooms:
        return _JoinPreview(
          session: _session,
          publicRooms: screen == _Screen.publicRooms,
        );
      case _Screen.news:
        return AnnouncementsPage(repo: _session);
      case _Screen.tutorial:
        return const TutorialPage();
      case _Screen.rules:
      case _Screen.characters:
      case _Screen.items:
      case _Screen.abilities:
        final tab = [
          _Screen.rules,
          _Screen.characters,
          _Screen.items,
          _Screen.abilities,
        ].indexOf(screen);
        return GuidePage(initialTab: tab);
      case _Screen.story:
      case _Screen.shuffle:
      case _Screen.character:
      case _Screen.role:
      case _Screen.prologueWait:
        return PrologueFlow(
          gameId: _gameId,
          repo: _session,
          antagonistCount: _session.antagonistCount,
          resume: screen != _Screen.story && screen != _Screen.shuffle,
          startAtShuffling: screen == _Screen.shuffle,
          startAtWaiting: screen == _Screen.prologueWait,
        );
      case _Screen.omen:
        return DarkOmen(onContinue: close);
      case _Screen.darkFace:
        return Material(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Backdrop(path: nightSkyPath(attack: true), dark: true, dim: 0.55),
              SafeArea(
                child: CardPick(
                  dark: true,
                  title: 'Pilih Wajah Gelapmu',
                  hint:
                      'Pilih satu kartu tertutup. Hanya kamu yang akan melihat wajah gelapmu.',
                  options: [
                    for (final stem
                        in AssetCatalog.I.stems(antagonisDir).take(3))
                      PickOption(
                        AssetCatalog.I.file(antagonisDir, stem),
                        'Wajah gelap',
                      ),
                  ],
                  onPick: (_) async => null,
                  onDone: close,
                  onSkip: close,
                ),
              ),
            ],
          ),
        );
      case _Screen.dawn:
        return DayTransition(
          day: day,
          leaves: leaves,
          cycle: 3,
          dark: dark,
          onDone: close,
        );
      case _Screen.offeringIntro:
        return OfferingTransition(
          day: 6,
          leaves: leaves,
          dark: dark,
          onDone: close,
        );
      case _Screen.jail:
        return JailVerdictScene(
          name: name,
          card: card,
          isMe: true,
          onDone: close,
        );
      case _Screen.evict:
        return EvictionVerdictScene(
          name: name,
          card: card,
          isMe: true,
          votes: 3,
          onDone: close,
        );
      case _Screen.revealVote:
        return VoteRevealScene(
          day: 6,
          rows: _session.voteRows,
          myId: _session.myId,
          onDone: close,
        );
      case _Screen.pump:
      case _Screen.burn:
      case _Screen.theft:
      case _Screen.mirror:
      case _Screen.shield:
      case _Screen.bowHit:
      case _Screen.bowMiss:
      case _Screen.finalBow:
        final effect = switch (screen) {
          _Screen.bowHit => 'bow_hit',
          _Screen.bowMiss => 'bow_miss',
          _Screen.finalBow => 'bow_final',
          _ => screen.name,
        };
        return NightScene(
          day: day,
          rows: _session.nightRows(
            effect,
            actor: effect.startsWith('bow_') ? !dark : dark,
          ),
          defs: previewCards,
          finalBow: screen == _Screen.finalBow,
          finalBowBackdrop: landscapePath(leaves),
          onDone: close,
        );
      default:
        final table = TablePage(
          gameId: _gameId,
          role: _session.role,
          initialDayTab: switch (screen) {
            _Screen.hand => DayTab.hand,
            _Screen.merge => DayTab.merge,
            _Screen.hall => DayTab.hall,
            _ => DayTab.market,
          },
          showOpeningScenes: const {
            _Screen.ceremony,
            _Screen.ending,
            _Screen.endingDark,
          }.contains(screen),
          onExit: close,
        );
        return _isDialog(screen)
            ? _DialogPreview(
                show: (ctx) => _showDialog(ctx, screen),
                child: table,
              )
            : table;
    }
  }

  bool _isDialog(_Screen screen) => const {
    _Screen.chat,
    _Screen.secretChat,
    _Screen.emotes,
    _Screen.player,
    _Screen.myInfo,
    _Screen.ability,
    _Screen.card,
    _Screen.parts,
    _Screen.nightPlan,
    _Screen.bowTarget,
  }.contains(screen);

  Future<void> _showDialog(BuildContext context, _Screen screen) async {
    final s = _session;
    final me = s.me;
    switch (screen) {
      case _Screen.chat:
      case _Screen.secretChat:
        final access = screen == _Screen.secretChat
            ? ValueNotifier(true)
            : null;
        try {
          await showChatSheet(
            context,
            repo: s,
            gameId: _gameId,
            players: s.roster,
            terbisikAccess: access,
            partnerName: s.other['name'] as String,
          );
        } finally {
          access?.dispose();
        }
      case _Screen.emotes:
        await showEmotePanel(
          context,
          repo: s,
          gameId: _gameId,
          day: s.day,
          players: s.roster,
        );
      case _Screen.player:
        await showPlayerSheet(
          context,
          repo: s,
          gameId: _gameId,
          player: s.other,
          hand: s.hand,
          defs: previewCards,
          balance: 74.7,
          socialOpen: true,
          day: s.day,
          iAmJailed: false,
        );
      case _Screen.myInfo:
        await showMyInfoDialog(
          context,
          isAntag: s.role == 'antagonis',
          name: me['name'] as String,
          characterStem: me['character_card'] as String,
          darkSeed: 0,
          abilityDef: previewAbilities['jangan_bohong'],
        );
      case _Screen.ability:
        await showAbilityDialog(
          context,
          def: previewAbilities['jangan_bohong']!,
          used: false,
          repo: s,
          gameId: _gameId,
          phase: 'day',
          jailed: false,
          others: s.roster.skip(1).toList(),
          everyone: s.roster,
          day: s.day,
          onUsed: () {},
        );
      case _Screen.card:
        await showCardPreview(
          context,
          previewCards['air_suci']!,
          defs: previewCards,
        );
      case _Screen.parts:
        await showPartsSheet(
          context,
          akar: 'subur',
          batang: 'biasa',
          tanah: 'layu',
          leaves: s.leaves,
          winLeaves: 20,
        );
      case _Screen.nightPlan:
        await showNightPlanDialog(
          context,
          repo: s,
          gameId: _gameId,
          day: s.day,
          hand: s.hand,
          defs: previewCards,
          others: s.roster.skip(1).toList(),
          onChanged: () {},
        );
      case _Screen.bowTarget:
        await showBowTargetDialog(context, players: s.roster, myId: s.myId);
      default:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = [
      for (final (title, screens) in _sections)
        (
          title,
          screens
              .where(
                (screen) =>
                    '$title ${screen.label}'.toLowerCase().contains(_query),
              )
              .toList(),
        ),
    ];
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onClose),
        title: const Text('Panel Pratinjau Embun'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                Text(
                  'Pilih layar untuk dibuka dengan data contoh lokal.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('Warga'),
                      selected: !_dark,
                      onSelected: (_) => setState(() => _dark = false),
                    ),
                    ChoiceChip(
                      label: const Text('Terbisik'),
                      selected: _dark,
                      onSelected: (_) => setState(() => _dark = true),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('1 antagonis'),
                      selected: _antagonists == 1,
                      onSelected: (_) => setState(() => _antagonists = 1),
                    ),
                    ChoiceChip(
                      label: const Text('2 antagonis'),
                      selected: _antagonists == 2,
                      onSelected: (_) => setState(() => _antagonists = 2),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    labelText: 'Cari halaman atau adegan',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 12),
                if (sections.every((section) => section.$2.isEmpty))
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Tidak ada layar yang cocok.'),
                  ),
                for (final (title, screens) in sections)
                  if (screens.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: EmbunColors.gold,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    for (final screen in screens)
                      ListTile(
                        title: Text(screen.label),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        visualDensity: VisualDensity.compact,
                        onTap: () => _open(screen),
                      ),
                    const Divider(height: 14),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewFrame extends StatelessWidget {
  const _PreviewFrame({required this.child, required this.onClose});

  final Widget child;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Material(
    child: Stack(
      fit: StackFit.expand,
      children: [
        child,
        Align(
          alignment: const Alignment(1, -0.35),
          child: SafeArea(
            minimum: const EdgeInsets.only(right: 4),
            child: IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Kembali ke panel pratinjau',
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xDB14221F),
                foregroundColor: EmbunColors.gold,
              ),
              onPressed: onClose,
              icon: const Icon(Icons.grid_view, size: 19),
            ),
          ),
        ),
      ],
    ),
  );
}

class _DialogPreview extends StatefulWidget {
  const _DialogPreview({required this.child, required this.show});

  final Widget child;
  final Future<void> Function(BuildContext) show;

  @override
  State<_DialogPreview> createState() => _DialogPreviewState();
}

class _DialogPreviewState extends State<_DialogPreview> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.show(context);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _JoinPreview extends StatefulWidget {
  const _JoinPreview({required this.session, required this.publicRooms});

  final PreviewSession session;
  final bool publicRooms;

  @override
  State<_JoinPreview> createState() => _JoinPreviewState();
}

class _JoinPreviewState extends State<_JoinPreview> {
  final _name = TextEditingController(text: 'Penguji');
  final _code = TextEditingController(text: PreviewSession.roomCode);

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PublicRoomsPage(
    repo: widget.session,
    nameCtrl: _name,
    codeCtrl: _code,
    onJoin: (code) async {
      await widget.session.joinGame(code, _name.text, 'pria-pelukis');
      return null;
    },
    onCreate: () {},
    initialTab: widget.publicRooms ? 1 : 0,
  );
}
