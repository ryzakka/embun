import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'card_tile.dart';
import 'player_status.dart';

double _seg(double v, double a, double b) =>
    ((v - a) / (b - a)).clamp(0.0, 1.0).toDouble();

double _smooth(double x) => x * x * (3 - 2 * x);

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _rnd(int i, int k) {
  final v = math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
  return v - v.floorToDouble();
}

/// Muncul dari bawah sambil memudar masuk pada rentang [a]..[b] dari [t].
Widget _up(double t, double a, double b, Widget child, {double dy = 18}) {
  final e = _smooth(_seg(t, a, b));
  return Opacity(
    opacity: e,
    child: Transform.translate(offset: Offset(0, (1 - e) * dy), child: child),
  );
}

// ====================================================================
// Data statistik
// ====================================================================

class _Award {
  final String title;
  final IconData icon;
  final Color color;
  final String uid;
  final String text;
  const _Award(this.title, this.icon, this.color, this.uid, this.text);
}

class _Round {
  final int day, right, wrong, none;
  const _Round(this.day, this.right, this.wrong, this.none);
  int get total => right + wrong + none;
}

class _Stats {
  final String? antagId;
  final int offerCards, buys, votes, goodOffers, badOffers;
  final int rightTotal, wargaVotes;
  final List<_Round> rounds;
  final List<MapEntry<String, int>> topCards;
  final List<_Award> awards;
  const _Stats({
    required this.antagId,
    required this.offerCards,
    required this.buys,
    required this.votes,
    required this.goodOffers,
    required this.badOffers,
    required this.rightTotal,
    required this.wargaVotes,
    required this.rounds,
    required this.topCards,
    required this.awards,
  });
}

const _pageTitles = [
  'Akhir Kisah',
  'Dalam Angka',
  'Sidang Desa',
  'Cahaya & Kabut',
  'Gelar Para Pemain',
  'Siapa Mereka Sebenarnya',
];
const _pageMs = [6200, 3000, 3400, 3600, 4400, 2400];
const _lastPage = 5;

const _endReasonText = {
  'daun_penuh': 'Daun Hayu kembali penuh.',
  'tertangkap': 'Si Terbisik berhasil ditangkap.',
  'antag_left': 'Si Terbisik meninggalkan desa.',
  'daun_habis': 'Daun terakhir Hayu gugur.',
  'waktu_habis': 'Waktu habis sebelum desa pulih.',
};

/// Layar akhir permainan, bertahap seperti bab penutup:
///
///  0 Akhir Kisah    pohon, ring daun yang terisi (30 titik menyala satu per
///                   satu), judul, sebab berakhir, vonis
///  1 Dalam Angka    hari bertahan, persembahan, pembelian, suara (hitung naik)
///  2 Sidang Desa    batang suara tiap voting: tepat / keliru / abstain
///  3 Cahaya & Kabut tarik tambang kartu persembahan + kartu terbanyak
///  4 Gelar          penghargaan yang dihitung dari catatan permainan
///  5 Para Pemain    peran asli, nyawa, tombol catatan lengkap & pulang
///
/// Geser ke kiri/kanan atau pakai tombol bawah. "Lewati" langsung ke bab akhir.
/// Semua statistik dihitung dari data game_recap + rahasia yang terbuka di
/// akhir permainan, tanpa perubahan SQL.
class FinalResultScreen extends StatefulWidget {
  final bool wargaMenang;
  final int leaves;
  final int day;
  final String? verdict;
  final String? endReason;
  final List<Map<String, dynamic>> players;
  final Map<String, Map<String, dynamic>> defs;
  final Map<String, Map<String, dynamic>> abilityDefs;
  final Map<String, String> usernames;
  final Future<Map<String, Map<String, dynamic>>> secrets;
  final Future<Map<String, dynamic>?> recap;

  /// Rekap rinci per pemain (mis. `_recapSection` milik TablePage).
  final Widget Function(Map<String, Map<String, dynamic>> secrets)
  detailsBuilder;
  final VoidCallback onExit;

  const FinalResultScreen({
    super.key,
    required this.wargaMenang,
    required this.leaves,
    required this.day,
    required this.players,
    required this.defs,
    required this.abilityDefs,
    required this.usernames,
    required this.secrets,
    required this.recap,
    required this.detailsBuilder,
    required this.onExit,
    this.verdict,
    this.endReason,
  });

