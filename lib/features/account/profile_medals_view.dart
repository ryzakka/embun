import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/profile_medals.dart';
import '../../data/profile_repository.dart';
import '../../data/medal_claims.dart';
import '../common/ornate.dart';
import 'medal_claim_scope.dart';
import 'medal_claim_celebration.dart';

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

class MedalArt extends StatelessWidget {
  const MedalArt({
    super.key,
    required this.medal,
    required this.unlocked,
    this.size = 76,
  });
  final ProfileMedal medal;
  final bool unlocked;
  final double size;
  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      switch (medal.series.metric) {
        MedalMetric.wargaWins => Icons.shield_outlined,
        MedalMetric.terbisikWins => Icons.nights_stay_outlined,
        MedalMetric.completed => Icons.sports_esports_outlined,
      },
      size: size * .65,
      color: EmbunColors.gold,
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
          if (unlocked)
            art
          else
            Opacity(
              opacity: .35,
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  .2126,
                  .7152,
                  .0722,
                  0,
                  0,
                  .2126,
                  .7152,
                  .0722,
                  0,
                  0,
                  .2126,
                  .7152,
                  .0722,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                ]),
                child: art,
              ),
            ),
          if (!unlocked)
            const Positioned(
              right: 0,
              bottom: 0,
              child: Icon(Icons.lock_outline, size: 19, color: Colors.white70),
            ),
        ],
      ),
    );
  }
}

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Koleksi Badge',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: EmbunColors.gold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            claims == null
                ? '${earned.length}/${profileMedals.length} badge diraih'
                : '${received.length}/${profileMedals.length} badge diklaim',
            key: const ValueKey('medals-earned-count'),
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
          const SizedBox(height: 12),
          if (claims != null) ...[
            if (claims.loading && !claims.initialized)
              const Text('Menyiapkan koleksi medali…'),
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
              Semantics(
                liveRegion: true,
                child: Text(
                  '${claims.pending.length} medali baru siap diklaim',
                  style: const TextStyle(
                    color: EmbunColors.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final medal in claims.pending)
                    OutlinedButton.icon(
                      key: ValueKey('claim-summary-${medal.id}'),
                      onPressed: claims.claimingId != null
                          ? null
                          : () => claimMedalWithCelebration(
                        context,
                        claims,
                        medal,
                      ),
                      icon: const Icon(Icons.emoji_events_outlined, size: 20),
                      label: Text(
                        claims.claimingId == medal.id
                            ? 'Menyimpan…'
                            : 'Klaim ${medal.name}',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ],
          if (highest.isEmpty)
            Text(
              claims == null
                  ? 'Belum ada badge yang diraih.'
                  : 'Belum ada medali yang diklaim.',
              style: const TextStyle(color: Colors.white60),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final medal in highest)
                  SizedBox(
                    width: 132,
                    child: InkWell(
                      key: ValueKey('medal-summary-${medal.id}'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => showMedalDetails(
                        context,
                        displayed,
                        medal,
                        claims: claims,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          children: [
                            MedalArt(medal: medal, unlocked: true),
                            const SizedBox(height: 6),
                            Text(
                              medal.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${medalNumber(medal.target)} ${medal.series.unit}',
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
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('open-medal-collection'),
              onPressed: () =>
                  showMedalCollection(context, displayed, claims: claims),
              icon: const Icon(Icons.emoji_events_outlined),
              label: const Text('Lihat koleksi'),
            ),
          ),
        ],
      ),
    );
  }
}

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
  );
}

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

/// Level 1: kartu seri (3 kartu). Level 2: kartu medali dalam satu seri.
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
        : [for (final m in profileMedals) if (m.series.id == series.id) m];
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
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
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
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
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
          Expanded(
            child: series == null
                ? GridView.builder(
              key: const ValueKey('medal-collection-scroll'),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisExtent: 190 + 60 * scale,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: medalSeries.length,
              itemBuilder: (context, i) {
                final s = medalSeries[i];
                final medals = [
                  for (var n = 0; n < s.targets.length; n++)
                    ProfileMedal(s, n),
                ];
                final states = [
                  for (final m in medals) _stateOf(profile, m, claims),
                ];
                final done = states
                    .where((e) => e == _MedalState.received)
                    .length;
                final cover =
                    medals
                        .where((m) => m.unlocked(profile))
                        .lastOrNull ??
                        medals.first;
                final ratio = done / medals.length;
                return _MedalFrame(
                  key: ValueKey('medal-series-${s.id}'),
                  alert: states.contains(_MedalState.ready),
                  onTap: () => setState(() => _series = s),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      MedalArt(
                        medal: cover,
                        unlocked: cover.unlocked(profile),
                        size: 72,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: EmbunColors.gold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(ratio * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _FrameBar(value: ratio),
                    ],
                  ),
                );
              },
            )
                : GridView.builder(
              key: ValueKey('medal-series-scroll-${series.id}'),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 150,
                mainAxisExtent: 134 + 56 * scale,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: series.targets.length,
              itemBuilder: (context, i) {
                final medal = ProfileMedal(series, i);
                final state = _stateOf(profile, medal, claims);
                final locked = state == _MedalState.locked;
                return _MedalFrame(
                  key: ValueKey('medal-${medal.id}'),
                  alert: state == _MedalState.ready,
                  dim: locked,
                  onTap: () => showMedalDetails(
                    context,
                    profile,
                    medal,
                    claims: claims,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      MedalArt(
                        medal: medal,
                        unlocked: !locked,
                        size: 72,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        medal.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: locked
                              ? Colors.white70
                              : EmbunColors.gold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        switch (state) {
                          _MedalState.locked =>
                          '${medalNumber(medal.valueOf(profile))}/${medalNumber(medal.target)}',
                          _MedalState.ready =>
                          claims?.initialized == false
                              ? 'Memuat…'
                              : 'Klaim!',
                          _MedalState.received => 'Diraih',
                        },
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: state == _MedalState.ready
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: switch (state) {
                            _MedalState.locked => Colors.white54,
                            _MedalState.ready => EmbunColors.gold,
                            _MedalState.received => EmbunColors.leaf,
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      _FrameBar(value: medal.progress(profile)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FrameBar extends StatelessWidget {
  const _FrameBar({required this.value});
  final double value;
  @override
  Widget build(BuildContext context) => LinearProgressIndicator(
    value: value,
    minHeight: 2,
    backgroundColor: Colors.white12,
    color: EmbunColors.gold,
  );
}

/// Kartu berbingkai lengkung-cekung bergaya "achievement".
class _MedalFrame extends StatelessWidget {
  const _MedalFrame({
    super.key,
    required this.child,
    required this.onTap,
    this.alert = false,
    this.dim = false,
  });
  final Widget child;
  final VoidCallback onTap;
  final bool alert, dim;
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned.fill(
        child: CustomPaint(
          painter: _FramePainter(glow: alert, dim: dim),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
                child: child,
              ),
            ),
          ),
        ),
      ),
      if (alert)
        Positioned(
          top: -3,
          right: -3,
          child: IgnorePointer(
            child: Container(
              key: const ValueKey('medal-card-alert'),
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                shape: BoxShape.circle,
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
  const _FramePainter({required this.glow, required this.dim});
  final bool glow, dim;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      _framePath((Offset.zero & size).deflate(1), 16),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = glow ? 2 : 1.2
        ..color = EmbunColors.gold.withValues(
          alpha: glow ? 1 : (dim ? .3 : .7),
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _FramePainter old) =>
      old.glow != glow || old.dim != dim;
}

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
    backgroundColor: const Color(0xFF11271E),
    constraints: const BoxConstraints(maxWidth: 540),
    builder: (context) => _watchClaims(
      claims,
          () => SingleChildScrollView(
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
              child: MedalArt(medal: medal, unlocked: unlocked, size: 124),
            ),
            const SizedBox(height: 12),
            Text(
              medal.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: EmbunColors.gold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              !unlocked
                  ? 'Belum diraih'
                  : claims == null || claims.isClaimed(medal)
                  ? 'Sudah diraih'
                  : claims.initialized
                  ? 'Siap diklaim'
                  : 'Memuat status klaim…',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: unlocked ? EmbunColors.leaf : Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              medal.series.requirement(medal.target),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: medal.progress(profile),
              semanticsLabel: 'Progres ${medal.name}',
              semanticsValue: '${(medal.progress(profile) * 100).round()}%',
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
                Text(
                  claims.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFFFB5A8)),
                ),
              FilledButton(
                key: ValueKey('claim-detail-${medal.id}'),
                onPressed: !claims.initialized || claims.claimingId != null
                    ? null
                    : () => claimMedalWithCelebration(context, claims, medal),
                child: Text(
                  claims.claimingId == medal.id ? 'Menyimpan…' : 'Klaim medali',
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
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
  final saved = await claims.claim(medal);
  if (!saved || !context.mounted || !claims.active) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => MedalClaimCelebration(
      medal: medal,
      art: MedalArt(medal: medal, unlocked: true, size: 148),
    ),
  );
}