import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Punggung kartu beli/item. Warga: hijau-emas; Si Terbisik: ungu kelam.
/// Rasio sama dengan CardTile (lebar : tinggi = 7 : 9).
class CardBackFace extends StatelessWidget {
  final double width;
  final bool dark;
  const CardBackFace({super.key, required this.width, this.dark = false});

  @override
  Widget build(BuildContext context) {
    final a = dark ? const Color(0xFF2A2140) : const Color(0xFF1F3A33);
    final b = dark ? const Color(0xFF120C1F) : const Color(0xFF0C1B17);
    final accent = dark ? const Color(0xFFB07CE8) : const Color(0xFFE8C766);
    return Container(
      width: width,
      height: width * 9 / 7,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [a, b],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.5), blurRadius: 8),
        ],
      ),
      child: CustomPaint(
        painter: _BackPainter(accent),
        child: Center(
          child: Icon(
            dark ? Icons.circle : Icons.eco,
            size: width * 0.36,
            color: accent.withValues(alpha: 0.85),
            shadows: [Shadow(color: accent, blurRadius: 18)],
          ),
        ),
      ),
    );
  }
}

class _BackPainter extends CustomPainter {
  final Color c;
  _BackPainter(this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(
      Rect.fromLTWH(7, 7, size.width - 14, size.height - 14),
      const Radius.circular(8),
    );
    canvas.save();
    canvas.clipRRect(rr);
    final line = Paint()
      ..color = c.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    const step = 14.0;
    for (var x = -size.height; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), line);
      canvas.drawLine(Offset(x + size.height, 0), Offset(x, size.height), line);
    }
    canvas.restore();
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = c.withValues(alpha: 0.4),
    );
    final dot = Paint()..color = c.withValues(alpha: 0.6);
    for (final o in [
      const Offset(14, 14),
      Offset(size.width - 14, 14),
      Offset(14, size.height - 14),
      Offset(size.width - 14, size.height - 14),
    ]) {
      canvas.drawCircle(o, 2, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _BackPainter old) => old.c != c;
}

/// Kartu yang masuk sebagai punggung, lalu berbalik menampilkan [front]
/// begitu [revealed] true.
///
/// Masuk: bila [dealOffset] diberikan, kartu dibagikan dari satu titik
/// tumpukan (offset = posisi tumpukan dikurangi posisi akhir kartu), melayang
/// sedikit sambil berputar, bergiliran menurut [index]. Tanpa [dealOffset],
/// kartu meluncur naik dari bawah seperti sebelumnya.
///
/// Berbalik: kartu terangkat, membesar sedikit, berpendar [glow], dengan getar
/// haptic ringan di titik tengah. Setelah mendarat, kilau menyapu mukanya.
/// [suspense] (biasanya kartu terakhir) menahan kartu lebih lama sambil
/// bergetar tegang sebelum berbalik, dengan pendar dan haptic lebih kuat.
///
/// [animate] hanya dibaca sekali (saat widget dibuat): false = langsung
/// tampil muka tanpa animasi, mis. ketika pemain kembali ke tab Pasar.
/// Setelah selesai, widget hanya mengembalikan [front] apa adanya, jadi
/// ketukan dan transformasi milik [front] tidak terganggu.
class FlipCard extends StatefulWidget {
  final int index;
  final double width;
  final double height;
  final bool revealed;
  final bool animate;
  final bool dark;
  final Color glow;
  final Widget front;
  final Offset? dealOffset;
  final bool suspense;
  final bool shine;

