import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'card_tile.dart';

/// Validasi masuk mendahului animasi. Layanan tetap menghabiskan surat saat
/// perawatan/jebakan dikonfirmasi, sesuai transaksi server yang sudah ada.
class ClinicEntryScene extends StatefulWidget {
  const ClinicEntryScene({
    super.key,
    required this.letter,
    required this.onSubmit,
    required this.onEntered,
    required this.onCancel,
    this.dark = false,
  });
  final Map<String, dynamic> letter;
  final Future<Map<String, dynamic>> Function() onSubmit;
  final void Function(Map<String, dynamic>) onEntered;
  final VoidCallback onCancel;
  final bool dark;
  @override
  State<ClinicEntryScene> createState() => _ClinicEntrySceneState();
}

class _ClinicEntrySceneState extends State<ClinicEntryScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _accepted;
  @override
  void initState() {
    super.initState();
    _animation.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted && _accepted != null) {
        widget.onEntered(_accepted!);
      }
    });
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await widget.onSubmit();
      if (!mounted) return;
      _accepted = result;
      final reduced = MediaQuery.disableAnimationsOf(context);
      _animation.duration = Duration(milliseconds: reduced ? 250 : 1700);
      _animation.forward();
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = errMsg(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    color: EmbunColors.bg,
    child: Stack(
      fit: StackFit.expand,
      children: [
        GameImage(
          path: firstScenery(const [
            'tempat-pondokperawatan',
            'sumur-sianghari',
          ]),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x6607130F), Color(0x1107130F), Color(0xF007130F)],
            ),
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final short = box.maxHeight < 460;
              final wide = box.maxWidth > 760 || (short && box.maxWidth > 560);
              final cardW = math.min(
                short ? 115.0 : 190.0,
                box.maxHeight * .28,
              );
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Batalkan masuk pondok',
                          onPressed: _submitting ? null : widget.onCancel,
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const Expanded(
                          child: Text(
                            'PONDOK PERAWATAN',
                            style: TextStyle(
                              fontSize: 12,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, _) {
                        final t = Curves.easeInOutCubic.transform(
                          _animation.value,
                        );
                        return Stack(
                          fit: StackFit.expand,
                          alignment: Alignment.center,
                          children: [
                            Align(
                              alignment: Alignment(
                                wide ? -.65 : 0,
                                short ? -.6 : -.85,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _animation.value > .5
                                          ? 'Surat diterima'
                                          : 'Serahkan suratmu',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: short ? 22 : 32,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    if (!short)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 8),
                                        child: Text(
                                          'Sebelum pintu pondok terbuka',
                                          style: TextStyle(
                                            color: EmbunColors.cream,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _LetterTrail(
                                    _animation.value,
                                    widget.dark,
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment(wide ? .48 : 0, .25),
                              child: Transform.translate(
                                offset: Offset(
                                  (wide ? -box.maxWidth * .18 : 0) * t,
                                  -box.maxHeight * .22 * t,
                                ),
                                child: Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, .001)
                                    ..rotateZ(-.1 * t)
                                    ..rotateX(.45 * t)
                                    ..scaleByDouble(
                                      1 - .75 * t,
                                      1 - .75 * t,
                                      1,
                                      1,
                                    ),
                                  child: Opacity(
                                    opacity: (1 - (t - .6).clamp(0.0, .4) / .4)
                                        .clamp(0.0, 1.0),
                                    child: CardTile(
                                      def: widget.letter,
                                      fallbackName:
                                          widget.letter['name'] as String? ??
                                          'Surat',
                                      width: cardW,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: EmbunColors.blood,
                                ),
                              ),
                            ),
                          FilledButton(
                            onPressed: _submitting ? null : _submit,
                            child: Text(
                              _submitting
                                  ? 'Membuka pintu…'
                                  : 'Serahkan ${widget.dark ? 'Surat Sakit' : 'Surat Dokter'}',
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Surat digunakan saat layanan dikonfirmasi.',
                            textAlign: TextAlign.center,
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
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _LetterTrail extends CustomPainter {
  const _LetterTrail(this.progress, this.dark);
  final double progress;
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= .1 || progress >= .98) return;
    final p = ((progress - .1) / .88).clamp(0.0, 1.0),
        center = Offset(size.width * .5, size.height * .35);
    final paint = Paint()
      ..color = (dark ? EmbunColors.mist : EmbunColors.gold).withValues(
        alpha: math.sin(p * math.pi) * .7,
      )
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, 16 + 46 * p, paint);
    for (var i = 0; i < 18; i++) {
      final a = i * 2.399 + progress * .6, r = 20 + 90 * p * (.4 + (i % 4) / 4);
      canvas.drawCircle(
        center + Offset(math.cos(a) * r, math.sin(a) * r),
        1.5 + (i % 3),
        Paint()..color = paint.color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LetterTrail oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.dark != dark;
}
