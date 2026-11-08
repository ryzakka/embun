import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../../data/game_repository.dart';
import '../common/art.dart';
import '../common/scene_flow.dart';
import '../common/ornate.dart';
import '../common/sfx.dart';
import 'card_tile.dart';

double _seg(double u, double a, double b) =>
    ((u - a) / (b - a)).clamp(0.0, 1.0).toDouble();

double _smooth(double x) => x * x * (3 - 2 * x);

double _lerp(double a, double b, double t) => a + (b - a) * t;

List<double> _sat(double s) {
  final inv = 1 - s;
  final r = 0.2126 * inv, g = 0.7152 * inv, b = 0.0722 * inv;
  return [
    r + s, g, b, 0, 0,
    r, g + s, b, 0, 0,
    r, g, b + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

Offset _bz(Offset p0, Offset c, Offset p1, double e) {
  final a = (1 - e) * (1 - e), b = 2 * (1 - e) * e, d = e * e;
  return Offset(
      a * p0.dx + b * c.dx + d * p1.dx, a * p0.dy + b * c.dy + d * p1.dy);
}

/// Palet pendaran khusus kartu lanjutan (kind 'lanjutan'), berbeda dari kartu
/// baik (emas) dan kartu jahat (ungu): Regenerasi hijau-aqua, Rekayasa merah
/// tua. Keduanya bertema DNA, seperti punggung kartunya.
class _AdvPal {
  final Color core, accent, spark, dim;
  const _AdvPal(this.core, this.accent, this.spark, this.dim);
}

const _regenPal = _AdvPal(
    Color(0xFF3DDC84), Color(0xFF7DF9E0), Color(0xFFD6FFE9), Color(0xFF0B2A1C));
const _rekayasaPal = _AdvPal(
    Color(0xFFFF3B4E), Color(0xFFFF8A5C), Color(0xFFFFD0C8), Color(0xFF30090F));

/// Gambar pohon menurut jumlah daun: pohon0 (rimbun) ... pohon9 (mati);
/// 30 daun (sempurna) memakai pohon0-sakura.
String? _treeFor(int leaves) {
  if (leaves >= 30) {
    final s = AssetCatalog.I.file(pohonDir, 'pohon0-sakura');
    if (s != null) return s;
  }
  return treePath(leaves);
}

/// Adegan sesudah semua pemain menyerahkan persembahan.
///
/// Pohon Hayu memenuhi layar (kamera mendekat pelan, bernapas). Lalu SEMUA
/// kartu yang dipersembahkan (baik maupun jahat, tanpa nama pemilik), satu
/// per satu:
///
///   naik dari bawah sebagai punggung -> berbalik, melayang, papan nama
///   muncul -> dilempar melengkung meninggalkan jejak -> menghantam Hayu.
///
/// Kartu baik: cahaya emas, berkas sinar, kelopak/daun beterbangan, pohon
/// mengembang. Kartu jahat: layar bergetar, retakan ungu, pohon memudar
/// warnanya sesaat. Aura di belakang Hayu tumbuh tiap kartu mendarat dan
/// warnanya bergeser antara emas dan ungu menurut kartu yang sudah masuk.
/// Setelah kartu terakhir, Hayu "menimbang": layar meredup, jantung pohon
/// berdetak, lalu layar menggelap menuju hasil.
///
/// Punggung kartu selalu punggung ITEM warga (hijau) supaya peran dan kartu
/// samaran tidak bocor sebelum kartu berbalik. Pohon tetap pada keadaan SEBELUM efek; jumlah daun yang
/// berubah baru diperlihatkan di layar hasil. Ketuk untuk melewati.
class OfferingCeremony extends StatefulWidget {
  final GameRepository repo;
  final String gameId;
  final int day;
  final int fallbackLeaves;
  final Map<String, Map<String, dynamic>> defs;
  final bool dark;
  /// [covered] true bila adegan berjalan sampai selesai DAN menampilkan hasil
  /// tiap kartu; layar nilai lalu hanya menampilkan sisa efek (kabut, dsb.).
  final void Function(bool covered) onDone;

  /// Batas daun untuk menang (menentukan garis pada bilah hitungan).
  final int winLeaves;

  const OfferingCeremony({
    super.key,
    required this.repo,
    required this.gameId,
    required this.day,
    required this.fallbackLeaves,
    required this.defs,
    required this.onDone,
    this.winLeaves = 20,
    this.dark = false,
  });

  @override
  State<OfferingCeremony> createState() => _OfferingCeremonyState();
}

class _OfferingCeremonyState extends State<OfferingCeremony>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctl;
  List<String> _cards = [];
  int _leaves = 0;
  bool _loaded = false;
  bool _done = false;
  int _per = 2400; // ms per kartu
  final Set<int> _hapFlip = {};
  final Set<int> _hapHit = {};
  bool _hapTail = false;

  /// Efek per kartu (effect_log.card_seq) dan apakah adegan sampai selesai.
  List<Map<String, dynamic>> _fx = [];
  bool _completed = false;
  bool get _hasBound => _fx.any((r) => r['card_seq'] != null);

  static const _lead = 900; // jeda awal (ms): pohon muncul dari gelap
  static const _tail = 1800; // jeda akhir (ms): Hayu menimbang

  @override
  void initState() {
    super.initState();
    _leaves = widget.fallbackLeaves;
    _load();
  }

  Future<void> _load() async {
    List<String> cards = [];
    int? before;
    try {
      final r = await Future.wait<Object?>([
        widget.repo.revealedCards(widget.gameId, widget.day),
        widget.repo.leavesBefore(widget.gameId),
      ]);
      cards = r[0] as List<String>;
      before = r[1] as int?;
    } catch (_) {}
    if (!mounted) return;
    if (cards.isEmpty) {
      _finish();
      return;
    }
    List<Map<String, dynamic>> fx = [];
    try {
      fx = await widget.repo.effects(widget.gameId, widget.day);
    } catch (_) {}
    if (!mounted) return;
    _per = cards.length <= 6 ? 2400 : 1800;
    final total = _lead + cards.length * _per + _tail;
    final c = AnimationController(
        vsync: this, duration: Duration(milliseconds: total));
    c.addListener(_onTick);
    c.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _completed = true;
        _finish();
      }
    });
    setState(() {
      _cards = cards;
      _fx = fx;
      _leaves = before ?? widget.fallbackLeaves;
      _ctl = c;
      _loaded = true;
    });
    c.forward();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    if (mounted) widget.onDone(_completed && _hasBound);
  }

  /// Waktu lokal kartu ke-i dalam ms sejak kartu itu mulai.
  double _local(int i) {
    final c = _ctl;
    if (c == null) return -1;
    final t = c.value * c.duration!.inMilliseconds - _lead;
    return t - i * _per;
  }

  void _onTick() {
    for (var i = 0; i < _cards.length; i++) {
      final u = _local(i) / _per;
      if (u >= 0.40 && _hapFlip.add(i)) HapticFeedback.selectionClick();
      if (u >= 0.86 && _hapHit.add(i)) {
        Sfx.I.play(_isBad(i) ? Snd.slashPedang : Snd.slashCahaya,
            owner: this, tag: 'hit', replace: true);
        if (_isBad(i)) {
          HapticFeedback.heavyImpact();
        } else {
          HapticFeedback.mediumImpact();
        }
      }
    }
    // Detak jantung Hayu saat menimbang ("lub-dub").
    final c = _ctl;
    if (c != null && !_hapTail) {
      final t = c.value * c.duration!.inMilliseconds - _lead;
      if (t >= _cards.length * _per + 200) {
        _hapTail = true;
        HapticFeedback.mediumImpact();
        Future.delayed(
            const Duration(milliseconds: 170), HapticFeedback.heavyImpact);
      }
    }
  }

  bool _isBad(int i) => widget.defs[_cards[i]]?['side'] == 'antagonis';

  /// Palet kartu lanjutan ke-i; null untuk kartu biasa.
  _AdvPal? _advPal(int i) {
    final d = widget.defs[_cards[i]];
    if (d?['kind'] != 'lanjutan') return null;
    return d?['side'] == 'antagonis' ? _rekayasaPal : _regenPal;
  }

  @override
  void dispose() {
    _ctl?.dispose();
    Sfx.I.release(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: Material(
        color: const Color(0xFF050A08),
        // Selagi data dimuat, layar menggelap pelan (bukan memotong ke hitam
        // saat adegan mulai, yang dulu tampak seperti kedipan).
        child: !_loaded
            ? Stack(
          fit: StackFit.expand,
          children: [
            Backdrop(
                path: landscapePath(_leaves),
                dark: widget.dark,
                dim: 0.78),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 650),
              builder: (context, a, child) => ColoredBox(
                  color: const Color(0xFF050A08).withValues(alpha: a)),
            ),
            const EmbunLoading(text: 'Menuju Hayu...'),
          ],
        )
            : LayoutBuilder(builder: (context, box) => _stage(box)),
      ),
    );
  }

  Widget _stage(BoxConstraints box) {
    final W = box.maxWidth, H = box.maxHeight;
    final cardH = (H * 0.30).clamp(110.0, 230.0).toDouble();
    final cardW = cardH / kTallAspect;
    final target = Offset(W / 2, H * 0.50);
    final mid = Offset(W / 2, H * 0.64);
    final start = Offset(W / 2, H + cardH * 0.7);
    final totalMs = _ctl!.duration!.inMilliseconds.toDouble();
    final treeImg = _treeFor(_leaves);
    final sakura = _leaves >= 30;

    return AnimatedBuilder(
      animation: _ctl!,
      builder: (context, _) {
        final ms = _ctl!.value * totalMs;
        final t = ms - _lead;
        final n = _cards.length;
        final cur = (t / _per).floor().clamp(0, n - 1).toInt();
        final endCards = n * _per.toDouble();
        final tail = ((t - endCards) / _tail).clamp(0.0, 1.0).toDouble();
        final beat = math
            .pow(math.max(0.0, math.sin(ms / 1000 * 2.4)), 8)
            .toDouble() *
            (1 + 1.5 * tail);

        // Kartu yang sudah mendarat: menentukan aura dan titik kemajuan.
        var goodN = 0, badN = 0;
        for (var i = 0; i < n; i++) {
          if (_local(i) / _per >= 0.86) {
            if (_isBad(i)) {
              badN++;
            } else {
              goodN++;
            }
          }
        }
        final landed = goodN + badN;
        final energy = n == 0 ? 0.0 : landed / n;
        var mix = landed == 0 ? 0.0 : badN / landed;
        if (widget.dark) mix = 0.5 + 0.5 * mix;
        final aura = Color.lerp(
            const Color(0xFFFFD866), const Color(0xFFB07CE8), mix)!;

        // Dampak kartu sekarang dan sebelumnya.
        var goodP = 0.0, badP = 0.0, dx = 0.0, dy = 0.0;
        final impacts = <_Impact>[];
        for (final k in {cur - 1, cur}) {
          if (k < 0 || k >= n) continue;
          final p = ((_local(k) / _per) - 0.86) / 0.45;
          if (p <= 0 || p >= 1) continue;
          final amp = math.sin(p * math.pi) * (1 - p);
          final b = _isBad(k);
          final blk = _isBlocked(k);
          if (blk) {
            // Ditahan: dentang kecil, tanpa guncangan hebat.
            dx += math.sin(p * 90) * 5 * (1 - p) * (1 - p);
          } else if (b) {
            badP = math.max(badP, amp);
            dx += math.sin(p * 70) * 14 * (1 - p) * (1 - p);
            dy += math.cos(p * 55) * 6 * (1 - p) * (1 - p);
          } else {
            goodP = math.max(goodP, amp);
            dy -= math.sin(p * math.pi) * 5 * (1 - p);
          }
          impacts.add(_Impact(k, p, b, _advPal(k), blk));
        }

        final shown = (t / _per).floor().clamp(-1, n - 1).toInt() + 1;

        // ---- pohon layar penuh ----
        final kb =
        Curves.easeInOut.transform((ms / totalMs).clamp(0.0, 1.0).toDouble());
        final treeScale = 1.0 + 0.10 * kb + 0.010 * beat + 0.025 * goodP;
        final sat = (1 - 0.65 * badP - 0.15 * tail).clamp(0.0, 1.0).toDouble();
        final tree = ClipRect(
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.scale(
              scale: treeScale,
              alignment: const Alignment(0, 0.25),
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix(_sat(sat)),
                child: GameImage(path: treeImg, cacheWidth: 1600),
              ),
            ),
          ),
        );

        // ---- kartu yang sedang beraksi ----
        var thFx = 0.0;
        var thBad = false;
        Widget? flying;
        Widget? plate;
        Widget? holdGlow;
        Widget? advFx;
        final ghosts = <Widget>[];
        final u = _local(cur) / _per;
        if (u >= 0 && u < 0.86) {
          final id = _cards[cur];
          final bad = _isBad(cur);
          final pal = _advPal(cur);
          final glow = pal?.core ??
              (bad ? EmbunColors.mist : const Color(0xFFFFD866));
          final dir = cur.isEven ? 1.0 : -1.0;
          final a = Curves.easeOutCubic.transform(_seg(u, 0, 0.26));
          final f = Curves.easeInOut.transform(_seg(u, 0.26, 0.46));
          final thRaw = _seg(u, 0.64, 0.86);
          final th = Curves.easeInCubic.transform(thRaw);
          thFx = thRaw;
          thBad = bad;
          final hover = _seg(u, 0.40, 0.50) * (1 - _seg(u, 0.62, 0.66));
          final ctrl = Offset(W / 2 - dir * W * 0.30,
              (mid.dy + target.dy) / 2 - H * 0.12);

          Offset posAt(double thv) {
            if (thv > 0) return _bz(mid, ctrl, target, thv);
            return Offset.lerp(start, mid, a)!
                .translate(0, math.sin(u * math.pi * 7) * 4 * hover);
          }

          double scaleAt(double thv) => thv > 0
              ? 1.0 - 0.72 * thv
              : 0.7 + 0.3 * a + 0.14 * math.sin(f * math.pi) + 0.06 * hover;

          double spinAt(double thv) => thv * 3.5 * math.pi * dir;

          // Cahaya di sekitar kartu saat ditampakkan (kartu lanjutan punya
          // pendaran sendiri di bawah: halo berdenyut, untai DNA, jejak).
          if (hover > 0 && pal == null) {
            holdGlow = Positioned(
              left: mid.dx - cardH * 0.9,
              top: mid.dy - cardH * 0.9,
              width: cardH * 1.8,
              height: cardH * 1.8,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      glow.withValues(alpha: 0.38 * hover),
                      glow.withValues(alpha: 0),
                    ]),
                  ),
                ),
              ),
            );
          }

          // Jejak bayangan saat dilempar.
          if (th > 0) {
            for (var k = 4; k >= 1; k--) {
              final thk = Curves.easeInCubic
                  .transform((thRaw - k * 0.055).clamp(0.0, 1.0).toDouble());
              if (thk <= 0) continue;
              ghosts.add(_flyingCard(
                pos: posAt(thk),
                spin: spinAt(thk),
                scale: scaleAt(thk),
                flip: math.pi,
                w: cardW,
                h: cardH,
                glow: glow,
                opacity: (1 - k / 5) * 0.32,
                back: _back(cardW, cardH),
                front: _back(cardW, cardH),
              ));
            }
          }

          flying = _flyingCard(
            pos: posAt(th),
            spin: spinAt(th),
            scale: scaleAt(th),
            flip: f * math.pi,
            w: cardW,
            h: cardH,
            glow: glow,
            back: _back(cardW, cardH),
            front: _front(id, cardW, cardH, glow,
                pal: pal, pulse: 0.5 + 0.5 * math.sin(ms / 1000 * 7)),
          );

          // Pendaran khusus kartu lanjutan. Mulai setelah kartu berbalik
          // (u >= 0.40), jadi tidak membocorkan jenis kartu dari punggungnya.
          if (pal != null) {
            final vis = _smooth(_seg(u, 0.40, 0.50)) * (1 - 0.35 * th);
            if (vis > 0.01) {
              final trail = <(Offset, double)>[];
              if (th > 0) {
                for (var k = 1; k <= 6; k++) {
                  final thk = Curves.easeInCubic.transform(
                      (thRaw - k * 0.05).clamp(0.0, 1.0).toDouble());
                  if (thk <= 0) continue;
                  trail.add((posAt(thk), scaleAt(thk)));
                }
              }
              advFx = Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _AdvFxPainter(
                      center: posAt(th),
                      scale: scaleAt(th),
                      cardW: cardW,
                      cardH: cardH,
                      sec: ms / 1000,
                      vis: vis,
                      trail: trail,
                      pal: pal,
                    ),
                  ),
                ),
              );
            }
          }

          final pt = _smooth(_seg(u, 0.30, 0.40)) *
              (1 - _smooth(_seg(u, 0.58, 0.66)));
          if (pt > 0.01) {
            plate = Positioned(
              left: 0,
              right: 0,
              top: mid.dy + cardH * 0.5 * 1.16 + 10,
              child: Center(
                child: Opacity(
                  opacity: pt,
                  child: Transform.translate(
                    offset: Offset(0, (1 - pt) * 10),
                    child: _plate(id, bad, pal),
                  ),
                ),
              ),
            );
          }
        }

        // ---- penutup / pembuka layar ----
        final fadeIn = 1 - _smooth(_seg(ms, 0, 800));
        final fadeOut =
        _smooth(_seg(ms, totalMs - kSceneFadeOutMs, totalMs));
        final blackA = math.max(fadeIn, fadeOut);

        final capT = _smooth(_seg(tail, 0.12, 0.38)) *
            (1 - _smooth(_seg(tail, 0.82, 1.0)));
        final dots = '.' * (1 + ((ms / 350).floor() % 3));

        // Kilatan layar sesaat saat kartu menghantam.
        var flashA = 0.0;
        var flashCol = const Color(0xFFFFF0B0);
        for (final im in impacts) {
          final f = (1 - im.p / 0.14).clamp(0.0, 1.0).toDouble();
          if (f <= 0) continue;
          final a = f * (im.blocked ? 0.26 : (im.bad ? 0.30 : 0.38));
          if (a > flashA) {
            flashA = a;
            flashCol = im.blocked
                ? const Color(0xFFBDF2FF)
                : (im.bad ? const Color(0xFFD9B8FF) : const Color(0xFFFFF0B0));
          }
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: tree),
            // peredam + vinyet (menutup rapat saat Hayu menimbang)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.26 + 0.2 * tail)),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.95,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.55 + 0.25 * tail),
                      ],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // aura, kabut, butiran cahaya berpusar menuju Hayu
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _Atmos(
                    ms: ms,
                    target: target,
                    dark: widget.dark,
                    energy: energy,
                    beat: beat,
                    tail: tail,
                    aura: aura,
                  ),
                ),
              ),
            ),
            // ledakan di titik hantam
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ImpactPainter(
                    impacts: impacts,
                    center: target,
                    radius: cardH * 1.0,
                    dark: widget.dark,
                    sakura: sakura,
                  ),
                ),
              ),
            ),
            if (flashA > 0.01)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(color: flashCol.withValues(alpha: flashA)),
                ),
              ),
            if (holdGlow != null) holdGlow,
            if (advFx != null) advFx,
            if (thFx > 0.15)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter:
                    _SpeedPainter(center: target, th: thFx, bad: thBad),
                  ),
                ),
              ),
            ...ghosts,
            if (flying != null) flying,
            if (plate != null) plate,
            ..._fxOverlay(context, ms, W, H, target),
            // judul
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Opacity(
                    opacity: _smooth(_seg(ms, 400, 1200)),
                    child: Column(
                      children: [
                        Text(
                          'Persembahan untuk Hayu  $shown/$n',
                          style: const TextStyle(
                              fontSize: 14,
                              letterSpacing: 1,
                              color: Colors.white70,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 8)
                              ]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Hayu menimbang
            if (capT > 0.01)
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: const Alignment(0, 0.62),
                    child: Opacity(
                      opacity: capT,
                      child: Text(
                        'Hayu menimbang persembahan$dots',
                        style: TextStyle(
                          fontSize: 17,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 1.2,
                          color: Color.lerp(EmbunColors.cream, aura, 0.35),
                          shadows: [
                            Shadow(color: aura, blurRadius: 18),
                            const Shadow(color: Colors.black, blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // titik kemajuan + petunjuk
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < n; i++)
                            _pip(i, cur, ms / 1000),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('Ketuk untuk melewati',
                          style: TextStyle(fontSize: 11, color: Colors.white38)),
                    ],
                  ),
                ),
              ),
            ),
            if (blackA > 0.01)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                      color: Colors.black
                          .withValues(alpha: blackA.clamp(0.0, 1.0).toDouble())),
                ),
              ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------ hasil tiap kartu

  /// Perubahan daun pada satu efek: hanya yang tertulis "+N daun" / "-N daun".
  int _leafDelta(Map<String, dynamic> r) {
    final m = RegExp(r'([+\-−–])\s*(\d+)\s*daun').firstMatch('${r['label'] ?? ''}');
    if (m == null) return 0;
    final v = int.parse(m.group(2)!);
    return m.group(1) == '+' ? v : -v;
  }

  List<Map<String, dynamic>> _rowsOf(int i) =>
      [for (final r in _fx) if (r['card_seq'] == i + 1) r];

  /// Peristiwa efek tiap kartu yang baru mendarat (waktu [u] dalam satuan kartu).
  /// Dipakai untuk kubah perlindungan, orb daun, dan angka raksasa.
  bool _isBlocked(int k) {
    for (final r in _rowsOf(k)) {
      final l = '${r['label'] ?? ''}'.toLowerCase();
      if (l.contains('menahan') || l.contains('dibatalkan')) return true;
    }
    return false;
  }

  bool _isShield(int k) {
    for (final r in _rowsOf(k)) {
      if (RegExp(r'\+\s*\d+\s*perlindungan', caseSensitive: false)
          .hasMatch('${r['label'] ?? ''}')) {
        return true;
      }
    }
    return false;
  }

  int _dsOf(int k) {
    var d = 0;
    for (final r in _rowsOf(k)) {
      d += _leafDelta(r);
    }
    return d;
  }

  /// Hitungan daun (bilah 30 segmen), angka raksasa saat mendarat, orb daun
  /// yang terbang ke hitungan, kubah perlindungan, dan label hasil.
  List<Widget> _fxOverlay(
      BuildContext context, double ms, double W, double H, Offset target) {
    if (!_hasBound) return const [];
    final n = _cards.length;
    final top = MediaQuery.paddingOf(context).top;
    final hudW = math.min(W * 0.86, 320.0);
    final hudTop = top + 30;
    final hudNum = Offset(W / 2, hudTop + 21);

    // Hitungan: tiap kartu menambah/mengurangi selagi orbnya tiba (u 1.10-1.32).
    var lvF = _leaves.toDouble();
    var last = -1;
    final events = <_Pt>[];
    for (var i = 0; i < n; i++) {
      final u = _local(i) / _per;
      if (u < 0.86) continue;
      last = i;
      final di = _dsOf(i);
      lvF += di * Curves.easeOutCubic.transform(_seg(u, 1.10, 1.32));
      if (u < 1.8) {
        events.add(_Pt(i, u, di, _isShield(i), _isBlocked(i)));
      }
    }
    lvF = lvF.clamp(0.0, 30.0).toDouble();
    final lv = lvF.round();
    final rows = last < 0 ? const <Map<String, dynamic>>[] : _rowsOf(last);
    final lu = last < 0 ? 0.0 : _local(last) / _per;
    final ds = last < 0 ? 0 : _dsOf(last);
    final blocked = last >= 0 && _isBlocked(last);

    final chipA = last < 0 ? 0.0 : _smooth(_seg(lu, 0.88, 1.0));
    final pulse = last < 0 ? 0.0 : math.sin(_seg(lu, 1.10, 1.45) * math.pi);
    final flash = ds > 0
        ? EmbunColors.leaf
        : ds < 0
        ? EmbunColors.blood
        : EmbunColors.gold;
    final hudA = _smooth(_seg(ms, 600, 1300));
    final shake = ds < 0
        ? math.sin(_seg(lu, 1.10, 1.45) * 60) * 5 * pulse
        : 0.0;

    // Angka raksasa / kata "DITAHAN" di titik hantam.
    Widget? big;
    if (last >= 0 && (ds != 0 || blocked)) {
      final inA = _smooth(_seg(lu, 0.86, 0.95));
      final outA = 1 - _smooth(_seg(lu, 1.12, 1.30));
      final op = inA * outA;
      if (op > 0.01) {
        final sc = _lerp(0.4, 1.0, Curves.easeOutBack.transform(_seg(lu, 0.86, 1.02)));
        final rise = 70 * Curves.easeOut.transform(_seg(lu, 0.86, 1.25));
        final bad = ds < 0;
        final txt = ds != 0 ? '${ds > 0 ? '+' : '−'}${ds.abs()}' : 'DITAHAN';
        final col = ds > 0
            ? const Color(0xFFFFF0B0)
            : ds < 0
            ? const Color(0xFFF4DDFF)
            : const Color(0xFFD8F8FF);
        final glow = ds > 0
            ? EmbunColors.leaf
            : ds < 0
            ? EmbunColors.blood
            : const Color(0xFF6FE3FF);
        big = Positioned(
          left: 0,
          right: 0,
          top: target.dy - 54 - rise,
          child: IgnorePointer(
            child: Opacity(
              opacity: op.clamp(0.0, 1.0).toDouble(),
              child: Transform.scale(
                scale: sc,
                child: Center(
                  child: Text(
                    txt,
                    style: TextStyle(
                      fontSize: ds != 0 ? 78 : 40,
                      fontWeight: FontWeight.w900,
                      fontStyle: ds == 0 ? FontStyle.italic : FontStyle.normal,
                      letterSpacing: ds == 0 ? 4 : 0,
                      height: 1,
                      color: col,
                      shadows: [
                        Shadow(color: glow, blurRadius: 28),
                        Shadow(color: glow.withValues(alpha: 0.8), blurRadius: 60),
                        Shadow(
                            color: Colors.black.withValues(alpha: bad ? 0.9 : 0.6),
                            blurRadius: 6),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return [
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: _PointFxPainter(
              events: events,
              target: target,
              hud: hudNum,
              radius: math.min(W, H) * 0.34,
            ),
          ),
        ),
      ),
      if (big != null) big,
      // hitungan daun: angka + bilah 30 segmen
      Positioned(
        left: 0,
        right: 0,
        top: hudTop,
        child: IgnorePointer(
          child: Opacity(
            opacity: hudA,
            child: Center(
              child: Transform.translate(
                offset: Offset(shake, 0),
                child: Transform.scale(
                  scale: 1 + 0.14 * pulse,
                  child: Container(
                    width: hudW,
                    padding: const EdgeInsets.fromLTRB(12, 5, 12, 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: Color.lerp(EmbunColors.goldDim, flash, pulse)!,
                          width: 1.5),
                      boxShadow: [
                        BoxShadow(
                            color: flash.withValues(alpha: 0.5 * pulse),
                            blurRadius: 24),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('$lv',
                                style: TextStyle(
                                    fontSize: 26,
                                    height: 1,
                                    fontWeight: FontWeight.w900,
                                    color: Color.lerp(
                                        EmbunColors.gold, flash, pulse))),
                            const SizedBox(width: 4),
                            const Text('/ 30 daun',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.white54)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        SizedBox(
                          height: 9,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _LeafBarPainter(
                                lit: lvF, win: widget.winLeaves, flash: flash, pulse: pulse),
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
      // label hasil kartu yang baru mendarat
      if (rows.isNotEmpty && chipA > 0.01)
        Positioned(
          left: 16,
          right: 16,
          top: hudTop + 66,
          child: IgnorePointer(
            child: Opacity(
              opacity: chipA,
              child: Transform.translate(
                offset: Offset(0, (1 - chipA) * 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final r in rows.take(3))
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: r['kind'] == 'bad'
                                  ? EmbunColors.blood
                                  : EmbunColors.leaf),
                        ),
                        child: Text('${r['label'] ?? ''}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: r['kind'] == 'bad'
                                    ? EmbunColors.blood
                                    : EmbunColors.leaf)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ];
  }

  Widget _pip(int i, int cur, double sec) {
    final landed = _local(i) / _per >= 0.86;
    final bad = _isBad(i);
    final col =
        _advPal(i)?.core ?? (bad ? EmbunColors.mist : EmbunColors.gold);
    final isCur = i == cur && !landed;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: landed ? col : Colors.white12,
        border: Border.all(
          color: landed
              ? col
              : isCur
              ? Colors.white70
              : Colors.white24,
          width: 1.4,
        ),
        boxShadow: landed
            ? [BoxShadow(color: col.withValues(alpha: 0.7), blurRadius: 8)]
            : null,
      ),
    );
  }

  /// Papan nama kartu yang sedang ditampakkan (tanpa nama pemilik).
  Widget _plate(String id, bool bad, _AdvPal? pal) {
    final def = widget.defs[id];
    final accent = pal?.core ?? (bad ? EmbunColors.mist : EmbunColors.gold);
    final name = (def?['name'] as String?) ?? id;
    final kind = kindLabel[def?['kind']] ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 16),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: accent)),
          Text(
            kind.isEmpty
                ? (bad ? 'Kartu jahat' : 'Kartu baik')
                : '${bad ? 'Kartu jahat' : 'Kartu baik'} · $kind',
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _flyingCard({
    required Offset pos,
    required double spin,
    required double scale,
    required double flip,
    required double w,
    required double h,
    required Color glow,
    required Widget back,
    required Widget front,
    double opacity = 1,
  }) {
    final face = flip < math.pi / 2
        ? back
        : Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(math.pi),
      child: front,
    );
    return Positioned(
      left: pos.dx - w / 2,
      top: pos.dy - h / 2,
      width: w,
      height: h,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0).toDouble(),
          child: Transform.rotate(
            angle: spin,
            child: Transform.scale(
              scale: scale.clamp(0.05, 3.0).toDouble(),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateY(flip),
                child: face,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Punggung warga untuk semua pemain: tidak membocorkan peran.
  Widget _back(double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.55), blurRadius: 10),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GameImage(path: itemBackPath(), cacheWidth: 360),
    ),
  );

  /// Bingkai terbang ([h]) seragam supaya bentuk kartu tidak membocorkan
  /// sisinya sebelum berbalik. Muka kartu baru memakai tingginya sendiri
  /// (2:3 untuk antagonis) dan meluber simetris dari bingkai.
  Widget _front(String id, double w, double h, Color glow,
      {_AdvPal? pal, double pulse = 0}) {
    final fh = w * cardAspectForDef(widget.defs[id]);
    return OverflowBox(
      minWidth: w,
      maxWidth: w,
      minHeight: fh,
      maxHeight: fh,
      child: Container(
        width: w,
        height: fh,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: glow.withValues(alpha: 0.7), blurRadius: 26),
            // Kartu lanjutan: lapis kedua yang berdenyut.
            if (pal != null)
              BoxShadow(
                  color: pal.accent.withValues(alpha: 0.30 + 0.30 * pulse),
                  blurRadius: 44 + 16 * pulse,
                  spreadRadius: 2 + 3 * pulse),
          ],
        ),
        child: CardTile(
          def: widget.defs[id],
          fallbackName: id,
          width: w,
        ),
      ),
    );
  }
}

class _Impact {
  final int k; // nomor kartu (benih acak)
  final double p; // 0..1
  final bool bad;
  final _AdvPal? pal; // kartu lanjutan: warna ledakan ikut palet
  final bool blocked; // serangan ditahan perlindungan: hantaman cyan, tanpa retak
  const _Impact(this.k, this.p, this.bad, [this.pal, this.blocked = false]);
}

/// Pendaran kartu lanjutan yang sedang ditampakkan dan dilempar: halo
/// berdenyut, untai DNA (heliks ganda) yang berputar di sekeliling kartu, dan
/// jejak cahaya mengikuti lemparan. Warna menurut [pal] (Regenerasi hijau-aqua,
/// Rekayasa merah tua).
class _AdvFxPainter extends CustomPainter {
  final Offset center;
  final double scale, cardW, cardH, sec, vis;
  final List<(Offset, double)> trail;
  final _AdvPal pal;
  const _AdvFxPainter({
    required this.center,
    required this.scale,
    required this.cardW,
    required this.cardH,
    required this.sec,
    required this.vis,
    required this.trail,
    required this.pal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final v = vis.clamp(0.0, 1.0).toDouble();

    // Jejak cahaya mengikuti lemparan.
    for (var i = 0; i < trail.length; i++) {
      final (p, s) = trail[i];
      final fall = 1 - i / trail.length;
      canvas.drawCircle(
        p,
        cardW * 0.55 * s,
        Paint()
          ..color = pal.core.withValues(alpha: 0.30 * fall * v)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }

    // Halo berdenyut.
    final pulse = 0.5 + 0.5 * math.sin(sec * 7);
    final hr = cardH * 0.95 * scale * (1 + 0.06 * pulse);
    canvas.drawCircle(
      center,
      hr,
      Paint()
        ..shader = RadialGradient(
          colors: [
            pal.accent.withValues(alpha: 0.30 * v * (0.8 + 0.2 * pulse)),
            pal.core.withValues(alpha: 0.22 * v),
            pal.core.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: hr)),
    );

    // Untai DNA: dua heliks berlawanan fase mengitari kartu.
    final halfH = cardH * 0.62 * scale;
    final amp = cardW * 0.58 * scale;
    const n = 16;
    final pts = <List<(Offset, double)>>[[], []];
    for (var st = 0; st < 2; st++) {
      for (var i = 0; i < n; i++) {
        final f = i / (n - 1);
        final y = (f * 2 - 1) * halfH;
        final ph = f * math.pi * 2.6 - sec * 3.2 + st * math.pi;
        pts[st].add((
        center + Offset(math.sin(ph) * amp, y),
        math.cos(ph) * 0.5 + 0.5, // 1 = di depan, 0 = di belakang
        ));
      }
    }
    final rung = Paint()
      ..strokeWidth = 1.2 * scale.clamp(0.4, 1.4)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < n; i++) {
      final f = i / (n - 1);
      final edge = math.min(1.0, math.min(f * 5, (1 - f) * 5));
      if (i % 3 == 1) {
        rung.color = pal.spark.withValues(alpha: 0.28 * v * edge);
        canvas.drawLine(pts[0][i].$1, pts[1][i].$1, rung);
      }
      for (var st = 0; st < 2; st++) {
        final (pos, depth) = pts[st][i];
        final sz = (2.0 + 1.8 * depth) * scale.clamp(0.4, 1.4);
        final al = (0.30 + 0.70 * depth) * v * edge;
        canvas.drawCircle(
            pos, sz * 2.6, Paint()..color = pal.core.withValues(alpha: 0.20 * al));
        canvas.drawCircle(
            pos,
            sz,
            Paint()
              ..color = Color.lerp(pal.accent, Colors.white, 0.45)!
                  .withValues(alpha: 0.95 * al));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AdvFxPainter old) => true;
}

/// Aura Hayu yang tumbuh tiap kartu mendarat, kabut tipis, dan butiran
/// cahaya yang berpusar menuju pohon.
class _Atmos extends CustomPainter {
  final double ms;
  final Offset target;
  final bool dark;
  final double energy;
  final double beat;
  final double tail;
  final Color aura;
  const _Atmos({
    required this.ms,
    required this.target,
    required this.dark,
    required this.energy,
    required this.beat,
    required this.tail,
    required this.aura,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final minS = math.min(w, h);
    final sec = ms / 1000;

    // aura
    final r = minS * (0.28 + 0.30 * energy + 0.05 * beat);
    final a = ((0.20 + 0.30 * energy) * (0.85 + 0.15 * beat) * (1 + 0.5 * tail))
        .clamp(0.0, 0.8)
        .toDouble();
    canvas.drawCircle(
      target,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            aura.withValues(alpha: a),
            aura.withValues(alpha: a * 0.35),
            aura.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: target, radius: r)),
    );

    // kabut
    final fp = Paint()
      ..color = Colors.white.withValues(alpha: dark ? 0.05 : 0.04)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    for (var i = 0; i < 4; i++) {
      final dir = i.isEven ? 1.0 : -1.0;
      final x = (i * 0.31 + sec * 0.012 * dir) % 1.3 - 0.15;
      canvas.drawCircle(
          Offset(w * x, h * (0.62 + 0.08 * i)), math.max(w, h) * 0.18, fp);
    }

    // butiran berpusar menuju Hayu
    final rnd = math.Random(3);
    final maxR = math.max(w, h) * 0.55;
    final cols = dark
        ? const [Color(0xFFD9B8FF), Color(0xFFB07CE8)]
        : const [Color(0xFFFFE08A), Color(0xFF9FE3FF)];
    for (var i = 0; i < 34; i++) {
      final a0 = rnd.nextDouble() * 2 * math.pi;
      final r0 = maxR * (0.45 + rnd.nextDouble() * 0.55);
      final period = 3.5 + rnd.nextDouble() * 3;
      final ph = rnd.nextDouble();
      final sz = 1.6 + rnd.nextDouble() * 2.8;
      final f = (sec / period + ph) % 1.0;
      final e = Curves.easeInCubic.transform(f);
      final rr = r0 * (1 - e) + 12;
      final ang = a0 + f * 2.4;
      final pos = target + Offset(math.cos(ang) * rr, math.sin(ang) * rr * 0.7);
      final al = (math.sin(f * math.pi) * 0.85).clamp(0.0, 1.0).toDouble();
      final col = Color.lerp(cols[i % 2], aura, 0.35)!;
      canvas.drawCircle(
          pos, sz * 2.6, Paint()..color = col.withValues(alpha: 0.16 * al));
      canvas.drawCircle(
          pos,
          sz,
          Paint()
            ..color = Color.lerp(col, Colors.white, 0.5)!
                .withValues(alpha: 0.9 * al));
    }
  }

  @override
  bool shouldRepaint(covariant _Atmos old) => true;
}

/// Ledakan di titik hantam. Kartu baik: kilatan, cincin, sinar emas, kelopak
/// atau daun beterbangan. Kartu jahat: kilatan ungu, cincin, retakan
/// bercahaya, serpihan gelap, dan vinyet yang menggelap.
class _ImpactPainter extends CustomPainter {
  final List<_Impact> impacts;
  final Offset center;
  final double radius;
  final bool dark;
  final bool sakura;
  const _ImpactPainter({
    required this.impacts,
    required this.center,
    required this.radius,
    required this.dark,
    required this.sakura,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final im in impacts) {
      final pal = im.pal;
      final bad = im.bad || dark;
      final a = im.blocked
          ? const Color(0xFF6FE3FF)
          : pal?.core ??
          (bad ? const Color(0xFFB07CE8) : const Color(0xFFFFD866));
      final b = im.blocked
          ? const Color(0xFFBDF2FF)
          : pal?.accent ??
          (bad ? const Color(0xFF6A3FA0) : const Color(0xFF9DF0B8));
      final spark = im.blocked
          ? Colors.white
          : pal?.spark ??
          (bad ? const Color(0xFFD9B8FF) : const Color(0xFFFFE08A));
      final p = im.p;
      final fade = (1 - p).clamp(0.0, 1.0).toDouble();
      final ease = Curves.easeOutCubic.transform(p);
      final rnd = math.Random(im.k * 7919 + 13);

      // Kilatan awal.
      final fr = radius * 0.7 * (0.4 + ease);
      canvas.drawCircle(
        center,
        fr,
        Paint()
          ..shader = RadialGradient(colors: [
            Colors.white.withValues(alpha: 0.9 * fade * fade),
            a.withValues(alpha: 0.55 * fade),
            a.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: center, radius: fr)),
      );

      // Tiga cincin kejut.
      for (var r = 0; r < 3; r++) {
        final pr = (ease - r * 0.14).clamp(0.0, 1.0).toDouble();
        if (pr <= 0) continue;
        canvas.drawCircle(
          center,
          radius * (0.2 + 1.1 * pr),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5 * (1 - pr) + 1
            ..color = (r == 0 ? a : (r == 1 ? b : spark))
                .withValues(alpha: 0.8 * (1 - pr)),
        );
      }

      // Percikan.
      const count = 26;
      for (var j = 0; j < count; j++) {
        final ang = (j / count) * 2 * math.pi + rnd.nextDouble() * 0.3;
        final spd = 0.55 + rnd.nextDouble() * 0.8;
        final d0 = radius * ease * spd;
        final len = 6 + 18 * fade;
        final dir = Offset(math.cos(ang), math.sin(ang));
        canvas.drawLine(
          center + dir * d0,
          center + dir * (d0 + len),
          Paint()
            ..strokeWidth = 2.4 * fade + 0.6
            ..strokeCap = StrokeCap.round
            ..color = (j.isEven ? spark : b).withValues(alpha: fade),
        );
      }

      if (im.blocked) {
        // Ditahan: kubah perlindungan digambar terpisah, tanpa retak/daun.
      } else if (!bad) {
        // Sinar emas yang menyebar.
        final rayLen = radius * (0.6 + 1.0 * ease);
        for (var j = 0; j < 10; j++) {
          final ang = j * 2 * math.pi / 10 + p * 0.8;
          const half = 0.07;
          final path = Path()
            ..moveTo(center.dx, center.dy)
            ..lineTo(center.dx + math.cos(ang - half) * rayLen,
                center.dy + math.sin(ang - half) * rayLen)
            ..lineTo(center.dx + math.cos(ang + half) * rayLen,
                center.dy + math.sin(ang + half) * rayLen)
            ..close();
          canvas.drawPath(
            path,
            Paint()
              ..blendMode = BlendMode.plus
              ..color = spark.withValues(alpha: 0.22 * fade),
          );
        }

        // Kelopak sakura / daun hijau beterbangan.
        const pink = [Color(0xFFF7B6D2), Color(0xFFFFD3E4), Color(0xFFF08FB5)];
        const greens = [
          Color(0xFF6FBF73),
          Color(0xFF8FE08F),
          Color(0xFFB9F08A),
          Color(0xFFFFE08A),
        ];
        for (var j = 0; j < 14; j++) {
          final ang = rnd.nextDouble() * 2 * math.pi;
          final d0 = radius * (0.4 + 0.9 * rnd.nextDouble()) * ease;
          final sz = 5 + rnd.nextDouble() * 6;
          final rot = rnd.nextDouble() * 6 + p * 5;
          final pos = center +
              Offset(math.cos(ang), math.sin(ang)) * d0 +
              Offset(0, 110 * p * p - 30 * ease);
          final col = sakura ? pink[j % pink.length] : greens[j % greens.length];
          canvas.save();
          canvas.translate(pos.dx, pos.dy);
          canvas.rotate(rot);
          final leaf = Path()
            ..moveTo(0, -sz)
            ..quadraticBezierTo(sz * 0.9, -sz * 0.2, 0, sz)
            ..quadraticBezierTo(-sz * 0.9, -sz * 0.2, 0, -sz);
          canvas.drawPath(leaf, Paint()..color = col.withValues(alpha: fade));
          canvas.restore();
        }
      } else {
        // Vinyet menggelap.
        final rect = Offset.zero & size;
        canvas.drawRect(
          rect,
          Paint()
            ..shader = RadialGradient(
              radius: 0.9,
              colors: [
                Colors.transparent,
                (pal?.dim ?? const Color(0xFF1A1030))
                    .withValues(alpha: 0.6 * fade),
              ],
              stops: const [0.35, 1.0],
            ).createShader(rect),
        );

        // Retakan bercahaya.
        final crack = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.5
          ..color = (pal?.spark ?? const Color(0xFFE6D6FF))
              .withValues(alpha: fade);
        for (var k = 0; k < 8; k++) {
          final ang = rnd.nextDouble() * 2 * math.pi;
          final len = (radius * 0.7 + rnd.nextDouble() * radius * 1.1) * ease;
          final path = Path()..moveTo(center.dx, center.dy);
          const steps = 4;
          for (var i = 1; i <= steps; i++) {
            final f = i / steps;
            final jitter = (rnd.nextDouble() - 0.5) * 24;
            final q = center +
                Offset(math.cos(ang), math.sin(ang)) * (len * f) +
                Offset(-math.sin(ang), math.cos(ang)) * jitter;
            path.lineTo(q.dx, q.dy);
          }
          canvas.drawPath(path, crack);
        }

        // Serpihan gelap.
        for (var j = 0; j < 10; j++) {
          final ang = rnd.nextDouble() * 2 * math.pi;
          final d0 = radius * (0.3 + 0.8 * rnd.nextDouble()) * ease;
          final sz = 4 + rnd.nextDouble() * 6;
          final pos = center +
              Offset(math.cos(ang), math.sin(ang)) * d0 +
              Offset(0, 70 * p * p);
          canvas.save();
          canvas.translate(pos.dx, pos.dy);
          canvas.rotate(rnd.nextDouble() * 6 + p * 4);
          final shard = Path()
            ..moveTo(0, -sz)
            ..lineTo(sz * 0.55, 0)
            ..lineTo(0, sz * 1.3)
            ..lineTo(-sz * 0.55, 0)
            ..close();
          canvas.drawPath(shard,
              Paint()..color = const Color(0xFF2A1745).withValues(alpha: fade));
          canvas.drawPath(
              shard,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.2
                ..color = spark.withValues(alpha: fade * 0.8));
          canvas.restore();
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ImpactPainter old) => true;
}

/// Satu kartu yang baru mendarat: [u] = waktu dalam satuan kartu (0.86 = hantam).
class _Pt {
  final int k;
  final double u;
  final int ds;
  final bool shield, blocked;
  const _Pt(this.k, this.u, this.ds, this.shield, this.blocked);
}

/// Garis kecepatan yang menyempit ke titik hantam saat kartu dilempar.
class _SpeedPainter extends CustomPainter {
  final Offset center;
  final double th; // 0..1 kemajuan lemparan
  final bool bad;
  const _SpeedPainter(
      {required this.center, required this.th, required this.bad});

  @override
  void paint(Canvas canvas, Size size) {
    final far = size.longestSide * 0.75;
    final col = bad ? const Color(0xFFD9B8FF) : const Color(0xFFFFE9A0);
    final k = Curves.easeIn.transform(th.clamp(0.0, 1.0).toDouble());
    for (var j = 0; j < 30; j++) {
      final h = math.sin(j * 12.9898) * 43758.5453;
      final r = h - h.floorToDouble();
      final ang = j / 30 * 2 * math.pi + r * 0.2;
      final dir = Offset(math.cos(ang), math.sin(ang));
      final r0 = far * (1 - 0.78 * k) * (0.7 + 0.3 * r);
      final len = far * 0.16 * k * (0.5 + r);
      canvas.drawLine(
        center + dir * r0,
        center + dir * (r0 + len),
        Paint()
          ..strokeWidth = 1.2 + 1.6 * r
          ..strokeCap = StrokeCap.round
          ..color = col.withValues(alpha: 0.38 * k * (0.4 + 0.6 * r)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedPainter old) => true;
}

/// Bilah 30 segmen: tiap segmen satu daun. Segmen terang = daun Hayu; garis
/// putih = batas menang.
class _LeafBarPainter extends CustomPainter {
  final double lit; // 0..30 (pecahan = sedang berubah)
  final int win;
  final Color flash;
  final double pulse;
  const _LeafBarPainter(
      {required this.lit,
        required this.win,
        required this.flash,
        required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    const n = 30;
    const gap = 2.0;
    final w = (size.width - gap * (n - 1)) / n;
    for (var i = 0; i < n; i++) {
      final x = i * (w + gap);
      final f = (lit - i).clamp(0.0, 1.0).toDouble();
      final rr = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 0, w, size.height), const Radius.circular(2));
      canvas.drawRRect(rr, Paint()..color = Colors.white.withValues(alpha: 0.12));
      if (f > 0) {
        final base = (i + 1) >= win ? EmbunColors.leaf : EmbunColors.gold;
        final near = ((lit - i).abs() < 1.6) ? pulse : 0.0;
        canvas.drawRRect(
          rr,
          Paint()
            ..color = Color.lerp(base, flash, near * 0.8)!
                .withValues(alpha: 0.35 + 0.65 * f),
        );
        if (near > 0.2) {
          canvas.drawRRect(
            rr,
            Paint()
              ..color = flash.withValues(alpha: 0.5 * near)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
          );
        }
      }
    }
    final wx = (win.clamp(1, n) * (w + gap)) - gap / 2 - 0.5;
    canvas.drawRect(Rect.fromLTWH(wx - 0.5, -3, 1.5, size.height + 6),
        Paint()..color = Colors.white70);
  }

  @override
  bool shouldRepaint(covariant _LeafBarPainter old) => true;
}

/// Kubah perlindungan (kisi heksagon + cincin) dan orb daun yang terbang dari
/// Hayu ke hitungan: emas-hijau bila menambah, ungu-merah bila mengurangi dan
/// pecah menjadi serpihan saat tiba.
class _PointFxPainter extends CustomPainter {
  final List<_Pt> events;
  final Offset target, hud;
  final double radius;
  const _PointFxPainter({
    required this.events,
    required this.target,
    required this.hud,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const cy = Color(0xFF6FE3FF);
    for (final e in events) {
      // ---------- kubah perlindungan ----------
      if (e.shield || e.blocked) {
        final q = ((e.u - 0.80) / 0.80).clamp(0.0, 1.0).toDouble();
        final flare = math.sin(q * math.pi);
        final strong = e.blocked ? 1.0 : 0.7;
        final r = radius * (0.92 + 0.14 * Curves.easeOut.transform(q));
        final rect = Rect.fromCircle(center: target, radius: r);
        canvas.drawCircle(
          target,
          r,
          Paint()
            ..shader = RadialGradient(colors: [
              cy.withValues(alpha: 0),
              cy.withValues(alpha: 0.05 * flare * strong),
              cy.withValues(alpha: 0.34 * flare * strong),
            ], stops: const [0.0, 0.62, 1.0])
                .createShader(rect),
        );
        // kisi heksagon di dalam kubah
        canvas.save();
        canvas.clipPath(Path()..addOval(rect));
        const hs = 24.0;
        final hp = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = cy.withValues(alpha: 0.30 * flare * strong);
        for (var row = -8; row <= 8; row++) {
          for (var col = -8; col <= 8; col++) {
            final cx = target.dx + col * hs * 1.732 + (row.isOdd ? hs * 0.866 : 0);
            final cyy = target.dy + row * hs * 1.5;
            if ((Offset(cx, cyy) - target).distance > r + hs) continue;
            final path = Path();
            for (var v = 0; v < 6; v++) {
              final a = math.pi / 6 + v * math.pi / 3;
              final px = cx + math.cos(a) * hs * 0.92;
              final py = cyy + math.sin(a) * hs * 0.92;
              v == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
            }
            path.close();
            canvas.drawPath(path, hp);
          }
        }
        canvas.restore();
        // cincin tepi
        canvas.drawCircle(
          target,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.2
            ..color = Colors.white.withValues(alpha: 0.75 * flare * strong),
        );
        canvas.drawCircle(
          target,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9
            ..color = cy.withValues(alpha: 0.35 * flare * strong)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
        if (e.blocked) {
          // serangan terpental di titik tepi kubah
          final ang = (e.k * 2.399) % (2 * math.pi);
          final hit = target + Offset(math.cos(ang), math.sin(ang)) * r;
          final pb = ((e.u - 0.86) / 0.45).clamp(0.0, 1.0).toDouble();
          final fade = 1 - pb;
          canvas.drawCircle(
            hit,
            10 + 46 * Curves.easeOut.transform(pb),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3 * fade + 0.5
              ..color = Colors.white.withValues(alpha: 0.9 * fade),
          );
          for (var j = 0; j < 12; j++) {
            final a = j / 12 * 2 * math.pi + e.k;
            final d0 = 8 + 50 * Curves.easeOut.transform(pb);
            final dir = Offset(math.cos(a), math.sin(a));
            canvas.drawLine(
              hit + dir * d0,
              hit + dir * (d0 + 12 * fade),
              Paint()
                ..strokeWidth = 2
                ..strokeCap = StrokeCap.round
                ..color = cy.withValues(alpha: fade),
            );
          }
        }
      }

      // ---------- orb daun menuju hitungan ----------
      if (e.ds != 0) {
        final good = e.ds > 0;
        final cnt = e.ds.abs().clamp(1, 7).toInt();
        final core = good ? const Color(0xFFFFF0B0) : const Color(0xFFF1D6FF);
        final halo = good ? EmbunColors.leaf : EmbunColors.blood;
        final mid = Offset.lerp(target, hud, 0.5)!;
        for (var j = 0; j < cnt; j++) {
          final delay = j * 0.05;
          final side = j.isEven ? 1.0 : -1.0;
          final ctrl = mid + Offset(side * (60 + 22 * j), 10.0 * j);
          final qr = (e.u - (0.92 + delay)) / 0.38;
          if (qr > 0 && qr < 1) {
            // jejak
            for (var s = 5; s >= 1; s--) {
              final qs = (qr - s * 0.045).clamp(0.0, 1.0).toDouble();
              if (qs <= 0) continue;
              final pp = _bez(target, ctrl, hud, Curves.easeInOut.transform(qs));
              canvas.drawCircle(
                pp,
                (5.5 - s * 0.6) * (1 - 0.3 * qs),
                Paint()
                  ..color = halo.withValues(alpha: 0.34 * (1 - s / 6))
                  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
              );
            }
            final pos = _bez(target, ctrl, hud, Curves.easeInOut.transform(qr));
            final sz = 6.5 + 2 * math.sin(qr * math.pi);
            canvas.drawCircle(
              pos,
              sz * 2.6,
              Paint()
                ..color = halo.withValues(alpha: 0.45)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
            );
            // daun kecil berputar
            canvas.save();
            canvas.translate(pos.dx, pos.dy);
            canvas.rotate(qr * 9 + j);
            final leaf = Path()
              ..moveTo(0, -sz)
              ..quadraticBezierTo(sz * 0.8, -sz * 0.2, 0, sz)
              ..quadraticBezierTo(-sz * 0.8, -sz * 0.2, 0, -sz);
            canvas.drawPath(leaf, Paint()..color = core);
            canvas.restore();
          }
          // tiba di hitungan
          final qa = (e.u - (1.30 + delay)) / 0.20;
          if (qa > 0 && qa < 1) {
            final f = 1 - qa;
            canvas.drawCircle(
              hud,
              10 + 34 * Curves.easeOut.transform(qa),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.5 * f + 0.5
                ..color = halo.withValues(alpha: 0.85 * f),
            );
            if (!good) {
              for (var s = 0; s < 6; s++) {
                final a = s / 6 * 2 * math.pi + j;
                final d0 = 8 + 30 * Curves.easeOut.transform(qa);
                canvas.drawLine(
                  hud + Offset(math.cos(a), math.sin(a)) * d0,
                  hud + Offset(math.cos(a), math.sin(a)) * (d0 + 8 * f),
                  Paint()
                    ..strokeWidth = 2
                    ..strokeCap = StrokeCap.round
                    ..color = const Color(0xFF2A1745).withValues(alpha: f),
                );
              }
            }
          }
        }
      }
    }
  }

  static Offset _bez(Offset a, Offset c, Offset b, double t) {
    final u = 1 - t;
    return Offset(u * u * a.dx + 2 * u * t * c.dx + t * t * b.dx,
        u * u * a.dy + 2 * u * t * c.dy + t * t * b.dy);
  }

  @override
  bool shouldRepaint(covariant _PointFxPainter old) => true;
}