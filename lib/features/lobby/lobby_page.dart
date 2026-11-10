import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/announcement_repository.dart';
import '../../data/app_info.dart';
import '../../data/asset_catalog.dart';
import '../../data/embun_data.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../../data/lobby_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import '../common/sfx.dart';
import '../common/cloth_transition.dart';
import '../common/shader_fx.dart';
import '../prologue/prologue_page.dart';
import '../guide/guide_page.dart';
import '../guide/tutorial_page.dart';
import 'more_games_sheet.dart';
import 'announcements_page.dart';
import 'public_rooms_page.dart';
import 'room_entry_view.dart';
import 'waiting_room_view.dart';
import 'title_intro.dart';
import 'announcement_body.dart';
import '../table/chat_sheet.dart';
import '../table/table_page.dart';

double _seg(double v, double a, double b) =>
    ((v - a) / (b - a)).clamp(0.0, 1.0).toDouble();

double _smooth(double x) => x * x * (3 - 2 * x);

/// Tiga tahap sebelum ruangan: layar judul, menu utama, lalu isian
/// (nama / kode ruangan). Bila pemain masih punya ruangan di lobi, tahap
/// ini dilewati dan ruangan langsung tampil.
enum _Stage { title, menu, entry }

class LobbyPage extends StatefulWidget {
  /// true = lewati layar judul (mis. kembali dari permainan).
  final bool startAtMenu;
  final bool startAtCreate;
  final WidgetBuilder? previewPanel;

