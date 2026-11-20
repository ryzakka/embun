import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/profile_medals.dart';
import '../../data/profile_repository.dart';
import '../common/ornate.dart';

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
    final earned = earnedMedals(profile);
    final highest = highestMedals(profile);
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
            '${earned.length}/${profileMedals.length} badge diraih',
            key: const ValueKey('medals-earned-count'),
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
          const SizedBox(height: 12),
          if (highest.isEmpty)
            const Text(
              'Belum ada badge yang diraih.',
              style: TextStyle(color: Colors.white60),
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
                      onTap: () => showMedalDetails(context, profile, medal),
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
              onPressed: () => showMedalCollection(context, profile),
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
  ProfileDetails profile,
) async {
  if (!profile.googleLinked) return;
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF11271E),
    constraints: const BoxConstraints(maxWidth: 680),
    builder: (context) => FractionallySizedBox(
      heightFactor: .9,
      child: Column(
        children: [
          ListTile(
            title: const Text('Koleksi Badge'),
            subtitle: Text(
              '${earnedMedals(profile).length}/${profileMedals.length} badge diraih',
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
                              onTap: () =>
                                  showMedalDetails(context, profile, medal),
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
                                        ? 'Diraih'
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
  );
}

Future<void> showMedalDetails(
  BuildContext context,
  ProfileDetails profile,
  ProfileMedal medal,
) async {
  if (!profile.googleLinked) return;
  final unlocked = medal.unlocked(profile);
  final next = nextMedal(profile, medal.series);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF11271E),
    constraints: const BoxConstraints(maxWidth: 540),
    builder: (context) => SingleChildScrollView(
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
            unlocked ? 'Sudah diraih' : 'Belum diraih',
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
        ],
      ),
    ),
  );
}
