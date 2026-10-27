import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../../data/game_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'card_tile.dart';

double _seg(double u, double a, double b) =>
    ((u - a) / (b - a)).clamp(0.0, 1.0).toDouble();

double _smooth(double x) => x * x * (3 - 2 * x);

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
/// Punggung kartu selalu punggung warga supaya peran tidak bocor sebelum
/// kartu berbalik. Pohon tetap pada keadaan SEBELUM efek; jumlah daun yang
/// berubah baru diperlihatkan di layar hasil. Ketuk untuk melewati.
class OfferingCeremony extends StatefulWidget {
  final GameRepository repo;
  final String gameId;
  final int day;
  final int fallbackLeaves;
  final Map<String, Map<String, dynamic>> defs;
  final bool dark;
  final VoidCallback onDone;

  const OfferingCeremony({
    super.key,
    required this.repo,
    required this.gameId,
    required this.day,
    required this.fallbackLeaves,
    required this.defs,
    required this.onDone,
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
    _per = cards.length <= 6 ? 2400 : 1800;
    final total = _lead + cards.length * _per + _tail;
    final c = AnimationController(
        vsync: this, duration: Duration(milliseconds: total));
    c.addListener(_onTick);
    c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _finish();
    });
    setState(() {
      _cards = cards;
      _leaves = before ?? widget.fallbackLeaves;
      _ctl = c;
      _loaded = true;
    });
    c.forward();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    if (mounted) widget.onDone();
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

  @override
  void dispose() {
    _ctl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: Material(
        color: const Color(0xFF050A08),
        child: !_loaded
            ? Stack(
          fit: StackFit.expand,
          children: [
            Backdrop(
                path: landscapePath(_leaves),
                dark: widget.dark,
                dim: 0.78),
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
    final cardW = cardH * 7 / 9;
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
          if (b) {
            badP = math.max(badP, amp);
            dx += math.sin(p * 70) * 14 * (1 - p) * (1 - p);
            dy += math.cos(p * 55) * 6 * (1 - p) * (1 - p);
          } else {
            goodP = math.max(goodP, amp);
            dy -= math.sin(p * math.pi) * 5 * (1 - p);
          }
          impacts.add(_Impact(k, p, b));
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
        Widget? flying;
        Widget? plate;
        Widget? holdGlow;
        final ghosts = <Widget>[];
        final u = _local(cur) / _per;
        if (u >= 0 && u < 0.86) {
          final id = _cards[cur];
          final bad = _isBad(cur);
          final glow = bad ? EmbunColors.mist : const Color(0xFFFFD866);
          final dir = cur.isEven ? 1.0 : -1.0;
          final a = Curves.easeOutCubic.transform(_seg(u, 0, 0.26));
          final f = Curves.easeInOut.transform(_seg(u, 0.26, 0.46));
          final thRaw = _seg(u, 0.64, 0.86);
          final th = Curves.easeInCubic.transform(thRaw);
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

          // Cahaya di sekitar kartu saat ditampakkan.
          if (hover > 0) {
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
            front: _front(id, cardW, cardH, glow),
          );

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
                    child: _plate(id, bad),
                  ),
                ),
              ),
            );
          }
        }

        // ---- penutup / pembuka layar ----
        final fadeIn = 1 - _smooth(_seg(ms, 0, 800));
        final fadeOut = _smooth(_seg(ms, totalMs - 450, totalMs));
        final blackA = math.max(fadeIn, fadeOut);

        final capT = _smooth(_seg(tail, 0.12, 0.38)) *
            (1 - _smooth(_seg(tail, 0.82, 1.0)));
        final dots = '.' * (1 + ((ms / 350).floor() % 3));

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
            if (holdGlow != null) holdGlow,
            ...ghosts,
            if (flying != null) flying,
            if (plate != null) plate,
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

  Widget _pip(int i, int cur, double sec) {
    final landed = _local(i) / _per >= 0.86;
    final bad = _isBad(i);
    final col = bad ? EmbunColors.mist : EmbunColors.gold;
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
  Widget _plate(String id, bool bad) {
    final def = widget.defs[id];
    final accent = bad ? EmbunColors.mist : EmbunColors.gold;
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
      child: GameImage(path: cardBackPath(), cacheWidth: 360),
    ),
  );

  Widget _front(String id, double w, double h, Color glow) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: glow.withValues(alpha: 0.7), blurRadius: 26),
      ],
    ),
    child: CardTile(
      def: widget.defs[id],
      fallbackName: id,
      width: w,
    ),
  );
}

class _Impact {
  final int k; // nomor kartu (benih acak)
  final double p; // 0..1
  final bool bad;
  const _Impact(this.k, this.p, this.bad);
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
      final bad = im.bad || dark;
      final a = bad ? const Color(0xFFB07CE8) : const Color(0xFFFFD866);
      final b = bad ? const Color(0xFF6A3FA0) : const Color(0xFF9DF0B8);
      final spark = bad ? const Color(0xFFD9B8FF) : const Color(0xFFFFE08A);
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

      if (!bad) {
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
                const Color(0xFF1A1030).withValues(alpha: 0.6 * fade),
              ],
              stops: const [0.35, 1.0],
            ).createShader(rect),
        );

        // Retakan bercahaya.
        final crack = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.5
          ..color = const Color(0xFFE6D6FF).withValues(alpha: fade);
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