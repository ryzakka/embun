import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../common/ornate.dart';

double _seg(double v, double a, double b) =>
    ((v - a) / (b - a)).clamp(0.0, 1.0).toDouble();

double _smooth(double x) => x * x * (3 - 2 * x);

/// Layar malam di antara dua hari biasa, diputar SEBELUM adegan fajar.
///
/// [rows] berasal dari `night_reports`: pengumuman untuk semua pemain
/// (user_id kosong, kind 'attack' atau 'calm') dan baris pribadi bila aku
/// menjadi korban (user_id = aku, kind 'private'). Sasaran dan jenis serangan
/// tidak pernah diumumkan ke semua orang.
///
/// Adegan: langit berbintang dengan bintang jatuh, bulan purnama, awan yang
/// lewat, siluet desa berjendela terang, pohon Hayu yang berdenyut lembut,
/// kunang-kunang, dan kabut. Saat ada serangan: layar terhentak, kilat merah,
/// retakan ungu dari langit, bulan dilahap gerhana, bintang berkedip padam,
/// jendela desa padam satu per satu, aura Hayu meredup dan daunnya gugur.
/// Malam tenang tetap hangat dan damai.
class NightScene extends StatefulWidget {
  /// Hari yang baru berakhir.
  final int day;
  final List<Map<String, dynamic>> rows;
  final VoidCallback onDone;

  const NightScene({
    super.key,
    required this.day,
    required this.rows,
    required this.onDone,
  });

  @override
  State<NightScene> createState() => _NightSceneState();
}

