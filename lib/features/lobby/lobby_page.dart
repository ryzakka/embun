import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../../data/lobby_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import '../prologue/prologue_page.dart';
import '../guide/guide_page.dart';
import 'more_games_sheet.dart';
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
  const LobbyPage({super.key, this.startAtMenu = false});
  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage>
    with SingleTickerProviderStateMixin {
  final repo = LobbyRepository();
  final _gr = GameRepository();
  final nameCtrl = TextEditingController();
  final codeCtrl = TextEditingController();
  String? gameId;
  bool busy = false;
  bool _navigated = false;

  late _Stage _stage;
  bool _joinMode = false;
  bool _booted = false;

  // Jam berkelanjutan untuk latar bergerak, kunang-kunang, dan melayang.
  late final AnimationController _t = AnimationController(
      vsync: this, duration: const Duration(seconds: 120))
    ..repeat();

  @override
  void initState() {
    super.initState();
    _stage = widget.startAtMenu ? _Stage.menu : _Stage.title;
    _boot();
  }

  @override
  void dispose() {
    _t.dispose();
    nameCtrl.dispose();
    codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    try {
      await repo.ensureSignedIn();
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
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => TablePage(gameId: id, role: role),
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

  Future<void> _run(Future<String> Function(String card) action) async {
    if (nameCtrl.text.trim().isEmpty) return _toast('Isi namamu dulu');
    setState(() => busy = true);
    try {
      final id = await action(randomProtagonist());
      if (mounted) setState(() => gameId = id);
    } catch (e) {
      _toast(errMsg(e));
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

  void _openEntry(bool join) {
    HapticFeedback.selectionClick();
    setState(() {
      _joinMode = join;
      _stage = _Stage.entry;
    });
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
          key: const ValueKey('room'), child: _framed(1100, _room(gameId!)));
    } else {
      switch (_stage) {
        case _Stage.title:
          screen = KeyedSubtree(key: const ValueKey('title'), child: _title());
        case _Stage.menu:
          screen = KeyedSubtree(key: const ValueKey('menu'), child: _menu());
        case _Stage.entry:
          screen = KeyedSubtree(
              key: const ValueKey('entry'), child: _framed(520, _entry()));
      }
    }

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
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

  Widget _framed(double maxW, Widget child) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );

  /// Latar bentang yang bergerak pelan (zoom dan geser), dengan kunang-kunang
  /// dan, di layar judul, berkas cahaya hangat dari atas.
  Widget _background(String stem, bool title) => AnimatedBuilder(
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
              tween: Tween<double>(end: title ? 1.0 : 0.0),
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
        onTap: _booted ? _start : null,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 3400),
          builder: (context, t, _) {
            final lt = _smooth(_seg(t, 0.0, 0.5));
            final st = _smooth(_seg(t, 0.42, 0.7));
            final bt = _smooth(_seg(t, 0.62, 0.9));
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
                                    'BALAI PERTEMUAN DESA V2.1.0',
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
    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
  );

  /// Panduan kini layar penuh (cara bermain, karakter, dan kartu item).
  void _openGuide() => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const GuidePage()));

  Widget _menu() {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 720;
      final items = <_MenuTile>[
        _MenuTile(
            index: 0,
            icon: 'roomcreate',
            label: 'Buat Ruangan',
            center: !wide,
            onTap: () => _openEntry(false)),
        _MenuTile(
            index: 1,
            icon: 'joinroom',
            label: 'Gabung Ruangan',
            center: !wide,
            onTap: () => _openEntry(true)),
        _MenuTile(
            index: 2,
            icon: 'info',
            label: 'Panduan',
            center: !wide,
            onTap: _openGuide),
        _MenuTile(
            index: 3,
            icon: 'plus',
            label: 'Permainan Lainnya',
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
                if (wide)
                  Positioned(
                    left: 56,
                    bottom: 56,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        logo(min(380.0, c.maxWidth * 0.34)),
                        const SizedBox(width: 56),
                        menuCol,
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 48, 24, 36),
                    child: Column(
                      children: [
                        logo(min(320.0, c.maxWidth - 48)),
                        const Spacer(),
                        menuCol,
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

  // ====================== 3. ISIAN (nama / kode) ======================

  Widget _panel(Widget child) =>
      _Glass(padding: const EdgeInsets.all(20), child: child);

  Widget _entry() {
    final join = _joinMode;
    return SingleChildScrollView(
      child: _panel(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _backButton(busy
                    ? () {}
                    : () => setState(() => _stage = _Stage.menu)),
                Expanded(
                  child: SectionHeader(
                    icon: join ? 'joinroom' : 'roomcreate',
                    title: join ? 'Gabung Ruangan' : 'Buat Ruangan',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 84,
              child: GameImage(
                  path: logoPath('logoteks-transparent'),
                  fit: BoxFit.contain,
                  cacheWidth: 600),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              maxLength: 20,
              decoration: const InputDecoration(
                labelText: 'Namamu',
                prefixIcon: Padding(
                  padding: EdgeInsets.all(6),
                  child: GameIcon('identity', size: 30),
                ),
              ),
            ),
            if (join) ...[
              const SizedBox(height: 6),
              TextField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Kode ruangan',
                  prefixIcon: Padding(
                    padding: EdgeInsets.all(6),
                    child: GameIcon('roomcode', size: 30),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            EmbunButton(
              label: join ? 'Gabung' : 'Buat Ruangan',
              icon: join ? 'joinroom' : 'roomcreate',
              expand: true,
              onPressed: busy
                  ? null
                  : join
                  ? () {
                if (codeCtrl.text.trim().isEmpty) {
                  return _toast('Isi kode ruangan dulu');
                }
                _run((card) => repo.joinGame(
                    codeCtrl.text.trim(), nameCtrl.text, card));
              }
                  : () =>
                  _run((card) => repo.createGame(nameCtrl.text, card)),
            ),
          ],
        ),
      ),
    );
  }

  // ====================== RUANGAN (lobi) ======================

  Future<void> _pickCard(String id, Map<String, dynamic> me) async {
    if (me['ready'] == true) return; // terkunci selama siap
    final stems = AssetCatalog.I.stems(protagonisDir);
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
    return StreamBuilder<Map<String, dynamic>?>(
      stream: repo.game(id),
      builder: (context, gs) {
        final game = gs.data;
        if (game == null) {
          // Sudah menerima data tetapi barisnya hilang: ruangan dibubarkan.
          if (gs.connectionState != ConnectionState.waiting) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || gameId != id) return;
              setState(() {
                gameId = null;
                _stage = _Stage.menu;
              });
              _toast('Ruangan sudah dibubarkan');
            });
          }
          return const EmbunLoading();
        }
        if (game['status'] != 'lobby') {
          if (!_navigated) {
            _navigated = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => PrologueFlow(gameId: id, repo: repo),
                ),
              );
            });
          }
          return const EmbunLoading();
        }
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: repo.players(id),
          builder: (context, ps) {
            final players = ps.data ?? [];
            final mine = players.where((p) => p['user_id'] == repo.myId);
            final me = mine.isEmpty ? null : mine.first;
            return _RoomShell(
              gr: _gr,
              gameId: id,
              players: players,
              room: _roomContent(id, game, players, me),
            );
          },
        );
      },
    );
  }

  Future<void> _setReady(String id, bool v) async {
    try {
      await repo.setReady(id, v);
    } catch (e) {
      _toast(errMsg(e));
    }
  }

  Widget _roomContent(String id, Map<String, dynamic> game,
      List<Map<String, dynamic>> players, Map<String, dynamic>? me) {
    final isHost = game['host_id'] == repo.myId;
    final hostId = game['host_id'] as String;
    final myCard = (me?['character_card'] as String?) ?? 'default';
    final iReady = me?['ready'] == true;
    final readyN = players.where((p) => p['ready'] == true).length;
    final canStart = players.length >= 3 && readyN == players.length;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: 48,
                child: GameImage(
                    path: logoPath('logoteks-transparent'),
                    fit: BoxFit.contain,
                    cacheWidth: 600),
              ),
              const SizedBox(height: 10),
              _codeHeader(game['code'] as String),
              const SizedBox(height: 14),
              _meCard(id, me, myCard, iReady),
              const SizedBox(height: 12),
              iReady
                  ? EmbunButton(
                label: 'Siap. Ketuk untuk batal',
                icon: 'centang',
                kind: EmbunButtonKind.secondary,
                expand: true,
                onPressed: me == null ? null : () => _setReady(id, false),
              )
                  : EmbunButton(
                label: 'Siap',
                icon: 'centang',
                expand: true,
                onPressed: me == null ? null : () => _setReady(id, true),
              ),
              const SizedBox(height: 20),
              SectionHeader(
                icon: 'persona',
                title: 'Pemain ${players.length}/8 · siap $readyN',
              ),
              const SizedBox(height: 10),
              for (final p in players) _playerTile(p, hostId),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (isHost)
          EmbunButton(
            label: canStart
                ? 'Mulai'
                : players.length < 3
                ? 'Menunggu pemain (min. 3)'
                : 'Menunggu semua siap ($readyN/${players.length})',
            icon: 'start',
            expand: true,
            onPressed: canStart
                ? () async {
              try {
                await repo.startGame(id);
              } catch (e) {
                _toast(errMsg(e));
              }
            }
                : null,
          ),
        const SizedBox(height: 8),
        EmbunButton(
          label: isHost ? 'Bubarkan ruangan' : 'Keluar',
          icon: isHost ? 'bubarkan' : 'keluar',
          kind: EmbunButtonKind.secondary,
          expand: true,
          height: 44,
          onPressed: () async {
            // Keluar dulu agar penghapusan ruangan tidak memicu
            // pesan "dibubarkan" untuk host sendiri.
            setState(() {
              gameId = null;
              _stage = _Stage.menu;
            });
            try {
              await repo.leave(id);
            } catch (e) {
              if (!mounted) return;
              setState(() => gameId = id);
              _toast(errMsg(e));
            }
          },
        ),
      ],
    );
  }

  Widget _codeHeader(String code) => Container(
    padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: EmbunColors.goldDim.withValues(alpha: 0.4)),
    ),
    child: Row(
      children: [
        const GameIcon('roomcode', size: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kode ruangan',
                  style: TextStyle(fontSize: 11, color: Colors.white60)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  code,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                    color: EmbunColors.gold,
                  ),
                ),
              ),
            ],
          ),
        ),
        MedallionButton(
          icon: 'salin',
          label: 'Salin',
          size: 40,
          onTap: () {
            Clipboard.setData(ClipboardData(text: code));
            _toast('Kode disalin');
          },
        ),
      ],
    ),
  );

  Widget _meCard(
      String id, Map<String, dynamic>? me, String myCard, bool iReady) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: EmbunColors.goldDim.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            CardArt(path: protagonistPath(myCard), width: 78),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(me?['name'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: EmbunColors.gold)),
                  Text(characterTitle(myCard),
                      style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 10),
                  EmbunButton(
                    label: iReady ? 'Kartu terkunci' : 'Ganti kartu',
                    icon: iReady ? 'lock' : 'customization',
                    kind: EmbunButtonKind.secondary,
                    height: 46,
                    onPressed:
                    me == null || iReady ? null : () => _pickCard(id, me),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _playerTile(Map<String, dynamic> p, String hostId) {
    final ready = p['ready'] == true;
    final isMe = p['user_id'] == repo.myId;
    final isHostP = p['user_id'] == hostId;
    final card = p['character_card'] as String;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ready
              ? EmbunColors.leaf.withValues(alpha: 0.7)
              : EmbunColors.goldDim.withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        leading: PlayerAvatar(
          path: protagonistPath(card),
          size: 44,
          ring: isMe ? EmbunColors.gold : EmbunColors.goldDim,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(p['name'] as String,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (isHostP)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.fromLTRB(2, 1, 8, 1),
                decoration: BoxDecoration(
                  color: EmbunColors.gold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GameIcon('host', size: 20),
                    SizedBox(width: 3),
                    Text('Host',
                        style:
                        TextStyle(fontSize: 11, color: EmbunColors.gold)),
                  ],
                ),
              ),
          ],
        ),
        subtitle: Text(characterTitle(card)),
        trailing: GameIcon(ready ? 'centang' : 'wait', size: 32),
      ),
    );
  }
}

