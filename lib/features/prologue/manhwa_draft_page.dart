import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../../data/lobby_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import '../common/sfx.dart';
import '../lobby/lobby_page.dart';
import 'prologue_page.dart';

/// Warna aksen tiap tokoh: dipakai untuk cahaya latar, glow kartu, dan cincin.
const _accents = <String, Color>{
  'baekseoyeon': Color(0xFF9AA8C4),
  'chahyunjae': Color(0xFFE0645A),
  'chaminhyuk': Color(0xFFE87BB0),
  'choinari': Color(0xFFF29BC0),
  'hanseoah': Color(0xFFE8708F),
  'hanseoyul': Color(0xFFF2D58A),
  'kangjiwoo': Color(0xFF9B86D4),
  'kimdasol': Color(0xFF7FC6A4),
  'kwontaehyuk': Color(0xFFC4473F),
  'leejunseo': Color(0xFFC59A6A),
  'namseojun': Color(0xFF4F7CAC),
};
Color _accentFor(String? characterId) =>
    _accents[characterId] ?? EmbunColors.gold;

class ManhwaDraftPage extends StatefulWidget {
  const ManhwaDraftPage({super.key, required this.repo, required this.gameId});
  final LobbyRepository repo;
  final String gameId;
  @override
  State<ManhwaDraftPage> createState() => _ManhwaDraftPageState();
}

