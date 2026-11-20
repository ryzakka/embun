import 'package:flutter/material.dart';
import 'account_status_badge.dart';
import 'profile_avatar.dart';

String accountInitials(String name) {
  final clean = name
      .replaceAll(
        RegExp(r'[\x00-\x1F\x7F\u200B-\u200F\u202A-\u202E\u2060-\u206F]'),
        '',
      )
      .trim();
  final words = clean.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  final first = words.first.characters.first;
  final last = words.length > 1 ? words.last.characters.first : '';
  return '$first$last'.toUpperCase();
}

/// Account identity before/after a match. Never use this in active gameplay.
class PlayerAccountAvatar extends StatelessWidget {
  const PlayerAccountAvatar({
    super.key,
    required this.name,
    this.avatarId,
    this.googleLinked,
    this.radius = 24,
    this.onTap,
  });
  final String name;
  final String? avatarId;
  final bool? googleLinked;
  final double radius;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final image = googleLinked == true && avatarId != null
        ? ProfileAvatar(avatarId: avatarId!, radius: radius)
        : CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFF234237),
            child: Text(
              accountInitials(name),
              maxLines: 1,
              style: TextStyle(
                fontSize: radius * .72,
                color: const Color(0xFFE8CD87),
                fontWeight: FontWeight.w800,
              ),
            ),
          );
    final status = googleLinked;
    final avatar = status == true
        ? AccountAvatarBadge(
            linked: true,
            size: (radius * .7).clamp(12.0, 20.0),
            child: image,
          )
        : status == false
        ? Tooltip(message: 'Belum menautkan akun Google', child: image)
        : image;
    return Semantics(
      label: 'Avatar $name',
      image: true,
      child: onTap == null
          ? avatar
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(radius),
              child: avatar,
            ),
    );
  }
}
