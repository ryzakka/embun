import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import '../common/scene_flow.dart';

double _seg(double v, double a, double b) =>
    ((v - a) / (b - a)).clamp(0.0, 1.0).toDouble();

/// Angka semu-acak yang stabil (0..1) untuk percikan bara.
double _rnd(int i, int k) {
  final v = math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
  return v - v.floorToDouble();
}

/// Debar jantung: dua denyut pendek per putaran (u = 0..1).
double _thump(double u) {
  double f(double x) => x < 0 ? 0.0 : math.exp(-x * 16);
  return math.min(1.0, f(u) + 0.7 * f(u - 0.28));
}

/// Adegan pembukaan suara setelah voting selesai. Alurnya dibuat seperti
/// pembacaan vonis:
///
///  * pembukaan: layar gelap berdenyut, debar haptic makin rapat;
///  * satu per satu kartu yang memilih muncul, hitungan di papan naik, dan
///    papan memerah pada pemain yang mendekati mayoritas;
///  * saat sebuah kartu tinggal SATU suara dari mayoritas, irama melambat,
///    tepi layar berdenyut dan muncul "butuh 1 suara lagi...";
///  * suara penentu menghantam: layar bergetar, berkilat putih, spanduk
///    MAYORITAS muncul bersama wajah yang dituduh;
///  * hasil: yang dituduh jatuh ke tengah, gelombang kejut, cap DITUDUH
///    menimpa, hitungan suara naik, bara melayang. Bila tak ada mayoritas,
///    suasana mereda jadi dingin dan tenang.
///
/// Berjalan SEBELUM adegan kurungan / pengusiran / fajar / akhir.
///
/// [rows] berasal dari tabel `vote_reveal` (urutan server, sama untuk semua
/// perangkat; yang tidak memilih di akhir).
class VoteRevealScene extends StatefulWidget {
  final int day;
  final List<Map<String, dynamic>> rows;
  final String myId;
  final VoidCallback onDone;

  const VoteRevealScene({
    super.key,
    required this.day,
    required this.rows,
    required this.myId,
    required this.onDone,
  });

  @override
  State<VoteRevealScene> createState() => _VoteRevealSceneState();
}

class _Person {
  final String id;
  final String name;
  final String? card;
  const _Person(this.id, this.name, this.card);
}

