import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import '../common/scene_flow.dart';

double _seg(double v, double a, double b) =>
    ((v - a) / (b - a)).clamp(0.0, 1.0).toDouble();

double _smooth(double x) => x * x * (3 - 2 * x);

/// Layar malam di antara dua hari biasa, diputar SEBELUM adegan fajar.
///
/// [rows] berasal dari `night_reports`: pengumuman untuk semua pemain
/// (user_id kosong, kind 'attack' atau 'calm') dan baris pribadi bila aku
/// menjadi korban (user_id = aku, kind 'private', kolom `scene` = 'sumur' atau
/// 'rumah'). Sasaran dan jenis serangan tidak pernah diumumkan ke semua orang.
///
/// Seluruhnya gambar dari assets/bentang, dihidupkan dengan gerak kamera:
///
///   MALAM TENANG (semua pemain)
///     langit-malamberawan -> kamera turun -> lembah-malamindah
///   ADA SERANGAN (semua pemain: sama persis, tanpa sasaran / jenis)
///     langit-malamberawan -> hentakan + kilat merah -> langit-malammerahunggelap
///     -> kamera turun -> lembah-malamkering
///   KORBAN SAJA (baris pribadi ber-scene)
///     lembah-malamkering -> kamera turun lagi -> sumur-gelapmalam (Racun Sumur)
///     atau rumah-malamdepanpintu (Maling Embun), bersama baris pribadinya.
///
/// Pemain lain tak pernah melihat dua gambar terakhir itu. Kabut Pekat tidak
/// punya korban pribadi, jadi bagi semua orang berhenti di lembah-malamkering.
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
  static const _intro = 1700; // ms sebelum baris pertama
  static const _hold = 1600; // jeda tambahan setelah baris terakhir terbaca
  static const _tiltMs = 2200; // lama satu gerak kamera turun
  // Serangan -> baris pribadi: jeda 800 ms, kamera turun ke lembah kering
  // (_tiltMs), lalu napas 200 ms sebelum turun lagi ke sumur / rumah.
  static const _privAfter = 800 + _tiltMs + 200;
  static const _privHold = 1800; // jeda tambahan setelah baris pribadi terbaca

  late final List<Map<String, dynamic>> _lines;
  late final List<double> _starts; // kapan tiap baris mulai muncul (ms)
  late final int _total;
  late final int _attackIdx;
  late final int _privateIdx;
  late final String? _victimScene;
  late final AnimationController _tl; // garis waktu
  late final AnimationController _loop; // jam berkelanjutan untuk latar
  final List<Timer> _timers = [];
  bool _done = false;

  // Gambar latar (dicari sekali).
  late final String? _skyCalm = nightSkyPath(attack: false);
  late final String? _skyAtk = nightSkyPath(attack: true);
  late final String? _valCalm = nightValleyPath(attack: false);
  late final String? _valAtk = nightValleyPath(attack: true);
  late final String? _victimImg;

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
    _victimScene = _privateIdx < 0
        ? null
        : (_lines[_privateIdx]['scene'] as String?);
    _victimImg = nightVictimPath(_victimScene);

    // Tiap baris diberi waktu baca sesuai panjang teksnya (dan baris lama
    // tetap terlihat, jadi yang paling akhir yang paling butuh waktu).
    final starts = <double>[];
    var cursor = _intro.toDouble();
    for (var i = 0; i < _lines.length; i++) {
      var at = cursor;
      if (i == _privateIdx && _attackIdx >= 0) {
        // Baris pribadi menunggu kamera selesai turun ke lembah kering.
        at = math.max(at, starts[_attackIdx] + _privAfter);
      }
      starts.add(at);
      cursor = at + _slot(_lines[i]);
    }
    _starts = starts;

    final last = _lines.length - 1;
    final lastRead = _slot(_lines[last]);
    _total = (_starts[last] +
        lastRead +
        (_privateIdx >= 0 ? _privHold : _hold) +
        kSceneFadeOutMs)
        .round();

    _tl = AnimationController(
        vsync: this, duration: Duration(milliseconds: _total))
      ..forward().whenComplete(_finish);
    _loop = AnimationController(
        vsync: this, duration: const Duration(seconds: 120))
      ..repeat();

    HapticFeedback.lightImpact();

    // Getar tiap baris muncul: berat untuk serangan, ringan untuk yang lain.
    for (var i = 0; i < _lines.length; i++) {
      _timers.add(Timer(Duration(milliseconds: _lineStart(i).round()), () {
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

  /// Waktu (ms) yang disediakan untuk satu baris sebelum baris berikutnya
  /// muncul: sesuai panjang teksnya. Serangan diberi tambahan agar hentakannya
  /// sempat dirasakan sebelum teks lain menimpa.
  double _slot(Map<String, dynamic> l) {
    final base = readMs('${l['text']}', min: 1700, max: 5200).toDouble();
    return l['kind'] == 'attack' ? base + 500 : base;
  }

  /// Baris pribadi muncul setelah kamera selesai turun ke lembah serangan
  /// (dan serangannya sempat terbaca); baris lain bergiliran sesuai waktu baca.
  double _lineStart(int i) => _starts[i];

  // ------------------------------------------------------------------
  // Lapisan gambar
  // ------------------------------------------------------------------

  /// Satu lapisan latar. [p] 0..1 = kemajuan kamera. [incoming] true: gambar
  /// yang MASUK (muncul dari bawah, mengecil ke ukuran akhir); false: gambar
  /// yang KELUAR (naik sedikit, membesar sedikit).
  Widget _layer(String? path, double opacity, double h,
      {required bool incoming, required double p}) {
    if (opacity <= 0.01) return const SizedBox.shrink();
    final dy = incoming ? (1 - p) * h * 0.10 : -p * h * 0.04;
    final z = incoming ? 1 + 0.06 * (1 - p) : 1 + 0.05 * p;
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0).toDouble(),
      child: Transform.translate(
        offset: Offset(0, dy),
        child: Transform.scale(
          scale: z,
          child: SizedBox.expand(
            child: GameImage(path: path, cacheWidth: 1280),
          ),
        ),
      ),
    );
  }

  Widget _world(double ms, double h, double atkAt, double privAt) {
    final hasAtk = _attackIdx >= 0;
    final hasVictim = _privateIdx >= 0 && _victimImg != null;

    // Langit tenang -> lembah tenang (hanya malam tanpa serangan).
    final pCalm = hasAtk ? 0.0 : Curves.easeInOut.transform(_seg(ms, 500, 500.0 + _tiltMs));

    // Serangan: langit merah menimpa, lalu kamera turun ke lembah kering.
    final skyAtkA = hasAtk ? _seg(ms, atkAt, atkAt + 380) : 0.0;
    final pAtk = hasAtk
        ? Curves.easeInOut.transform(_seg(ms, atkAt + 800, atkAt + 800.0 + _tiltMs))
        : 0.0;

    // Korban: lembah kering -> sumur / halaman rumah.
    final pVic = hasVictim
        ? Curves.easeInOut.transform(_seg(ms, privAt - 300, privAt + 900))
        : 0.0;

    final layers = <Widget>[];
    if (!hasAtk) {
      layers.add(_layer(_skyCalm, 1, h, incoming: false, p: pCalm));
      layers.add(_layer(_valCalm, _smooth(_seg(pCalm, 0.0, 0.7)), h,
          incoming: true, p: pCalm));
    } else {
      layers.add(_layer(_skyCalm, 1, h, incoming: false, p: 0));
      layers.add(_layer(_skyAtk, skyAtkA, h, incoming: false, p: pAtk));
      layers.add(_layer(_valAtk, _smooth(_seg(pAtk, 0.0, 0.7)), h,
          incoming: true, p: pAtk));
      if (hasVictim) {
        layers.add(_layer(_victimImg, _smooth(_seg(pVic, 0.0, 0.7)), h,
            incoming: true, p: pVic));
      }
    }
    return Stack(fit: StackFit.expand, children: layers);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSceneInk,
      child: LayoutBuilder(builder: (context, box) {
        final h = box.maxHeight;
        return AnimatedBuilder(
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
            final shake = Offset(math.sin(t * 95) * shakeAmp,
                math.cos(t * 81) * shakeAmp * 0.7);

            final fadeIn = 1 - fadeMs(ms, 0, kSceneFadeInMs.toDouble());
            final fadeOut =
            fadeMs(ms, _total - kSceneFadeOutMs.toDouble(), _total.toDouble());

            // Kamera: perbesaran tetap (membuang bingkai emas gambar) ditambah
            // desir pelan; bergeser sedikit mengikuti waktu.
            final drift = ms / _total;
            final zoom = kBentangZoom * (1.0 + 0.035 * drift);
            final pan = Offset(math.sin(sec * 0.35) * 6, -drift * h * 0.012);

            return Stack(
              fit: StackFit.expand,
              children: [
                // Dunia malam (gambar) + guncangan.
                ClipRect(
                  child: Transform.translate(
                    offset: shake + pan,
                    child: Transform.scale(
                      scale: zoom,
                      child: _world(ms, h, atkAt, privAt),
                    ),
                  ),
                ),

                // Perendam agar teks terbaca; menebal sedikit saat serangan.
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.50 + 0.10 * attack),
                          Colors.black.withValues(alpha: 0.28 + 0.12 * attack),
                          Colors.black.withValues(alpha: 0.55 + 0.10 * attack),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),

                // Retakan ungu dari langit saat serangan menghantam.
                if (atkPulse > 0.02)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _CrackPainter(pulse: atkPulse),
                      size: Size.infinite,
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
                      color: EmbunColors.blood.withValues(
                          alpha: (0.42 * atkFlash).clamp(0.0, 1.0)),
                    ),
                  ),
                if (privPulse > 0.01)
                  IgnorePointer(
                    child: ColoredBox(
                      color: EmbunColors.gold.withValues(
                          alpha: (0.10 * privPulse).clamp(0.0, 1.0)),
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

                sceneVeil(math.max(fadeIn, fadeOut)),
              ],
            );
          },
        );
      }),
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

/// Retakan ungu dari langit saat serangan menghantam.
class _CrackPainter extends CustomPainter {
  final double pulse; // 0..1
  const _CrackPainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rnd = math.Random(8);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..color = const Color(0xFFB07CE8).withValues(alpha: 0.6 * pulse);
    final core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFF1E6FF).withValues(alpha: 0.95 * pulse);
    for (var k = 0; k < 4; k++) {
      var x = w * (0.12 + 0.76 * rnd.nextDouble());
      var y = 0.0;
      final path = Path()..moveTo(x, y);
      const steps = 7;
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

  @override
  bool shouldRepaint(covariant _CrackPainter old) => old.pulse != pulse;
}