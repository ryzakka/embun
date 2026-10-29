import 'dart:math';
import 'package:flutter/services.dart';

const protagonisDir = 'assets/kartu/protagonis';
const antagonisDir = 'assets/kartu/antagonis';
const pohonDir = 'assets/pohon';
const bentangDir = 'assets/bentang';
const kartuWargaDir = 'assets/kartu/powerpro';
const kartuAntagDir = 'assets/kartu/poweranta';
const punggungDir = 'assets/kartu/punggungkartu';
const logoDir = 'assets/logo';
const kemampuanDir = 'assets/kartu/kemampuan';
// Bila isi assets/ikon/sudah adalah versi transparan, ganti ke
// 'assets/ikon/sudah' (dan daftarkan foldernya di pubspec.yaml).
const ikonDir = 'assets/ikon';

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

String? ikonPath(String name) => AssetCatalog.I.file(ikonDir, name);

String? logoPath(String stem) => AssetCatalog.I.file(logoDir, stem);

/// Punggung kartu. Untuk kartu yang terlihat pemain lain, jangan pakai
/// dark: true, karena itu membocorkan sisi pemilik kartu.
String? cardBackPath({bool dark = false}) => AssetCatalog.I.file(
    punggungDir, dark ? 'punggungantagonis' : 'punggungprotagonis');

/// Gambar kartu beli/item. Nama berkas = kolom `art` di card_definitions
/// (jatuh ke `id` bila kosong). Warga di powerpro, antagonis di poweranta.
String? cardArtPath(Map<String, dynamic>? def) {
  if (def == null) return null;
  final stem = (def['art'] as String?) ?? (def['id'] as String?);
  if (stem == null) return null;
  final dir = def['side'] == 'antagonis' ? kartuAntagDir : kartuWargaDir;
  return AssetCatalog.I.file(dir, stem);
}

/// Gambar kartu kemampuan warga. Nama berkas = kolom `art` di
/// ability_definitions (jatuh ke `id`). Bila belum ada, kartu tampil berikon.
String? abilityArtPath(Map<String, dynamic>? def) {
  if (def == null) return null;
  final stem = (def['art'] as String?) ?? (def['id'] as String?);
  if (stem == null) return null;
  return AssetCatalog.I.file(kemampuanDir, stem);
}

/// Rasio tinggi : lebar kartu karakter. Kartu protagonis baru berukuran
/// 1024 x 1536 (2:3). Kartu gelap (antagonis) tetap 3:4; ubah
/// [kAntagonisAspect] ke 1.5 bila kartu gelap juga dibuat ulang 2:3.
const kProtagonistAspect = 1.5;
const kAntagonisAspect = 4 / 3;

double cardAspectFor(String? path) {
  if (path == null || path.startsWith(protagonisDir)) return kProtagonistAspect;
  if (path.startsWith(antagonisDir)) return kAntagonisAspect;
  return 4 / 3; // kartu lain (mis. pratinjau item) seperti semula
}

/// Nama karakter dari nama berkas. Nama berkas = <pekerjaan><jenis>, mis.
/// `nelayanikanwanita`, `bangsawan-pangeran`. Akhiran pria/wanita dan angka
/// dibuang; harus sama dengan fungsi SQL `_char_title`.
String characterTitle(String stem) {
  if (stem == 'default') return 'Belum memilih';
  final base = stem
      .replaceAll(RegExp(r'\d+$'), '')
      .replaceAll(RegExp(r'(pria|wanita)$'), '');
  const names = {
    // kartu baru
    'bangsawan-bangsawan': 'Bangsawan',
    'bangsawan-gouverneur': 'Gubernur',
    'bangsawan-pangeran': 'Pangeran',
    'bangsawan-puteri': 'Puteri',
    'buruhangkat': 'Buruh Angkat',
    'burungangkat': 'Buruh Angkat', // salah ketik pada nama berkas
    'kriyawan': 'Kriyawan',
    'nelayanikan': 'Nelayan',
    'pekebunteh': 'Pekebun Teh',
    'penenun': 'Penenun',
    'penjahit': 'Penjahit',
    'perajintembikar': 'Perajin Tembikar',
    'petanipadi': 'Petani Padi',
    'wargadesa': 'Warga Desa',
    // kartu lama (tetap dikenali bila masih ada)
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
  final known = names[base];
  if (known != null) return known;
  if (base.isEmpty) return stem;
  // Tak dikenal: rapikan seadanya ("abc-def" -> "Abc Def"), maks 16 huruf
  // supaya nama (batas 20 karakter) masih muat dengan nomor.
  final words = base
      .split('-')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
  return words.length > 16 ? words.substring(0, 16) : words;
}