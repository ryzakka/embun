import 'package:supabase_flutter/supabase_flutter.dart';

/// Pesan galat yang enak dibaca, tanpa "PostgrestException(message: ...)".
String errMsg(Object e) {
  if (e is PostgrestException) return e.message;
  if (e is AuthException) return e.message;
  final type = e.runtimeType.toString();
  if (type.contains('SocketException') ||
      type.contains('ClientException') ||
      type.contains('TimeoutException') ||
      type.contains('HandshakeException')) {
    return 'Koneksi bermasalah. Periksa jaringanmu lalu coba lagi.';
  }
  final s = e.toString();
  return s.startsWith('Exception: ') ? s.substring(11) : s;
}