/// Aturan Stetoskop; server tetap memvalidasi biaya dan tingkat kartu.
abstract final class StethoscopeRules {
  static const chances = [30, 50, 70, 85, 100];
  static const costs = [3, 5, 7, 10];
  static const interferenceThreshold = 80;

  static int level(Map<String, dynamic> card) =>
      ((card['inspection_level'] as num?)?.toInt() ?? 0).clamp(0, 4);
  static int chance(Map<String, dynamic> card) => chances[level(card)];
  static int? nextCost(Map<String, dynamic> card) =>
      level(card) == 4 ? null : costs[level(card)];
  static bool protected(Map<String, dynamic> card) =>
      chance(card) >= interferenceThreshold;
  static String summary(Map<String, dynamic> card) {
    final percent = chance(card);
    return percent == 100
        ? '100% · Peran pasti terbaca. Kebal pengelabuan.'
        : '$percent% berhasil membaca peran. Gagal: belum dapat dipastikan. '
              '${protected(card) ? 'Kebal pengelabuan.' : 'Masih dapat dipengaruhi pengelabuan.'}';
  }
}

class InspectionReport {
  const InspectionReport({
    required this.id,
    required this.targetName,
    required this.kind,
    required this.outcome,
    required this.message,
    required this.day,
    this.chance,
    this.value,
    this.targetId,
    this.seen = false,
  });

  factory InspectionReport.fromRow(Map<String, dynamic> row) =>
      InspectionReport(
        id: '${row['id']}',
        targetId: row['target_id'] as String?,
        targetName: row['target_name'] as String? ?? 'Pemain',
        kind: row['kind'] as String? ?? 'heartbeat',
        outcome: row['outcome'] as String? ?? 'unknown',
        message: row['message'] as String? ?? '',
        day: (row['day'] as num?)?.toInt() ?? 0,
        chance: (row['chance'] as num?)?.toInt(),
        value: (row['value'] as num?)?.toInt(),
        seen: row['seen_at'] != null,
      );

  final String id, targetName, kind, outcome, message;
  final String? targetId;
  final int day;
  final int? chance, value;
  final bool seen;
  bool get isRole => kind == 'heartbeat';
  bool get isNumber => kind == 'hand' || kind == 'purchase';
  String get source => switch (kind) {
    'hand' => 'Kaca Pembesar',
    'purchase' => 'Lampu Senter',
    'offering' => 'Lentera Lawas',
    _ => 'Stetoskop',
  };
  String get headline => switch (outcome) {
    'warga' => 'Warga Desa',
    'antagonis' => 'Si Terbisik',
    'baik' => 'Tampak Baik',
    'buruk' => 'Tampak Buruk',
    'number' => '${value ?? 0}',
    _ => 'Belum Terbaca',
  };
  String get detail => switch (kind) {
    'hand' => 'kartu masih disimpan saat pemeriksaan',
    'purchase' => 'kartu dibeli di Pasar Pagi pada dua hari sebelumnya',
    'offering' => 'Penilaian persembahan; dapat dipengaruhi pengelabuan.',
    _ =>
      outcome == 'unknown'
          ? 'Peran belum dapat dipastikan. Tidak ada kesimpulan tentang sasaran.'
          : chance == 100
          ? 'Peran terbaca pasti. Pemeriksaan ini kebal pengelabuan.'
          : (chance ?? 30) >= StethoscopeRules.interferenceThreshold
          ? 'Pembacaan berhasil. Pemeriksaan ini kebal pengelabuan.'
          : 'Hasil pembacaan dapat dipengaruhi pengelabuan.',
  };
}
