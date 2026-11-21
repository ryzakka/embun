import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/melody_rules.dart';
import 'melody_art.dart';

/// Geometri bersama: jalur, garis penilaian, dan waktu tempuh ketukan.
const double kMelodyLineRatio = .84;
const double kMelodyTravelMs = 1800;

const _gold = Color(0xFFE8C766);
const _mist = Color(0xFFB07CE8);
const _teal = Color(0xFF70C4D5);
const _blood = Color(0xFFE5645A);
const _cream = Color(0xFFF3E9C6);

/// Warna tiap kelompok nilai (0..6), dari kelabu sampai emas terang.
Color melodyTierColor(int tier) => const [
  Color(0xFF8FA39C),
  Color(0xFF9ECEC1),
  Color(0xFF8AD17D),
  Color(0xFF70C4D5),
  Color(0xFFDFB75D),
  Color(0xFFE8C766),
  Color(0xFFFFE9A6),
][tier.clamp(0, 6).toInt()];

/// Tingkat efek yang dipilih pemain: 0 teks saja, 1 ringan, 2 penuh.
/// Disimpan di perangkat supaya pemain yang sensitif cukup memilih sekali.
class MelodyFxLevel {
  static final ValueNotifier<int> level = ValueNotifier<int>(2);
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getInt('melody_fx_level');
      if (v != null) {
        level.value = v.clamp(0, 2).toInt();
      }
    } catch (_) {}
  }

  /// Penuh -> ringan -> teks saja -> penuh.
  static Future<void> cycle() async {
    level.value = (level.value + 2) % 3;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('melody_fx_level', level.value);
    } catch (_) {}
  }

  static String label(int v) =>
      const ['Efek: teks saja', 'Efek: ringan', 'Efek: penuh'][v.clamp(0, 2)];
}

enum MelodyHitKind { perfect, good, stray, broken, milestone, streak }

class _Spawn {
  _Spawn(this.lane, this.kind, this.hold, [this.value = 0]);
  final int lane;
  final MelodyHitKind kind;
  final bool hold;
  final int value;
}

class _Spark {
  _Spark({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.size,
    required this.g,
    required this.color,
  });
  double x, y, vx, vy, life, size, g;
  double age = 0;
  Color color;
}

class _Ring {
  _Ring(
    this.x,
    this.y,
    this.life,
    this.maxR,
    this.width,
    this.color,
    this.flat,
  );
  final double x, y, life, maxR, width;
  final Color color;
  final bool flat;
  double age = 0;
}

class _Pop {
  _Pop(this.x, this.y, this.text, this.color, this.size);
  final double x, y, size;
  final String text;
  final Color color;
  double age = 0;
}

class _Banner {
  _Banner(this.title, this.sub, this.color);
  final String title, sub;
  final Color color;
  double age = 0;
}

/// Mesin efek: menampung peristiwa ketukan lalu mensimulasikan percikan,
/// gelombang, teks penilaian, dan getaran. Digambar oleh painter di bawah.
/// Semua gerak mati otomatis pada tingkat 0 atau saat animasi dikurangi.
class MelodyFxController {
  MelodyFxController({required this.laneColors});
  final List<Color> laneColors;

  int level = 2;
  bool reduced = false, antag = false;
  int pressure = 0;
  int combo = 0;
  Set<int> held = const {};

  final List<double> laneGlow = List<double>.filled(4, 0);
  final Set<int> _down = <int>{};
  double energy = 0, shake = 0, comboPulse = 0, hitPulse = 0, breakPulse = 0;
  double flash = 0;
  final List<double> laneFlash = List<double>.filled(4, 0);
  double time = 0;
  double _dt = 0, _last = 0;
  final Stopwatch _sw = Stopwatch()..start();
  final List<_Spawn> _pending = [];
  final List<_Spark> _sparks = [];
  final List<_Ring> _rings = [];
  final List<_Pop> _pops = [];
  final Map<int, double> _holdAcc = {};
  _Banner? _banner;
  final math.Random _rng = math.Random(11);

  bool get motion => level > 0 && !reduced;
  double get _amount => level >= 2 ? 1.0 : .45;

  Offset get shakeOffset => (!motion || shake <= 0)
      ? Offset.zero
      : Offset(
          math.sin(time * 41) * shake * (level >= 2 ? 7 : 3),
          math.cos(time * 33) * shake * (level >= 2 ? 5 : 2.5),
        );

  void reset() {
    _pending.clear();
    _sparks.clear();
    _rings.clear();
    _pops.clear();
    _holdAcc.clear();
    _down.clear();
    _banner = null;
    held = const {};
    combo = 0;
    energy = shake = comboPulse = hitPulse = breakPulse = flash = 0;
    for (var i = 0; i < laneGlow.length; i++) {
      laneGlow[i] = 0;
      laneFlash[i] = 0;
    }
  }

  void press(int lane, bool down) {
    if (down) {
      _down.add(lane);
    } else {
      _down.remove(lane);
    }
  }

  void hit(int lane, MelodyHitKind kind, {bool hold = false}) {
    if (_pending.length > 24) {
      return;
    }
    _pending.add(_Spawn(lane, kind, hold));
    if (kind == MelodyHitKind.perfect) {
      hitPulse = 1;
    } else if (kind == MelodyHitKind.good) {
      hitPulse = math.max(hitPulse, .55);
    }
  }

