import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../../data/profile_medals.dart';
import '../../data/profile_repository.dart';
import '../../data/medal_claims.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import '../guide/learning_frame.dart';
import 'medal_claim_scope.dart';
import 'medal_claim_celebration.dart';
import 'profile_style.dart';

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

String _seriesIcon(MedalSeries s) => switch (s.metric) {
  MedalMetric.wargaWins => 'persona',
  MedalMetric.terbisikWins => 'danger',
  MedalMetric.completed => 'hari',
};

String _seriesSub(MedalSeries s) => switch (s.metric) {
  MedalMetric.wargaWins => 'Kemenangan sebagai Warga Desa',
  MedalMetric.terbisikWins => 'Kemenangan sebagai Si Terbisik',
  MedalMetric.completed => 'Pertandingan selesai',
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
                    medal.tint.withValues(alpha: .7),
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
              opacity: .82,
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

Widget _alertDot({Key? key}) => IgnorePointer(
  child: Container(
    key: key,
    width: 18,
    height: 18,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xFFEF4444),
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFF0B1A14), width: 2),
    ),
    child: const Text(
      '!',
      style: TextStyle(
        fontSize: 10,
        height: 1,
        fontWeight: FontWeight.w900,
        color: Colors.white,
      ),
    ),
  ),
);

final _goldButton = FilledButton.styleFrom(
  backgroundColor: EmbunColors.gold,
  foregroundColor: const Color(0xFF1A1405),
  disabledBackgroundColor: const Color(0xFF3A3420),
  disabledForegroundColor: Colors.white38,
);

// ───────────────────────── Ringkasan di profil ─────────────────────────

class ProfileMedalsSummary extends StatelessWidget {
  const ProfileMedalsSummary({
    super.key,
    required this.profile,
    this.framed = true,
  });
  final ProfileDetails profile;

