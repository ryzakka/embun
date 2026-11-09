import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../../data/game_repository.dart';
import '../../data/server_clock.dart';
import '../common/art.dart';
import '../../data/errors.dart';
import '../common/ornate.dart';
import '../common/sfx.dart';
import 'day_chrome.dart';
import 'player_status.dart';

double _seg(double v, double a, double b) =>
    ((v - a) / (b - a)).clamp(0.0, 1.0).toDouble();

double _smooth(double x) => x * x * (3 - 2 * x);

/// Debar jantung: dua denyut pendek per putaran (u = 0..1).
double _thump(double u) {
  double f(double x) => x < 0 ? 0.0 : math.exp(-x * 16);
  return math.min(1.0, f(u) + 0.7 * f(u - 0.28));
}

class VotingView extends StatefulWidget {
  final GameRepository repo;
  final String gameId;

  /// Hanya pemain yang masih di desa.
  final List<Map<String, dynamic>> players;
  final int day;

  /// Suaraku sudah terkunci (pemain ditandai siap): tampilkan layar menunggu
  /// yang tegang, bukan daftar tersangka.
  final bool locked;
  final int readyCount;
  final int total;

  /// Pemain memegang Patuhilah Padaku yang belum terpakai.
  final bool hasHammer;
  final VoidCallback? onHammerUsed;

  const VotingView({
    super.key,
    required this.repo,
    required this.gameId,
    required this.players,
    required this.day,
    this.locked = false,
    this.readyCount = 0,
    this.total = 0,
    this.hasHammer = false,
    this.onHammerUsed,
  });

  @override
  State<VotingView> createState() => _VotingViewState();
}

