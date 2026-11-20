import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

import 'profile_avatar_catalog.dart';
export 'profile_avatar_catalog.dart' show profileAvatarIds;

/// Presentation preferences only. Never use user metadata for permissions.
@immutable
class PlayerProfile {
  const PlayerProfile({
    required this.userId,
    required this.googleAccount,
    required this.metadata,
    this.anonymous = false,
    this.email,
  });

  final String userId;
  final bool googleAccount;
  final bool anonymous;
  final Map<String, dynamic> metadata;
  final String? email;

  String get nickname => metadata['embun_nickname'] is String
      ? (metadata['embun_nickname'] as String).trim()
      : '';
  String get avatarId => profileAvatarIds.contains(metadata['embun_avatar'])
      ? metadata['embun_avatar'] as String
      : 'penjaga_hayu';
  bool get complete =>
      googleAccount &&
      metadata['embun_profile_version'] == 1 &&
      nicknameError(nickname) == null;

  String get initialNickname {
    if (nickname.isNotEmpty) return nickname;
    final name = metadata['full_name'] ?? metadata['name'] ?? '';
    if (name is! String) return '';
    final clean = name
        .replaceAll(
          RegExp(r'[\x00-\x1F\x7F\u200B-\u200F\u202A-\u202E\u2060-\u206F]'),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return clean.characters.take(20).toString();
  }
}

String normalizeNickname(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

String? nicknameError(String value) {
  if (value.trim().isEmpty) return 'Isi nama panggilanmu.';
  if (RegExp(
    r'[\x00-\x1F\x7F\u200B-\u200F\u202A-\u202E\u2060-\u206F]',
  ).hasMatch(value)) {
    return 'Nama mengandung karakter yang tidak dapat ditampilkan.';
  }
  if (value.trim().characters.length > 20) {
    return 'Nama paling panjang 20 karakter.';
  }
  return null;
}

/// Preserve the deployed app path, including a subdirectory; strip OAuth
/// parameters and fragments so tokens and old codes are never redirected.
Uri webAccountRedirect(Uri base) {
  if (!['http', 'https'].contains(base.scheme) || base.host.isEmpty) {
    throw ArgumentError('Alamat web aplikasi tidak valid.');
  }
  return Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: base.path.isEmpty ? '/' : base.path,
  );
}
