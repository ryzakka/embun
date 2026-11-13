import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/ornate.dart';

/// Uses only the public name and character card, including an antagonist's
/// public disguise. Never accepts secret roles, abilities or dark portraits.
///
/// Urutan tampil: pemeran diungkap SATU DEMI SATU di bawah sorot lampu (kamu
/// terakhir), lalu seluruh daftar muncul sebagai penutup dan otomatis lanjut.
/// Ketuk layar untuk mempercepat, atau "Lewati" untuk langsung ke daftar.
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
  bool _finale = false; // true = tampilkan daftar lengkap
  int _index = 0; // pemeran yang sedang disorot
  bool _reduced = false;

  /// Pemain lain lebih dulu, kamu diungkap paling akhir.
  List<Map<String, dynamic>> get _cast {
    final others = <Map<String, dynamic>>[];
    final mine = <Map<String, dynamic>>[];
    for (final p in widget.players) {
      (widget.myId != null && p['user_id'] == widget.myId ? mine : others).add(
        p,
      );
    }
    return [...others, ...mine];
  }

  bool get _staging =>
      !_finale &&
          !_continued &&
          !widget.waiting &&
          widget.players.isNotEmpty;

  Duration get _dwell => Duration(
    milliseconds: _reduced
        ? 900
        : (_index >= _cast.length - 1 ? 2800 : 2200),
  );

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(CastIntroduction oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    if (widget.waiting || _continued || widget.players.isEmpty) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_timer != null) return;
    _timer = _finale
        ? Timer(const Duration(seconds: 7), _continue)
        : Timer(_dwell, _advance);
  }

  void _advance() {
    _timer = null;
    if (!mounted || _finale || _continued) return;
    setState(() {
      if (_index < _cast.length - 1) {
        _index++;
      } else {
        _finale = true;
      }
    });
    _schedule();
  }

  void _next() {
    _timer?.cancel();
    _timer = null;
    _advance();
  }

  void _skip() {
    _timer?.cancel();
    _timer = null;
    setState(() => _finale = true);
    _schedule();
  }

  void _continue() {
    if (!mounted || _continued || widget.waiting || widget.players.isEmpty) {
      return;
    }
    setState(() => _continued = true);
    _timer?.cancel();
    _timer = null;
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
    final staging = _staging;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      color: staging ? const Color(0xE606100C) : const Color(0x8806100C),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1060),
            child: LayoutBuilder(
              builder: (context, box) {
                final compact = box.maxWidth < 600;
                final pad = compact ? 16.0 : 28.0;
                return AnimatedSwitcher(
                  duration: Duration(milliseconds: _reduced ? 0 : 500),
                  child: staging
                      ? _stage(compact, pad)
                      : _roster(box, compact, pad, waiting),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Babak 1: satu demi satu di bawah sorot lampu
  // -------------------------------------------------------------------------
  Widget _stage(bool compact, double pad) {
    final cast = _cast;
    final idx = math.min(_index, cast.length - 1);
    final player = cast[idx];
    final isMe = widget.myId != null && player['user_id'] == widget.myId;
    return Column(
      key: const ValueKey('stage'),
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 14, pad, 0),
          child: Row(
            children: [
              const GameIcon('addmember', size: 24),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'PARA PEMERAN',
                  style: TextStyle(
                    color: EmbunColors.gold,
                    fontSize: 11,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${(idx + 1).toString().padLeft(2, '0')} / ${cast.length.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: EmbunColors.gold,
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Semantics(
            button: true,
            label: 'Lanjut ke pemeran berikutnya',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _next,
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: _reduced ? 0 : 350),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: _Spotlight(
                  key: ValueKey('spot-$idx-${player['user_id']}'),
                  player: player,
                  isMe: isMe,
                  reduced: _reduced,
                ),
              ),
            ),
          ),
        ),
        _lineup(cast, idx, pad),
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 2, pad, 10),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Ketuk layar untuk lanjut',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
              TextButton(
                onPressed: _skip,
                child: const Text(
                  'Lewati pengenalan',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Barisan siluet: yang sudah diungkap menampakkan wajah, sisanya "?".
  Widget _lineup(List<Map<String, dynamic>> cast, int idx, double pad) =>
      SizedBox(
        height: 66,
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: pad),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: math.max(0.0, c.maxWidth - pad * 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < cast.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      child: _LineupSlot(
                        player: cast[i],
                        revealed: i <= idx,
                        current: i == idx,
                        isMe:
                        widget.myId != null &&
                            cast[i]['user_id'] == widget.myId,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );

  // -------------------------------------------------------------------------
  // Babak 2: seluruh daftar (penutup), lalu lanjut otomatis
  // -------------------------------------------------------------------------
  Widget _roster(BoxConstraints box, bool compact, double pad, bool waiting) =>
      Column(
        key: const ValueKey('roster'),
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
                      (space.maxWidth - 12 * (columns - 1)) / columns;
                  return Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 16,
                    children: [
                      for (var i = 0; i < widget.players.length; i++)
                        _CastMember(
                          key: ValueKey(widget.players[i]['user_id'] ?? i),
                          player: widget.players[i],
                          isMe:
                          widget.myId != null &&
                              widget.players[i]['user_id'] == widget.myId,
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
}

// ===========================================================================
// Sorotan satu pemeran
// ===========================================================================

/// Satu pemeran muncul di bawah kerucut lampu: kilatan, kartu naik dengan
/// pendar, lalu nama (menajam dari kabur), "SEBAGAI", dan gelar karakter.
class _Spotlight extends StatelessWidget {
  const _Spotlight({
    super.key,
    required this.player,
    required this.isMe,
    required this.reduced,
  });

  final Map<String, dynamic> player;
  final bool isMe, reduced;

  @override
  Widget build(BuildContext context) {
    final name = (player['name'] as String?)?.trim();
    final stem = (player['character_card'] as String?) ?? 'default';
    final label = name == null || name.isEmpty ? 'Pemain' : name;
    final title = stem == 'default' ? 'Karakter desa' : characterTitle(stem);
    final tint = isMe ? EmbunColors.gold : EmbunColors.mist;
    return Semantics(
      liveRegion: true,
      label: '$label sebagai $title${isMe ? ', kamu' : ''}',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduced ? 1.0 : 0.0, end: 1.0),
        duration: const Duration(milliseconds: 1500),
        builder: (context, t, _) => LayoutBuilder(
          builder: (context, box) {
            double seg(double s, double e, [Curve c = Curves.easeOutCubic]) =>
                c.transform(((t - s) / (e - s)).clamp(0.0, 1.0));
            final wide =
                box.maxWidth >= 700 && box.maxWidth > box.maxHeight * 1.15;
            final artW = math.max(
              90.0,
              wide
                  ? math.min(
                math.min(box.maxWidth * .3, box.maxHeight * .62),
                340.0,
              )
                  : math.min(
                math.min(box.maxWidth * .6, (box.maxHeight - 170) * .66),
                300.0,
              ),
            );
            final nameBlur = 8 * (1 - seg(.3, .75));
            final nameStyle = TextStyle(
              color: EmbunColors.cream,
              fontSize: wide ? 52 : 34,
              height: 1.05,
              fontWeight: FontWeight.w900,
              shadows: const [Shadow(color: Colors.black87, blurRadius: 14)],
            );
            Widget nameText = Text(
              label,
              textAlign: wide ? TextAlign.left : TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: nameStyle,
            );
            if (nameBlur > .2) {
              nameText = ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: nameBlur,
                  sigmaY: nameBlur,
                  tileMode: TileMode.decal,
                ),
                child: nameText,
              );
            }
            final maxText = wide ? box.maxWidth * .46 : box.maxWidth - 32;
            final art = Opacity(
              opacity: seg(0, .35),
              child: Transform.translate(
                offset: Offset(0, 40 * (1 - seg(0, .55))),
                child: Transform.scale(
                  scale: .86 + .14 * seg(0, .6, Curves.easeOutBack),
                  child: CardArt(
                    path: protagonistPath(stem),
                    width: artW,
                    glow: tint,
                  ),
                ),
              ),
            );
            final texts = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: wide
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                if (isMe) ...[
                  Opacity(
                    opacity: seg(.3, .6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: EmbunColors.gold),
                        color: EmbunColors.gold.withValues(alpha: .14),
                      ),
                      child: const Text(
                        'KAMU',
                        style: TextStyle(
                          color: EmbunColors.gold,
                          fontSize: 11,
                          letterSpacing: 2.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Opacity(
                  opacity: seg(.3, .65),
                  child: Transform.translate(
                    offset: Offset(
                      wide ? -26 * (1 - seg(.3, .75)) : 0,
                      wide ? 0 : 16 * (1 - seg(.3, .75)),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxText),
                      child: nameText,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Opacity(
                  opacity: seg(.5, .75),
                  child: const Text(
                    'SEBAGAI',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Opacity(
                  opacity: seg(.6, .9),
                  child: Transform.translate(
                    offset: Offset(0, 12 * (1 - seg(.6, .95))),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxText),
                      child: Text(
                        title,
                        textAlign: wide ? TextAlign.left : TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: EmbunColors.gold,
                          fontSize: wide ? 30 : 22,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          shadows: const [
                            Shadow(color: Colors.black87, blurRadius: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
            return Stack(
              fit: StackFit.expand,
              children: [
                IgnorePointer(
                  child: CustomPaint(painter: _BeamPainter(t, tint, wide)),
                ),
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: wide
                        ? Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [art, const SizedBox(width: 40), texts],
                    )
                        : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [art, const SizedBox(height: 22), texts],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Kerucut lampu dari atas, pendar di belakang kartu, kilatan saat muncul, dan
/// debu cahaya yang naik lalu menghilang.
class _BeamPainter extends CustomPainter {
  const _BeamPainter(this.t, this.tint, this.wide);
  final double t;
  final Color tint;
  final bool wide;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w * (wide ? .38 : .5);
    final cy = h * .44;
    final reveal = Curves.easeOut.transform((t / .4).clamp(0.0, 1.0));

    canvas.drawPath(
      Path()
        ..moveTo(cx - w * .05, 0)
        ..lineTo(cx + w * .05, 0)
        ..lineTo(cx + w * (.18 + .26 * reveal), h)
        ..lineTo(cx - w * (.18 + .26 * reveal), h)
        ..close(),
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), [
          tint.withValues(alpha: .30 * reveal),
          tint.withValues(alpha: 0),
        ]),
    );

    final glowR = math.min(w, h) * .55;
    canvas.drawCircle(
      Offset(cx, cy),
      glowR,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(Offset(cx, cy), glowR, [
          tint.withValues(alpha: .24 * reveal),
          tint.withValues(alpha: 0),
        ]),
    );

    if (t < .3) {
      final f = 1 - t / .3;
      final r = math.max(w, h) * (.3 + .5 * (t / .3));
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.radial(Offset(cx, cy), r, [
            Color.lerp(tint, Colors.white, .6)!.withValues(alpha: .34 * f),
            tint.withValues(alpha: 0),
          ]),
      );
    }

    final fade = 1 - ((t - .7) / .3).clamp(0.0, 1.0);
    if (fade > 0) {
      for (var i = 0; i < 16; i++) {
        final life = (t * .8 + i / 16) % 1.0;
        final a = i * 2.399;
        final x = cx + math.sin(a) * w * .26 * (.4 + (i % 4) / 4);
        final y = h * (1.02 - life * .85);
        canvas.drawCircle(
          Offset(x, y),
          1.2 + (i % 3) * .7,
          Paint()
            ..color = tint.withValues(
              alpha: math.sin(life * math.pi) * .55 * fade,
            ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BeamPainter old) =>
      old.t != t || old.tint != tint || old.wide != wide;
}

/// Satu slot di barisan bawah: "?" sebelum diungkap, potret sesudahnya.
class _LineupSlot extends StatelessWidget {
  const _LineupSlot({
    required this.player,
    required this.revealed,
    required this.current,
    required this.isMe,
  });

  final Map<String, dynamic> player;
  final bool revealed, current, isMe;

  @override
  Widget build(BuildContext context) {
    final stem = (player['character_card'] as String?) ?? 'default';
    final gold = current || (revealed && isMe);
    return AnimatedScale(
      scale: current ? 1.14 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        width: 34,
        height: 50,
        decoration: BoxDecoration(
          color: revealed ? const Color(0xCC102A20) : const Color(0x88000000),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: gold ? EmbunColors.gold : const Color(0x55577954),
            width: current ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: revealed
              ? GameImage(
            path: protagonistPath(stem),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          )
              : const Center(
            child: Text(
              '?',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
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