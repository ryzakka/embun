import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../../data/game_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';

double _seg(double v, double a, double b) =>
    ((v - a) / (b - a)).clamp(0.0, 1.0).toDouble();

double _smooth(double x) => x * x * (3 - 2 * x);

double _bump(double t, double c, double w) => max(0.0, 1 - (t - c).abs() / w);

List<double> _sat(double s) {
  final inv = 1 - s;
  final r = 0.2126 * inv, g = 0.7152 * inv, b = 0.0722 * inv;
  return [
    r + s, g, b, 0, 0,
    r, g + s, b, 0, 0,
    r, g, b + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/// pohon0 (rimbun) ... pohon9 (mati); 30 daun (sempurna) = pohon0-sakura.
String? _treeFor(int leaves) {
  if (leaves >= 30) {
    final s = AssetCatalog.I.file(pohonDir, 'pohon0-sakura');
    if (s != null) return s;
  }
  return treePath(leaves);
}

Offset _bz(Offset p0, Offset c, Offset p1, double e) {
  final a = (1 - e) * (1 - e), b = 2 * (1 - e) * e, d = e * e;
  return Offset(
      a * p0.dx + b * c.dx + d * p1.dx, a * p0.dy + b * c.dy + d * p1.dy);
}

/// Layar hasil persembahan.
///
/// 1. Gelembung "+1 / -1" muncul dari Hayu satu per satu, melayang, lalu
///    terbang ke hitungan daun di atas. Begitu tiba, ANGKA daun langsung
///    berubah (berguling naik/turun), diiringi ledakan efek.
/// 2. Gambar pohon sengaja TIDAK berubah selama gelembung berdatangan; ia
///    tetap pada keadaan sebelum efek.
/// 3. Setelah semua efek selesai, Hayu "berubah": layar meredup, ledakan
///    cahaya, pohon beralih ke gambar akhir, dan spanduk perubahan bersih
///    menghantam layar. Baru setelah itu tombol Lanjut muncul.
///
/// Angka diambil dari label tiap efek (tanda +/- dan angkanya; bila tak
/// ada, +1 untuk efek baik dan -1 untuk efek buruk). Bila jumlah akhirnya
/// berbeda dengan angka akhir dari server (mis. efek yang disamarkan Topeng
/// Warga atau batas 0-30), angka disetel ke nilai server pada akhir.
class EffectsView extends StatefulWidget {
  final GameRepository repo;
  final String gameId;
  final int day;
  final int finalLeaves;
  final bool isAntag;
  final bool waiting;
  final int readyCount;
  final int total;
  final Future<void> Function() onContinue;

  const EffectsView({
    super.key,
    required this.repo,
    required this.gameId,
    required this.day,
    required this.finalLeaves,
    required this.isAntag,
    required this.waiting,
    required this.readyCount,
    required this.total,
    required this.onContinue,
  });

  @override
  State<EffectsView> createState() => _EffectsViewState();
}

class _EffectsViewState extends State<EffectsView>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> rows = [];
  bool loaded = false;
  int revealed = 0;
  int arrived = 0;

  /// Daun sebelum efek (null = tidak diketahui, angka tidak dihitung live).
  int? _before;

  /// Angka daun yang tampil (berubah live saat gelembung tiba).
  late int shown = widget.finalLeaves;

  /// Daun yang menentukan GAMBAR pohon: bertahan di keadaan sebelum efek
  /// sampai semua efek selesai.
  late int imgLeaves = widget.finalLeaves;

  bool gray = false;
  bool _settled = false; // pohon sudah beralih ke gambar akhir
  bool _ready = false; // seluruh adegan selesai, tombol boleh muncul
  Timer? timer;

  int _lastDelta = 0;
  int _flashIdx = -1;
  bool _lastBad = false;
  int _hits = 0;
  int _streak = 0; // efek berturut-turut yang sejenis (kombo)
  bool _streakBad = false;

  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));
  late final AnimationController _hud = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800));
  late final AnimationController _final = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3600));
  late final AnimationController _t = AnimationController(
      vsync: this, duration: const Duration(seconds: 120))
    ..repeat();

  bool get _hasBefore => _before != null;
  int get _net => widget.finalLeaves - (_before ?? widget.finalLeaves);

  @override
  void initState() {
    super.initState();
    _final.addListener(() {
      if (!_settled && _final.value >= 0.30) {
        _settled = true;
        if (mounted) setState(() => imgLeaves = widget.finalLeaves);
        HapticFeedback.heavyImpact();
        Future.delayed(
            const Duration(milliseconds: 140), HapticFeedback.heavyImpact);
      }
    });
    _final.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _ready = true);
      }
    });
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.repo.effects(widget.gameId, widget.day);
      final before = await widget.repo.leavesBefore(widget.gameId);
      if (!mounted) return;
      setState(() {
        rows = r;
        loaded = true;
        _before = before;
        // Hitungan awal dari server, bukan dari log (log tidak membawa angka).
        if (before != null) {
          shown = before;
          imgLeaves = before;
        }
      });
      if (r.isEmpty) {
        setState(() {
          shown = widget.finalLeaves;
          imgLeaves = widget.finalLeaves;
          _settled = true;
          _ready = true;
        });
        return;
      }
      setState(() => revealed = 1);
      timer = Timer.periodic(const Duration(milliseconds: 1500), (t) {
        if (!mounted || revealed >= rows.length) {
          t.cancel();
          return;
        }
        setState(() => revealed++);
      });
    } catch (_) {
      // Gagal memuat: jangan kunci pemain, tampilkan hasil akhir saja.
      if (mounted) {
        setState(() {
          loaded = true;
          rows = [];
          shown = widget.finalLeaves;
          imgLeaves = widget.finalLeaves;
          _settled = true;
          _ready = true;
        });
      }
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    _pulse.dispose();
    _hud.dispose();
    _final.dispose();
    _t.dispose();
    super.dispose();
  }

  /// Perubahan daun yang tertulis pada satu efek.
  int _deltaOf(Map<String, dynamic> row) {
    final label = (row['label'] as String?) ?? '';
    final m = RegExp(r'([+\-−–])\s*(\d+)').firstMatch(label);
    if (m != null) {
      final n = int.parse(m.group(2)!);
      return m.group(1) == '+' ? n : -n;
    }
    return row['kind'] == 'bad' ? -1 : 1;
  }

  void _arrive(Map<String, dynamic> row) {
    if (!mounted) return;
    final isBad = row['kind'] == 'bad';
    final d = _deltaOf(row);
    _lastBad = isBad;
    _hits++;
    if (arrived > 0 && _streakBad == isBad) {
      _streak++;
    } else {
      _streak = 1;
    }
    _streakBad = isBad;
    _pulse.forward(from: 0);
    _hud.forward(from: 0);
    if (isBad) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
    setState(() {
      arrived++;
      if (_hasBefore) {
        final prev = shown;
        shown = (shown + d).clamp(0, 30).toInt();
        _lastDelta = shown == prev ? d : shown - prev;
        _flashIdx = _lastDelta > 0 ? shown - 1 : shown;
        if (arrived >= rows.length && shown != widget.finalLeaves) {
          // Samakan dengan angka server (mis. efek yang disamarkan).
          final fix = widget.finalLeaves - shown;
          shown = widget.finalLeaves;
          _lastDelta = fix;
          _flashIdx = fix > 0 ? shown - 1 : shown;
        }
      } else {
        _lastDelta = d;
      }
      if (isBad) gray = true;
    });
    if (isBad) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => gray = false);
      });
    }
    if (arrived >= rows.length) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) _final.forward(from: 0);
      });
    }
  }

  // ====================== build ======================

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Color(0xFF050A08)),
          EmbunLoading(text: 'Menghitung hasil...'),
        ],
      );
    }
    return LayoutBuilder(builder: (context, box) => _stage(box));
  }

  Widget _stage(BoxConstraints box) {
    final W = box.maxWidth, H = box.maxHeight;
    final pad = MediaQuery.paddingOf(context);
    final center = Offset(W / 2, H * 0.52);
    final counterC = Offset(W / 2, pad.top + 16 + 40 + 10 + 30);
    final dark = widget.isAntag;
    final perfect = widget.finalLeaves >= 30;
    final fin = widget.finalLeaves;

    return AnimatedBuilder(
      animation: Listenable.merge([_pulse, _hud, _final, _t]),
      builder: (context, _) {
        final time = _t.value * 120;
        final p = _pulse.value;
        final pulsing = _pulse.isAnimating;
        final fv = _final.value;
        final inFinal = fv > 0;
        final net = _net;

        // ---- guncangan kamera ----
        var dx = 0.0, dy = 0.0;
        if (pulsing) {
          if (_lastBad) {
            final k = 1 + 0.15 * min(_streak, 5);
            dx += sin(p * 70) * 14 * k * (1 - p) * (1 - p);
            dy += cos(p * 55) * 6 * k * (1 - p) * (1 - p);
          } else {
            dy -= sin(p * pi) * 4 * (1 - p);
          }
        }
        if (inFinal) {
          final pre = _seg(fv, 0, 0.3);
          dx += sin(time * 60) * 3 * pre;
          if (fv >= 0.3) {
            final k = _seg(fv, 0.30, 0.62);
            final amp = net < 0 ? 18.0 : 9.0;
            dx += sin(k * 80) * amp * (1 - k);
            dy += cos(k * 66) * amp * 0.5 * (1 - k);
          }
        }

        // ---- pohon layar penuh ----
        final punch = fv >= 0.3 ? 0.10 * (1 - _seg(fv, 0.30, 0.6)) : 0.0;
        final ts = 1.04 +
            0.03 * sin(time * 0.2) +
            (pulsing ? (_lastBad ? -0.03 : 0.045) * sin(p * pi) : 0.0) +
            punch;
        final path = _treeFor(imgLeaves);
        final tree = ClipRect(
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.scale(
              scale: ts,
              alignment: const Alignment(0, 0.25),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: gray ? 0.0 : 1.0),
                duration: const Duration(milliseconds: 500),
                builder: (_, s, child) => ColorFiltered(
                    colorFilter: ColorFilter.matrix(_sat(s)), child: child),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 1100),
                  layoutBuilder: (cur, prev) => Stack(
                    fit: StackFit.expand,
                    children: [...prev, if (cur != null) cur],
                  ),
                  child: GameImage(
                      key: ValueKey(path), path: path, cacheWidth: 1600),
                ),
              ),
            ),
          ),
        );

        // ---- peredam sebelum ledakan akhir ----
        final anticip = !inFinal
            ? 0.0
            : (fv < 0.3
            ? 0.45 * _seg(fv, 0, 0.28)
            : 0.45 * (1 - _seg(fv, 0.30, 0.42)));

        final finalFlash = _bump(fv, 0.30, 0.05) * 0.9;
        final finalFlashCol =
        net < 0 ? const Color(0xFFD9B8FF) : const Color(0xFFFFF6D6);
        final hitFlash = (pulsing && _lastBad)
            ? (1 - p) * 0.18 * (0.5 + 0.5 * sin(p * 60))
            : 0.0;

        // ---- aura & suasana ----
        final vit = (shown / 30).clamp(0.0, 1.0).toDouble();
        final aura = dark
            ? const Color(0xFFB07CE8)
            : Color.lerp(const Color(0xFF7A6A92), const Color(0xFFFFE08A), vit)!;
        final mode = !_settled
            ? 0
            : perfect
            ? 1
            : (fin <= 6 ? 2 : 0);

        // ---- gelembung ----
        final bubbles = <Widget>[];
        for (var i = 0; i < revealed && i < rows.length; i++) {
          final seq = (rows[i]['seq'] as int?) ?? i;
          final fx = (((seq * 37) % 100) / 100) * 0.36 - 0.18;
          bubbles.add(_Bubble(
            key: ValueKey('b$i'),
            row: rows[i],
            origin: Offset(W / 2 + fx * W, H * 0.58),
            end: counterC,
            onArrive: () => _arrive(rows[i]),
          ));
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
                child: Backdrop(
                    path: landscapePath(imgLeaves), dark: dark, dim: 0.5)),
            Positioned.fill(child: tree),
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.22)),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.95,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.55),
                      ],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            if (anticip > 0.01)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                      color: Colors.black.withValues(alpha: anticip)),
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _Ambient(
                      time: time, aura: aura, mode: mode, vit: vit, center: center),
                ),
              ),
            ),
            if (pulsing)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _HitPainter(
                      t: p,
                      bad: _lastBad,
                      seed: _hits,
                      center: center,
                      power: 1 + 0.12 * min(arrived, 6),
                    ),
                  ),
                ),
              ),
            if (inFinal)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _FinalPainter(
                      v: fv,
                      gain: net >= 0,
                      center: center,
                      aura: aura,
                    ),
                  ),
                ),
              ),
            ...bubbles,
            // spanduk perubahan bersih
            if (inFinal && _hasBefore)
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: const Alignment(0, 0.12),
                    child: _banner(fv, net, perfect, fin),
                  ),
                ),
              ),
            // hitungan daun
            Positioned(
              top: pad.top + 16,
              left: 0,
              right: 0,
              child: _hudBlock(W),
            ),
            // ledakan di hitungan daun saat angka berubah
            if (_hud.isAnimating)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _CounterBurst(
                      t: _hud.value,
                      bad: _lastBad,
                      seed: _hits,
                      center: counterC,
                    ),
                  ),
                ),
              ),
            // kombo efek sejenis berturut-turut
            if (_streak >= 2 && _hud.isAnimating)
              Positioned(
                top: pad.top + 16 + 140,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: Opacity(
                      opacity: (1 - _seg(_hud.value, 0.55, 1.0)).toDouble(),
                      child: Transform.scale(
                        scale: 1 + 0.55 * sin(_hud.value * pi),
                        child: Text(
                          _streakBad
                              ? 'KABUT ×$_streak'
                              : 'BERKAH ×$_streak',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            fontStyle: FontStyle.italic,
                            color: _streakBad
                                ? const Color(0xFFE6B8FF)
                                : const Color(0xFFFFE08A),
                            shadows: [
                              Shadow(
                                  color: _streakBad
                                      ? EmbunColors.blood
                                      : const Color(0xFF7FE0A0),
                                  blurRadius: 22),
                              const Shadow(color: Colors.black, blurRadius: 6),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // tombol
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: !_ready
                          ? const SizedBox(key: ValueKey('none'), height: 52)
                          : widget.waiting
                          ? Row(
                        key: const ValueKey('wait'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const GameIcon('wait', size: 36),
                          const SizedBox(width: 8),
                          Text(
                              'Menunggu warga lain... ${widget.readyCount}/${widget.total}'),
                        ],
                      )
                          : EmbunButton(
                        key: const ValueKey('go'),
                        label: 'Lanjut',
                        icon: 'skip',
                        onPressed: widget.onContinue,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // cahaya tepi layar berdenyut tiap efek tiba
            if (pulsing)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 0.95,
                        colors: [
                          Colors.transparent,
                          (_lastBad
                              ? const Color(0xFFB07CE8)
                              : const Color(0xFFFFE08A))
                              .withValues(alpha: 0.42 * (1 - p)),
                        ],
                        stops: const [0.55, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            if (hitFlash > 0.005)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                      color: EmbunColors.blood.withValues(alpha: hitFlash)),
                ),
              ),
            if (finalFlash > 0.01)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                      color: finalFlashCol.withValues(
                          alpha: finalFlash.clamp(0.0, 1.0).toDouble())),
                ),
              ),
          ],
        );
      },
    );
  }

  // ====================== HUD ======================

  Widget _hudBlock(double W) {
    final dark = widget.isAntag;
    final vit = (shown / 30).clamp(0.0, 1.0).toDouble();
    final barColor = dark
        ? const Color(0xFFB07CE8)
        : Color.lerp(Colors.redAccent, Colors.greenAccent, vit)!;
    final gw = min(W - 48, 440.0).toDouble();

    return AnimatedBuilder(
      animation: _hud,
      builder: (context, _) {
        final h = _hud.value;
        final active = _hud.isAnimating;
        final up = _lastDelta >= 0;
        final flashCol = up ? const Color(0xFF9DF0B8) : EmbunColors.blood;
        final punch = active ? sin(h * pi) * (1 - h * 0.4) : 0.0;
        final numCol = Color.lerp(
            EmbunColors.gold, flashCol, active ? (1 - h).clamp(0.0, 1.0) : 0.0)!;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(4, 2, 16, 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: EmbunColors.gold.withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GameIcon('hari', size: 36),
                  const SizedBox(width: 8),
                  Text('Hasil persembahan hari ${widget.day}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: EmbunColors.gold)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Transform.scale(
              scale: 1 + 0.22 * punch,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const GameIcon('helaidaun', size: 46),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 70,
                        height: 56,
                        child: ClipRect(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 380),
                            transitionBuilder: (child, anim) {
                              final incoming = child.key == ValueKey(shown);
                              final dir = up ? 1.0 : -1.0;
                              final off = Tween<Offset>(
                                begin: Offset(0, incoming ? 0.9 * dir : -0.9 * dir),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                  parent: anim, curve: Curves.easeOutBack));
                              return FadeTransition(
                                opacity: anim,
                                child: SlideTransition(position: off, child: child),
                              );
                            },
                            child: Center(
                              key: ValueKey(shown),
                              child: Text('$shown',
                                  style: TextStyle(
                                    fontSize: 44,
                                    height: 1.0,
                                    fontWeight: FontWeight.w900,
                                    color: numCol,
                                    shadows: [
                                      Shadow(
                                          color: numCol.withValues(alpha: 0.8),
                                          blurRadius: 18),
                                      const Shadow(
                                          color: Colors.black, blurRadius: 6),
                                    ],
                                  )),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('daun',
                          style: TextStyle(
                              fontSize: 18,
                              color: Colors.white70,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 6)
                              ])),
                    ],
                  ),
                  // selisih melayang
                  if (active && _lastDelta != 0)
                    Positioned(
                      right: -48,
                      top: -6 - 30 * h,
                      child: Opacity(
                        opacity: (1 - h).clamp(0.0, 1.0).toDouble(),
                        child: Text(
                          _lastDelta > 0 ? '+$_lastDelta' : '−${-_lastDelta}',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: flashCol,
                            shadows: [
                              Shadow(color: flashCol, blurRadius: 16),
                              const Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // bilah 30 sel
            SizedBox(
              width: gw,
              height: 10,
              child: Row(
                children: [
                  for (var i = 0; i < 30; i++)
                    Expanded(
                      child: Builder(builder: (_) {
                        final filled = i < shown;
                        final flashing =
                            active && i == _flashIdx && h < 0.7;
                        Color c = filled ? barColor : Colors.white12;
                        if (flashing) c = up ? Colors.white : EmbunColors.blood;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: c,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: flashing
                                ? [BoxShadow(color: c, blurRadius: 10)]
                                : null,
                          ),
                        );
                      }),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ====================== spanduk akhir ======================

  Widget _banner(double v, int net, bool perfect, int fin) {
    final inT = Curves.easeOutBack.transform(_seg(v, 0.32, 0.46));
    final outT = _smooth(_seg(v, 0.84, 1.0));
    final op = (inT.clamp(0.0, 1.0) * (1 - outT)).toDouble();
    if (op <= 0.01) return const SizedBox.shrink();

    final gain = net > 0, loss = net < 0;
    final Color col = loss
        ? const Color(0xFFE6B8FF)
        : gain
        ? const Color(0xFFFFE08A)
        : EmbunColors.cream;
    final Color glow = loss
        ? EmbunColors.blood
        : gain
        ? const Color(0xFF7FE0A0)
        : EmbunColors.goldDim;
    final big = gain ? '+$net' : (loss ? '−${-net}' : 'Hayu bertahan');
    final sub = perfect
        ? 'Hayu mekar sempurna!'
        : fin <= 0
        ? 'Hayu layu...'
        : gain
        ? 'Hayu menghijau kembali'
        : loss
        ? 'Kabut menggerogoti Hayu'
        : 'Tidak ada yang berubah malam ini';

    return Opacity(
      opacity: op,
      child: Transform.scale(
        scale: 2.2 - 1.2 * inT.clamp(0.0, 1.2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 14),
          decoration: BoxDecoration(
            gradient: RadialGradient(colors: [
              Colors.black.withValues(alpha: 0.62),
              Colors.black.withValues(alpha: 0),
            ]),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(big,
                  style: TextStyle(
                    fontSize: (gain || loss) ? 84 : 36,
                    height: 1.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: (gain || loss) ? 2 : 3,
                    color: col,
                    shadows: [
                      Shadow(color: glow, blurRadius: 34),
                      Shadow(color: glow, blurRadius: 12),
                      const Shadow(color: Colors.black, blurRadius: 6),
                    ],
                  )),
              if (gain || loss)
                Text('daun',
                    style: TextStyle(
                        fontSize: 20,
                        letterSpacing: 4,
                        color: col,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 8)
                        ])),
              const SizedBox(height: 6),
              Text(sub,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black, blurRadius: 10)])),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================== gelembung ======================

/// Gelembung efek: membal keluar dari Hayu, melayang sebentar (bergetar bila
/// buruk), lalu melesat ke hitungan daun dengan jejak. Saat tiba memanggil
/// [onArrive] (angka daun berubah saat itu juga).
class _Bubble extends StatefulWidget {
  final Map<String, dynamic> row;
  final Offset origin;
  final Offset end;
  final VoidCallback onArrive;
  const _Bubble({
    super.key,
    required this.row,
    required this.origin,
    required this.end,
    required this.onArrive,
  });

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> with SingleTickerProviderStateMixin {
  late final AnimationController c;
  bool arrived = false;

  bool get bad => widget.row['kind'] == 'bad';
  double get holdEnd => bad ? 0.50 : 0.45;
  double get arriveAt => bad ? 0.68 : 0.72;

  @override
  void initState() {
    super.initState();
    c = AnimationController(
        vsync: this, duration: Duration(milliseconds: bad ? 3000 : 2200));
    c.addListener(() {
      if (!arrived && c.value >= arriveAt) {
        arrived = true;
        widget.onArrive();
      }
    });
    c.forward();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Offset _posAt(double u) {
    final o = widget.origin;
    final rise = Curves.easeOut.transform(_seg(u, 0, 0.2));
    var hover = o + Offset(0, -26 * rise + sin(u * pi * 6) * 3);
    if (bad) {
      hover += Offset(sin(u * 130) * 4 * _seg(u, 0.2, 0.5), 0);
    }
    if (u < holdEnd) return hover;
    final f = ((u - holdEnd) / (arriveAt - holdEnd)).clamp(0.0, 1.0).toDouble();
    final e = Curves.easeInCubic.transform(f);
    final side = (((widget.row['seq'] as int?) ?? 0) % 2 == 0) ? -1.0 : 1.0;
    final ctrl = Offset((hover.dx + widget.end.dx) / 2 + side * 90,
        (hover.dy + widget.end.dy) / 2 - 40);
    return _bz(hover, ctrl, widget.end, e);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final u = c.value;
        if (u >= 0.999) return const SizedBox.shrink();
        final pop = Curves.elasticOut.transform(_seg(u, 0, 0.22));
        final flyF = _seg(u, holdEnd, arriveAt);
        final scale = pop * (1 - 0.5 * Curves.easeIn.transform(flyF));
        final opacity = 1 - _seg(u, arriveAt, arriveAt + 0.12);
        final accent = bad ? Colors.purpleAccent : Colors.lightGreenAccent;
        final pos = _posAt(u);

        // jejak
        final trail = <Offset>[];
        if (u > holdEnd) {
          for (var k = 1; k <= 7; k++) {
            trail.add(_posAt(max(holdEnd, u - k * 0.018)));
          }
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            if (trail.isNotEmpty)
              IgnorePointer(
                child: CustomPaint(
                  painter: _TrailPainter(
                      points: trail,
                      color: bad
                          ? const Color(0xFFB07CE8)
                          : const Color(0xFFFFE08A),
                      alpha: opacity),
                ),
              ),
            Positioned(
              left: pos.dx,
              top: pos.dy,
              child: FractionalTranslation(
                translation: const Offset(-0.5, -0.5),
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0).toDouble(),
                  child: Transform.rotate(
                    angle: bad ? sin(u * 40) * 0.04 * _seg(u, 0.2, 0.5) : 0.0,
                    child: Transform.scale(
                      scale: scale.clamp(0.0, 2.0).toDouble(),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 6, 20, 6),
                        decoration: BoxDecoration(
                          color: bad
                              ? const Color(0xFF3A2A44)
                              : const Color(0xFF2E7D5B),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: accent, width: 1.6),
                          boxShadow: [
                            BoxShadow(
                                color: accent.withValues(alpha: 0.55),
                                blurRadius: 22,
                                spreadRadius: 2),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GameIcon(bad ? 'poinmin1' : 'poinplus1', size: 46),
                            const SizedBox(width: 6),
                            Text(widget.row['label'] as String,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
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

class _TrailPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final double alpha;
  const _TrailPainter(
      {required this.points, required this.color, required this.alpha});

  @override
  void paint(Canvas canvas, Size size) {
    for (var k = 0; k < points.length; k++) {
      final f = 1 - (k + 1) / (points.length + 1);
      canvas.drawCircle(points[k], 16 * f + 3,
          Paint()..color = color.withValues(alpha: (0.18 * f * alpha).clamp(0.0, 1.0)));
      canvas.drawCircle(points[k], 6 * f + 1.5,
          Paint()..color = Colors.white.withValues(alpha: (0.7 * f * alpha).clamp(0.0, 1.0)));
    }
  }

  @override
  bool shouldRepaint(covariant _TrailPainter old) => true;
}

// ====================== ledakan di hitungan daun ======================

/// Ledakan kecil di angka daun saat nilainya berubah: cincin kejut, percikan
/// (baik) atau serpihan bergerigi (buruk).
class _CounterBurst extends CustomPainter {
  final double t;
  final bool bad;
  final int seed;
  final Offset center;
  const _CounterBurst({
    required this.t,
    required this.bad,
    required this.seed,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fade = (1 - t).clamp(0.0, 1.0).toDouble();
    final e = Curves.easeOutCubic.transform(t);
    final rnd = Random(seed * 53 + 3);
    final a = bad ? const Color(0xFFB07CE8) : const Color(0xFFFFE08A);
    final b = bad ? EmbunColors.blood : const Color(0xFF9DF0B8);

    final fr = 90 * (0.4 + e);
    canvas.drawCircle(
      center,
      fr,
      Paint()
        ..shader = RadialGradient(colors: [
          Colors.white.withValues(alpha: 0.75 * fade * fade),
          a.withValues(alpha: 0.5 * fade),
          a.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: center, radius: fr)),
    );

    for (var r = 0; r < 2; r++) {
      final pr = (e - r * 0.16).clamp(0.0, 1.0).toDouble();
      if (pr <= 0) continue;
      canvas.drawCircle(
        center,
        24 + 150 * pr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * (1 - pr) + 1
          ..color = (r == 0 ? a : b).withValues(alpha: 0.85 * (1 - pr)),
      );
    }

    for (var j = 0; j < 22; j++) {
      final ang = (j / 22) * 2 * pi + rnd.nextDouble() * 0.3;
      final d0 = (30 + 120 * rnd.nextDouble()) * e;
      final dir = Offset(cos(ang), sin(ang));
      if (bad) {
        final sz = 3 + rnd.nextDouble() * 5;
        final pos = center + dir * d0 + Offset(0, 50 * t * t);
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(rnd.nextDouble() * 6 + t * 5);
        final shard = Path()
          ..moveTo(0, -sz)
          ..lineTo(sz * 0.55, 0)
          ..lineTo(0, sz * 1.3)
          ..lineTo(-sz * 0.55, 0)
          ..close();
        canvas.drawPath(shard,
            Paint()..color = const Color(0xFF2A1745).withValues(alpha: fade));
        canvas.drawPath(
            shard,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.1
              ..color = const Color(0xFFD9B8FF).withValues(alpha: fade));
        canvas.restore();
      } else {
        canvas.drawLine(
          center + dir * d0,
          center + dir * (d0 + 4 + 14 * fade),
          Paint()
            ..strokeWidth = 2.4 * fade + 0.6
            ..strokeCap = StrokeCap.round
            ..color = (j.isEven ? a : Colors.white).withValues(alpha: fade),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CounterBurst old) => true;
}

// ====================== suasana ======================

/// Aura Hayu, butiran cahaya naik, dan (setelah hasil) kelopak sakura bila
/// sempurna atau abu bila Hayu hampir mati.
class _Ambient extends CustomPainter {
  final double time;
  final Color aura;
  final int mode; // 0 tidak ada, 1 kelopak, 2 abu
  final double vit;
  final Offset center;
  const _Ambient({
    required this.time,
    required this.aura,
    required this.mode,
    required this.vit,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = min(w, h) * 0.45 * (0.92 + 0.08 * sin(time * 1.3));
    final a = 0.14 + 0.2 * vit;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(colors: [
          aura.withValues(alpha: a),
          aura.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: center, radius: r)),
    );

    // butiran naik
    final rnd = Random(9);
    for (var i = 0; i < 24; i++) {
      final x0 = rnd.nextDouble();
      final y0 = rnd.nextDouble();
      final sp = 0.02 + rnd.nextDouble() * 0.04;
      final sz = 1.4 + rnd.nextDouble() * 2.6;
      final ph = rnd.nextDouble() * 2 * pi;
      final f = (y0 - time * sp) % 1.0;
      final o = Offset((x0 + sin(time * 0.3 + ph) * 0.03) * w, f * h);
      final al = (0.3 + 0.7 * (0.5 + 0.5 * sin(time * 1.7 + ph))) * sin(f * pi);
      final col = vit > 0.3
          ? (i.isEven ? const Color(0xFFFFE08A) : const Color(0xFFBFF5D0))
          : const Color(0xFFB07CE8);
      canvas.drawCircle(
          o, sz * 3, Paint()..color = col.withValues(alpha: (0.14 * al).clamp(0.0, 1.0)));
      canvas.drawCircle(
          o,
          sz,
          Paint()
            ..color = Color.lerp(col, Colors.white, 0.5)!
                .withValues(alpha: (0.8 * al).clamp(0.0, 1.0)));
    }

    if (mode == 1) {
      const pink = [Color(0xFFF7B6D2), Color(0xFFFFD3E4), Color(0xFFF08FB5)];
      final pr = Random(21);
      for (var i = 0; i < 46; i++) {
        final x0 = pr.nextDouble();
        final ph = pr.nextDouble();
        final sp = 0.05 + pr.nextDouble() * 0.06;
        final sz = 5 + pr.nextDouble() * 7;
        final f = (time * sp + ph) % 1.0;
        final x = ((x0 + f * 0.25 + sin(f * 8 + ph * 6) * 0.04) % 1.1) * w;
        final y = (-0.05 + f * 1.1) * h;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(f * 8 + ph * 6);
        canvas.scale(1, 0.3 + 0.7 * cos(f * 9 + ph * 5).abs());
        final path = Path()
          ..moveTo(0, -sz)
          ..quadraticBezierTo(sz * 0.9, -sz * 0.2, 0, sz)
          ..quadraticBezierTo(-sz * 0.9, -sz * 0.2, 0, -sz);
        canvas.drawPath(
            path,
            Paint()
              ..color = pink[i % 3]
                  .withValues(alpha: (sin(f * pi) * 0.9).clamp(0.0, 1.0)));
        canvas.restore();
      }
    } else if (mode == 2) {
      final ar = Random(33);
      for (var i = 0; i < 34; i++) {
        final x0 = ar.nextDouble();
        final ph = ar.nextDouble();
        final sp = 0.03 + ar.nextDouble() * 0.04;
        final sz = 1.2 + ar.nextDouble() * 2.6;
        final f = (time * sp + ph) % 1.0;
        final x = ((x0 + f * 0.12 + sin(f * 6 + ph * 5) * 0.03) % 1.1) * w;
        final y = (-0.05 + f * 1.1) * h;
        canvas.drawCircle(
            Offset(x, y),
            sz,
            Paint()
              ..color = const Color(0xFFB8B0A8)
                  .withValues(alpha: (sin(f * pi) * 0.55).clamp(0.0, 1.0)));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Ambient old) => true;
}

// ====================== efek tiap gelembung tiba ======================

/// Ledakan di Hayu saat satu efek tiba.
/// Baik: kilau emas, cincin, sinar, percikan, daun melayang naik.
/// Buruk: vinyet gelap, cincin ungu-merah, retakan lebar, serpihan, kepulan.
class _HitPainter extends CustomPainter {
  final double t;
  final bool bad;
  final int seed;
  final Offset center;
  final double power;
  const _HitPainter({
    required this.t,
    required this.bad,
    required this.seed,
    required this.center,
    required this.power,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final fade = (1 - t).clamp(0.0, 1.0).toDouble();
    final e = Curves.easeOutCubic.transform(t);
    final R = min(w, h) * 0.32 * power;
    final rnd = Random(seed * 131 + 7);

    if (bad) {
      final rect = Offset.zero & size;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            radius: 0.9,
            colors: [
              Colors.transparent,
              const Color(0xFF1A1030).withValues(alpha: 0.65 * fade),
            ],
            stops: const [0.3, 1.0],
          ).createShader(rect),
      );
      final fr = R * (0.5 + e);
      canvas.drawCircle(
        center,
        fr,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFE6D6FF).withValues(alpha: 0.6 * fade * fade),
            const Color(0xFFB07CE8).withValues(alpha: 0.35 * fade),
            const Color(0xFFB07CE8).withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: center, radius: fr)),
      );
      for (var r = 0; r < 3; r++) {
        final pr = (e - r * 0.14).clamp(0.0, 1.0).toDouble();
        if (pr <= 0) continue;
        canvas.drawCircle(
          center,
          R * (0.2 + 1.3 * pr),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6 * (1 - pr) + 1
            ..color = (r == 0
                ? const Color(0xFFB07CE8)
                : r == 1
                ? EmbunColors.blood
                : Colors.white)
                .withValues(alpha: 0.85 * (1 - pr)),
        );
      }
      // retakan lebar
      final crack = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.6
        ..color = const Color(0xFFE6D6FF).withValues(alpha: fade);
      for (var k = 0; k < 10; k++) {
        final ang = rnd.nextDouble() * 2 * pi;
        final len = (R * 0.8 + rnd.nextDouble() * R * 1.4) * e;
        final path = Path()..moveTo(center.dx, center.dy);
        for (var i = 1; i <= 5; i++) {
          final f = i / 5;
          final jitter = (rnd.nextDouble() - 0.5) * 26;
          final q = center +
              Offset(cos(ang), sin(ang)) * (len * f) +
              Offset(-sin(ang), cos(ang)) * jitter;
          path.lineTo(q.dx, q.dy);
        }
        canvas.drawPath(path, crack);
      }
      // serpihan
      for (var j = 0; j < 14; j++) {
        final ang = rnd.nextDouble() * 2 * pi;
        final d0 = R * (0.3 + 0.9 * rnd.nextDouble()) * e;
        final sz = 4 + rnd.nextDouble() * 7;
        final pos = center +
            Offset(cos(ang), sin(ang)) * d0 +
            Offset(0, 80 * t * t);
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(rnd.nextDouble() * 6 + t * 5);
        final shard = Path()
          ..moveTo(0, -sz)
          ..lineTo(sz * 0.55, 0)
          ..lineTo(0, sz * 1.3)
          ..lineTo(-sz * 0.55, 0)
          ..close();
        canvas.drawPath(shard,
            Paint()..color = const Color(0xFF2A1745).withValues(alpha: fade));
        canvas.drawPath(
            shard,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = const Color(0xFFD9B8FF).withValues(alpha: fade * 0.8));
        canvas.restore();
      }
      // kepulan
      final sp = Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22)
        ..color = const Color(0xFF2A1745).withValues(alpha: 0.45 * fade);
      for (var k = 0; k < 5; k++) {
        final ang = rnd.nextDouble() * 2 * pi;
        canvas.drawCircle(
            center + Offset(cos(ang), sin(ang)) * R * 0.6 * e +
                Offset(0, -50 * e),
            R * (0.25 + 0.2 * e),
            sp);
      }
    } else {
      final gr = R * 1.3 * (0.5 + e);
      canvas.drawCircle(
        center,
        gr,
        Paint()
          ..shader = RadialGradient(colors: [
            Colors.white.withValues(alpha: 0.7 * fade * fade),
            const Color(0xFFFFD866).withValues(alpha: 0.5 * fade),
            const Color(0xFFFFD866).withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: center, radius: gr)),
      );
      for (var r = 0; r < 3; r++) {
        final pr = (e - r * 0.14).clamp(0.0, 1.0).toDouble();
        if (pr <= 0) continue;
        canvas.drawCircle(
          center,
          R * (0.2 + 1.3 * pr),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5 * (1 - pr) + 1
            ..color = (r == 0
                ? const Color(0xFFFFE08A)
                : r == 1
                ? const Color(0xFF9DF0B8)
                : Colors.white)
                .withValues(alpha: 0.85 * (1 - pr)),
        );
      }
      // sinar
      final rayLen = R * (0.8 + 1.4 * e);
      for (var j = 0; j < 12; j++) {
        final ang = j * 2 * pi / 12 + t * 0.9;
        const half = 0.06;
        final path = Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(center.dx + cos(ang - half) * rayLen,
              center.dy + sin(ang - half) * rayLen)
          ..lineTo(center.dx + cos(ang + half) * rayLen,
              center.dy + sin(ang + half) * rayLen)
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = const Color(0xFFFFE08A).withValues(alpha: 0.2 * fade),
        );
      }
      // percikan
      for (var j = 0; j < 30; j++) {
        final ang = (j / 30) * 2 * pi + rnd.nextDouble() * 0.3;
        final spd = 0.55 + rnd.nextDouble() * 0.9;
        final d0 = R * e * spd;
        final len = 6 + 20 * fade;
        final dir = Offset(cos(ang), sin(ang));
        canvas.drawLine(
          center + dir * d0,
          center + dir * (d0 + len),
          Paint()
            ..strokeWidth = 2.6 * fade + 0.6
            ..strokeCap = StrokeCap.round
            ..color = (j.isEven
                ? const Color(0xFFFFE08A)
                : const Color(0xFFBFF5D0))
                .withValues(alpha: fade),
        );
      }
      // daun melayang naik
      const greens = [
        Color(0xFF6FBF73),
        Color(0xFF8FE08F),
        Color(0xFFB9F08A),
        Color(0xFFFFE08A),
      ];
      for (var j = 0; j < 16; j++) {
        final ang = rnd.nextDouble() * 2 * pi;
        final d0 = R * (0.3 + 0.9 * rnd.nextDouble()) * e;
        final sz = 5 + rnd.nextDouble() * 6;
        final pos = center +
            Offset(cos(ang), sin(ang)) * d0 +
            Offset(sin(t * 8 + j) * 8, -70 * e);
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(rnd.nextDouble() * 6 + t * 5);
        final leaf = Path()
          ..moveTo(0, -sz)
          ..quadraticBezierTo(sz * 0.9, -sz * 0.2, 0, sz)
          ..quadraticBezierTo(-sz * 0.9, -sz * 0.2, 0, -sz);
        canvas.drawPath(
            leaf, Paint()..color = greens[j % 4].withValues(alpha: fade));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HitPainter old) => true;
}

// ====================== ledakan akhir ======================

/// Saat semua efek selesai. Sebelum ledakan (v < 0.3): butiran netral
/// tersedot ke Hayu (tanpa petunjuk hasilnya). Sesudahnya: cincin kejut
/// besar; bila Hayu bertambah/tetap, sinar emas dan percikan; bila
/// berkurang, retakan panjang dan serpihan gelap berjatuhan.
class _FinalPainter extends CustomPainter {
  final double v;
  final bool gain;
  final Offset center;
  final Color aura;
  const _FinalPainter({
    required this.v,
    required this.gain,
    required this.center,
    required this.aura,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final maxD = max(w, h);
    final rnd = Random(77);

    if (v < 0.3) {
      final pre = _seg(v, 0, 0.3);
      for (var i = 0; i < 36; i++) {
        final a0 = rnd.nextDouble() * 2 * pi;
        final r0 = maxD * (0.35 + rnd.nextDouble() * 0.4);
        final ph = rnd.nextDouble() * 0.5;
        final f = ((pre - ph * 0.5) / (1 - ph * 0.5)).clamp(0.0, 1.0).toDouble();
        final e = Curves.easeInCubic.transform(f);
        final rr = r0 * (1 - e) + 8;
        final ang = a0 + f * 3;
        final pos = center + Offset(cos(ang), sin(ang)) * rr;
        final al = sin(f * pi).clamp(0.0, 1.0).toDouble();
        canvas.drawCircle(pos, 6,
            Paint()..color = const Color(0xFFFFF1C0).withValues(alpha: 0.2 * al));
        canvas.drawCircle(pos, 2.2,
            Paint()..color = Colors.white.withValues(alpha: 0.9 * al));
      }
      return;
    }

    final s = _seg(v, 0.30, 1.0);
    final e = Curves.easeOutCubic.transform(s);
    final fade = (1 - s).clamp(0.0, 1.0).toDouble();
    final c1 = gain ? const Color(0xFFFFE08A) : const Color(0xFFB07CE8);
    final c2 = gain ? const Color(0xFF9DF0B8) : EmbunColors.blood;

    // cincin kejut besar
    for (var r = 0; r < 4; r++) {
      final pr = ((s - r * 0.07) / (1 - r * 0.07)).clamp(0.0, 1.0).toDouble();
      if (pr <= 0) continue;
      final pe = Curves.easeOutCubic.transform(pr);
      canvas.drawCircle(
        center,
        40 + maxD * 0.85 * pe,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (12 * (1 - pr)).clamp(0.5, 12.0).toDouble()
          ..color = (r.isEven ? c1 : c2)
              .withValues(alpha: (1 - pr).clamp(0.0, 1.0).toDouble()),
      );
    }

    if (gain) {
      final rayLen = maxD * (0.5 + 0.9 * e);
      for (var j = 0; j < 16; j++) {
        final ang = j * 2 * pi / 16 + s * 1.2;
        const half = 0.05;
        final path = Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(center.dx + cos(ang - half) * rayLen,
              center.dy + sin(ang - half) * rayLen)
          ..lineTo(center.dx + cos(ang + half) * rayLen,
              center.dy + sin(ang + half) * rayLen)
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = c1.withValues(alpha: 0.24 * fade),
        );
      }
      for (var j = 0; j < 70; j++) {
        final ang = rnd.nextDouble() * 2 * pi;
        final spd = 0.3 + rnd.nextDouble() * 0.9;
        final d0 = maxD * 0.5 * e * spd;
        final pos = center +
            Offset(cos(ang), sin(ang)) * d0 +
            Offset(0, 120 * s * s);
        canvas.drawCircle(
            pos,
            1.5 + rnd.nextDouble() * 3,
            Paint()
              ..color = (j.isEven ? c1 : Colors.white)
                  .withValues(alpha: (fade * 1.2).clamp(0.0, 1.0).toDouble()));
      }
    } else {
      final crack = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3
        ..color = const Color(0xFFE6D6FF).withValues(alpha: fade);
      for (var k = 0; k < 14; k++) {
        final ang = rnd.nextDouble() * 2 * pi;
        final len = maxD * (0.3 + rnd.nextDouble() * 0.5) * e;
        final path = Path()..moveTo(center.dx, center.dy);
        for (var i = 1; i <= 6; i++) {
          final f = i / 6;
          final jitter = (rnd.nextDouble() - 0.5) * 34;
          final q = center +
              Offset(cos(ang), sin(ang)) * (len * f) +
              Offset(-sin(ang), cos(ang)) * jitter;
          path.lineTo(q.dx, q.dy);
        }
        canvas.drawPath(path, crack);
      }
      for (var j = 0; j < 50; j++) {
        final ang = rnd.nextDouble() * 2 * pi;
        final d0 = maxD * (0.1 + 0.5 * rnd.nextDouble()) * e;
        final sz = 3 + rnd.nextDouble() * 7;
        final pos = center +
            Offset(cos(ang), sin(ang)) * d0 +
            Offset(0, 160 * s * s);
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(rnd.nextDouble() * 6 + s * 6);
        final shard = Path()
          ..moveTo(0, -sz)
          ..lineTo(sz * 0.55, 0)
          ..lineTo(0, sz * 1.3)
          ..lineTo(-sz * 0.55, 0)
          ..close();
        canvas.drawPath(
            shard,
            Paint()
              ..color = const Color(0xFF2A1745)
                  .withValues(alpha: (fade * 1.3).clamp(0.0, 1.0).toDouble()));
        canvas.restore();
      }
      final rect = Offset.zero & size;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            radius: 0.9,
            colors: [
              Colors.transparent,
              const Color(0xFF1A1030).withValues(alpha: 0.6 * fade),
            ],
            stops: const [0.3, 1.0],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FinalPainter old) => true;
}