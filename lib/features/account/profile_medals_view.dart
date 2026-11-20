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
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF11271E),
    constraints: const BoxConstraints(maxWidth: 680),
    builder: (context) => _watchClaims(
      claims,
      () => FractionallySizedBox(
        heightFactor: .9,
        child: Column(
          children: [
            ListTile(
              title: const Text('Koleksi Badge'),
              subtitle: Text(
                claims == null
                    ? '${earnedMedals(profile).length}/${profileMedals.length} badge diraih'
                    : '${earnedMedals(profile).where(claims.isClaimed).length}/${profileMedals.length} badge diklaim',
              ),
              trailing: IconButton(
                tooltip: 'Tutup koleksi badge',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
                  return CustomScrollView(
                    key: const ValueKey('medal-collection-scroll'),
                    slivers: [
                      for (final series in medalSeries) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  series.name,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    color: EmbunColors.gold,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${medalNumber(series.valueOf(profile))} ${series.unit} tercatat',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          sliver: SliverGrid.builder(
                            gridDelegate:
                                SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 180,
                                  mainAxisExtent: 96 + 64 * scale,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                            itemCount: series.targets.length,
                            itemBuilder: (context, i) {
                              final medal = ProfileMedal(series, i);
                              final unlocked = medal.unlocked(profile);
                              return InkWell(
                                key: ValueKey('medal-${medal.id}'),
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => showMedalDetails(
                                  context,
                                  profile,
                                  medal,
                                  claims: claims,
                                ),
                                child: Column(
                                  children: [
                                    MedalArt(medal: medal, unlocked: unlocked),
                                    const SizedBox(height: 6),
                                    Text(
                                      medal.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      medalNumber(medal.target),
                                      maxLines: 1,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    Text(
                                      unlocked
                                          ? claims == null ||
                                                    claims.isClaimed(medal)
                                                ? 'Diraih'
                                                : claims.initialized
                                                ? 'Klaim'
                                                : 'Memuat…'
                                          : '${medalNumber(medal.valueOf(profile))}/${medalNumber(medal.target)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: unlocked
                                            ? EmbunColors.leaf
                                            : Colors.white54,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
