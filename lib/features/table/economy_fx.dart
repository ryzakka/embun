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

String _fmtNum(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

const _dewLight = Color(0xFFBDF2E4);

Path _dropPath(Offset c, double s) => Path()
  ..addOval(Rect.fromCircle(center: c, radius: s))
  ..moveTo(c.dx - s * 0.85, c.dy - s * 0.45)
  ..lineTo(c.dx, c.dy - s * 2.1)
  ..lineTo(c.dx + s * 0.85, c.dy - s * 0.45)
  ..close();

// ===========================================================================
// Saldo embun: hitung naik/turun, label "+N" / "−N", tetes jatuh,
// dan hujan embun untuk pendapatan harian.
// ===========================================================================

/// Sisi tempat label "+N" melayang (pilih sisi yang ruangnya lapang).
enum FxSide { left, right }

/// Membungkus tampilan saldo. Tiap kali [balance] berubah:
///
/// * saldo dihitung naik/turun ke nilai baru ([builder] menerima angka yang
///   sedang ditampilkan);
/// * tampilan berdenyut dengan pendar (hijau/ungu bila naik, merah bila turun)
///   dan label "+N" atau "−N" melayang;
/// * naik: tetes embun jatuh ke ikon; turun: tetes melayang keluar.
///
/// Bila kenaikan terjadi bersamaan dengan pergantian [day] (dalam 3 detik,
/// urutan stream mana pun yang lebih dulu), itu dianggap PENDAPATAN HARIAN:
/// hujan tetes embun, kilau menyapu, hitungan lebih lambat, label
/// "+N hari ini".
///
/// [ready] false (data belum dimuat) dan perubahan pertama sesudahnya tidak
/// dianimasikan. [hold] true (adegan layar penuh menutupi tampilan) menahan
/// animasi sampai adegan selesai, supaya terlihat pemain.
class BalanceFx extends StatefulWidget {
  final double balance;
  final int day;
  final bool dark;
  final bool ready;
  final bool hold;
  final FxSide side;
  final Widget Function(BuildContext context, double shown) builder;

  /// Dipanggil tepat saat animasi perubahan saldo mulai ([delta] bertanda).
  /// Bila mengembalikan true, tetes embun bawaan tidak digambar karena
  /// lapisan lain (animasi memberi / menerima antar pemain) yang memainkannya;
  /// hitungan, denyut, dan label "+N" tetap jalan. Pendapatan harian tidak
  /// pernah dibisukan. Jangan memanggil setState di dalamnya (dipanggil saat
  /// membangun).
  final bool Function(double delta)? quiet;

  const BalanceFx({
    super.key,
    required this.balance,
    required this.day,
    required this.builder,
    this.dark = false,
    this.ready = true,
    this.hold = false,
    this.side = FxSide.right,
    this.quiet,
  });

  @override
  State<BalanceFx> createState() => _BalanceFxState();
}

class _BalanceFxState extends State<BalanceFx>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  double _from = 0, _to = 0;
  double _delta = 0;
  bool _daily = false;
  bool _quiet = false;
  bool _active = false;
  bool _pending = false;
  DateTime? _gainAt, _dayAt;
  bool _midHaptic = false;

  @override
  void initState() {
    super.initState();
    _from = _to = widget.balance;
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _active = false);
      }
    });
    _c.addListener(() {
      if (_daily && !_midHaptic && _c.value >= 0.55) {
        _midHaptic = true;
        HapticFeedback.selectionClick();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Nilai yang sedang tampil sekarang (dipakai sebagai awal hitungan baru).
  double _displayed() {
    if (_pending) return _from;
    if (_active) return _valueAt(_c.value);
    return _to;
  }

  double _valueAt(double u) {
    final k = Curves.easeOutCubic.transform(_seg(u, 0.08, 0.85));
    final v = _lerp(_from, _to, k);
    final whole = _from == _from.roundToDouble() && _to == _to.roundToDouble();
    return whole ? v.roundToDouble() : (v * 10).roundToDouble() / 10;
  }

  @override
  void didUpdateWidget(covariant BalanceFx old) {
    super.didUpdateWidget(old);
    final now = DateTime.now();

    if (!widget.ready) {
      _from = _to = widget.balance;
      _active = false;
      _pending = false;
      return;
    }
    if (!old.ready) {
      // Data pertama: terima diam-diam.
      _from = _to = widget.balance;
      _active = false;
      _pending = false;
      return;
    }

    if (widget.day != old.day) {
      _dayAt = now;
      // Saldo sudah lebih dulu naik: tingkatkan jadi efek harian.
      if (_active &&
          !_daily &&
          _delta > 0 &&
          _gainAt != null &&
          now.difference(_gainAt!) < const Duration(seconds: 3) &&
          !widget.hold) {
        _from = _displayed();
        _begin();
      }
    }

    if (widget.balance != old.balance) {
      final shown = _displayed();
      final change = widget.balance - old.balance;
      _delta = _pending ? _delta + change : change;
      if (!_pending) _from = shown;
      _to = widget.balance;
      if (change > 0) _gainAt = now;
      _pending = true;
    }

    if (_pending && !widget.hold) {
      _pending = false;
      _begin();
    }
  }

  void _begin() {
    final daily = _delta > 0 &&
        _dayAt != null &&
        _gainAt != null &&
        _gainAt!.difference(_dayAt!).abs() < const Duration(seconds: 3);
    _daily = daily;
    _quiet = !daily && (widget.quiet?.call(_delta) ?? false);
    _midHaptic = false;
    _active = true;
    _c.duration = Duration(milliseconds: daily ? 2000 : 1100);
    if (daily) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final active = _active;
        final u = active ? _c.value : 0.0;
        final gain = _delta > 0;
        final shown = _pending
            ? _from
            : (active ? _valueAt(u) : (_to == widget.balance ? _to : widget.balance));
        final dark = widget.dark;

        final env = active ? math.sin(math.pi * _seg(u, 0.0, 0.9)) : 0.0;
        final glowColor = gain
            ? (_daily
            ? EmbunColors.gold
            : (dark ? EmbunColors.mist : EmbunColors.leaf))
            : EmbunColors.blood;
        final pulse = active ? math.sin(math.pi * _seg(u, 0.0, 0.35)) : 0.0;

        final labelColor = gain
            ? (_daily
            ? EmbunColors.gold
            : (dark ? EmbunColors.mist : EmbunColors.leaf))
            : EmbunColors.blood;
        final labelA = active
            ? _smooth(_seg(u, 0.04, 0.16)) * (1 - _smooth(_seg(u, 0.80, 1.0)))
            : 0.0;
        final drift = Curves.easeOutCubic.transform(_seg(u, 0.04, 0.6)) * 10;
        final sign = gain ? '+' : '\u2212';

        final label = Text.rich(
          TextSpan(children: [
            TextSpan(
              text: '$sign${_fmtNum(_delta.abs())}',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: labelColor,
                shadows: [
                  Shadow(
                      color: labelColor.withValues(alpha: 0.7),
                      blurRadius: 10),
                  const Shadow(color: Colors.black, blurRadius: 4),
                ],
              ),
            ),
            if (_daily)
              const TextSpan(
                text: ' hari ini',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
          ]),
          maxLines: 1,
          softWrap: false,
        );

        final left = widget.side == FxSide.left;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Pendar di belakang.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: glowColor.withValues(alpha: 0.5 * env),
                        blurRadius: 6 + 16 * env,
                        spreadRadius: 1 * env,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Transform.scale(
              scale: 1 + 0.08 * pulse * (gain ? 1 : -0.6),
              child: widget.builder(context, shown),
            ),
            // Tetes embun, hujan harian, kilau.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _BalancePainter(
                    u: active ? u : -1,
                    gain: gain,
                    daily: _daily,
                    dark: dark,
                    quiet: active && _quiet,
                  ),
                ),
              ),
            ),
            // Label melayang.
            if (active && labelA > 0.01)
              Positioned(
                top: 0,
                bottom: 0,
                left: left ? -8 : null,
                right: left ? null : -8,
                child: FractionalTranslation(
                  translation: Offset(left ? -1 : 1, 0),
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: labelA,
                      child: Transform.translate(
                        offset: Offset(left ? -drift : drift, 0),
                        child: Align(alignment: Alignment.center, child: label),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BalancePainter extends CustomPainter {
  final double u; // <0 = tidak aktif
  final bool gain;
  final bool daily;
  final bool dark;
  final bool quiet;
  const _BalancePainter(
      {required this.u,
        required this.gain,
        required this.daily,
        required this.dark,
        this.quiet = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (u < 0 || u >= 1) return;
    final dew = dark ? EmbunColors.mist : _dewLight;
    final tx = math.min(size.width * 0.3, size.height * 0.55 + 2);
    final cy = size.height * 0.5;
    final paint = Paint()..style = PaintingStyle.fill;

    if (quiet) {
      // Tetes digambar oleh lapisan lain (pemberian antar pemain).
    } else if (gain) {
      final n = daily ? 16 : 6;
      final fromY = -size.height * (daily ? 3.4 : 1.8);
      final spread = size.width * (daily ? 0.9 : 0.5);
      for (var i = 0; i < n; i++) {
        final d = (daily ? 0.0 : 0.02) + (daily ? 0.5 : 0.35) * _rnd(i, 1);
        final span = daily ? 0.30 : 0.38;
        final p = _seg(u, d, d + span);
        if (p <= 0) continue;
        final fall = Curves.easeIn.transform(p);
        final x0 = tx + (_rnd(i, 2) - 0.5) * spread;
        final x = _lerp(x0, tx, fall);
        final y = _lerp(fromY, cy, fall);
        final s = 2.6 + 2.2 * _rnd(i, 3);
        final a = (1 - _smooth(_seg(p, 0.82, 1.0)));
        paint.color = dew.withValues(alpha: 0.9 * a);
        canvas.drawPath(_dropPath(Offset(x, y), s), paint);
        paint.color = Colors.white.withValues(alpha: 0.7 * a);
        canvas.drawCircle(Offset(x - s * 0.3, y - s * 0.2), s * 0.28, paint);
        // Cipratan kecil saat mendarat.
        final r = _seg(p, 0.85, 1.0);
        if (r > 0 && r < 1) {
          canvas.drawCircle(
            Offset(tx, cy),
            _lerp(4, 17, Curves.easeOut.transform(r)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4 * (1 - r) + 0.4
              ..color = dew.withValues(alpha: 0.55 * (1 - r)),
          );
        }
      }
    } else {
      // Tetes melayang keluar ke bawah.
      for (var i = 0; i < 4; i++) {
        final p = _seg(u, 0.02 + 0.12 * i, 0.5 + 0.12 * i);
        if (p <= 0) continue;
        final e = Curves.easeIn.transform(p);
        final x = tx + (_rnd(i, 4) - 0.5) * size.height * 0.9;
        final y = _lerp(cy, cy + size.height * 1.5, e);
        final s = 2.4 + 1.6 * _rnd(i, 5);
        paint.color = dew.withValues(alpha: 0.85 * (1 - _smooth(p)));
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(math.pi); // ujung runcing menghadap ke bawah
        canvas.translate(-x, -y);
        canvas.drawPath(_dropPath(Offset(x, y), s), paint);
        canvas.restore();
      }
    }

    // Kilau emas menyapu (pendapatan harian).
    if (daily && gain) {
      final p = _seg(u, 0.45, 0.95);
      if (p > 0 && p < 1) {
        final e = Curves.easeInOut.transform(p);
        final fade = math.sin(p * math.pi);
        final rect = Offset.zero & size;
        canvas.save();
        canvas.clipRRect(RRect.fromRectAndRadius(
            rect.inflate(2), Radius.circular(math.min(20, size.height / 2))));
        final cx = _lerp(-size.width * 0.3, size.width * 1.3, e);
        canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0),
                EmbunColors.gold.withValues(alpha: 0.55 * fade),
                Colors.white.withValues(alpha: 0),
              ],
            ).createShader(Rect.fromLTWH(
                cx - size.width * 0.25, 0, size.width * 0.5, size.height)),
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BalancePainter old) =>
      old.u != u || old.gain != gain || old.daily != daily || old.quiet != quiet;
}

// ===========================================================================
// Kartu terbang saat dibeli
// ===========================================================================

/// Salinan kartu yang baru dibeli terangkat dari rak toko, melengkung terbang
/// ke tab "Meja" sambil mengecil dan meninggalkan jejak kilau emas, lalu
/// pecah jadi kilau di tab. Tetes embun melayang dari pil saldo ke kartu
/// sebagai tanda pembayaran.
///
/// [from] / [to] / [pay] adalah persegi dalam koordinat layar global. Bila
/// [to] null, kartu terbang ke tengah bawah layar. Memakai lapisan Overlay
/// sehingga tidak mengganggu tata letak dan hilang sendiri.
void showCardFlight(
    BuildContext context, {
      required Map<String, dynamic>? def,
      required Rect from,
      Rect? to,
      Rect? pay,
      int price = 0,
      bool dark = false,
    }) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: _CardFlight(
        def: def,
        from: from,
        to: to,
        pay: pay,
        price: price,
        dark: dark,
        onDone: () {
          if (entry.mounted) entry.remove();
        },
      ),
    ),
  );
  overlay.insert(entry);
}

class _CardFlight extends StatefulWidget {
  final Map<String, dynamic>? def;
  final Rect from;
  final Rect? to;
  final Rect? pay;
  final int price;
  final bool dark;
  final VoidCallback onDone;

  const _CardFlight({
    required this.def,
    required this.from,
    required this.to,
    required this.pay,
    required this.price,
    required this.dark,
    required this.onDone,
  });

  @override
  State<_CardFlight> createState() => _CardFlightState();
}

class _CardFlightState extends State<_CardFlight>
    with SingleTickerProviderStateMixin {
  static const _arrive = 0.78;

  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500));
  Offset _origin = Offset.zero;
  bool _arrived = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.lightImpact();
    _c.addListener(() {
      if (!_arrived && _c.value >= _arrive) {
        _arrived = true;
        HapticFeedback.mediumImpact();
      }
    });
    _c.forward().whenComplete(widget.onDone);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ro = context.findRenderObject();
      if (ro is RenderBox && ro.attached) {
        setState(() => _origin = ro.localToGlobal(Offset.zero));
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final from = widget.from.shift(-_origin);
    final to = (widget.to ??
        Rect.fromCenter(
            center: Offset(size.width / 2, size.height - 40),
            width: 40,
            height: 40))
        .shift(-_origin);
    final pay = widget.pay?.shift(-_origin);

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final lift = _smooth(_seg(t, 0.0, 0.2));
        final fly = Curves.easeInOutCubic.transform(_seg(t, 0.2, _arrive));
        final p0 = from.center;
        final p2 = to.center;
        final mid = Offset.lerp(p0, p2, 0.5)!;
        final p1 = mid + Offset(0, -(80 + (p2 - p0).distance * 0.12));
        Offset bez(double k) {
          final a = Offset.lerp(p0, p1, k)!;
          final b = Offset.lerp(p1, p2, k)!;
          return Offset.lerp(a, b, k)!;
        }

        final pos = bez(fly);
        final endScale =
        (math.min(to.width, to.height) * 0.7 / from.width).clamp(0.12, 0.5);
        final scale =
            _lerp(1.0, 1.12, lift) * _lerp(1.0, endScale, fly);
        final angle = math.sin(fly * math.pi) *
            0.28 *
            (p2.dx >= p0.dx ? 1 : -1);
        final cardA = 1 - _smooth(_seg(t, _arrive - 0.04, _arrive + 0.05));

        final glow = widget.dark ? EmbunColors.mist : const Color(0xFFFFD866);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Jejak kilau, pembayaran, dan ledakan di tujuan.
            Positioned.fill(
              child: CustomPaint(
                painter: _FlightPainter(
                  t: t,
                  arrive: _arrive,
                  bez: bez,
                  from: from,
                  to: to,
                  pay: pay,
                  price: widget.price,
                  glow: glow,
                  dark: widget.dark,
                ),
              ),
            ),
            if (cardA > 0.01)
              Positioned(
                left: pos.dx - from.width / 2,
                top: pos.dy - from.height / 2,
                width: from.width,
                height: from.height,
                child: Opacity(
                  opacity: cardA,
                  child: Transform.rotate(
                    angle: angle,
                    child: Transform.scale(
                      scale: scale,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: glow.withValues(
                                  alpha: 0.35 + 0.4 * math.sin(fly * math.pi)),
                              blurRadius: 18 + 14 * lift,
                              spreadRadius: 1 + 2 * lift,
                            ),
                          ],
                        ),
                        child: CardTile(
                          def: widget.def,
                          fallbackName: '',
                          width: from.width,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FlightPainter extends CustomPainter {
  final double t;
  final double arrive;
  final Offset Function(double) bez;
  final Rect from;
  final Rect to;
  final Rect? pay;
  final int price;
  final Color glow;
  final bool dark;

  const _FlightPainter({
    required this.t,
    required this.arrive,
    required this.bez,
    required this.from,
    required this.to,
    required this.pay,
    required this.price,
    required this.glow,
    required this.dark,
  });

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

  @override
  void paint(Canvas canvas, Size size) {
    final fly = Curves.easeInOutCubic.transform(_seg(t, 0.2, arrive));

    // Pembayaran: tetes embun dari pil saldo menuju kartu.
    final pr = pay;
    if (pr != null && price > 0) {
      final n = math.min(price, 6);
      final dew = dark ? EmbunColors.mist : _dewLight;
      final fill = Paint();
      for (var i = 0; i < n; i++) {
        final d = 0.0 + 0.04 * i;
        final p = _seg(t, d, d + 0.26);
        if (p <= 0 || p >= 1) continue;
        final e = Curves.easeInOut.transform(p);
        final a = pr.center;
        final b = from.center;
        final ctrl = Offset.lerp(a, b, 0.5)! + Offset(0, -26 - 8.0 * i);
        final q = Offset.lerp(
            Offset.lerp(a, ctrl, e)!, Offset.lerp(ctrl, b, e)!, e)!;
        final s = (3.4 - 1.4 * e);
        fill.color = dew.withValues(alpha: 0.95 * (1 - _smooth(_seg(p, 0.8, 1))));
        canvas.drawCircle(q, s, fill);
        fill.color = Colors.white.withValues(alpha: 0.6 * (1 - p));
        canvas.drawCircle(q.translate(-s * 0.3, -s * 0.3), s * 0.35, fill);
      }
    }

    // Jejak kilau di sepanjang lengkung.
    if (t > 0.2 && t < arrive + 0.05) {
      final fill = Paint();
      for (var k = 0; k < 14; k++) {
        final back = fly - k * 0.035;
        if (back <= 0) continue;
        final pt = bez(back.clamp(0.0, 1.0));
        final off = Offset((_rnd(k, 1) - 0.5) * 16, (_rnd(k, 2) - 0.5) * 16);
        final a = (1 - k / 14) * 0.85;
        fill.color = (k.isEven ? glow : Colors.white).withValues(alpha: a);
        _star(canvas, pt + off, (5.5 - k * 0.25).clamp(1.5, 6.0), fill);
      }
    }

    // Ledakan kilau + cincin di tujuan.
    final b = _seg(t, arrive, 1.0);
    if (b > 0 && b < 1) {
      final c = to.center;
      final e = Curves.easeOutCubic.transform(b);
      canvas.drawCircle(
        c,
        _lerp(8, math.max(to.width, to.height) * 0.9, e),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - b) + 0.6
          ..color = glow.withValues(alpha: 0.85 * (1 - b)),
      );
      canvas.drawCircle(
        c,
        _lerp(4, math.max(to.width, to.height) * 0.5, e),
        Paint()
          ..color = glow.withValues(alpha: 0.28 * (1 - b)),
      );
      final fill = Paint();
      for (var i = 0; i < 10; i++) {
        final a = i * 2 * math.pi / 10 + _rnd(i, 3);
        final d = (14 + 26 * _rnd(i, 4)) * e;
        fill.color = (i.isEven ? glow : Colors.white)
            .withValues(alpha: (1 - b).clamp(0.0, 1.0));
        _star(canvas, c + Offset(math.cos(a), math.sin(a)) * d,
            (3 + 3 * _rnd(i, 5)) * (1 - 0.5 * b), fill);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FlightPainter old) => old.t != t;
}