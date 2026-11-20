import 'package:flutter/material.dart';
import '../../data/profile_avatar_catalog.dart';
import '../common/ornate.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.avatarId, this.radius = 28});
  final String avatarId;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final avatar = profileAvatars[avatarId];
    final fallback = Icon(
      switch (avatarId) {
        'sun' => Icons.wb_sunny_outlined,
        'moon' => Icons.nightlight_outlined,
        'water' => Icons.water_drop_outlined,
        'flower' => Icons.local_florist_outlined,
        'tree' => Icons.park_outlined,
        _ => Icons.eco_outlined,
      },
      color: EmbunColors.gold,
      size: radius,
    );
    return Semantics(
      label: avatar?.$2 ?? 'Avatar',
      image: true,
      child: SizedBox.square(
        dimension: radius * 2,
        child: avatar == null
            ? CircleAvatar(
                radius: radius,
                backgroundColor: const Color(0xFF234237),
                child: fallback,
              )
            : Image.asset(
                'assets/avatars/${avatar.$1}',
                fit: BoxFit.contain,
                cacheWidth: (radius * 6).round(),
                errorBuilder: (_, _, _) => CircleAvatar(
                  radius: radius,
                  backgroundColor: const Color(0xFF234237),
                  child: fallback,
                ),
              ),
      ),
    );
  }
}