  /// Dipanggil tiap frame dengan kombo terbaru dari juri.
  void setCombo(int c) {
    if (c == combo) {
      return;
    }
    if (c > combo) {
      comboPulse = 1;
      final m = c ~/ 15;
      if (m > combo ~/ 15) {
        _milestone(m * 15);
      } else if (c >= 5 && c ~/ 5 > combo ~/ 5) {
        _pending.add(_Spawn(-2, MelodyHitKind.streak, false, c ~/ 5 * 5));
      }
    } else if (c == 0 && combo >= 3) {
      _pending.add(_Spawn(-1, MelodyHitKind.broken, false, combo));
      breakPulse = 1;
      shake = math.max(shake, combo >= 15 ? 1.0 : .8);
    }
    combo = c;
  }

  void _milestone(int c) {
    final tier = ((c ~/ 15) - 1).clamp(0, 3).toInt();
    final good = const [
      Color(0xFF8AD17D),
      Color(0xFF70C4D5),
      Color(0xFFE8C766),
      Color(0xFFFFE9A6),
    ];
    final dark = const [
      Color(0xFFB07CE8),
      Color(0xFFC99BFF),
      Color(0xFFE4CDFF),
      Color(0xFFFFFFFF),
    ];
    final names = antag
        ? const [
            'Bisikan menguat',
            'Irama retak',
            'Gema bayangan',
            'Malam bergema',
          ]
        : const ['Selaras', 'Harmoni', 'Gema Hayu', 'Ritual Agung'];
    _banner = _Banner(
      antag ? 'GANGGUAN $c' : 'KOMBO $c',
      names[tier],
      antag ? dark[tier] : good[tier],
    );
    shake = math.max(shake, 1.1);
    flash = 1;
    _pending.add(_Spawn(-2, MelodyHitKind.milestone, false, tier));
  }

  /// Maju satu langkah waktu. Dipanggil sekali per frame oleh painter latar.
  void advance() {
    final now = _sw.elapsedMicroseconds / 1e6;
    var dt = now - _last;
    if (dt <= 0) {
      return;
    }
    _last = now;
    dt = math.min(dt, .05);
    _dt = dt;
    time = now;
    for (var l = 0; l < 4; l++) {
      final target = _down.contains(l) ? 1.0 : 0.0;
      final rate = target > laneGlow[l] ? 20.0 : 5.0;
      laneGlow[l] += (target - laneGlow[l]) * math.min(1.0, dt * rate);
    }
    final et = (combo / 45).clamp(0.0, 1.0).toDouble();
    energy += (et - energy) * math.min(1.0, dt * 2.5);
    shake *= math.exp(-dt * 7);
    if (shake < .01) {
      shake = 0;
    }
    comboPulse *= math.exp(-dt * 6);
    hitPulse *= math.exp(-dt * 9);
    breakPulse *= math.exp(-dt * 2.6);
    flash *= math.exp(-dt * 4.5);
    for (var l = 0; l < 4; l++) {
      laneFlash[l] *= math.exp(-dt * 6);
    }
    for (final s in _sparks) {
      s.age += dt;
      s.vy += s.g * dt;
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.vx *= math.max(0.0, 1 - dt * 1.4);
    }
    _sparks.removeWhere((s) => s.age >= s.life);
    for (final r in _rings) {
      r.age += dt;
    }
    _rings.removeWhere((r) => r.age >= r.life);
    for (final p in _pops) {
      p.age += dt;
    }
    _pops.removeWhere((p) => p.age >= .8);
    final b = _banner;
    if (b != null) {
      b.age += dt;
      if (b.age > 2.0) {
        _banner = null;
      }
    }
  }

  void _spark(
    double x,
    double y,
    Color c, {
    double speed = 300,
    double spread = .84,
    double down = 0,
  }) {
    if (_sparks.length > 340) {
      return;
    }
    final a = -math.pi * (.08 + _rng.nextDouble() * spread);
    final v = speed * (.35 + _rng.nextDouble() * .9);
    _sparks.add(
      _Spark(
        x: x + (_rng.nextDouble() - .5) * 10,
        y: y,
        vx: math.cos(a) * v,
        vy: math.sin(a) * v + down,
        life: .45 + _rng.nextDouble() * .5,
        size: 1.8 + _rng.nextDouble() * 3,
        g: 620,
        color: Color.lerp(c, Colors.white, _rng.nextDouble() * .6)!,
      ),
    );
  }

  void _pop(double x, double y, String text, Color c, double size) {
    if (_pops.length > 12) {
      _pops.removeAt(0);
    }
    _pops.add(_Pop(x, y, text, c, size));
  }

  /// Ubah peristiwa tertunda menjadi percikan, saat ukuran layar diketahui.
  void flush(Size size) {
    final w = size.width / 4;
    final line = size.height * kMelodyLineRatio;
    for (final s in _pending) {
      _burst(s, w, line, size.width, size.height);
    }
    _pending.clear();
    if (motion && held.isNotEmpty) {
      for (final lane in held) {
        final acc = (_holdAcc[lane] ?? 0) + _dt * (level >= 2 ? 38 : 16);
        var n = acc.floor();
        _holdAcc[lane] = acc - n;
        while (n-- > 0) {
          _spark((lane + .5) * w, line, laneColors[lane], speed: 200);
        }
      }
    }
  }

