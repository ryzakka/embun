import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import '../common/sfx.dart';
import '../common/scene_flow.dart';
import 'countdown.dart';

/// Layar "malam tiba" selama fase 'night' (hari biasa sudah berakhir, malam
/// belum dijalankan). Semua pemain melihat latar dan teks yang sama.
///
/// Si Terbisik, bila memegang kartu serangan malam, melihat dua pilihan:
/// pakai kartu, atau lanjut ke hari berikutnya. Tanpa kartu, malam
/// dilanjutkan sendiri setelah beberapa detik (waktu tampil pemain lain tak
/// banyak berbeda). Bila tenggat server habis, malam jalan otomatis.
class NightChoice extends StatefulWidget {
  final bool isAntag;

  /// Si Terbisik memegang setidaknya satu kartu jenis 'malam'.
  final bool hasCards;
  final DateTime? deadline;

  /// Sedang memproses (mis. memanggil server): tombol dinonaktifkan.
  final bool busy;
  final VoidCallback onUseCard;
  final VoidCallback onContinue;

  const NightChoice({
    super.key,
    required this.isAntag,
    required this.hasCards,
    required this.deadline,
    required this.busy,
    required this.onUseCard,
    required this.onContinue,
  });

  @override
  State<NightChoice> createState() => _NightChoiceState();
}

class _NightChoiceState extends State<NightChoice> {
  static const _noCardDelay = Duration(seconds: 4);
  Timer? _auto;

  @override
  void initState() {
    super.initState();
    Sfx.I.playAny(Snd.winds, owner: this, tag: 'wind');
    if (widget.isAntag) {
      // Tangan kartu baru dimuat ulang saat fase berganti; nilainya dibaca
      // saat timer berbunyi, bukan sekarang.
      _auto = Timer(_noCardDelay, () {
        if (mounted && !widget.hasCards && !widget.busy) widget.onContinue();
      });
    }
  }

  @override
  void dispose() {
    _auto?.cancel();
    Sfx.I.release(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sky = nightSkyPath(attack: false);
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: kSceneInk),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: kSceneFadeInMs),
          builder: (_, v, child) => Opacity(opacity: v, child: child),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Backdrop(path: sky, dark: true, dim: 0.35),
              SafeArea(child: _content()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _content() {
    final showChoice = widget.isAntag && widget.hasCards;
    return Stack(
      children: [
        Positioned(
          top: 10,
          right: 12,
          child: showChoice
              ? Countdown(deadline: widget.deadline)
              : const SizedBox.shrink(),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.nightlight_round,
                size: 72,
                color: EmbunColors.mist,
                shadows: [
                  Shadow(
                      color: EmbunColors.mist.withValues(alpha: 0.7),
                      blurRadius: 28),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Malam tiba...',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        if (showChoice)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: OrnatePanel(
                  accent: EmbunColors.mist,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Kabut menunggu perintahmu. Lancarkan serangan malam, '
                            'atau biarkan malam berlalu.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      EmbunButton(
                        label: 'Gunakan kartu malam',
                        icon: 'show',
                        expand: true,
                        onPressed: widget.busy ? null : widget.onUseCard,
                      ),
                      const SizedBox(height: 8),
                      EmbunButton(
                        label: 'Lanjut ke hari berikutnya',
                        kind: EmbunButtonKind.secondary,
                        expand: true,
                        height: 46,
                        onPressed: widget.busy ? null : widget.onContinue,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}