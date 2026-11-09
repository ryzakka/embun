import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import '../table/flip_card.dart';

class PickOption {
  final String? facePath;
  final String label;
  const PickOption(this.facePath, this.label);
}

/// Pilihan karakter dan wajah gelap sama-sama memakai kartu tertutup.
/// Setelah pilihan terkunci, hanya kartu yang tidak diambil yang dibuka.
class CardPick extends StatefulWidget {
  final String title;
  final String hint;
  final List<PickOption> options;
  final bool dark;
  final String? note;
  final Future<String?> Function(int index) onPick;
  final VoidCallback onDone;
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
  int? _selected;
  int? _chosen;
  bool _busy = false;
  bool _labelsOn = false;
  String? _error;
  Timer? _done;
  Timer? _labels;

  Color get _accent => widget.dark ? EmbunColors.mist : EmbunColors.gold;
  bool get _locked => _chosen != null;

  @override
  void dispose() {
    _done?.cancel();
    _labels?.cancel();
    super.dispose();
  }

  void _select(int i) {
    if (_busy || _locked) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selected = i;
      _error = null;
    });
  }

  Future<void> _confirm() async {
    final i = _selected;
    if (i == null || _busy || _locked) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    String? error;
    try {
      error = await widget.onPick(i);
    } catch (e) {
      error = errMsg(e);
    }
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    HapticFeedback.heavyImpact();
    setState(() {
      _busy = false;
      _chosen = i;
    });
    _labels = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() => _labelsOn = true);
    });
    _done = Timer(const Duration(milliseconds: 3600), widget.onDone);
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xCB09140F),
          widget.dark ? const Color(0x4B1C0B2B) : const Color(0x5007130F),
          const Color(0xDD07130F),
        ],
      ),
    ),
    child: LayoutBuilder(
      builder: (context, box) {
        final short = box.maxHeight < 440;
        final split = box.maxWidth >= (short ? 530 : 700);
        final vertical = short ? 10.0 : 18.0;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: short ? 12 : 16,
            vertical: vertical,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 1100,
                minHeight: math.max(0, box.maxHeight - vertical * 2),
              ),
              child: split
                  ? Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _heading(),
                              const SizedBox(height: 14),
                              _actions(),
                            ],
                          ),
                        ),
                        SizedBox(width: short ? 12 : 26),
                        Expanded(flex: 3, child: _gallery(short: short)),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _heading(),
                        const SizedBox(height: 16),
                        _gallery(short: short),
                        const SizedBox(height: 16),
                        _actions(),
                      ],
                    ),
            ),
          ),
        );
      },
    ),
  );

  Widget _heading() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.dark ? 'PROLOG · WAJAH GELAP' : 'PROLOG · KARAKTER',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          color: _accent,
        ),
      ),
      const SizedBox(height: 5),
      Semantics(
        header: true,
        child: Text(
          widget.title,
          style: const TextStyle(
            fontSize: 26,
            height: 1.10,
            fontWeight: FontWeight.w900,
            color: EmbunColors.cream,
          ),
        ),
      ),
      const SizedBox(height: 7),
      Text(
        widget.hint,
        style: const TextStyle(
          fontSize: 13,
          height: 1.35,
          color: Colors.white70,
        ),
      ),
    ],
  );

  Widget _actions() {
    final selected = _selected;
    final error = _error ?? widget.note;
    final status = _locked
        ? 'Pilihan terkunci'
        : _busy
        ? 'Mengunci pilihan…'
        : selected == null
        ? 'Belum ada kartu dipilih'
        : 'Kartu ${selected + 1} dipilih';
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _accent.withValues(alpha: 0.32))),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  Icon(
                    _locked ? Icons.lock_rounded : Icons.style_outlined,
                    color: _locked ? EmbunColors.leaf : _accent,
                    size: 17,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      status,
                      style: TextStyle(
                        color: _locked ? EmbunColors.leaf : EmbunColors.cream,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            if (_locked)
              const Text(
                'Kartu lain dibuka. Sebentar lagi kamu lanjut.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              )
            else ...[
              if (error != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: const TextStyle(
                      fontSize: 13,
                      color: EmbunColors.blood,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
              ],
              EmbunButton(
                label: 'Kunci pilihan',
                height: 44,
                expand: true,
                onPressed: selected == null || _busy ? null : _confirm,
              ),
              if (error != null && widget.onSkip != null)
                TextButton(
                  onPressed: _busy ? null : widget.onSkip,
                  child: const Text('Lanjut tanpa memilih'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _gallery({required bool short}) {
    final back = cardBackPath(dark: widget.dark);
    return LayoutBuilder(
      builder: (context, box) {
        final count = widget.options.length;
        final gap = short ? 8.0 : 10.0;
        final width = math.min(
          short ? 112.0 : 192.0,
          math.max(0.0, (box.maxWidth - gap * (count - 1)) / count),
        );
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) SizedBox(width: gap),
              _cell(i, width, back),
            ],
          ],
        );
      },
    );
  }

  Widget _cell(int i, double width, String? back) {
    final option = widget.options[i];
    final chosen = _chosen == i;
    final active = _selected == i;
    final reveal = _locked && !chosen;
    final label = chosen
        ? 'Pilihanmu'
        : _labelsOn
        ? option.label
        : 'Kartu ${i + 1}';

    return Semantics(
      selected: active,
      button: !_busy && !_locked,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _busy || _locked ? null : () => _select(i),
          child: SizedBox(
            width: width,
            child: Column(
              children: [
                AnimatedOpacity(
                  opacity: !_locked && _selected != null && !active ? 0.70 : 1,
                  duration: const Duration(milliseconds: 160),
                  child: Stack(
                    children: [
                      FlipCard(
                        key: ValueKey('pick$i'),
                        index: reveal ? 0 : i,
                        width: width,
                        height: width * kTallAspect,
                        revealed: reveal,
                        dark: widget.dark,
                        backPath: back,
                        glow: _accent,
                        front: CardArt(
                          path: option.facePath,
                          width: width,
                          glow: widget.dark ? EmbunColors.mist : null,
                        ),
                      ),
                      if (active)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(color: _accent, width: 2),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: _accent.withValues(alpha: 0.30),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 7),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                      color: active ? _accent : Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
