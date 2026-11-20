import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/profile_medals.dart';
import '../../data/profile_repository.dart';
import '../../data/medal_claims.dart';
import '../common/ornate.dart';
import 'medal_claim_scope.dart';
import 'medal_claim_celebration.dart';

// ───────────────────────── Aset ─────────────────────────

// Cache per asset bundle, including lookups that have no installed image yet.
final _manifests = Expando<Future<AssetManifest>>();
final _paths = Expando<Map<String, Future<String?>>>();
Future<String?> medalAsset(AssetBundle bundle, ProfileMedal medal) {
  final paths = _paths[bundle] ??= {};
  return paths.putIfAbsent(medal.id, () async {
    try {
      final manifest = await (_manifests[bundle] ??=
          AssetManifest.loadFromAssetBundle(bundle));
      final files = manifest.listAssets().toSet();
      for (final extension in ['webp', 'png']) {
        final path = 'assets/medals/${medal.assetStem}.$extension';
        if (files.contains(path)) return path;
      }
    } catch (_) {
      // The badge remains readable when an optional image is unavailable.
    }
    return null;
  });
}

// ───────────────────────── Tema tingkat & seri ─────────────────────────

const _tierNames = [
  'Perunggu',
  'Perunggu',
  'Perak',
  'Perak',
  'Emas',
  'Emas',
  'Zamrud',
  'Zamrud',
  'Kecubung',
  'Legenda',
];
const _tierColors = [
  Color(0xFFD99058),
  Color(0xFFD99058),
  Color(0xFFCBD5DF),
  Color(0xFFCBD5DF),
  EmbunColors.gold,
  EmbunColors.gold,
  Color(0xFF3FD6B0),
  Color(0xFF3FD6B0),
  EmbunColors.mist,
  Color(0xFFFF8FB1),
];

extension on ProfileMedal {
  Color get tint => _tierColors[index];
  String get tier => _tierNames[index];
}

Color _seriesColor(MedalSeries s) => switch (s.metric) {
  MedalMetric.wargaWins => EmbunColors.leaf,
  MedalMetric.terbisikWins => EmbunColors.mist,
  MedalMetric.completed => EmbunColors.gold,
};

enum _MedalState { locked, ready, received }

_MedalState _stateOf(
    ProfileDetails profile,
    ProfileMedal medal,
    MedalClaimsController? claims,
    ) {
  if (!medal.unlocked(profile)) return _MedalState.locked;
  if (claims == null || claims.isClaimed(medal)) return _MedalState.received;
  return _MedalState.ready;
}

double _wave(double t) => (math.sin(t * 2 * math.pi) + 1) / 2;

// ───────────────────────── Animasi dasar ─────────────────────────

/// Nilai 0..1 yang berulang. Diam bila pengguna mematikan animasi.
class _Loop extends StatefulWidget {
  const _Loop({required this.period, required this.builder});
  final Duration period;
  final Widget Function(BuildContext context, double t) builder;
  @override
  State<_Loop> createState() => _LoopState();
}

class _LoopState extends State<_Loop> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) => widget.builder(context, _c.value),
  );
}

/// Muncul membesar sekali saat pertama dibangun.
class _Entrance extends StatelessWidget {
  const _Entrance({required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final off = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: off ? 1 : 0, end: 1),
      duration: off
          ? Duration.zero
          : Duration(milliseconds: 360 + math.min(index, 10) * 60),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.scale(scale: .86 + .14 * v, child: child),
      ),
      child: child,
    );
  }
}

// ───────────────────────── Painter ─────────────────────────

/// Sinar berputar di belakang medali.
class _RaysPainter extends CustomPainter {
  const _RaysPainter({required this.color, required this.turn});
  final Color color;
  final double turn;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    const count = 14;
    const step = 2 * math.pi / count;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: .38), color.withValues(alpha: 0)],
        stops: const [.2, 1],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    for (var i = 0; i < count; i++) {
      final a = turn * 2 * math.pi + i * step;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r)
          ..lineTo(
            c.dx + math.cos(a + step * .42) * r,
            c.dy + math.sin(a + step * .42) * r,
          )
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RaysPainter old) =>
      old.turn != turn || old.color != color;
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.value, this.color, this.stroke);
  final double value, stroke;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final rect =
    Offset(stroke / 2, stroke / 2) &
    Size(size.width - stroke, size.height - stroke);
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white12,
    );
    if (value > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * value.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.color != color || old.stroke != stroke;
}

