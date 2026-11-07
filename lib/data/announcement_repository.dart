import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pengumuman & log pembaruan dari tabel `announcements` (baca saja), serta
/// penanda "sudah dibaca" yang disimpan di perangkat.
class AnnouncementRepository {
  static const _seenKey = 'ann_last_seen_id';
  final _db = Supabase.instance.client;

  /// Yang disematkan di atas, lalu yang terbaru.
  Future<List<Map<String, dynamic>>> fetch() async {
    final rows = await _db
        .from('announcements')
        .select('id, kind, title, body, version, pinned, published_at')
        .order('pinned', ascending: false)
        .order('published_at', ascending: false)
        .order('id', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Entri "pembaruan" terbaru yang punya nomor versi (untuk penanda versi
  /// baru di lobi). Dibandingkan dengan AppInfo.version oleh pemanggil.
  Future<List<Map<String, dynamic>>> updates() async {
    final rows = await _db
        .from('announcements')
        .select('id, title, body, version')
        .eq('kind', 'pembaruan')
        .order('id', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// id terbesar yang pernah dilihat; null bila perangkat ini belum pernah
  /// membukanya (pemasangan baru).
  Future<int?> lastSeen() async {
    try {
      return (await SharedPreferences.getInstance()).getInt(_seenKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> markSeen(int id) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (id > (p.getInt(_seenKey) ?? 0)) await p.setInt(_seenKey, id);
    } catch (_) {}
  }

  /// Jumlah entri yang belum dibaca (maks 99). Pada pemasangan baru, semua
  /// yang sudah ada dianggap terbaca supaya pemain baru tidak disambut
  /// penanda "99".
  Future<int> unreadCount() async {
    final seen = await lastSeen();
    if (seen == null) {
      final top = await _db
          .from('announcements')
          .select('id')
          .order('id', ascending: false)
          .limit(1);
      await markSeen(top.isEmpty ? 0 : (top.first['id'] as num).toInt());
      return 0;
    }
    final rows =
    await _db.from('announcements').select('id').gt('id', seen).limit(99);
    return rows.length;
  }
}