  @override
  State<FinalResultScreen> createState() => _FinalResultScreenState();
}

class _FinalResultScreenState extends State<FinalResultScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pa = AnimationController(
      vsync: this, duration: Duration(milliseconds: _pageMs[0]));
  late final AnimationController _loop = AnimationController(
      vsync: this, duration: const Duration(seconds: 600))
    ..repeat();

  int _page = 0;
  Map<String, Map<String, dynamic>> _secrets = {};
  Map<String, dynamic>? _recap;
  _Stats? _stats;
  bool _hapGauge = false;

  bool get _win => widget.wargaMenang;
  Color get _accent => _win ? EmbunColors.leaf : EmbunColors.mist;

  @override
  void initState() {
    super.initState();
    _pa.addListener(_onTick);
    _pa.forward();
    HapticFeedback.heavyImpact();
    _load();
  }

  @override
  void dispose() {
    _pa.dispose();
    _loop.dispose();
    super.dispose();
  }

  void _onTick() {
    if (_page == 0 && !_hapGauge && _pa.value >= 0.62) {
      _hapGauge = true;
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _load() async {
    try {
      _secrets = await widget.secrets;
    } catch (_) {}
    try {
      _recap = await widget.recap;
    } catch (_) {}
    if (!mounted) return;
    setState(() => _stats = _compute());
    // Statistik baru tiba saat pemain sudah di bab statistik: putar ulang.
    if (_page >= 1 && _page <= 4) _pa.forward(from: 0);
  }

  void _goto(int p) {
    if (p < 0 || p > _lastPage || p == _page) return;
    HapticFeedback.selectionClick();
    setState(() => _page = p);
    _pa.duration = Duration(milliseconds: _pageMs[p]);
    _pa.forward(from: 0);
  }

  // ------------------------------------------------------------ data

  String _nameOf(String uid) {
    for (final p in widget.players) {
      if (p['user_id'] == uid) return p['name'] as String;
    }
    return '?';
  }

  String? _cardOf(String uid) {
    for (final p in widget.players) {
      if (p['user_id'] == uid) return p['character_card'] as String?;
    }
    return null;
  }

  String _cardName(String id) => (widget.defs[id]?['name'] as String?) ?? id;

  _Stats _compute() {
    final r = _recap ?? const <String, dynamic>{};
    List<Map<String, dynamic>> list(String k) =>
        List<Map<String, dynamic>>.from((r[k] as List?) ?? const []);
    final offs = list('offerings');
    final buys = list('purchases');
    final votes = list('votes');

    String? antagId;
    for (final e in _secrets.entries) {
      if (e.value['role'] == 'antagonis') antagId = e.key;
    }
    final order = [for (final p in widget.players) p['user_id'] as String];

    final goodBy = <String, int>{};
    final badBy = <String, int>{};
    final buyBy = <String, int>{};
    final costBy = <String, int>{};
    final rightBy = <String, int>{};
    final wrongBy = <String, int>{};
    final recvBy = <String, int>{};
    final freq = <String, int>{};
    var good = 0, bad = 0;

    for (final o in offs) {
      final uid = o['user_id'] as String;
      final cid = o['card_id'] as String;
      freq[cid] = (freq[cid] ?? 0) + 1;
      if (widget.defs[cid]?['side'] == 'antagonis') {
        bad++;
        badBy[uid] = (badBy[uid] ?? 0) + 1;
      } else {
        good++;
        goodBy[uid] = (goodBy[uid] ?? 0) + 1;
      }
    }
    for (final b in buys) {
      final uid = b['user_id'] as String;
      final cid = b['card_id'] as String;
      buyBy[uid] = (buyBy[uid] ?? 0) + 1;
      costBy[uid] =
          (costBy[uid] ?? 0) + ((widget.defs[cid]?['cost'] as int?) ?? 0);
    }

    final byDay = <int, List<int>>{};
    var right = 0, wargaVotes = 0;
    for (final v in votes) {
      final uid = v['user_id'] as String;
      final d = v['day'] as int;
      final t = v['target_id'] as String?;
      if (t != null) recvBy[t] = (recvBy[t] ?? 0) + 1;
      if (antagId == null || uid == antagId) continue;
      final a = byDay.putIfAbsent(d, () => [0, 0, 0]);
      wargaVotes++;
      if (t == null) {
        a[2]++;
      } else if (t == antagId) {
        a[0]++;
        right++;
        rightBy[uid] = (rightBy[uid] ?? 0) + 1;
      } else {
        a[1]++;
        wrongBy[uid] = (wrongBy[uid] ?? 0) + 1;
      }
    }
    final days = byDay.keys.toList()..sort();
    final rounds = [
      for (final d in days) _Round(d, byDay[d]![0], byDay[d]![1], byDay[d]![2]),
    ];

    String? top(Map<String, int> m, {int min = 1, String? exclude}) {
      String? best;
      var bv = 0;
      for (final uid in order) {
        if (uid == exclude) continue;
        final v = m[uid] ?? 0;
        if (v > bv) {
          bv = v;
          best = uid;
        }
      }
      return bv >= min ? best : null;
    }

    final awards = <_Award>[];
    final eagle = top(rightBy);
    if (eagle != null) {
      awards.add(_Award('Mata Elang', Icons.visibility_rounded,
          EmbunColors.gold, eagle,
          '${rightBy[eagle]}× menunjuk Si Terbisik dengan tepat'));
    }
    final suspect = top(recvBy, min: 2);
    if (suspect != null) {
      final guilty = suspect == antagId;
      awards.add(_Award(
          'Paling Dicurigai',
          Icons.person_search_rounded,
          EmbunColors.blood,
          suspect,
          'Dituding ${recvBy[suspect]}× di seluruh sidang '
              '${antagId == null ? '' : guilty ? 'dan memang dalangnya' : 'padahal warga biasa'}'));
    }
    final wrong = top(wrongBy);
    if (wrong != null) {
      awards.add(_Award('Salah Sasaran', Icons.report_gmailerrorred_rounded,
          Colors.orangeAccent, wrong,
          '${wrongBy[wrong]}× menuding warga yang tak bersalah'));
    }
    final giver = top(goodBy, exclude: antagId);
    if (giver != null) {
      awards.add(_Award('Dermawan Hayu', Icons.volunteer_activism_rounded,
          EmbunColors.leaf, giver, '${goodBy[giver]} kartu dipersembahkan'));
    }
    final shopper = top(buyBy, min: 2);
    if (shopper != null) {
      awards.add(_Award('Pembelanja Ulung', Icons.shopping_bag_rounded,
          Colors.lightBlueAccent, shopper,
          '${buyBy[shopper]} kartu · ${costBy[shopper]} embun'));
    }
    if (antagId != null && (badBy[antagId] ?? 0) > 0) {
      awards.add(_Award('Dalang Kabut', Icons.nightlight_round,
          EmbunColors.mist, antagId,
          '${badBy[antagId]} kartu kabut dipersembahkan'));
    }

    final topCards = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _Stats(
      antagId: antagId,
      offerCards: offs.length,
      buys: buys.length,
      votes: votes.length,
      goodOffers: good,
      badOffers: bad,
      rightTotal: right,
      wargaVotes: wargaVotes,
      rounds: rounds,
      topCards: topCards.take(3).toList(),
      awards: awards,
    );
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Backdrop(
              path: landscapePath(widget.leaves), dark: !_win, dim: 0.62),
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _loop,
              builder: (_, _) => CustomPaint(
                painter: _AmbientPainter(
                  time: _loop.value * 600,
                  win: _win,
                  sakura: widget.leaves >= 30,
                ),
                size: Size.infinite,
              ),
            ),
          ),
          SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v < -300) _goto(_page + 1);
                if (v > 300) _goto(_page - 1);
              },
              child: Column(
                children: [
                  _topBar(),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(
                          scale: Tween(begin: 0.97, end: 1.0).animate(anim),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_page),
                        child: _pageBody(),
                      ),
                    ),
                  ),
                  _bottomBar(),
                ],
              ),
            ),
          ),
          // Kilatan pembuka: emas bila menang, redup pekat bila kalah.
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _pa,
              builder: (_, _) {
                if (_page != 0) return const SizedBox.shrink();
                final t = _pa.value;
                final a = _win
                    ? 0.75 * (1 - _smooth(_seg(t, 0, 0.12)))
                    : 0.7 * (1 - _smooth(_seg(t, 0, 0.3)));
                if (a <= 0.01) return const SizedBox.shrink();
                return ColoredBox(
                  color: (_win ? const Color(0xFFFFF0B0) : Colors.black)
                      .withValues(alpha: a),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const SizedBox(width: 16),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _pageTitles[_page].toUpperCase(),
                key: ValueKey(_page),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.4,
                  color: EmbunColors.gold,
                ),
              ),
            ),
          ),
          if (_page < _lastPage)
            TextButton(
              onPressed: () => _goto(_lastPage),
              child: const Text('Lewati'),
            ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: _page == 0
                ? null
                : IconButton(
              onPressed: () => _goto(_page - 1),
              icon: const Icon(Icons.chevron_left_rounded, size: 30),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i <= _lastPage; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: i == _page
                          ? EmbunColors.gold
                          : i < _page
                          ? EmbunColors.goldDim
                          : Colors.white24,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 120,
            child: _page == _lastPage
                ? null
                : EmbunButton(
              label: 'Lanjut',
              height: 44,
              onPressed: () => _goto(_page + 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageBody() {
    return AnimatedBuilder(
      animation: _pa,
      builder: (context, _) {
        final t = _pa.value;
        final Widget content;
        if (_page == 0) {
          content = _p0(t);
        } else if (_page == _lastPage) {
          content = _p5(t);
        } else if (_stats == null) {
          content = const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          );
        } else {
          content = switch (_page) {
            1 => _p1(t),
            2 => _p2(t),
            3 => _p3(t),
            _ => _p4(t),
          };
        }
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: content,
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------ bab 0

  Widget _p0(double t) {
    final leaves = widget.leaves;
    final sakura =
    leaves >= 30 ? AssetCatalog.I.file(pohonDir, 'pohon0-sakura') : null;
    final g = Curves.easeOutCubic.transform(_seg(t, 0.22, 0.62));
    final count = leaves * g;
    final treeIn = _smooth(_seg(t, 0, 0.2));
    final spacing =
    _lerp(8, 0.6, Curves.easeOut.transform(_seg(t, 0.5, 0.82)));
    final reason = _endReasonText[widget.endReason];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _up(
          t,
          0,
          0.15,
          SizedBox(
            height: 44,
            child: GameImage(
                path: logoPath('logoteks-transparent'),
                fit: BoxFit.contain,
                cacheWidth: 600),
          ),
        ),
        const SizedBox(height: 10),
        Opacity(
          opacity: treeIn,
          child: Transform.scale(
            scale: _lerp(0.92, 1, treeIn),
            child: SizedBox(
              height: 200,
              child: TreePortrait(leaves: leaves, pathOverride: sakura),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            SizedBox(
              width: 112,
              height: 112,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(112, 112),
                    painter: _GaugePainter(
                      count: count,
                      color: _accent,
                      glow: _win ? EmbunColors.gold : EmbunColors.blood,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${count.round()}',
                          style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: _accent,
                              height: 1)),
                      const Text('dari 30 daun',
                          style:
                          TextStyle(fontSize: 10, color: Colors.white60)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Opacity(
                    opacity: _smooth(_seg(t, 0.5, 0.7)),
                    child: Text(
                      _win ? 'Hayu mekar kembali!' : 'Hayu layu, desa kembali redup...',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: spacing,
                        height: 1.15,
                        color: _win ? EmbunColors.cream : Colors.white,
                        shadows: [
                          Shadow(
                              color: _accent.withValues(alpha: 0.7),
                              blurRadius: 18),
                        ],
                      ),
                    ),
                  ),
                  if (reason != null) ...[
                    const SizedBox(height: 6),
                    _up(t, 0.66, 0.82,
                        Text(reason,
                            style: const TextStyle(
                                color: Colors.white70, height: 1.3))),
                  ],
                  if (widget.verdict != null) ...[
                    const SizedBox(height: 4),
                    _up(t, 0.76, 0.92,
                        Text(widget.verdict!,
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: Colors.white54,
                                height: 1.3))),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------------ bab 1

  Widget _tile(String icon, String label, int value, double t, double a) {
    final e = _smooth(_seg(t, a, a + 0.25));
    final n = (value * Curves.easeOutCubic.transform(_seg(t, a + 0.05, a + 0.6)))
        .round();
    return Opacity(
      opacity: e,
      child: Transform.scale(
        scale: _lerp(0.85, 1, e),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border:
            Border.all(color: EmbunColors.goldDim.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                  color: EmbunColors.gold.withValues(alpha: 0.12 * e),
                  blurRadius: 18),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GameIcon(icon, size: 40),
              const SizedBox(height: 6),
              Text('$n',
                  style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: EmbunColors.gold,
                      height: 1.1)),
              const SizedBox(height: 2),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _p1(double t) {
    final s = _stats!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Expanded(child: _tile('timer', 'hari dilewati', widget.day, t, 0.0)),
          const SizedBox(width: 12),
          Expanded(
              child: _tile('donations', 'kartu dipersembahkan', s.offerCards, t, 0.14)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: _tile('bulirembun', 'kartu dibeli', s.buys, t, 0.28)),
          const SizedBox(width: 12),
          Expanded(child: _tile('vote', 'suara diberikan', s.votes, t, 0.42)),
        ]),
      ],
    );
  }

  // ------------------------------------------------------------ bab 2

  Widget _legendDot(Color c, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(text, style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
    ],
  );

  Widget _p2(double t) {
    final s = _stats!;
    if (s.antagId == null || s.rounds.isEmpty) {
      return const Text('Tidak ada voting yang tercatat.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60));
    }
    final maxTot = s.rounds.fold<int>(1, (m, r) => math.max(m, r.total));
    final unit = 118.0 / maxTot;
    final pct = s.wargaVotes == 0 ? 0.0 : s.rightTotal / s.wargaVotes;
    final shown =
    (pct * 100 * Curves.easeOutCubic.transform(_seg(t, 0.1, 0.7))).round();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _up(
          t,
          0,
          0.2,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$shown%',
                  style: const TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.w800,
                      color: EmbunColors.leaf)),
              const SizedBox(width: 10),
              const Flexible(
                child: Text('suara warga tepat\nmenunjuk Si Terbisik',
                    style: TextStyle(color: Colors.white70, height: 1.3)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          height: 190,
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < s.rounds.length; i++)
                Expanded(child: _bar(s.rounds[i], i, t, unit)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _up(
          t,
          0.6,
          0.8,
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 6,
            children: [
              _legendDot(EmbunColors.leaf, 'Tepat'),
              _legendDot(EmbunColors.blood, 'Keliru'),
              _legendDot(Colors.white38, 'Tak memilih'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bar(_Round r, int i, double t, double unit) {
    final g = Curves.easeOutCubic
        .transform(_seg(t, 0.15 + 0.08 * i, 0.6 + 0.08 * i));
    Widget seg(int n, Color c) => n == 0
        ? const SizedBox.shrink()
        : Container(
      height: n * unit * g,
      margin: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: 8)],
      ),
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Opacity(
          opacity: _smooth(_seg(g, 0.6, 1)),
          child: Text('${r.total}',
              style: const TextStyle(fontSize: 11, color: Colors.white60)),
        ),
        const SizedBox(height: 2),
        Center(
          child: SizedBox(
            width: 28,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                seg(r.none, Colors.white38),
                seg(r.wrong, EmbunColors.blood),
                seg(r.right, EmbunColors.leaf),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text('H${r.day}',
            style: const TextStyle(fontSize: 11, color: EmbunColors.goldDim)),
      ],
    );
  }

  // ------------------------------------------------------------ bab 3

  Widget _p3(double t) {
    final s = _stats!;
    final total = s.goodOffers + s.badOffers;
    if (total == 0) {
      return const Text('Tidak ada persembahan yang tercatat.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60));
    }
    final target = s.goodOffers / total;
    final e = Curves.easeOutCubic.transform(_seg(t, 0.1, 0.6));
    final share = _lerp(0.5, target, e);
    final goodN = (s.goodOffers * e).round();
    final badN = (s.badOffers * e).round();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _up(
          t,
          0,
          0.15,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cahaya  $goodN',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: EmbunColors.leaf)),
              Text('$badN  Kabut',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: EmbunColors.mist)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          final x = w * share;
          return SizedBox(
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Row(
                    children: [
                      SizedBox(
                        width: x,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Color(0xFF2E7350),
                              EmbunColors.leaf,
                            ]),
                          ),
                          child: SizedBox.expand(),
                        ),
                      ),
                      const Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              EmbunColors.mist,
                              Color(0xFF2A1646),
                            ]),
                          ),
                          child: SizedBox.expand(),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: x - 2,
                  top: -5,
                  bottom: -5,
                  width: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: const [
                        BoxShadow(color: Colors.white70, blurRadius: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 22),
        if (s.topCards.isNotEmpty) ...[
          _up(
              t,
              0.4,
              0.55,
              const Text('Kartu yang paling sering dipersembahkan',
                  style: TextStyle(fontSize: 12.5, color: Colors.white60))),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < s.topCards.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _up(
                    t,
                    0.45 + 0.12 * i,
                    0.7 + 0.12 * i,
                    _topCard(s.topCards[i]),
                    dy: 30,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _topCard(MapEntry<String, int> e) {
    return SizedBox(
      width: 88,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CardTile(
                  def: widget.defs[e.key], fallbackName: e.key, width: 88),
              Positioned(
                right: -6,
                top: -8,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: EmbunColors.gold),
                  ),
                  child: Text('×${e.value}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: EmbunColors.gold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(_cardName(e.key),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ bab 4

  Widget _p4(double t) {
    final s = _stats!;
    if (s.awards.isEmpty) {
      return const Text('Tak ada yang menonjol kali ini.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < s.awards.length; i++)
          _awardRow(s.awards[i], _seg(t, 0.04 + 0.15 * i, 0.26 + 0.15 * i)),
      ],
    );
  }

  Widget _awardRow(_Award a, double p) {
    // Seperti cap ditekan: membesar lalu mendarat dengan sedikit memantul.
    final e = Curves.easeOutBack.transform(p);
    final op = _smooth(_seg(p, 0, 0.5));
    return Opacity(
      opacity: op,
      child: Transform.scale(
        scale: _lerp(1.3, 1, e),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: a.color.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(
                  color: a.color.withValues(alpha: 0.28 * (1 - p) + 0.08),
                  blurRadius: 22),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: a.color.withValues(alpha: 0.18),
                  border: Border.all(color: a.color),
                ),
                child: Icon(a.icon, color: a.color, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: a.color)),
                    const SizedBox(height: 2),
                    Text(a.text,
                        style: const TextStyle(
                            fontSize: 12.5, color: Colors.white70, height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 62,
                child: Column(
                  children: [
                    PlayerAvatar(
                      path: protagonistPath(_cardOf(a.uid) ?? 'default'),
                      size: 42,
                      ring: a.color,
                    ),
                    const SizedBox(height: 3),
                    Text(_nameOf(a.uid),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ bab 5

  Widget _p5(double t) {
    // Si Terbisik di urutan pertama, sisanya menurut urutan meja.
    final ps = [...widget.players];
    ps.sort((a, b) {
      final x = _secrets[a['user_id']]?['role'] == 'antagonis' ? 0 : 1;
      final y = _secrets[b['user_id']]?['role'] == 'antagonis' ? 0 : 1;
      return x.compareTo(y);
    });

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < ps.length; i++)
          _up(t, 0.04 + 0.1 * i, 0.3 + 0.1 * i, _playerRow(ps[i]), dy: 24),
        const SizedBox(height: 16),
        _up(
          t,
          0.5,
          0.8,
          Column(
            children: [
              EmbunButton(
                label: 'Catatan lengkap',
                icon: 'logorhistory',
                kind: EmbunButtonKind.secondary,
                expand: true,
                onPressed: _showDetails,
              ),
              const SizedBox(height: 10),
              EmbunButton(
                label: 'Kembali ke balai',
                icon: 'home',
                expand: true,
                onPressed: widget.onExit,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _playerRow(Map<String, dynamic> p) {
    final uid = p['user_id'] as String;
    final antag = _secrets[uid]?['role'] == 'antagonis';
    final hasRole = _secrets[uid]?['role'] != null;
    final uname = widget.usernames[uid];
    final ability = antag
        ? null
        : widget.abilityDefs['${_secrets[uid]?['ability']}']?['name'] as String?;
    final col = antag ? EmbunColors.mist : EmbunColors.leaf;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: (antag ? EmbunColors.mist : Colors.white24)
                .withValues(alpha: antag ? 0.9 : 1)),
        boxShadow: antag
            ? [
          BoxShadow(
              color: EmbunColors.mist.withValues(alpha: 0.3),
              blurRadius: 18),
        ]
            : null,
      ),
      child: Row(
        children: [
          PlayerAvatar(
            path: protagonistPath(p['character_card'] as String),
            size: 46,
            ring: antag ? EmbunColors.mist : EmbunColors.goldDim,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['name'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                Text(
                  [
                    if (uname != null) uname,
                    if (hasRole) antag ? 'Si Terbisik' : 'Warga Desa',
                    if (ability != null) ability,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12, color: hasRole ? col : Colors.white60),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isOut(p))
            const StatusTag(text: 'Keluar', color: Colors.white54)
          else
            LivesRow(lives: livesLeft(p), size: 16),
        ],
      ),
    );
  }

  void _showDetails() {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: OrnatePanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    child: widget.detailsBuilder(_secrets),
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
}

// ====================================================================
// Pelukis
// ====================================================================

/// Cincin 30 titik: tiap titik menyala menurut jumlah daun; titik terbaru
/// berpijar.
class _GaugePainter extends CustomPainter {
  final double count;
  final Color color, glow;
  const _GaugePainter(
      {required this.count, required this.color, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 6;
    canvas.drawCircle(
      c,
      r * 0.85,
      Paint()
        ..shader = RadialGradient(colors: [
          color.withValues(alpha: 0.22 * (count / 30).clamp(0.0, 1.0)),
          color.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final head = count.floor();
    for (var i = 0; i < 30; i++) {
      final ang = -math.pi / 2 + i * 2 * math.pi / 30;
      final dir = Offset(math.cos(ang), math.sin(ang));
      final lit = (count - i).clamp(0.0, 1.0).toDouble();
      final paint = Paint()
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(Colors.white24, color, lit)!;
      canvas.drawLine(c + dir * (r - 11), c + dir * r, paint);
      if (i == head && lit > 0 && lit < 1 && count < 30) {
        canvas.drawCircle(
          c + dir * r,
          6,
          Paint()
            ..color = glow.withValues(alpha: 0.9)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.count != count || old.color != color;
}

/// Suasana di latar sepanjang layar akhir.
///  Menang : daun / kelopak berguguran pelan + kunang-kunang naik.
///  Kalah  : abu berjatuhan + kabut ungu melintas.
class _AmbientPainter extends CustomPainter {
  final double time;
  final bool win, sakura;
  const _AmbientPainter(
      {required this.time, required this.win, required this.sakura});

  Path _leaf(double s) => Path()
    ..moveTo(0, -s)
    ..quadraticBezierTo(s * 0.8, -s * 0.2, 0, s)
    ..quadraticBezierTo(-s * 0.8, -s * 0.2, 0, -s)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < 36; i++) {
      final speed = 0.018 + 0.03 * _rnd(i, 1);
      final u = (time * speed + _rnd(i, 2)) % 1.0;
      final x = _rnd(i, 3) * size.width + math.sin(time * 0.6 + i) * 20;
      final kind = i % 3;
      if (win) {
        if (kind < 2) {
          final y = size.height * u;
          final a = (math.sin(u * math.pi) * 0.75).clamp(0.0, 1.0).toDouble();
          paint.color = (sakura
              ? const Color(0xFFFFB7CF)
              : Color.lerp(EmbunColors.leaf, EmbunColors.gold, _rnd(i, 4))!)
              .withValues(alpha: a);
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(time * 0.5 * (_rnd(i, 5) - 0.5) + i);
          canvas.drawPath(_leaf(5 + 5 * _rnd(i, 6)), paint);
          canvas.restore();
        } else {
          final y = size.height * (1.05 - 1.1 * u);
          final a = (math.sin(u * math.pi) * 0.8).clamp(0.0, 1.0).toDouble();
          paint
            ..color = EmbunColors.gold.withValues(alpha: a)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
          canvas.drawCircle(Offset(x, y), 1.8 + 2 * _rnd(i, 7), paint);
          paint.maskFilter = null;
        }
      } else {
        if (kind < 2) {
          final y = size.height * u;
          final a = (math.sin(u * math.pi) * 0.5).clamp(0.0, 1.0).toDouble();
          paint.color = const Color(0xFFB9B2C8).withValues(alpha: a);
          canvas.drawCircle(Offset(x, y), 1.2 + 1.8 * _rnd(i, 6), paint);
        } else {
          final xx = size.width * ((u * 1.4) - 0.2);
          final y = size.height * (0.15 + 0.7 * _rnd(i, 8));
          final r = size.shortestSide * (0.25 + 0.25 * _rnd(i, 9));
          final a = math.sin(u * math.pi) * 0.14;
          paint
            ..maskFilter = null
            ..shader = RadialGradient(colors: [
              EmbunColors.mist.withValues(alpha: a),
              EmbunColors.mist.withValues(alpha: 0),
            ]).createShader(Rect.fromCircle(center: Offset(xx, y), radius: r));
          canvas.drawCircle(Offset(xx, y), r, paint);
          paint.shader = null;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter old) => true;
}