// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
import '../lib/data/lobby_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  const room = '00000000-0000-0000-0000-000000000001';
  Future<void> session({required bool anonymous}) async {
    final user = User(
      id: anonymous ? 'guest' : 'google',
      isAnonymous: anonymous,
      aud: 'authenticated',
      createdAt: '2026-11-20T00:00:00Z',
      appMetadata: anonymous ? const {} : const {'provider': 'google'},
      userMetadata: anonymous
          ? const {}
          : const {
              'embun_nickname': 'Nama Tersimpan',
              'embun_avatar': 'penjaga_hayu',
              'embun_profile_version': 1,
            },
    );
    await Supabase.instance.client.auth.recoverSession(
      jsonEncode(
        Session(
          accessToken: 'test.token.value',
          refreshToken: 'local-only',
          tokenType: 'bearer',
          user: user,
        ).toJson(),
      ),
    );
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.test',
      publishableKey: 'test-key',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/character_definitions')) {
          return http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return http.Response(
          jsonEncode(room),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
  });
  tearDownAll(() async => Supabase.instance.dispose());
  setUp(() => requests.clear());
  test(
    'guest creates room using entered name, without Google requirement',
    () async {
      await session(anonymous: true);
      expect(
        await LobbyRepository().createGame('  Tamu Desa  ', 'default'),
        room,
      );
      final body = jsonDecode(requests.last.body) as Map;
      expect(body['p_name'], 'Tamu Desa');
      expect(requests.last.url.path, endsWith('/rpc/create_game'));
    },
  );
  test(
    'guest joins room with entered name and invalid empty name is rejected',
    () async {
      await session(anonymous: true);
      expect(
        await LobbyRepository().joinGame('ABC123', 'Nama Tamu', 'default'),
        room,
      );
      expect((jsonDecode(requests.last.body) as Map)['p_name'], 'Nama Tamu');
      await expectLater(
        LobbyRepository().joinGame('ABC123', '   ', 'default'),
        throwsArgumentError,
      );
    },
  );
  test('Google room name continues using saved account nickname', () async {
    await session(anonymous: false);
    await LobbyRepository().createGame('Other Room Name', 'default');
    expect((jsonDecode(requests.last.body) as Map)['p_name'], 'Nama Tersimpan');
  });
}
