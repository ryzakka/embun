import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/fx_shaders.dart';
import '../common/ornate.dart';
import '../common/sfx.dart';
import '../common/scene_flow.dart';

double _seg(double v, double a, double b) =>
    ((v - a) / (b - a)).clamp(0.0, 1.0).toDouble();

double _a(double v) => v.clamp(0.0, 1.0).toDouble();

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

/// Adegan pembukaan suara setelah voting selesai.
///
/// Semua pemain duduk MELINGKAR sebagai kartu: 3 orang = segitiga, 4 =
/// persegi, 5 = segi lima, dst. (n kartu = segi-n beraturan).
///
///  * pembukaan: layar gelap berdenyut, lalu kartu-kartu dibagikan ke
///    lingkaran;
///  * satu per satu, kartu pemilih menarik diri lalu melesatkan petir ke
///    kartu sasaran. Sasaran terhantam dan angka di pojok kartunya naik
///    (+1, atau +2 untuk Patuhilah Padaku). Benang panah tipis tertinggal
///    sebagai jejak siapa memilih siapa;
///  * penanda MAYORITAS TIDAK muncul selama suara masuk. Irama hanya
///    melambat dan denyut makin rapat saat ada yang mendekati batas;
///  * setelah SEMUA suara masuk: hening, debar, lalu vonis dijatuhkan:
///    spanduk MAYORITAS, kartu lain meredup, yang dituduh membesar, dicap
///    DITUDUH, gelombang kejut, bara melayang. Bila tak ada mayoritas,
///    suasana mereda jadi dingin.
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

/// Suara "Kabut" dari kartu Fitnah: bukan pemain, tak dihitung dalam jumlah
/// pemilih, tetapi dihitung sebagai satu suara untuk sasarannya. Di lingkaran
/// ia muncul sebagai kartu di tengah.
const _kFogId = '00000000-0000-0000-0000-000000000000';

/// Tinggi baris nama di bawah kartu.
const double _kNameH = 20;

/// Saat (0..1 pada [_strike]) sasaran terkena petir.
const _kHitAt = 0.62;

class _Person {
  final String id;
  final String name;
  final String? card;
  const _Person(this.id, this.name, this.card);
}

/// Satu suara yang sudah mendarat. [from] = -1 berarti Kabut (dari tengah).
class _Edge {
  final int from;
  final int to;
  final int weight;
  final bool fog;
  const _Edge(this.from, this.to, this.weight, this.fog);
}

// ------------------------- susunan lingkaran -------------------------

class _Ring {
  final Size size;
  final Offset center;
  final double radius;
  final double cardW;
  final double cardH;
  final List<Offset> pos; // titik tengah gambar tiap kartu

  const _Ring({
    required this.size,
    required this.center,
    required this.radius,
    required this.cardW,
    required this.cardH,
    required this.pos,
  });

  /// -1 (Kabut / tidak ada) = pusat lingkaran.
  Offset at(int k) => (k < 0 || k >= pos.length) ? center : pos[k];
}

/// Menyusun [n] kartu pada segi-n beraturan. Ganjil: satu titik di puncak
/// (segitiga: atas, kiri-bawah, kanan-bawah). Genap: sisi datar di atas
/// (4 = persegi). Kartu dibuat sebesar mungkin selama tidak saling menimpa.
_Ring _layoutRing(Size s, int n) {
  List<Offset> pts(Offset c, double r) {
    final start = n.isOdd ? -math.pi / 2 : -math.pi / 2 - math.pi / n;
    return [
      for (var k = 0; k < n; k++)
        c +
            Offset(math.cos(start + 2 * math.pi * k / n),
                math.sin(start + 2 * math.pi * k / n)) *
                r,
    ];
  }

  if (n <= 1) {
    final w = math.min(120.0, s.width * 0.4);
    final c = Offset(s.width / 2, (s.height - _kNameH) / 2);
    return _Ring(
      size: s,
      center: c,
      radius: 0,
      cardW: w,
      cardH: w * kProtagonistAspect,
      pos: n == 0 ? const [] : [c],
    );
  }

  _Ring? best;
  for (var w = 120.0; w >= 30; w -= 2) {
    final h = w * kProtagonistAspect;
    final r = math.min((s.width - w - 20) / 2, (s.height - _kNameH - 10 - h) / 2);
    if (r <= 0) continue;
    final c = Offset(s.width / 2, 10 + h / 2 + r);
    final p = pts(c, r);
    var ok = true;
    for (var i = 0; i < n && ok; i++) {
      for (var j = i + 1; j < n; j++) {
        if ((p[i].dx - p[j].dx).abs() < w + 8 &&
            (p[i].dy - p[j].dy).abs() < h + _kNameH + 6) {
          ok = false;
          break;
        }
      }
    }
    best = _Ring(size: s, center: c, radius: r, cardW: w, cardH: h, pos: p);
    if (ok) return best;
  }
  if (best != null) return best;
  const w = 30.0;
  const h = w * kProtagonistAspect;
  final c = Offset(s.width / 2, s.height / 2);
  return _Ring(size: s, center: c, radius: 40, cardW: w, cardH: h, pos: pts(c, 40));
}

/// Lengkung tipis dari tepi kartu pemilih ke tepi kartu sasaran. Bengkoknya
/// berlawanan arah untuk A->B dan B->A sehingga dua benang tidak menumpuk.
class _Curve {
  final Offset a;
  final Offset b;
  final Offset c;
  const _Curve(this.a, this.b, this.c);

  Offset at(double u) {
    final m = 1 - u;
    return a * (m * m) + c * (2 * m * u) + b * (u * u);
  }
}

_Curve? _curveBetween(Offset p0, Offset p1, double w, double h) {
  final d = p1 - p0;
  final len = d.distance;
  if (len < 6) return null;
  final u = d / len;
  final ax = u.dx.abs();
  final ay = u.dy.abs();
  final tx = ax < 1e-6 ? double.infinity : (w / 2 + 3) / ax;
  final ty = ay < 1e-6 ? double.infinity : (h / 2 + 3) / ay;
  final ex = math.min(tx, ty);
  final rem = len - 2 * ex;
  if (rem < 6) return null;
  final a = p0 + u * ex;
  final b = p1 - u * ex;
  final nrm = Offset(-u.dy, u.dx);
  final c = (a + b) / 2 + nrm * (rem * 0.14);
  return _Curve(a, b, c);
}

