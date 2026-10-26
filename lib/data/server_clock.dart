/// Selisih jam perangkat dengan server, supaya hitung mundur tenggat fase
/// sama di semua perangkat walau jam perangkat meleset.
class ServerClock {
  static Duration offset = Duration.zero;
  static DateTime? _lastSync;

  static DateTime now() => DateTime.now().add(offset);

  /// Sinkron ulang paling sering tiap 5 menit.
  static bool get needsSync =>
      _lastSync == null ||
          DateTime.now().difference(_lastSync!) > const Duration(minutes: 5);

  static void markSyncing() => _lastSync = DateTime.now();
}