  const LobbyPage({
    super.key,
    this.startAtMenu = false,
    this.startAtCreate = false,
    this.previewPanel,
  });
  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage>
    with TickerProviderStateMixin {
  late final repo = EmbunData.maybeOf(context)?.lobby ?? LobbyRepository();
  late final _gr = EmbunData.maybeOf(context)?.game ?? GameRepository();
  late final _news =
      EmbunData.maybeOf(context)?.announcements ?? AnnouncementRepository();
  final nameCtrl = TextEditingController();
  final codeCtrl = TextEditingController();
  String? gameId;
  bool busy = false;
  bool _navigated = false;

  ({
    String id,
    Stream<Map<String, dynamic>?> game,
    Stream<List<Map<String, dynamic>>> players,
    Stream<List<Map<String, dynamic>>> chat,
  })? _roomStreams;

  late _Stage _stage;
  bool _createPublic = false;
  int _createCycles = 4;
  int _createAntagonists = 1;
  int _unreadNews = 0;

  /// Versi yang lebih baru dari aplikasi ini (dari entri "pembaruan"), beserta
  /// tautan unduhnya bila ada. Null = sudah terbaru.
  ({String version, String? url})? _update;
  bool _updateHidden = false;
  bool _booted = false;
  bool _tutorialNew = false;

  // Naskah pembukaan layar judul (0..1): Hayu pulih, lalu logo dan tombol.
  late final AnimationController _intro = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 8500));

  // Jam berkelanjutan untuk latar bergerak, kunang-kunang, dan melayang.
  late final AnimationController _t = AnimationController(
      vsync: this, duration: const Duration(seconds: 120))
    ..repeat();

  @override
  void initState() {
    super.initState();
    _stage = widget.startAtCreate
        ? _Stage.entry
        : widget.startAtMenu
        ? _Stage.menu
        : _Stage.title;
    if (_stage != _Stage.title) {
      _intro.value = 1;
    } else {
      _intro.forward();
    }
    _boot();
  }

  @override
  void dispose() {
    _t.dispose();
    _intro.dispose();
    nameCtrl.dispose();
    codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    try {
      await repo.ensureSignedIn();
      unawaited(_refreshNews());
      unawaited(TutorialPage.isNew().then((v) {
        if (mounted && v != _tutorialNew) setState(() => _tutorialNew = v);
      }));
      final g = await repo.activeGame();
      if (!mounted) return;
      if (g != null) {
        final id = g['id'] as String;
        if (g['status'] == 'lobby') {
          setState(() => gameId = id);
          return;
        }
        final role = await repo.myRole(id);
        if (!mounted) return;
        if (role != null) {
          // Gerbang prolog masih tertutup: kembali ke prolog, bukan ke meja.
          final inPrologue = g['prologue_until'] != null;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => inPrologue
                  ? PrologueFlow(
                      gameId: id,
                      repo: repo,
                      resume: true,
                      antagonistCount: (g['antagonist_count'] as int?) ?? 1,
                    )
                  : TablePage(gameId: id, role: role),
            ),
          );
          return;
        }
      }
    } catch (e) {
      if (mounted) _toast(errMsg(e));
    } finally {
      if (mounted) setState(() => _booted = true);
    }
  }

  Future<void> _createRoom(String name) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final id = await repo.createGame(
        name,
        randomProtagonist(),
        isPublic: _createPublic,
        cycles: _createCycles,
        antagonistCount: _createAntagonists,
      );
      if (mounted) setState(() => gameId = id);
    } catch (e) {
      if (mounted) _toast(errMsg(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _start() {
    if (!_booted || _stage != _Stage.title) return;
    HapticFeedback.lightImpact();
    setState(() => _stage = _Stage.menu);
  }

  /// Layar isian untuk membuat ruangan. Bergabung punya layar sendiri
  /// ([_openJoin]) dengan tab kode dan daftar publik.
  void _openCreate() {
    HapticFeedback.selectionClick();
    setState(() => _stage = _Stage.entry);
  }

  Future<void> _refreshNews() async {
    try {
      final n = await _news.unreadCount();
      if (mounted && n != _unreadNews) setState(() => _unreadNews = n);
    } catch (_) {
      // Tabel belum ada / offline: menu tetap tampil tanpa penanda.
    }
    await _loadUpdate();
  }

  Future<void> _loadUpdate() async {
    try {
      final rows = await _news.updates();
      String? best;
      String? url;
      for (final r in rows) {
        final v = ((r['version'] as String?) ?? '').trim();
        if (v.isEmpty || !AppInfo.isNewer(v)) continue;
        if (best == null || AppInfo.compare(v, best) > 0) {
          best = v;
          url = null;
        }
        if (v == best) {
          url ??= findDownloadLink((r['body'] as String?) ?? '')?.url;
        }
      }
      if (!mounted) return;
      setState(() => _update = best == null ? null : (version: best, url: url));
    } catch (_) {
      // Offline atau tabel belum ada: tanpa penanda.
    }
  }

  bool get _showUpdate => _update != null && !_updateHidden;

  void _openUpdate() {
    final u = _update;
    if (u == null) return;
    HapticFeedback.selectionClick();
    if (u.url != null) {
      openAnnouncementLink(context, u.url!);
    } else {
      _openNews();
    }
  }

  /// Pembaruan di depan menu, bergaya butir menu lain (ikon + teks, tanpa
  /// kotak): "Unduh Vx" dengan penanda, keterangan versi, dan "Nanti saja".
  Widget _updateEntry(bool center) {
    final u = _update!;
    final cross = center ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: cross,
        children: [
          _MenuTile(
            index: 0,
            icon: 'announcement',
            label: u.url != null ? 'Unduh V${u.version}' : 'Pembaruan V${u.version}',
            badge: 1,
            center: center,
            onTap: _openUpdate,
          ),
          Padding(
            padding: EdgeInsets.only(left: center ? 0 : 70),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Versi baru · versimu ${AppInfo.tag}',
                    style: const TextStyle(
                        fontSize: 11.5,
                        letterSpacing: 0.4,
                        color: Colors.white60)),
                const SizedBox(width: 10),
                InkWell(
                  onTap: () => setState(() => _updateHidden = true),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Text('Nanti saja',
                        style: TextStyle(
                            fontSize: 11.5,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white38,
                            color: Colors.white54)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openNews() async {
    HapticFeedback.selectionClick();
    Sfx.I.playAny(Snd.winds);
    await Navigator.of(context).push(
      ClothTransition.route<void>(
        AnnouncementsPage(repo: _news),
        style: ClothStyle.bungaKrem,
      ),
    );
    if (mounted) _refreshNews();
  }

  /// Gabung Ruangan (layar penuh) dengan dua tab: "Pakai Kode" dan "Ruangan
  /// Publik". Nama diisi dan gabung dilakukan di dalam layar itu; bila
  /// berhasil, layar menutup dan ruangan tampil di sini.
  void _openJoin() {
    HapticFeedback.selectionClick();
    Sfx.I.playAny(Snd.winds);
    Navigator.of(context).push(
      ClothTransition.route<void>(
        PublicRoomsPage(
          repo: repo,
          nameCtrl: nameCtrl,
          codeCtrl: codeCtrl,
          onJoin: _joinRoom,
          onCreate: () {
            setState(() => _createPublic = true);
            _openCreate();
          },
        ),
        style: ClothStyle.daunHayu,
      ),
    );
  }

  /// Null bila berhasil bergabung; kalau gagal, pesan galatnya.
  Future<String?> _joinRoom(String code) async {
    try {
      final id =
      await repo.joinGame(code, nameCtrl.text, randomProtagonist());
      if (mounted) setState(() => gameId = id);
      return null;
    } catch (e) {
      return errMsg(e);
    }
  }

  // ====================== kerangka & latar ======================

  @override
  Widget build(BuildContext context) {
    final inRoom = gameId != null;
    final canPop = inRoom || _stage == _Stage.title;
    final bg = _stage == _Stage.title && !inRoom
        ? 'lembah-hijau0'
        : 'rumahdesa-hijau';

    final Widget screen;
    if (inRoom) {
      screen = KeyedSubtree(
          key: ValueKey('room-$gameId'), child: _room(gameId!));
    } else {
      switch (_stage) {
        case _Stage.title:
          screen = KeyedSubtree(key: const ValueKey('title'), child: _title());
        case _Stage.menu:
          screen = KeyedSubtree(key: const ValueKey('menu'), child: _menu());
        case _Stage.entry:
          screen = CreateRoomView(
            key: const ValueKey('entry'),
            nameCtrl: nameCtrl,
            isPublic: _createPublic,
            cycles: _createCycles,
            antagonistCount: _createAntagonists,
            busy: busy,
            onVisibilityChanged: (value) => setState(() => _createPublic = value),
            onDurationChanged: (cycles) => setState(() => _createCycles = cycles),
            onAntagonistCountChanged: (count) =>
                setState(() => _createAntagonists = count),
            onCreate: _createRoom,
            onBack: () => setState(() => _stage = _Stage.menu),
          );
      }
    }

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || busy) return;
        setState(() => _stage =
        _stage == _Stage.entry ? _Stage.menu : _Stage.title);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF050A08),
        body: Stack(
          fit: StackFit.expand,
          children: [
            _background(bg, _stage == _Stage.title && !inRoom),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 700),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              layoutBuilder: (cur, prev) => Stack(
                fit: StackFit.expand,
                children: [...prev, ?cur],
              ),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.97, end: 1.0).animate(anim),
                  child: child,
                ),
              ),
              child: screen,
            ),
          ],
        ),
      ),
    );
  }

  /// Layar judul memakai pembukaan sinematik ([TitleIntroBackdrop]); layar
  /// lain memakai latar bentang yang bergerak pelan.
  Widget _background(String stem, bool title) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 900),
    layoutBuilder: (current, previous) => Stack(
      fit: StackFit.expand,
      children: [...previous, if (current != null) current],
    ),
    child: title
        ? TitleIntroBackdrop(
        key: const ValueKey('title-bg'), progress: _intro, clock: _t)
        : KeyedSubtree(
        key: const ValueKey('plain-bg'), child: _plainBackground(stem)),
  );

  /// Latar bentang yang bergerak pelan (zoom dan geser) dengan kunang-kunang.
  Widget _plainBackground(String stem) => AnimatedBuilder(
    animation: _t,
    builder: (context, _) {
      final time = _t.value * 120;
      final k = 1.07 + 0.04 * sin(time * 0.12);
      final al = Alignment(sin(time * 0.07) * 0.5, cos(time * 0.05) * 0.3);
      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: Transform.scale(
              scale: k,
              alignment: al,
              child: Backdrop(path: sceneryPath(stem), dim: 0.4),
            ),
          ),
          IgnorePointer(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: 0.0),
              duration: const Duration(milliseconds: 900),
              builder: (_, beam, __) => CustomPaint(
                painter: _Fx(time: time, beam: beam),
              ),
            ),
          ),
        ],
      );
    },
  );

  // ====================== 1. LAYAR JUDUL ======================

  Widget _title() {
    return LayoutBuilder(builder: (context, c) {
      final logoH = min(c.maxHeight * 0.5, 420.0).toDouble();
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Ketukan pertama melewati pembukaan, ketukan berikutnya memulai.
        onTap: () {
          if (_intro.value < 0.9) {
            _intro.animateTo(1,
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOut);
          } else if (_booted) {
            _start();
          }
        },
        child: AnimatedBuilder(
          animation: _intro,
          builder: (context, _) {
            final t = _intro.value;
            final lt = _smooth(_seg(t, 0.62, 0.86));
            final st = _smooth(_seg(t, 0.80, 0.94));
            final bt = _smooth(_seg(t, 0.90, 1.0));
            return Stack(
              fit: StackFit.expand,
              children: [
                // vinyet
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 1.0,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                        stops: const [0.45, 1.0],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: AnimatedBuilder(
                        animation: _t,
                        builder: (context, _) {
                          final time = _t.value * 120;
                          final float = sin(time * 0.9) * 5;
                          final pulse = 0.5 + 0.5 * sin(time * 1.4);
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Opacity(
                                opacity: lt,
                                child: Transform.translate(
                                  offset: Offset(0, float),
                                  child: Transform.scale(
                                    scale: 0.88 + 0.12 * lt,
                                    child: SizedBox(
                                      width: logoH * 1.3,
                                      height: logoH,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Container(
                                            width: logoH * 1.2,
                                            height: logoH * 1.2,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: RadialGradient(colors: [
                                                EmbunColors.gold.withValues(
                                                    alpha: 0.18 +
                                                        0.12 * pulse),
                                                EmbunColors.gold
                                                    .withValues(alpha: 0),
                                              ]),
                                            ),
                                          ),
                                          GameImage(
                                              path: logoPath(
                                                  'ikon-transparent'),
                                              fit: BoxFit.contain,
                                              cacheWidth: 1000),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Opacity(
                                opacity: st,
                                child: Transform.translate(
                                  offset: Offset(0, (1 - st) * 10),
                                  child: Text(
                                    AppInfo.titleLine,
                                    style: TextStyle(
                                      fontSize: 12,
                                      letterSpacing: 4,
                                      color: EmbunColors.gold
                                          .withValues(alpha: 0.9),
                                      shadows: const [
                                        Shadow(
                                            color: Colors.black,
                                            blurRadius: 10),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 26),
                              Opacity(
                                opacity: bt,
                                child: Transform.translate(
                                  offset: Offset(0, (1 - bt) * 14),
                                  child: SizedBox(
                                    width: 240,
                                    child: EmbunButton(
                                      label: _booted ? 'Mulai' : 'Memuat...',
                                      icon: 'start',
                                      expand: true,
                                      onPressed: _booted ? _start : null,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Opacity(
                                opacity: bt * (0.3 + 0.3 * pulse),
                                child: const Text('Ketuk di mana saja',
                                    style: TextStyle(
                                        fontSize: 11,
                                        letterSpacing: 1,
                                        color: Colors.white70)),
                              ),
                              if (_showUpdate) ...[
                                const SizedBox(height: 16),
                                Opacity(
                                  opacity: bt,
                                  child: SizedBox(
                                    width: 240,
                                    child: EmbunButton(
                                      label: _update!.url != null
                                          ? 'Unduh V${_update!.version}'
                                          : 'Pembaruan V${_update!.version}',
                                      icon: 'announcement',
                                      kind: EmbunButtonKind.secondary,
                                      height: 44,
                                      expand: true,
                                      onPressed: _openUpdate,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    });
  }

  // ====================== 2. MENU UTAMA ======================

  Widget _backButton(VoidCallback onTap) => IconButton(
    tooltip: 'Kembali',
    onPressed: onTap,
    color: EmbunColors.gold,
    icon: const GameIcon('back', size: 23),
  );

  /// Panduan kini layar penuh (cara bermain, karakter, dan kartu item).
  /// Panduan kini layar penuh (cara bermain, karakter, dan kartu item).
  void _openGuide() {
    Sfx.I.playAny(Snd.winds);
    Navigator.of(context).push(
      ClothTransition.route<void>(
        const GuidePage(),
        style: ClothStyle.selendangBata,
      ),
    );
  }

  /// Tutorial singkat (halaman geser dengan narasi). Lencana "Baru" hilang
  /// setelah dibuka sekali.
  void _openTutorial() {
    Sfx.I.playAny(Snd.winds);
    if (_tutorialNew) setState(() => _tutorialNew = false);
    Navigator.of(context).push(
      ClothTransition.route<void>(
        const TutorialPage(),
        style: ClothStyle.selendangBata,
      ),
    );
  }

  /// Lonceng Pengumuman di pojok kanan atas; bertitik angka bila ada kabar
  /// yang belum dibaca.
  Widget _newsBell() => Badge(
    isLabelVisible: _unreadNews > 0,
    label: Text(_unreadNews >= 99 ? '99+' : '$_unreadNews'),
    alignment: const AlignmentDirectional(-6, 6),
    child: IconButton(
      tooltip: 'Pengumuman',
      onPressed: _openNews,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: Opacity(
        opacity: _unreadNews > 0 ? 1.0 : 0.85,
        child: const GameIcon('notification', size: 44),
      ),
    ),
  );

  void _openSettings() => showLobbySettings(context);

  /// Nomor versi kecil di pojok menu; diketuk membuka Pengumuman.
  Widget _versionFooter() => Positioned(
    bottom: 8,
    right: 12,
    child: InkWell(
      onTap: _openNews,
      onLongPress: widget.previewPanel == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: widget.previewPanel!),
              ),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          _unreadNews > 0 ? '${AppInfo.tag}  ·  ada kabar baru' : AppInfo.tag,
          style: TextStyle(
            fontSize: 11.5,
            letterSpacing: 1.2,
            color: _unreadNews > 0 ? EmbunColors.gold : Colors.white54,
            shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
          ),
        ),
      ),
    ),
  );

  Widget _menu() {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 720;
      final items = <Widget>[
        if (_showUpdate) _updateEntry(!wide),
        // Dua aksi utama dibuat lebih besar.
        _MenuTile(
            index: 0,
            icon: 'roomcreate',
            label: 'Buat Ruangan',
            scale: 1.15,
            center: !wide,
            onTap: _openCreate),
        _MenuTile(
            index: 1,
            icon: 'jointoroom',
            label: 'Gabung Ruangan',
            scale: 1.15,
            center: !wide,
            onTap: _openJoin),
        _MenuTile(
            index: 2,
            icon: 'info',
            label: 'Panduan',
            center: !wide,
            onTap: _openGuide),
        _MenuTile(
            index: 3,
            icon: 'tutor',
            label: 'Tutorial',
            badge: _tutorialNew ? 1 : 0,
            center: !wide,
            onTap: _openTutorial),
        _MenuTile(
            index: 4,
            icon: 'settings',
            label: 'Pengaturan',
            center: !wide,
            onTap: _openSettings),
        _MenuTile(
            index: 5,
            icon: 'plus',
            label: 'Permainan Lainnya',
            scale: 0.82,
            center: !wide,
            onTap: () => showMoreGames(context)),
      ];
      final menuCol = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
        wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: items,
      );

      Widget logo(double w) => SizedBox(
        width: w,
        height: w * 0.36,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (_, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(
                offset: Offset(0, (1 - v) * 16), child: child),
          ),
          child: GameImage(
              path: logoPath('logoteks-transparent'),
              fit: BoxFit.contain,
              alignment: wide ? Alignment.centerLeft : Alignment.center,
              cacheWidth: 900),
        ),
      );

      return Stack(
        fit: StackFit.expand,
        children: [
          // bayangan agar logo dan menu terbaca
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: wide
                    ? LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.82),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.8],
                )
                    : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 6,
                  left: 6,
                  child: _backButton(
                          () => setState(() => _stage = _Stage.title)),
                ),
                Positioned(top: 4, right: 8, child: _newsBell()),
                _versionFooter(),
                if (wide)
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(56, 56, 24, 40),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        // Menyusut otomatis bila layar pendek, tak pernah meluap.
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.bottomLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              logo(min(380.0, c.maxWidth * 0.34)),
                              const SizedBox(width: 56),
                              menuCol,
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Positioned.fill(
                    child: CustomScrollView(
                      slivers: [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding:
                            const EdgeInsets.fromLTRB(24, 48, 24, 36),
                            child: Column(
                              children: [
                                logo(min(320.0, c.maxWidth - 48)),
                                const Spacer(),
                                const SizedBox(height: 16),
                                menuCol,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    });
  }

  // ====================== RUANGAN (lobi) ======================

  Future<void> _pickCard(String id, Map<String, dynamic> me) async {
    if (me['ready'] == true) return; // terkunci selama siap
    final stems = protagonistStems();
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF12201E),
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.75,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SectionHeader(icon: 'mydeck', title: 'Pilih kartu karakter'),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 130,
                  childAspectRatio: 1 / kProtagonistAspect,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: stems.length,
                itemBuilder: (_, i) {
                  final s = stems[i];
                  final sel = s == me['character_card'];
                  return GestureDetector(
                    onTap: () => Navigator.pop(ctx, s),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel ? EmbunColors.gold : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: GameImage(
                            path: protagonistPath(s), cacheWidth: 300),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (chosen != null && chosen != me['character_card']) {
      try {
        await repo.updateCharacter(id, me['name'] as String, chosen);
      } catch (e) {
        if (mounted) _toast(errMsg(e));
      }
    }
  }

  Widget _room(String id) {
    if (_roomStreams?.id != id) {
      _roomStreams = (
        id: id,
        game: repo.game(id),
        players: repo.players(id),
        chat: _gr.chat(id),
      );
    }
    final streams = _roomStreams!;
    return StreamBuilder<Map<String, dynamic>?>(
      stream: streams.game,
      builder: (context, snapshot) {
        final game = snapshot.data;
        if (game == null) {
          if (snapshot.connectionState != ConnectionState.waiting) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || gameId != id) return;
              _returnToMenu();
              _toast('Ruangan sudah dibubarkan');
            });
          }
          return const EmbunLoading();
        }
        if (game['status'] != 'lobby') {
          if (!_navigated) {
            _navigated = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || gameId != id) return;
              Navigator.of(context).pushReplacement(
                ClothTransition.route(PrologueFlow(
                  gameId: id,
                  repo: repo,
                  antagonistCount: (game['antagonist_count'] as int?) ?? 1,
                )),
              );
            });
          }
          return const EmbunLoading();
        }
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: streams.players,
          builder: (context, snapshot) {
            final players = snapshot.data ?? [];
            return WaitingRoomView(
              code: game['code'] as String,
              isPublic: game['is_public'] == true,
              antagonistCount: (game['antagonist_count'] as int?) ?? 1,
              hostId: game['host_id'] as String,
              viewerId: repo.myId,
              players: players,
              chatMessages: streams.chat,
              chat: ChatPanel(
                repo: _gr, gameId: id, players: players, lobby: true,
              ),
              onVisibilityChanged: (value) => repo.setRoomPublic(id, value),
              onReady: (value) => repo.setReady(id, value),
              onStart: () => repo.startGame(id),
              onLeave: () => _leaveRoom(id),
              onEditCharacter: (player) => _pickCard(id, player),
            );
          },
        );
      },
    );
  }

  void _returnToMenu() {
    setState(() {
      gameId = null;
      _roomStreams = null;
      _navigated = false;
      _stage = _Stage.menu;
    });
  }

  Future<void> _leaveRoom(String id) async {
    // Putus langganan sebelum host menghapus ruang.
    _returnToMenu();
    try {
      await repo.leave(id);
    } catch (e) {
      if (!mounted) return;
      setState(() => gameId = id);
      _toast(errMsg(e));
    }
  }
}

/// Pengaturan: Suara dan Efek Visual dalam satu dialog.
Future<void> showLobbySettings(BuildContext context) {
  HapticFeedback.selectionClick();
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: OrnatePanel(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(icon: 'customization', title: 'Pengaturan'),
              const SizedBox(height: 8),
              ValueListenableBuilder<bool>(
                valueListenable: Sfx.I.muted,
                builder: (_, muted, _) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const GameIcon('announcement', size: 32),
                  value: !muted,
                  onChanged: (v) => Sfx.I.muted.value = !v,
                  title: const Text('Suara'),
                  subtitle: const Text('Musik dan efek suara',
                      style: TextStyle(fontSize: 11.5, color: Colors.white60)),
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: ShaderFx.enabled,
                builder: (_, on, _) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const GameIcon('show', size: 32),
                  value: on,
                  onChanged: (v) => ShaderFx.enabled.value = v,
                  title: const Text('Efek Visual'),
                  subtitle: const Text(
                      'Matikan bila perangkat terasa berat',
                      style: TextStyle(fontSize: 11.5, color: Colors.white60)),
                ),
              ),
              const SizedBox(height: 12),
              EmbunButton(
                label: 'Tutup',
                icon: 'silang',
                kind: EmbunButtonKind.secondary,
                height: 46,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Satu butir menu utama: ikon medali + teks. Muncul bergantian dari kiri;
/// saat disentuh atau disorot, teks beralih emas, bergeser, dan bertitik.
class _MenuTile extends StatefulWidget {
  final int index;
  final String icon;
  final String label;
  final bool center;
  final int badge;
  final VoidCallback onTap;

  /// Skala ikon dan teks: 1,15 untuk aksi utama, 0,82 untuk butir kecil.
  final double scale;

  /// Ikon Material; bila diisi dipakai menggantikan ikon gambar [icon].
  final IconData? materialIcon;
  const _MenuTile({
    required this.index,
    required this.icon,
    required this.label,
    required this.onTap,
    this.center = false,
    this.badge = 0,
    this.scale = 1.0,
    this.materialIcon,
  });

  @override
  State<_MenuTile> createState() => _MenuTileState();
}

class _MenuTileState extends State<_MenuTile> {
  bool _on = false;

  void _set(bool v) {
    if (mounted && _on != v) setState(() => _on = v);
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 650 + widget.index * 200),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0).toDouble(),
        child: Transform.translate(offset: Offset((1 - v) * -34, 0), child: child),
      ),
      child: MouseRegion(
        onEnter: (_) => _set(true),
        onExit: (_) => _set(false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _set(true),
          onTapUp: (_) => _set(false),
          onTapCancel: () => _set(false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_on ? 8 : 0, 0, 0),
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _on ? EmbunColors.gold : Colors.transparent,
                    boxShadow: _on
                        ? [
                      BoxShadow(
                          color:
                          EmbunColors.gold.withValues(alpha: 0.8),
                          blurRadius: 8),
                    ]
                        : null,
                  ),
                ),
                widget.materialIcon != null
                    ? SizedBox(
                  width: 34 * widget.scale,
                  height: 34 * widget.scale,
                  child: Icon(widget.materialIcon,
                      size: 28 * widget.scale, color: EmbunColors.gold),
                )
                    : GameIcon(widget.icon, size: 34 * widget.scale),
                const SizedBox(width: 12),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 160),
                  style: TextStyle(
                    fontSize: 22 * widget.scale,
                    letterSpacing: 1.2,
                    fontWeight: _on ? FontWeight.bold : FontWeight.w500,
                    color: _on ? EmbunColors.gold : EmbunColors.cream,
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 10),
                    ],
                  ),
                  child: Text(widget.label),
                ),
                if (widget.badge > 0) ...[
                  const SizedBox(width: 10),
                  Container(
                    constraints:
                    const BoxConstraints(minWidth: 22, minHeight: 22),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: EmbunColors.gold,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                            color: EmbunColors.gold.withValues(alpha: 0.6),
                            blurRadius: 8),
                      ],
                    ),
                    child: Text(
                      widget.badge >= 99 ? '99+' : '${widget.badge}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF07130F)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kunang-kunang emas yang melayang naik; bila [beam] > 0, ditambah
/// berkas cahaya hangat diagonal dari kanan atas (layar judul).
class _Fx extends CustomPainter {
  final double time;
  final double beam;
  _Fx({required this.time, required this.beam});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    if (beam > 0.01) {
      final origin = Offset(w * 0.8, -h * 0.15);
      const ang = 2.0; // arah turun ke kiri
      final len = h * 1.6;
      const half = 0.2;
      final dir = Offset(cos(ang), sin(ang));
      final path = Path()
        ..moveTo(origin.dx, origin.dy)
        ..lineTo(origin.dx + cos(ang - half) * len,
            origin.dy + sin(ang - half) * len)
        ..lineTo(origin.dx + cos(ang + half) * len,
            origin.dy + sin(ang + half) * len)
        ..close();
      final a = (0.2 * beam * (0.8 + 0.2 * sin(time * 0.5)))
          .clamp(0.0, 1.0)
          .toDouble();
      canvas.drawPath(
        path,
        Paint()
          ..blendMode = BlendMode.plus
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28)
          ..shader = ui.Gradient.linear(
            origin,
            origin + dir * len,
            [
              const Color(0xFFFFF1C0).withValues(alpha: a),
              const Color(0xFFFFF1C0).withValues(alpha: 0),
            ],
          ),
      );
    }

    final rnd = Random(5);
    for (var i = 0; i < 26; i++) {
      final x0 = rnd.nextDouble();
      final y0 = rnd.nextDouble();
      final sp = 0.015 + rnd.nextDouble() * 0.04;
      final sz = 1.4 + rnd.nextDouble() * 2.6;
      final ph = rnd.nextDouble() * 2 * pi;
      final tw = 1.2 + rnd.nextDouble() * 2;
      final f = (y0 - time * sp) % 1.0;
      final o = Offset((x0 + sin(time * 0.3 + ph) * 0.03) * w, f * h);
      final a = (0.35 + 0.65 * (0.5 + 0.5 * sin(time * tw + ph))) * sin(f * pi);
      final col =
      i.isEven ? const Color(0xFFFFE08A) : const Color(0xFFBFF5D0);
      canvas.drawCircle(o, sz * 3,
          Paint()..color = col.withValues(alpha: (0.14 * a).clamp(0.0, 1.0)));
      canvas.drawCircle(
          o,
          sz,
          Paint()
            ..color = Color.lerp(col, Colors.white, 0.5)!
                .withValues(alpha: (0.85 * a).clamp(0.0, 1.0)));
    }
  }

  @override
  bool shouldRepaint(covariant _Fx old) => true;
}