Path _framePath(Rect r, double c) => Path()
  ..moveTo(r.left + c, r.top)
  ..lineTo(r.right - c, r.top)
  ..arcToPoint(
    Offset(r.right, r.top + c),
    radius: Radius.circular(c),
    clockwise: false,
  )
  ..lineTo(r.right, r.bottom - c)
  ..arcToPoint(
    Offset(r.right - c, r.bottom),
    radius: Radius.circular(c),
    clockwise: false,
  )
  ..lineTo(r.left + c, r.bottom)
  ..arcToPoint(
    Offset(r.left, r.bottom - c),
    radius: Radius.circular(c),
    clockwise: false,
  )
  ..lineTo(r.left, r.top + c)
  ..arcToPoint(
    Offset(r.left + c, r.top),
    radius: Radius.circular(c),
    clockwise: false,
  )
  ..close();

class _FramePainter extends CustomPainter {
  const _FramePainter({
    required this.color,
    required this.pulse,
    required this.alert,
    required this.dim,
    required this.filled,
  });
  final Color color;
  final double pulse;
  final bool alert, dim, filled;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(1.5);
    final path = _framePath(rect, 16);
    if (alert) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = color.withValues(alpha: .25 + .4 * pulse)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + 6 * pulse),
      );
    }
    canvas.drawPath(
      path,
      Paint()..color = const Color(0xFF07130F).withValues(alpha: dim ? .55 : .66),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: filled ? .22 : .07),
            color.withValues(alpha: filled ? .05 : .02),
          ],
        ).createShader(rect),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = alert ? 2.2 : 1.3
        ..color = color.withValues(alpha: alert ? 1 : (dim ? .28 : .8)),
    );
    canvas.drawPath(
      _framePath(rect.deflate(5), 12),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7
        ..color = color.withValues(alpha: dim ? .08 : .24),
    );
  }

  @override
  bool shouldRepaint(covariant _FramePainter old) =>
      old.color != color ||
          old.pulse != pulse ||
          old.alert != alert ||
          old.dim != dim ||
          old.filled != filled;
}

// ───────────────────────── Komponen visual ─────────────────────────

class MedalArt extends StatelessWidget {
  const MedalArt({
    super.key,
    required this.medal,
    required this.unlocked,
    this.size = 76,
    this.glow = true,
  });
  final ProfileMedal medal;
  final bool unlocked;
  final double size;
  final bool glow;
  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      switch (medal.series.metric) {
        MedalMetric.wargaWins => Icons.shield_outlined,
        MedalMetric.terbisikWins => Icons.nights_stay_outlined,
        MedalMetric.completed => Icons.sports_esports_outlined,
      },
      size: size * .65,
      color: unlocked ? medal.tint : EmbunColors.gold,
    );
    final art = SizedBox.square(
      dimension: size,
      child: FutureBuilder<String?>(
        future: medalAsset(DefaultAssetBundle.of(context), medal),
        builder: (context, snapshot) => snapshot.data == null
            ? fallback
            : Image.asset(
          snapshot.data!,
          fit: BoxFit.contain,
          cacheWidth: (size * 3).round(),
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
    return Semantics(
      image: true,
      label: '${medal.name}, ${unlocked ? 'diraih' : 'terkunci'}',
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (unlocked && glow)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    medal.tint.withValues(alpha: .4),
                    medal.tint.withValues(alpha: 0),
                  ],
                  stops: const [.35, 1],
                ),
              ),
            ),
          if (unlocked)
            art
          else
            Opacity(
              opacity: .6,
              child: ColorFiltered(
                // Abu-abu gelap: bentuknya terbaca, warnanya masih rahasia.
                colorFilter: const ColorFilter.matrix([
                  .117, .393, .040, 0, 0, //
                  .117, .393, .040, 0, 0, //
                  .117, .393, .040, 0, 0, //
                  0, 0, 0, 1, 0,
                ]),
                child: art,
              ),
            ),
          if (!unlocked)
            Positioned(
              right: size * .02,
              bottom: size * .02,
              child: Container(
                padding: EdgeInsets.all(size * .06),
                decoration: const BoxDecoration(
                  color: Color(0xFF0B1A14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline,
                  size: math.max(14, size * .2),
                  color: Colors.white70,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Medali besar dengan sinar berputar di belakangnya (hanya bila sudah diraih).
class _Stage extends StatelessWidget {
  const _Stage({
    required this.medal,
    required this.unlocked,
    required this.size,
  });
  final ProfileMedal medal;
  final bool unlocked;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size * 1.5,
    child: Stack(
      alignment: Alignment.center,
      children: [
        if (unlocked)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: _Loop(
                  period: const Duration(seconds: 40),
                  builder: (_, t) => CustomPaint(
                    painter: _RaysPainter(color: medal.tint, turn: t),
                  ),
                ),
              ),
            ),
          ),
        MedalArt(medal: medal, unlocked: unlocked, size: size),
      ],
    ),
  );
}