/// Satu butir menu utama: ikon medali + teks. Muncul bergantian dari kiri;
/// saat disentuh atau disorot, teks beralih emas, bergeser, dan bertitik.
class _MenuTile extends StatefulWidget {
  final int index;
  final String icon;
  final String label;
  final bool center;
  final VoidCallback onTap;
  const _MenuTile({
    required this.index,
    required this.icon,
    required this.label,
    required this.onTap,
    this.center = false,
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
                GameIcon(widget.icon, size: 34),
                const SizedBox(width: 12),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 160),
                  style: TextStyle(
                    fontSize: 22,
                    letterSpacing: 1.2,
                    fontWeight: _on ? FontWeight.bold : FontWeight.w500,
                    color: _on ? EmbunColors.gold : EmbunColors.cream,
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 10),
                    ],
                  ),
                  child: Text(widget.label),
                ),
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

/// Panel kaca gelap yang dipakai bersama oleh layar isian, ruangan, dan obrolan.
class _Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Glass({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) =>
      OrnatePanel(padding: padding, child: child);
}

/// Tata letak ruangan yang responsif:
/// - layar lebar (>= 820 px): ruangan di kiri, obrolan di kanan;
/// - ponsel: dua halaman yang digeser (ruangan, lalu obrolan di kanan).
class _RoomShell extends StatefulWidget {
  final GameRepository gr;
  final String gameId;
  final List<Map<String, dynamic>> players;
  final Widget room;
  const _RoomShell({
    required this.gr,
    required this.gameId,
    required this.players,
    required this.room,
  });

