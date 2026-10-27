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

/// Adegan sesudah semua pemain menyerahkan persembahan: layar beralih ke
/// gambar pohon Hayu, lalu SEMUA kartu yang dipersembahkan (baik maupun
/// jahat, tanpa nama pemilik) satu per satu:
///
///   naik dari bawah sebagai punggung -> berbalik menampakkan gambarnya ->
///   dilempar melengkung ke pohon -> meledak di batang Hayu.
///
/// Punggung kartu selalu punggung warga (sama untuk semua pemain) supaya
/// peran tidak bocor sebelum kartu berbalik. Ketuk layar untuk melewati.
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
  int _per = 2200; // ms per kartu
  final Set<int> _hapFlip = {};
  final Set<int> _hapHit = {};

  static const _lead = 500; // jeda awal (ms)
  static const _tail = 700; // jeda akhir (ms)

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
    _per = cards.length <= 6 ? 2200 : 1700;
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

  /// Waktu lokal kartu ke-i dalam satuan ms sejak kartu itu mulai.
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
  }

  bool _isBad(int i) =>
      widget.defs[_cards[i]]?['side'] == 'antagonis';

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
        color: const Color(0xFF0B1512),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Backdrop(
                path: landscapePath(_leaves), dark: widget.dark, dim: 0.78),
            if (!_loaded)
              const EmbunLoading(text: 'Menuju Hayu...')
            else
              LayoutBuilder(builder: (context, box) => _stage(box)),
          ],
        ),
      ),
    );
  }

  Widget _stage(BoxConstraints box) {
    final W = box.maxWidth, H = box.maxHeight;
    final cardH = (H * 0.32).clamp(110.0, 230.0).toDouble();
    final cardW = cardH * 7 / 9;
    final treeC = Offset(W / 2, H * 0.36);
    final mid = Offset(W / 2, H * 0.70);
    final start = Offset(W / 2, H + cardH * 0.7);
    final treeH = H * 0.56;

    return AnimatedBuilder(
      animation: _ctl!,
      builder: (context, _) {
        final n = _cards.length;
        final t = _ctl!.value * _ctl!.duration!.inMilliseconds - _lead;
        final cur = (t / _per).floor().clamp(0, n - 1).toInt();

        // Denyut pohon dan ledakan: kartu sekarang dan sebelumnya.
        var pulse = 0.0;
        final impacts = <_Impact>[];
        for (final k in {cur - 1, cur}) {
          if (k < 0 || k >= n) continue;
          final p = ((_local(k) / _per) - 0.86) / 0.45;
          if (p <= 0 || p >= 1) continue;
          pulse = math.max(pulse, math.sin(p * math.pi) * (1 - p));
          impacts.add(_Impact(k, p, _isBad(k)));
        }

        final shown = (t / _per).floor().clamp(-1, n - 1).toInt() + 1;

        Widget? flying;
        {
          final u = _local(cur) / _per;
          if (u >= 0 && u < 0.86) {
            final id = _cards[cur];
            final bad = _isBad(cur);
            final a = Curves.easeOutCubic.transform(_seg(u, 0, 0.28));
            final f = Curves.easeInOut.transform(_seg(u, 0.30, 0.50));
            final th = Curves.easeInCubic.transform(_seg(u, 0.66, 0.86));
            var pos = Offset.lerp(start, mid, a)!;
            var sc = 0.7 + 0.3 * a + 0.14 * math.sin(f * math.pi);
            var spin = 0.0;
            if (th > 0) {
              pos = Offset.lerp(mid, treeC, th)!;
              pos = pos.translate(0, -math.sin(th * math.pi) * H * 0.14);
              sc = 1.0 - 0.72 * th;
              spin = th * 3.5 * math.pi * (cur.isEven ? 1 : -1);
            }
            final angle = f * math.pi;
            final glow = bad ? EmbunColors.mist : const Color(0xFFFFD866);
            final face = angle < math.pi / 2
                ? _back(cardW, cardH)
                : Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(math.pi),
              child: _front(id, cardW, cardH, glow),
            );
            flying = Positioned(
              left: pos.dx - cardW / 2,
              top: pos.dy - cardH / 2,
              width: cardW,
              height: cardH,
              child: IgnorePointer(
                child: Transform.rotate(
                  angle: spin,
                  child: Transform.scale(
                    scale: sc,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0012)
                        ..rotateY(angle),
                      child: face,
                    ),
                  ),
                ),
              ),
            );
          }
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: treeC.dy - treeH / 2,
              height: treeH,
              child: Transform.scale(
                scale: 1 + 0.045 * pulse,
                child: TreePortrait(leaves: _leaves),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ImpactPainter(
                      impacts: impacts,
                      center: treeC,
                      radius: cardH * 0.95,
                      dark: widget.dark),
                ),
              ),
            ),
            ?flying,
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    children: [
                      const GameIcon('titlepersembahan',
                          width: 190, height: 50),
                      const SizedBox(height: 2),
                      Text(
                        'Persembahan untuk Hayu  $shown/$n',
                        style: const TextStyle(
                            fontSize: 12.5, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: SafeArea(
                child: Text('Ketuk untuk melewati',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.white38)),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Punggung warga untuk semua pemain: tidak membocorkan peran.
  Widget _back(double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 10),
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
        BoxShadow(color: glow.withValues(alpha: 0.6), blurRadius: 22),
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

/// Cincin kejut, kilatan, dan percikan di titik tumbukan.
class _ImpactPainter extends CustomPainter {
  final List<_Impact> impacts;
  final Offset center;
  final double radius;
  final bool dark;
  const _ImpactPainter({
    required this.impacts,
    required this.center,
    required this.radius,
    required this.dark,
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

      // Kilatan awal.
      canvas.drawCircle(
        center,
        radius * 0.55 * (0.4 + ease),
        Paint()
          ..shader = RadialGradient(colors: [
            Colors.white.withValues(alpha: 0.85 * fade * fade),
            a.withValues(alpha: 0.5 * fade),
            a.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(
              center: center, radius: radius * 0.55 * (0.4 + ease))),
      );

      // Dua cincin kejut.
      for (var r = 0; r < 2; r++) {
        final pr = (ease - r * 0.18).clamp(0.0, 1.0).toDouble();
        if (pr <= 0) continue;
        canvas.drawCircle(
          center,
          radius * (0.2 + 0.9 * pr),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 * (1 - pr) + 1
            ..color = (r == 0 ? a : b).withValues(alpha: 0.8 * (1 - pr)),
        );
      }

      // Percikan.
      final rnd = math.Random(im.k * 7919 + 13);
      const count = 22;
      for (var j = 0; j < count; j++) {
        final ang = (j / count) * 2 * math.pi + rnd.nextDouble() * 0.3;
        final spd = 0.55 + rnd.nextDouble() * 0.7;
        final d0 = radius * ease * spd;
        final len = 6 + 16 * fade;
        final p0 = center + Offset(math.cos(ang), math.sin(ang)) * d0;
        final p1 = center + Offset(math.cos(ang), math.sin(ang)) * (d0 + len);
        canvas.drawLine(
          p0,
          p1,
          Paint()
            ..strokeWidth = 2.4 * fade + 0.6
            ..strokeCap = StrokeCap.round
            ..color = (j.isEven ? spark : b).withValues(alpha: fade),
        );
      }

      // Serpihan jatuh (daun / bulir).
      for (var j = 0; j < 8; j++) {
        final ang = rnd.nextDouble() * 2 * math.pi;
        final d0 = radius * (0.3 + 0.6 * rnd.nextDouble()) * ease;
        final x = center.dx + math.cos(ang) * d0;
        final y = center.dy + math.sin(ang) * d0 + 40 * p * p;
        canvas.drawCircle(
          Offset(x, y),
          2.5 + 2 * fade,
          Paint()
            ..color = (bad ? const Color(0xFF8A74A8) : const Color(0xFF7FD3F7))
                .withValues(alpha: 0.8 * fade),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ImpactPainter old) => true;
}