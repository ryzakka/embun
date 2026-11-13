import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import '../common/sfx.dart';
import '../common/scene_flow.dart';
import 'night_impact.dart';

double _seg(double v, double a, double b) =>
    ((v - a) / (b - a)).clamp(0.0, 1.0).toDouble();

double _smooth(double x) => x * x * (3 - 2 * x);

double _rnd(int i, int k) {
  final v = math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
  return v - v.floorToDouble();
}

/// Layar malam di antara dua hari biasa, diputar SEBELUM adegan fajar.
///
/// Laporan umum memakai suasana malam yang sama untuk semua pemain.
/// Laporan pribadi menambahkan lokasi korban dan visual hasil bila tersedia.
class NightScene extends StatefulWidget {
  /// Hari yang baru berakhir.
  final int day;
  final List<Map<String, dynamic>> rows;
  final VoidCallback onDone;
  final Map<String, Map<String, dynamic>> defs;
  final bool finalBow;
  final String? finalBowBackdrop;

  const NightScene({
    super.key,
    required this.day,
    required this.rows,
    required this.onDone,
    this.defs = const {},
    this.finalBow = false,
    this.finalBowBackdrop,
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
  static const _ghostExtra = 1400; // tambahan waktu bila hantu menampakkan diri

  late final List<Map<String, dynamic>> _lines;
  late final List<NightImpact?> _impacts;
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
  late final String? _ghostImg;

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
    _impacts = _lines.map(NightImpact.fromReport).toList();
    _attackIdx = _lines.indexWhere((l) => l['kind'] == 'attack');
    _privateIdx = _lines.indexWhere((l) =>
    l['kind'] == 'private' && nightVictimPath(l['scene'] as String?) != null);
    _victimScene = _privateIdx < 0
        ? null
        : (_lines[_privateIdx]['scene'] as String?);
    _victimImg = nightVictimPath(_victimScene);
    _ghostImg = _victimImg == null ? null : nightGhostPath(_victimScene);

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
      cursor = at + _slot(i);
    }
    _starts = starts;

    final last = _lines.length - 1;
    final lastRead = _slot(last);
    _total = (_starts[last] +
        lastRead +
        (_privateIdx >= 0
            ? _privHold + (_ghostImg != null ? _ghostExtra : 0)
            : _hold) +
        kSceneFadeOutMs)
        .round();

    _tl = AnimationController(
        vsync: this, duration: Duration(milliseconds: _total))
      ..forward().whenComplete(_finish);
    _loop = AnimationController(
        vsync: this, duration: const Duration(seconds: 120))
      ..repeat();

    HapticFeedback.lightImpact();
    // Angin malam (sama untuk semua pemain).
    Sfx.I.playAny(Snd.winds, owner: this, tag: 'wind');

    // Getar tiap baris muncul: berat untuk serangan, ringan untuk yang lain.
    for (var i = 0; i < _lines.length; i++) {
      // Suara + getar dampak disinkronkan ke saat benturan di layar.
      final imp = _impacts[i];
      if (imp != null) {
        final hitMs = (_lineStart(i) + imp.hit * kNightImpactMs).round();
        _timers.add(Timer(Duration(milliseconds: hitMs), () {
          if (!mounted) return;
          final sound = imp.sound;
          if (sound != null) Sfx.I.play(sound, owner: this, tag: 'impact');
          if (imp.applied) {
            HapticFeedback.heavyImpact();
            Future.delayed(const Duration(milliseconds: 120),
                HapticFeedback.mediumImpact);
          } else {
            HapticFeedback.lightImpact();
          }
        }));
      }
      _timers.add(Timer(Duration(milliseconds: _lineStart(i).round()), () {
        if (!mounted) return;
        final k = _lines[i]['kind'];
        final impact = _impacts[i];
        if (impact != null) {
          HapticFeedback.selectionClick();
        } else if (k == 'attack') {
          // Pengumuman serangan: sama untuk semua pemain (tanpa sasaran/jenis).
          Sfx.I.play(Snd.slashPedang, owner: this, tag: 'slash');
          HapticFeedback.heavyImpact();
          Future.delayed(
              const Duration(milliseconds: 140), HapticFeedback.heavyImpact);
        } else if (k == 'bow') {
          HapticFeedback.heavyImpact();
        } else if (k == 'skill') {
          HapticFeedback.mediumImpact();
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
    Sfx.I.release(this);
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
  double _slot(int index) {
    final line = _lines[index];
    final impact = _impacts[index];
    final text = '${impact?.title ?? ''} ${line['text']}';
    final base = readMs(text, min: 1700, max: 5200).toDouble();
    if (impact != null) return math.max(base + 560, kNightImpactMs + 300.0);
    return line['kind'] == 'attack' ? base + 500 : base;
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
    if (widget.finalBow) {
      final p = _smooth(_seg(ms, 0, 2600));
      return _layer(widget.finalBowBackdrop ?? _valAtk, 1, h,
          incoming: false, p: p);
    }
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
        // Hantu menyusup perlahan, lalu berkedip tak menentu.
        if (_ghostImg != null) {
          final g = _smooth(_seg(ms, privAt + 1500, privAt + 2600));
          final flicker =
              0.88 + 0.12 * math.sin(ms / 1000 * 23) * math.cos(ms / 1000 * 7);
          layers.add(_layer(_ghostImg, g * flicker, h, incoming: false, p: 0));
        }
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

            // Serangan dramatis: hentakan keras + gema yang lebih panjang.
            final atkEcho = _attackIdx < 0 ? 0.0 : pulse(atkAt + 80, 1100);
            final atkSecond = _attackIdx < 0 ? 0.0 : pulse(atkAt + 260, 380);
            final atkSince = _attackIdx < 0 ? -1.0 : (ms - atkAt);
            // Adegan dampak layar penuh (hasil pribadi).
            final act = _starts.lastIndexWhere((s) => s <= ms);
            final imp = act >= 0 ? _impacts[act] : null;
            final impAt = act >= 0 ? _starts[act] : 0.0;
            final impP =
            imp == null ? 0.0 : _seg(ms, impAt, impAt + kNightImpactMs);
            final impPower = imp?.shakePower ?? 0.0;
            final impPulse = imp == null
                ? 0.0
                : pulse(impAt + imp.hit * kNightImpactMs, 450);

            final shakeAmp = 20 * atkPulse +
                8 * atkSecond +
                3 * atkEcho +
                3 * privPulse +
                26 * impPower * impPulse;
            final t = ms / 1000;
            final shake = Offset(math.sin(t * 95) * shakeAmp,
                math.cos(t * 81) * shakeAmp * 0.7);
            final tilt = math.sin(t * 61) * 0.012 * (atkPulse + atkSecond) +
                math.sin(t * 57) * 0.014 * impPower * impPulse;
            final punch =
                0.09 * atkPulse + 0.03 * atkSecond + 0.045 * impPower * impPulse;

            final fadeIn = 1 - fadeMs(ms, 0, kSceneFadeInMs.toDouble());
            final fadeOut =
            fadeMs(ms, _total - kSceneFadeOutMs.toDouble(), _total.toDouble());

            // Kamera: perbesaran tetap (membuang bingkai emas gambar) ditambah
            // desir pelan; bergeser sedikit mengikuti waktu.
            final drift = ms / _total;
            final zoom = kBentangZoom * (1.0 + 0.035 * drift + punch);
            final pan = Offset(math.sin(sec * 0.35) * 6, -drift * h * 0.012);

            return Stack(
              fit: StackFit.expand,
              children: [
                // Dunia malam (gambar) + guncangan.
                ClipRect(
                  child: Transform.translate(
                    offset: shake + pan,
                    child: Transform.rotate(
                      angle: tilt,
                      child: Transform.scale(
                        scale: zoom,
                        child: _world(ms, h, atkAt, privAt),
                      ),
                    ),
                  ),
                ),

                // Gelombang kejut + garis kecepatan dari titik hantaman.
                if (atkSince >= 0 && atkSince < 1600)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _ShockPainter(since: atkSince),
                      size: Size.infinite,
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
                if (atkEcho > 0.02)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _CrackPainter(pulse: math.min(1.0, atkPulse + 0.35 * atkEcho)),
                      size: Size.infinite,
                    ),
                  ),

                // Isi: judul + baris laporan.
                Transform.translate(
                  offset: shake * 1.3,
                  child: SafeArea(child: _content(ms, atkPulse, attack)),
                ),

                // Adegan dampak layar penuh: panah, perisai, api, dll.
                if (imp != null && impP > 0 && impP < 1)
                  NightImpactStage(
                    key: ValueKey('impact-$act'),
                    impact: imp,
                    progress: impP,
                    cardArt: cardArtPath(widget.defs[imp.card]),
                  ),

                // Kilatan.
                // Putih menyilaukan sesaat, lalu merah darah, lalu berdenyut.
                if (atkFlash > 0.01)
                  IgnorePointer(
                    child: ColoredBox(
                      color: Color.lerp(EmbunColors.blood, Colors.white,
                          (atkFlash * atkFlash).clamp(0.0, 1.0))!
                          .withValues(
                          alpha: (0.75 * atkFlash).clamp(0.0, 1.0)),
                    ),
                  ),
                if (atkSecond > 0.01)
                  IgnorePointer(
                    child: ColoredBox(
                      color: EmbunColors.blood.withValues(
                          alpha: (0.22 * atkSecond).clamp(0.0, 1.0)),
                    ),
                  ),
                // Tepi layar memerah berdenyut seperti detak jantung.
                if (attack > 0.01)
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          radius: 0.95,
                          colors: [
                            Colors.transparent,
                            EmbunColors.blood.withValues(
                                alpha: (attack *
                                    (0.22 +
                                        0.12 *
                                            math.sin(ms / 1000 * 5.2) +
                                        0.25 * atkEcho))
                                    .clamp(0.0, 0.6)),
                          ],
                          stops: const [0.55, 1.0],
                        ),
                      ),
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
    final word = widget.finalBow ? 'PANAH' : 'MALAM';
    final active = _starts.lastIndexWhere((start) => start <= ms);
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
              icon: const GameIcon('skip2', size: 22),
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
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < word.length; i++) letter(i),
                        ],
                      ),
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
                        widget.finalBow
                            ? 'Busur Terakhir'
                            : 'Hari ${widget.day} berlalu',
                        style: const TextStyle(
                            fontSize: 13.5,
                            letterSpacing: 1.2,
                            color: Colors.white60),
                      ),
                    ),
                    const SizedBox(height: 26),
                    for (var i = active; i >= 0; i--)
                      _line(_lines[i], i, ms, atkPulse, active: i == active),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _line(Map<String, dynamic> l, int i, double ms, double atkPulse,
      {required bool active}) {
    final kind = '${l['kind']}';
    final text = '${l['text']}';
    final a = _seg(ms, _lineStart(i), _lineStart(i) + 520);
    final impact = _impacts[i];
    if (impact != null) {
      final card = widget.defs[impact.card];
      return Opacity(
        opacity: a,
        child: NightImpactReport(
          key: ValueKey(l['id']),
          impact: impact,
          message: text,
          cardName: card?['name'] as String?,
          active: active,
        ),
      );
    }
    final Color color;
    final Widget icon;
    String? tag;
    switch (kind) {
      case 'attack':
        color = EmbunColors.blood;
        icon = const GameIcon('alert', size: 28);
        tag = 'BAHAYA';
      case 'bow':
        color = EmbunColors.gold;
        icon = const Icon(Icons.gps_fixed_rounded,
            size: 28, color: EmbunColors.gold);
        tag = 'BUSUR TERAKHIR';
      case 'skill':
        color = EmbunColors.mist;
        icon = const Icon(Icons.auto_awesome_rounded,
            size: 28, color: EmbunColors.mist);
        tag = 'HARGA KEMAMPUAN';
      case 'private':
        color = EmbunColors.gold;
        icon = const GameIcon('lock', size: 28);
        tag = 'Hanya kamu yang tahu';
      default:
        color = const Color(0xFF8FD6B0);
        icon = const Icon(Icons.bedtime_rounded,
            size: 28, color: Color(0xFF8FD6B0));
    }
    final isAtk = kind == 'attack';
    final pop = Curves.elasticOut.transform(_seg(a, 0.0, 1.0));

    final offset = switch (kind) {
      'attack' => Offset(0, 0),
      'private' => Offset(0, 22 * (1 - a)),
      _ => Offset(0, 14 * (1 - a)),
    };
    // Kartu serangan menghantam dari besar (1.9x) ke ukuran asli dengan
    // sedikit memantul.
    final scale = isAtk ? 1.9 - 0.9 * Curves.easeOutBack.transform(a) : 1.0;

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
                  child: icon,
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

/// Retakan ungu bercabang dari langit saat serangan menghantam.
class _CrackPainter extends CustomPainter {
  final double pulse; // 0..1
  const _CrackPainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rnd = math.Random(8);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9)
      ..color = const Color(0xFFB07CE8).withValues(alpha: 0.7 * pulse);
    final core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFF8F1FF).withValues(alpha: pulse);
    final thin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE2CCFF).withValues(alpha: 0.85 * pulse);

    void bolt(double sx, double sy, double len, double dir, int depth) {
      var x = sx, y = sy;
      final path = Path()..moveTo(x, y);
      const steps = 9;
      for (var i = 0; i < steps; i++) {
        x += (rnd.nextDouble() - 0.5) * w * 0.09 + dir * w * 0.012;
        y += len / steps;
        path.lineTo(x, y);
        if (depth < 2 && i > 1 && i < steps - 1 && rnd.nextDouble() < 0.32) {
          bolt(x, y, len * 0.45, rnd.nextBool() ? 1 : -1, depth + 1);
        }
      }
      canvas.drawPath(path, glow);
      canvas.drawPath(path, depth == 0 ? core : thin);
    }

    for (var k = 0; k < 6; k++) {
      bolt(w * (0.08 + 0.84 * rnd.nextDouble()), 0,
          h * (0.30 + 0.30 * rnd.nextDouble()), 0, 0);
    }
  }

  @override
  bool shouldRepaint(covariant _CrackPainter old) => old.pulse != pulse;
}

