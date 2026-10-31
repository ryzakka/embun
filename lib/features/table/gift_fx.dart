import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../common/ornate.dart';
import 'card_tile.dart';

double _seg(double v, double a, double b) =>
    ((v - a) / (b - a)).clamp(0.0, 1.0).toDouble();

double _smooth(double x) => x * x * (3 - 2 * x);

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _rnd(int i, int k) {
  final v = math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
  return v - v.floorToDouble();
}

const _dewLight = Color(0xFFBDF2E4);
const _goldGlow = Color(0xFFFFD866);

Path _dropPath(Offset c, double s) => Path()
  ..addOval(Rect.fromCircle(center: c, radius: s))
  ..moveTo(c.dx - s * 0.85, c.dy - s * 0.45)
  ..lineTo(c.dx, c.dy - s * 2.1)
  ..lineTo(c.dx + s * 0.85, c.dy - s * 0.45)
  ..close();

void _star(Canvas canvas, Offset c, double r, Paint p) {
  final path = Path();
  for (var i = 0; i < 8; i++) {
    final rr = i.isEven ? r : r * 0.32;
    final a = i * math.pi / 4 - math.pi / 2;
    final pt = Offset(c.dx + math.cos(a) * rr, c.dy + math.sin(a) * rr);
    i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
  }
  path.close();
  canvas.drawPath(path, p);
}

/// Persegi widget dalam koordinat layar, atau null bila belum terpasang.
Rect? globalRectOf(GlobalKey? key) {
  final ro = key?.currentContext?.findRenderObject();
  if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
  return ro.localToGlobal(Offset.zero) & ro.size;
}

/// Persegi cadangan di tengah bawah layar, dipakai bila tujuan (mis. tab
/// Meja) sedang tidak tampil.
Rect screenFallbackRect(BuildContext context, {double dy = 40}) {
  final s = MediaQuery.sizeOf(context);
  return Rect.fromCenter(
      center: Offset(s.width / 2, s.height - dy), width: 40, height: 40);
}

/// Geser pusat persegi supaya tetap di dalam layar (avatar bisa tergulir
/// keluar dari deretan desa).
Rect _onScreen(Rect r, Size s) {
  const pad = 16.0;
  final c = Offset(
    r.center.dx.clamp(pad, math.max(pad, s.width - pad)).toDouble(),
    r.center.dy.clamp(pad, math.max(pad, s.height - pad)).toDouble(),
  );
  return Rect.fromCenter(center: c, width: r.width, height: r.height);
}

// ===========================================================================
// Kerangka overlay: lapisan di atas segalanya, hilang sendiri.
// ===========================================================================

class _Beat {
  final double at;
  final VoidCallback fire;
  const _Beat(this.at, this.fire);
}

typedef _FxBuilder = Widget Function(
    BuildContext context, double t, Offset origin);

void _showFx(
    BuildContext context, {
      required int ms,
      required _FxBuilder builder,
      List<_Beat> beats = const [],
    }) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: _FxOverlay(
        ms: ms,
        builder: builder,
        beats: beats,
        onDone: () {
          if (entry.mounted) entry.remove();
        },
      ),
    ),
  );
  overlay.insert(entry);
}

class _FxOverlay extends StatefulWidget {
  final int ms;
  final _FxBuilder builder;
  final List<_Beat> beats;
  final VoidCallback onDone;
  const _FxOverlay({
    required this.ms,
    required this.builder,
    required this.beats,
    required this.onDone,
  });

  @override
  State<_FxOverlay> createState() => _FxOverlayState();
}

class _FxOverlayState extends State<_FxOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: Duration(milliseconds: widget.ms));
  final Set<int> _fired = {};
  Offset? _origin;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      for (var i = 0; i < widget.beats.length; i++) {
        if (_c.value >= widget.beats[i].at && _fired.add(i)) {
          widget.beats[i].fire();
        }
      }
    });
    _c.forward().whenComplete(widget.onDone);
    // Lapisan Overlay belum tentu berawal di (0,0) layar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ro = context.findRenderObject();
      setState(() => _origin =
      (ro is RenderBox && ro.attached) ? ro.localToGlobal(Offset.zero) : Offset.zero);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = _origin;
    if (o == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _c,
      builder: (ctx, _) => widget.builder(ctx, _c.value, o),
    );
  }
}

