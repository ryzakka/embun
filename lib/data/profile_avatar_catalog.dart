import 'package:flutter/services.dart';

/// Bundled avatars; all choices are available, with no unlock system.
const profileAvatars = <String, (String, String)>{
  'penjaga_hayu': ('01_penjaga_hayu.png', 'Penjaga Hayu'),
  'peramu_bunga': ('02_peramu_bunga.png', 'Peramu Bunga'),
  'petani_muda': ('03_petani_muda.png', 'Petani Muda'),
  'pengelana_rimba': ('04_pengelana_rimba.png', 'Pengelana Rimba'),
  'jurutulis_desa': ('05_jurutulis_desa.png', 'Jurutulis Desa'),
  'penenun_daun': ('06_penenun_daun.png', 'Penenun Daun'),
  'penjaga_sumur': ('07_penjaga_sumur.png', 'Penjaga Sumur'),
  'perawat_desa': ('08_perawat_desa.png', 'Perawat Desa'),
  'perajin_kayu': ('09_perajin_kayu.png', 'Perajin Kayu'),
  'tetua_bijak': ('10_tetua_bijak.png', 'Tetua Bijak'),
};

// Older saved icon preferences remain valid until the owner picks an image.
const legacyProfileAvatarIds = [
  'leaf',
  'sun',
  'moon',
  'water',
  'flower',
  'tree',
];
final profileAvatarIds = [...profileAvatars.keys, ...legacyProfileAvatarIds];

/// Resolve the installed format without changing saved avatar IDs. Prefer WebP
/// when both files exist. Each bundle's manifest and each lookup are cached.
final _avatarManifests = Expando<Future<AssetManifest>>();
final _avatarPaths = Expando<Map<String, Future<String?>>>();

Future<String?> profileAvatarAsset(AssetBundle bundle, String avatarId) {
  final avatar = profileAvatars[avatarId];
  if (avatar == null) return Future.value(null);
  final paths = _avatarPaths[bundle] ??= {};
  return paths.putIfAbsent(avatarId, () async {
    try {
      final manifest = await (_avatarManifests[bundle] ??=
          AssetManifest.loadFromAssetBundle(bundle));
      final files = manifest.listAssets().toSet();
      final stem = avatar.$1.replaceFirst(RegExp(r'\.(png|webp)$'), '');
      for (final extension in ['webp', 'png']) {
        final path = 'assets/avatars/$stem.$extension';
        if (files.contains(path)) return path;
      }
    } catch (_) {
      // Missing manifest/assets should keep a readable fallback avatar.
    }
    return null;
  });
}
