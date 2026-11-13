import 'dart:math';
import 'package:flutter/services.dart';

// Kartu karakter protagonis dibagi dua folder menurut jenis kelamin. Nama
// berkas diawali `pria-` / `wanita-`, jadi id (stem) tetap unik lintas folder.
// [protagonisDir] adalah induknya: pakai HANYA untuk `startsWith` pada path.
const protagonisDir = 'assets/kartu/CharPro';
const protagonisPriaDir = 'assets/kartu/CharPro/CharPro-Pria';
const protagonisWanitaDir = 'assets/kartu/CharPro/CharPro-Wanita';
const antagonisDir = 'assets/kartu/CharAnta';
const pohonDir = 'assets/pohon';
const bentangDir = 'assets/bentang';
const kartuPerawatanDir = 'assets/kartu/itemPerawatan';
const kartuWargaDir = 'assets/kartu/ItemPro';
const kartuAntagDir = 'assets/kartu/ItemAnta';
const kartuMalamDir =
    'assets/kartu/ItemAntaNight'; // kartu serangan malam (ungu)
const kartuSiangDir = 'assets/kartu/ItemProDay'; // kartu siang warga (kuning)
const kartuRekayasaDir =
    'assets/kartu/ItemAntaRekayasa'; // Kartu Rekayasa + Poin DNA
const kartuRegenerasiDir =
    'assets/kartu/ItemProRegenerasi'; // Kartu Regenerasi + Poin Regenerasi
const punggungDir = 'assets/kartu/punggungkartu';
const logoDir = 'assets/logo';
const kemampuanDir = 'assets/kartu/CharSkill';
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
        final isImage =
            lower.endsWith('.png') ||
            lower.endsWith('.webp') ||
            lower.endsWith('.jpg') ||
            lower.endsWith('.jpeg');
        if (!path.startsWith('assets/') || !isImage) continue;
        final slash = path.lastIndexOf('/');
        final file = path.substring(slash + 1);
        final stem = file.substring(0, file.lastIndexOf('.'));
        final folder = byFolder.putIfAbsent(path.substring(0, slash), () => {});
        if (!folder.containsKey(stem) || lower.endsWith('.webp')) {
          folder[stem] = path;
        }
      }
    } catch (_) {}
    _instance = AssetCatalog._(byFolder);
  }

  String? file(String folder, String stem) => _byFolder[folder]?[stem];

  /// Berkas pertama (urut abjad) yang namanya diawali [prefix]. Dipakai bila
  /// nama lengkapnya tak pasti atau panjang.
  String? byPrefix(String folder, String prefix) {
    final m = _byFolder[folder];
    if (m == null) return null;
    final keys = m.keys.where((k) => k.startsWith(prefix)).toList()..sort();
    return keys.isEmpty ? null : m[keys.first];
  }

  List<String> stems(String folder) =>
      (_byFolder[folder]?.keys.toList() ?? <String>[])..sort();
}

/// Semua id karakter protagonis (pria + wanita), terurut.
List<String> protagonistStems() => [
  ...AssetCatalog.I.stems(protagonisPriaDir),
  ...AssetCatalog.I.stems(protagonisWanitaDir),
]..sort();

String? protagonistPath(String id) =>
    AssetCatalog.I.file(protagonisPriaDir, id) ??
    AssetCatalog.I.file(protagonisWanitaDir, id);