/// Gelombang kejut ganda, garis kecepatan, dan bara yang terlempar dari
/// pusat layar saat serangan menghantam. [since] = ms sejak serangan muncul.
class _ShockPainter extends CustomPainter {
  final double since;
  const _ShockPainter({required this.since});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.46);
    final maxR = size.longestSide * 0.75;

    // Dua cincin kejut berurutan.
    for (var k = 0; k < 2; k++) {
      final u = _seg(since, 40 + k * 160.0, 900 + k * 160.0);
      if (u <= 0 || u >= 1) continue;
      final e = Curves.easeOutCubic.transform(u);
      final a = (1 - u);
      canvas.drawCircle(
        c,
        maxR * e,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18 * (1 - u) + 2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
          ..color = EmbunColors.blood.withValues(alpha: 0.55 * a),
      );
      canvas.drawCircle(
        c,
        maxR * e,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * (1 - u) + 0.8
          ..color = const Color(0xFFFFE6EA).withValues(alpha: 0.9 * a),
      );
    }

    // Garis kecepatan memancar keluar.
    final lu = _seg(since, 0, 520);
    if (lu > 0 && lu < 1) {
      final fade = math.sin(lu * math.pi);
      final line = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.55 * fade);
      for (var i = 0; i < 36; i++) {
        final ang = _rnd(i, 1) * math.pi * 2;
        final r0 = maxR * (0.12 + 0.55 * lu * (0.6 + 0.4 * _rnd(i, 2)));
        final r1 = r0 + maxR * (0.10 + 0.18 * _rnd(i, 3));
        canvas.drawLine(
          c + Offset(math.cos(ang), math.sin(ang)) * r0,
          c + Offset(math.cos(ang), math.sin(ang)) * r1,
          line,
        );
      }
    }

    // Bara merah-ungu yang terlempar lalu jatuh.
    final pu = _seg(since, 60, 1500);
    if (pu > 0 && pu < 1) {
      for (var i = 0; i < 40; i++) {
        final ang = _rnd(i, 7) * math.pi * 2;
        final speed = 0.25 + 0.6 * _rnd(i, 8);
        final dist = maxR * speed * Curves.easeOutCubic.transform(pu);
        final p = c +
            Offset(math.cos(ang) * dist,
                math.sin(ang) * dist + pu * pu * 90 * (0.5 + _rnd(i, 9)));
        final a = math.sin(pu * math.pi) * 0.9;
        canvas.drawCircle(
          p,
          1.5 + 3 * _rnd(i, 10) * (1 - pu),
          Paint()
            ..color = (i.isEven ? EmbunColors.blood : const Color(0xFFD7A8FF))
                .withValues(alpha: a),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ShockPainter old) => old.since != since;
}