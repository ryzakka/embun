import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../../data/game_rules.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import '../common/sfx.dart';
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

class _Day {
  final int day;
  final List<(String, String)> offers; // (pemain, kartu)
  final List<(String, String)> buys; // (pemain, kartu)
  final String? top; // paling banyak dituding; null = seri / tanpa sidang
  final int topN, voters;
  final bool caught;
  const _Day({
    required this.day,
    required this.offers,
    required this.buys,
    required this.top,
    required this.topN,
    required this.voters,
    required this.caught,
  });
}

class _Acc {
  final String uid;
  final int right, total;
  const _Acc(this.uid, this.right, this.total);
}

class _Stats {
  final String? antagId;
  final int offerCards, buys, votes, goodOffers, badOffers;
  final int rightTotal, wargaVotes;
  final List<_Round> rounds;
  final List<MapEntry<String, int>> topCards;
  final List<_Award> awards;
  final List<_Day> chron;
  final List<_Acc> acc;
  final int spent;
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
    required this.chron,
    required this.acc,
    required this.spent,
  });
}

const _pageTitles = [
  'Akhir Kisah',
  'Barisan Akhir',
  'Dalam Angka',
  'Kronik Desa',
  'Sidang Desa',
  'Cahaya & Kabut',
  'Gelar Para Pemain',
  'Para Pemain',
];
const _pageTabs = [
  'Hasil',
  'Barisan',
  'Angka',
  'Kronik',
  'Sidang',
  'Persembahan',
  'Gelar',
  'Pemain',
];
const _pageMs = [3400, 3000, 1050, 1100, 1100, 1100, 1200, 900];
const _lastPage = 7;

const _endReasonText = {
  'daun_penuh': 'Daun Hayu kembali penuh.',
  'tertangkap': 'Si Terbisik berhasil ditangkap.',
  'panah': 'Si Terbisik tumbang oleh Busur Terakhir.',
  'antag_left': 'Si Terbisik meninggalkan desa.',
  'daun_habis': 'Daun terakhir Hayu gugur.',
  'waktu_habis': 'Waktu habis sebelum desa pulih.',
};

