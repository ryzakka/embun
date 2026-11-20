import 'package:flutter/material.dart';
import '../../data/medal_claims.dart';
import '../../data/profile_medals.dart';
import '../../data/profile_repository.dart';
import '../common/ornate.dart';
import 'medal_claim_scope.dart';
import 'profile_medals_view.dart';

List<ProfileMedal> showcasedMedals(
  String userId,
  RoomAccountProfile? profile,
  MedalClaimsController? claims,
) {
  final mine =
      claims?.userId == userId &&
      claims?.initialized == true &&
      claims?.profile != null;
  final ids = mine
      ? earnedMedals(
          claims!.profile!,
        ).where(claims.isClaimed).map((m) => m.id).toSet()
      : profile?.googleLinked == true && profile?.medalsAvailable == true
      ? profile!.medalIds.toSet()
      : <String>{};
  return [
    for (final series in medalSeries)
      if (profileMedals
              .where((m) => m.series.id == series.id && ids.contains(m.id))
              .lastOrNull
          case final ProfileMedal medal)
        medal,
  ];
}

/// A maximum of one received medal per series, never pending achievements.
class RoomMedalStrip extends StatelessWidget {
  const RoomMedalStrip({
    super.key,
    required this.userId,
    this.profile,
    this.onViewProfile,
    this.size = 27,
  });
  final String userId;
  final RoomAccountProfile? profile;
  final VoidCallback? onViewProfile;
  final double size;
  @override
  Widget build(BuildContext context) {
    final medals = showcasedMedals(
      userId,
      profile,
      MedalClaimScope.maybeOf(context),
    );
    if (medals.isEmpty) return const SizedBox.shrink();
    return Wrap(
      key: ValueKey('showcase-$userId'),
      spacing: 3,
      runSpacing: 3,
      children: [
        for (final medal in medals)
          Tooltip(
            message: medal.name,
            child: InkResponse(
              key: ValueKey('showcase-$userId-${medal.id}'),
              onTap: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(medal.name),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MedalArt(medal: medal, unlocked: true, size: 110),
                      const SizedBox(height: 12),
                      Text(
                        medal.series.requirement(medal.target),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sudah diklaim',
                        style: TextStyle(color: EmbunColors.leaf),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Tutup'),
                    ),
                    if (onViewProfile != null)
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onViewProfile!();
                        },
                        child: const Text('Lihat profil'),
                      ),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: MedalArt(
                  medal: medal,
                  unlocked: true,
                  size: size,
                  glow: false,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Visible only after a match. Refreshes existing account counters, no claim.
class EndingMedalNotice extends StatefulWidget {
  const EndingMedalNotice({super.key, this.onOpenProfile});
  final VoidCallback? onOpenProfile;
  @override
  State<EndingMedalNotice> createState() => _EndingMedalNoticeState();
}

class _EndingMedalNoticeState extends State<EndingMedalNotice> {
  MedalClaimsController? _claims;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final claims = MedalClaimScope.maybeOf(context);
    if (_claims == claims) return;
    _claims = claims;
    if (claims != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) claims.refresh();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final claims = MedalClaimScope.maybeOf(context);
    if (claims == null) return const SizedBox.shrink();
    if (claims.error != null) {
      return TextButton.icon(
        onPressed: claims.loading ? null : () => claims.refresh(),
        icon: const Icon(Icons.refresh),
        label: const Text('Coba lagi pencapaian akun'),
      );
    }
    if (!claims.hasPending) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('ending-new-achievements'),
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: EmbunColors.gold.withValues(alpha: .4)),
        color: EmbunColors.gold.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: EmbunColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                '${claims.pending.length} pencapaian siap diklaim!\n'
                '${claims.pending.map((m) => m.name).join(' · ')}',
                style: const TextStyle(color: EmbunColors.gold),
              ),
            ),
          ),
          if (widget.onOpenProfile != null)
            TextButton(
              onPressed: widget.onOpenProfile,
              child: const Text('Buka profil'),
            ),
        ],
      ),
    );
  }
}