  /// true = membawa judul bagiannya sendiri (ikon + garis atas);
  /// false = hanya isi, untuk disematkan di bagian yang sudah berjudul.
  final bool framed;
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
    final countText = claims == null
        ? '${earned.length}/${profileMedals.length} badge diraih'
        : '${received.length}/${profileMedals.length} badge diklaim';

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            countText,
            key: const ValueKey('medals-earned-count'),
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
        ),
        ProfileMeter(
          value: received.length / profileMedals.length,
          color: EmbunColors.gold,
        ),
        const SizedBox(height: 12),
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
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: claims.loading || claims.claimingId != null
                    ? null
                    : () => claims.refresh(details: profile),
                child: const Text('Coba lagi status medali'),
              ),
            ),
          ],
          if (claims.hasPending) ...[
            _ClaimBanner(claims: claims),
            const SizedBox(height: 12),
          ],
        ],
        if (highest.isEmpty)
          ProfileRow(
            accent: Colors.white,
            visualSize: 30,
            visual: const Icon(
              Icons.lock_outline,
              color: Colors.white38,
              size: 22,
            ),
            title: claims == null
                ? 'Belum ada badge yang diraih.'
                : 'Belum ada medali yang diklaim.',
            titleColor: Colors.white60,
          )
        else
          LayoutBuilder(
            builder: (context, box) {
              final w = ((box.maxWidth - 16) / 3).floorToDouble().clamp(
                88.0,
                180.0,
              );
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < highest.length; i++)
                    SizedBox(
                      width: w,
                      child: ProfileReveal(
                        index: i,
                        child: _HighestTile(
                          key: ValueKey('medal-summary-${highest[i].id}'),
                          medal: highest[i],
                          width: w,
                          onTap: () => showMedalDetails(
                            context,
                            displayed,
                            highest[i],
                            claims: claims,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        const SizedBox(height: 6),
        if (claims != null && claims.initialized) ...[
          const SizedBox(height: 14),
          Text(
            medalSeries.every((s) => nextMedal(displayed, s) == null)
                ? 'Seluruh target medali tercapai'
                : 'Pencapaian berikutnya',
            style: profileCaps,
          ),
          for (final series in medalSeries)
            if (nextMedal(displayed, series) case final ProfileMedal next)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      next.name,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 5),
                    ProfileMeter(
                      value: next.progress(displayed),
                      color: _seriesColor(series),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${medalNumber(next.valueOf(displayed))}/${medalNumber(next.target)} ${series.unit}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('open-medal-collection'),
            style: TextButton.styleFrom(
              foregroundColor: EmbunColors.gold,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onPressed: () =>
                showMedalCollection(context, displayed, claims: claims),
            icon: const Icon(Icons.emoji_events_outlined, size: 20),
            label: const Text('Lihat koleksi'),
          ),
        ),
      ],
    );

    if (!framed) return body;
    return ProfileSection(
      icon: 'helaidaun',
      title: 'Koleksi Badge',
      children: [body],
    );
  }
}

/// Medali tertinggi satu seri: terbuka, garis bawah sewarna tingkat.
class _HighestTile extends StatelessWidget {
  const _HighestTile({
    super.key,
    required this.medal,
    required this.width,
    required this.onTap,
  });
  final ProfileMedal medal;
  final double width;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: medal.tint, width: 2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MedalArt(
              medal: medal,
              unlocked: true,
              size: math.min(96, width - 20),
            ),
            const SizedBox(height: 8),
            Text(
              medal.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: EmbunColors.cream,
              ),
            ),
            const SizedBox(height: 3),
            _TierLabel(medal),
            const SizedBox(height: 3),
            Text(
              '${medalNumber(medal.target)} ${medal.series.unit}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.white60),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Spanduk datar (hanya dua garis emas yang berdenyut) untuk medali siap klaim.
class _ClaimBanner extends StatelessWidget {
  const _ClaimBanner({required this.claims});
  final MedalClaimsController claims;
  @override
  Widget build(BuildContext context) => _Loop(
    period: const Duration(milliseconds: 2200),
    builder: (context, t) {
      final side = BorderSide(
        color: EmbunColors.gold.withValues(alpha: .35 + .5 * _wave(t)),
        width: 1.5,
      );
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(top: side, bottom: side),
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

// ───────────────────────── Koleksi layar penuh ─────────────────────────

/// Halaman penuh bergaya Panduan: daftar seri | grid medali | penyaring.
Future<void> showMedalCollection(
  BuildContext context,
  ProfileDetails profile, {
  MedalClaimsController? claims,
}) async {
  if (!profile.googleLinked) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => _watchClaims(
        claims,
        () => _MedalCollectionPage(profile: profile, claims: claims),
      ),
    ),
  );
}

const _collectionWide = 880.0;
const _statusLabels = ['Semua', 'Siap diklaim', 'Diraih', 'Terkunci'];

class _MedalCollectionPage extends StatefulWidget {
  const _MedalCollectionPage({required this.profile, this.claims});
  final ProfileDetails profile;
  final MedalClaimsController? claims;
  @override
  State<_MedalCollectionPage> createState() => _MedalCollectionPageState();
}

class _MedalCollectionPageState extends State<_MedalCollectionPage> {
  int _side = 0; // 0 = semua seri, 1.. = seri
  int _status = 0;

  List<ProfileMedal> _medalsOf(MedalSeries s) => [
    for (var i = 0; i < s.targets.length; i++) ProfileMedal(s, i),
  ];

  bool _matches(_MedalState s) => switch (_status) {
    1 => s == _MedalState.ready,
    2 => s == _MedalState.received,
    3 => s == _MedalState.locked,
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final claims = widget.claims;
    final series = _side == 0 ? null : medalSeries[_side - 1];
    final accent = series == null ? EmbunColors.gold : _seriesColor(series);
    final shown = series == null ? medalSeries : [series];
    final pool = [for (final s in shown) ..._medalsOf(s)];
    final received = pool
        .where((m) => _stateOf(profile, m, claims) == _MedalState.received)
        .length;
    final verb = claims == null ? 'diraih' : 'diklaim';

    int doneOf(MedalSeries s) => _medalsOf(
      s,
    ).where((m) => _stateOf(profile, m, claims) == _MedalState.received).length;

    Widget tab(int i, {required bool compact}) {
      final s = i == 0 ? null : medalSeries[i - 1];
      return ProfileTab(
        key: s == null
            ? const ValueKey('medal-series-all')
            : ValueKey('medal-series-${s.id}'),
        label: s?.name ?? 'Semua',
        sub: s == null ? 'Seluruh seri badge' : _seriesSub(s),
        icon: s == null ? 'helaidaun' : _seriesIcon(s),
        count: s == null
            ? '$received/${profileMedals.length}'
            : '${doneOf(s)}/${s.targets.length}',
        accent: s == null ? EmbunColors.gold : _seriesColor(s),
        selected: i == _side,
        compact: compact,
        onTap: () => setState(() {
          _side = i;
          _status = 0;
        }),
      );
    }

    final filter = ProfileFilter(
      title: 'Status',
      options: _statusLabels,
      selected: _status,
      accent: accent,
      onSelect: (i) => setState(() => _status = i),
    );

    Widget content() {
      final children = <Widget>[
        Text(
          '$received/${pool.length} badge $verb',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: accent,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Ketuk medali untuk rincian. Medali yang sudah diraih tapi belum diklaim ditandai "!".',
          style: const TextStyle(fontSize: 12, color: Colors.white60),
        ),
        const SizedBox(height: 14),
      ];
      var any = false;
      for (var si = 0; si < shown.length; si++) {
        final s = shown[si];
        final medals = [
          for (final m in _medalsOf(s))
            if (_matches(_stateOf(profile, m, claims))) m,
        ];
        if (series != null) {
          children.add(
            ProfileReveal(
              child: _SeriesHero(profile: profile, series: s),
            ),
          );
        }
        if (medals.isEmpty) continue;
        any = true;
        final grid = _grid(context, profile, claims, medals);
        if (series != null) {
          children.add(grid);
        } else {
          children.add(
            ProfileReveal(
              index: si,
              child: ProfileSection(
                icon: _seriesIcon(s),
                title: s.name,
                accent: _seriesColor(s),
                trailing: '${doneOf(s)}/${s.targets.length}',
                children: [
                  ProfileMeter(
                    value: doneOf(s) / s.targets.length,
                    color: _seriesColor(s),
                  ),
                  const SizedBox(height: 12),
                  grid,
                ],
              ),
            ),
          );
        }
      }
      if (!any) {
        children.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Text(
                'Tidak ada medali yang cocok.',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    return LearningFrame(
      title: 'Koleksi Badge',
      icon: 'helaidaun',
      background:
          sceneryPath('papanmedali-latar') ??
          sceneryPath('perpustakaantua') ??
          landscapePath(30),
      child: LayoutBuilder(
        builder: (context, box) {
          if (box.maxWidth >= _collectionWide) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 220,
                    child: ProfileReveal(
                      dx: -24,
                      dy: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(right: profileRule(accent)),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(right: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i <= medalSeries.length; i++)
                                tab(i, compact: false),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SingleChildScrollView(
                        key: ValueKey(
                          'medal-series-scroll-${series?.id ?? 'all'}',
                        ),
                        padding: const EdgeInsets.only(bottom: 16),
                        child: content(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 230,
                    child: ProfileReveal(
                      dx: 24,
                      dy: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(left: profileRule(accent)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: filter,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          final pad = box.maxWidth < 420 ? 10.0 : 14.0;
          return SingleChildScrollView(
            key: const ValueKey('medal-collection-scroll'),
            padding: EdgeInsets.fromLTRB(pad, 10, pad, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i <= medalSeries.length; i++)
                        Expanded(child: tab(i, compact: true)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                filter,
                const SizedBox(height: 16),
                content(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _grid(
    BuildContext context,
    ProfileDetails profile,
    MedalClaimsController? claims,
    List<ProfileMedal> medals,
  ) => LayoutBuilder(
    builder: (context, c) {
      const gap = 12.0;
      final avail = c.maxWidth.isFinite ? c.maxWidth : 360.0;
      final cols = ((avail + gap) / (148 + gap)).floor().clamp(2, 5).toInt();
      final w = ((avail - gap * (cols - 1)) / cols).floorToDouble();
      return Wrap(
        spacing: gap,
        runSpacing: 16,
        children: [
          for (var i = 0; i < medals.length; i++)
            SizedBox(
              width: w,
              child: ProfileReveal(
                index: i,
                dy: 24,
                scaleFrom: .86,
                child: _medalCell(context, profile, claims, medals[i], w),
              ),
            ),
        ],
      );
    },
  );

  Widget _medalCell(
    BuildContext context,
    ProfileDetails profile,
    MedalClaimsController? claims,
    ProfileMedal medal,
    double cellWidth,
  ) {
    final state = _stateOf(profile, medal, claims);
    final locked = state == _MedalState.locked;
    final ready = state == _MedalState.ready;
    final color = locked ? EmbunColors.goldDim : medal.tint;
    final art = (cellWidth - 8).clamp(84.0, 124.0).toDouble();
    final cell = Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('medal-${medal.id}'),
        onTap: () => showMedalDetails(context, profile, medal, claims: claims),
        child: Container(
          padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: ready
                  ? const BorderSide(color: EmbunColors.gold, width: 2)
                  : profileRule(color),
            ),
          ),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  if (!locked)
                    Container(
                      width: art * 1.15,
                      height: art * 1.15,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: medal.tint.withValues(alpha: .35),
                            blurRadius: 26,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  MedalArt(medal: medal, unlocked: !locked, size: art),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 34,
                child: Center(
                  child: Text(
                    medal.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      color: locked ? Colors.white70 : medal.tint,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
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
                  fontWeight: ready ? FontWeight.w900 : FontWeight.w500,
                  color: switch (state) {
                    _MedalState.locked => Colors.white54,
                    _MedalState.ready => EmbunColors.gold,
                    _MedalState.received => EmbunColors.leaf,
                  },
                ),
              ),
              const SizedBox(height: 6),
              ProfileMeter(value: medal.progress(profile), color: color),
            ],
          ),
        ),
      ),
    );
    if (!ready) return cell;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        cell,
        Positioned(
          top: -2,
          right: -2,
          child: _alertDot(key: const ValueKey('medal-card-alert')),
        ),
      ],
    );
  }
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(border: Border(bottom: profileRule(color))),
      child: Row(
        children: [
          _Stage(medal: focus, unlocked: focus.unlocked(profile), size: 104),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  focus.unlocked(profile) ? focus.name : series.name,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .3,
                    color: color,
                  ),
                ),
                if (focus.unlocked(profile)) ...[
                  const SizedBox(height: 2),
                  _TierLabel(focus),
                ],
                const SizedBox(height: 4),
                Text(
                  '${medalNumber(series.valueOf(profile))} ${series.unit} tercatat',
                  style: const TextStyle(fontSize: 12, color: Colors.white60),
                ),
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
                  const SizedBox(height: 6),
                  ProfileMeter(
                    value: next.progress(profile),
                    color: color,
                    height: 6,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${medalNumber(next.valueOf(profile))} / ${medalNumber(next.target)} ${series.unit}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
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
    backgroundColor: Colors.transparent,
    elevation: 0,
    constraints: const BoxConstraints(maxWidth: 540),
    builder: (context) => ProfileSheetFrame(
      asset: sceneryPath('sheetmedal-latar'),
      child: _watchClaims(claims, () {
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
        final tint = unlocked ? medal.tint : EmbunColors.goldDim;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  GameIcon(_seriesIcon(medal.series), size: 27),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        medal.series.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: EmbunColors.cream,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup rincian badge',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(context),
                    icon: const GameIcon('silang', size: 22),
                  ),
                ],
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(bottom: profileRule()),
                ),
                child: const SizedBox(height: 4),
              ),
              const SizedBox(height: 8),
              Center(
                child: _Stage(medal: medal, unlocked: unlocked, size: 150),
              ),
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
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Semantics(
                label: 'Progres ${medal.name}',
                value: '${(progress * 100).round()}%',
                child: ProfileMeter(value: progress, color: tint, height: 8),
              ),
              if (!unlocked)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${medalNumber(medal.valueOf(profile))} / ${medalNumber(medal.target)}',
                    textAlign: TextAlign.center,
                    key: const ValueKey('medal-detail-progress'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              const SizedBox(height: 14),
              ProfileRow(
                accent: tint,
                visualSize: 30,
                visual: Icon(Icons.flag_outlined, color: tint, size: 24),
                label: 'SYARAT',
                title: medal.series.requirement(medal.target),
              ),
              ProfileRow(
                accent: tint,
                visualSize: 30,
                visual: Icon(Icons.timeline, color: tint, size: 24),
                label: 'TOTAL TERCATAT',
                title:
                    '${medalNumber(medal.valueOf(profile))} ${medal.series.unit}',
              ),
              if (unlocked && next != null)
                ProfileRow(
                  accent: next.tint,
                  visualSize: 30,
                  visual: Icon(Icons.trending_up, color: next.tint, size: 24),
                  label: 'BERIKUTNYA',
                  title: next.name,
                  text:
                      '${medalNumber(next.valueOf(profile))}/${medalNumber(next.target)} ${next.series.unit}',
                ),
              const SizedBox(height: 12),
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
              ],
            ],
          ),
        );
      }),
    ),
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
  final highestReceived = profileMedals
      .where(
        (m) =>
            m.series.id == medal.series.id &&
            claims.isClaimed(m) &&
            claims.profile != null &&
            m.unlocked(claims.profile!),
      )
      .lastOrNull;
  final previous =
      highestReceived != null && highestReceived.index < medal.index
      ? highestReceived
      : null;
  final saved = await claims.claim(medal);
  if (!saved || !context.mounted || !claims.active) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => MedalClaimCelebration(
      medal: medal,
      previousMedal: previous,
      art: MedalArt(medal: medal, unlocked: true, size: 200),
    ),
  );
}
