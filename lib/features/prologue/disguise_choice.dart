import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/ornate.dart';

/// Layar pilih wajah samaran untuk Si Terbisik: tiga kartu karakter, pilih
/// satu. Kartu inilah yang dilihat semua pemain di meja.
///
/// [onPick] mengembalikan null bila berhasil (induk lalu berpindah layar),
/// atau pesan galat. Setelah galat, muncul tombol "Lanjut tanpa mengganti"
/// supaya pemain tidak terjebak (mis. waktu memilih sudah habis).
class DisguiseChoice extends StatefulWidget {
  final List<String> options;
  final Future<String?> Function(String stem) onPick;
  final VoidCallback onSkip;

  const DisguiseChoice({
    super.key,
    required this.options,
    required this.onPick,
    required this.onSkip,
  });

  @override
  State<DisguiseChoice> createState() => _DisguiseChoiceState();
}

class _DisguiseChoiceState extends State<DisguiseChoice> {
  String? _sel;
  bool _busy = false;
  String? _error;

  Future<void> _confirm() async {
    final s = _sel;
    if (s == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await widget.onPick(s);
    if (!mounted) return; // sukses: induk sudah berpindah layar
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Pilih Wajah Samaranmu',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: EmbunColors.mist,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Wajah inilah yang dilihat semua pemain di meja. Pilih satu; '
                    'setelah dipilih tidak bisa diganti. Hanya kamu yang tahu '
                    'ada pilihan ini.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12.5, height: 1.4, color: Colors.white60),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, c) {
                const gap = 10.0;
                final n = widget.options.length;
                final w = ((c.maxWidth - gap * (n - 1)) / n)
                    .clamp(80.0, 150.0)
                    .toDouble();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < n; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      _option(widget.options[i], w),
                    ],
                  ],
                );
              }),
              const SizedBox(height: 18),
              if (_error != null) ...[
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12.5, color: EmbunColors.blood)),
                const SizedBox(height: 10),
              ],
              EmbunButton(
                label: _sel == null ? 'Pilih satu kartu' : 'Pakai wajah ini',
                icon: 'centang',
                expand: true,
                onPressed: (_sel == null || _busy) ? null : _confirm,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                EmbunButton(
                  label: 'Lanjut tanpa mengganti',
                  kind: EmbunButtonKind.secondary,
                  expand: true,
                  height: 46,
                  onPressed: _busy ? null : widget.onSkip,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _option(String stem, double w) {
    final on = _sel == stem;
    return GestureDetector(
      onTap: _busy
          ? null
          : () {
        HapticFeedback.selectionClick();
        setState(() => _sel = stem);
      },
      child: SizedBox(
        width: w,
        child: Column(
          children: [
            AnimatedScale(
              scale: on ? 1.06 : 1.0,
              duration: const Duration(milliseconds: 160),
              child: AnimatedOpacity(
                opacity: (_sel == null || on) ? 1 : 0.55,
                duration: const Duration(milliseconds: 160),
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: on ? EmbunColors.gold : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: CardArt(
                    path: protagonistPath(stem),
                    width: w,
                    glow: on ? EmbunColors.gold : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              characterTitle(stem),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: on ? FontWeight.bold : FontWeight.normal,
                color: on ? EmbunColors.gold : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}