class _NightSceneState extends State<NightScene>
    with TickerProviderStateMixin {
  static const _intro = 1500; // ms sebelum baris pertama
  static const _perLine = 1300; // jeda antar baris
  static const _hold = 2000; // jeda setelah baris terakhir

  late final List<Map<String, dynamic>> _lines;
  late final int _total;
  late final int _attackIdx;
  late final int _privateIdx;
  late final AnimationController _tl; // garis waktu
  late final AnimationController _loop; // jam berkelanjutan untuk latar
  final List<Timer> _timers = [];
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final pub = [
      for (final r in widget.rows)
        if (r['user_id'] == null) r
    ];
    final priv = [
      for (final r in widget.rows)
        if (r['user_id'] != null) r
    ];
    _lines = [...pub, ...priv];
    _attackIdx = _lines.indexWhere((l) => l['kind'] == 'attack');
    _privateIdx = _lines.indexWhere((l) => l['kind'] == 'private');
    _total = _intro + _lines.length * _perLine + _hold;

    _tl = AnimationController(
        vsync: this, duration: Duration(milliseconds: _total))
      ..forward().whenComplete(_finish);
    _loop = AnimationController(
        vsync: this, duration: const Duration(seconds: 120))
      ..repeat();

    HapticFeedback.lightImpact();

    // Getar tiap baris muncul: berat untuk serangan, ringan untuk yang lain.
    for (var i = 0; i < _lines.length; i++) {
      _timers.add(Timer(Duration(milliseconds: _intro + i * _perLine), () {
        if (!mounted) return;
        final k = _lines[i]['kind'];
        if (k == 'attack') {
          HapticFeedback.heavyImpact();
          Future.delayed(
              const Duration(milliseconds: 140), HapticFeedback.heavyImpact);
        } else if (k == 'private') {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.selectionClick();
        }
      }));
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _tl.dispose();
    _loop.dispose();
    super.dispose();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  double _lineStart(int i) => (_intro + i * _perLine).toDouble();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF040813),
      child: AnimatedBuilder(
        animation: Listenable.merge([_tl, _loop]),
        builder: (context, _) {
          final ms = _tl.value * _total;
          final sec = _loop.value * 120;

          double pulse(double at, double len) =>
              ms < at ? 0.0 : math.exp(-(ms - at) / len * 5).toDouble();

          final atkAt = _attackIdx < 0 ? 1e9 : _lineStart(_attackIdx);
          final privAt = _privateIdx < 0 ? 1e9 : _lineStart(_privateIdx);

          // 0 -> 1 selama kegelapan merayap setelah serangan diumumkan.
          final attack = _attackIdx < 0
              ? 0.0
              : _smooth(_seg(ms, atkAt, atkAt + 1800));
          final atkPulse = _attackIdx < 0 ? 0.0 : pulse(atkAt + 80, 420);
          final atkFlash = _attackIdx < 0 ? 0.0 : pulse(atkAt + 60, 200);
          final privPulse = _privateIdx < 0 ? 0.0 : pulse(privAt + 80, 380);

          final shakeAmp = 9 * atkPulse + 3 * privPulse;
          final t = ms / 1000;
          final shake = Offset(
              math.sin(t * 95) * shakeAmp, math.cos(t * 81) * shakeAmp * 0.7);

          final intro = _smooth(_seg(ms, 0, 1000));
          final fadeIn = 1 - _smooth(_seg(ms, 0, 500));
          final fadeOut = _smooth(_seg(ms, _total - 600.0, _total.toDouble()));

          return Stack(
            fit: StackFit.expand,
            children: [
              // Dunia malam (sedikit diperbesar agar tepi tak terlihat saat getar).
              Transform.translate(
                offset: shake,
                child: Transform.scale(
                  scale: 1.06,
                  child: SizedBox.expand(
                    child: CustomPaint(
                      painter: _NightPainter(
                        sec: sec,
                        intro: intro,
                        attack: attack,
                        atkPulse: atkPulse,
                      ),
                    ),
                  ),
                ),
              ),

              // Isi: judul + baris laporan.
              Transform.translate(
                offset: shake * 1.3,
                child: SafeArea(child: _content(ms, atkPulse, attack)),
              ),

              // Kilatan.
              if (atkFlash > 0.01)
                IgnorePointer(
                  child: ColoredBox(
                    color: EmbunColors.blood
                        .withValues(alpha: (0.42 * atkFlash).clamp(0.0, 1.0)),
                  ),
                ),
              if (privPulse > 0.01)
                IgnorePointer(
                  child: ColoredBox(
                    color: EmbunColors.gold
                        .withValues(alpha: (0.10 * privPulse).clamp(0.0, 1.0)),
                  ),
                ),

              // Vinyet.
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 1.0,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.55),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
              ),

              if (fadeIn > 0.01)
                IgnorePointer(
                  child: ColoredBox(
                      color: Colors.black.withValues(alpha: fadeIn)),
                ),
              if (fadeOut > 0.01)
                IgnorePointer(
                  child: ColoredBox(
                      color: const Color(0xFF040813)
                          .withValues(alpha: fadeOut)),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _content(double ms, double atkPulse, double attack) {
    final titleCol = Color.lerp(
        const Color(0xFFE8EDFF), const Color(0xFFFFD9DD), attack)!;
    final titleGlow = Color.lerp(
        const Color(0xFF7FA8FF), EmbunColors.blood, attack)!;
    const word = 'MALAM';
    final subA = _smooth(_seg(ms, 750, 1250));
    final ornA = _smooth(_seg(ms, 500, 1300));

    Widget letter(int i) {
      final lt = _smooth(_seg(ms, 150 + i * 120.0, 650 + i * 120.0));
      return Opacity(
        opacity: lt,
        child: Transform.translate(
          offset: Offset(0, (1 - lt) * -26),
          child: Transform.scale(
            scale: 1.6 - 0.6 * lt,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 3 + 9 * (1 - lt)),
              child: Text(
                word[i],
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: titleCol,
                  shadows: [
                    Shadow(
                        color: titleGlow.withValues(
                            alpha: 0.55 + 0.35 * atkPulse),
                        blurRadius: 18 + 16 * atkPulse),
                    const Shadow(color: Colors.black, blurRadius: 6),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 6, 8, 0),
            child: TextButton.icon(
              onPressed: _finish,
              icon: const Icon(Icons.fast_forward_rounded, size: 20),
              label: const Text('Lewati'),
              style: TextButton.styleFrom(foregroundColor: Colors.white54),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [for (var i = 0; i < word.length; i++) letter(i)],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 140 * ornA,
                      height: 1.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.transparent,
                          titleGlow.withValues(alpha: 0.8),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: subA,
                      child: Text(
                        'Hari ${widget.day} berlalu',
                        style: const TextStyle(
                            fontSize: 13.5,
                            letterSpacing: 1.2,
                            color: Colors.white60),
                      ),
                    ),
                    const SizedBox(height: 26),
                    for (var i = 0; i < _lines.length; i++)
                      _line(_lines[i], i, ms, atkPulse),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _line(Map<String, dynamic> l, int i, double ms, double atkPulse) {
    final kind = '${l['kind']}';
    final text = '${l['text']}';
    final a = _seg(ms, _lineStart(i), _lineStart(i) + 520);
    final Color color;
    final IconData icon;
    String? tag;
    switch (kind) {
      case 'attack':
        color = EmbunColors.blood;
        icon = Icons.warning_amber_rounded;
        tag = 'BAHAYA';
      case 'private':
        color = EmbunColors.gold;
        icon = Icons.lock_rounded;
        tag = 'Hanya kamu yang tahu';
      default:
        color = const Color(0xFF8FD6B0);
        icon = Icons.bedtime_rounded;
    }
    final isAtk = kind == 'attack';
    final pop = Curves.elasticOut.transform(_seg(a, 0.0, 1.0));

    final offset = switch (kind) {
      'attack' => Offset(0, 0),
      'private' => Offset(0, 22 * (1 - a)),
      _ => Offset(0, 14 * (1 - a)),
    };
    final scale = isAtk ? 1.22 - 0.22 * Curves.easeOutCubic.transform(a) : 1.0;

    return Opacity(
      opacity: a,
      child: Transform.translate(
        offset: offset,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  color.withValues(alpha: isAtk ? 0.22 : 0.14),
                  color.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: color.withValues(alpha: 0.75),
                  width: isAtk ? 1.4 + 1.6 * atkPulse : 1.4),
              boxShadow: isAtk
                  ? [
                BoxShadow(
                    color: color.withValues(alpha: 0.3 + 0.4 * atkPulse),
                    blurRadius: 24 + 30 * atkPulse,
                    spreadRadius: 2 * atkPulse),
              ]
                  : [
                BoxShadow(
                    color: color.withValues(alpha: 0.12),
                    blurRadius: 14),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform.scale(
                  scale: (0.3 + 0.7 * pop).clamp(0.1, 1.5).toDouble(),
                  child: Icon(icon, size: 28, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (tag != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(tag,
                              style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: isAtk ? 3 : 0.6,
                                  fontWeight: FontWeight.w800,
                                  color: color)),
                        ),
                      Text(text,
                          style: TextStyle(
                              fontSize: isAtk ? 16.5 : 15.5,
                              height: 1.35,
                              fontWeight:
                              isAtk ? FontWeight.w800 : FontWeight.w600,
                              color: Colors.white)),
                    ],
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

/// Seluruh dunia malam dalam satu kanvas.
class _NightPainter extends CustomPainter {
  final double sec; // detik, berjalan terus
  final double intro; // 0..1 saat adegan masuk
  final double attack; // 0..1 kegelapan merayap (serangan)
  final double atkPulse; // 0..1 denyut saat serangan menghantam

  const _NightPainter({
    required this.sec,
    required this.intro,
    required this.attack,
    required this.atkPulse,
  });

  static final List<List<double>> _stars = () {
    final r = math.Random(11);
    return [
      for (var i = 0; i < 110; i++)
        [
          r.nextDouble(),
          r.nextDouble() * 0.62,
          0.5 + r.nextDouble() * 1.4,
          r.nextDouble() * math.pi * 2,
          0.5 + r.nextDouble() * 1.5,
        ],
    ];
  }();

  static final List<List<double>> _flies = () {
    final r = math.Random(4);
    return [
      for (var i = 0; i < 16; i++)
        [
          r.nextDouble(),
          r.nextDouble(),
          r.nextDouble() * math.pi * 2,
          1 + r.nextDouble() * 2,
          1.2 + r.nextDouble() * 1.8,
        ],
    ];
  }();

  static final List<List<double>> _leaves = () {
    final r = math.Random(21);
    return [
      for (var i = 0; i < 18; i++)
        [
          r.nextDouble() - 0.5,
          r.nextDouble(),
          0.6 + r.nextDouble() * 0.8,
          3 + r.nextDouble() * 3,
        ],
    ];
  }();

  double _hill(double x, double w, double h) =>
      h * 0.80 +
          math.sin(x / w * math.pi * 2 + 0.6) * h * 0.018 +
          math.sin(x / w * math.pi * 5 + 1.3) * h * 0.007;

  double _hill2(double x, double w, double h) =>
      h * 0.89 + math.sin(x / w * math.pi * 3 + 2.0) * h * 0.016;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;

    // ---------------- langit ----------------
    final top = Color.lerp(
        const Color(0xFF040813), const Color(0xFF12041A), attack)!;
    final mid = Color.lerp(
        const Color(0xFF0A1330), const Color(0xFF2A0A30), attack)!;
    final bot = Color.lerp(
        const Color(0xFF16254A), const Color(0xFF4A1233), attack)!;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
            Offset.zero, Offset(0, h), [top, mid, bot], [0.0, 0.55, 1.0]),
    );

    // ---------------- bintang ----------------
    final sp = Paint();
    for (final s in _stars) {
      final x = (s[0] * w + sec * 1.2 * s[2]) % w;
      final y = s[1] * h;
      final tw = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(sec * s[4] * 1.6 + s[3]));
      // Saat serangan: bintang berkedip kacau lalu padam.
      final flick = 1 -
          attack * (0.35 + 0.65 * (0.5 + 0.5 * math.sin(sec * 26 + s[3] * 3)));
      final a = (0.8 * tw * flick * intro * (1 - 0.55 * attack))
          .clamp(0.0, 1.0)
          .toDouble();
      sp.color = Colors.white.withValues(alpha: a);
      canvas.drawCircle(Offset(x, y), s[2], sp);
    }

    // ---------------- bintang jatuh ----------------
    if (attack < 0.3) {
      const cycle = 11.0;
      final k = (sec / cycle).floor();
      final ph = (sec % cycle) / cycle;
      if (ph < 0.07) {
        final t = ph / 0.07;
        final sx = w * (0.08 + 0.45 * (((k * 37) % 10) / 10));
        final head = Offset(sx + w * 0.32 * t, h * 0.06 + w * 0.15 * t);
        final tail = head - Offset(w * 0.10, w * 0.05);
        canvas.drawLine(
          tail,
          head,
          Paint()
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.round
            ..shader = ui.Gradient.linear(tail, head, [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.9 * (1 - t) * intro),
            ]),
        );
      }
    }

    // ---------------- bulan ----------------
    final r = math.min(w, h) * 0.11;
    final moonIn = Curves.easeOut.transform(intro);
    final mc = Offset(w * 0.74, h * 0.2 + (1 - moonIn) * h * 0.06);
    final tint = Color.lerp(
        const Color(0xFFF3E9B8), const Color(0xFFE5645A), attack * 0.85)!;
    canvas.drawCircle(
      mc,
      r * 3.6,
      Paint()
        ..shader = ui.Gradient.radial(mc, r * 3.6, [
          tint.withValues(alpha: (0.34 * (1 - 0.45 * attack)) * moonIn),
          tint.withValues(alpha: 0),
        ]),
    );
    final moonCol = Color.lerp(
        const Color(0xFFF6EDBF), const Color(0xFFE0745F), attack * 0.7)!;
    canvas.drawCircle(
        mc, r, Paint()..color = moonCol.withValues(alpha: 0.95 * moonIn));
    for (final k in const [
      [-0.3, -0.25, 0.22],
      [0.28, 0.12, 0.16],
      [-0.08, 0.42, 0.12],
    ]) {
      canvas.drawCircle(mc + Offset(k[0] * r, k[1] * r), k[2] * r,
          Paint()..color = Colors.black.withValues(alpha: 0.08 * moonIn));
    }
    // Gerhana: piringan gelap menggeser menutupi bulan.
    if (attack > 0.01) {
      final e = Curves.easeInOut.transform(attack);
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: mc, radius: r)));
      canvas.drawCircle(
        mc + Offset(-r * 2.3 * (1 - e), -r * 0.15 * (1 - e)),
        r * 1.02,
        Paint()..color = const Color(0xFF12040C).withValues(alpha: 0.96),
      );
      canvas.restore();
      // Cincin korona merah di tepi bulan.
      canvas.drawCircle(
        mc,
        r * 1.06,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
          ..color = EmbunColors.blood
              .withValues(alpha: (0.7 * attack * (0.7 + 0.3 * atkPulse))
              .clamp(0.0, 1.0)),
      );
    }

    // ---------------- awan ----------------
    final cloudCol = Color.lerp(
        const Color(0xFF2A3A66), const Color(0xFF3A1030), attack)!;
    final cp = Paint()
      ..color = cloudCol.withValues(alpha: 0.24 * intro)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26);
    for (var i = 0; i < 3; i++) {
      final x = ((sec * (6 + i * 3) + i * w * 0.45) % (w * 1.6)) - w * 0.3;
      final y = h * (0.15 + 0.10 * i);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(x, y), width: w * 0.55, height: h * 0.05),
          cp);
    }

    // ---------------- bukit belakang ----------------
    final hillPath = Path()..moveTo(0, h);
    for (double x = 0; x <= w + 6; x += 6) {
      hillPath.lineTo(x, _hill(x, w, h));
    }
    hillPath.lineTo(w, h);
    hillPath.close();
    canvas.drawPath(
      hillPath,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, h * 0.75), Offset(0, h), [
          Color.lerp(const Color(0xFF0B1630), const Color(0xFF1A0A24), attack)!,
          const Color(0xFF050A14),
        ]),
    );

    // ---------------- rumah desa ----------------
    final u = math.min(w, h);
    final bw = u * 0.055, bh = bw * 0.8, rh = bw * 0.5;
    const hx = [0.50, 0.61, 0.73, 0.85];
    for (var i = 0; i < hx.length; i++) {
      final x = w * hx[i];
      final by = _hill(x, w, h) + 2;
      final body = Rect.fromLTWH(x - bw / 2, by - bh, bw, bh);
      canvas.drawRect(body, Paint()..color = const Color(0xFF040810));
      canvas.drawPath(
        Path()
          ..moveTo(x - bw * 0.62, by - bh)
          ..lineTo(x, by - bh - rh)
          ..lineTo(x + bw * 0.62, by - bh)
          ..close(),
        Paint()..color = const Color(0xFF03060D),
      );
      // Jendela padam satu per satu saat serangan.
      final thresh = 0.18 + 0.2 * i;
      var lit = attack < thresh
          ? 0.85 + 0.15 * math.sin(sec * 3 + i * 2)
          : 0.0;
      if (attack >= thresh && attack < thresh + 0.12) {
        lit = math.sin(sec * 40 + i) > 0 ? 0.6 : 0.0; // kedip terakhir
      }
      lit *= intro;
      if (lit > 0.01) {
        final win = Rect.fromCenter(
            center: Offset(x, by - bh * 0.5), width: bw * 0.3, height: bw * 0.3);
        canvas.drawCircle(
          win.center,
          bw * 1.1,
          Paint()
            ..shader = ui.Gradient.radial(win.center, bw * 1.1, [
              const Color(0xFFFFC857).withValues(alpha: 0.28 * lit),
              const Color(0xFFFFC857).withValues(alpha: 0),
            ]),
        );
        canvas.drawRect(win,
            Paint()..color = const Color(0xFFFFD27A).withValues(alpha: lit));
      }
    }

    // ---------------- pohon Hayu ----------------
    final tx = w * 0.20;
    final baseY = _hill(tx, w, h);
    final th = h * 0.06;
    final ch = h * 0.045;
    final trunkW = h * 0.011;
    final canopyBase = baseY - th;
    final treeCol = Color.lerp(
        const Color(0xFF06101A), const Color(0xFF0A0610), attack)!;

    // Aura hidup yang berdenyut; meredup dan tersendat saat serangan.
    final beat = 0.8 + 0.2 * math.sin(sec * 2.2);
    final stutter = attack > 0.05
        ? (0.55 + 0.45 * math.sin(sec * 17).abs())
        : 1.0;
    final auraA =
    (0.16 * beat * (1 - attack * 0.9) * stutter * intro).clamp(0.0, 1.0);
    final ac = Offset(tx, canopyBase - ch * 0.4);
    canvas.drawCircle(
      ac,
      ch * 3.6,
      Paint()
        ..shader = ui.Gradient.radial(ac, ch * 3.6, [
          const Color(0xFF7FE0A0).withValues(alpha: auraA),
          const Color(0xFF7FE0A0).withValues(alpha: 0),
        ]),
    );

    canvas.drawPath(
      Path()
        ..moveTo(tx - trunkW, baseY + 2)
        ..lineTo(tx - trunkW * 0.55, canopyBase)
        ..lineTo(tx + trunkW * 0.55, canopyBase)
        ..lineTo(tx + trunkW, baseY + 2)
        ..close(),
      Paint()..color = treeCol,
    );
    const crown = [
      [0.0, 0.2, 1.0],
      [-0.9, 0.0, 0.7],
      [0.9, 0.05, 0.75],
      [-0.4, 0.9, 0.7],
      [0.45, 0.85, 0.65],
    ];
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFFBFD4FF)
          .withValues(alpha: 0.28 * (1 - attack) * intro);
    final fill = Paint()..color = treeCol;
    for (final c in crown) {
      final p = Offset(tx + c[0] * ch, canopyBase - c[1] * ch);
      canvas.drawCircle(p, c[2] * ch, fill);
      canvas.drawCircle(p, c[2] * ch, rim);
    }

    // Daun gugur saat serangan.
    if (attack > 0.05) {
      final lp = Paint();
      for (var i = 0; i < _leaves.length; i++) {
        final s = _leaves[i];
        final f = (sec * 0.22 * s[2] + s[1]) % 1.0;
        final al = (attack * math.sin(f * math.pi) * 0.85).clamp(0.0, 1.0);
        final x = tx + s[0] * ch * 3.2 + math.sin(f * 6 + s[1] * 6) * ch * 0.5 +
            f * ch * 1.6;
        final y = canopyBase - ch + f * (baseY - canopyBase + ch * 1.4);
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(f * 9 + s[1] * 6);
        canvas.scale(1, 0.35 + 0.65 * math.cos(f * 11 + s[1] * 5).abs());
        final sz = s[3];
        lp.color = const Color(0xFF9A6A3A).withValues(alpha: al);
        canvas.drawPath(
          Path()
            ..moveTo(0, -sz)
            ..quadraticBezierTo(sz * 0.9, -sz * 0.2, 0, sz)
            ..quadraticBezierTo(-sz * 0.9, -sz * 0.2, 0, -sz),
          lp,
        );
        canvas.restore();
      }
    }

    // ---------------- bukit depan ----------------
    final front = Path()..moveTo(0, h);
    for (double x = 0; x <= w + 6; x += 6) {
      front.lineTo(x, _hill2(x, w, h));
    }
    front.lineTo(w, h);
    front.close();
    canvas.drawPath(front, Paint()..color = const Color(0xFF03060D));

    // ---------------- kunang-kunang ----------------
    final fa = (1 - attack * 1.3).clamp(0.0, 1.0) * intro;
    if (fa > 0.01) {
      final fp = Paint();
      for (var i = 0; i < _flies.length; i++) {
        final s = _flies[i];
        final x = (s[0] + math.sin(sec * 0.3 + s[2]) * 0.03) * w;
        final y = h * (0.80 + 0.15 * s[1]) + math.sin(sec * 0.6 + s[2]) * 9;
        final a = (0.35 + 0.65 * (0.5 + 0.5 * math.sin(sec * s[3] + s[2]))) * fa;
        final col = i.isEven ? const Color(0xFFFFE08A) : const Color(0xFFBFF5D0);
        fp.color = col.withValues(alpha: 0.16 * a);
        canvas.drawCircle(Offset(x, y), s[4] * 3.2, fp);
        fp.color = Color.lerp(col, Colors.white, 0.5)!.withValues(alpha: 0.9 * a);
        canvas.drawCircle(Offset(x, y), s[4], fp);
      }
    }

    // ---------------- kabut ----------------
    final fogCol = Color.lerp(
        const Color(0xFFB8C8E8), const Color(0xFF9A5CC8), attack)!;
    final fogP = Paint()
      ..color = fogCol.withValues(alpha: (0.07 + 0.09 * attack) * intro)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    for (var i = 0; i < 3; i++) {
      final dir = i.isEven ? 1.0 : -1.0;
      final x = (i * 0.35 + sec * 0.012 * dir) % 1.3 - 0.15;
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(w * x, h * (0.80 + 0.06 * i)),
              width: w * 1.1,
              height: h * 0.10),
          fogP);
    }

    // ---------------- retakan ungu dari langit saat serangan menghantam ----
    if (atkPulse > 0.02) {
      final rnd = math.Random(8);
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..color = const Color(0xFFB07CE8).withValues(alpha: 0.6 * atkPulse);
      final core = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFF1E6FF).withValues(alpha: 0.95 * atkPulse);
      for (var k = 0; k < 4; k++) {
        var x = w * (0.12 + 0.76 * rnd.nextDouble());
        var y = 0.0;
        final path = Path()..moveTo(x, y);
        final steps = 7;
        final len = h * (0.22 + 0.2 * rnd.nextDouble());
        for (var i = 0; i < steps; i++) {
          x += (rnd.nextDouble() - 0.5) * w * 0.07;
          y += len / steps;
          path.lineTo(x, y);
        }
        canvas.drawPath(path, glow);
        canvas.drawPath(path, core);
      }
    }

    // ---------------- selubung gelap merayap dari tepi ----------------
    final creep = (0.55 * attack + 0.3 * atkPulse).clamp(0.0, 1.0);
    if (creep > 0.01) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(
            size.center(Offset.zero),
            math.max(w, h) * 0.75,
            [
              Colors.transparent,
              const Color(0xFF2A0620).withValues(alpha: creep),
            ],
            [0.35, 1.0],
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NightPainter old) => true;
}