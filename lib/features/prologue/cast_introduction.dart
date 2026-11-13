import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/ornate.dart';

/// Uses only the public name and character card, including an antagonist's
/// public disguise. Never accepts secret roles, abilities or dark portraits.
///
/// Urutan tampil: pemeran diungkap SATU DEMI SATU di bawah sorot lampu (kamu
/// terakhir), lalu seluruh daftar muncul sebagai penutup dan otomatis lanjut.
/// Ketuk layar untuk mempercepat, atau "Lewati" untuk langsung ke daftar.
///
/// Sentuhan sinematik: vinyet gelap, sorot silang, kartu miring 3D yang
/// "mendarat" di atas genangan cahaya, kilau berkala, nomor hantu raksasa,
/// ornamen berlian, judul berkilau emas, bar progres per-pemeran, getaran
/// haptic, dan hitung mundur tipis di babak penutup.
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
        : (_index >= _cast.length - 1 ? 3000 : 2400),
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
        ? Timer(_finaleDuration, _continue)
        : Timer(_dwell, _advance);
  }

  static const _finaleDuration = Duration(seconds: 7);

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
      color: staging ? const Color(0xF2040B08) : const Color(0x8806100C),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Vinyet: tepi layar menggelap, perhatian tertarik ke tengah.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: staging ? 1 : 0,
                duration: const Duration(milliseconds: 600),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 1.05,
                      colors: [Color(0x00000000), Color(0xCC000000)],
                      stops: [.45, 1],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1060),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final compact = box.maxWidth < 600;
                    final pad = compact ? 16.0 : 28.0;
                    return AnimatedSwitcher(
                      duration: Duration(milliseconds: _reduced ? 0 : 600),
                      child: staging
                          ? _stage(compact, pad)
                          : _roster(box, compact, pad, waiting),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
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
                    letterSpacing: 4,
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
        _progress(cast.length, idx, pad),
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
                  index: idx,
                  total: cast.length,
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

  /// Bar progres bersegmen: satu segmen per pemeran. Segmen aktif terisi
  /// selama durasi sorotnya, jadi terasa "napas" pertunjukan.
  Widget _progress(int count, int idx, double pad) => Padding(
    padding: EdgeInsets.fromLTRB(pad, 10, pad, 0),
    child: Row(
      children: [
        for (var i = 0; i < count; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  height: 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: Color(0x33FFFFFF)),
                      if (i < idx)
                        ColoredBox(color: EmbunColors.goldDim)
                      else if (i == idx)
                        TweenAnimationBuilder<double>(
                          key: ValueKey('progress-$idx'),
                          tween: Tween(begin: _reduced ? 1.0 : 0.0, end: 1.0),
                          duration: _dwell,
                          curve: Curves.linear,
                          builder: (context, v, _) => Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: v,
                              child: const ColoredBox(
                                color: EmbunColors.gold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PARA PEMERAN',
                            style: TextStyle(
                              color: EmbunColors.gold,
                              fontSize: 11,
                              letterSpacing: 4,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Kisah Hayu bersama kalian',
                            style: TextStyle(
                              color: EmbunColors.cream,
                              fontSize: compact ? 22 : 32,
                              height: 1.12,
                              fontWeight: FontWeight.w900,
                              shadows: const [
                                Shadow(color: Colors.black87, blurRadius: 12),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: compact ? 72 : 110,
                            height: 2,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [EmbunColors.gold, Color(0x00FFFFFF)],
                              ),
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
                  // Hitung mundur tipis menuju "Lanjut" otomatis.
                  if (!waiting && widget.players.isNotEmpty && !_reduced) ...[
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 1.0, end: 0.0),
                      duration: _finaleDuration,
                      curve: Curves.linear,
                      builder: (context, v, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: v,
                          minHeight: 2,
                          backgroundColor: const Color(0x22FFFFFF),
                          valueColor: const AlwaysStoppedAnimation(
                            EmbunColors.gold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
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

/// Satu pemeran muncul di bawah sorot silang: kilatan, kartu miring 3D
/// "mendarat" di atas genangan cahaya, nama menajam dari kabur, ornamen
/// berlian, "SEBAGAI", lalu gelar karakter yang berkilau emas. Setelah tampil,
/// kartu melayang pelan, kilau lewat berkala, dan debu cahaya terus naik.
class _Spotlight extends StatefulWidget {
  const _Spotlight({
    super.key,
    required this.player,
    required this.isMe,
    required this.reduced,
    required this.index,
    required this.total,
  });

  final Map<String, dynamic> player;
  final bool isMe, reduced;
  final int index, total;

  @override
  State<_Spotlight> createState() => _SpotlightState();
}

class _SpotlightState extends State<_Spotlight> with TickerProviderStateMixin {
  // Satu kali: pengungkapan. Berulang: melayang, kilau, debu cahaya.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  static const _highlight = Color(0xFFFFF3C4);

  @override
  void initState() {
    super.initState();
    if (widget.reduced) {
      _intro.value = 1;
    } else {
      _intro.forward();
      _idle.repeat();
      if (widget.isMe) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final isMe = widget.isMe;
    final reduced = widget.reduced;
    final name = (player['name'] as String?)?.trim();
    final stem = (player['character_card'] as String?) ?? 'default';
    final label = name == null || name.isEmpty ? 'Pemain' : name;
    final title = stem == 'default' ? 'Karakter desa' : characterTitle(stem);
    final tint = isMe ? EmbunColors.gold : EmbunColors.mist;
    return Semantics(
      liveRegion: true,
      label: '$label sebagai $title${isMe ? ', kamu' : ''}',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: Listenable.merge([_intro, _idle]),
        builder: (context, _) => LayoutBuilder(
          builder: (context, box) {
            final t = _intro.value;
            final idle = _idle.value;
            final wave = reduced ? 0.0 : math.sin(idle * 2 * math.pi);

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
                math.min(box.maxWidth * .6, (box.maxHeight - 190) * .66),
                300.0,
              ),
            );

            // --- Nama: menajam dari kabur sambil mengecil ke ukuran akhir ---
            final nameBlur = 10 * (1 - seg(.3, .75));
            final nameStyle = TextStyle(
              color: EmbunColors.cream,
              fontSize: wide ? 54 : 35,
              height: 1.05,
              fontWeight: FontWeight.w900,
              shadows: const [Shadow(color: Colors.black87, blurRadius: 16)],
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

            // --- Kilau: sekali saat tampil, lalu bergantian tiap ~4 detik ---
            final cardPos = t < 1
                ? seg(.45, 1.0, Curves.easeInOut)
                : math.min(1.0, ((idle * 2 + .5) % 1.0) / .45);
            final titlePos = t < 1
                ? seg(.75, 1.0, Curves.easeInOut)
                : math.min(1.0, ((idle * 2) % 1.0) / .45);
            final sheen = isMe
                ? const Color(0x77FFE9A8)
                : const Color(0x55FFFFFF);

            // --- Kartu: miring 3D lalu mendarat, melayang pelan sesudahnya ---
            Widget card = CardArt(
              path: protagonistPath(stem),
              width: artW,
              glow: tint,
            );
            if (cardPos > 0 && cardPos < 1) {
              card = ShaderMask(
                blendMode: BlendMode.srcATop,
                shaderCallback: (r) => LinearGradient(
                  begin: Alignment(-2.2 + 4.4 * cardPos, -.6),
                  end: Alignment(-1.2 + 4.4 * cardPos, .6),
                  colors: [const Color(0x00FFFFFF), sheen, const Color(0x00FFFFFF)],
                ).createShader(r),
                child: card,
              );
            }
            final tilt = .55 * (1 - seg(0, .7)) + wave * .035;
            final art = Opacity(
              opacity: seg(0, .35),
              child: Transform.translate(
                offset: Offset(0, 46 * (1 - seg(0, .6)) + wave * 5),
                child: Transform.scale(
                  scale: .84 + .16 * seg(0, .65, Curves.easeOutBack),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, .0012)
                      ..rotateY(tilt),
                    child: card,
                  ),
                ),
              ),
            );

            // --- Genangan cahaya di bawah kartu ---
            final poolH = math.max(16.0, artW * .1);
            final pool = Transform.translate(
              offset: Offset(0, -poolH * .55),
              child: Opacity(
                opacity: seg(.15, .6) * (.85 - wave * .15),
                child: SizedBox(
                  width: artW * 1.08,
                  height: poolH,
                  child: CustomPaint(painter: _PoolPainter(tint)),
                ),
              ),
            );
            final artBlock = Column(
              mainAxisSize: MainAxisSize.min,
              children: [art, pool],
            );

            // --- Judul karakter: emas berkilau (bayangan terpisah agar tetap hitam) ---
            final titleStyle = TextStyle(
              fontSize: wide ? 31 : 23,
              height: 1.15,
              letterSpacing: .6,
              fontWeight: FontWeight.w800,
            );
            final titleAlign = wide ? TextAlign.left : TextAlign.center;
            final titleWidget = Stack(
              children: [
                Text(
                  title,
                  textAlign: titleAlign,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle.copyWith(
                    color: Colors.transparent,
                    shadows: const [
                      Shadow(color: Colors.black87, blurRadius: 12),
                    ],
                  ),
                ),
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (r) => LinearGradient(
                    begin: Alignment(-2.0 + 4.0 * titlePos, 0),
                    end: Alignment(-1.0 + 4.0 * titlePos, 0),
                    colors: const [
                      EmbunColors.gold,
                      _highlight,
                      EmbunColors.gold,
                    ],
                  ).createShader(r),
                  child: Text(
                    title,
                    textAlign: titleAlign,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle.copyWith(color: Colors.white),
                  ),
                ),
              ],
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
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: EmbunColors.gold),
                        color: EmbunColors.gold.withValues(alpha: .14),
                        boxShadow: [
                          BoxShadow(
                            color: EmbunColors.gold.withValues(
                              alpha: .28 + .14 * wave,
                            ),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: const Text(
                        'KAMU',
                        style: TextStyle(
                          color: EmbunColors.gold,
                          fontSize: 11,
                          letterSpacing: 3,
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
                      wide ? -30 * (1 - seg(.3, .75)) : 0,
                      wide ? 0 : 18 * (1 - seg(.3, .75)),
                    ),
                    child: Transform.scale(
                      alignment: wide ? Alignment.centerLeft : Alignment.center,
                      scale: 1 + .12 * (1 - seg(.3, .8)),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxText),
                        child: nameText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _ornament(seg(.45, .85), isMe ? EmbunColors.gold : tint),
                const SizedBox(height: 12),
                Opacity(
                  opacity: seg(.5, .75),
                  child: const Text(
                    'SEBAGAI',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      letterSpacing: 6,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Opacity(
                  opacity: seg(.6, .9),
                  child: Transform.translate(
                    offset: Offset(0, 14 * (1 - seg(.6, .95))),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxText),
                      child: titleWidget,
                    ),
                  ),
                ),
              ],
            );

            // Nomor hantu raksasa (kerangka saja) di belakang semuanya.
            final ghost = IgnorePointer(
              child: Align(
                alignment: wide ? Alignment.centerRight : Alignment.bottomCenter,
                child: Opacity(
                  opacity: seg(.05, .7),
                  child: Transform.translate(
                    offset: Offset(30 * (1 - seg(.05, .8)), 0),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        (widget.index + 1).toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: wide ? 260 : 170,
                          height: .85,
                          fontWeight: FontWeight.w900,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 1.4
                            ..color = tint.withValues(alpha: .16),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );

            return Stack(
              fit: StackFit.expand,
              children: [
                ghost,
                IgnorePointer(
                  child: CustomPaint(
                    painter: _BeamPainter(
                      t: t,
                      idle: idle,
                      tint: tint,
                      wide: wide,
                      isMe: isMe,
                      still: reduced,
                    ),
                  ),
                ),
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: wide
                        ? Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        artBlock,
                        const SizedBox(width: 44),
                        texts,
                      ],
                    )
                        : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        artBlock,
                        const SizedBox(height: 14),
                        texts,
                      ],
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

  /// Garis tipis yang melebar dari tengah dengan berlian kecil di pusatnya.
  Widget _ornament(double p, Color c) => Opacity(
    opacity: p,
    child: SizedBox(
      width: 190,
      height: 10,
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: p,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [c.withValues(alpha: 0), c],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Transform.rotate(
              angle: math.pi / 4,
              child: Container(width: 6, height: 6, color: c),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: p,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [c, c.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Genangan cahaya berbentuk elips di lantai, tempat kartu "berdiri".
class _PoolPainter extends CustomPainter {
  const _PoolPainter(this.tint);
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final r = size.width / 2;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(1, size.height / size.width);
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(Offset.zero, r, [
          tint.withValues(alpha: .55),
          tint.withValues(alpha: .18),
          tint.withValues(alpha: 0),
        ], const [
          0,
          .45,
          1,
        ]),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PoolPainter old) => old.tint != tint;
}

/// Sorot silang dari atas, kerucut utama dengan inti terang, pendar di belakang
/// kartu, kilatan + gelombang kejut saat muncul, dan debu cahaya yang terus
/// naik sambil meliuk.
class _BeamPainter extends CustomPainter {
  const _BeamPainter({
    required this.t,
    required this.idle,
    required this.tint,
    required this.wide,
    required this.isMe,
    required this.still,
  });
  final double t, idle;
  final Color tint;
  final bool wide, isMe, still;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w * (wide ? .38 : .5);
    final cy = h * .44;
    final reveal = Curves.easeOut.transform((t / .4).clamp(0.0, 1.0));
    final sway = still ? 0.0 : math.sin(idle * 2 * math.pi);

    // Dua sorot miring yang bersilang ke arah pemeran, bergoyang pelan.
    for (final s in const [-1.0, 1.0]) {
      final topX = cx + s * w * .46;
      final footX = cx - s * w * .06 + sway * w * .03;
      canvas.drawPath(
        Path()
          ..moveTo(topX - w * .012, 0)
          ..lineTo(topX + w * .012, 0)
          ..lineTo(footX + w * .07, h * .92)
          ..lineTo(footX - w * .07, h * .92)
          ..close(),
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.linear(
            Offset(topX, 0),
            Offset(footX, h * .92),
            [
              tint.withValues(alpha: .10 * reveal),
              tint.withValues(alpha: 0),
            ],
          ),
      );
    }

    // Kerucut utama.
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

    // Inti terang yang lebih sempit.
    canvas.drawPath(
      Path()
        ..moveTo(cx - w * .02, 0)
        ..lineTo(cx + w * .02, 0)
        ..lineTo(cx + w * (.06 + .10 * reveal), h * .9)
        ..lineTo(cx - w * (.06 + .10 * reveal), h * .9)
        ..close(),
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h * .9), [
          Color.lerp(tint, Colors.white, .5)!.withValues(alpha: .20 * reveal),
          tint.withValues(alpha: 0),
        ]),
    );

    // Pendar di belakang kartu.
    final glowR = math.min(w, h) * (.55 + .02 * sway);
    canvas.drawCircle(
      Offset(cx, cy),
      glowR,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(Offset(cx, cy), glowR, [
          tint.withValues(alpha: .26 * reveal),
          tint.withValues(alpha: 0),
        ]),
    );

    // Kilatan saat muncul.
    if (t < .3) {
      final f = 1 - t / .3;
      final r = math.max(w, h) * (.3 + .5 * (t / .3));
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.radial(Offset(cx, cy), r, [
            Color.lerp(tint, Colors.white, .6)!.withValues(alpha: .38 * f),
            tint.withValues(alpha: 0),
          ]),
      );
    }

    // Gelombang kejut emas, khusus saat giliran "kamu".
    if (isMe && t < .8) {
      final p = t / .8;
      final r = math.min(w, h) * (.1 + .6 * Curves.easeOut.transform(p));
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..blendMode = BlendMode.plus
          ..color = tint.withValues(alpha: .55 * (1 - p)),
      );
    }

    // Debu cahaya: terus naik dan meliuk (mulus karena idle berulang utuh).
    if (!still) {
      const n = 26;
      for (var i = 0; i < n; i++) {
        final life = (idle * 2 + i / n) % 1.0;
        final a = i * 2.399;
        final x =
            cx + math.sin(a + life * math.pi * 2) * w * .2 * (.35 + (i % 5) / 5);
        final y = h * (1.03 - life * .9);
        canvas.drawCircle(
          Offset(x, y),
          1.1 + (i % 3) * .7,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = Color.lerp(tint, Colors.white, (i % 2) * .5)!.withValues(
              alpha: math.sin(life * math.pi) * .6 * reveal,
            ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BeamPainter old) =>
      old.t != t ||
          old.idle != idle ||
          old.tint != tint ||
          old.wide != wide ||
          old.isMe != isMe ||
          old.still != still;
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
      scale: current ? 1.16 : 1.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
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
          boxShadow: current
              ? [
            BoxShadow(
              color: EmbunColors.gold.withValues(alpha: .5),
              blurRadius: 14,
            ),
          ]
              : null,
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
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isMe
                ? const [Color(0xDD2B2A14), Color(0xCC102A20)]
                : const [Color(0xDD173A2C), Color(0xCC0C201A)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMe ? EmbunColors.gold : const Color(0x66577954),
            width: isMe ? 1.5 : 1,
          ),
          boxShadow: isMe
              ? [
            BoxShadow(
              color: EmbunColors.gold.withValues(alpha: .28),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ]
              : const [BoxShadow(color: Color(0x66000000), blurRadius: 10)],
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
            const SizedBox(height: 6),
            Container(
              width: 28,
              height: 1.5,
              color: (isMe ? EmbunColors.gold : const Color(0x66577954)),
            ),
            const SizedBox(height: 6),
            Text(
              isMe ? 'KAMU · SEBAGAI' : 'SEBAGAI',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 9,
                letterSpacing: 2,
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
      duration: Duration(milliseconds: 550 + order * 80),
      curve: Curves.easeOutCubic,
      child: body,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 26 * (1 - t)),
          child: Transform.scale(scale: .92 + .08 * t, child: child),
        ),
      ),
    );
  }
}