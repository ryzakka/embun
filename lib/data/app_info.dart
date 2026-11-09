/// Satu-satunya tempat nomor versi aplikasi. Semua layar membacanya dari sini.
///
/// Ubah [version] di bawah, atau tanpa menyentuh kode saat build:
///   flutter build web --dart-define=APP_VERSION=2.7.0
/// Samakan dengan kolom `version` pada entri "pembaruan" di tabel
/// `announcements`, karena halaman Pengumuman membandingkan keduanya.
class AppInfo {
  AppInfo._();

  static const version =
  String.fromEnvironment('APP_VERSION', defaultValue: '3.0.2');

  /// Untuk ditampilkan: "V2.6.0".
  static const tag = 'V$version';

  /// Teks di layar judul.
  static const titleLine = 'BALAI PERTEMUAN DESA $tag';

  static List<int> _parts(String v) {
    final clean = v.trim().replaceFirst(RegExp(r'^[vV]'), '');
    return [for (final p in clean.split('.')) int.tryParse(p) ?? 0];
  }

  /// Negatif bila [a] < [b], 0 bila sama, positif bila [a] > [b].
  /// "2.10.0" dianggap lebih baru dari "2.9.0".
  static int compare(String a, String b) {
    final x = _parts(a), y = _parts(b);
    final n = x.length > y.length ? x.length : y.length;
    for (var i = 0; i < n; i++) {
      final p = i < x.length ? x[i] : 0;
      final q = i < y.length ? y[i] : 0;
      if (p != q) return p.compareTo(q);
    }
    return 0;
  }

  static bool isNewer(String v) => compare(v, version) > 0;
  static bool isCurrent(String v) => compare(v, version) == 0;
}