class _VoteRevealSceneState extends State<VoteRevealScene>
    with TickerProviderStateMixin {
  static const _bg = kSceneInk;
  static const _teal = Color(0xFF5FB8A5);

  late final List<Map<String, dynamic>> _votes;
  late final List<Map<String, dynamic>> _abstain;
  late final List<_Person> _people;
  late final Map<String, int> _idx;
  late final Set<String> _abstainIds;
  late final int _total;

  final Map<String, int> _counts = {};
  final List<_Edge> _edges = [];
  // 0 pembukaan, 1 pemilihan, 2 hening menunggu, 3 vonis
  int _phase = 0;
  int _i = 0; // suara yang sedang tampil
  int _stage = 0; // 0 kosong, 1 pemilih muncul, 2 petir melesat, 3 terhitung
  bool _banner = false;
  bool _near = false; // ada yang mendekati batas (hanya irama, bukan tanda)
  bool _stopped = false;
  bool _done = false;
  bool _hit = false; // hantaman suara ini sudah terjadi
  bool _counted = false; // suara ini sudah masuk hitungan

  // Denyut tepi layar (kecepatan berubah menurut ketegangan).
  late final AnimationController _beat = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));
  // Getar layar dan kilat putih saat hantaman.
  late final AnimationController _shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 560));
  late final AnimationController _flash = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
  // Garis waktu vonis.
  late final AnimationController _vc = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3400));
  final Set<int> _fired = {};
  // Serangan satu suara: kumpul tenaga, petir meluncur, hantaman.
  late final AnimationController _strike = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 560));
  // Sentakan kecil seluruh layar tiap suara mendarat.
  late final AnimationController _tap = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 260));
  // Kartu dibagikan ke lingkaran.
  late final AnimationController _enter = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000));
  // Jam pelan untuk gerak kabut shader.
  late final AnimationController _loop = AnimationController(
      vsync: this, duration: const Duration(seconds: 120));
  ui.FragmentShader? _fx;
  late final AnimationController _veil = AnimationController(
      vsync: this,
      value: 1.0,
      duration: const Duration(milliseconds: kSceneFadeOutMs),
      reverseDuration: const Duration(milliseconds: kSceneFadeInMs));

  _Ring? _ringMemo;
  Size? _ringSize;

  @override
  void initState() {
    super.initState();
    _veil.reverse();
    final rows = widget.rows;
    _votes = [for (final r in rows) if (r['target_id'] != null) r];
    _abstain = [for (final r in rows) if (r['target_id'] == null) r];
    _abstainIds = {for (final r in _abstain) r['voter_id'] as String};
    _total = rows.where((r) => r['voter_id'] != _kFogId).length;

    final seen = <String>{};
    final people = <_Person>[];
    for (final r in rows) {
      final id = r['voter_id'] as String;
      if (id == _kFogId) continue;
      if (seen.add(id)) {
        people.add(_Person(id, '${r['voter_name']}', r['voter_card'] as String?));
      }
    }
    // Urutan duduk stabil (urut nama), sama di semua perangkat.
    people.sort((a, b) => a.name.compareTo(b.name));
    _people = people;
    _idx = {for (var k = 0; k < people.length; k++) people[k].id: k};

    _beat.repeat();
    _fx = FxShaders.make(FxShaders.voteReveal);
    if (_fx != null) _loop.repeat();
    _vc.addListener(_onVerdictTick);
    _strike.addListener(_onStrikeTick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  @override
  void dispose() {
    _stopped = true;
    _beat.dispose();
    _shake.dispose();
    _flash.dispose();
    _strike.dispose();
    _tap.dispose();
    _enter.dispose();
    _vc.dispose();
    _loop.dispose();
    _fx?.dispose();
    _veil.dispose();
    Sfx.I.release(this);
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
    // Memudar ke gelap dulu, baru adegan berikutnya mulai.
    await _veil.forward();
    if (mounted) widget.onDone();
  }

  /// Hantaman layar: getar + kilat + haptic berat.
  void _slam({bool flash = true}) {
    _shake.forward(from: 0);
    if (flash) {
      _flash.forward(from: 0);
      Sfx.I.play(Snd.slashPedang, owner: this, tag: 'slam', replace: true);
    }
    HapticFeedback.heavyImpact();
  }

  /// Tepat saat petir mengenai kartu sasaran: sentakan, haptic, suara, dan
  /// angka di kartu sasaran naik. Tidak ada hantaman khusus untuk suara
  /// penentu: mayoritas baru diumumkan setelah semua suara masuk.
  void _onStrikeTick() {
    if (_hit || _stage < 2 || _strike.value < _kHitAt) return;
    _hit = true;
    if (_i < _votes.length) _applyCount(_votes[_i]);
    _tap.forward(from: 0);
    HapticFeedback.mediumImpact();
    Sfx.I.play(Snd.clickTung, owner: this, tag: 'hit', replace: true);
  }

  void _applyCount(Map<String, dynamic> v) {
    if (_counted || !mounted) return;
    _counted = true;
    final tid = v['target_id'] as String;
    setState(() => _counts[tid] = (_counts[tid] ?? 0) + _weightOf(v));
  }

  void _onVerdictTick() {
    if (_winnerId == null) return;
    final t = _vc.value;
    // Spanduk MAYORITAS menghantam, lalu yang dituduh membesar dan dicap.
    if (t >= 0.08 && _fired.add(0)) {
      _slam();
      if (mounted) setState(() => _banner = true);
    }
    if (t >= 0.42 && _fired.add(1)) {
      if (mounted) setState(() => _banner = false);
    }
    if (t >= 0.54 && _fired.add(2)) _slam(flash: false);
    if (t >= 0.60 && _fired.add(3)) _slam();
  }

  Future<void> _play() async {
    // Pembukaan: debar yang makin rapat sebelum kartu dibagikan.
    HapticFeedback.lightImpact();
    if (!await _w(520)) return;
    HapticFeedback.lightImpact();
    if (!await _w(360)) return;
    HapticFeedback.mediumImpact();
    if (!await _w(260)) return;
    HapticFeedback.mediumImpact();
    if (!await _w(220)) return;
    HapticFeedback.heavyImpact();
    _enter.forward(from: 0);
    setState(() => _phase = 1);
    if (!await _w(1100)) return;

    final n = _votes.length;
    for (var i = 0; i < n; i++) {
      final v = _votes[i];

      // Irama: normal di awal, melambat di sepertiga akhir, merayap saat ada
      // yang mendekati batas. Tidak berubah setelah batas terlewati supaya
      // mayoritas tidak bocor sebelum waktunya.
      final tense = i >= (n * 2 / 3).floor();
      final m = _near ? 1.7 : (tense ? 1.3 : 1.0);

      _strike.value = 0;
      _hit = false;
      _counted = false;
      setState(() {
        _i = i;
        _stage = 1; // pemilih menonjol
      });
      if (_near) HapticFeedback.lightImpact();
      if (!await _w((470 * m).round())) return;

      final strikeMs = (560 * m).round();
      _strike.duration = Duration(milliseconds: strikeMs);
      setState(() => _stage = 2); // petir melesat ke sasaran
      _strike.forward(from: 0);
      Sfx.I.play(
        [Snd.swingWind1, Snd.swingWind2, Snd.swingWind3][i % 3],
        owner: this,
        tag: 'wind',
        replace: true,
      );
      if (!await _w(strikeMs)) return;

      _applyCount(v); // jaga-jaga bila tick hantaman terlewat
      setState(() {
        _stage = 3;
        _edges.add(_Edge(
          _indexOf(v['voter_id'] as String),
          _indexOf(v['target_id'] as String),
          _weightOf(v),
          v['voter_id'] == _kFogId,
        ));
      });
      HapticFeedback.selectionClick();

      final nearNow =
          _need >= 3 && _lead >= 2 && _lead >= _need - 1 && i < n - 1;
      if (nearNow != _near) {
        setState(() => _near = nearNow);
        if (nearNow) {
          _beat.repeat(period: const Duration(milliseconds: 620));
          HapticFeedback.mediumImpact();
        }
      }
      if (!await _w((440 * m).round())) return;
    }

    // Semua suara sudah masuk: hening, debar, lalu vonis.
    setState(() {
      _stage = 0;
      _near = false;
      _phase = 2;
    });
    _beat.repeat(period: const Duration(milliseconds: 700));
    HapticFeedback.mediumImpact();
    if (!await _w(1100)) return;
    if (_abstain.isNotEmpty) {
      // Makin banyak yang tidak memilih, makin lama tandanya tampil.
      if (!await _w((1300 + 200 * _abstain.length).clamp(1300, 2200).toInt())) {
        return;
      }
    }
    HapticFeedback.lightImpact();
    if (!await _w(420)) return;
    HapticFeedback.mediumImpact();
    if (!await _w(320)) return;
    HapticFeedback.heavyImpact();
    if (!await _w(260)) return;

    setState(() => _phase = 3);
    final won = _winnerId != null;
    if (won) {
      _beat.repeat(period: const Duration(milliseconds: 1500));
    } else {
      _beat.repeat(period: const Duration(milliseconds: 2400));
      HapticFeedback.lightImpact();
    }
    _vc.forward(from: 0);
    // Linimasa vonis 3,4 detik, lalu jeda baca.
    if (!await _w(won ? 3400 + 2300 : 3400 + 1500)) return;
    _finish();
  }

  // ------------------------- data bantu -------------------------

  /// Bobot suara (2 bila pemilih memakai Patuhilah Padaku).
  int _weightOf(Map<String, dynamic> v) => (v['weight'] as int?) ?? 1;

  /// Indeks kartu di lingkaran; -1 untuk Kabut atau yang tak dikenal.
  int _indexOf(String id) => _idx[id] ?? -1;

  _Person? _person(String? id) {
    final k = id == null ? null : _idx[id];
    return k == null ? null : _people[k];
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

  /// Kepanasan 0..1, dibatasi 0.92 supaya kartu yang sudah melewati batas
  /// tidak tampak berbeda dari yang tinggal selangkah lagi.
  double _heatOf(int count) =>
      (count / _need).clamp(0.0, 0.92).toDouble();

  String _targetName(Map<String, dynamic> v) => '${v['target_name']}';
  String _voterName(Map<String, dynamic> v) => '${v['voter_name']}';

  _Ring _ringFor(Size s) {
    if (_ringMemo != null && _ringSize == s) return _ringMemo!;
    _ringSize = s;
    return _ringMemo = _layoutRing(s, _people.length);
  }

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
          if (_fx != null) _fxLayer(),
          if (won) _spotlight(),
          _vignette(),
          AnimatedBuilder(
            animation: Listenable.merge([_shake, _tap]),
            builder: (context, child) {
              final k = _shake.value;
              final amp = _shake.isAnimating ? (1 - k) : 0.0;
              final kt = _tap.value;
              final ta = _tap.isAnimating ? (1 - kt) : 0.0;
              return Transform.translate(
                offset: Offset(
                    math.sin(k * 52) * 10 * amp + math.sin(kt * 70) * 3.2 * ta,
                    math.sin(k * 41 + 1.3) * 7 * amp +
                        math.sin(kt * 55 + 0.7) * 2.4 * ta),
                child: child,
              );
            },
            child: SafeArea(
              child: Column(
                children: [
                  _top(),
                  Expanded(child: _stageArea()),
                  _caption(),
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

  /// Latar shader: kabut merah yang makin pekat menurut ketegangan, gelombang
  /// kejut saat hantaman, berkas cahaya vonis, dan kabut dingin saat tak ada
  /// mayoritas.
  Widget _fxLayer() {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([_loop, _beat, _shake, _vc]),
          builder: (context, _) {
            final won = _winnerId != null;
            final heat = _heatOf(_lead);
            final double tension = switch (_phase) {
              0 => 0.25,
              1 => 0.12 + 0.55 * heat * heat + (_near ? 0.18 : 0.0),
              2 => 0.30,
              _ => won ? 0.75 : 0.0,
            };
            final verdict = (_phase == 3 && won)
                ? Curves.easeOut.transform(_seg(_vc.value, 0.05, 0.40))
                : 0.0;
            final calm = (_phase == 3 && !won)
                ? Curves.easeOut.transform(_seg(_vc.value, 0.0, 0.5))
                : 0.0;
            return CustomPaint(
              size: Size.infinite,
              painter: _VoteFxPainter(
                shader: _fx!,
                time: _loop.value * 120.0,
                heat: tension.clamp(0.0, 1.0).toDouble(),
                beat: _thump(_beat.value),
                slam: _shake.isAnimating ? _shake.value : 0.0,
                verdict: verdict.toDouble(),
                calm: calm.toDouble(),
                centerFrac: const Offset(0.5, 0.42),
                hot: EmbunColors.blood,
                cool: _teal,
              ),
            );
          },
        ),
      ),
    );
  }

  /// Tepi layar berdenyut: makin merah dan cepat bila ada yang mendekati
  /// batas. Saat hasil tanpa mayoritas berubah menjadi hijau-dingin.
  Widget _vignette() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _beat,
        builder: (context, _) {
          final won = _winnerId != null;
          final heat = _heatOf(_lead);
          final double base = switch (_phase) {
            0 => 0.14,
            1 => 0.06 + 0.34 * heat * heat + (_near ? 0.20 : 0.0),
            2 => 0.30,
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

  String get _sub => switch (_phase) {
    1 => 'Hari ${widget.day} · suara ${math.min(_i + 1, _votes.length)} '
        'dari ${_votes.length}',
    2 => 'Hari ${widget.day} · semua suara telah masuk',
    3 => 'Hari ${widget.day} · hasil',
    _ => 'Hari ${widget.day} · siapa memilih siapa',
  };

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
              Text(
                _sub,
                key: ValueKey(_sub),
                style: const TextStyle(fontSize: 12.5, color: Colors.white54),
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
    if (_phase == 0) return Center(child: _openingStage());
    return _ringStage(Size(c.maxWidth, c.maxHeight));
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

  // ---------- lingkaran kartu ----------

  Widget _ringStage(Size size) {
    final ring = _ringFor(size);
    final n = _people.length;
    final cur = (_phase == 1 && _stage >= 1 && _i < _votes.length)
        ? _votes[_i]
        : null;
    final isFog = cur != null && cur['voter_id'] == _kFogId;
    final src = cur == null ? -1 : _indexOf(cur['voter_id'] as String);
    final tgt = cur == null ? -1 : _indexOf(cur['target_id'] as String);
    final weight = cur == null ? 1 : _weightOf(cur);
    final voterMine = cur != null && cur['voter_id'] == widget.myId;
    final accent = isFog
        ? EmbunColors.mist
        : (weight >= 2 ? EmbunColors.gold : EmbunColors.blood);
    final srcPos = ring.at(src);
    final tgtPos = ring.at(tgt);
    final dv = tgtPos - srcPos;
    final u = dv.distance < 1 ? Offset.zero : dv / dv.distance;
    final nrm = Offset(-u.dy, u.dx);
    final wid = _phase == 3 ? _winnerId : null;
    final widx = wid == null ? -1 : _indexOf(wid);
    final boxW = ring.cardW + 14;
    // Pusat gambar kartu = titik skala/putar, supaya sasaran petir tepat.
    final align = Alignment(0, -_kNameH / (ring.cardH + _kNameH));
    final fogPath = AssetCatalog.I.file(kartuMalamDir, 'pindaisalah');

    final order = <int>[
      for (var k = 0; k < n; k++)
        if (k != src && k != tgt && k != widx) k,
    ];
    if (src >= 0 && src != widx) order.add(src);
    if (tgt >= 0 && tgt != src && tgt != widx) order.add(tgt);
    if (widx >= 0) order.add(widx);

    return AnimatedBuilder(
      animation: Listenable.merge([_strike, _enter, _vc]),
      builder: (context, _) {
        final st = (cur != null && _stage >= 2) ? _strike.value : 0.0;
        final vt = _phase == 3 ? _vc.value : 0.0;

        // Kartu pemenang membesar dan sedikit tertarik ke tengah.
        final up = Curves.easeOutBack.transform(_seg(vt, 0.42, 0.60));
        Offset winnerPos() => widx < 0
            ? ring.center
            : Offset.lerp(ring.pos[widx], ring.center, 0.12 * _a(up))!;

        Widget buildCard(int k) {
          final p = _people[k];
          var pos = ring.pos[k];
          var scale = 1.0;
          var rot = 0.0;
          var opacity = 1.0;
          var flash = 0.0;
          Color? glow;
          String? tag = p.id == widget.myId ? 'Kamu' : null;

          // Dibagikan dari tengah ke lingkaran, bergiliran.
          final stag = n <= 1 ? 0.0 : k / n * 0.45;
          final e = _seg(_enter.value, stag, stag + 0.55);
          pos = Offset.lerp(ring.center, pos, Curves.easeOutCubic.transform(e))!;
          scale *= 0.55 + 0.45 * Curves.easeOutBack.transform(e);
          opacity *= e;

          if (cur != null) {
            if (k == src && src != tgt) {
              if (_stage == 1) {
                scale *= 1.07;
              } else {
                // Menarik diri, menerjang, lalu mengendur.
                final charge = Curves.easeOut.transform(_seg(st, 0, 0.22));
                final lunge = Curves.easeOutCubic.transform(_seg(st, 0.22, 0.32));
                final settle = Curves.easeOutCubic.transform(_seg(st, 0.32, 0.80));
                final off =
                    (-12 * charge) * (1 - lunge) + 9 * lunge * (1 - settle);
                pos += u * off;
                scale *= 1 + 0.06 * charge * (1 - lunge);
              }
              glow = isFog ? EmbunColors.mist : EmbunColors.gold;
              if (weight >= 2) tag = voterMine ? 'Suaramu x2' : 'Palu x2';
            }
            if (k == tgt && _stage >= 2) {
              // Gemetar menjelang kena, lalu terpental menjauhi pemilih.
              final pre = _seg(st, 0.40, _kHitAt);
              final post = _seg(st, _kHitAt, 1.0);
              final recoil = post > 0
                  ? math.sin(post * math.pi * 3.2) * math.exp(-post * 3.2)
                  : 0.0;
              pos += u * (recoil * 14) + nrm * (pre * math.sin(st * 110) * 1.8);
              scale *= 1 - 0.06 * math.max(0.0, recoil);
              rot = recoil * 0.06;
              if (post > 0 && post < 0.95) {
                flash = 0.6 * (1 - _seg(post, 0, 0.35));
              }
              glow = accent;
            }
          }

          final count = _counts[p.id] ?? 0;
          final heat = _heatOf(count);
          final abstained = _phase >= 2 && _abstainIds.contains(p.id);
          if (abstained) opacity *= 0.5;

          if (_phase == 3) {
            if (wid != null) {
              if (k == widx) {
                scale *= 1 + 0.22 * up + 0.012 * math.sin(_seg(vt, 0.6, 1.0) * 4 * math.pi);
                pos = winnerPos();
                glow = EmbunColors.blood;
              } else {
                opacity *= 1 - 0.68 * Curves.easeOut.transform(_seg(vt, 0.40, 0.56));
              }
            } else {
              opacity *= 1 - 0.25 * Curves.easeOut.transform(_seg(vt, 0.0, 0.5));
            }
          }

          if (glow == null && heat >= 0.5) glow = EmbunColors.blood;

          return Positioned(
            key: ValueKey('rc${p.id}'),
            left: pos.dx - boxW / 2,
            top: pos.dy - ring.cardH / 2,
            width: boxW,
            child: Opacity(
              opacity: _a(opacity),
              child: Transform.rotate(
                angle: rot,
                alignment: align,
                child: Transform.scale(
                  scale: scale,
                  alignment: align,
                  child: _RingCard(
                    name: p.id == widget.myId ? '${p.name} (kamu)' : p.name,
                    card: p.card,
                    width: ring.cardW,
                    count: count,
                    heat: heat,
                    me: p.id == widget.myId,
                    winner: wid != null && k == widx,
                    abstained: abstained,
                    glow: glow,
                    flash: flash,
                    tag: tag,
                  ),
                ),
              ),
            ),
          );
        }

        final children = <Widget>[
          for (final k in order) buildCard(k),

          // Kartu Kabut (Fitnah): muncul di tengah lingkaran.
          if (isFog)
            Positioned(
              key: ValueKey('fog$_i'),
              left: ring.center.dx - boxW / 2,
              top: ring.center.dy - ring.cardH / 2,
              width: boxW,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutBack,
                builder: (_, e, child) => Opacity(
                  opacity: _a(e),
                  child: Transform.scale(
                      scale: 0.6 + 0.4 * e, alignment: align, child: child),
                ),
                child: _RingCard(
                  name: _voterName(cur!),
                  card: null,
                  artPath: fogPath,
                  width: ring.cardW,
                  count: 0,
                  heat: 0,
                  me: false,
                  winner: false,
                  abstained: false,
                  glow: EmbunColors.mist,
                  flash: 0,
                  tag: 'Fitnah',
                ),
              ),
            ),

          // Serangan, benang jejak, dan angka +N.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _RingPainter(
                  ring: ring,
                  edges: _edges,
                  live: (cur != null && _stage == 2)
                      ? _Edge(src, tgt, weight, isFog)
                      : null,
                  t: st,
                  accent: accent,
                  intense: _near,
                  verdict: vt,
                  winner: widx,
                ),
              ),
            ),
          ),

          // Gelombang kejut dan cap DITUDUH pada pemenang.
          if (widx >= 0) ...[
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ShockPainter(
                    center: winnerPos(),
                    t: _seg(vt, 0.52, 0.88),
                    unit: ring.cardW,
                  ),
                ),
              ),
            ),
            _stamp(ring, winnerPos(), vt),
          ],
        ];

        return SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(clipBehavior: Clip.none, children: children),
        );
      },
    );
  }

  Widget _stamp(_Ring ring, Offset p, double vt) {
    final s = Curves.easeOutBack.transform(_seg(vt, 0.56, 0.70));
    if (s <= 0.01) return const SizedBox.shrink();
    final sw = ring.cardW * 1.5;
    final sh = sw * 90 / 220;
    return Positioned(
      left: p.dx - sw / 2,
      top: p.dy + ring.cardH * 0.12 - sh / 2,
      width: sw,
      height: sh,
      child: IgnorePointer(
        child: Opacity(
          opacity: _a(s),
          child: Transform.rotate(
            angle: -0.22,
            child: Transform.scale(
              scale: 2.4 - 1.4 * s,
              child: GameIcon('tertuduh', width: sw, height: sh),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- keterangan di bawah lingkaran ----------

  Widget _caption() => SizedBox(
    height: 88,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: switch (_phase) {
          1 => _voteLine(),
          2 => _waiting(),
          3 => _verdictLine(),
          _ => const SizedBox.shrink(),
        },
      ),
    ),
  );

  /// "A memilih B": nama sasaran baru terungkap saat petir melesat.
  Widget _voteLine() {
    if (_stage == 0 || _i >= _votes.length) return const SizedBox.shrink();
    final v = _votes[_i];
    final voterMine = v['voter_id'] == widget.myId;
    final targetMine = v['target_id'] == widget.myId;
    return AnimatedBuilder(
      animation: _strike,
      builder: (context, _) {
        final reveal = _stage >= 2 ? _seg(_strike.value, 0.30, 0.62) : 0.0;
        return Text.rich(
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
                text: _stage >= 2 ? (targetMine ? 'kamu' : _targetName(v)) : '...',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _stage >= 2
                      ? EmbunColors.blood.withValues(alpha: _a(reveal))
                      : Colors.white38,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        );
      },
    );
  }

  /// Hening setelah suara terakhir: belum ada yang diumumkan.
  Widget _waiting() => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 600),
    builder: (_, t, child) => Opacity(opacity: t, child: child),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Semua suara telah masuk...',
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white70),
        ),
        if (_abstain.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '${_abstain.length} tidak memilih',
            style: const TextStyle(fontSize: 12.5, color: Colors.white54),
          ),
        ],
      ],
    ),
  );

  Widget _verdictLine() {
    final wid = _winnerId;
    return AnimatedBuilder(
      animation: _vc,
      builder: (context, _) {
        final t = _vc.value;
        if (wid == null) {
          final inT = Curves.easeOut.transform(_seg(t, 0.0, 0.35));
          final sway =
              math.sin(t * 2 * math.pi * 1.5) * 0.14 * (1 - _seg(t, 0.55, 1.0));
          return Opacity(
            opacity: inT,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 330),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.rotate(
                          angle: sway,
                          child: const Icon(Icons.balance_rounded,
                              size: 24, color: _teal),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Tidak ada yang mencapai mayoritas',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Desa menahan napas. Kali ini tak seorang pun dituduh.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: Colors.white54),
                    ),
                    const Text(
                      'Butuh lebih dari separuh suara.',
                      style: TextStyle(fontSize: 12, color: Colors.white38),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final w = _person(wid);
        final head = Curves.easeOutCubic.transform(_seg(t, 0.06, 0.30));
        final countT = Curves.easeOut.transform(_seg(t, 0.62, 0.90));
        final shown = ((_counts[wid] ?? 0) * countT).round();
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
            const SizedBox(height: 4),
            Opacity(
              opacity: _seg(t, 0.58, 0.68),
              child: Text(
                '${w == null ? '' : (w.id == widget.myId ? 'Kamu' : w.name)}'
                    ' · $shown dari $_total suara',
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

  Widget _majorityBanner() {
    final p = _person(_winnerId);
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

/// Menggambar shader latar `vote_reveal.frag` layar penuh (BlendMode.plus).
/// Urutan setFloat harus sama dengan deklarasi uniform di shader.
class _VoteFxPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double time;
  final double heat;
  final double beat;
  final double slam;
  final double verdict;
  final double calm;
  final Offset centerFrac;
  final Color hot;
  final Color cool;

  const _VoteFxPainter({
    required this.shader,
    required this.time,
    required this.heat,
    required this.beat,
    required this.slam,
    required this.verdict,
    required this.calm,
    required this.centerFrac,
    required this.hot,
    required this.cool,
  });

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time)
      ..setFloat(3, heat)
      ..setFloat(4, beat)
      ..setFloat(5, slam)
      ..setFloat(6, size.width * centerFrac.dx)
      ..setFloat(7, size.height * centerFrac.dy)
      ..setFloat(8, verdict)
      ..setFloat(9, calm)
      ..setFloat(10, hot.r)
      ..setFloat(11, hot.g)
      ..setFloat(12, hot.b)
      ..setFloat(13, cool.r)
      ..setFloat(14, cool.g)
      ..setFloat(15, cool.b);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = shader
        ..blendMode = BlendMode.plus,
    );
  }

  // Selalu digambar ulang: waktu, denyut, dan hantaman berubah tiap bingkai.
  @override
  bool shouldRepaint(covariant _VoteFxPainter old) => true;
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

/// Serangan satu suara di atas lingkaran kartu, plus benang jejak semua suara
/// yang sudah masuk.
///
/// Serangan [live] ([t] = 0..1): 0-0.22 orb tenaga berkumpul di tepi kartu
/// pemilih, 0.22-0.62 petir meluncur makin cepat dengan ekor komet,
/// 0.62-1 hantaman di kartu sasaran (sabetan, cincin kejut, serpihan, "+N").
///
/// Benang: panah tipis melengkung dari pemilih ke sasaran. Saat vonis,
/// benang menuju pemenang menyala merah dan sisanya memudar.
class _RingPainter extends CustomPainter {
  final _Ring ring;
  final List<_Edge> edges;
  final _Edge? live;
  final double t;
  final Color accent;
  final bool intense;
  final double verdict; // 0..1 (hanya fase vonis)
  final int winner; // -1 = tak ada

  const _RingPainter({
    required this.ring,
    required this.edges,
    required this.live,
    required this.t,
    required this.accent,
    required this.intense,
    required this.verdict,
    required this.winner,
  });

  static Color _colorOf(_Edge e) => e.fog
      ? EmbunColors.mist
      : (e.weight >= 2 ? EmbunColors.gold : EmbunColors.blood);

  void _thread(Canvas canvas, _Curve cv, Color col, double alpha) {
    final path = Path()
      ..moveTo(cv.a.dx, cv.a.dy)
      ..quadraticBezierTo(cv.c.dx, cv.c.dy, cv.b.dx, cv.b.dy);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = col.withValues(alpha: _a(alpha)),
    );
    final tg = cv.b - cv.c;
    final l = tg.distance;
    if (l < 0.1) return;
    final d = tg / l;
    final nr = Offset(-d.dy, d.dx);
    const s = 7.0;
    final head = Path()
      ..moveTo(cv.b.dx, cv.b.dy)
      ..lineTo(cv.b.dx - d.dx * s + nr.dx * s * 0.55,
          cv.b.dy - d.dy * s + nr.dy * s * 0.55)
      ..lineTo(cv.b.dx - d.dx * s - nr.dx * s * 0.55,
          cv.b.dy - d.dy * s - nr.dy * s * 0.55)
      ..close();
    canvas.drawPath(head, Paint()..color = col.withValues(alpha: _a(alpha + 0.15)));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = ring.cardW;
    final h = ring.cardH;

    // 1. Benang jejak semua suara yang sudah mendarat.
    for (final e in edges) {
      final cv = _curveBetween(ring.at(e.from), ring.at(e.to), w, h);
      if (cv == null) continue;
      var col = _colorOf(e);
      var al = 0.32;
      if (verdict > 0) {
        if (winner >= 0) {
          final f = Curves.easeOut.transform(_seg(verdict, 0.40, 0.58));
          if (e.to == winner) {
            col = Color.lerp(col, EmbunColors.blood, f)!;
            al = 0.32 + 0.5 * f;
          } else {
            al = 0.32 * (1 - f);
          }
        } else {
          al = 0.32 * (1 - 0.6 * Curves.easeOut.transform(_seg(verdict, 0, 0.4)));
        }
      }
      _thread(canvas, cv, col, al);
    }

    // 2. Serangan yang sedang berlangsung.
    final lv = live;
    if (lv == null || t <= 0) return;
    final srcP = ring.at(lv.from);
    final tgtP = ring.at(lv.to);
    final cv = _curveBetween(srcP, tgtP, w, h);

    final charge = _seg(t, 0, 0.22);
    final fireU = _seg(t, 0.22, _kHitAt);
    final hitV = _seg(t, _kHitAt, 1.0);
    final core = intense ? const Color(0xFFFFE9A8) : Colors.white;
    final bw = intense ? 7.0 : 5.0;
    final seed = (t * 45).floor();
    const blur = MaskFilter.blur(BlurStyle.normal, 10);

    if (cv != null) {
      // Orb tenaga di tepi kartu pemilih.
      final orbA = t < 0.22 ? charge : 1 - _seg(t, 0.22, 0.42);
      if (orbA > 0.01) {
        final r = (4 + 11 * charge) * (1 + 0.18 * math.sin(t * 70));
        canvas.drawCircle(
          cv.a,
          r * 2.4,
          Paint()
            ..color = accent.withValues(alpha: _a(0.45 * orbA))
            ..maskFilter = blur,
        );
        canvas.drawCircle(cv.a, r, Paint()..color = core.withValues(alpha: _a(orbA)));
        if (t < 0.22) {
          // Percikan tersedot masuk ke orb.
          final sp = Paint();
          for (var k = 0; k < 10; k++) {
            final ang = k * math.pi * 2 / 10 + _rnd(k, 5) * 0.6;
            final dist = (1 - charge) * (22 + 20 * _rnd(k, 6)) + 5;
            sp.color = accent.withValues(alpha: _a(0.4 + 0.6 * charge));
            canvas.drawCircle(
              cv.a + Offset(math.cos(ang) * dist, math.sin(ang) * dist * 0.8),
              1.5,
              sp,
            );
          }
        }
      }

      // Petir bergerigi mengikuti lengkung benang.
      if (fireU > 0) {
        final hu = Curves.easeInCubic.transform(fireU);
        final amp = 7.0 * (1 - hitV);
        final chord = cv.b - cv.a;
        final cl = chord.distance;
        final nr = cl < 1 ? Offset.zero : Offset(-chord.dy / cl, chord.dx / cl);
        const n = 18;
        final path = Path()..moveTo(cv.a.dx, cv.a.dy);
        for (var k = 1; k <= n; k++) {
          final off = k == n
              ? 0.0
              : (_rnd(k, seed) - 0.5) * 2 * amp * math.sin(math.pi * k / n);
          final p = cv.at(hu * k / n) + nr * off;
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..color = accent.withValues(alpha: 0.22)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..strokeJoin = StrokeJoin.round
            ..color = accent.withValues(alpha: 0.5),
        );

        // Komet: kepala putih dan ekor yang memudar.
        final cometA = 1 - _seg(t, _kHitAt, 0.78);
        if (cometA > 0.01) {
          final head = cv.at(hu);
          for (var k = 8; k >= 1; k--) {
            final uu = hu - k * 0.035;
            if (uu < 0) continue;
            final f = 1 - k / 9;
            canvas.drawCircle(
              cv.at(uu),
              bw * (0.35 + 0.65 * f),
              Paint()
                ..color = accent.withValues(alpha: _a(0.7 * f * cometA))
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
            );
          }
          canvas.drawCircle(
            head,
            bw * 3,
            Paint()
              ..color = accent.withValues(alpha: _a(0.5 * cometA))
              ..maskFilter = blur,
          );
          canvas.drawCircle(
              head, bw * 0.9, Paint()..color = core.withValues(alpha: _a(cometA)));
        }
        // Setelah kena, benang menjadi panah jejak (sama dengan yang akan
        // tertinggal) supaya peralihannya mulus.
        if (hitV > 0) {
          _thread(canvas, cv, accent, 0.32 * _seg(hitV, 0, 0.5));
        }
      }
    }

    // 3. Hantaman di kartu sasaran.
    if (hitV > 0) {
      final backDir = srcP == tgtP
          ? -math.pi / 2
          : math.atan2(srcP.dy - tgtP.dy, srcP.dx - tgtP.dx);

      // Sabetan diagonal.
      final slashS = Curves.easeOut.transform(_seg(hitV, 0.0, 0.30));
      final slashF = 1 - _seg(hitV, 0.30, 0.85);
      if (slashS > 0 && slashF > 0) {
        final p0 = Offset(tgtP.dx + w / 2 + 10, tgtP.dy - h / 2 - 6);
        final p1 = Offset(tgtP.dx - w / 2 - 10, tgtP.dy + h / 2 + 6);
        final end = Offset.lerp(p0, p1, slashS)!;
        canvas.drawLine(
          p0,
          end,
          Paint()
            ..strokeWidth = 8
            ..strokeCap = StrokeCap.round
            ..color = accent.withValues(alpha: _a(0.6 * slashF))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        canvas.drawLine(
          p0,
          end,
          Paint()
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round
            ..color = Colors.white.withValues(alpha: _a(0.95 * slashF)),
        );
      }

      // Cincin kejut dari tengah kartu sasaran.
      final rr = Curves.easeOutCubic.transform(hitV);
      canvas.drawCircle(
        tgtP,
        w * 0.35 + w * (intense ? 1.1 : 0.9) * rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5 * (1 - hitV) + 0.6
          ..color = accent.withValues(alpha: _a(0.8 * (1 - hitV))),
      );

      // Serpihan memercik ke arah pemilih dan sekitarnya.
      final nShard = intense ? 22 : 16;
      final shard = Paint()
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      final se = Curves.easeOutCubic.transform(hitV);
      for (var k = 0; k < nShard; k++) {
        final ang = backDir + (_rnd(k, 7) - 0.5) * math.pi * 1.7;
        final dist = (18 + 52 * _rnd(k, 8)) * se;
        final dir = Offset(math.cos(ang), math.sin(ang));
        shard.color = (k.isEven ? Colors.white : accent)
            .withValues(alpha: _a(math.pow(1 - hitV, 1.2).toDouble()));
        canvas.drawLine(tgtP + dir * (dist * 0.55), tgtP + dir * dist, shard);
      }

      // Angka "+N" melayang naik dari kartu sasaran.
      final u = _seg(hitV, 0.05, 1.0);
      final a = _seg(u, 0, 0.15) * (1 - _seg(u, 0.65, 1.0));
      if (a > 0.01) {
        final fs = (w * 0.30).clamp(20.0, 38.0).toDouble();
        final tp = TextPainter(
          text: TextSpan(
            text: '+${lv.weight}',
            style: TextStyle(
              fontSize: fs,
              fontWeight: FontWeight.w900,
              color: core.withValues(alpha: _a(a)),
              shadows: [
                Shadow(color: accent.withValues(alpha: _a(a)), blurRadius: 14),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final sc = 0.6 + 0.6 * Curves.easeOutBack.transform(_seg(u, 0, 0.3));
        final c = Offset(
            tgtP.dx, tgtP.dy - h * 0.18 - 26 * Curves.easeOutCubic.transform(u));
        canvas
          ..save()
          ..translate(c.dx, c.dy)
          ..scale(sc);
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
        tp.dispose();
      }
    }
  }

  // Selalu digambar ulang: serangan berubah tiap bingkai.
  @override
  bool shouldRepaint(covariant _RingPainter old) => true;
}

/// Gelombang kejut dua lapis dari kartu yang dituduh.
class _ShockPainter extends CustomPainter {
  final Offset center;
  final double t; // 0..1
  final double unit; // lebar kartu
  const _ShockPainter(
      {required this.center, required this.t, required this.unit});

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    for (var k = 0; k < 2; k++) {
      final u = ((t - k * 0.14) / (1 - k * 0.14)).clamp(0.0, 1.0).toDouble();
      if (u <= 0 || u >= 1) continue;
      final e = Curves.easeOutCubic.transform(u);
      canvas.drawCircle(
        center,
        unit * (0.8 + 3.4 * e),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0 * (1 - u) + 0.8
          ..color = EmbunColors.blood.withValues(alpha: 0.65 * (1 - u)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ShockPainter old) =>
      old.t != t || old.center != center || old.unit != unit;
}

/// Kartu satu pemain di lingkaran: gambar karakter, nama, dan pojok angka
/// jumlah suara yang diterima. Makin dekat ke batas ([heat] 0..1), bingkai
/// dan angkanya makin merah.
class _RingCard extends StatelessWidget {
  final String name;
  final String? card;

  /// Gambar kartu pengganti (mis. kartu Fitnah); null = kartu karakter.
  final String? artPath;
  final double width;
  final int count;
  final double heat;
  final bool me;
  final bool winner;
  final bool abstained;
  final Color? glow;
  final double flash; // 0..1 kilat putih saat terhantam
  final String? tag;

  const _RingCard({
    required this.name,
    required this.card,
    this.artPath,
    required this.width,
    required this.count,
    required this.heat,
    required this.me,
    required this.winner,
    required this.abstained,
    required this.glow,
    required this.flash,
    required this.tag,
  });

  @override
  Widget build(BuildContext context) {
    final h = width * kProtagonistAspect;
    final badge = (width * 0.36).clamp(20.0, 34.0).toDouble();
    final fs = (width * 0.125).clamp(8.5, 13.0).toDouble();
    final hot = heat >= 0.5 ? (heat - 0.5) / 0.5 : 0.0;
    final borderCol = winner
        ? EmbunColors.blood
        : me
        ? EmbunColors.gold
        : hot > 0
        ? Color.lerp(Colors.white24, EmbunColors.blood, hot)!
        : null;
    final red = winner || hot > 0.4;

    return SizedBox(
      width: width + 14,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: borderCol == null
                      ? null
                      : Border.all(color: borderCol, width: winner ? 3 : 2.5),
                ),
                child: CardArt(
                  path: artPath ?? protagonistPath(card ?? 'default'),
                  width: width,
                  glow: glow,
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: _kNameH - 3,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fs,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: winner
                        ? Colors.white
                        : (me ? EmbunColors.gold : Colors.white70),
                  ),
                ),
              ),
            ],
          ),
          if (flash > 0.01)
            Positioned(
              left: 7,
              top: 0,
              width: width,
              height: h,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: _a(flash)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          if (abstained)
            Positioned(
              left: 7,
              top: 0,
              width: width,
              height: h,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(Icons.do_not_disturb_on_outlined,
                        size: (width * 0.45).clamp(16.0, 40.0).toDouble(),
                        color: Colors.white60),
                  ),
                ),
              ),
            ),
          if (tag != null && width >= 40)
            Positioned(
              top: -9,
              left: 0,
              right: 0,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    decoration: BoxDecoration(
                      color: tag == 'Fitnah' ? EmbunColors.mist : EmbunColors.gold,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      tag!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF07130F),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (count > 0)
            Positioned(
              top: -badge * 0.35,
              right: 7 - badge * 0.35,
              child: Container(
                width: badge,
                height: badge,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: red ? EmbunColors.blood : EmbunColors.gold,
                  border: Border.all(color: const Color(0xFF05080F), width: 1.6),
                  boxShadow: [
                    BoxShadow(
                      color: (red ? EmbunColors.blood : EmbunColors.gold)
                          .withValues(alpha: 0.55),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  transitionBuilder: (child, a) => ScaleTransition(
                      scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
                      child: child),
                  child: Text(
                    '$count',
                    key: ValueKey(count),
                    style: TextStyle(
                      fontSize: badge * 0.56,
                      height: 1.0,
                      fontWeight: FontWeight.w900,
                      color: red ? Colors.white : const Color(0xFF07130F),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}