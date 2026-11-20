/// Durasi presentasi; diselaraskan dengan migrasi phase_flow_timing.sql.
/// Tenggat server tetap menentukan fase. Klien yang terlambat langsung
/// menampilkan ringkasan, tanpa menahan fase pemain lain.
abstract final class PhaseTiming {
  static const loadTimeout = Duration(seconds: 8);
  static const resultsReserve = Duration(seconds: 8);
  static const summaryReserve = Duration(seconds: 5);
  static const effectInterval = Duration(milliseconds: 2100);

  static Duration ceremony(int cards) => Duration(
        milliseconds: 2700 + cards * (cards <= 6 ? 2400 : 1800),
      );

  /// Sama dengan _games_effects_phase: meliputi pemuatan, adegan, hasil,
  /// transformasi Hayu, dan waktu membaca. Semua siap tetap bisa mempercepat.
  static Duration effectsBudget(int cards, int effects) => Duration(
        milliseconds: 15000 + cards * 2400 +
            (effects * 2100 + 8000 < 30000
                ? 30000 : effects * 2100 + 8000),
      );

  static bool canPlayCeremony(int cards, Duration? remaining) =>
      remaining == null || remaining >= ceremony(cards) + resultsReserve;
}