String randomProtagonist() {
  final s = protagonistStems();
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
    ? firstScenery(const ['lembah-hantumurka', 'desajembatan-keringgulita'])
    : AssetCatalog.I.file(bentangDir, 'lembah-hijau${_scale(leaves, 5.99)}');

String? sceneryPath(String stem) => AssetCatalog.I.file(bentangDir, stem);

/// Gambar bentang pertama yang ada dari daftar [stems]; null bila tak satu
/// pun ada. Dipakai agar aplikasi tidak rusak bila sebuah aset belum diunggah.
String? firstScenery(List<String> stems) {
  for (final s in stems) {
    final p = AssetCatalog.I.file(bentangDir, s);
    if (p != null) return p;
  }
  return null;
}

/// Perbesaran latar `bentang`. Bingkai emas ikut tertanam di gambarnya;
/// sedikit diperbesar (dari tengah) supaya bingkai itu keluar dari layar.
/// Ubah sesuai hasil uji. Gambar `pohon` tidak berbingkai: jangan diperbesar.
const kBentangZoom = 1.08;

/// Hari ke-[day] memilih satu dari [stems] secara bergilir (hanya yang ada).
String? _rotate(List<String> stems, int day) {
  final have = [
    for (final s in stems)
      if (_scenery(s) != null) _scenery(s)!,
  ];
  if (have.isEmpty) return null;
  return have[day.abs() % have.length];
}

/// Seperti [sceneryPath], tetapi nama berakhiran `*` dicocokkan sebagai awalan.
String? _scenery(String stem) => stem.endsWith('*')
    ? AssetCatalog.I.byPrefix(bentangDir, stem.substring(0, stem.length - 1))
    : AssetCatalog.I.file(bentangDir, stem);

/// Latar meja menurut fase, hari, dan kesehatan Hayu.
///
/// Hari biasa menurun bersama daun:
///   >= 20 daun : desa hijau yang bergilir tiap hari
///   12-19 daun : desa gersang
///   < 12 daun  : kembali ke [landscapePath] (lembah makin gelap, dan
///                `desajembatan-keringgulita` saat daun habis)
/// Fase lain (musyawarah, vote, persembahan) memakai adegannya sendiri selama
/// Hayu masih >= 12 daun.
String? phaseScenery(String phase, int day, int leaves) {
  final fallback = landscapePath(leaves);
  if (leaves < 12) return fallback;
  String? pick;
  switch (phase) {
    case 'day':
      pick = leaves >= 20
          ? _rotate(const [
              'pasar-sianghari',
              'balaidesa-luarsiang',
              'peternakan-sianghari',
              'sumur-sianghari',
              'menaralonceng-sianghari',
              'gerobakdankeranjang',
              'tepisungai-tanggaterjalsianghari',
              'balkon-siang',
            ], day)
          : _rotate(const [
              'ladang-gersang',
              'rumahdesa2-gersang',
              'rumahdesa-gersang',
            ], day);
    case 'research':
      pick = _rotate(const [
        'kedai-karturiset',
        'kuali-racikan',
        'perpustakaantua',
        'mejaku',
      ], day);
    case 'discussion':
      pick = _rotate([
        'balaidesa-dalamsiang',
        'sinarmataharikedalamrumah',
        'kamarkayudesa',
        'perpustakaantua',
        // Hayu mulai kering: sosok di atas rak perpustakaan ikut bergilir.
        if (leaves < 20) 'hantu-perempuanbertopengdiatasrak*',
      ], day);
    case 'voting':
      pick = firstScenery(const ['alunalun-tiangberpita']);
    case 'offering':
      pick = firstScenery(const [
        'pohon-toplesnyaladankunang',
        'pohon-keranjangbuah',
      ]);
  }
  return pick ?? fallback;
}

// ---- malam ----

/// Langit malam: tenang, atau langit serangan (sama untuk SEMUA pemain).
String? nightSkyPath({required bool attack}) => firstScenery(
  attack
      ? const ['langit-malammerahungugelap', 'langit-malamberawan']
      : const ['langit-malamberawan'],
);

/// Lembah malam tempat langit itu turun: tenang atau kering akibat serangan.
String? nightValleyPath({required bool attack}) => firstScenery(
  attack
      ? const ['lembah-malamkering', 'lembah-malamindah']
      : const ['lembah-malamindah'],
);

/// Latar pribadi korban: `sumur` (Racun Sumur) atau `rumah` (Maling Embun).
/// Null untuk selain itu; adegan ini tidak pernah dipakai untuk pemain lain.
String? nightVictimPath(String? scene) => switch (scene) {
  'sumur' => firstScenery(const ['sumur-gelapmalam']),
  'rumah' => firstScenery(const ['rumah-malamdepanpintu']),
  'pondok' => firstScenery(const ['tempatdalam-pondokperawatan','tempat-pondokperawatan']),
  _ => null,
};

// ---- hantu ----

/// Hantu yang muncul pada korban serangan malam (hanya di layar korban):
/// `sumur` (Racun Sumur) -> perempuan keluar dari sumur, `rumah` (Maling
/// Embun) -> sosok pria di dalam kamar.
String? nightGhostPath(String? scene) => switch (scene) {
  'sumur' => firstScenery(const ['hantu-perempuankeluarsumur']),
  'rumah' => firstScenery(const ['hantu-priapenggodadikamar']),
  _ => null,
};

/// Orang-orangan sawah yang merayap mendekat, urut dari jauh ke dekat
/// (dipakai adegan pemain diusir). Hanya yang berkasnya ada.
List<String> scarecrowFrames() => [
  for (final s in const [
    'hantu-jeramidiladang',
    'hantu-jeramigerakdiam',
    'hantujeramigerakmaju',
  ])
    if (sceneryPath(s) != null) sceneryPath(s)!,
];

/// Hantu murka yang menampakkan diri di atas lembah saat Hayu mati.
List<String> wrathGhostPaths() => [
  for (final s in const [
    'hantumurka-perempuanbungameraih',
    'hantumurka-topengpria',
    'hantumurka-wanitatopengjubah',
  ])
    if (sceneryPath(s) != null) sceneryPath(s)!,
];

/// Latar layar akhir saat Si Terbisik menang.
///   waktu habis : malam di desa, sosok setengah kuda di sisi gerobak
///   daun habis  : lembah hantu murka (lihat [landscapePath])
String? defeatScenery({required int leaves, String? endReason}) {
  if (endReason == 'waktu_habis' && leaves > 0) {
    return firstScenery(const [
      'hantu-manusiaberbadansetengahkuda01',
      'keterasingan',
    ]);
  }
  if (leaves <= 0 || endReason == 'daun_habis') {
    return firstScenery(const ['lembah-hantumurka', 'keterasingan']);
  }
  return firstScenery(const ['keterasingan']);
}

String? ikonPath(String name) => AssetCatalog.I.file(ikonDir, name);

String? logoPath(String stem) => AssetCatalog.I.file(logoDir, stem);

/// Punggung kartu KARAKTER (protagonis hijau, kartu gelap merah). Untuk kartu
/// yang terlihat pemain lain, jangan pakai dark: true, karena itu membocorkan
/// sisi pemilik kartu.
String? cardBackPath({bool dark = false}) => AssetCatalog.I.file(
  punggungDir,
  dark ? 'punggungantagonis' : 'punggungprotagonis',
);

/// Punggung kartu beli/item, terpisah dari punggung kartu karakter: item warga
/// hijau (peti), item antagonis merah (peti), serangan malam ungu (bulan),
/// kartu lanjutan Rekayasa merah (DNA) dan Regenerasi hijau (DNA).
/// Kartu yang terlihat pemain lain WAJIB memakai bentuk tanpa argumen
/// (punggung warga): merah/ungu membocorkan peran dan kartu samaran. Bila
/// berkasnya belum ada, jatuh ke punggung kartu karakter.
String? itemBackPath({
  bool dark = false,
  bool night = false,
  bool day = false,
  bool advanced = false, // kartu lanjutan / poin (Rekayasa atau Regenerasi)
}) =>
    AssetCatalog.I.file(
      punggungDir,
      night
          ? 'punggungitemmalam'
          : day
          ? 'punggungitemsiang'
          : advanced
          ? (dark ? 'punggungitemantarekayasa' : 'punggungitemproregenerasi')
          : dark
          ? 'punggungitemantagonis'
          : 'punggungitemprotagonis',
    ) ??
    cardBackPath(dark: dark || night);

/// Punggung item menurut definisinya (`side`, `kind`). Hanya untuk kartu milik
/// sendiri, mis. pasar pribadi: kartu `malam` (serangan malam) berpunggung
/// ungu, kartu lanjutan/poin antagonis (Rekayasa) merah-DNA, kartu
/// lanjutan/poin warga (Regenerasi) hijau-DNA, item antagonis merah, item
/// warga hijau.
String? itemBackFor(Map<String, dynamic>? def) => itemBackPath(
  dark: def?['side'] == 'antagonis',
  night: def?['kind'] == 'malam',
  day: def?['kind'] == 'siang',
  advanced: def?['kind'] == 'lanjutan' || def?['kind'] == 'poin',
);

/// Punggung kartu kemampuan warga.
String? abilityBackPath() =>
    AssetCatalog.I.file(punggungDir, 'punggungkemampuan') ?? cardBackPath();

/// Gambar kartu beli/item. Nama berkas = kolom `art` di card_definitions
/// (jatuh ke `id` bila kosong). Warga di powerpro, antagonis di poweranta,
/// kartu serangan malam (kind 'malam') di powernight.
String? cardArtPath(Map<String, dynamic>? def) {
  if (def == null) return null;
  final stem = (def['art'] as String?) ?? (def['id'] as String?);
  if (stem == null) return null;
  if (def['kind'] == 'perawatan') {
    return AssetCatalog.I.file(kartuPerawatanDir, stem);
  }
  if (def['kind'] == 'malam') {
    // Folder sendiri; bila belum ada di sana, jatuh ke folder antagonis.
    return AssetCatalog.I.file(kartuMalamDir, stem) ??
        AssetCatalog.I.file(kartuAntagDir, stem);
  }
  if (def['kind'] == 'lanjutan' || def['kind'] == 'poin') {
    // Kartu lanjutan + kartu poin: folder sendiri per sisi; bila belum ada,
    // jatuh ke folder item biasa.
    final bad = def['side'] == 'antagonis';
    return AssetCatalog.I.file(
          bad ? kartuRekayasaDir : kartuRegenerasiDir,
          stem,
        ) ??
        AssetCatalog.I.file(bad ? kartuAntagDir : kartuWargaDir, stem);
  }
  if (def['kind'] == 'siang') {
    // Kartu kuning: folder sendiri; bila belum ada, jatuh ke folder warga.
    return AssetCatalog.I.file(kartuSiangDir, stem) ??
        AssetCatalog.I.file(kartuWargaDir, stem);
  }
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

/// Rasio tinggi : lebar. SEMUA kartu (karakter, item warga/antagonis, malam,
/// siang, poin, lanjutan, kemampuan, dan punggungnya) berukuran 2:3.
const kTallAspect = 1.5; // 2:3
const kItemAspect = kTallAspect; // dulu 9/7; kini sama untuk semua kartu
const kProtagonistAspect = kTallAspect; // dipakai _FaceCrop dan layar lain
const kAntagonisAspect = kTallAspect;

/// Rasio satu-satunya untuk semua kartu. Parameter dipertahankan agar
/// pemanggil lama tidak perlu diubah.
double cardAspectFor(String? path) => kTallAspect;

/// Sama untuk semua jenis kartu (lihat [cardAspectFor]).
double cardAspectForDef(Map<String, dynamic>? def) => kTallAspect;

/// Nama karakter dari nama berkas. Nama berkas = `pekerjaan` + `jenis`, mis.
/// `nelayanikanwanita`, `bangsawan-pangeran`. Akhiran pria/wanita dan angka
/// dibuang; harus sama dengan fungsi SQL `_char_title`.
String characterTitle(String stem) {
  if (stem == 'default') return 'Belum memilih';
  final isFemale = stem.startsWith('wanita-');
  final base = stem
      .replaceAll(RegExp(r'^(pria|wanita)-'), '')
      .replaceAll(RegExp(r'\d+$'), '')
      .replaceAll(RegExp(r'(pria|wanita)$'), '');
  if (base == 'peraga') return isFemale ? 'Peragawati' : 'Peragawan';
  const names = {
    // kartu CharPro (pria/wanita)
    'ilmuwan': 'Ilmuwan Desa',
    'mastersauna': 'Master Sauna',
    'matamata': 'Mata-mata',
    'nelayanlautdalam': 'Nelayan Laut Dalam',
    'pandaibesi': 'Pandai Besi',
    'pemahatbatu': 'Pemahat Batu',
    'penambangemas': 'Penambang Emas',
    'penari': 'Penari',
    'pengukirkayu': 'Pengukir Kayu',
    'penjelajah': 'Penjelajah',
    'peracik': 'Peracik',
    'peselancar': 'Peselancar',
    'peternakkelinci': 'Peternak Kelinci',
    'tukangdaging': 'Tukang Daging',
    'pengajar': 'Pengajar',
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
    // kartu baru (gelombang 2)
    'petanirumputlaut': 'Petani Rumput Laut',
    'bangsawan-pangeranmelayu': 'Pangeran Melayu',
    'bangsawan-puterimelayu': 'Puteri Melayu',
    'bangsawan-pangeranjawa': 'Pangeran Jawa',
    'bangsawan-puterijawa': 'Puteri Jawa',
    'bangsawan-pangerantailan': 'Pangeran Tailan',
    'bangsawan-puteritailan': 'Puteri Tailan',
    'bangsawan-pangeranasiatenggara': 'Pangeran Asia Tenggara',
    'bangsawan-puteriasiatenggara': 'Puteri Asia Tenggara',
    'bangsawan-pangerantimurtengah': 'Pangeran Timur Tengah',
    'bangsawan-puteritimurtengah': 'Puteri Timur Tengah',
    'penggembala': 'Penggembala',
    'pelukis': 'Pelukis',
    'penatu': 'Penatu',
    'penjaga': 'Penjaga',
    'pemburu': 'Pemburu',
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
  // Tak dikenal: rapikan seadanya ("abc-def" -> "Abc Def"), maks 24 huruf
  // supaya nama (batas 26 karakter) masih muat dengan nomor.
  final words = base
      .split('-')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
  return words.length > 24 ? words.substring(0, 24) : words;
}
