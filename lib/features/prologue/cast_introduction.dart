import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/ornate.dart';

/// Uses only the public name and character card, including an antagonist's
/// public disguise. Never accepts secret roles, abilities or dark portraits.
class CastIntroduction extends StatefulWidget {
  const CastIntroduction({
    super.key,
    required this.players,
    required this.myId,
    required this.onContinue,
    this.waiting = false,
  });

  final List<Map<String, dynamic>> players;
  final String? myId;
  final VoidCallback onContinue;
  final bool waiting;

  @override
  State<CastIntroduction> createState() => _CastIntroductionState();
}

class _CastIntroductionState extends State<CastIntroduction> {
  Timer? _timer;
  bool _continued = false;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(CastIntroduction oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    if (widget.waiting || widget.players.isEmpty) {
      _timer?.cancel();
      _timer = null;
    } else if (!_continued && _timer == null && widget.players.isNotEmpty) {
      _timer = Timer(const Duration(seconds: 8), _continue);
    }
  }

  void _continue() {
    if (!mounted || _continued || widget.waiting || widget.players.isEmpty) {
      return;
    }
    setState(() => _continued = true);
    _timer?.cancel();
    widget.onContinue();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waiting = widget.waiting || _continued;
    return ColoredBox(
      color: const Color(0x8806100C),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1060),
            child: LayoutBuilder(
              builder: (context, box) {
                final compact = box.maxWidth < 600;
                final pad = compact ? 16.0 : 28.0;
                return Column(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: math.max(64, box.maxHeight * .30),
                      ),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(pad, 16, pad, 10),
                          child: Row(
                            children: [
                              const GameIcon('addmember', size: 32),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'PARA PEMERAN',
                                      style: TextStyle(
                                        color: EmbunColors.gold,
                                        fontSize: 11,
                                        letterSpacing: 2,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      'Kisah Hayu bersama kalian',
                                      style: TextStyle(
                                        color: EmbunColors.cream,
                                        fontSize: compact ? 21 : 29,
                                        height: 1.15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: widget.players.isEmpty
                          ? const Center(
                              child: Text(
                                'Menyiapkan daftar pemeran…',
                                style: TextStyle(color: EmbunColors.cream),
                              ),
                            )
                          : SingleChildScrollView(
                              key: const ValueKey('cast-scroll'),
                              padding: EdgeInsets.fromLTRB(pad, 12, pad, 20),
                              child: LayoutBuilder(
                                builder: (context, space) {
                                  final columns = space.maxWidth < 440
                                      ? 2
                                      : space.maxWidth < 700
                                      ? 3
                                      : 4;
                                  final width =
                                      (space.maxWidth - 12 * (columns - 1)) /
                                      columns;
                                  return Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 12,
                                    runSpacing: 16,
                                    children: [
                                      for (
                                        var i = 0;
                                        i < widget.players.length;
                                        i++
                                      )
                                        _CastMember(
                                          key: ValueKey(
                                            widget.players[i]['user_id'] ?? i,
                                          ),
                                          player: widget.players[i],
                                          isMe:
                                              widget.myId != null &&
                                              widget.players[i]['user_id'] ==
                                                  widget.myId,
                                          width: width,
                                          order: i,
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                    ),
                    // This area can scroll too on short screens / large text.
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: math.max(48, box.maxHeight * .32),
                      ),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(pad, 8, pad, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                waiting
                                    ? 'Menunggu pemain lain. Meja akan dibuka bersama.'
                                    : 'Kenali nama dan karakter teman bermainmu.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            if (!waiting && widget.players.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              EmbunButton(
                                label: 'Lanjut',
                                icon: 'lock',
                                expand: true,
                                onPressed: _continue,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CastMember extends StatelessWidget {
  const _CastMember({
    super.key,
    required this.player,
    required this.isMe,
    required this.width,
    required this.order,
  });

  final Map<String, dynamic> player;
  final bool isMe;
  final double width;
  final int order;

  @override
  Widget build(BuildContext context) {
    final name = (player['name'] as String?)?.trim();
    final stem = (player['character_card'] as String?) ?? 'default';
    final label = name == null || name.isEmpty ? 'Pemain' : name;
    final title = stem == 'default' ? 'Karakter desa' : characterTitle(stem);
    final artWidth = math.min(132.0, math.max(56.0, width - 24));
    final body = Semantics(
      label: '$label sebagai $title${isMe ? ', kamu' : ''}',
      excludeSemantics: true,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xCC102A20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMe ? EmbunColors.gold : const Color(0x66577954),
          ),
        ),
        child: Column(
          children: [
            CardArt(
              path: protagonistPath(stem),
              width: artWidth,
              glow: isMe ? EmbunColors.goldDim : null,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: EmbunColors.cream,
                fontSize: 16,
                height: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              isMe ? 'KAMU · SEBAGAI' : 'SEBAGAI',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 9,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: EmbunColors.gold,
                fontSize: 14,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) return body;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + order * 65),
      child: body,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - t)),
          child: child,
        ),
      ),
    );
  }
}