  void _radial(double cx, double cy, Color c, int n, double speed) {
    for (var i = 0; i < n; i++) {
      if (_sparks.length > 340) {
        return;
      }
      final a = _rng.nextDouble() * math.pi * 2;
      final v = speed * (.3 + _rng.nextDouble() * .9);
      _sparks.add(
        _Spark(
          x: cx,
          y: cy,
          vx: math.cos(a) * v,
          vy: math.sin(a) * v,
          life: .7 + _rng.nextDouble() * .7,
          size: 2 + _rng.nextDouble() * 3.5,
          g: 260,
          color: Color.lerp(c, Colors.white, _rng.nextDouble() * .6)!,
        ),
      );
    }
  }

  void _burst(_Spawn s, double w, double line, double fullW, double h) {
    final x = (s.lane + .5) * w;
    final col = laneColors[s.lane.clamp(0, 3).toInt()];
    final light = Color.lerp(col, Colors.white, .55)!;
    switch (s.kind) {
      case MelodyHitKind.perfect:
        _pop(x, line - 80, 'TEPAT!', light, 28);
        laneFlash[s.lane.clamp(0, 3).toInt()] = 1;
        if (motion) {
          _rings.add(_Ring(x, line, .7, w * .9, 6, col, false));
          _rings.add(_Ring(x, line, .5, w * .55, 4, Colors.white, false));
          _rings.add(_Ring(x, line, .34, w * .6, 0, col, true));
          final n = (32 * _amount).round();
          for (var i = 0; i < n; i++) {
            _spark(x, line, col, speed: 540);
          }
        }
      case MelodyHitKind.good:
        _pop(x, line - 72, 'Bagus', col, 20);
        laneFlash[s.lane.clamp(0, 3).toInt()] = .5;
        if (motion) {
          _rings.add(_Ring(x, line, .5, w * .55, 4, col, false));
          _rings.add(_Ring(x, line, .35, w * .45, 0, col, true));
          final n = (14 * _amount).round();
          for (var i = 0; i < n; i++) {
            _spark(x, line, col, speed: 340);
          }
        }
      case MelodyHitKind.stray:
        if (motion) {
          for (var i = 0; i < 3; i++) {
            _spark(x, line, Colors.white54, speed: 160);
          }
        }
      case MelodyHitKind.broken:
        _pop(fullW / 2, line - 110, 'IRAMA TERPUTUS', _blood, 28);
        if (s.value >= 10) {
          _pop(fullW / 2, line - 76, 'Kombo ${s.value} lenyap', _cream, 16);
        }
        if (motion) {
          _rings.add(_Ring(fullW / 2, line, .7, fullW * .5, 5, _blood, false));
          final n = (30 * _amount).round();
          for (var i = 0; i < n; i++) {
            _sparks.add(
              _Spark(
                x: _rng.nextDouble() * fullW,
                y: line - 10,
                vx: (_rng.nextDouble() - .5) * 70,
                vy: -60 + _rng.nextDouble() * 200,
                life: .9,
                size: 2 + _rng.nextDouble() * 3,
                g: 480,
                color: Color.lerp(
                  _blood,
                  Colors.white,
                  _rng.nextDouble() * .3,
                )!,
              ),
            );
          }
        }
      case MelodyHitKind.streak:
        _pop(
          fullW / 2,
          h * .2 - 64,
          '${s.value} KOMBO!',
          Color.lerp(antag ? _mist : _gold, Colors.white, .35)!,
          24,
        );
        if (motion) {
          _radial(
            fullW / 2,
            h * .2,
            antag ? _mist : _gold,
            (20 * _amount).round(),
            280,
          );
        }
      case MelodyHitKind.milestone:
        final c = _banner?.color ?? (antag ? _mist : _gold);
        if (motion) {
          _rings.add(_Ring(fullW / 2, h * .36, .9, fullW * .45, 7, c, false));
          _rings.add(
            _Ring(fullW / 2, h * .36, .7, fullW * .3, 4, Colors.white, false),
          );
          _rings.add(_Ring(fullW / 2, h * .36, 1.1, fullW * .6, 2.5, c, false));
          _radial(fullW / 2, h * .36, c, (80 * _amount).round(), 430);
          _radial(fullW * .22, h * .3, c, (30 * _amount).round(), 300);
          _radial(fullW * .78, h * .3, c, (30 * _amount).round(), 300);
        }
    }
  }
}

void _text(Canvas c, String s, Offset center, TextStyle style) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: style),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout();
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
}

/// Lapisan paling bawah: cahaya suasana, berkas cahaya tiap jalur, debu
/// cahaya yang melayang, dan pinggiran ungu saat bisikan menekan.
class MelodyBackdropPainter extends CustomPainter {
  MelodyBackdropPainter(this.fx);
  final MelodyFxController fx;