Widget _chip(String text, Color accent, double opacity) => Opacity(
  opacity: opacity.clamp(0.0, 1.0).toDouble(),
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: accent.withValues(alpha: 0.85)),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
        color: accent,
      ),
    ),
  ),
);

// ===========================================================================
// Embun mengalir dari satu titik ke titik lain
// ===========================================================================

/// Tetes-tetes embun melengkung dari [from] ke [to]; di tujuan berpendar dan
/// beriak. Dipakai dua arah:
///
/// * memberi: [from] = saldo milikku, [to] = avatar penerima, [label] "+N";
/// * menerima: [from] = deretan desa (netral, pemberi tetap rahasia),
///   [to] = saldo milikku, tanpa [label] (angka sudah ditangani BalanceFx).
void showEmbunFlow(
    BuildContext context, {
      required Rect from,
      required Rect to,
      required int amount,
      bool dark = false,
      String? label,
    }) {
  final screen = MediaQuery.sizeOf(context);
  final a = _onScreen(from, screen);
  final b = _onScreen(to, screen);
  final n = math.min(10, amount.clamp(1, 9) * 2 + 2);
  final accent = dark ? EmbunColors.mist : EmbunColors.gold;
  _showFx(
    context,
    ms: 1500,
    beats: const [
      _Beat(0.0, HapticFeedback.lightImpact),
      _Beat(0.34, HapticFeedback.selectionClick),
      _Beat(0.62, HapticFeedback.mediumImpact),
    ],
    builder: (ctx, t, origin) {
      final ac = a.center - origin;
      final bc = b.center - origin;
      final labelA = label == null
          ? 0.0
          : _smooth(_seg(t, 0.5, 0.64)) * (1 - _smooth(_seg(t, 0.86, 1.0)));
      final rise = Curves.easeOutCubic.transform(_seg(t, 0.5, 1.0)) * 14;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _EmbunFlowPainter(
                t: t,
                a: ac,
                b: bc,
                targetSize: b.size,
                n: n,
                dew: dark ? EmbunColors.mist : _dewLight,
                accent: accent,
              ),
            ),
          ),
          if (label != null && labelA > 0.01)
            Positioned(
              left: bc.dx - 40,
              top: bc.dy - b.height / 2 - 30 - rise,
              width: 80,
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: accent.withValues(alpha: labelA),
                    shadows: [
                      Shadow(
                          color: accent.withValues(alpha: 0.8 * labelA),
                          blurRadius: 12),
                      Shadow(
                          color: Colors.black.withValues(alpha: labelA),
                          blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _EmbunFlowPainter extends CustomPainter {
  final double t;
  final Offset a, b;
  final Size targetSize;
  final int n;
  final Color dew, accent;
  const _EmbunFlowPainter({
    required this.t,
    required this.a,
    required this.b,
    required this.targetSize,
    required this.n,
    required this.dew,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint();
    final dist = (b - a).distance;
    final base = math.max(14.0, math.min(targetSize.width, targetSize.height));

    // Pendar di tujuan sejak tetes pertama mendekat.
    final glowP = _seg(t, 0.3, 0.95);
    if (glowP > 0 && glowP < 1) {
      final env = math.sin(glowP * math.pi);
      canvas.drawCircle(
        b,
        base * (0.7 + 0.3 * env),
        Paint()
          ..shader = RadialGradient(colors: [
            accent.withValues(alpha: 0.42 * env),
            accent.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: b, radius: base)),
      );
    }

    for (var i = 0; i < n; i++) {
      final start = 0.03 + 0.35 * i / n + 0.04 * _rnd(i, 9);
      final p = _seg(t, start, start + 0.42);
      final ctrl = Offset.lerp(a, b, 0.5)! +
          Offset((_rnd(i, 1) - 0.5) * 70,
              -(40 + dist * 0.12 + 40 * _rnd(i, 2)));
      Offset q(double k) {
        final u = Offset.lerp(a, ctrl, k)!;
        final v = Offset.lerp(ctrl, b, k)!;
        return Offset.lerp(u, v, k)!;
      }

      if (p > 0 && p < 1) {
        final e = Curves.easeInOut.transform(p);
        final pos = q(e);
        final ahead = q(math.min(1.0, e + 0.02));
        final ang =
            math.atan2(ahead.dy - pos.dy, ahead.dx - pos.dx) + math.pi / 2;
        final s = 3.4 + 2.0 * _rnd(i, 3);
        final fade = 1 - _smooth(_seg(p, 0.88, 1.0));
        for (var k = 1; k <= 3; k++) {
          final tp = q((e - 0.035 * k).clamp(0.0, 1.0).toDouble());
          fill.color = dew.withValues(alpha: 0.35 * fade * (1 - k / 4));
          canvas.drawCircle(tp, s * (1 - k * 0.18), fill);
        }
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(ang);
        fill.color = dew.withValues(alpha: 0.95 * fade);
        canvas.drawPath(_dropPath(Offset.zero, s), fill);
        fill.color = Colors.white.withValues(alpha: 0.7 * fade);
        canvas.drawCircle(Offset(-s * 0.3, -s * 0.2), s * 0.28, fill);
        canvas.restore();
      }

      // Cipratan kecil saat satu tetes mendarat.
      final r = _seg(t, start + 0.40, start + 0.56);
      if (r > 0 && r < 1) {
        canvas.drawCircle(
          b + Offset((_rnd(i, 4) - 0.5) * base * 0.5, (_rnd(i, 5) - 0.5) * base * 0.4),
          _lerp(3, 13, Curves.easeOut.transform(r)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4 * (1 - r) + 0.4
            ..color = dew.withValues(alpha: 0.6 * (1 - r)),
        );
      }
    }

    // Cincin penutup.
    final ring = _seg(t, 0.74, 1.0);
    if (ring > 0 && ring < 1) {
      final e = Curves.easeOutCubic.transform(ring);
      canvas.drawCircle(
        b,
        _lerp(8, base * 0.95, e),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - ring) + 0.6
          ..color = accent.withValues(alpha: 0.85 * (1 - ring)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EmbunFlowPainter old) => old.t != t;
}

// ===========================================================================
// Kartu terbang antar pemain
// ===========================================================================

/// Arah animasi kartu.
///
/// * [send]    kartu meninggalkan Mejaku dan terbang ke avatar [to]
///             (kartu benar-benar pindah tangan, mis. hasil tukar).
/// * [offer]   sama, tetapi berupa salinan agak transparan: kartu masih di
///             tanganku karena tawaran belum dijawab.
/// * [receive] kartu muncul dari avatar [from], melayang sebentar
///             memperlihatkan mukanya, lalu terbang masuk ke Mejaku [to].
enum GiftMode { send, offer, receive }

void showCardGift(
    BuildContext context, {
      required Map<String, dynamic>? def,
      required Rect from,
      required Rect to,
      required GiftMode mode,
      String? label,
      bool dark = false,
    }) {
  final screen = MediaQuery.sizeOf(context);
  final a = _onScreen(from, screen);
  final b = _onScreen(to, screen);
  final recv = mode == GiftMode.receive;
  _showFx(
    context,
    ms: recv ? 1900 : 1500,
    beats: recv
        ? const [
      _Beat(0.04, HapticFeedback.selectionClick),
      _Beat(0.18, HapticFeedback.lightImpact),
      _Beat(0.86, HapticFeedback.mediumImpact),
    ]
        : const [
      _Beat(0.0, HapticFeedback.lightImpact),
      _Beat(0.78, HapticFeedback.mediumImpact),
    ],
    builder: (ctx, t, origin) => _CardGiftView(
      t: t,
      origin: origin,
      screen: screen,
      def: def,
      from: a,
      to: b,
      mode: mode,
      label: label,
      dark: dark,
    ),
  );
}

class _CardGiftView extends StatelessWidget {
  final double t;
  final Offset origin;
  final Size screen;
  final Map<String, dynamic>? def;
  final Rect from, to;
  final GiftMode mode;
  final String? label;
  final bool dark;

  static const _cardW = 84.0;
  static const _cardH = _cardW * 9 / 7;

  const _CardGiftView({
    required this.t,
    required this.origin,
    required this.screen,
    required this.def,
    required this.from,
    required this.to,
    required this.mode,
    required this.label,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final recv = mode == GiftMode.receive;
    final bad = def?['side'] == 'antagonis';
    final glow = (dark || bad) ? EmbunColors.mist : _goldGlow;
    final accent = (dark || bad) ? EmbunColors.mist : EmbunColors.gold;

    final a = from.center - origin;
    final b = to.center - origin;
    // Titik melayang (hanya terima): tepat di bawah avatar sumber (deretan
    // desa ada di atas layar), tetap di dalam layar.
    final hover = recv
        ? Offset(
      a.dx.clamp(_cardW * 0.7, math.max(_cardW * 0.7, screen.width - _cardW * 0.7)).toDouble(),
      math.max(_cardH * 0.6 + 12, a.dy + from.height / 2 + _cardH * 0.6 + 10),
    )
        : a;

    final p0 = recv ? hover : a;
    final dist = (b - p0).distance;
    final p1 = Offset.lerp(p0, b, 0.5)! + Offset(0, -(70 + dist * 0.1));
    Offset bez(double k) {
      final u = Offset.lerp(p0, p1, k)!;
      final v = Offset.lerp(p1, b, k)!;
      return Offset.lerp(u, v, k)!;
    }

    final dir = b.dx >= p0.dx ? 1.0 : -1.0;
    final endScale =
    (math.min(to.width, to.height) * (recv ? 0.7 : 0.8) / _cardW)
        .clamp(0.15, 0.5)
        .toDouble();

    late final Offset pos;
    late final double scale, opacity, glowA, fly;
    if (recv) {
      final appear = Curves.easeOutCubic.transform(_seg(t, 0.0, 0.2));
      final grow = _smooth(_seg(t, 0.12, 0.42));
      fly = Curves.easeInOutCubic.transform(_seg(t, 0.46, 0.86));
      pos = fly > 0 ? bez(fly) : Offset.lerp(a, hover, appear)!;
      scale = _lerp(0.3, 0.95, appear) *
          (1 + 0.15 * grow) *
          _lerp(1.0, endScale, fly);
      opacity = _smooth(_seg(t, 0.0, 0.1)) *
          (1 - _smooth(_seg(t, 0.84, 0.93)));
      glowA = (0.35 + 0.5 * grow) * (1 - fly * 0.4);
    } else {
      final lift = _smooth(_seg(t, 0.0, 0.2));
      fly = Curves.easeInOutCubic.transform(_seg(t, 0.2, 0.78));
      pos = bez(fly);
      scale = _lerp(0.45, 1.0, lift) * _lerp(1.0, endScale, fly);
      opacity = _smooth(_seg(t, 0.0, 0.1)) *
          (1 - _smooth(_seg(t, 0.78, 0.9))) *
          (mode == GiftMode.offer ? 0.88 : 1.0);
      glowA = 0.35 + 0.4 * math.sin(fly * math.pi);
    }
    final angle = math.sin(fly * math.pi) * 0.3 * dir;

    // Label: terima = di bawah kartu yang melayang; kirim = di bawah avatar.
    Widget? labelW;
    if (label != null) {
      if (recv) {
        final la = _smooth(_seg(t, 0.14, 0.26)) * (1 - _smooth(_seg(t, 0.42, 0.52)));
        if (la > 0.01) {
          labelW = Positioned(
            left: hover.dx - 80,
            top: hover.dy + _cardH * 0.62 + 12,
            width: 160,
            child: Center(child: _chip(label!, accent, la)),
          );
        }
      } else {
        final la = _smooth(_seg(t, 0.7, 0.82)) * (1 - _smooth(_seg(t, 0.92, 1.0)));
        if (la > 0.01) {
          labelW = Positioned(
            left: b.dx - 80,
            top: b.dy + to.height / 2 + 8,
            width: 160,
            child: Center(child: _chip(label!, accent, la)),
          );
        }
      }
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _CardGiftPainter(
              t: t,
              recv: recv,
              fly: fly,
              bez: bez,
              b: b,
              toSize: to.size,
              glow: glow,
              accent: accent,
            ),
          ),
        ),
        if (opacity > 0.01)
          Positioned(
            left: pos.dx - _cardW / 2,
            top: pos.dy - _cardH / 2,
            width: _cardW,
            height: _cardH,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0).toDouble(),
              child: Transform.rotate(
                angle: angle,
                child: Transform.scale(
                  scale: scale,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: glow.withValues(alpha: glowA.clamp(0.0, 1.0).toDouble()),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CardTile(def: def, fallbackName: '', width: _cardW),
                  ),
                ),
              ),
            ),
          ),
        ?labelW,
      ],
    );
  }
}

class _CardGiftPainter extends CustomPainter {
  final double t;
  final bool recv;
  final double fly;
  final Offset Function(double) bez;
  final Offset b;
  final Size toSize;
  final Color glow, accent;
  const _CardGiftPainter({
    required this.t,
    required this.recv,
    required this.fly,
    required this.bez,
    required this.b,
    required this.toSize,
    required this.glow,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final base = math.max(18.0, math.max(toSize.width, toSize.height));

    // Jejak kilau sepanjang lengkung terbang.
    final flying = recv ? (t > 0.46 && t < 0.9) : (t > 0.2 && t < 0.82);
    if (flying) {
      final fill = Paint();
      for (var k = 0; k < 12; k++) {
        final back = fly - k * 0.035;
        if (back <= 0) continue;
        final pt = bez(back.clamp(0.0, 1.0).toDouble());
        final off = Offset((_rnd(k, 1) - 0.5) * 16, (_rnd(k, 2) - 0.5) * 16);
        fill.color = (k.isEven ? glow : Colors.white)
            .withValues(alpha: (1 - k / 12) * 0.85);
        _star(canvas, pt + off, (5.5 - k * 0.3).clamp(1.5, 6.0).toDouble(), fill);
      }
    }

    // Tiba: cincin + kilau (terima = ledakan lebih besar di Meja).
    final land = recv ? _seg(t, 0.86, 1.0) : _seg(t, 0.78, 1.0);
    if (land > 0 && land < 1) {
      final e = Curves.easeOutCubic.transform(land);
      canvas.drawCircle(
        b,
        _lerp(8, base * (recv ? 1.0 : 0.95), e),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - land) + 0.6
          ..color = glow.withValues(alpha: 0.85 * (1 - land)),
      );
      canvas.drawCircle(
        b,
        _lerp(4, base * 0.5, e),
        Paint()..color = glow.withValues(alpha: 0.28 * (1 - land)),
      );
      final fill = Paint();
      final count = recv ? 12 : 8;
      for (var i = 0; i < count; i++) {
        final ang = i * 2 * math.pi / count + _rnd(i, 3);
        final d = (14 + 26 * _rnd(i, 4)) * e;
        fill.color = (i.isEven ? glow : Colors.white)
            .withValues(alpha: (1 - land).clamp(0.0, 1.0).toDouble());
        _star(canvas, b + Offset(math.cos(ang), math.sin(ang)) * d,
            (3 + 3 * _rnd(i, 5)) * (1 - 0.5 * land), fill);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CardGiftPainter old) => old.t != t;
}