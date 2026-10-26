import 'dart:math';
import 'package:flutter/services.dart';

const protagonisDir = 'assets/kartu/protagonis';
const antagonisDir = 'assets/kartu/antagonis';
const pohonDir = 'assets/pohon';
const bentangDir = 'assets/bentang';

/// Membaca daftar gambar dari manifest aset, jadi nama file tidak perlu
/// ditulis satu per satu. .png dan .webp sama-sama didukung.
class AssetCatalog {
  AssetCatalog._(this._byFolder);
  final Map<String, Map<String, String>> _byFolder;

  static AssetCatalog? _instance;
  static AssetCatalog get I => _instance ?? AssetCatalog._({});

  static Future<void> load() async {
    final byFolder = <String, Map<String, String>>{};
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      for (final path in manifest.listAssets()) {
        final lower = path.toLowerCase();
        final isImage = lower.endsWith('.png') ||
            lower.endsWith('.webp') ||
            lower.endsWith('.jpg') ||
            lower.endsWith('.jpeg');
        if (!path.startsWith('assets/') || !isImage) continue;
        final slash = path.lastIndexOf('/');
        final file = path.substring(slash + 1);
        final stem = file.substring(0, file.lastIndexOf('.'));
        final folder =
        byFolder.putIfAbsent(path.substring(0, slash), () => {});
        if (!folder.containsKey(stem) || lower.endsWith('.webp')) {
          folder[stem] = path;
        }
      }
    } catch (_) {}
    _instance = AssetCatalog._(byFolder);
  }

  String? file(String folder, String stem) => _byFolder[folder]?[stem];

  List<String> stems(String folder) =>
      (_byFolder[folder]?.keys.toList() ?? <String>[])..sort();
}

String? protagonistPath(String id) => AssetCatalog.I.file(protagonisDir, id);

String randomProtagonist() {
  final s = AssetCatalog.I.stems(protagonisDir);
  return s.isEmpty ? 'default' : s[Random().nextInt(s.length)];
}

String? darkCardPath(int seed) {
  final s = AssetCatalog.I.stems(antagonisDir);
  if (s.isEmpty) return null;
  return AssetCatalog.I.file(antagonisDir, s[seed.abs() % s.length]);
}

int _scale(int leaves, double top) =>
    ((30 - leaves.clamp(0, 30).toInt()) * top / 30).floor();

/// 30 daun = pohon0 (rimbun) ... 0 daun = pohon9 (mati)
String? treePath(int leaves) =>
    AssetCatalog.I.file(pohonDir, 'pohon${_scale(leaves, 9.99)}');

/// 30 daun = lembah-hijau0 ... makin sedikit daun makin gelap
String? landscapePath(int leaves) => leaves <= 0
    ? AssetCatalog.I.file(bentangDir, 'desajembatan-keringgulita')
    : AssetCatalog.I.file(bentangDir, 'lembah-hijau${_scale(leaves, 5.99)}');

String? sceneryPath(String stem) => AssetCatalog.I.file(bentangDir, stem);

String characterTitle(String stem) {
  final base = stem.replaceAll(RegExp(r'\d+$'), '');
  const names = {
    'atlet': 'Atlet',
    'besi': 'Pandai Besi',
    'guru': 'Guru',
    'masak': 'Juru Masak',
    'montir': 'Montir',
    'nelayan': 'Nelayan',
    'pekebun': 'Pekebun',
    'pekerja': 'Pekerja',
    'pemadam': 'Pemadam',
    'perajut': 'Perajut',
    'peramu': 'Peramu',
    'perawat': 'Perawat',
    'petani': 'Petani',
    'petua': 'Petua',
    'pianis': 'Pianis',
    'polisi': 'Polisi',
    'pustakawan': 'Pustakawan',
    'warga': 'Warga Desa',
  };
  if (stem == 'default') return 'Belum memilih';
  return names[base] ??
      (base.isEmpty ? stem : base[0].toUpperCase() + base.substring(1));
}