class _ManhwaDraftPageState extends State<ManhwaDraftPage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _state;
  String? _selected, _error;
  bool _busy = false,
      _loading = false,
      _navigated = false,
      _wasDrafting = false;
  Timer? _timer, _clock;

  // Efek bersama (kilau, denyut). Satu controller untuk seluruh halaman.
  late final AnimationController _fx = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat();

  // Hitung mundur lokal supaya cincin waktu halus di antara dua polling.
  final ValueNotifier<int?> _left = ValueNotifier<int?>(null);
  int? _syncSecs;
  DateTime? _syncAt;
  int _maxSecs = 0;
  String? _lastStage;
  bool _warned = false;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _load());
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tickClock());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clock?.cancel();
    _fx.dispose();
    _left.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- waktu

  void _syncClock(Map<String, dynamic> state) {
    final raw = state['seconds_left'];
    if (raw is num) {
      final secs = raw.toInt();
      final stage = '${state['stage']}';
      if (stage != _lastStage) {
        _lastStage = stage;
        _maxSecs = secs;
        _warned = false;
      } else if (secs > _maxSecs) {
        _maxSecs = secs;
      }
      if (secs > 10) _warned = false;
      _syncSecs = secs;
      _syncAt = DateTime.now();
      _left.value = secs;
      _maybeWarn(secs);
    } else {
      _syncSecs = null;
      _left.value = null;
    }
  }

  void _tickClock() {
    final base = _syncSecs, at = _syncAt;
    if (base == null || at == null) return;
    final left = math.max(0, base - DateTime.now().difference(at).inSeconds);
    if (_left.value != left) {
      _left.value = left;
      _maybeWarn(left);
    }
  }

  void _maybeWarn(int left) {
    if (left > 0 && left <= 10 && !_warned) {
      _warned = true;
      unawaited(Sfx.I.play(Snd.timer1, tag: 'draft-timer'));
    }
  }

  // ---------------------------------------------------------------- logika

  void _accept(Map<String, dynamic> state) {
    if (!mounted) return;
    final characters = state['stage'] == 'characters';
    final items = (state[characters ? 'characters' : 'outfits'] as List? ?? [])
        .cast<Map>();
    final canKeepSelection =
        state['status'] == 'prologue' &&
            _state?['stage'] == state['stage'] &&
            (characters
                ? state['turn'] == widget.repo.myId
                : (state['own'] as Map?)?['outfit_card'] == null) &&
            items.any((item) => item['id'] == _selected && item['taken'] != true);
    _syncClock(state);
    setState(() {
      _state = state;
      if (!canKeepSelection) _selected = null;
      _error = null;
    });
    if (state['status'] == 'prologue') _wasDrafting = true;
    if (_navigated) return;
    if (state['status'] == 'playing' || state['status'] == 'finished') {
      _navigated = true;
      _timer?.cancel();
      _clock?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Sfx.I.stopMenuMusic();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => state['status'] == 'playing'
                ? PrologueFlow(
              gameId: widget.gameId,
              repo: widget.repo,
              characterTheme: 'manhwa',
              resume: !_wasDrafting,
              antagonistCount: (state['antagonist_count'] as int?) ?? 1,
            )
                : const LobbyPage(startAtMenu: true),
          ),
        );
      });
    }
  }

  Future<void> _load() async {
    if (_loading || _busy || _navigated) return;
    _loading = true;
    try {
      _accept(await widget.repo.manhwaDraft(widget.gameId));
    } catch (e) {
      if (mounted) setState(() => _error = errMsg(e));
    } finally {
      _loading = false;
    }
  }

  Future<void> _confirm() async {
    if (_busy || _selected == null) return;
    final selected = _selected!;
    setState(() => _busy = true);
    try {
      final state = _state!['stage'] == 'characters'
          ? await widget.repo.chooseManhwaCharacter(widget.gameId, selected)
          : await widget.repo.chooseManhwaOutfit(widget.gameId, selected);
      Sfx.I.click(Snd.clickTung);
      _accept(state);
    } catch (e) {
      if (mounted) setState(() => _error = errMsg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelRoom() async {
    if (_busy) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bubarkan ruangan?'),
        content: const Text(
          'Pemilihan tokoh akan dihentikan untuk semua pemain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bubarkan'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repo.endGame(widget.gameId);
    } catch (e) {
      if (mounted) setState(() => _error = errMsg(e));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _load();
      }
    }
  }

  void _select(String id) {
    if (_selected == id) return;
    Sfx.I.click(Snd.click2);
    setState(() => _selected = id);
  }

  void _showRules(bool characters) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: EmbunColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Text(
            characters
                ? 'Setiap tokoh hanya bisa dipilih satu pemain. Urutan mengikuti pemain masuk ruangan. Jika waktu habis, tokoh dipilihkan otomatis.'
                : 'Setelah semua pakaian terkunci, peran dibagikan. Jika waktu habis, pakaian yang belum dipilih dikunci otomatis dari tokoh masing-masing.',
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: EmbunColors.cream,
            ),
          ),
        ),
      ),
    );
  }

  String? _avatarPath(Map p, bool characters, List<Map> items) {
    final oc = p['outfit_card'];
    if (oc != null) return protagonistPath('$oc');
    final cid = p['character_id'];
    if (cid == null) return null;
    if (characters) {
      for (final it in items) {
        if ('${it['id']}' == '$cid') return protagonistPath('${it['preview']}');
      }
    }
    for (final o in manhwaOutfits.values) {
      if (o.characterId == cid) return protagonistPath(o.id);
    }
    return null;
  }

  // ---------------------------------------------------------------- tampilan

  @override
  Widget build(BuildContext context) {
    final s = _state;
    final stage = s?['stage'];
    final own = s?['own'] as Map?;
    final characters = stage == 'characters';
    final mine = characters
        ? (s?['turn'] == widget.repo.myId)
        : (stage == 'outfits' && (own?['outfit_card'] == null));
    final players = (s?['players'] as List? ?? []).cast<Map>();
    final turnPlayer = players
        .where((p) => p['user_id'] == s?['turn'])
        .firstOrNull;
    final turnName = turnPlayer == null
        ? 'pemain berikutnya'
        : '${turnPlayer['name']}';
    final items = (s?[characters ? 'characters' : 'outfits'] as List? ?? [])
        .cast<Map>();
    final locked = stage == 'outfits' && (own?['outfit_card'] != null);

    String? charOf(String? id) =>
        characters ? id : manhwaOutfits[id]?.characterId;
    final String? accentChar = _selected != null
        ? charOf(_selected)
        : locked
        ? manhwaOutfits['${own?['outfit_card']}']?.characterId
        : (!characters && items.isNotEmpty
        ? manhwaOutfits['${items.first['id']}']?.characterId
        : null);
    final accent = _accentFor(accentChar);

    final selItem = items
        .where((it) => '${it['id']}' == _selected)
        .firstOrNull;
    final selLabel = selItem == null
        ? null
        : '${characters ? selItem['name'] : selItem['label']}';
    final selPath = selItem == null
        ? null
        : protagonistPath('${characters ? selItem['preview'] : selItem['id']}');

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF07050E),
        body: Stack(
          fit: StackFit.expand,
          children: [
            _StageBackdrop(accent: accent),
            SafeArea(
              child: s == null
                  ? Center(
                child: _error == null
                    ? const EmbunLoading(text: 'Memuat pilihan…')
                    : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              )
                  : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    children: [
                      _DraftHeader(
                        accent: accent,
                        eyebrow: characters
                            ? 'TAHAP 1 · TOKOH'
                            : 'TAHAP 2 · PAKAIAN',
                        title: characters
                            ? (mine ? 'GILIRANMU' : 'MENUNGGU GILIRAN')
                            : (locked ? 'TERKUNCI' : 'PILIH PAKAIAN'),
                        subtitle: characters
                            ? (mine
                            ? 'Pilih tokoh yang akan kamu mainkan'
                            : '$turnName sedang memilih tokoh')
                            : (locked
                            ? 'Pakaianmu sudah terkunci'
                            : 'Tentukan penampilan tokohmu'),
                        left: _left,
                        maxSecs: _maxSecs,
                        fx: _fx,
                        isHost: s['host_id'] == widget.repo.myId,
                        busy: _busy,
                        onCancel: _cancelRoom,
                        onInfo: () => _showRules(characters),
                      ),
                      _PlayerStrip(
                        players: players,
                        characters: characters,
                        turnId: s['turn'],
                        myId: widget.repo.myId,
                        accent: accent,
                        fx: _fx,
                        avatarOf: (p) => _avatarPath(p, characters, items),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Colors.orangeAccent,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _busy ? null : _load,
                                child: const Text('Muat ulang'),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: locked
                            ? _LockedHero(
                          path: protagonistPath(
                            '${own!['outfit_card']}',
                          ),
                          accent: accent,
                          fx: _fx,
                          waiting: [
                            for (final p in players)
                              if (p['outfit_card'] == null)
                                '${p['name']}',
                          ],
                        )
                            : items.isEmpty
                            ? const Center(
                          child: Text('Belum ada pilihan.'),
                        )
                            : characters
                            ? _CharacterGrid(
                          items: items,
                          players: players,
                          selectedId: _selected,
                          enabled: mine && !_busy,
                          accentOf: _accentFor,
                          fx: _fx,
                          onSelect: _select,
                        )
                            : LayoutBuilder(
                          builder: (_, c) {
                            final f = c.maxWidth < 600
                                ? 0.62
                                : c.maxWidth < 900
                                ? 0.42
                                : 0.3;
                            return _OutfitCarousel(
                              key: ValueKey('car-$f'),
                              fraction: f,
                              items: items,
                              selectedId: _selected,
                              enabled: mine && !_busy,
                              accent: accent,
                              fx: _fx,
                              onSelect: _select,
                            );
                          },
                        ),
                      ),
                      if (!locked)
                        _BottomBar(
                          mine: mine,
                          busy: _busy,
                          characters: characters,
                          label: selLabel,
                          previewPath: selPath,
                          turnName: turnName,
                          accent: accent,
                          onConfirm: _selected == null || _busy
                              ? null
                              : _confirm,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// Latar
// ======================================================================

class _StageBackdrop extends StatelessWidget {
  const _StageBackdrop({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1B1430), Color(0xFF110D20), Color(0xFF07050E)],
            ),
          ),
        ),
        TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: accent),
          duration: const Duration(milliseconds: 700),
          builder: (_, c, _) => DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.85),
                radius: 1.15,
                colors: [
                  (c ?? accent).withValues(alpha: 0.30),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        const RepaintBoundary(child: CustomPaint(painter: _ComicPainter())),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.15,
                colors: [Colors.transparent, Color(0x99000000)],
                stops: [0.55, 1],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Garis kecepatan ala panel komik + halftone di dasar layar.
class _ComicPainter extends CustomPainter {
  const _ComicPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final center = Offset(size.width / 2, size.height * 0.30);
    final line = Paint()..color = Colors.white.withValues(alpha: 0.035);
    final reach = size.longestSide * 1.2;
    for (var i = 0; i < 44; i++) {
      final a = (i / 44) * math.pi * 2 + rnd.nextDouble() * 0.08;
      final w = 0.006 + rnd.nextDouble() * 0.012;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + math.cos(a - w) * reach,
          center.dy + math.sin(a - w) * reach,
        )
        ..lineTo(
          center.dx + math.cos(a + w) * reach,
          center.dy + math.sin(a + w) * reach,
        )
        ..close();
      canvas.drawPath(path, line);
    }
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.05);
    const gap = 18.0;
    final top = size.height * 0.68;
    for (var y = top; y < size.height; y += gap) {
      final k = (y - top) / (size.height - top);
      final row = ((y - top) / gap).floor();
      for (var x = (row.isOdd ? gap / 2 : 0.0); x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 0.5 + 2.2 * k, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ======================================================================
// Header, cincin waktu, strip pemain
// ======================================================================

class _DraftHeader extends StatelessWidget {
  const _DraftHeader({
    required this.accent,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.left,
    required this.maxSecs,
    required this.fx,
    required this.isHost,
    required this.busy,
    required this.onCancel,
    required this.onInfo,
  });
  final Color accent;
  final String eyebrow, title, subtitle;
  final ValueListenable<int?> left;
  final int maxSecs;
  final Animation<double> fx;
  final bool isHost, busy;
  final VoidCallback onCancel, onInfo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 10, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    title,
                    key: ValueKey(title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                      color: EmbunColors.cream,
                      shadows: [
                        Shadow(
                          color: accent.withValues(alpha: 0.65),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<int?>(
            valueListenable: left,
            builder: (_, v, _) => v == null
                ? const SizedBox.shrink()
                : _TimerRing(
              left: v,
              total: math.max(maxSecs, math.max(v, 1)),
              fx: fx,
            ),
          ),
          IconButton(
            tooltip: 'Aturan',
            onPressed: onInfo,
            icon: const Icon(Icons.info_outline, color: Colors.white70),
          ),
          if (isHost)
            IconButton(
              tooltip: 'Bubarkan ruangan',
              onPressed: busy ? null : onCancel,
              icon: const Icon(Icons.close, color: Colors.white70),
            ),
        ],
      ),
    );
  }
}

class _TimerRing extends StatelessWidget {
  const _TimerRing({
    required this.left,
    required this.total,
    required this.fx,
  });
  final int left, total;
  final Animation<double> fx;

  @override
  Widget build(BuildContext context) {
    final urgent = left <= 10;
    return AnimatedBuilder(
      animation: fx,
      builder: (_, _) {
        final pulse = urgent
            ? 0.5 + 0.5 * math.sin(fx.value * math.pi * 4)
            : 0.0;
        final color = urgent
            ? Color.lerp(EmbunColors.gold, EmbunColors.blood, 0.4 + 0.6 * pulse)!
            : EmbunColors.gold;
        return Transform.scale(
          scale: 1 + 0.06 * pulse,
          child: SizedBox(
            width: 54,
            height: 54,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(54, 54),
                  painter: _RingPainter((left / total).clamp(0.0, 1.0), color),
                ),
                Text(
                  '$left',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color);
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(4);
    canvas.drawArc(
      r,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.white12,
    );
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.progress != progress || o.color != color;
}

class _PlayerStrip extends StatelessWidget {
  const _PlayerStrip({
    required this.players,
    required this.characters,
    required this.turnId,
    required this.myId,
    required this.accent,
    required this.fx,
    required this.avatarOf,
  });
  final List<Map> players;
  final bool characters;
  final Object? turnId, myId;
  final Color accent;
  final Animation<double> fx;
  final String? Function(Map) avatarOf;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 84,
      child: LayoutBuilder(
        builder: (_, c) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: c.maxWidth - 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final p in players)
                  _PlayerChip(
                    name: '${p['name']}',
                    path: avatarOf(p),
                    isMe: p['user_id'] == myId,
                    isTurn: characters && p['user_id'] == turnId,
                    done: characters
                        ? p['character_id'] != null
                        : p['outfit_card'] != null,
                    accent: accent,
                    fx: fx,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  const _PlayerChip({
    required this.name,
    required this.path,
    required this.isMe,
    required this.isTurn,
    required this.done,
    required this.accent,
    required this.fx,
  });
  final String name;
  final String? path;
  final bool isMe, isTurn, done;
  final Color accent;
  final Animation<double> fx;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 66,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: fx,
            builder: (_, child) {
              final pulse = isTurn
                  ? 0.5 + 0.5 * math.sin(fx.value * math.pi * 2)
                  : 0.0;
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: isTurn
                      ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35 + 0.35 * pulse),
                      blurRadius: 8 + 10 * pulse,
                      spreadRadius: 1 + 2 * pulse,
                    ),
                  ]
                      : null,
                ),
                child: child,
              );
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Opacity(
                  opacity: done || isTurn ? 1 : 0.55,
                  child: PlayerAvatar(
                    path: path,
                    size: 40,
                    ring: isTurn
                        ? accent
                        : done
                        ? EmbunColors.leaf
                        : Colors.white30,
                  ),
                ),
                if (done)
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: EmbunColors.leaf,
                        border: Border.all(
                          color: const Color(0xFF07050E),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 11,
                        color: Color(0xFF07130F),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isMe ? '$name (kamu)' : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isMe ? FontWeight.w800 : FontWeight.w500,
              color: isMe ? EmbunColors.gold : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// Kartu
// ======================================================================

class _DraftCard extends StatefulWidget {
  const _DraftCard({
    super.key,
    required this.path,
    required this.accent,
    required this.fx,
    required this.label,
    this.selected = false,
    this.taken = false,
    this.takenBy,
    this.onTap,
  });
  final String? path;
  final Color accent;
  final Animation<double> fx;
  final String label;
  final bool selected, taken;
  final String? takenBy;
  final VoidCallback? onTap;

  @override
  State<_DraftCard> createState() => _DraftCardState();
}

class _DraftCardState extends State<_DraftCard> {
  Offset _tilt = Offset.zero;
  bool _down = false;

  void _hover(PointerEvent e, Size size) {
    if (widget.onTap == null || size.isEmpty) return;
    setState(() {
      _tilt = Offset(
        (e.localPosition.dx / size.width) * 2 - 1,
        (e.localPosition.dy / size.height) * 2 - 1,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxWidth * kTallAspect);
        final sel = w.selected;
        Widget art = CardArt(
          path: w.path,
          width: size.width,
          glow: sel ? w.accent : null,
        );
        if (w.taken) {
          art = ColorFiltered(
            colorFilter: const ColorFilter.mode(
              Colors.grey,
              BlendMode.saturation,
            ),
            child: art,
          );
        }
        final card = SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              art,
              if (sel)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedBuilder(
                        animation: w.fx,
                        builder: (_, _) {
                          final t = w.fx.value;
                          final p = math.sin(t * math.pi * 2);
                          return DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: w.accent.withValues(
                                  alpha: 0.8 + 0.2 * p,
                                ),
                                width: 3,
                              ),
                              gradient: LinearGradient(
                                begin: Alignment(-2 + 4 * t, -1),
                                end: Alignment(-1 + 4 * t, 1),
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: 0.24),
                                  Colors.white.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              if (sel)
                Positioned(
                  top: -7,
                  right: -7,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: w.accent,
                      border: Border.all(
                        color: const Color(0xFF07050E),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 16,
                      color: Color(0xFF07050E),
                    ),
                  ),
                ),
              if (w.taken)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ColoredBox(
                        color: const Color(0x99000000),
                        child: Center(
                          child: Transform.rotate(
                            angle: -0.2,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: size.width * 0.88,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xCC1A0A0C),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: EmbunColors.blood,
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'DIPILIH',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 3,
                                        color: EmbunColors.blood,
                                      ),
                                    ),
                                    if (w.takenBy != null)
                                      Text(
                                        w.takenBy!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: EmbunColors.cream,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );

        final tilt = Matrix4.identity()
          ..setEntry(3, 2, 0.0014)
          ..rotateX(-_tilt.dy * 0.14)
          ..rotateY(_tilt.dx * 0.14);

        return Semantics(
          button: true,
          selected: sel,
          enabled: w.onTap != null,
          label: w.label,
          child: MouseRegion(
            cursor: w.onTap == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            onHover: (e) => _hover(e, size),
            onExit: (_) => setState(() => _tilt = Offset.zero),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: w.onTap == null
                  ? null
                  : (_) => setState(() => _down = true),
              onTapUp: (_) => setState(() => _down = false),
              onTapCancel: () => setState(() => _down = false),
              onTap: w.onTap,
              child: AnimatedScale(
                scale: sel ? 1.05 : (_down ? 0.96 : 1),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: Transform(
                  alignment: Alignment.center,
                  transform: tilt,
                  child: card,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ======================================================================
// Tahap 1: grid tokoh
// ======================================================================

class _CharacterGrid extends StatelessWidget {
  const _CharacterGrid({
    required this.items,
    required this.players,
    required this.selectedId,
    required this.enabled,
    required this.accentOf,
    required this.fx,
    required this.onSelect,
  });
  final List<Map> items, players;
  final String? selectedId;
  final bool enabled;
  final Color Function(String?) accentOf;
  final Animation<double> fx;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = (c.maxWidth / 170).floor().clamp(2, 6);
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: 1 / kTallAspect,
            crossAxisSpacing: 16,
            mainAxisSpacing: 18,
          ),
          itemBuilder: (context, i) {
            final item = items[i];
            final id = '${item['id']}';
            final taken = item['taken'] == true;
            String? takenBy;
            if (taken) {
              final owner = players
                  .where((p) => '${p['character_id']}' == id)
                  .firstOrNull;
              if (owner != null) takenBy = '${owner['name']}';
            }
            return TweenAnimationBuilder<double>(
              key: ValueKey('manhwa-$id'),
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 380 + 50 * math.min(i, 10)),
              curve: Curves.easeOutCubic,
              builder: (_, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 26 * (1 - t)),
                  child: child,
                ),
              ),
              child: _DraftCard(
                path: protagonistPath('${item['preview']}'),
                accent: accentOf(id),
                fx: fx,
                label: '${item['name']}${taken ? ', sudah dipilih' : ''}',
                selected: selectedId == id,
                taken: taken,
                takenBy: takenBy,
                onTap: !enabled || taken ? null : () => onSelect(id),
              ),
            );
          },
        );
      },
    );
  }
}

// ======================================================================
// Tahap 2: carousel pakaian
// ======================================================================

class _OutfitCarousel extends StatefulWidget {
  const _OutfitCarousel({
    super.key,
    required this.fraction,
    required this.items,
    required this.selectedId,
    required this.enabled,
    required this.accent,
    required this.fx,
    required this.onSelect,
  });
  final double fraction;
  final List<Map> items;
  final String? selectedId;
  final bool enabled;
  final Color accent;
  final Animation<double> fx;
  final void Function(String) onSelect;

  @override
  State<_OutfitCarousel> createState() => _OutfitCarouselState();
}

class _OutfitCarouselState extends State<_OutfitCarousel> {
  late final PageController _pc;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    final idx = widget.items.indexWhere(
          (e) => '${e['id']}' == widget.selectedId,
    );
    _page = idx < 0 ? 0 : idx;
    _pc = PageController(
      initialPage: _page,
      viewportFraction: widget.fraction,
    );
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final cur = items[_page.clamp(0, items.length - 1)];
    final id0 = '${cur['id']}';
    final label = '${cur['label'] ?? manhwaOutfits[id0]?.label ?? ''}';
    final parts = label.split(' · ');
    final title = parts.first;
    final sub = parts.length > 1 ? parts.sublist(1).join(' · ') : null;

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pc,
            itemCount: items.length,
            onPageChanged: (i) {
              setState(() => _page = i);
              if (widget.enabled) widget.onSelect('${items[i]['id']}');
            },
            itemBuilder: (context, i) {
              final item = items[i];
              final id = '${item['id']}';
              return AnimatedBuilder(
                animation: _pc,
                builder: (context, child) {
                  var page = _page.toDouble();
                  if (_pc.hasClients && _pc.position.haveDimensions) {
                    page = _pc.page ?? page;
                  }
                  final d = (page - i).abs().clamp(0.0, 1.0).toDouble();
                  return Center(
                    child: Opacity(
                      opacity: 1 - 0.55 * d,
                      child: Transform.scale(scale: 1 - 0.2 * d, child: child),
                    ),
                  );
                },
                child: LayoutBuilder(
                  builder: (context, c) {
                    final h = c.maxHeight * 0.92;
                    final w = math.min(c.maxWidth * 0.9, h / kTallAspect);
                    return Center(
                      child: SizedBox(
                        width: w,
                        height: w * kTallAspect,
                        child: _DraftCard(
                          key: ValueKey('manhwa-$id'),
                          path: protagonistPath(id),
                          accent: widget.accent,
                          fx: widget.fx,
                          label: '${item['label'] ?? id}',
                          selected: widget.selectedId == id,
                          onTap: !widget.enabled
                              ? null
                              : () {
                            if (i != _page) {
                              _pc.animateToPage(
                                i,
                                duration: const Duration(
                                  milliseconds: 320,
                                ),
                                curve: Curves.easeOutCubic,
                              );
                            } else {
                              widget.onSelect(id);
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Column(
            key: ValueKey(label),
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: EmbunColors.cream,
                ),
              ),
              if (sub != null)
                Text(
                  sub,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 1,
                    color: widget.accent,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (items.length <= 12)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < items.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: i == _page ? widget.accent : Colors.white24,
                  ),
                ),
            ],
          )
        else
          Text(
            '${_page + 1} / ${items.length}',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        const SizedBox(height: 6),
        if (widget.enabled)
          const Text(
            'Geser untuk melihat · ketuk untuk memilih',
            style: TextStyle(fontSize: 11, color: Colors.white38),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ======================================================================
// Setelah terkunci
// ======================================================================

class _LockedHero extends StatelessWidget {
  const _LockedHero({
    required this.path,
    required this.accent,
    required this.fx,
    required this.waiting,
  });
  final String? path;
  final Color accent;
  final Animation<double> fx;
  final List<String> waiting;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = ((c.maxHeight - 130) / kTallAspect).clamp(120.0, 260.0);
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: fx,
              builder: (_, _) {
                final p = 0.5 + 0.5 * math.sin(fx.value * math.pi * 2);
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    CardArt(
                      path: path,
                      width: w,
                      glow: accent.withValues(alpha: 0.6 + 0.4 * p),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(-2 + 4 * fx.value, -1),
                                end: Alignment(-1 + 4 * fx.value, 1),
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: 0.22),
                                  Colors.white.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF07050E),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: accent, width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock, size: 13, color: accent),
                            const SizedBox(width: 6),
                            Text(
                              'TERKUNCI',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.5,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 34),
            const Text(
              'Menunggu pemain lain…',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            if (waiting.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
                child: Text(
                  waiting.join(' · '),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ======================================================================
// Bar bawah
// ======================================================================

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.mine,
    required this.busy,
    required this.characters,
    required this.label,
    required this.previewPath,
    required this.turnName,
    required this.accent,
    required this.onConfirm,
  });
  final bool mine, busy, characters;
  final String? label, previewPath;
  final String turnName;
  final Color accent;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x0007050E), Color(0xEE07050E)],
        ),
      ),
      child: mine
          ? Row(
        children: [
          Container(
            width: 40,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: label == null ? Colors.white12 : accent,
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: previewPath == null
                  ? const ColoredBox(color: Color(0x22FFFFFF))
                  : GameImage(path: previewPath, cacheWidth: 120),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  characters ? 'TOKOHMU' : 'PAKAIANMU',
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 2.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label ?? 'Belum dipilih',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: label == null
                        ? Colors.white38
                        : EmbunColors.cream,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          EmbunButton(
            label: busy
                ? 'Mengunci…'
                : characters
                ? 'Kunci tokoh'
                : 'Kunci pakaian',
            icon: 'lock',
            onPressed: onConfirm,
          ),
        ],
      )
          : Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Menunggu $turnName memilih tokoh…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}