class _Ring extends StatelessWidget {
  const _Ring({
    required this.value,
    required this.color,
    required this.size,
    required this.child,
    this.stroke = 5,
  });
  final double value, size, stroke;
  final Color color;
  final Widget child;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _RingPainter(value, color, stroke),
    child: SizedBox.square(dimension: size, child: Center(child: child)),
  );
}

class _GlowBar extends StatelessWidget {
  const _GlowBar({required this.value, required this.color, this.height = 6});
  final double value, height;
  final Color color;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.white12),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value.clamp(0.0, 1.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: .55), color],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

BoxDecoration _panelDecoration(Color accent) => BoxDecoration(
  borderRadius: BorderRadius.circular(20),
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.lerp(EmbunColors.panelHi, accent, .14)!.withValues(alpha: .90),
      EmbunColors.panel.withValues(alpha: .90),
    ],
  ),
  border: Border.all(color: accent.withValues(alpha: .5)),
  boxShadow: [BoxShadow(color: accent.withValues(alpha: .14), blurRadius: 26)],
);

class _TierLabel extends StatelessWidget {
  const _TierLabel(this.medal);
  final ProfileMedal medal;
  @override
  Widget build(BuildContext context) => Text(
    medal.tier.toUpperCase(),
    style: TextStyle(
      fontSize: 10,
      letterSpacing: 1.6,
      fontWeight: FontWeight.w800,
      color: medal.tint,
    ),
  );
}

/// Kartu berbingkai lengkung-cekung bergaya "achievement".
class _MedalFrame extends StatelessWidget {
  const _MedalFrame({
    super.key,
    required this.child,
    required this.onTap,
    this.color = EmbunColors.gold,
    this.alert = false,
    this.dim = false,
    this.filled = false,
  });
  final Widget child;
  final VoidCallback onTap;
  final Color color;
  final bool alert, dim, filled;