  @override
  void paint(Canvas canvas, Size size) {
    fx.advance();
    final w = size.width, h = size.height, lw = w / 4;
    final line = h * kMelodyLineRatio;
    final e = fx.energy;
    final tint = Color.lerp(
      fx.antag ? _mist : _teal,
      fx.antag ? const Color(0xFFE4CDFF) : _gold,
      e,
    )!;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(0, line / h * 2 - 1),
          radius: 1.25,
          colors: [
            tint.withValues(
              alpha: (.10 + .20 * e + .12 * fx.hitPulse).clamp(0.0, 1.0),
            ),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
    MelodyArtCache.shared.paint(
      canvas,
      'melodi-garismelodi',
      Rect.fromLTWH(w * .08, 8, w * .84, math.min(70, h * .16)),
      opacity: .16,
    );
    if (fx.level > 0) {
      for (var lane = 0; lane < 4; lane++) {
        final g = fx.laneGlow[lane];
        if (g < .02) {
          continue;
        }
        final col = fx.laneColors[lane];
        final top = line - h * (.45 + .35 * g);
        final r = Rect.fromLTRB(
          lane * lw + lw * .1,
          top,
          (lane + 1) * lw - lw * .1,
          line,
        );
        canvas.drawRect(
          r,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                col.withValues(alpha: .38 * g),
                Colors.transparent,
              ],
            ).createShader(r),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset((lane + .5) * lw, line),
            width: lw * 1.1,
            height: 26,
          ),
          Paint()
            ..blendMode = BlendMode.plus
            ..color = col.withValues(alpha: .35 * g),
        );
      }
    }
    if (fx.motion) {
      final n = fx.level >= 2 ? 26 : 12;
      for (var i = 0; i < n; i++) {
        final s1 = (i * .6180339) % 1.0;
        final s2 = (i * .7548777) % 1.0;
        final speed = .03 + .05 * s2 + .04 * e;
        final yy = 1 - ((fx.time * speed + s1) % 1.0);
        final xx = (s2 + math.sin(fx.time * .4 + i) * .02) % 1.0;
        final tw = .5 + .5 * math.sin(fx.time * 1.3 + i * 2.1);
        canvas.drawCircle(
          Offset(xx * w, yy * h),
          1.2 + 2.2 * s1,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = tint.withValues(
              alpha: ((.12 + .28 * tw) * (.7 + .5 * e)).clamp(0.0, 1.0),
            ),
        );
      }
    }
    if (!fx.antag && fx.pressure > 0 && fx.level > 0) {
      final a =
          (.05 * fx.pressure).clamp(0.0, .2).toDouble() *
          (.75 + (fx.reduced ? 0 : .25 * math.sin(fx.time * 2.2)));
      final lr = Rect.fromLTWH(0, 0, w * .18, h);
      final rr = Rect.fromLTWH(w * .82, 0, w * .18, h);
      canvas.drawRect(
        lr,
        Paint()
          ..shader = LinearGradient(
            colors: [
              _mist.withValues(alpha: a),
              Colors.transparent,
            ],
          ).createShader(lr),
      );
      canvas.drawRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              _mist.withValues(alpha: a),
            ],
          ).createShader(rr),
      );
    }
  }

  @override
  bool shouldRepaint(covariant MelodyBackdropPainter old) => true;
}

/// Jalur, garis penilaian, dan ketukan. Posisi dan waktu sama persis dengan
/// versi lama; hanya tampilannya yang diperkaya (halo, jejak, ekor bercahaya).
class MelodyLanePainter extends CustomPainter {
  MelodyLanePainter({
    required this.notes,
    required this.judge,
    required this.elapsed,
    required this.fx,
    required this.reduced,
  });
  final List<MelodyNote> notes;
  final MelodyJudge judge;
  final int elapsed;
  final MelodyFxController fx;
  final bool reduced;