class _VotingViewState extends State<VotingView>
    with TickerProviderStateMixin {
  String? target;
  bool busy = false;
  bool _hammer = false; // pakai Patuhilah Padaku pada suara ini

  // Segel suara: tampil sebentar sebelum suara benar-benar dikirim.
  bool stamping = false;
  String? stampId; // null = tidak memilih

  // Suara yang baru saja berhasil terkirim (menjembatani jeda sebelum
  // stream menandai pemain siap).
  bool _sent = false;
  String? _sentTarget;

  // Galat kirim ditampilkan di bilah aksi (SnackBar mengambang menutupi tombol).
  String? _error;

  // Denyut cahaya merah pada kartu yang dipilih. Hanya berjalan saat ada
  // pilihan supaya tidak memboroskan frame.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  // Pembukaan sidang: judul menghantam, lalu kartu tersangka masuk satu per
  // satu. 0.00-0.50 judul, 0.50-0.78 tirai terangkat, kartu masuk 0.50-0.96.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  final Set<int> _fired = {};

  @override
  void initState() {
    super.initState();
    Sfx.I.music(Snd.bgmVoting, owner: this);
    if (widget.locked) {
      // Masuk kembali setelah memilih: langsung ke layar menunggu.
      _intro.value = 1;
    } else {
      _intro.addListener(_onIntroTick);
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _intro.dispose();
    Sfx.I.release(this);
    super.dispose();
  }

  void _onIntroTick() {
    final t = _intro.value;
    if (t >= 0.10 && _fired.add(0)) HapticFeedback.heavyImpact();
    if (t >= 0.14 && _fired.add(1)) HapticFeedback.mediumImpact();
    if (t >= 0.52 && _fired.add(2)) HapticFeedback.selectionClick();
  }

  void _skipIntro() {
    if (_intro.value >= 0.5) return;
    _intro.animateTo(1.0,
        duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
  }

  Map<String, dynamic>? _player(String? id) {
    if (id == null) return null;
    for (final p in widget.players) {
      if (p['user_id'] == id) return p;
    }
    return null;
  }

  /// Ketuk kartu: memilih, atau ketuk lagi untuk membatalkan.
  void _select(String id) {
    final cancel = target == id;
    if (cancel) {
      HapticFeedback.selectionClick();
    } else {
      HapticFeedback.mediumImpact();
    }
    setState(() {
      target = cancel ? null : id;
      _error = null;
    });
    if (target == null) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  Future<void> _submit(String? t) async {
    _pulse.stop();
    setState(() {
      _error = null;
      busy = true;
      stamping = true;
      stampId = t;
    });
    HapticFeedback.heavyImpact();
    Future.delayed(
        const Duration(milliseconds: 380), HapticFeedback.heavyImpact);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    var ok = false;
    try {
      final useHammer = widget.hasHammer && _hammer && t != null;
      await widget.repo.submitVote(widget.gameId, t, hammer: useHammer);
      ok = true;
      if (useHammer) widget.onHammerUsed?.call();
    } catch (e) {
      if (mounted) setState(() => _error = errMsg(e));
    } finally {
      if (mounted) {
        setState(() {
          if (ok) {
            _sent = true;
            _sentTarget = t;
          } else {
            busy = false;
          }
          stamping = false;
        });
        if (!ok && target != null && !_pulse.isAnimating) {
          _pulse.repeat(reverse: true);
        }
      }
    }
  }

  void _showRules(int need) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aturan sidang'),
        content: SingleChildScrollView(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 13.5, height: 1.45),
              children: [
                TextSpan(
                  text: 'Butuh $need suara.\n\n',
                  style: const TextStyle(
                    color: EmbunColors.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const TextSpan(
                  text: 'Tuduhan pertama: dikurung sampai musyawarah '
                      'berikutnya dan Hayu kehilangan 1 daun.\n\n'
                      'Tuduhan kedua: Si Terbisik tertangkap, tapi warga '
                      'yang salah tuduh keluar dari desa.\n\n'
                      'Tiap pemain punya 2 nyawa.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  /// Hierarki layar: (1) judul + syarat suara, (2) daftar tersangka yang
  /// bisa digulir, (3) bilah aksi yang SELALU terlihat. Tata letak mengikuti
  /// ruang yang diberikan induk (bukan ukuran layar), jadi tidak tertindih
  /// header / deretan desa di ponsel.
  @override
  Widget build(BuildContext context) {
    final others =
    widget.players.where((p) => p['user_id'] != widget.repo.myId).toList();
    final need = widget.players.length ~/ 2 + 1;
    final showLocked = widget.locked || _sent;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.25,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            layoutBuilder: (current, previous) => Stack(
              fit: StackFit.expand,
              children: [...previous, ?current],
            ),
            child: showLocked
                ? _LockedView(
              key: const ValueKey('locked'),
              known: _sent,
              target: _player(_sentTarget),
              ready: widget.readyCount,
              total: widget.total,
            )
                : KeyedSubtree(
              key: const ValueKey('open'),
              child: LayoutBuilder(builder: (context, box) {
                // Ponsel miring: daftar di kiri, aksi di kanan.
                final side = box.maxWidth >= 600 && box.maxHeight < 440;
                final compact = side || box.maxHeight < 520;
                final list = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(need, compact),
                    SizedBox(height: compact ? 2 : 4),
                    Expanded(child: _suspects(others, compact)),
                  ],
                );
                if (side) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: list),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 250,
                        child: Center(
                          child: SingleChildScrollView(
                            child: _actionBar(compact: true, vertical: true),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: list),
                    SizedBox(height: compact ? 6 : 8),
                    _actionBar(compact: compact, vertical: false),
                  ],
                );
              }),
            ),
          ),
          if (stamping)
            Positioned.fill(child: _VoteStamp(player: _player(stampId))),
          if (!showLocked)
            Positioned.fill(
              child: _SessionIntro(
                  t: _intro, day: widget.day, onSkip: _skipIntro),
            ),
        ],
      ),
    );
  }

  /// Satu baris: ikon + judul, syarat suara, dan tombol aturan.
  Widget _header(int need, bool compact) {
    return Container(
      padding: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: EmbunColors.gold.withValues(alpha: 0.35), width: 1.2),
        ),
      ),
      child: Row(
        children: [
          GameIcon('vote', size: compact ? 24 : 28),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Siapa Si Terbisik?',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: EmbunColors.gold,
                fontWeight: FontWeight.bold,
                fontSize: compact ? 15 : 16,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: EmbunColors.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: EmbunColors.gold.withValues(alpha: 0.6)),
            ),
            child: Text(
              'Butuh $need suara',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: EmbunColors.gold),
            ),
          ),
          IconButton(
            tooltip: 'Aturan',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            padding: EdgeInsets.zero,
            onPressed: () => _showRules(need),
            icon: const GameIcon('question', size: 23),
          ),
        ],
      ),
    );
  }

  /// Daftar tersangka sebagai kartu karakter utuh (2:3), tersusun di tengah.
  /// Jumlah kolom dan lebar kartu dihitung dari RUANG YANG DIBERIKAN induk:
  /// dicari susunan terbesar yang semua kartunya muat tanpa menggulir. Bila
  /// pemain terlalu banyak untuk ukuran kartu yang masih terbaca, kartu
  /// dijaga di ukuran nyaman dan daftar digulir (kartu tak pernah terpotong).
  Widget _suspects(List<Map<String, dynamic>> others, bool compact) {
    if (others.isEmpty) {
      return const Center(
        child: Text('Belum ada pemain lain di desa.',
            style: TextStyle(color: Colors.white60)),
      );
    }
    return LayoutBuilder(builder: (context, c) {
      const hPad = 8.0;
      final vPad = compact ? 8.0 : 12.0;
      final gap = compact ? 8.0 : 12.0;
      final availW = math.max(c.maxWidth - hPad * 2, 60.0);
      final availH = math.max(c.maxHeight - vPad * 2, 60.0);
      final n = others.length;
      // Batas kartu yang masih nyaman dibaca / disentuh.
      const minW = 74.0;
      final maxW = c.maxWidth < 420 ? 128.0 : (c.maxWidth < 800 ? 150.0 : 168.0);

      double widthFor(int cols) => math.min(
          (availW - (cols - 1) * gap) / cols, maxW);

      // 1) Susunan terbesar yang seluruhnya muat tanpa menggulir.
      var cols = 0;
      var cardW = 0.0;
      for (var k = 1; k <= n; k++) {
        final w = widthFor(k);
        if (w < minW) break;
        final rows = (n / k).ceil();
        final total = rows * w * kProtagonistAspect + (rows - 1) * gap;
        if (total <= availH) {
          cols = k;
          cardW = w;
          break;
        }
      }
      // 2) Tak muat: pakai lebar kartu nyaman (~104) dan biarkan menggulir.
      if (cols == 0) {
        cols = math.max(1, ((availW + gap) / (104 + gap)).floor());
        cols = math.min(cols, n);
        cardW = math.max(widthFor(cols), math.min(minW, availW));
      }
      cardW = cardW.floorToDouble();
      final cardH = cardW * kProtagonistAspect;

      final items = <Widget>[
        for (var i = 0; i < n; i++)
              () {
            final p = others[i];
            final id = p['user_id'] as String;
            final sel = target == id;
            final slot = math.min(i, 7);
            final opacity = busy && !sel
                ? 0.45
                : (target != null && !sel ? 0.7 : 1.0);
            return SizedBox(
              width: cardW,
              height: cardH,
              child: AnimatedBuilder(
                animation: _intro,
                builder: (context, child) {
                  final t = Curves.easeOutBack.transform(_seg(
                      _intro.value, 0.50 + 0.03 * slot, 0.78 + 0.03 * slot));
                  return Opacity(
                    opacity: t.clamp(0.0, 1.0).toDouble(),
                    child: Transform.translate(
                      offset: Offset(0, 46 * (1 - t)),
                      child: Transform.rotate(
                        angle: (i.isEven ? -0.07 : 0.07) * (1 - t),
                        child: child,
                      ),
                    ),
                  );
                },
                child: _SuspectCard(
                  player: p,
                  width: cardW,
                  selected: sel,
                  opacity: opacity,
                  enabled: !busy,
                  jailed: isJailed(p, widget.day),
                  pulse: _pulse,
                  onTap: () => _select(id),
                ),
              ),
            );
          }(),
      ];

      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, vPad),
        child: ConstrainedBox(
          // Muat tanpa gulir: kartu berada di tengah ruang yang tersedia.
          constraints: BoxConstraints(minHeight: availH),
          child: Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              spacing: gap,
              runSpacing: gap,
              children: items,
            ),
          ),
        ),
      );
    });
  }

  /// Bilah aksi: selalu terlihat. Status pilihan (atau galat) satu-dua
  /// baris, lalu tombol Kunci (utama) dan Tidak memilih (sekunder).
  Widget _actionBar({required bool compact, required bool vertical}) {
    final chosen = _player(target);
    final canLock = !busy && target != null;
    final err = _error;

    final Widget status;
    if (err != null) {
      status = Text(
        err,
        key: const ValueKey('err'),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12.5, color: EmbunColors.blood),
      );
    } else if (chosen == null) {
      status = const Text(
        'Pilih satu pemain untuk dituduh.',
        key: ValueKey('none'),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: Colors.white60),
      );
    } else {
      status = Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 14, color: Colors.white70),
          children: [
            const TextSpan(text: 'Kamu menuduh  '),
            TextSpan(
              text: chosen['name'] as String,
              style: const TextStyle(
                color: EmbunColors.blood,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (strikesOf(chosen) >= 1)
              const TextSpan(
                text: '\nSudah dituduh sekali: bila mayoritas sepakat, '
                    'ia KELUAR dari desa (Si Terbisik: tertangkap).',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.3,
                  color: EmbunColors.gold,
                ),
              ),
          ],
        ),
        key: ValueKey('sel${chosen['user_id']}'),
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );
    }

    final btnH = compact ? 46.0 : 52.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          padding: EdgeInsets.fromLTRB(10, compact ? 6 : 8, 10, compact ? 6 : 8),
          decoration: tableEdge(
            target != null ? EmbunColors.blood : EmbunColors.gold,
            vertical: vertical,
            top: !vertical,
          ),
          child: LayoutBuilder(builder: (context, c) {
            final stacked = vertical || c.maxWidth < 300;
            final wideLabel = c.maxWidth >= 400;
            final lock = EmbunButton(
              label: 'Kunci suara',
              icon: 'lock',
              expand: true,
              height: btnH,
              onPressed: canLock ? () => _submit(target) : null,
            );
            final skip = EmbunButton(
              label: wideLabel || stacked ? 'Tidak memilih' : 'Lewati',
              icon: 'skip',
              kind: EmbunButtonKind.secondary,
              expand: true,
              height: stacked ? 42 : btnH,
              onPressed: busy ? null : () => _submit(null),
            );
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: status,
                  ),
                ),
                SizedBox(height: compact ? 6 : 8),
                if (widget.hasHammer && target != null && !busy) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _hammer = !_hammer);
                    },
                    child: Padding(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        children: [
                          Icon(Icons.gavel_rounded,
                              size: 20,
                              color: _hammer ? EmbunColors.gold : Colors.white54),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pakai Patuhilah Padaku: suaramu bernilai 2',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: _hammer
                                      ? EmbunColors.gold
                                      : Colors.white60),
                            ),
                          ),
                          Switch(
                            value: _hammer,
                            onChanged: (v) => setState(() => _hammer = v),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 4 : 6),
                ],
                if (stacked) ...[
                  lock,
                  const SizedBox(height: 8),
                  skip,
                ] else
                  Row(
                    children: [
                      Expanded(flex: 3, child: lock),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: skip),
                    ],
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// Kartu tersangka: kartu karakter 2:3 utuh dengan pelat nama dan nyawa di
/// bagian bawah. Dipilih = bingkai dan cahaya merah berdenyut, tanda bahaya;
/// pemain lain meredup selagi ada yang dipilih. Semua ukuran isi mengikuti
/// [width], jadi kartu kecil di ponsel sempit tetap rapi dan tak meluap.
class _SuspectCard extends StatelessWidget {
  final Map<String, dynamic> player;
  final double width;
  final bool selected;
  final double opacity;
  final bool enabled;
  final bool jailed;
  final Animation<double> pulse;
  final VoidCallback onTap;