  const FlipCard({
    super.key,
    required this.index,
    required this.width,
    required this.height,
    required this.revealed,
    required this.front,
    this.animate = true,
    this.dark = false,
    this.glow = const Color(0xFFFFD866),
    this.dealOffset,
    this.suspense = false,
    this.shine = true,
  });

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard> with TickerProviderStateMixin {
  static const _suspenseMs = 520;

  late final AnimationController _in = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 560));
  late final AnimationController _flip = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800));
  late final AnimationController _shine = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _sus = AnimationController(
      vsync: this, duration: const Duration(milliseconds: _suspenseMs));
  late final bool _animate = widget.animate;
  Timer? _tIn;
  Timer? _tFlip;
  Timer? _tSus;
  bool _ticked = false;

  @override
  void initState() {
    super.initState();
    _flip.addListener(() {
      if (!_ticked && _flip.value >= 0.5) {
        _ticked = true;
        if (widget.suspense) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.lightImpact();
        }
      }
    });
    _flip.addStatusListener((st) {
      if (st == AnimationStatus.completed && _animate && widget.shine) {
        _shine.forward(from: 0);
      }
    });
    if (!_animate) {
      _ticked = true;
      _in.value = 1;
      if (widget.revealed) _flip.value = 1;
    } else {
      final step = widget.dealOffset != null ? 90 : 120;
      _tIn = Timer(Duration(milliseconds: step * widget.index), () {
        if (mounted) _in.forward();
      });
      if (widget.revealed) _scheduleFlip();
    }
  }

  void _scheduleFlip() {
    _tFlip?.cancel();
    _tSus?.cancel();
    final extra = widget.suspense ? 520 : 0;
    _tFlip = Timer(Duration(milliseconds: 650 + 380 * widget.index + extra), () {
      if (mounted) _flip.forward();
    });
    if (widget.suspense) {
      // Getar tegang tepat sebelum berbalik.
      _tSus = Timer(
          Duration(
              milliseconds: 650 + 380 * widget.index + extra - _suspenseMs),
              () {
            if (mounted) _sus.forward(from: 0);
          });
    }
  }

  @override
  void didUpdateWidget(covariant FlipCard old) {
    super.didUpdateWidget(old);
    if (!old.revealed && widget.revealed) {
      if (_animate) {
        _scheduleFlip();
      } else {
        _ticked = true;
        _flip.value = 1;
      }
    }
  }

  @override
  void dispose() {
    _tIn?.cancel();
    _tFlip?.cancel();
    _tSus?.cancel();
    _in.dispose();
    _flip.dispose();
    _shine.dispose();
    _sus.dispose();
    super.dispose();
  }

  /// Pita cahaya diagonal yang menyapu dari kiri ke kanan.
  Widget _shineOverlay(double t) {
    final e = Curves.easeInOut.transform(t);
    final fade = sin(t * pi).clamp(0.0, 1.0).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-1.6 + 3.2 * e, -1),
            end: Alignment(-0.6 + 3.2 * e, 1),
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.55 * fade),
              Colors.white.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: Listenable.merge([_in, _flip, _shine, _sus]),
        builder: (_, _) {
          if (_in.value >= 1 && _flip.value >= 1) {
            if (_shine.isAnimating) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  widget.front,
                  Positioned.fill(
                      child: IgnorePointer(child: _shineOverlay(_shine.value))),
                ],
              );
            }
            return widget.front;
          }

          final t = Curves.easeInOutCubic.transform(_flip.value);
          final ang = t * pi;
          final showFront = ang > pi / 2;
          final peak = sin(t * pi);
          final sus = _sus.value;
          final big = widget.suspense;

          // Masuk: dibagikan dari tumpukan, atau naik dari bawah.
          final Offset enterOff;
          final double enterRot;
          final double enterOpacity;
          final deal = widget.dealOffset;
          if (deal != null) {
            final e = Curves.easeOutCubic.transform(_in.value);
            enterOff = deal * (1 - e) + Offset(0, -sin(e * pi) * 22);
            enterRot = (1 - e) * (widget.index.isEven ? -0.35 : 0.35);
            enterOpacity = (_in.value * 4).clamp(0.0, 1.0).toDouble();
          } else {
            final e = Curves.easeOutBack.transform(_in.value);
            enterOff = Offset(0, (1 - e) * 46);
            enterRot = 0;
            enterOpacity = _in.value.clamp(0.0, 1.0).toDouble();
          }
          // Getar tegang (hanya kartu suspense).
          final shake = sin(sus * 46) * 0.035 * sus;

          final face = showFront
              ? Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(pi),
            child: widget.front,
          )
              : CardBackFace(width: widget.width, dark: widget.dark);

          final glowA = (0.75 * peak + 0.5 * sus).clamp(0.0, 1.0).toDouble();

          return Opacity(
            opacity: enterOpacity,
            child: Transform.translate(
              offset: enterOff + Offset(0, -peak * (big ? 22 : 16)),
              child: Transform.rotate(
                angle: enterRot + shake,
                child: Transform.scale(
                  scale: 1 + (big ? 0.16 : 0.10) * peak + 0.03 * sus,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      if (glowA > 0.02)
                        Container(
                          width: widget.width,
                          height: widget.height,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: widget.glow.withValues(alpha: glowA),
                                blurRadius:
                                12 + (big ? 48 : 34) * peak + 18 * sus,
                                spreadRadius: (big ? 4 : 2) * peak + 2 * sus,
                              ),
                            ],
                          ),
                        ),
                      AbsorbPointer(
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.0012)
                            ..rotateY(ang),
                          child: face,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}