  @override
  State<_RoomShell> createState() => _RoomShellState();
}

class _RoomShellState extends State<_RoomShell> {
  static const _wideBreakpoint = 820.0;
  final _pc = PageController();
  int page = 0;
  int seen = 0;
  late final Stream<List<Map<String, dynamic>>> chat =
  widget.gr.chat(widget.gameId);

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Widget _chatPane() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionHeader(icon: 'discuss', title: 'Obrolan Desa'),
      const SizedBox(height: 8),
      Expanded(
        child: ChatPanel(
          repo: widget.gr,
          gameId: widget.gameId,
          players: widget.players,
          lobby: true,
        ),
      ),
    ],
  );

  void _goto(int i) => _pc.animateToPage(i,
      duration: const Duration(milliseconds: 280), curve: Curves.easeOut);

  Widget _tabs(int unread) => Row(
    children: [
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          avatar: const GameIcon('persona', size: 26),
          label: Text('Ruangan (${widget.players.length})'),
          selected: page == 0,
          visualDensity: VisualDensity.compact,
          onSelected: (_) => _goto(0),
        ),
      ),
      Badge(
        isLabelVisible: unread > 0 && page != 1,
        label: Text('$unread'),
        child: ChoiceChip(
          avatar: const GameIcon('discuss', size: 26),
          label: const Text('Obrolan'),
          selected: page == 1,
          visualDensity: VisualDensity.compact,
          onSelected: (_) => _goto(1),
        ),
      ),
      const Spacer(),
      if (page == 0)
        const Text('Geser untuk obrolan',
            style: TextStyle(fontSize: 11, color: Colors.white54)),
      if (page == 0) const GameIcon('skip2', size: 22),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= _wideBreakpoint) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _Glass(child: widget.room)),
            const SizedBox(width: 16),
            SizedBox(width: 380, child: _Glass(child: _chatPane())),
          ],
        );
      }
      return StreamBuilder<List<Map<String, dynamic>>>(
        stream: chat,
        builder: (context, s) {
          final count = (s.data ?? [])
              .where((m) => m['user_id'] != widget.gr.myId)
              .length;
          if (page == 1) seen = count;
          final unread = count - seen;
          return Column(
            children: [
              _tabs(unread),
              const SizedBox(height: 8),
              Expanded(
                child: PageView(
                  controller: _pc,
                  onPageChanged: (i) => setState(() {
                    page = i;
                    if (i == 1) seen = count;
                  }),
                  children: [
                    _KeepAlive(child: _Glass(child: widget.room)),
                    _KeepAlive(child: _Glass(child: _chatPane())),
                  ],
                ),
              ),
            ],
          );
        },
      );
    });
  }
}

class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});
  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}