  const _SuspectCard({
    required this.player,
    required this.width,
    required this.selected,
    required this.opacity,
    required this.enabled,
    required this.jailed,
    required this.pulse,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = player['name'] as String;
    final card = player['character_card'] as String;
    final lives = livesLeft(player);
    const radius = 12.0;
    final nameSize = (width * 0.13).clamp(11.0, 15.0).toDouble();
    final heartSize = (width * 0.12).clamp(11.0, 16.0).toDouble();
    final dangerSize = (width * 0.24).clamp(20.0, 34.0).toDouble();
    final pad = (width * 0.06).clamp(5.0, 9.0).toDouble();

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: 'Tuduh $name',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: opacity,
        child: AnimatedScale(
          scale: selected ? 1.05 : 1,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          child: AnimatedBuilder(
            animation: pulse,
            builder: (context, child) {
              final glow = selected ? 0.35 + 0.35 * pulse.value : 0.0;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: selected
                        ? EmbunColors.blood
                        : EmbunColors.goldDim.withValues(alpha: 0.5),
                    width: selected ? 3 : 1.5,
                  ),
                  boxShadow: [
                    if (selected)
                      BoxShadow(
                        color: EmbunColors.blood.withValues(alpha: glow),
                        blurRadius: 16 + 14 * pulse.value,
                        spreadRadius: 2,
                      )
                    else
                      const BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 8,
                          offset: Offset(0, 3)),
                  ],
                ),
                child: child,
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius - 1),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GameImage(
                    path: protagonistPath(card),
                    alignment: Alignment.topCenter,
                    cacheWidth: (width * 2.5).round(),
                  ),
                  // Pudar gelap di bawah supaya nama selalu terbaca.
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: 0.46,
                      widthFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.88),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Semburat merah saat dipilih.
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    color: EmbunColors.blood
                        .withValues(alpha: selected ? 0.20 : 0.0),
                  ),
                  Positioned(
                    left: pad,
                    right: pad,
                    bottom: pad * 0.8,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: nameSize,
                            height: 1.15,
                            fontWeight:
                            selected ? FontWeight.w900 : FontWeight.w700,
                            color: Colors.white,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
                        ),
                        SizedBox(height: width * 0.02),
                        LivesRow(lives: lives, size: heartSize),
                      ],
                    ),
                  ),
                  if (jailed)
                    Positioned(
                      left: pad * 0.7,
                      top: pad * 0.7,
                      right: pad * 0.7,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topLeft,
                          child: const StatusTag(
                              text: 'Dikurung',
                              color: EmbunColors.blood,
                              asset: 'lock'),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 3,
                    right: 3,
                    child: AnimatedScale(
                      scale: selected ? 1 : 0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.elasticOut,
                      child: GameIcon('danger', size: dangerSize),
                    ),
                  ),
                  Positioned.fill(
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: enabled ? onTap : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pembukaan sidang: layar menggelap, judul "SIDANG DESA" menghantam dengan
/// getar, garis merah memanjang, lalu tirai terangkat dan kartu tersangka
/// masuk. Ketuk untuk melewati. Tidak menghalangi lagi setelah tirai naik.
class _SessionIntro extends StatelessWidget {
  final Animation<double> t;
  final int day;
  final VoidCallback onSkip;

  const _SessionIntro({
    required this.t,
    required this.day,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        final v = t.value;
        if (v >= 0.78) return const SizedBox.shrink();

        final scrim = 0.95 * (1 - _smooth(_seg(v, 0.50, 0.78)));
        final titleIn = Curves.easeOutCubic.transform(_seg(v, 0.04, 0.24));
        final titleOut = 1 - _smooth(_seg(v, 0.46, 0.60));
        final subIn = _smooth(_seg(v, 0.22, 0.36));
        final line = Curves.easeOutCubic.transform(_seg(v, 0.12, 0.36));
        final k = _seg(v, 0.10, 0.20);
        final shake = (k > 0 && k < 1) ? math.sin(k * 40) * 7 * (1 - k) : 0.0;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onSkip,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                  color: const Color(0xFF080306).withValues(alpha: scrim)),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 0.9,
                    colors: [
                      EmbunColors.blood.withValues(alpha: 0.30 * scrim),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Opacity(
                opacity: (titleIn * titleOut).clamp(0.0, 1.0).toDouble(),
                child: Transform.translate(
                  offset: Offset(shake, 0),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.scale(
                              scale: 1.5 - 0.5 * titleIn,
                              child: const GameIcon('vote', size: 72),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'SIDANG DESA',
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 16 - 11 * titleIn,
                                color: EmbunColors.blood,
                                shadows: [
                                  Shadow(
                                    color: EmbunColors.blood
                                        .withValues(alpha: 0.7),
                                    blurRadius: 24,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: 220 * line,
                              height: 2,
                              child: ColoredBox(
                                color:
                                EmbunColors.blood.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Opacity(
                              opacity: subIn,
                              child: Text(
                                'Hari $day  ·  satu suara bisa mengubah segalanya',
                                style: const TextStyle(
                                    fontSize: 13.5, color: Colors.white70),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Opacity(
                              opacity: subIn * 0.7,
                              child: const Text(
                                'Ketuk untuk melewati',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.white38),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Layar setelah suara dikunci: segel merah berdenyut, siapa yang kamu tuduh,
/// dan deretan segel yang menyala satu per satu saat pemain lain mengunci
/// suaranya.
class _LockedView extends StatefulWidget {
  /// true bila kita tahu pilihan sesi ini (bukan masuk kembali).
  final bool known;
  final Map<String, dynamic>? target; // null = tidak memilih
  final int ready;
  final int total;

  const _LockedView({
    super.key,
    required this.known,
    required this.target,
    required this.ready,
    required this.total,
  });

  @override
  State<_LockedView> createState() => _LockedViewState();
}

class _LockedViewState extends State<_LockedView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  @override
  void initState() {
    super.initState();
    _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _choice() {
    final t = widget.target;
    if (!widget.known) {
      return const Text('Suaramu sudah dijatuhkan.',
          style: TextStyle(fontSize: 14, color: Colors.white70));
    }
    if (t == null) {
      return const Text('Kamu memilih untuk tidak memilih.',
          style: TextStyle(fontSize: 14, color: Colors.white70));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlayerAvatar(
          path: protagonistPath(t['character_card'] as String),
          size: 44,
          ring: EmbunColors.blood,
        ),
        const SizedBox(width: 12),
        Text.rich(
          TextSpan(
            style: const TextStyle(fontSize: 15, color: Colors.white70),
            children: [
              const TextSpan(text: 'Kamu menuduh  '),
              TextSpan(
                text: t['name'] as String,
                style: const TextStyle(
                  color: EmbunColors.blood,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _seals(int total, int ready, double beat) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < ready ? EmbunColors.blood : Colors.transparent,
              border: Border.all(
                color: i < ready
                    ? EmbunColors.blood
                    : Colors.white.withValues(alpha: 0.2 + 0.25 * beat),
                width: 2,
              ),
              boxShadow: i < ready
                  ? [
                BoxShadow(
                  color: EmbunColors.blood.withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ]
                  : null,
            ),
            child: i < ready
                ? const GameIcon('centang', size: 16)
                : null,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = math.max(widget.total, 1);
    final ready = widget.ready.clamp(0, total).toInt();
    final left = total - ready;

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final beat = _thump(_c.value);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: 1 + 0.07 * beat,
                      child: Container(
                        width: 96,
                        height: 96,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              EmbunColors.blood.withValues(alpha: 0.55),
                              const Color(0xFF2A0C0C),
                            ],
                          ),
                          border:
                          Border.all(color: EmbunColors.blood, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: EmbunColors.blood
                                  .withValues(alpha: 0.35 + 0.35 * beat),
                              blurRadius: 18 + 20 * beat,
                              spreadRadius: 2 * beat,
                            ),
                          ],
                        ),
                        child: const GameIcon('lock', size: 52),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'SUARAMU TERKUNCI',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        color: EmbunColors.blood,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _choice(),
                    const SizedBox(height: 22),
                    _seals(total, ready, beat),
                    const SizedBox(height: 10),
                    Text(
                      left > 0
                          ? 'Menunggu $left suara lagi...'
                          : 'Semua suara terkunci. Pintu balai ditutup...',
                      style: const TextStyle(
                          fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tak ada yang bisa ditarik kembali.',
                      style: TextStyle(fontSize: 11.5, color: Colors.white38),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Segel suara: yang dituduh menghantam ke tengah layar, layar bergetar
/// dan cap "DITUDUH" menimpa. Tidak memilih mendapat cap abu-abu yang
/// tenang. Hanya tampil di layar pemilih sendiri.
class _VoteStamp extends StatelessWidget {
  final Map<String, dynamic>? player; // null = tidak memilih
  const _VoteStamp({required this.player});

  @override
  Widget build(BuildContext context) {
    final abstain = player == null;
    final color = abstain ? Colors.white60 : Colors.redAccent;
    final size = MediaQuery.sizeOf(context);
    final avatar =
    (math.min(size.width, size.height) * 0.28).clamp(64.0, 130.0).toDouble();
    final stampW = (size.width * 0.6).clamp(160.0, 260.0).toDouble();

    return AbsorbPointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        builder: (context, t, _) {
          final dimT = Curves.easeOut
              .transform((t / 0.3).clamp(0.0, 1.0).toDouble());
          final land = Curves.easeOutBack
              .transform((t / 0.5).clamp(0.0, 1.0).toDouble());
          final st = Curves.easeOutBack
              .transform(((t - 0.4) / 0.4).clamp(0.0, 1.0).toDouble());
          final flash =
          (1 - (t - 0.45).abs() / 0.08).clamp(0.0, 1.0).toDouble();
          // Getar singkat saat cap menghantam, lalu mereda.
          final k = ((t - 0.45) / 0.25).clamp(0.0, 1.0).toDouble();
          final shake = (t > 0.45 && t < 0.7)
              ? math.sin(k * 40) * 7 * (1 - k)
              : 0.0;

          return Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: Colors.black.withValues(alpha: 0.80 * dimT)),
              if (!abstain)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.95,
                      colors: [
                        Colors.transparent,
                        Colors.redAccent.withValues(alpha: 0.35 * dimT),
                      ],
                      stops: const [0.45, 1.0],
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(shake, shake * 0.6),
                child: Center(
                  // Menyusut otomatis di layar pendek (ponsel miring).
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (abstain)
                            Opacity(
                              opacity: (t / 0.3).clamp(0.0, 1.0).toDouble(),
                              child: const GameIcon('silang', size: 80),
                            )
                          else
                            Opacity(
                              opacity: (t / 0.2).clamp(0.0, 1.0).toDouble(),
                              child: Transform.scale(
                                scale: 2.2 - 1.2 * land,
                                child: PlayerAvatar(
                                  path: protagonistPath(
                                      player!['character_card'] as String),
                                  size: avatar,
                                  ring: Colors.redAccent,
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          if (!abstain)
                            Text(
                              player!['name'] as String,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                          const SizedBox(height: 16),
                          Opacity(
                            opacity: st.clamp(0.0, 1.0).toDouble(),
                            child: Transform.rotate(
                              angle: -0.2,
                              child: Transform.scale(
                                scale: 2.6 - 1.6 * st,
                                child: abstain
                                    ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: color, width: 4),
                                    borderRadius:
                                    BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'TIDAK MEMILIH',
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 4,
                                    ),
                                  ),
                                )
                                    : GameIcon('tertuduh',
                                    width: stampW,
                                    height: stampW * 90 / 220),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (flash > 0.01)
                ColoredBox(
                    color: Colors.white.withValues(alpha: 0.35 * flash)),
            ],
          );
        },
      ),
    );
  }
}

/// Ketegangan sepanjang sesi voting, dipasang di atas SELURUH layar meja
/// (bukan di panel saja). Tenang sampai 20 detik terakhir; sesudah itu tepi
/// layar berdenyut merah seperti detak jantung yang makin cepat, ada getar
/// haptic mulai 10 detik terakhir, dan 5 detik terakhir ditandai angka besar
/// yang samar di tengah layar. Tidak menangkap sentuhan.
class VotingTension extends StatefulWidget {
  final DateTime? deadline;
  const VotingTension({super.key, required this.deadline});

  @override
  State<VotingTension> createState() => _VotingTensionState();
}

class _VotingTensionState extends State<VotingTension>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  Timer? _timer;
  int _band = 0; // 0 tenang, 1 <=20s, 2 <=10s, 3 <=5s
  int _left = 999; // detik tersisa (dibulatkan ke atas)
  double _lastV = 0;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onBeat);
    _measure(notify: false);
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) _measure(notify: true);
    });
  }

  @override
  void didUpdateWidget(covariant VotingTension old) {
    super.didUpdateWidget(old);
    if (old.deadline != widget.deadline) _measure(notify: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _measure({required bool notify}) {
    final d = widget.deadline;
    int band = 0;
    int secs = 999;
    if (d != null) {
      final left = d.difference(ServerClock.now()).inMilliseconds / 1000.0;
      secs = left <= 0 ? 0 : left.ceil();
      band = left <= 5 ? 3 : (left <= 10 ? 2 : (left <= 20 ? 1 : 0));
    }
    final bandChanged = band != _band;
    if (!bandChanged && secs == _left) return;

    void apply() {
      _band = band;
      _left = secs;
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
    if (bandChanged) {
      if (band == 0) {
        _c.stop();
        _c.value = 0;
      } else {
        final ms = band == 1 ? 1100 : (band == 2 ? 800 : 540);
        _c.repeat(period: Duration(milliseconds: ms));
      }
    }
  }

  /// Satu debar di awal tiap putaran.
  void _onBeat() {
    final v = _c.value;
    if (v < _lastV) {
      if (_band == 3) {
        HapticFeedback.mediumImpact();
      } else if (_band == 2) {
        HapticFeedback.lightImpact();
      }
    }
    _lastV = v;
  }

  @override
  Widget build(BuildContext context) {
    if (_band == 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final urgency = _band == 1 ? 0.35 : (_band == 2 ? 0.65 : 1.0);
          final beat = _thump(_c.value);
          final a = (0.10 + 0.45 * urgency) * (0.35 + 0.65 * beat);
          return Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 1.0,
                    colors: [
                      Colors.transparent,
                      EmbunColors.blood.withValues(alpha: a),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
              if (_band == 3 && _left > 0)
                Center(
                  child: Opacity(
                    opacity: 0.10 + 0.16 * beat,
                    child: Transform.scale(
                      scale: 1 + 0.12 * beat,
                      child: Text(
                        '$_left',
                        style: const TextStyle(
                          fontSize: 180,
                          fontWeight: FontWeight.w900,
                          color: EmbunColors.blood,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}