  @override
  void paint(Canvas c, Size s) {
    final width = s.width / 4;
    final line = s.height * kMelodyLineRatio;
    final held = judge.pressed;
    final fancy = fx.level > 0 && !reduced;
    for (var lane = 0; lane < 4; lane++) {
      final col = fx.laneColors[lane];
      final g = fx.laneGlow[lane];
      final lr = Rect.fromLTWH(lane * width + 5, 0, width - 10, s.height);
      c.drawRRect(
        RRect.fromRectAndRadius(lr, const Radius.circular(16)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              col.withValues(alpha: .02),
              col.withValues(alpha: .06 + .16 * g),
            ],
          ).createShader(lr),
      );
      final a = Offset(lane * width + 8, line);
      final b = Offset((lane + 1) * width - 8, line);
      if (fancy) {
        c.drawLine(
          a,
          b,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = col.withValues(alpha: .06 + .14 * g)
            ..strokeWidth = 22
            ..strokeCap = StrokeCap.round,
        );
        c.drawLine(
          a,
          b,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = col.withValues(alpha: .12 + .25 * g)
            ..strokeWidth = 12
            ..strokeCap = StrokeCap.round,
        );
      }
      c.drawLine(
        a,
        b,
        Paint()
          ..color = col
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
      final cx = (lane + .5) * width;
      final tr = math.min(18.0, width * .18) + 5;
      c.drawCircle(
        Offset(cx, line),
        tr,
        Paint()..color = col.withValues(alpha: .08 + .30 * g),
      );
      c.drawCircle(
        Offset(cx, line),
        tr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = col.withValues(alpha: .55 + .4 * g),
      );
      MelodyArtCache.shared.paint(
        c,
        melodyLaneArt[lane],
        Rect.fromCenter(
          center: Offset(cx, line),
          width: (tr + 5) * 2,
          height: (tr + 5) * 2,
        ),
        opacity: .14 + .35 * g,
      );
    }
    for (var i = 1; i < 4; i++) {
      c.drawLine(
        Offset(i * width, 0),
        Offset(i * width, s.height),
        Paint()
          ..color = Colors.white.withValues(alpha: .05)
          ..strokeWidth = 1,
      );
    }
    for (final n in notes) {
      final delta = n.at - elapsed;
      if (delta > kMelodyTravelMs || delta < -n.hold - 200) {
        continue;
      }
      final x = (n.lane + .5) * width;
      final y = line - delta / kMelodyTravelMs * line;
      final col = fx.laneColors[n.lane];
      final prox = (1 - delta / kMelodyTravelMs).clamp(0.0, 1.0).toDouble();
      final fade = delta > kMelodyTravelMs - 200
          ? ((kMelodyTravelMs - delta) / 200).clamp(0.0, 1.0).toDouble()
          : 1.0;
      final isHeld =
          n.hold > 0 &&
          held.contains(n.lane) &&
          judge.consumed(n.id) &&
          delta <= 0;
      if (n.hold > 0) {
        final tail = line - (n.at + n.hold - elapsed) / kMelodyTravelMs * line;
        final head = isHeld ? math.min(y, line) : y;
        final top = tail.clamp(0, s.height).toDouble();
        final bottom = head.clamp(0, s.height).toDouble();
        if (bottom > top) {
          final bw = math.min(18.0, width * .22);
          final bar = Rect.fromLTRB(x - bw / 2, top, x + bw / 2, bottom);
          c.drawRRect(
            RRect.fromRectAndRadius(bar, Radius.circular(bw / 2)),
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  col.withValues(alpha: (isHeld ? .55 : .28) * fade),
                  col.withValues(alpha: (isHeld ? .85 : .5) * fade),
                ],
              ).createShader(bar),
          );
          c.drawRRect(
            RRect.fromRectAndRadius(bar, Radius.circular(bw / 2)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = Colors.white.withValues(alpha: isHeld ? .55 : .22),
          );
        }
      }
      if (judge.consumed(n.id)) {
        continue;
      }
      final r0 = math.min(18.0, width * .18);
      final r = r0 * (.82 + .28 * prox);
      if (fancy) {
        final trail = Rect.fromLTWH(x - r * .4, y - 70, r * .8, 70);
        c.drawRect(
          trail,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                col.withValues(alpha: 0),
                col.withValues(alpha: .38 * fade),
              ],
            ).createShader(trail),
        );
        c.drawCircle(
          Offset(x, y),
          r + 11,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = col.withValues(alpha: .10 * fade),
        );
        c.drawCircle(
          Offset(x, y),
          r + 5,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = col.withValues(alpha: .22 * fade),
        );
      }
      final textured = MelodyArtCache.shared.paint(
        c,
        melodyLaneArt[n.lane],
        Rect.fromCenter(
          center: Offset(x, y),
          width: r * 2 + 12,
          height: r * 2 + 12,
        ),
        opacity: fade,
      );
      if (!textured) {
        c.drawCircle(
          Offset(x, y),
          r,
          Paint()..color = col.withValues(alpha: fade),
        );
        c.drawCircle(
          Offset(x, y - r * .2),
          r * .55,
          Paint()..color = Colors.white.withValues(alpha: .30 * fade),
        );
        c.drawCircle(
          Offset(x, y),
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white.withValues(alpha: .5 * fade),
        );
      }
      if (delta.abs() < 140) {
        c.drawCircle(
          Offset(x, y),
          r + 9,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white.withValues(alpha: .35),
        );
      }
      if (!textured) {
        _text(
          c,
          '${n.lane + 1}',
          Offset(x, y),
          TextStyle(
            color: const Color(0xFF06120E).withValues(alpha: fade),
            fontSize: r,
            fontWeight: FontWeight.w900,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant MelodyLanePainter old) => true;
}

/// Lapisan paling atas: gelombang, percikan, teks penilaian, angka kombo
/// besar, dan spanduk pencapaian tiap kelipatan 15.
class MelodyFrontPainter extends CustomPainter {
  MelodyFrontPainter(this.fx);
  final MelodyFxController fx;

  @override
  void paint(Canvas canvas, Size size) {
    fx.flush(size);
    final w = size.width, h = size.height;
    final line = h * kMelodyLineRatio;
    final tintMain = fx.antag ? _mist : _gold;

    if (fx.motion && fx.hitPulse > .02) {
      canvas.drawRect(
        Rect.fromLTWH(0, line - 3, w, 6),
        Paint()
          ..blendMode = BlendMode.plus
          ..color = Colors.white.withValues(alpha: .6 * fx.hitPulse),
      );
    }
    if (fx.motion && fx.flash > .02) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = tintMain.withValues(alpha: .11 * fx.flash),
      );
    }
    for (var lane = 0; lane < 4; lane++) {
      final f = fx.laneFlash[lane];
      if (f < .02 || fx.level == 0) {
        continue;
      }
      final col = fx.laneColors[lane];
      final r = Rect.fromLTRB(
        lane * w / 4 + 4,
        line - h * .8,
        (lane + 1) * w / 4 - 4,
        line,
      );
      canvas.drawRect(
        r,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Color.lerp(col, Colors.white, .5)!.withValues(alpha: .42 * f),
              Colors.transparent,
            ],
          ).createShader(r),
      );
    }
    if (fx.motion && fx.breakPulse > .02) {
      final bp = fx.breakPulse;
      final br = Rect.fromLTWH(0, h * .5, w, h * .5);
      canvas.drawRect(
        br,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              _blood.withValues(alpha: .34 * bp),
              Colors.transparent,
            ],
          ).createShader(br),
      );
      final lr = Rect.fromLTWH(0, 0, w * .2, h);
      final rr = Rect.fromLTWH(w * .8, 0, w * .2, h);
      canvas.drawRect(
        lr,
        Paint()
          ..shader = LinearGradient(
            colors: [
              _blood.withValues(alpha: .26 * bp),
              Colors.transparent,
            ],
          ).createShader(lr),
      );
      canvas.drawRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              _blood.withValues(alpha: .26 * bp),
            ],
          ).createShader(rr),
      );
      final crack = Path()..moveTo(0, line);
      for (var i = 1; i <= 14; i++) {
        crack.lineTo(
          w * i / 14,
          line + (i.isEven ? -11 : 11) * math.sin(i * 1.7),
        );
      }
      canvas.drawPath(
        crack,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.bevel
          ..blendMode = BlendMode.plus
          ..color = _blood.withValues(alpha: .8 * bp),
      );
    }

    if (fx.combo >= 3) {
      final scale = fx.motion ? 1 + .38 * fx.comboPulse : 1.0;
      final base = Color.lerp(Colors.white, tintMain, .6 + .4 * fx.energy)!;
      final a = (.30 + .30 * fx.energy + .35 * fx.comboPulse)
          .clamp(0.0, .95)
          .toDouble();
      _text(
        canvas,
        '${fx.combo}',
        Offset(w / 2, h * .2),
        TextStyle(
          color: base.withValues(alpha: a),
          fontSize: 88 * scale,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(color: base.withValues(alpha: a * .8), blurRadius: 22),
          ],
        ),
      );
      if (!MelodyArtCache.shared.paint(
        canvas,
        'melodi-combo',
        Rect.fromCenter(
          center: Offset(w / 2, h * .2 + 58),
          width: math.min(w * .34, 160),
          height: 42,
        ),
        opacity: .8,
      )) {
        _text(
          canvas,
          'KOMBO',
          Offset(w / 2, h * .2 + 58),
          TextStyle(
            color: _cream.withValues(alpha: .5),
            fontSize: 11,
            letterSpacing: 4,
            fontWeight: FontWeight.w700,
          ),
        );
      }
    }

    for (final r in fx._rings) {
      final t = r.age / r.life;
      final e = Curves.easeOutCubic.transform(t);
      final a = ((1 - t) * .85).clamp(0.0, 1.0).toDouble();
      if (r.flat) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(r.x, r.y),
            width: r.maxR * 2 * e,
            height: 14 * (1 - t) + 4,
          ),
          Paint()
            ..blendMode = BlendMode.plus
            ..color = r.color.withValues(alpha: a * .6),
        );
      } else {
        canvas.drawCircle(
          Offset(r.x, r.y),
          r.maxR * e,
          Paint()
            ..blendMode = BlendMode.plus
            ..style = PaintingStyle.stroke
            ..strokeWidth = r.width * (1 - t) + .5
            ..color = r.color.withValues(alpha: a),
        );
      }
    }

    for (final s in fx._sparks) {
      final t = s.age / s.life;
      final a = math.pow(1 - t, 1.4).toDouble();
      final p = Offset(s.x, s.y);
      final paint = Paint()
        ..blendMode = BlendMode.plus
        ..color = s.color.withValues(alpha: a)
        ..strokeWidth = s.size * .8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p, p - Offset(s.vx * .02, s.vy * .02), paint);
      canvas.drawCircle(p, s.size * (1 - t * .5), paint);
    }

    for (final p in fx._pops) {
      final t = p.age / .8;
      final lift = fx.motion ? 60 * Curves.easeOutCubic.transform(t) : 0.0;
      final scale = fx.motion && t < .15 ? 2.0 - (t / .15) * 1.0 : 1.0;
      final a = t < .65 ? 1.0 : (1 - (t - .65) / .35).clamp(0.0, 1.0);
      final asset = switch (p.text) {
        'TEPAT!' => 'melodi-perfect',
        'Bagus' => 'melodi-good',
        'IRAMA TERPUTUS' => 'melodi-break',
        _ => null,
      };
      final pw = math.min(w * .38, p.size * 5.5 * scale);
      final ph = pw * .36;
      final center = Offset(
        p.x.clamp(pw / 2, w - pw / 2).toDouble(),
        (p.y - lift).clamp(ph / 2, math.max(ph / 2, h - ph / 2)).toDouble(),
      );
      final drawn =
          fx.level > 0 &&
          asset != null &&
          MelodyArtCache.shared.paint(
            canvas,
            asset,
            Rect.fromCenter(center: center, width: pw, height: ph),
            opacity: a.toDouble(),
          );
      if (!drawn) {
        _text(
          canvas,
          p.text,
          Offset(p.x, p.y - lift),
          TextStyle(
            color: p.color.withValues(alpha: a.toDouble()),
            fontSize: p.size * scale,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            shadows: [
              Shadow(
                color: p.color.withValues(alpha: .8 * a.toDouble()),
                blurRadius: 12,
              ),
            ],
          ),
        );
      }
    }

    final b = fx._banner;
    if (b != null) {
      final t = (b.age / 2.0).clamp(0.0, 1.0).toDouble();
      final enter = Curves.easeOutBack.transform((t / .16).clamp(0.0, 1.0));
      final scale = fx.motion ? 1.9 - .9 * enter : 1.0;
      final a = t < .16 ? t / .16 : (t > .7 ? 1 - (t - .7) / .3 : 1.0);
      final cx = w / 2, cy = h * .36;
      if (fx.motion && fx.level >= 2) {
        final len = size.shortestSide * .7 * (.6 + .4 * enter);
        final rot = fx.time * .5;
        for (var i = 0; i < 18; i++) {
          final ang = rot + i * 2 * math.pi / 18;
          final path = Path()
            ..moveTo(cx, cy)
            ..lineTo(
              cx + math.cos(ang - .05) * len,
              cy + math.sin(ang - .05) * len,
            )
            ..lineTo(
              cx + math.cos(ang + .05) * len,
              cy + math.sin(ang + .05) * len,
            )
            ..close();
          canvas.drawPath(
            path,
            Paint()
              ..blendMode = BlendMode.plus
              ..color = b.color.withValues(alpha: .26 * a),
          );
        }
        canvas.drawCircle(
          Offset(cx, cy),
          40 + 150 * t,
          Paint()
            ..blendMode = BlendMode.plus
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 * (1 - t) + .5
            ..color = b.color.withValues(alpha: .5 * (1 - t)),
        );
      }
      if (fx.motion) {
        final bandW = w * 1.3 * enter.clamp(0.0, 1.0);
        canvas.drawRect(
          Rect.fromCenter(center: Offset(cx, cy), width: bandW, height: 70),
          Paint()
            ..blendMode = BlendMode.plus
            ..color = b.color.withValues(alpha: .14 * a),
        );
        canvas.drawRect(
          Rect.fromCenter(center: Offset(cx, cy), width: bandW, height: 3),
          Paint()
            ..blendMode = BlendMode.plus
            ..color = Colors.white.withValues(alpha: .6 * a),
        );
      }
      final main = Color.lerp(b.color, Colors.white, .3)!;
      _text(
        canvas,
        b.title,
        Offset(cx, cy),
        TextStyle(
          color: main.withValues(alpha: a.clamp(0.0, 1.0).toDouble()),
          fontSize: math.min(w * .12, 78) * scale,
          fontWeight: FontWeight.w900,
          letterSpacing: 3,
          shadows: [
            Shadow(
              color: b.color.withValues(
                alpha: .8 * a.clamp(0.0, 1.0).toDouble(),
              ),
              blurRadius: 24,
            ),
          ],
        ),
      );
      _text(
        canvas,
        b.sub,
        Offset(cx, cy + math.min(w * .12, 78) * .9 + 8),
        TextStyle(
          color: _cream.withValues(alpha: .9 * a.clamp(0.0, 1.0).toDouble()),
          fontSize: 16,
          letterSpacing: 2,
          fontWeight: FontWeight.w700,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant MelodyFrontPainter old) => true;
}

/// Hitung mundur 3-2-1: angka mengecil dari besar, dengan cincin yang melebar.
class MelodyCountdown extends StatelessWidget {
  const MelodyCountdown({
    super.key,
    required this.number,
    required this.color,
    this.reduced = false,
  });
  final int number;
  final Color color;
  final bool reduced;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final width = math.min(360.0, box.maxWidth * .8);
      final height = math.min(230.0, box.maxHeight * .8);
      final ready = number > 3;
      return SizedBox(
        width: width,
        height: height,
        child: TweenAnimationBuilder<double>(
          key: ValueKey(number),
          tween: Tween(begin: reduced ? 1.0 : 0.0, end: 1.0),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, value, _) => Stack(
            alignment: Alignment.center,
            children: [
              if (!reduced)
                CustomPaint(
                  size: Size(width, height),
                  painter: _RingPulsePainter(value, color),
                ),
              if (!ready)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: MelodyArtView(
                    'melodi-ready',
                    height: height * .2,
                    label: 'Bersiap',
                  ),
                ),
              Transform.scale(
                scale: reduced ? 1 : 1.2 - value * .2,
                child: MelodyArtView(
                  ready ? 'melodi-ready' : 'melodi-angka${number.clamp(1, 3)}',
                  width: width * .92,
                  height: height * (ready ? .48 : .65),
                  label: ready ? 'Bersiap' : '$number',
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _RingPulsePainter extends CustomPainter {
  _RingPulsePainter(this.v, this.color);
  final double v;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      size.center(Offset.zero),
      36 + 110 * v,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * (1 - v) + .5
        ..color = color.withValues(
          alpha: ((1 - v) * .6).clamp(0.0, 1.0).toDouble(),
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _RingPulsePainter old) => old.v != v;
}

/// Judul panel: huruf merapat dari renggang sambil memudar masuk.
class MelodyTitle extends StatelessWidget {
  const MelodyTitle({
    super.key,
    required this.text,
    required this.color,
    this.reduced = false,
  });
  final String text;
  final Color color;
  final bool reduced;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(text),
    tween: Tween<double>(begin: reduced ? 1.0 : 0.0, end: 1.0),
    duration: const Duration(milliseconds: 900),
    curve: Curves.easeOutCubic,
    builder: (context, v, _) => Opacity(
      opacity: v.clamp(0.0, 1.0).toDouble(),
      child: (text == 'PELATARAN MELODI' || text == 'KALKULASI MELODI')
          ? MelodyArtView(
              text == 'PELATARAN MELODI'
                  ? 'titlepelataranmelodi'
                  : 'titlekalkulasimelodi',
              height: MediaQuery.sizeOf(context).width < 600 ? 88 : 124,
              label: text,
            )
          : Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
    ),
  );
}

/// Muncul membesar dengan pantulan setelah jeda [delay] (0..1 dari 1,8 dtk).
class MelodyReveal extends StatelessWidget {
  const MelodyReveal({
    super.key,
    required this.child,
    this.delay = .5,
    this.reduced = false,
  });
  final Widget child;
  final double delay;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    if (reduced) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1800),
      curve: Interval(delay, 1.0, curve: Curves.elasticOut),
      builder: (context, v, c) => Opacity(
        opacity: (v * 3).clamp(0.0, 1.0).toDouble(),
        child: Transform.scale(scale: .6 + .4 * v, child: c),
      ),
      child: child,
    );
  }
}

/// Nilai akhir: angka menghitung naik, lalu berdenyut dengan sinar berputar
/// yang makin terang pada kelompok nilai tinggi.
class MelodyScoreReveal extends StatefulWidget {
  const MelodyScoreReveal({
    super.key,
    required this.score,
    required this.tier,
    required this.label,
    this.reduced = false,
  });
  final int score, tier;
  final String label;
  final bool reduced;

  @override
  State<MelodyScoreReveal> createState() => _MelodyScoreRevealState();
}

class _MelodyScoreRevealState extends State<MelodyScoreReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.reduced
        ? const Duration(milliseconds: 1)
        : const Duration(milliseconds: 2400),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = melodyTierColor(widget.tier);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final countT = Curves.easeOutCubic.transform((t / .62).clamp(0.0, 1.0));
        final shown = (widget.score * countT).round();
        final pop = ((t - .62) / .38).clamp(0.0, 1.0).toDouble();
        final scale = 1 + .22 * math.sin(math.pi * pop);
        return SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ScoreRaysPainter(
                    t: t,
                    pop: pop,
                    color: color,
                    tier: widget.tier,
                    still: widget.reduced,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: scale,
                    child: Text(
                      '$shown',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: color,
                        fontSize: 68,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: color.withValues(alpha: .6),
                            blurRadius: 26,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: pop,
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScoreRaysPainter extends CustomPainter {
  _ScoreRaysPainter({
    required this.t,
    required this.pop,
    required this.color,
    required this.tier,
    required this.still,
  });
  final double t, pop;
  final Color color;
  final int tier;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final strength = .35 + tier / 6 * .65;
    final rect = Rect.fromCircle(center: c, radius: 150);
    canvas.drawCircle(
      c,
      150,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: .18 * strength * (.4 + .6 * t)),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
    if (still) {
      return;
    }
    if (tier >= 2) {
      final rays = tier >= 5 ? 16 : 10;
      final rot = t * 2.2;
      for (var i = 0; i < rays; i++) {
        final a = rot + i * 2 * math.pi / rays;
        final len = 150 * (.5 + .5 * pop);
        final path = Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(
            c.dx + math.cos(a - .045) * len,
            c.dy + math.sin(a - .045) * len,
          )
          ..lineTo(
            c.dx + math.cos(a + .045) * len,
            c.dy + math.sin(a + .045) * len,
          )
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = color.withValues(alpha: .12 * strength * pop),
        );
      }
    }
    if (pop > 0 && pop < 1) {
      canvas.drawCircle(
        c,
        50 + 120 * pop,
        Paint()
          ..blendMode = BlendMode.plus
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - pop) + .5
          ..color = color.withValues(alpha: .6 * (1 - pop)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreRaysPainter old) => true;
}

/// Suasana panel undangan dan hasil: cahaya lembut dan debu cahaya naik.
/// Memakai pengendali waktu [frames] (30 dtk berulang) agar putarannya mulus.
class MelodyAmbientPainter extends CustomPainter {
  MelodyAmbientPainter({
    required this.tint,
    required this.intensity,
    required this.frames,
    this.level = 2,
    this.reduced = false,
  }) : super(repaint: frames);
  final Color tint;
  final double intensity;
  final Animation<double> frames;
  final int level;
  final bool reduced;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, .3),
          radius: 1.1,
          colors: [
            tint.withValues(alpha: (.08 + .14 * intensity).clamp(0.0, 1.0)),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
    if (reduced || level == 0) {
      return;
    }
    final v = frames.value;
    final n = level >= 2 ? 22 : 10;
    for (var i = 0; i < n; i++) {
      final s1 = (i * .6180339) % 1.0;
      final s2 = (i * .7548777) % 1.0;
      final k = 1 + i % 3;
      final yy = 1 - ((v * k + s1) % 1.0);
      final xx = (s2 + math.sin(2 * math.pi * v * 2 + i) * .02) % 1.0;
      final tw = .5 + .5 * math.sin(2 * math.pi * v * 6 + i * 2.1);
      canvas.drawCircle(
        Offset(xx * w, yy * h),
        1.2 + 2.4 * s1,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = tint.withValues(
            alpha: ((.10 + .26 * tw) * (.6 + .6 * intensity)).clamp(0.0, 1.0),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant MelodyAmbientPainter old) =>
      old.tint != tint ||
      old.intensity != intensity ||
      old.level != level ||
      old.reduced != reduced;
}
