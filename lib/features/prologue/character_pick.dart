import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import '../table/flip_card.dart';

/// Satu pilihan kartu: muka kartu (disembunyikan sampai dibuka) dan namanya.
class PickOption {
  final String? facePath;
  final String label;
  const PickOption(this.facePath, this.label);
}

/// Pilih satu dari beberapa kartu TERBALIK (punggung). Dipakai dua kali di
/// prolog: kartu karakter baik (semua pemain) dan wajah gelap (Si Terbisik).
///
/// Alur:
///  1. kartu dibagikan sebagai punggung; pemain mengetuk satu lalu menekan
///     tombol Ambil. Muka kartu TIDAK terlihat selama memilih.
///  2. [onPick] dipanggil. Bila mengembalikan teks, itu pesan galat (kartu
///     tetap tertutup, pemain boleh memilih lagi / lanjut tanpa memilih).
///  3. Bila berhasil: kartu yang dipilih tetap tertutup, dua kartu lain
///     berbalik memperlihatkan wajahnya, lalu [onDone] dipanggil.
class CardPick extends StatefulWidget {
  final String title;
  final String hint;
  final List<PickOption> options;
  final bool dark;

  /// Pesan dari percobaan sebelumnya (mis. kartu sudah diambil pemain lain).
  final String? note;
  final Future<String?> Function(int index) onPick;
  final VoidCallback onDone;

  /// Tombol "Lanjut tanpa memilih"; hanya tampil setelah ada galat.
  final VoidCallback? onSkip;

  const CardPick({
    super.key,
    required this.title,
    required this.hint,
    required this.options,
    required this.onPick,
    required this.onDone,
    this.dark = false,
    this.note,
    this.onSkip,
  });

  @override
  State<CardPick> createState() => _CardPickState();
}

class _CardPickState extends State<CardPick> {
  int? _sel;
  int? _chosen;
  bool _busy = false;
  bool _flipOthers = false;
  bool _labelsOn = false;
  String? _error;
  Timer? _done;
  Timer? _labels;

  Color get _accent => widget.dark ? EmbunColors.mist : EmbunColors.gold;

  @override
  void dispose() {
    _done?.cancel();
    _labels?.cancel();
    super.dispose();
  }

  void _select(int i) {
    if (_busy || _chosen != null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _sel = i;
      _error = null;
    });
  }

  Future<void> _confirm() async {
    final i = _sel;
    if (i == null || _busy || _chosen != null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await widget.onPick(i);
    if (!mounted) return; // induk mengganti widget ini (pilihan dikocok ulang)
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    HapticFeedback.heavyImpact();
    setState(() {
      _busy = false;
      _chosen = i;
      _flipOthers = true;
    });
    // Nama kartu lain baru muncul setelah kartunya berbalik.
    _labels = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() => _labelsOn = true);
    });
    _done = Timer(const Duration(milliseconds: 3600), widget.onDone);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.options.length;
    final back = cardBackPath(dark: widget.dark);
    final picked = _chosen != null;
    final err = _error ?? widget.note;

    return LayoutBuilder(builder: (context, c) {
      const gap = 12.0;
      var w = (c.maxWidth - 40 - gap * (n - 1)) / n;
      if (c.maxHeight.isFinite) {
        final byH = (c.maxHeight - 240) / kTallAspect;
        if (byH < w) w = byH;
      }
      w = w.clamp(64.0, 150.0).toDouble().floorToDouble();
      final h = w * kTallAspect;

      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                    color: _accent,
                    shadows: [
                      Shadow(
                          color: _accent.withValues(alpha: 0.5),
                          blurRadius: 14),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    picked
                        ? (widget.dark
                        ? 'Wajah gelapmu terpilih. Dua wajah lain yang '
                        'tak kamu ambil kini terbuka...'
                        : 'Kartumu terambil. Dua kartu lain yang tak '
                        'kamu ambil kini terbuka...')
                        : widget.hint,
                    key: ValueKey(picked),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12.5, height: 1.4, color: Colors.white60),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < n; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      _cell(i, w, h, back),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                if (err != null && !picked) ...[
                  Text(err,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12.5, color: EmbunColors.blood)),
                  const SizedBox(height: 10),
                ],
                if (!picked)
                  EmbunButton(
                    label: _sel == null ? 'Pilih satu kartu' : 'Ambil kartu ini',
                    icon: 'centang',
                    expand: true,
                    onPressed: (_sel == null || _busy) ? null : _confirm,
                  ),
                if (err != null && !picked && widget.onSkip != null) ...[
                  const SizedBox(height: 8),
                  EmbunButton(
                    label: 'Lanjut tanpa memilih',
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
    });
  }

  Widget _cell(int i, double w, double h, String? back) {
    final o = widget.options[i];
    final isChosen = _chosen == i;
    final sel = _sel == i && _chosen == null;
    final reveal = _flipOthers && !isChosen;
    final dimmed = _chosen == null && _sel != null && !sel;
    final accent = _accent;

    final String label = isChosen ? 'Pilihanmu' : (_labelsOn ? o.label : '');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _select(i),
      child: SizedBox(
        width: w,
        child: Column(
          children: [
            AnimatedScale(
              scale: (sel || isChosen) ? 1.07 : 1.0,
              duration: const Duration(milliseconds: 180),
              child: AnimatedOpacity(
                opacity: dimmed ? 0.6 : 1,
                duration: const Duration(milliseconds: 180),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    FlipCard(
                      key: ValueKey('pick$i'),
                      // Kartu yang terbuka berbalik bersamaan (indeks 0).
                      index: reveal ? 0 : i,
                      width: w,
                      height: h,
                      revealed: reveal,
                      dark: widget.dark,
                      backPath: back,
                      glow: accent,
                      front: CardArt(
                          path: o.facePath,
                          width: w,
                          glow: widget.dark ? EmbunColors.mist : null),
                    ),
                    if (sel || isChosen)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: accent, width: 3),
                              boxShadow: [
                                BoxShadow(
                                    color: accent.withValues(alpha: 0.55),
                                    blurRadius: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: AnimatedOpacity(
                opacity: label.isEmpty ? 0 : 1,
                duration: const Duration(milliseconds: 500),
                child: Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.2,
                    fontWeight: isChosen ? FontWeight.bold : FontWeight.normal,
                    color: isChosen ? accent : Colors.white70,
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