  Widget _frame(double pulse) => Stack(
    fit: StackFit.passthrough,
    clipBehavior: Clip.none,
    children: [
      CustomPaint(
        painter: _FramePainter(
          color: color,
          pulse: pulse,
          alert: alert,
          dim: dim,
          filled: filled,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
              child: child,
            ),
          ),
        ),
      ),
      if (alert)
        Positioned(
          top: -4,
          right: -4,
          child: IgnorePointer(
            child: Container(
              key: const ValueKey('medal-card-alert'),
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF0B1A14), width: 2),
              ),
              child: const Text(
                '!',
                style: TextStyle(
                  fontSize: 11,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => alert
      ? _Loop(
    period: const Duration(milliseconds: 1800),
    builder: (_, t) => _frame(_wave(t)),
  )
      : _frame(0);
}

// ───────────────────────── Ringkasan di profil ─────────────────────────

class ProfileMedalsSummary extends StatelessWidget {
  const ProfileMedalsSummary({super.key, required this.profile});
  final ProfileDetails profile;
  @override
  Widget build(BuildContext context) {
    if (!profile.googleLinked) return const SizedBox.shrink();
    final scoped = MedalClaimScope.maybeOf(context);
    final claims = scoped?.owns(profile) == true ? scoped : null;
    final displayed = claims?.profile ?? profile;
    final earned = earnedMedals(displayed);
    final received = earned
        .where((m) => claims == null || claims.isClaimed(m))
        .toList();
    final highest = [
      for (final series in medalSeries)
        if (received.where((m) => m.series.id == series.id).lastOrNull
        case final ProfileMedal m)
          m,
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: DecoratedBox(
        decoration: _panelDecoration(EmbunColors.gold),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _Ring(
                    value: received.length / profileMedals.length,
                    color: EmbunColors.gold,
                    size: 54,
                    child: const Icon(
                      Icons.emoji_events,
                      color: EmbunColors.gold,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Koleksi Badge',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .4,
                            color: EmbunColors.gold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          claims == null
                              ? '${earned.length}/${profileMedals.length} badge diraih'
                              : '${received.length}/${profileMedals.length} badge diklaim',
                          key: const ValueKey('medals-earned-count'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (claims != null) ...[
                if (claims.loading && !claims.initialized)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('Menyiapkan koleksi medali…'),
                  ),
                if (claims.error != null) ...[
                  Text(
                    claims.error!,
                    style: const TextStyle(color: Color(0xFFFFB5A8)),
                  ),
                  TextButton(
                    onPressed: claims.loading || claims.claimingId != null
                        ? null
                        : () => claims.refresh(details: profile),
                    child: const Text('Coba lagi status medali'),
                  ),
                ],
                if (claims.hasPending) ...[
                  _ClaimBanner(claims: claims),
                  const SizedBox(height: 16),
                ],
              ],
              if (highest.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.black26,
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        color: Colors.white38,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          claims == null
                              ? 'Belum ada badge yang diraih.'
                              : 'Belum ada medali yang diklaim.',
                          style: const TextStyle(color: Colors.white60),
                        ),
                      ),
                    ],
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, box) {
                    final w = ((box.maxWidth - 16) / 3).floorToDouble().clamp(
                      80.0,
                      180.0,
                    );
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < highest.length; i++)
                          SizedBox(
                            width: w,
                            child: _Entrance(
                              index: i,
                              child: _MedalFrame(
                                key: ValueKey('medal-summary-${highest[i].id}'),
                                color: highest[i].tint,
                                filled: true,
                                onTap: () => showMedalDetails(
                                  context,
                                  displayed,
                                  highest[i],
                                  claims: claims,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    MedalArt(
                                      medal: highest[i],
                                      unlocked: true,
                                      size: math.min(76, w - 20),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      highest[i].name,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    _TierLabel(highest[i]),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${medalNumber(highest[i].target)} ${highest[i].series.unit}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white60,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                key: const ValueKey('open-medal-collection'),
                onPressed: () =>
                    showMedalCollection(context, displayed, claims: claims),
                icon: const Icon(Icons.emoji_events_outlined),
                label: const Text('Lihat koleksi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Spanduk berdenyut untuk medali yang siap diklaim.
class _ClaimBanner extends StatelessWidget {
  const _ClaimBanner({required this.claims});
  final MedalClaimsController claims;
  @override
  Widget build(BuildContext context) => _Loop(
    period: const Duration(milliseconds: 2200),
    builder: (context, t) {
      final p = _wave(t);
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              EmbunColors.gold.withValues(alpha: .26),
              EmbunColors.gold.withValues(alpha: .08),
            ],
          ),
          border: Border.all(
            color: EmbunColors.gold.withValues(alpha: .55 + .45 * p),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: EmbunColors.gold.withValues(alpha: .15 + .25 * p),
              blurRadius: 14 + 10 * p,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: EmbunColors.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      '${claims.pending.length} medali baru siap diklaim',
                      style: const TextStyle(
                        color: EmbunColors.gold,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final medal in claims.pending)
                  FilledButton.icon(
                    key: ValueKey('claim-summary-${medal.id}'),
                    style: _goldButton,
                    onPressed: claims.claimingId != null
                        ? null
                        : () =>
                        claimMedalWithCelebration(context, claims, medal),
                    icon: const Icon(Icons.emoji_events, size: 20),
                    label: Text(
                      claims.claimingId == medal.id
                          ? 'Menyimpan…'
                          : 'Klaim ${medal.name}',
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

final _goldButton = FilledButton.styleFrom(
  backgroundColor: EmbunColors.gold,
  foregroundColor: const Color(0xFF1A1405),
  disabledBackgroundColor: const Color(0xFF3A3420),
  disabledForegroundColor: Colors.white38,
);

// ───────────────────────── Latar koleksi ─────────────────────────

/// Gambar latar papan medali di assets/bentang. Dicari .webp lalu .png.
const _backdropStem = 'assets/bentang/papanmedali-latar';
Future<String?> _backdropAsset(AssetBundle bundle) {
  final paths = _paths[bundle] ??= {};
  return paths.putIfAbsent('_backdrop', () async {
    try {
      final manifest = await (_manifests[bundle] ??=
          AssetManifest.loadFromAssetBundle(bundle));
      final files = manifest.listAssets().toSet();
      for (final extension in ['webp', 'png', 'jpg']) {
        final path = '$_backdropStem.$extension';
        if (files.contains(path)) return path;
      }
    } catch (_) {}
    return null;
  });
}

/// Teras berlentera: gambar bergerak pelan (diperbesar sedikit supaya bingkai
/// emas bawaan gambar terpotong rapi), diberi tirai gelap agar teks terbaca,
/// dan kunang-kunang cahaya yang naik perlahan.
class _MedalBackdrop extends StatelessWidget {
  const _MedalBackdrop({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -1.1),
              radius: 1.3,
              colors: [Color(0xFF1D4F3C), Color(0xFF0B1A14)],
            ),
          ),
        ),
        ClipRect(
          child: FutureBuilder<String?>(
            future: _backdropAsset(DefaultAssetBundle.of(context)),
            builder: (context, snapshot) {
              final path = snapshot.data;
              if (path == null) return const SizedBox.shrink();
              return RepaintBoundary(
                child: _Loop(
                  period: const Duration(seconds: 60),
                  builder: (_, t) => Transform.translate(
                    offset: Offset(math.sin(2 * math.pi * t) * 8, 0),
                    child: Transform.scale(
                      scale: 1.12 + .04 * _wave(t),
                      child: Image.asset(
                        path,
                        fit: BoxFit.cover,
                        cacheWidth: 1280,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xB8071410),
                Color(0x47071410),
                Color(0x57071410),
                Color(0xCC071410),
              ],
              stops: [0, .28, .65, 1],
            ),
          ),
        ),
        if (!still)
          IgnorePointer(
            child: RepaintBoundary(
              child: _Loop(
                period: const Duration(seconds: 30),
                builder: (_, t) => CustomPaint(painter: _FirefliesPainter(t)),
              ),
            ),
          ),
        child,
      ],
    );
  }
}

class _FirefliesPainter extends CustomPainter {
  const _FirefliesPainter(this.t);
  final double t;
  static double _r(int i, int k) =>
      (math.sin(i * 12.9898 + k * 78.233) * 43758.5453).abs() % 1;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    for (var i = 0; i < 22; i++) {
      final rise = (t * (1 + i % 3) + _r(i, 4)) % 1;
      final x =
          _r(i, 1) * size.width +
              math.sin((t * 2 + _r(i, 5)) * 2 * math.pi) * 14;
      final y = (_r(i, 2) * size.height + size.height - rise * size.height * .35) %
          size.height;
      final twinkle = (math.sin((t * 6 + _r(i, 6)) * 2 * math.pi) + 1) / 2;
      final alpha = (.12 + .5 * twinkle) * math.sin(math.pi * rise);
      canvas.drawCircle(
        Offset(x, y),
        1.2 + _r(i, 7) * 1.8,
        paint..color = const Color(0xFFFFE9A8).withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FirefliesPainter old) => old.t != t;
}

// ───────────────────────── Koleksi layar penuh ─────────────────────────

Future<void> showMedalCollection(
    BuildContext context,
    ProfileDetails profile, {
      MedalClaimsController? claims,
    }) async {
  if (!profile.googleLinked) return;
  await showDialog<void>(
    context: context,
    useSafeArea: false,
    builder: (context) => Dialog.fullscreen(
      backgroundColor: const Color(0xFF0B1A14),
      child: _MedalBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: _watchClaims(
                claims,
                    () => _MedalCollectionView(profile: profile, claims: claims),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Level 1: spanduk seri (3 kartu). Level 2: kartu medali dalam satu seri.
class _MedalCollectionView extends StatefulWidget {
  const _MedalCollectionView({required this.profile, this.claims});
  final ProfileDetails profile;
  final MedalClaimsController? claims;
  @override
  State<_MedalCollectionView> createState() => _MedalCollectionViewState();
}

class _MedalCollectionViewState extends State<_MedalCollectionView> {
  MedalSeries? _series;

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final claims = widget.claims;
    final series = _series;
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final pool = series == null
        ? profileMedals
        : [
      for (final m in profileMedals)
        if (m.series.id == series.id) m,
    ];
    final received = pool
        .where((m) => _stateOf(profile, m, claims) == _MedalState.received)
        .length;
    final verb = claims == null ? 'diraih' : 'diklaim';
    return PopScope(
      canPop: series == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _series = null);
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                if (series == null)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.emoji_events,
                      color: EmbunColors.gold,
                      size: 30,
                    ),
                  )
                else
                  IconButton(
                    key: const ValueKey('medal-series-back'),
                    tooltip: 'Kembali ke daftar seri',
                    onPressed: () => setState(() => _series = null),
                    icon: const Icon(Icons.arrow_back),
                  ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        series?.name ?? 'Koleksi Badge',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .4,
                          color: EmbunColors.gold,
                        ),
                      ),
                      Text(
                        series == null
                            ? '$received/${pool.length} badge $verb'
                            : '$received/${pool.length} badge $verb · ${medalNumber(series.valueOf(profile))} ${series.unit} tercatat',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup koleksi badge',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 4),
            child: _GlowBar(
              value: pool.isEmpty ? 0 : received / pool.length,
              color: series == null ? EmbunColors.gold : _seriesColor(series),
              height: 6,
            ),
          ),
          Expanded(
            child: series == null
                ? ListView.separated(
              key: const ValueKey('medal-collection-scroll'),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              itemCount: medalSeries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, i) =>
                  _seriesBanner(profile, claims, medalSeries[i], i),
            )
                : CustomScrollView(
              key: ValueKey('medal-series-scroll-${series.id}'),
              slivers: [
                SliverToBoxAdapter(
                  child: _SeriesHero(profile: profile, series: series),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate:
                    SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 160,
                      mainAxisExtent: 156 + 60 * scale,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 14,
                    ),
                    delegate: SliverChildBuilderDelegate(
                          (context, i) => _Entrance(
                        index: i,
                        child: _medalCard(
                          context,
                          profile,
                          claims,
                          ProfileMedal(series, i),
                        ),
                      ),
                      childCount: series.targets.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _seriesBanner(
      ProfileDetails profile,
      MedalClaimsController? claims,
      MedalSeries s,
      int index,
      ) {
    final color = _seriesColor(s);
    final medals = [
      for (var n = 0; n < s.targets.length; n++) ProfileMedal(s, n),
    ];
    final states = [for (final m in medals) _stateOf(profile, m, claims)];
    final done = states.where((e) => e == _MedalState.received).length;
    final cover =
        medals.where((m) => m.unlocked(profile)).lastOrNull ?? medals.first;
    final next = nextMedal(profile, s);
    return _Entrance(
      index: index,
      child: _MedalFrame(
        key: ValueKey('medal-series-${s.id}'),
        color: color,
        filled: done > 0,
        alert: states.contains(_MedalState.ready),
        onTap: () => setState(() => _series = s),
        child: Row(
          children: [
            _Stage(
              medal: cover,
              unlocked: cover.unlocked(profile),
              size: 68,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .3,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cover.unlocked(profile)
                        ? 'Tertinggi: ${cover.name}'
                        : 'Belum ada badge',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  _Pips(series: s, states: states),
                  const SizedBox(height: 6),
                  Text(
                    next == null
                        ? '$done/${medals.length} · Lengkap!'
                        : '$done/${medals.length} · Berikutnya ${medalNumber(next.valueOf(profile))}/${medalNumber(next.target)}',
                    style: const TextStyle(fontSize: 11, color: Colors.white60),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _medalCard(
      BuildContext context,
      ProfileDetails profile,
      MedalClaimsController? claims,
      ProfileMedal medal,
      ) {
    final state = _stateOf(profile, medal, claims);
    final locked = state == _MedalState.locked;
    return _MedalFrame(
      key: ValueKey('medal-${medal.id}'),
      color: locked ? EmbunColors.goldDim : medal.tint,
      alert: state == _MedalState.ready,
      dim: locked,
      filled: state != _MedalState.locked,
      onTap: () => showMedalDetails(context, profile, medal, claims: claims),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MedalArt(medal: medal, unlocked: !locked, size: 76),
          const SizedBox(height: 6),
          Text(
            medal.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: locked ? Colors.white70 : medal.tint,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            switch (state) {
              _MedalState.locked =>
              '${medalNumber(medal.valueOf(profile))}/${medalNumber(medal.target)}',
              _MedalState.ready =>
              claims?.initialized == false ? 'Memuat…' : 'Klaim!',
              _MedalState.received => 'Diraih',
            },
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: state == _MedalState.ready
                  ? FontWeight.w900
                  : FontWeight.w500,
              color: switch (state) {
                _MedalState.locked => Colors.white54,
                _MedalState.ready => EmbunColors.gold,
                _MedalState.received => EmbunColors.leaf,
              },
            ),
          ),
          const SizedBox(height: 6),
          _GlowBar(
            value: medal.progress(profile),
            color: locked ? EmbunColors.goldDim : medal.tint,
            height: 4,
          ),
        ],
      ),
    );
  }
}

/// Deretan penanda sepuluh tingkat dalam satu seri.
class _Pips extends StatelessWidget {
  const _Pips({required this.series, required this.states});
  final MedalSeries series;
  final List<_MedalState> states;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < states.length; i++)
        Expanded(
          child: Container(
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: switch (states[i]) {
                _MedalState.received => ProfileMedal(series, i).tint,
                _MedalState.ready => EmbunColors.gold,
                _MedalState.locked => Colors.white12,
              },
              boxShadow: states[i] == _MedalState.ready
                  ? [
                BoxShadow(
                  color: EmbunColors.gold.withValues(alpha: .8),
                  blurRadius: 6,
                ),
              ]
                  : null,
            ),
          ),
        ),
    ],
  );
}

/// Panggung seri: medali tertinggi dengan sinar, plus jalan menuju berikutnya.
class _SeriesHero extends StatelessWidget {
  const _SeriesHero({required this.profile, required this.series});
  final ProfileDetails profile;
  final MedalSeries series;
  @override
  Widget build(BuildContext context) {
    final color = _seriesColor(series);
    final medals = [
      for (var n = 0; n < series.targets.length; n++) ProfileMedal(series, n),
    ];
    final focus =
        medals.where((m) => m.unlocked(profile)).lastOrNull ?? medals.first;
    final next = nextMedal(profile, series);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: _panelDecoration(color),
      child: Column(
        children: [
          _Stage(medal: focus, unlocked: focus.unlocked(profile), size: 96),
          Text(
            focus.unlocked(profile) ? focus.name : series.name,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: .3,
              color: color,
            ),
          ),
          if (focus.unlocked(profile)) ...[
            const SizedBox(height: 2),
            _TierLabel(focus),
          ],
          const SizedBox(height: 10),
          if (next == null)
            const Text(
              'Semua badge seri ini sudah diraih!',
              style: TextStyle(
                color: EmbunColors.leaf,
                fontWeight: FontWeight.w800,
              ),
            )
          else ...[
            Text(
              'Berikutnya: ${next.name}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            _GlowBar(value: next.progress(profile), color: color, height: 8),
            const SizedBox(height: 6),
            Text(
              '${medalNumber(next.valueOf(profile))} / ${medalNumber(next.target)} ${series.unit}',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────── Rincian & klaim ─────────────────────────

Future<void> showMedalDetails(
    BuildContext context,
    ProfileDetails profile,
    ProfileMedal medal, {
      MedalClaimsController? claims,
    }) async {
  if (!profile.googleLinked) return;
  final unlocked = medal.unlocked(profile);
  final next = nextMedal(profile, medal.series);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF0E211A),
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      side: BorderSide(
        color: (unlocked ? medal.tint : EmbunColors.goldDim).withValues(
          alpha: .6,
        ),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    constraints: const BoxConstraints(maxWidth: 540),
    builder: (context) => _watchClaims(claims, () {
      final received = claims == null || claims.isClaimed(medal);
      final status = !unlocked
          ? 'Belum diraih'
          : received
          ? 'Sudah diraih'
          : claims.initialized
          ? 'Siap diklaim'
          : 'Memuat status klaim…';
      final statusColor = !unlocked
          ? Colors.white70
          : received
          ? EmbunColors.leaf
          : EmbunColors.gold;
      final progress = medal.progress(profile);
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -.8),
            radius: 1.0,
            colors: [
              (unlocked ? medal.tint : Colors.white).withValues(alpha: .20),
              Colors.transparent,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Tutup rincian badge',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              Center(
                child: _Stage(medal: medal, unlocked: unlocked, size: 124),
              ),
              const SizedBox(height: 4),
              Center(child: _TierLabel(medal)),
              const SizedBox(height: 6),
              Text(
                medal.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .4,
                  color: unlocked ? medal.tint : EmbunColors.gold,
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: statusColor.withValues(alpha: .12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: .6),
                    ),
                  ),
                  child: Text(
                    status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                medal.series.requirement(medal.target),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Semantics(
                label: 'Progres ${medal.name}',
                value: '${(progress * 100).round()}%',
                child: _GlowBar(
                  value: progress,
                  color: unlocked ? medal.tint : EmbunColors.goldDim,
                  height: 10,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Total tercatat: ${medalNumber(medal.valueOf(profile))} ${medal.series.unit}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              if (!unlocked)
                Text(
                  '${medalNumber(medal.valueOf(profile))} / ${medalNumber(medal.target)}',
                  textAlign: TextAlign.center,
                  key: const ValueKey('medal-detail-progress'),
                ),
              if (unlocked && next != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'Berikutnya: ${next.name} · ${medalNumber(next.valueOf(profile))}/${medalNumber(next.target)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60),
                  ),
                ),
              const SizedBox(height: 20),
              if (claims != null && unlocked && !claims.isClaimed(medal)) ...[
                if (claims.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      claims.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFFFB5A8)),
                    ),
                  ),
                FilledButton.icon(
                  key: ValueKey('claim-detail-${medal.id}'),
                  style: _goldButton.copyWith(
                    minimumSize: const WidgetStatePropertyAll(Size(0, 54)),
                  ),
                  onPressed: !claims.initialized || claims.claimingId != null
                      ? null
                      : () => claimMedalWithCelebration(context, claims, medal),
                  icon: const Icon(Icons.emoji_events),
                  label: Text(
                    claims.claimingId == medal.id
                        ? 'Menyimpan…'
                        : 'Klaim medali',
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      );
    }),
  );
}

Widget _watchClaims(MedalClaimsController? claims, Widget Function() builder) =>
    claims == null
        ? builder()
        : ListenableBuilder(listenable: claims, builder: (_, _) => builder());

Future<void> claimMedalWithCelebration(
    BuildContext context,
    MedalClaimsController claims,
    ProfileMedal medal,
    ) async {
  final saved = await claims.claim(medal);
  if (!saved || !context.mounted || !claims.active) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => MedalClaimCelebration(
      medal: medal,
      art: MedalArt(medal: medal, unlocked: true, size: 200),
    ),
  );
}