/// Layar akhir permainan, bertahap seperti bab penutup:
///
///  0 Akhir Kisah    pohon, ring daun yang terisi (30 titik menyala satu per
///                   satu), judul, sebab berakhir, vonis
///  1 Barisan Akhir  kartu semua pemain muncul per fraksi: pemenang ala juara,
///                   yang kalah ala runtuh (lihat [_pFaction])
///  2 Dalam Angka    hari bertahan, persembahan, pembelian, suara (hitung naik)
///  3 Kronik Desa    garis waktu hari demi hari: persembahan, pembelian, sidang
///  4 Sidang Desa    batang suara tiap voting + ketepatan tiap pemain
///  5 Cahaya & Kabut tarik tambang kartu persembahan + kartu terbanyak
///  6 Gelar          penghargaan yang dihitung dari catatan permainan
///  7 Para Pemain    peran asli, nyawa, catatan lengkap, dan tombol kembali
///
/// Gunakan tab, tombol bawah, atau geser isi untuk berganti bab.
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

  /// Id pemain yang sedang melihat layar ini; dipakai untuk menentukan
  /// fraksi "milikku" di bab Barisan Akhir.
  final String? myId;
  final Future<Map<String, Map<String, dynamic>>> secrets;
  final Future<Map<String, dynamic>?> recap;

  /// Rekap rinci per pemain (mis. `_recapSection` milik TablePage).
  final Widget Function(Map<String, Map<String, dynamic>> secrets)
  detailsBuilder;
  final VoidCallback onExit;

  const FinalResultScreen({
    super.key,
    this.myId,
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
    vsync: this,
    duration: Duration(milliseconds: _pageMs[0]),
  );
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 600),
  );

  late final TabController _tabs = TabController(
    length: _pageTabs.length,
    vsync: this,
  );
  int _page = 0;
  bool _loadingSecrets = true;
  bool _loadingRecap = true;
  Map<String, Map<String, dynamic>> _secrets = {};
  Map<String, dynamic>? _recap;
  _Stats? _stats;
  bool _hapGauge = false;
  final Set<int> _hap = {};

  bool get _win => widget.wargaMenang;
  Color get _accent => _win ? EmbunColors.leaf : EmbunColors.mist;

  /// Hasil untuk pemain ini (bukan hanya kubu pemenang). Selama peran belum
  /// termuat, dianggap sama dengan kubu pemenang.
  bool get _iWon => _viewerWon ?? _win;
  bool get _iKnow => _viewerWon != null;

  @override
  void initState() {
    super.initState();
    _pa.addListener(_onTick);
    _pa.forward();
    Sfx.I.music(Snd.bgmAkhir, owner: this);
    HapticFeedback.heavyImpact();
    _loadSecrets();
    _loadRecap();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _pa.dispose();
    _loop.dispose();
    Sfx.I.release(this);
    super.dispose();
  }

  void _onTick() {
    if (_page == 1) {
      final t = _pa.value;
      // Pemenang tiba: berat. Pihak kalah menghantam tanah sedikit lebih lambat.
      final arrive = _viewerWon == false ? 0.20 : 0.10;
      if (t >= arrive && _hap.add(1)) HapticFeedback.heavyImpact();
      if (t >= 0.55 && _hap.add(2)) HapticFeedback.mediumImpact();
    }
    if (_page == 0 && !_hapGauge && _pa.value >= 0.62) {
      _hapGauge = true;
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _loadSecrets() async {
    var secrets = <String, Map<String, dynamic>>{};
    try {
      secrets = await widget.secrets;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _secrets = secrets;
      _loadingSecrets = false;
      if (_recap != null) _stats = _compute();
    });
    if (_page == 1 && secrets.isNotEmpty && !_reduceMotion) {
      _hap.clear();
      _pa.forward(from: 0);
    }
  }

  Future<void> _loadRecap() async {
    Map<String, dynamic>? recap;
    try {
      recap = await widget.recap;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _recap = recap;
      _loadingRecap = false;
      if (recap != null) _stats = _compute();
    });
    if (_page >= 2 && _page < _lastPage && recap != null && !_reduceMotion) {
      _pa.forward(from: 0);
    }
  }

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion) {
      _pa.stop();
      _loop.stop();
    } else if (!_loop.isAnimating) {
      _loop.repeat();
      if (!_pa.isAnimating && _pa.value < 1) _pa.forward();
    }
  }

  void _goto(int p) {
    if (p < 0 || p > _lastPage || p == _page) return;
    HapticFeedback.selectionClick();
    _hap.clear();
    setState(() => _page = p);
    if (_tabs.index != p) _tabs.animateTo(p);
    _pa.duration = Duration(milliseconds: _pageMs[p]);
    if (!_reduceMotion) _pa.forward(from: 0);
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
    final noneBy = <String, int>{};
    final tally = <int, Map<String, int>>{};
    final voteN = <int, int>{};
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
      if (t != null) {
        recvBy[t] = (recvBy[t] ?? 0) + 1;
        final m = tally.putIfAbsent(d, () => {});
        m[t] = (m[t] ?? 0) + 1;
      }
      voteN[d] = (voteN[d] ?? 0) + 1;
      if (antagId == null || uid == antagId) continue;
      final a = byDay.putIfAbsent(d, () => [0, 0, 0]);
      wargaVotes++;
      if (t == null) {
        a[2]++;
        noneBy[uid] = (noneBy[uid] ?? 0) + 1;
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
      awards.add(
        _Award(
          'Mata Elang',
          Icons.visibility_rounded,
          EmbunColors.gold,
          eagle,
          '${rightBy[eagle]}× menunjuk Si Terbisik dengan tepat',
        ),
      );
    }
    final suspect = top(recvBy, min: 2);
    if (suspect != null) {
      final guilty = suspect == antagId;
      awards.add(
        _Award(
          'Paling Dicurigai',
          Icons.person_search_rounded,
          EmbunColors.blood,
          suspect,
          'Dituding ${recvBy[suspect]}× di seluruh sidang '
              '${antagId == null
                  ? ''
                  : guilty
                  ? 'dan memang dalangnya'
                  : 'padahal warga biasa'}',
        ),
      );
    }
    final wrong = top(wrongBy);
    if (wrong != null) {
      awards.add(
        _Award(
          'Salah Sasaran',
          Icons.report_gmailerrorred_rounded,
          Colors.orangeAccent,
          wrong,
          '${wrongBy[wrong]}× menuding warga yang tak bersalah',
        ),
      );
    }
    final giver = top(goodBy, exclude: antagId);
    if (giver != null) {
      awards.add(
        _Award(
          'Dermawan Hayu',
          Icons.volunteer_activism_rounded,
          EmbunColors.leaf,
          giver,
          '${goodBy[giver]} kartu dipersembahkan',
        ),
      );
    }
    final shopper = top(buyBy, min: 2);
    if (shopper != null) {
      awards.add(
        _Award(
          'Pembelanja Ulung',
          Icons.shopping_bag_rounded,
          Colors.lightBlueAccent,
          shopper,
          '${buyBy[shopper]} kartu · ${costBy[shopper]} embun',
        ),
      );
    }
    if (antagId != null && (badBy[antagId] ?? 0) > 0) {
      awards.add(
        _Award(
          'Dalang Kabut',
          Icons.nightlight_round,
          EmbunColors.mist,
          antagId,
          '${badBy[antagId]} kartu kabut dipersembahkan',
        ),
      );
    }

    // Kronik: peristiwa tiap hari, urut dari hari pertama.
    final dayKeys = <int>{
      for (final o in offs) o['day'] as int,
      for (final b in buys) b['day'] as int,
      ...tally.keys,
      ...voteN.keys,
    }.toList()..sort();
    final chron = <_Day>[];
    for (final d in dayKeys) {
      String? topId;
      var topN = 0;
      var tie = false;
      for (final e in (tally[d] ?? const <String, int>{}).entries) {
        if (e.value > topN) {
          topN = e.value;
          topId = e.key;
          tie = false;
        } else if (e.value == topN) {
          tie = true;
        }
      }
      chron.add(
        _Day(
          day: d,
          offers: [
            for (final o in offs)
              if (o['day'] == d)
                (o['user_id'] as String, o['card_id'] as String),
          ],
          buys: [
            for (final b in buys)
              if (b['day'] == d)
                (b['user_id'] as String, b['card_id'] as String),
          ],
          top: tie ? null : topId,
          topN: topN,
          voters: voteN[d] ?? 0,
          caught: !tie && topId != null && topId == antagId,
        ),
      );
    }

    // Ketepatan suara tiap warga, yang terbaik di atas.
    final acc =
        <_Acc>[
          for (final uid in order)
            if (uid != antagId)
              if ((rightBy[uid] ?? 0) +
                      (wrongBy[uid] ?? 0) +
                      (noneBy[uid] ?? 0) >
                  0)
                _Acc(
                  uid,
                  rightBy[uid] ?? 0,
                  (rightBy[uid] ?? 0) +
                      (wrongBy[uid] ?? 0) +
                      (noneBy[uid] ?? 0),
                ),
        ]..sort((a, b) {
          final pa = a.right / a.total, pb = b.right / b.total;
          return pb != pa ? pb.compareTo(pa) : b.right.compareTo(a.right);
        });

    // Penghargaan tambahan.
    for (final a in acc) {
      if (a.right >= 2 && a.right == a.total) {
        awards.add(
          _Award(
            'Tak Pernah Meleset',
            Icons.gps_fixed_rounded,
            EmbunColors.cream,
            a.uid,
            '${a.right} dari ${a.total} suara tepat',
          ),
        );
        break;
      }
    }
    final hesitant = top(noneBy, min: 2);
    if (hesitant != null) {
      awards.add(
        _Award(
          'Paling Ragu',
          Icons.hourglass_empty_rounded,
          Colors.white70,
          hesitant,
          '${noneBy[hesitant]}× memilih tak memilih',
        ),
      );
    }
    if (antagId != null) {
      final escaped = chron.where((x) => x.voters > 0 && !x.caught).length;
      if (escaped > 0) {
        awards.add(
          _Award(
            'Bayang Lolos',
            Icons.blur_on_rounded,
            EmbunColors.mist,
            antagId,
            'Lolos dari tudingan terbanyak $escaped sidang',
          ),
        );
      }
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
      chron: chron,
      acc: acc,
      spent: costBy.values.fold<int>(0, (a, b) => a + b),
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
            path: _win
                ? landscapePath(widget.leaves)
                : (defeatScenery(
                        leaves: widget.leaves,
                        endReason: widget.endReason,
                      ) ??
                      landscapePath(widget.leaves)),
            dark: !_win,
            dim: 0.62,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xC3091711),
                  Color(0x3007130F),
                  Color(0xEC07130F),
                ],
                stops: [0, 0.42, 1],
              ),
            ),
          ),
          // Daun habis: hantu murka menampakkan diri bergiliran di lembah.
          if (!_reduceMotion &&
              !_win &&
              (widget.leaves <= 0 || widget.endReason == 'daun_habis'))
            Apparition(paths: wrathGhostPaths()),
          if (!_reduceMotion)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _loop,
                builder: (_, _) => CustomPaint(
                  painter: _AmbientPainter(
                    time: _loop.value * 600,
                    win: _iWon,
                    sakura: widget.leaves >= kLeavesMax,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1150),
                child: LayoutBuilder(
                  builder: (context, box) => Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: box.maxWidth < 460 ? 12 : 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _topBar(box.maxWidth),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onHorizontalDragEnd: (d) {
                              final v = d.primaryVelocity ?? 0;
                              if (v < -300) _goto(_page + 1);
                              if (v > 300) _goto(_page - 1);
                            },
                            child: _pageBody(),
                          ),
                        ),
                        _bottomBar(box.maxWidth),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Kilatan pembuka: emas bila menang, redup pekat bila kalah.
          if (!_reduceMotion)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _pa,
                builder: (_, _) {
                  if (_page != 0) return const SizedBox.shrink();
                  final t = _pa.value;
                  final a = _iWon
                      ? 0.75 * (1 - _smooth(_seg(t, 0, 0.12)))
                      : 0.7 * (1 - _smooth(_seg(t, 0, 0.3)));
                  if (a <= 0.01) return const SizedBox.shrink();
                  return ColoredBox(
                    color: (_iWon ? const Color(0xFFFFF0B0) : Colors.black)
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

  BorderSide _rule([Color color = EmbunColors.gold]) =>
      BorderSide(color: color.withValues(alpha: 0.28));

  String get _winnerName => _factionName(!_win);

  Widget _topBar(double width) {
    final compact = width < 540;
    final scrollTabs =
        width < 830 || MediaQuery.textScalerOf(context).scale(13) > 16;
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: _rule())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: compact ? 4 : 8),
            child: Row(
              children: [
                if (width >= 370) ...[
                  const GameIcon('logorhistory', size: 28),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    width < 370 ? 'Hasil akhir' : 'Hasil Permainan',
                    semanticsLabel: 'Hasil Permainan',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: EmbunColors.cream,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Hari ${widget.day}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: EmbunColors.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_iKnow && _page != 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    _iWon ? 'Menang' : 'Kalah',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _iWon ? EmbunColors.gold : EmbunColors.blood,
                    ),
                  ),
                ],
              ],
            ),
          ),
          TabBar(
            controller: _tabs,
            onTap: _goto,
            isScrollable: scrollTabs,
            tabAlignment: scrollTabs ? TabAlignment.start : TabAlignment.fill,
            dividerHeight: 0,
            indicatorColor: EmbunColors.gold,
            labelColor: EmbunColors.gold,
            unselectedLabelColor: EmbunColors.cream,
            labelPadding: EdgeInsets.symmetric(horizontal: scrollTabs ? 11 : 4),
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
            tabs: [
              for (final label in _pageTabs)
                Tab(height: compact ? 38 : 42, text: label),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(double width) {
    final last = _page == _lastPage;
    final caption = 'Bagian ${_page + 1} dari ${_pageTabs.length}';
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(top: _rule())),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Bagian sebelumnya',
              onPressed: _page == 0 ? null : () => _goto(_page - 1),
              icon: const Icon(Icons.chevron_left_rounded, size: 24),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 230),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_page + 1} / ${_pageTabs.length}',
                        semanticsLabel: caption,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: (_page + 1) / _pageTabs.length,
                        color: EmbunColors.gold,
                        backgroundColor: Colors.white12,
                        minHeight: 2,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: math.max(0, width - 100)),
              child: EmbunButton(
                label: last ? 'Kembali ke balai' : 'Lanjut',
                height: 42,
                onPressed: last ? widget.onExit : () => _goto(_page + 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notice(String message, {bool loading = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(
      children: [
        if (loading)
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          const Icon(
            Icons.info_outline_rounded,
            color: EmbunColors.gold,
            size: 19,
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message, style: const TextStyle(color: Colors.white70)),
        ),
      ],
    ),
  );

  Widget _heading(String text) => Semantics(
    header: true,
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 25,
        height: 1.15,
        fontWeight: FontWeight.w800,
        color: EmbunColors.cream,
      ),
    ),
  );

  Widget _pageBody() => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      key: ValueKey(_page),
      primary: false,
      padding: EdgeInsets.symmetric(vertical: box.maxHeight < 340 ? 10 : 20),
      child: AnimatedBuilder(
        animation: _page == 1 ? Listenable.merge([_pa, _loop]) : _pa,
        builder: (context, _) {
          final t = _reduceMotion ? 1.0 : _pa.value;
          final Widget content;
          if (_page == 0) {
            content = _p0(t, box.maxWidth, box.maxHeight);
          } else if (_page == _lastPage) {
            content = _p5(t);
          } else if (_page == 1) {
            content = _loadingSecrets
                ? _notice('Memuat peran pemain…', loading: true)
                : _pFaction(t, box.maxWidth);
          } else if (_loadingRecap) {
            content = _notice('Memuat statistik…', loading: true);
          } else if (_stats == null) {
            content = _notice('Statistik pertandingan tidak tersedia.');
          } else {
            content = switch (_page) {
              2 => _p1(t),
              3 => _pKronik(t),
              4 => _p2(t),
              5 => _p3(t),
              _ => _p4(t),
            };
          }
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _page == 3 ? 750 : 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_page != 0) ...[
                    _heading(_pageTitles[_page]),
                    const SizedBox(height: 15),
                  ],
                  content,
                ],
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _p0(double t, double width, double height) {
    final leaves = widget.leaves;
    final sakura = leaves >= kLeavesMax
        ? AssetCatalog.I.file(pohonDir, 'pohon0-sakura')
        : null;
    final count = leaves * Curves.easeOutCubic.transform(_seg(t, 0.10, 0.62));
    final reason = _endReasonText[widget.endReason];
    final title = !_iKnow
        ? '$_winnerName menang'
        : _iWon
        ? 'Kamu menang'
        : 'Kamu kalah';
    final resultColor = _iKnow && !_iWon ? EmbunColors.blood : EmbunColors.gold;
    final wide = width >= 650;
    final compact = height < 340;
    final story = _up(
      t,
      0.02,
      0.19,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'AKHIR KISAH',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w800,
              color: resultColor,
            ),
          ),
          const SizedBox(height: 5),
          Semantics(
            header: true,
            child: Text(
              title,
              style: TextStyle(
                color: EmbunColors.cream,
                fontSize: wide && !compact ? 50 : 34,
                fontWeight: FontWeight.w900,
                height: 1.08,
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (_iKnow)
            Text(
              '$_winnerName menang',
              style: TextStyle(
                fontSize: 14,
                color: resultColor,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
    final ending = _up(
      t,
      0.12,
      0.32,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _win ? 'Hayu mekar kembali!' : 'Hayu layu, desa kembali redup.',
            style: const TextStyle(
              color: EmbunColors.cream,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (reason != null) ...[
            const SizedBox(height: 4),
            Text(
              reason,
              style: const TextStyle(color: Colors.white70, height: 1.3),
            ),
          ],
          if (widget.verdict case final verdict?
              when verdict.trim().isNotEmpty && verdict != reason) ...[
            const SizedBox(height: 4),
            Text(
              verdict,
              style: const TextStyle(
                fontSize: 12.5,
                color: Colors.white70,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );

    final art = _up(
      t,
      0.07,
      0.25,
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: SizedBox(
              height: compact
                  ? 128
                  : wide
                  ? 250
                  : 160,
              child: TreePortrait(leaves: leaves, pathOverride: sakura),
            ),
          ),
          const SizedBox(width: 10),
          Semantics(
            label: 'Daun Hayu. $leaves dari $kLeavesMax',
            excludeSemantics: true,
            child: SizedBox.square(
              dimension: wide && !compact ? 118 : 92,
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    painter: _GaugePainter(
                      count: count,
                      color: _accent,
                      glow: _win ? EmbunColors.gold : EmbunColors.blood,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(13),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${count.round()}/$kLeavesMax',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: _accent,
                            ),
                          ),
                          const Text(
                            'daun Hayu',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          story,
          const SizedBox(height: 8),
          art,
          const SizedBox(height: 14),
          ending,
        ],
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: compact ? 0 : math.min(440, height - 40),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [story, const SizedBox(height: 14), ending],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(child: art),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ bab barisan

  bool _isAntag(String uid) => _secrets[uid]?['role'] == 'antagonis';

  String _factionName(bool antag) => antag ? 'Si Terbisik' : 'Warga Desa';

  /// true = fraksi pemain ini menang, false = kalah, null = tak diketahui.
  bool? get _viewerWon {
    final id = widget.myId;
    final role = id == null ? null : _secrets[id]?['role'];
    if (role == null) return null;
    final antag = role == 'antagonis';
    return antag != widget.wargaMenang;
  }

  /// Kartu semua pemain muncul per fraksi. Fraksi pemenang muncul ala juara
  /// (kartu naik membal, berpendar, kilau menyapu, berkas cahaya, piala);
  /// fraksi yang kalah muncul ala runtuh (kartu jatuh menghantam, memucat,
  /// retak, dicap KALAH). Keduanya muncul bersamaan; kata KEMENANGAN /
  /// KEKALAHAN untuk fraksi pemain ini baru dicap setelah kartu mendarat.
  Widget _pFaction(double t, double width) {
    if (_secrets.isEmpty) {
      return const Text(
        'Peran para pemain tidak dapat dimuat.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white60),
      );
    }
    final ids = [for (final p in widget.players) p['user_id'] as String];
    final antagIds = [
      for (final u in ids)
        if (_isAntag(u)) u,
    ];
    final wargaIds = [
      for (final u in ids)
        if (!_isAntag(u)) u,
    ];
    final winners = widget.wargaMenang ? wargaIds : antagIds;
    final losers = widget.wargaMenang ? antagIds : wargaIds;
    final time = _loop.value * 600;

    if (width >= 690 && winners.isNotEmpty && losers.isNotEmpty) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _group(winners, true, t, time)),
          const SizedBox(width: 18),
          Expanded(child: _group(losers, false, t, time)),
        ],
      );
    }
    return Column(
      children: [
        if (winners.isNotEmpty) _group(winners, true, t, time),
        if (losers.isNotEmpty) ...[
          const SizedBox(height: 12),
          _group(losers, false, t, time),
        ],
      ],
    );
  }

  Widget _group(List<String> uids, bool winner, double t, double time) {
    final antagGroup = _isAntag(uids.first);
    final accent = winner
        ? (antagGroup ? EmbunColors.mist : EmbunColors.gold)
        : Colors.white54;
    final n = uids.length;
    final cw = antagGroup
        ? (winner ? 124.0 : 104.0)
        : (n <= 4 ? 92.0 : (n <= 6 ? 80.0 : 68.0));
    final stag = math.min(0.05, 0.28 / math.max(1, n - 1));
    final start = winner ? 0.04 : 0.06;
    final mine = widget.myId != null && uids.contains(widget.myId);
    final name = _factionName(antagGroup);

    final head = Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        Icon(
          winner ? Icons.emoji_events_rounded : Icons.heart_broken_rounded,
          size: 18,
          color: winner ? EmbunColors.gold : EmbunColors.blood,
        ),
        Text(
          winner ? '$name · Menang' : '$name · Kalah',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: winner ? EmbunColors.gold : Colors.white70,
          ),
        ),
        if (mine)
          const Text(
            'Fraksimu',
            style: TextStyle(fontSize: 11, color: Colors.white70),
          ),
      ],
    );

    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: _rule(accent))),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _StagePainter(
                    time: time,
                    t: t,
                    winner: winner,
                    color: accent,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  head,
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 14,
                    children: [
                      for (var i = 0; i < uids.length; i++)
                        _fcard(
                          uids[i],
                          i,
                          stag,
                          start,
                          winner,
                          cw,
                          t,
                          time,
                          accent,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 0 = warna asli, 1 = abu-abu.
  List<double> _grayMatrix(double g) {
    const List<double> id = [
      1.0, 0, 0, 0, 0, //
      0, 1, 0, 0, 0, //
      0, 0, 1, 0, 0, //
      0, 0, 0, 1, 0,
    ];
    const List<double> gr = [
      0.33, 0.59, 0.11, 0, 0, //
      0.33, 0.59, 0.11, 0, 0, //
      0.33, 0.59, 0.11, 0, 0, //
      0, 0, 0, 1, 0,
    ];
    return [for (var i = 0; i < 20; i++) _lerp(id[i], gr[i], g)];
  }

  Widget _fcard(
    String uid,
    int i,
    double stag,
    double start,
    bool winner,
    double cw,
    double t,
    double time,
    Color accent,
  ) {
    final antag = _isAntag(uid);
    final String? path = antag
        ? darkCardPath((_secrets[uid]?['dark_seed'] as int?) ?? 0)
        : protagonistPath(_cardOf(uid) ?? 'default');
    final ch = cw * cardAspectFor(path);
    final a = start + stag * i;
    final me = uid == widget.myId;

    final Widget body;
    final Offset off;
    final double scale, rot, op;

    if (winner) {
      final p = _seg(t, a, a + 0.26);
      final e = Curves.easeOutBack.transform(p);
      off = Offset(
        0,
        (1 - e) * 90 + (p >= 1 ? math.sin(time * 1.6 + i) * 3 : 0.0),
      );
      scale = _lerp(0.55, 1, e);
      rot = (1 - e) * (i.isEven ? -0.25 : 0.25);
      op = _smooth(_seg(p, 0, 0.4));
      final pulse = 0.75 + 0.25 * math.sin(time * 2.4 + i);
      final glowA = (0.30 + 0.55 * _smooth(p) * pulse)
          .clamp(0.0, 1.0)
          .toDouble();
      final sheen = _seg(t, a + 0.26, a + 0.52);
      final se = Curves.easeInOut.transform(sheen);
      body = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: glowA),
                    blurRadius: 14 + 22 * p,
                    spreadRadius: 1 + 2 * p,
                  ),
                ],
              ),
            ),
          ),
          CardArt(path: path, width: cw, glow: accent),
          if (sheen > 0 && sheen < 1)
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1.6 + 3.2 * se, -1),
                        end: Alignment(-0.6 + 3.2 * se, 1),
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(
                            alpha: 0.55 * math.sin(sheen * math.pi),
                          ),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: -12,
            left: 0,
            right: 0,
            child: Center(
              child: Opacity(
                opacity: _smooth(_seg(p, 0.6, 1)),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  size: 22,
                  color: EmbunColors.gold,
                  shadows: [Shadow(color: EmbunColors.gold, blurRadius: 10)],
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      final p = _seg(t, a, a + 0.30);
      final fall = Curves.bounceOut.transform(p);
      final land = _seg(p, 0.55, 0.85);
      final shakeX = (land > 0 && land < 1)
          ? math.sin(land * 40) * 5 * (1 - land)
          : 0.0;
      off = Offset(shakeX, (1 - fall) * -150);
      final droop = _smooth(_seg(p, 0.7, 1));
      scale = 1.0 - 0.03 * droop;
      rot =
          (1 - p) * (i.isEven ? -0.3 : 0.3) + (i.isEven ? 0.05 : -0.05) * droop;
      op = _smooth(_seg(p, 0, 0.2));
      final g = _smooth(_seg(p, 0.6, 1));
      final crack = _seg(p, 0.75, 1);
      final stamp = _seg(p, 0.85, 1);
      body = Stack(
        clipBehavior: Clip.none,
        children: [
          ColorFiltered(
            colorFilter: ColorFilter.matrix(_grayMatrix(g)),
            child: CardArt(path: path, width: cw),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.38 * g),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CrackPainter(progress: crack, seed: i + 1),
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Opacity(
                opacity: _smooth(stamp),
                child: Transform.rotate(
                  angle: -0.35,
                  child: Transform.scale(
                    scale: _lerp(1.8, 1, Curves.easeOutCubic.transform(stamp)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: EmbunColors.blood, width: 2),
                      ),
                      child: Text(
                        'KALAH',
                        style: TextStyle(
                          fontSize: cw * 0.16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: EmbunColors.blood,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final card = Transform.translate(
      offset: off,
      child: Transform.rotate(
        angle: rot,
        child: Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: op,
            child: SizedBox(width: cw, height: ch, child: body),
          ),
        ),
      ),
    );

    return SizedBox(
      width: cw,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: cw,
            height: ch,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [card],
            ),
          ),
          const SizedBox(height: 5),
          Opacity(
            opacity: _smooth(_seg(t, 0.3, 0.5)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _nameOf(uid),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: winner ? Colors.white : Colors.white54,
                  ),
                ),
                if (me)
                  const Text(
                    'KAMU',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: EmbunColors.gold,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ bab 1

  Widget _tile(String icon, String label, int value, double t, double start) {
    final n =
        (value * Curves.easeOutCubic.transform(_seg(t, start, start + 0.48)))
            .round();
    return _up(
      t,
      start,
      start + 0.2,
      DecoratedBox(
        decoration: BoxDecoration(border: Border(top: _rule())),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  GameIcon(icon, size: 27),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '$n',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        color: EmbunColors.gold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
      dy: 8,
    );
  }

  Widget _p1(double t) {
    final s = _stats!;
    final tiles = [
      ('timer', 'Hari dilewati', widget.day),
      ('donations', 'Persembahan', s.offerCards),
      ('bulirembun', 'Kartu dibeli', s.buys),
      ('vote', 'Suara diberikan', s.votes),
      ('bulirhitam', 'Kartu kabut', s.badOffers),
      ('bulirembun', 'Embun terpakai', s.spent),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= 580 ? 3 : 2;
        const gap = 14.0;
        final width = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: 8,
          children: [
            for (var i = 0; i < tiles.length; i++)
              SizedBox(
                width: width,
                child: _tile(
                  tiles[i].$1,
                  tiles[i].$2,
                  tiles[i].$3,
                  t,
                  i * 0.075,
                ),
              ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------ kronik

  Widget _pKronik(double t) {
    final s = _stats!;
    if (s.chron.isEmpty) {
      return const Text(
        'Belum ada peristiwa yang tercatat.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white60),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < s.chron.length; i++)
          _up(
            t,
            math.min(i, 9) * 0.07,
            math.min(i, 9) * 0.07 + 0.28,
            _dayCard(s.chron[i], i == s.chron.length - 1),
            dy: 20,
          ),
      ],
    );
  }

  /// Satu baris peristiwa: ikon kecil + kalimat dengan nama kartu berwarna.
  Widget _eventLine(String icon, List<InlineSpan> spans) => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GameIcon(icon, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            TextSpan(children: spans),
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.3,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    ),
  );

  /// "Budi: Kartu A, Kartu B" dikelompokkan per pemain.
  List<Widget> _grouped(
    String icon,
    String verb,
    List<(String, String)> items,
    bool sided,
  ) {
    final by = <String, List<String>>{};
    for (final (uid, cid) in items) {
      by.putIfAbsent(uid, () => []).add(cid);
    }
    return [
      for (final e in by.entries)
        _eventLine(icon, [
          TextSpan(
            text: _nameOf(e.key),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          TextSpan(text: ' $verb '),
          for (var i = 0; i < e.value.length; i++) ...[
            if (i > 0) const TextSpan(text: ', '),
            TextSpan(
              text: _cardName(e.value[i]),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: sided && widget.defs[e.value[i]]?['side'] == 'antagonis'
                    ? EmbunColors.mist
                    : EmbunColors.gold,
              ),
            ),
          ],
        ]),
    ];
  }

  Widget _dayCard(_Day d, bool last) {
    final Color node;
    String? verdict;
    if (d.voters == 0) {
      node = EmbunColors.goldDim;
    } else if (d.top == null) {
      node = Colors.white54;
      verdict = d.topN == 0 ? 'Tanpa tuduhan' : 'Suara seri';
    } else if (d.caught) {
      node = EmbunColors.leaf;
      verdict = 'Si Terbisik paling dituding';
    } else {
      node = EmbunColors.blood;
      verdict = 'Warga paling dituding';
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: node,
                    boxShadow: [
                      BoxShadow(
                        color: node.withValues(alpha: 0.6),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: EmbunColors.goldDim.withValues(alpha: 0.45),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 0, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Hari ${d.day}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: EmbunColors.gold,
                        ),
                      ),
                      if (verdict != null)
                        Text(
                          verdict,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: node,
                          ),
                        ),
                    ],
                  ),
                  ..._grouped('donations', 'mempersembahkan', d.offers, true),
                  ..._grouped('bulirembun', 'membeli', d.buys, false),
                  if (d.voters > 0)
                    _eventLine('vote', [
                      if (d.top == null)
                        TextSpan(
                          text: d.topN == 0
                              ? 'Tidak ada pemain yang dituding.'
                              : 'Sidang berakhir seri.',
                        )
                      else ...[
                        const TextSpan(text: 'Sidang: '),
                        TextSpan(
                          text: _nameOf(d.top!),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        TextSpan(
                          text: ' dituding ${d.topN} dari ${d.voters} suara',
                        ),
                      ],
                    ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ bab 2

  Widget _legendDot(Color c, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(text, style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
    ],
  );

  Widget _p2(double t) {
    final s = _stats!;
    if (_loadingSecrets) return _notice('Memuat peran pemain…', loading: true);
    if (s.antagId == null && s.votes > 0) {
      return _notice(
        'Ketepatan suara tidak tersedia karena peran belum diketahui.',
      );
    }
    if (s.rounds.isEmpty) {
      return _notice('Tidak ada suara warga yang tercatat.');
    }
    final maxTot = s.rounds.fold<int>(1, (m, r) => math.max(m, r.total));
    final unit = 118.0 / maxTot;
    final pct = s.rightTotal / s.wargaVotes;
    final shown = (pct * 100 * Curves.easeOutCubic.transform(_seg(t, 0.1, 0.7)))
        .round();
    final chart = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _up(
          t,
          0,
          0.2,
          Row(
            children: [
              Text(
                '$shown%',
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: EmbunColors.leaf,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'suara warga tepat menunjuk Si Terbisik',
                  style: TextStyle(color: Colors.white70, height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(border: Border(bottom: _rule())),
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: LayoutBuilder(
              builder: (context, box) {
                final width = math.max(32.0, box.maxWidth / s.rounds.length);
                return SingleChildScrollView(
                  primary: false,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < s.rounds.length; i++)
                        SizedBox(
                          width: width,
                          child: _bar(s.rounds[i], i, t, unit),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        _up(
          t,
          0.4,
          0.6,
          Wrap(
            spacing: 14,
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
    final accuracy = _up(
      t,
      0.4,
      0.75,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ketepatan tiap warga',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: EmbunColors.cream,
            ),
          ),
          const SizedBox(height: 6),
          for (final a in s.acc) _accChip(a),
        ],
      ),
    );
    if (s.acc.isEmpty) return chart;
    return _sideBySide(chart, accuracy);
  }

  Widget _sideBySide(Widget first, Widget second) => LayoutBuilder(
    builder: (context, box) => box.maxWidth < 660
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 22), second],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              const SizedBox(width: 28),
              Expanded(child: second),
            ],
          ),
  );

  Widget _accChip(_Acc a) {
    final c = a.right * 2 >= a.total ? EmbunColors.leaf : Colors.white70;
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: _rule())),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            PlayerAvatar(
              path: protagonistPath(_cardOf(a.uid) ?? 'default'),
              size: 27,
              ring: c,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_nameOf(a.uid), style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(width: 8),
            Text(
              '${a.right}/${a.total}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: c,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(_Round r, int i, double t, double unit) {
    final delay = math.min(i, 7) * 0.05;
    final g = Curves.easeOutCubic.transform(_seg(t, 0.1 + delay, 0.55 + delay));
    Widget seg(int n, Color c) => n == 0
        ? const SizedBox.shrink()
        : Container(
            height: n * unit * g,
            margin: const EdgeInsets.only(bottom: 1),
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: 8),
              ],
            ),
          );
    return Semantics(
      label:
          'Hari ${r.day}, ${r.right} tepat, ${r.wrong} keliru, ${r.none} tak memilih',
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(
            height: 130 + MediaQuery.textScalerOf(context).scale(15),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Opacity(
                  opacity: _smooth(_seg(g, 0.6, 1)),
                  child: Text(
                    '${r.total}',
                    style: const TextStyle(fontSize: 11, color: Colors.white60),
                  ),
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
              ],
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'H${r.day}',
              style: const TextStyle(fontSize: 11, color: EmbunColors.cream),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ bab 3

  Widget _p3(double t) {
    final s = _stats!;
    final total = s.goodOffers + s.badOffers;
    if (total == 0) {
      return const Text(
        'Tidak ada persembahan yang tercatat.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white60),
      );
    }
    final target = s.goodOffers / total;
    final e = Curves.easeOutCubic.transform(_seg(t, 0.1, 0.6));
    final share = _lerp(0.5, target, e);
    final goodN = (s.goodOffers * e).round();
    final badN = (s.badOffers * e).round();

    final balance = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _up(
          t,
          0,
          0.2,
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cahaya  $goodN',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: EmbunColors.leaf,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Kabut  $badN',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: EmbunColors.mist,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, box) => Semantics(
            label:
                '${s.goodOffers} kartu Cahaya dan ${s.badOffers} kartu Kabut',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: box.maxWidth * share,
                      child: const ColoredBox(color: EmbunColors.leaf),
                    ),
                    const Expanded(child: ColoredBox(color: EmbunColors.mist)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 9),
        Text(
          '$total kartu dipersembahkan',
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
    if (s.topCards.isEmpty) return balance;
    final cards = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Paling sering dipersembahkan',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: EmbunColors.cream,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 14,
          children: [
            for (var i = 0; i < s.topCards.length; i++)
              _up(
                t,
                0.24 + 0.10 * i,
                0.55 + 0.10 * i,
                _topCard(s.topCards[i]),
                dy: 10,
              ),
          ],
        ),
      ],
    );
    return _sideBySide(balance, cards);
  }

  Widget _topCard(MapEntry<String, int> e) {
    return SizedBox(
      width: 88,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CardTile(def: widget.defs[e.key], fallbackName: e.key, width: 88),
              Positioned(
                right: -6,
                top: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: EmbunColors.gold),
                  ),
                  child: Text(
                    '×${e.value}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: EmbunColors.gold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _cardName(e.key),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ bab 4

  Widget _p4(double t) {
    final s = _stats!;
    if (s.awards.isEmpty) {
      return const Text(
        'Tak ada yang menonjol kali ini.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white60),
      );
    }
    final awards = [
      for (var i = 0; i < s.awards.length; i++)
        _awardRow(s.awards[i], _seg(t, 0.04 + 0.06 * i, 0.27 + 0.06 * i)),
    ];
    final split = (awards.length + 1) ~/ 2;
    return _sideBySide(
      Column(children: awards.take(split).toList()),
      Column(children: awards.skip(split).toList()),
    );
  }

  Widget _awardRow(_Award a, double p) {
    // Seperti cap ditekan: membesar lalu mendarat dengan sedikit memantul.
    final e = Curves.easeOutBack.transform(p);
    final op = _smooth(_seg(p, 0, 0.5));
    return Opacity(
      opacity: op,
      child: Transform.scale(
        scale: _lerp(1.05, 1, e),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: _rule(a.color))),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: a.color.withValues(alpha: 0.18),
                  border: Border.all(color: a.color),
                ),
                child: Icon(a.icon, color: a.color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: a.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      a.text,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.white70,
                        height: 1.3,
                      ),
                    ),
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
                    Text(
                      _nameOf(a.uid),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
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
    final ps = [
      ...widget.players.where((p) => _isAntag(p['user_id'] as String)),
      ...widget.players.where((p) => !_isAntag(p['user_id'] as String)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: _showDetails,
          icon: const GameIcon('logorhistory', size: 20),
          label: const Text('Catatan lengkap'),
        ),
        const SizedBox(height: 4),
        if (_loadingSecrets)
          _notice('Memuat peran pemain…', loading: true)
        else if (_secrets.isEmpty)
          _notice('Peran para pemain tidak dapat dimuat.'),
        for (var i = 0; i < ps.length; i++)
          _up(t, 0.02 + 0.06 * i, 0.22 + 0.06 * i, _playerRow(ps[i]), dy: 8),
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
        : widget.abilityDefs['${_secrets[uid]?['ability']}']?['name']
              as String?;
    final col = antag ? EmbunColors.mist : EmbunColors.leaf;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: _rule(antag ? col : EmbunColors.gold)),
      ),
      child: Row(
        children: [
          PlayerAvatar(
            path: protagonistPath(
              (p['character_card'] as String?) ?? 'default',
            ),
            size: 46,
            ring: antag ? EmbunColors.mist : EmbunColors.goldDim,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p['name'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  [
                    ?uname,
                    if (hasRole) _factionName(antag),
                    ?ability,
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 12,
                    color: hasRole ? col : Colors.white70,
                  ),
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
        backgroundColor: const Color(0xFF11231B),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _heading('Catatan lengkap'),
              const SizedBox(height: 8),
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
    );
  }
}

// ====================================================================
// Pelukis
// ====================================================================

/// Latar panggung satu fraksi.
///  Pemenang: berkas cahaya berputar pelan + kunang-kunang naik.
///  Kalah   : abu jatuh + bayang gelap dari atas.
class _StagePainter extends CustomPainter {
  final double time, t;
  final bool winner;
  final Color color;
  const _StagePainter({
    required this.time,
    required this.t,
    required this.winner,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final env = _smooth(_seg(t, 0.05, 0.35));
    if (winner) {
      final c = size.center(Offset.zero);
      final len = size.longestSide * 0.8;
      final paint = Paint();
      for (var i = 0; i < 12; i++) {
        final ang = i * 2 * math.pi / 12 + time * 0.1;
        final w = 0.06 + 0.04 * _rnd(i, 1);
        final l = len * (0.6 + 0.4 * _rnd(i, 2));
        final path = Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + math.cos(ang - w) * l, c.dy + math.sin(ang - w) * l)
          ..lineTo(c.dx + math.cos(ang + w) * l, c.dy + math.sin(ang + w) * l)
          ..close();
        paint.shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.20 * env),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: l));
        canvas.drawPath(path, paint);
      }
      final sp = Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      for (var i = 0; i < 22; i++) {
        final u = (time * 0.25 + _rnd(i, 3)) % 1.0;
        final x = _rnd(i, 4) * size.width;
        final y = size.height * (1.05 - 1.1 * u);
        final a = (math.sin(u * math.pi) * 0.8 * env)
            .clamp(0.0, 1.0)
            .toDouble();
        sp.color = Color.lerp(color, Colors.white, 0.4)!.withValues(alpha: a);
        canvas.drawCircle(Offset(x, y), 1.5 + 2 * _rnd(i, 5), sp);
      }
    } else {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.35 * env),
              Colors.transparent,
            ],
          ).createShader(Offset.zero & size),
      );
      final ash = Paint();
      for (var i = 0; i < 22; i++) {
        final u = (time * 0.05 + _rnd(i, 3)) % 1.0;
        final x = _rnd(i, 4) * size.width + math.sin(time * 0.5 + i) * 8;
        final y = size.height * u;
        final a = (math.sin(u * math.pi) * 0.5 * env)
            .clamp(0.0, 1.0)
            .toDouble();
        ash.color = const Color(0xFFB9B2C8).withValues(alpha: a);
        canvas.drawCircle(Offset(x, y), 1.1 + 1.6 * _rnd(i, 5), ash);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StagePainter old) => true;
}

/// Retakan yang menjalar dari satu titik di muka kartu.
class _CrackPainter extends CustomPainter {
  final double progress;
  final int seed;
  const _CrackPainter({required this.progress, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final origin = Offset(
      size.width * (0.3 + 0.4 * _rnd(seed, 1)),
      size.height * (0.3 + 0.35 * _rnd(seed, 2)),
    );
    final dark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.8
      ..color = Colors.black.withValues(alpha: 0.85);
    final light = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.35);
    const segs = 6;
    for (var k = 0; k < 5; k++) {
      var ang = k * 2 * math.pi / 5 + _rnd(seed, 3 + k) * 0.8;
      var pos = origin;
      final path = Path()..moveTo(pos.dx, pos.dy);
      for (var s = 0; s < segs; s++) {
        if (s / segs >= progress) break;
        ang += (_rnd(seed * 10 + k, s) - 0.5) * 0.9;
        pos += Offset.fromDirection(
          ang,
          size.shortestSide * 0.14 * (0.7 + 0.6 * _rnd(seed + k, s + 7)),
        );
        path.lineTo(pos.dx, pos.dy);
      }
      canvas.drawPath(path, dark);
      canvas.drawPath(path.shift(const Offset(1, 1)), light);
    }
  }

  @override
  bool shouldRepaint(covariant _CrackPainter old) => old.progress != progress;
}

/// Cincin 30 titik: tiap titik menyala menurut jumlah daun; titik terbaru
/// berpijar.
class _GaugePainter extends CustomPainter {
  final double count;
  final Color color, glow;
  const _GaugePainter({
    required this.count,
    required this.color,
    required this.glow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 6;
    canvas.drawCircle(
      c,
      r * 0.85,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(
              alpha: 0.22 * (count / kLeavesMax).clamp(0.0, 1.0),
            ),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final head = count.floor();
    for (var i = 0; i < kLeavesMax; i++) {
      final ang = -math.pi / 2 + i * 2 * math.pi / kLeavesMax;
      final dir = Offset(math.cos(ang), math.sin(ang));
      final lit = (count - i).clamp(0.0, 1.0).toDouble();
      final paint = Paint()
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(Colors.white24, color, lit)!;
      canvas.drawLine(c + dir * (r - 11), c + dir * r, paint);
      if (i == head && lit > 0 && lit < 1 && count < kLeavesMax) {
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
  const _AmbientPainter({
    required this.time,
    required this.win,
    required this.sakura,
  });

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
          paint.color =
              (sakura
                      ? const Color(0xFFFFB7CF)
                      : Color.lerp(
                          EmbunColors.leaf,
                          EmbunColors.gold,
                          _rnd(i, 4),
                        )!)
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
            ..shader = RadialGradient(
              colors: [
                EmbunColors.mist.withValues(alpha: a),
                EmbunColors.mist.withValues(alpha: 0),
              ],
            ).createShader(Rect.fromCircle(center: Offset(xx, y), radius: r));
          canvas.drawCircle(Offset(xx, y), r, paint);
          paint.shader = null;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter old) => true;
}
