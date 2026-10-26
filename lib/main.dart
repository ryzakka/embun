import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/lobby/lobby_page.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  assert(
  supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty,
  'Jalankan dengan --dart-define=SUPABASE_URL=... dan --dart-define=SUPABASE_ANON_KEY=...',
  );

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  runApp(const ProviderScope(child: EmbunApp()));
}

class EmbunApp extends StatelessWidget {
  const EmbunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Embun',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3E8E7E),
        brightness: Brightness.dark,
      ),
      home: const LobbyPage(),
    );
  }
}