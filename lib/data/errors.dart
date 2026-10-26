import 'package:supabase_flutter/supabase_flutter.dart';

/// Pesan galat yang enak dibaca, tanpa "PostgrestException(message: ...)".
String errMsg(Object e) {
  if (e is PostgrestException) return e.message;
  if (e is AuthException) return e.message;
  final s = e.toString();
  return s.startsWith('Exception: ') ? s.substring(11) : s;
}