class _VoteRevealSceneState extends State<VoteRevealScene>
    with TickerProviderStateMixin {
  static const _bg = kSceneInk;
  static const _teal = Color(0xFF5FB8A5);

  late final List<Map<String, dynamic>> _votes;
  late final List<Map<String, dynamic>> _abstain;
  late final List<_Person> _people;
  late final int _total;
  String? _myTarget;

  final Map<String, int> _counts = {};
  int _phase = 0; // 0 pembukaan, 1 pemilihan, 2 tidak memilih, 3 hasil
  int _i = 0; // suara yang sedang tampil
  int _stage = 0; // 0 kosong, 1 pemilih muncul, 2 + sasaran, 3 terhitung
  String? _majorityId;
  bool _banner = false;
  bool _near = false; // satu suara lagi menuju mayoritas
  bool _decisive = false; // suara penentu sudah jatuh
  bool _stopped = false;
  bool _done = false;

  // Denyut tepi layar (kecepatan berubah menurut ketegangan).
  late final AnimationController _beat = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));
  // Getar layar dan kilat putih saat hantaman.
  late final AnimationController _shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 560));
  late final AnimationController _flash = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
  // Garis waktu adegan hasil.
  late final AnimationController _vc = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3400));
  final Set<int> _fired = {};
  // Tirai gelap: 1 = layar tertutup kSceneInk. Terbuka saat adegan mulai,
  // menutup lagi sebelum adegan berikutnya (kurungan / pengusiran / fajar).
  late final AnimationController _veil = AnimationController(
      vsync: this,
      value: 1.0,
      duration: const Duration(milliseconds: kSceneFadeOutMs),
      reverseDuration: const Duration(milliseconds: kSceneFadeInMs));

  @override
  void initState() {
    super.initState();
    _veil.reverse();
    final rows = widget.rows;
    _votes = [for (final r in rows) if (r['target_id'] != null) r];
    _abstain = [for (final r in rows) if (r['target_id'] == null) r];
    _total = rows.length;

    final seen = <String>{};
    final people = <_Person>[];
    for (final r in rows) {
      final id = r['voter_id'] as String;
      if (seen.add(id)) {
        people.add(_Person(id, '${r['voter_name']}', r['voter_card'] as String?));
      }
    }
    // Susunan papan stabil (urut nama), bukan urutan pemilihan.
    people.sort((a, b) => a.name.compareTo(b.name));
    _people = people;

    for (final r in rows) {
      if (r['voter_id'] == widget.myId) _myTarget = r['target_id'] as String?;
    }

    _beat.repeat();
    _vc.addListener(_onVerdictTick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  @override
  void dispose() {
    _stopped = true;
    _beat.dispose();
    _shake.dispose();
    _flash.dispose();
    _vc.dispose();
    _veil.dispose();
    super.dispose();
  }

  // ------------------------- alur waktu -------------------------

  Future<bool> _w(int ms) async {
    await Future.delayed(Duration(milliseconds: ms));
    return mounted && !_stopped;
  }

  Future<void> _finish() async {
    if (_done) return;
    _done = true;
    _stopped = true;
    // Memudar ke gelap dulu, baru adegan berikutnya mulai (yang juga
    // mulai dari gelap), tanpa pemotongan mendadak.
    await _veil.forward();
    if (mounted) widget.onDone();
  }

  /// Hantaman layar: getar + kilat + haptic berat.
  void _slam({bool flash = true}) {
    _shake.forward(from: 0);
    if (flash) _flash.forward(from: 0);
    HapticFeedback.heavyImpact();
  }

  void _onVerdictTick() {
    if (_winnerId == null) return;
    final t = _vc.value;
    // Wajah yang dituduh mendarat, lalu cap menimpa.
    if (t >= 0.34 && _fired.add(0)) _slam(flash: false);
    if (t >= 0.50 && _fired.add(1)) _slam();
  }

  Future<void> _play() async {
    // Pembukaan: debar yang makin rapat sebelum suara pertama dibuka.
    HapticFeedback.lightImpact();
    if (!await _w(520)) return;
    HapticFeedback.lightImpact();
    if (!await _w(360)) return;
    HapticFeedback.mediumImpact();
    if (!await _w(260)) return;
    HapticFeedback.mediumImpact();
    if (!await _w(220)) return;
    HapticFeedback.heavyImpact();
    setState(() => _phase = 1);

    final n = _votes.length;
    for (var i = 0; i < n; i++) {
      final v = _votes[i];
      final tid = v['target_id'] as String;

      // Irama: normal di awal, melambat di sepertiga akhir selama belum ada
      // mayoritas, merayap saat tinggal satu suara lagi, dan mengebut
      // setelah mayoritas jatuh.
      final tense = _majorityId == null && i >= (n * 2 / 3).floor();
      final m = _majorityId != null
          ? 0.62
          : (_near ? 1.7 : (tense ? 1.3 : 1.0));

      setState(() {
        _i = i;
        _stage = 1; // pemilih muncul
      });
      if (_near) HapticFeedback.lightImpact();
      if (!await _w((470 * m).round())) return;

      setState(() => _stage = 2); // panah + sasaran
      if (!await _w((430 * m).round())) return;

      setState(() {
        _stage = 3; // terhitung
        _counts[tid] = (_counts[tid] ?? 0) + 1;
      });
      HapticFeedback.selectionClick();

      if (_majorityId == null && _counts[tid]! * 2 > _total) {
        // Suara penentu: hantaman, lalu spanduk MAYORITAS.
        _majorityId = tid;
        setState(() {
          _near = false;
          _decisive = true;
          _banner = true;
        });
        _beat.repeat(period: const Duration(milliseconds: 900));
        _slam();
        if (!await _w(170)) return;
        HapticFeedback.heavyImpact();
        if (!await _w(1500)) return;
        setState(() => _banner = false);
      } else if (_majorityId == null) {
        final nearNow = _lead >= 2 && _lead == _need - 1 && (n - 1 - i) >= 1;
        if (nearNow != _near) {
          setState(() => _near = nearNow);
          if (nearNow) {
            _beat.repeat(period: const Duration(milliseconds: 620));
            HapticFeedback.mediumImpact();
          }
        }
      }
      if (!await _w((560 * m).round())) return;
    }

    setState(() {
      _stage = 0;
      _near = false;
    });

    if (_abstain.isNotEmpty) {
      setState(() => _phase = 2);
      // Makin banyak yang tidak memilih, makin lama wajah-wajahnya tampil.
      if (!await _w((1900 + 200 * _abstain.length).clamp(1900, 3000).toInt())) return;
    }

    setState(() => _phase = 3);
    final won = _winnerId != null;
    if (won) {
      _beat.repeat(period: const Duration(milliseconds: 1500));
    } else {
      _beat.repeat(period: const Duration(milliseconds: 2400));
      HapticFeedback.lightImpact();
    }
    _vc.forward(from: 0);
    // Linimasa hasil 3,4 detik, lalu jeda baca: nama yang dituduh, hitungan
    // suara, dan keterangan harus sempat terbaca sebelum layar memudar.
    if (!await _w(won ? 3400 + 2300 : 3400 + 1500)) return;
    _finish();
  }

  // ------------------------- data bantu -------------------------

  _Person? _person(String? id) {
    for (final p in _people) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Pemenang akhir: satu-satunya yang melewati separuh suara.
  String? get _winnerId {
    for (final e in _counts.entries) {
      if (e.value * 2 > _total) return e.key;
    }
    return null;
  }

  /// Suara yang dibutuhkan untuk mayoritas.
  int get _need => _total ~/ 2 + 1;

  /// Suara terbanyak sejauh ini.
  int get _lead {
    var m = 0;
    for (final c in _counts.values) {
      if (c > m) m = c;
    }
    return m;
  }

  String? get _leaderId {
    String? id;
    var m = 0;
    for (final e in _counts.entries) {
      if (e.value > m) {
        m = e.value;
        id = e.key;
      }
    }
    return id;
  }

  String _targetName(Map<String, dynamic> v) => '${v['target_name']}';
  String _voterName(Map<String, dynamic> v) => '${v['voter_name']}';

  // ------------------------- tampilan -------------------------

  @override
  Widget build(BuildContext context) {
    final won = _phase == 3 && _winnerId != null;
    return Material(
      color: _bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.35),
                radius: 1.15,
                colors: [Color(0xFF1B1233), _bg],
              ),
            ),
          ),
          if (won) _spotlight(),
          _vignette(),
          AnimatedBuilder(
            animation: _shake,
            builder: (context, child) {
              final k = _shake.value;
              final amp = _shake.isAnimating ? (1 - k) : 0.0;
              return Transform.translate(
                offset: Offset(
                    math.sin(k * 52) * 10 * amp, math.sin(k * 41 + 1.3) * 7 * amp),
                child: child,
              );
            },
            child: SafeArea(
              child: Column(
                children: [
                  _top(),
                  Expanded(child: _stageArea()),
                  _board(),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          if (won) _embers(),
          if (_banner) _majorityBanner(),
          AnimatedBuilder(
            animation: _veil,
            builder: (_, _) => sceneVeil(_veil.value),
          ),
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _flash,
              builder: (_, _) {
                final a = _flash.isAnimating ? 0.5 * (1 - _flash.value) : 0.0;
                if (a <= 0.005) return const SizedBox.shrink();
                return ColoredBox(color: Colors.white.withValues(alpha: a));
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Tepi layar berdenyut: makin merah dan cepat bila ada yang mendekati
  /// mayoritas. Saat hasil tanpa mayoritas berubah menjadi hijau-dingin.
  Widget _vignette() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _beat,
        builder: (context, _) {
          final won = _winnerId != null;
          final heat = (_lead / _need).clamp(0.0, 1.0).toDouble();
          final double base = switch (_phase) {
            0 => 0.14,
            1 => 0.06 +
                0.34 * heat * heat +
                (_near ? 0.20 : 0.0) +
                (_decisive ? 0.20 : 0.0),
            2 => 0.08,
            _ => won ? 0.30 : 0.18,
          };
          final col = (_phase == 3 && !won) ? _teal : EmbunColors.blood;
          final a = (base * (0.45 + 0.55 * _thump(_beat.value)))
              .clamp(0.0, 1.0)
              .toDouble();
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.0,
                colors: [Colors.transparent, col.withValues(alpha: a)],
                stops: const [0.45, 1.0],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Cahaya dari atas jatuh ke yang dituduh.
  Widget _spotlight() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _vc,
        builder: (context, _) {
          final s = Curves.easeOut.transform(_seg(_vc.value, 0.05, 0.40));
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.1),
                radius: 0.75,
                colors: [
                  Colors.white.withValues(alpha: 0.12 * s),
                  Colors.transparent,
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Bara merah melayang naik setelah vonis jatuh.
  Widget _embers() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_vc, _beat]),
        builder: (context, _) => CustomPaint(
          painter: _EmberPainter(
            env: _seg(_vc.value, 0.45, 0.80),
            loop: _beat.value,
          ),
        ),
      ),
    );
  }

  Widget _top() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 10, 8, 0),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Suara Terbuka',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: EmbunColors.gold,
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: (_near && _leaderId != null)
                    ? Text(
                  '${_person(_leaderId)?.name ?? ''} butuh 1 suara lagi...',
                  key: const ValueKey('near'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: EmbunColors.blood,
                  ),
                )
                    : Text(
                  'Hari ${widget.day} · siapa memilih siapa',
                  key: const ValueKey('sub'),
                  style: const TextStyle(
                      fontSize: 12.5, color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: _finish,
          icon: const Icon(Icons.fast_forward_rounded, size: 20),
          label: const Text('Lewati'),
          style: TextButton.styleFrom(foregroundColor: Colors.white60),
        ),
      ],
    ),
  );

  Widget _stageArea() => LayoutBuilder(builder: (context, c) {
    final cardW = math
        .min(math.min(c.maxWidth * 0.28, (c.maxHeight - 90) / kProtagonistAspect), 128.0)
        .clamp(52.0, 128.0)
        .toDouble();
    final Widget body = switch (_phase) {
      0 => _openingStage(),
      1 => _voteStage(cardW),
      2 => _abstainStage(),
      _ => _resultStage(cardW),
    };
    // Diskalakan turun bila layar pendek (ponsel miring) agar tak meluap.
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: c.maxWidth * 0.9),
          child: Center(child: body),
        ),
      ),
    );
  });

  // ---------- pembukaan ----------

  Widget _openingStage() => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 1500),
    curve: Curves.easeOutCubic,
    builder: (_, t, _) => Opacity(
      opacity: t.clamp(0.0, 1.0).toDouble(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GameIcon('vote', size: 56),
          const SizedBox(height: 14),
          Text(
            'SEMUA SUARA DIBUKA',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 12 - 8 * t,
              color: EmbunColors.cream,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tak ada yang bisa ditarik kembali...',
            style: TextStyle(fontSize: 13, color: Colors.white54),
          ),
        ],
      ),
    ),
  );

  // ---------- satu suara ----------

  Widget _voteStage(double cardW) {
    if (_stage == 0 || _i >= _votes.length) return const SizedBox.shrink();
    final v = _votes[_i];
    final voterMine = v['voter_id'] == widget.myId;
    final targetMine = v['target_id'] == widget.myId;
    final showTarget = _stage >= 2;

    return Column(
      key: ValueKey('vote$_i'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
              builder: (_, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                    offset: Offset(-48 * (1 - t), 0), child: child),
              ),
              child: _VoteCard(
                name: _voterName(v),
                card: v['voter_card'] as String?,
                width: cardW,
                tag: voterMine ? 'Suaramu' : null,
                glow: voterMine ? EmbunColors.gold : EmbunColors.leaf,
                ring: voterMine,
              ),
            ),
            SizedBox(
              width: cardW * 0.62,
              height: cardW * kProtagonistAspect + 22,
              child: showTarget
                  ? TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 300),
                builder: (_, t, child) => Opacity(
                    opacity: t,
                    child: Transform.scale(scale: 0.6 + 0.4 * t, child: child)),
                child: Padding(
                  padding: const EdgeInsets.only(top: 22),
                  child: Center(
                    child: Icon(Icons.arrow_forward_rounded,
                        size: cardW * 0.4, color: EmbunColors.blood),
                  ),
                ),
              )
                  : null,
            ),
            SizedBox(
              width: cardW + 24,
              child: showTarget
                  ? TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutBack,
                builder: (_, t, child) {
                  final tc = t.clamp(0.0, 1.0).toDouble();
                  return Stack(
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.none,
                    children: [
                      // Cincin kejut saat sasaran menerima suara.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(painter: _HitRingPainter(t: tc)),
                        ),
                      ),
                      Opacity(
                        opacity: tc,
                        child: Transform.translate(
                          offset: Offset(math.sin(tc * 36) * 5 * (1 - tc), 0),
                          child: Transform.scale(
                              scale: 0.55 + 0.45 * t, child: child),
                        ),
                      ),
                    ],
                  );
                },
                child: _VoteCard(
                  name: _targetName(v),
                  card: v['target_card'] as String?,
                  width: cardW,
                  tag: targetMine ? 'Kamu' : null,
                  glow: EmbunColors.blood,
                  ring: targetMine,
                ),
              )
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 14),
        AnimatedOpacity(
          opacity: showTarget ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          child: Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 16, color: Colors.white70),
              children: [
                TextSpan(
                  text: voterMine ? 'Kamu' : _voterName(v),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: voterMine ? EmbunColors.gold : Colors.white,
                  ),
                ),
                const TextSpan(text: '  memilih  '),
                TextSpan(
                  text: targetMine ? 'kamu' : _targetName(v),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: EmbunColors.blood,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  // ---------- tidak memilih ----------

  Widget _abstainStage() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      builder: (_, t, child) => Opacity(opacity: t, child: child),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.do_not_disturb_on_outlined,
                  size: 34, color: Colors.white54),
              const SizedBox(height: 6),
              const Text('Tidak memilih',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white70)),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  for (final r in _abstain)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PlayerAvatar(
                          path: protagonistPath(
                              (r['voter_card'] as String?) ?? 'default'),
                          size: 44,
                          ring: r['voter_id'] == widget.myId
                              ? EmbunColors.gold
                              : Colors.white30,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          r['voter_id'] == widget.myId
                              ? '${r['voter_name']} (kamu)'
                              : '${r['voter_name']}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: r['voter_id'] == widget.myId
                                ? EmbunColors.gold
                                : Colors.white60,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- hasil ----------

  Widget _resultStage(double cardW) {
    final wid = _winnerId;
    final w = _person(wid);
    return AnimatedBuilder(
      animation: _vc,
      builder: (context, _) {
        final t = _vc.value;
        if (w == null) return _noMajority(t);

        final head = Curves.easeOutCubic.transform(_seg(t, 0.0, 0.22));
        final appear = _seg(t, 0.10, 0.20);
        final drop = Curves.easeIn.transform(_seg(t, 0.12, 0.36));
        final stamp = Curves.easeOutBack.transform(_seg(t, 0.48, 0.64));
        final countT = Curves.easeOut.transform(_seg(t, 0.58, 0.88));
        final votes = _counts[wid] ?? 0;
        final shown = (votes * countT).round();
        final cw = cardW * 1.1;
        final breathe =
            1 + 0.012 * math.sin(_seg(t, 0.36, 1.0) * 4 * math.pi);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: head,
              child: Text(
                'DITUDUH MAYORITAS',
                style: TextStyle(
                  fontSize: 14,
                  letterSpacing: 14 - 11 * head,
                  fontWeight: FontWeight.w900,
                  color: EmbunColors.blood,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _ShockPainter(t: _seg(t, 0.36, 0.70)),
                    ),
                  ),
                ),
                Opacity(
                  opacity: appear,
                  child: Transform.translate(
                    offset: Offset(0, -170 * (1 - drop)),
                    child: Transform.scale(
                      scale: (1.6 - 0.6 * drop) * breathe,
                      child: _VoteCard(
                        name: w.name,
                        card: w.card,
                        width: cw,
                        tag: w.id == widget.myId ? 'Kamu' : null,
                        glow: EmbunColors.blood,
                        ring: w.id == widget.myId,
                      ),
                    ),
                  ),
                ),
                if (stamp > 0.01)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Align(
                        alignment: const Alignment(0, 0.25),
                        child: Opacity(
                          opacity: stamp.clamp(0.0, 1.0).toDouble(),
                          child: Transform.rotate(
                            angle: -0.22,
                            child: Transform.scale(
                              scale: 2.4 - 1.4 * stamp,
                              child: GameIcon(
                                'tertuduh',
                                width: cw * 1.3,
                                height: cw * 1.3 * 90 / 220,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Opacity(
              opacity: _seg(t, 0.55, 0.65),
              child: Text(
                '$shown dari $_total suara',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Tak ada yang mencapai mayoritas: suasana mereda, dingin dan tenang.
  Widget _noMajority(double t) {
    final inT = Curves.easeOut.transform(_seg(t, 0.0, 0.35));
    final sway =
        math.sin(t * 2 * math.pi * 1.5) * 0.14 * (1 - _seg(t, 0.55, 1.0));
    return Opacity(
      opacity: inT,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: sway,
            child: const Icon(Icons.balance_rounded, size: 64, color: _teal),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tidak ada yang mencapai mayoritas',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Desa menahan napas. Kali ini tak seorang pun dituduh.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.white54),
          ),
          const SizedBox(height: 4),
          const Text(
            'Butuh lebih dari separuh suara.',
            style: TextStyle(fontSize: 12, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  // ---------- papan hitungan ----------

  Widget _board() {
    final wid = _phase == 3 ? _winnerId : null;
    final focus = (_phase == 1 && _stage >= 2 && _i < _votes.length)
        ? _votes[_i]['target_id'] as String?
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final p in _people)
            AnimatedOpacity(
              opacity: (_phase == 3 && wid != null && p.id != wid) ? 0.32 : 1,
              duration: const Duration(milliseconds: 400),
              child: _Tile(
                person: p,
                count: _counts[p.id] ?? 0,
                // Memerah saat mendekati mayoritas.
                heat: _phase == 1
                    ? ((_counts[p.id] ?? 0) / _need).clamp(0.0, 1.0).toDouble()
                    : 0.0,
                focused: focus == p.id,
                winner: wid == p.id,
                me: p.id == widget.myId,
                votedByMe: _myTarget == p.id && _phase >= 1 && _myVoteShown(p.id),
              ),
            ),
        ],
      ),
    );
  }

  /// Tanda "suaramu" di papan baru muncul setelah suaraku sendiri dibuka.
  bool _myVoteShown(String targetId) {
    if (_phase >= 2) return true;
    for (var k = 0; k <= _i && k < _votes.length; k++) {
      final v = _votes[k];
      if (v['voter_id'] == widget.myId && v['target_id'] == targetId) {
        return k < _i || _stage >= 3;
      }
    }
    return false;
  }

  Widget _majorityBanner() {
    final p = _person(_majorityId);
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Colors.black.withValues(alpha: 0.38)),
            Align(
              alignment: const Alignment(0, -0.3),
              child: TweenAnimationBuilder<double>(
                key: const ValueKey('banner'),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 520),
                curve: Curves.elasticOut,
                builder: (_, t, child) => Opacity(
                  opacity: t.clamp(0.0, 1.0).toDouble(),
                  child: Transform.scale(scale: 0.4 + 0.6 * t, child: child),
                ),
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
                  decoration: BoxDecoration(
                    color: EmbunColors.blood.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                          color: EmbunColors.blood.withValues(alpha: 0.7),
                          blurRadius: 44,
                          spreadRadius: 4),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (p != null) ...[
                        PlayerAvatar(
                          path: protagonistPath(p.card ?? 'default'),
                          size: 64,
                          ring: Colors.white,
                        ),
                        const SizedBox(height: 10),
                      ],
                      const Text('MAYORITAS',
                          style: TextStyle(
                              fontSize: 30,
                              letterSpacing: 6,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                      if (p != null)
                        Text(p.id == widget.myId ? 'Kamu' : p.name,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white70)),
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

/// Cincin kejut yang melebar dari kartu sasaran saat menerima suara.
class _HitRingPainter extends CustomPainter {
  final double t; // 0..1
  const _HitRingPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final e = Curves.easeOutCubic.transform(t);
    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide * (0.30 + 0.55 * e),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2 * (1 - t) + 0.6
        ..color = EmbunColors.blood.withValues(alpha: 0.75 * (1 - t)),
    );
  }

  @override
  bool shouldRepaint(covariant _HitRingPainter old) => old.t != t;
}

/// Gelombang kejut dua lapis saat yang dituduh mendarat.
class _ShockPainter extends CustomPainter {
  final double t; // 0..1
  const _ShockPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final c = size.center(Offset.zero);
    for (var k = 0; k < 2; k++) {
      final u = ((t - k * 0.14) / (1 - k * 0.14)).clamp(0.0, 1.0).toDouble();
      if (u <= 0 || u >= 1) continue;
      final e = Curves.easeOutCubic.transform(u);
      canvas.drawCircle(
        c,
        size.shortestSide * (0.45 + 1.0 * e),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0 * (1 - u) + 0.8
          ..color = EmbunColors.blood.withValues(alpha: 0.65 * (1 - u)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ShockPainter old) => old.t != t;
}

/// Bara merah dan jingga yang melayang naik, berulang selama hasil tampil.
class _EmberPainter extends CustomPainter {
  final double env; // 0..1 kemunculan
  final double loop; // 0..1 berulang
  const _EmberPainter({required this.env, required this.loop});

  @override
  void paint(Canvas canvas, Size size) {
    if (env <= 0) return;
    final p = Paint();
    for (var i = 0; i < 30; i++) {
      final u = (loop * (0.6 + 0.8 * _rnd(i, 1)) + _rnd(i, 2)) % 1.0;
      final x = size.width * _rnd(i, 3) + math.sin(u * 6 + i) * 14;
      final y = size.height * (1.02 - 0.95 * u);
      final r = 1.2 + 2.6 * _rnd(i, 4);
      final a = math.sin(u * math.pi) * 0.75 * env;
      p.color = (i.isEven ? EmbunColors.blood : const Color(0xFFFFB347))
          .withValues(alpha: a.clamp(0.0, 1.0).toDouble());
      canvas.drawCircle(Offset(x, y), r, p);
    }
  }

  @override
  bool shouldRepaint(covariant _EmberPainter old) =>
      old.env != env || old.loop != loop;
}

/// Kartu karakter dengan nama. Slot atas (22 px) selalu ada supaya kartu
/// pemilih dan sasaran sejajar, dengan atau tanpa tanda ("Suaramu", "Kamu").
class _VoteCard extends StatelessWidget {
  final String name;
  final String? card;
  final double width;
  final String? tag;
  final Color glow;
  final bool ring;

  const _VoteCard({
    required this.name,
    required this.card,
    required this.width,
    required this.glow,
    this.tag,
    this.ring = false,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width + 24,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 22,
          child: tag == null
              ? null
              : Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
            decoration: BoxDecoration(
              color: EmbunColors.gold,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(tag!,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF07130F))),
          ),
        ),
        DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: ring
                ? Border.all(color: EmbunColors.gold, width: 3)
                : null,
          ),
          child: CardArt(
            path: protagonistPath(card ?? 'default'),
            width: width,
            glow: glow,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 13.5, height: 1.2, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

/// Satu pemain di papan hitungan: avatar, nama, dan jumlah suara. Makin dekat
/// ke mayoritas ([heat] 0..1), bingkai dan cahayanya makin merah.
class _Tile extends StatelessWidget {
  final _Person person;
  final int count;
  final double heat;
  final bool focused;
  final bool winner;
  final bool me;
  final bool votedByMe;

  const _Tile({
    required this.person,
    required this.count,
    required this.heat,
    required this.focused,
    required this.winner,
    required this.me,
    required this.votedByMe,
  });

  @override
  Widget build(BuildContext context) {
    final hot = heat >= 0.5 ? (heat - 0.5) / 0.5 : 0.0;
    final border = winner
        ? EmbunColors.blood
        : focused
        ? EmbunColors.gold
        : hot > 0
        ? Color.lerp(Colors.white24, EmbunColors.blood, hot)!
        : me
        ? EmbunColors.gold.withValues(alpha: 0.55)
        : Colors.white24;
    final scale = winner ? 1.08 : (focused ? 1.05 : 1.0 + 0.05 * hot);
    final glowOn = winner || focused || hot > 0;
    final glowColor = (winner || (hot > 0 && !focused))
        ? EmbunColors.blood
        : EmbunColors.gold;
    final glowAlpha = winner ? 0.4 : (focused ? 0.4 : 0.15 + 0.3 * hot);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 68,
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      transform: Matrix4.diagonal3Values(scale, scale, 1),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        color: winner
            ? EmbunColors.blood.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: focused ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: border, width: (winner || focused || hot > 0) ? 2 : 1.2),
        boxShadow: glowOn
            ? [
          BoxShadow(
              color: glowColor.withValues(alpha: glowAlpha),
              blurRadius: 14),
        ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              PlayerAvatar(
                path: protagonistPath(person.card ?? 'default'),
                size: 36,
                ring: me ? EmbunColors.gold : Colors.white38,
              ),
              if (votedByMe)
                Positioned(
                  left: -4,
                  top: -4,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: EmbunColors.gold,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF05080F), width: 1.5),
                    ),
                    child: const Icon(Icons.how_to_vote_rounded,
                        size: 8, color: Color(0xFF05080F)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            person.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              color: me ? EmbunColors.gold : Colors.white70,
            ),
          ),
          const SizedBox(height: 2),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, a) => ScaleTransition(
                scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
                child: child),
            child: Text(
              count == 0 ? '·' : '$count',
              key: ValueKey(count),
              style: TextStyle(
                fontSize: count == 0 ? 14 : 19,
                height: 1.1,
                fontWeight: FontWeight.w900,
                color: count == 0
                    ? Colors.white30
                    : ((winner || hot > 0) ? EmbunColors.blood : EmbunColors.gold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}