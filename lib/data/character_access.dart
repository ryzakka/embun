import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'character_catalog.dart';

/// Public metadata only. Selection is also enforced by the database trigger.
class CharacterAccess {
  CharacterAccess._();
  static final I = CharacterAccess._();
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;

  void start() {
    if (_subscription != null) return;
    _subscription = Supabase.instance.client
        .from('character_definitions')
        .stream(primaryKey: ['id'])
        .listen(
          CharacterCatalog.replaceStatus,
          onError: (Object error) {
            debugPrint('Status karakter: $error');
          },
        );
  }

  Future<void> refresh() async {
    try {
      final rows = await Supabase.instance.client
          .from('character_definitions')
          .select('id, enabled, listed')
          .timeout(const Duration(seconds: 3));
      CharacterCatalog.replaceStatus(rows);
    } catch (error) {
      // Keep the most recent known state; default Penggoda remains locked
      // even if the migration has not been installed or the device is offline.
      debugPrint('Pembaruan status karakter: $error');
    }
  }
}
