import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/asset_catalog.dart';
import 'features/common/cloth_transition.dart';
import 'features/common/ornate.dart';
import 'features/common/scene_flow.dart';
import 'features/common/sfx.dart';
import 'features/lobby/lobby_page.dart';

// Sementara ditanam langsung. Kunci "anon" memang publik; keamanan dijaga RLS.
// JANGAN pernah menaruh kunci "service_role" di sini.
const supabaseUrl = 'https://djwcmkngydczvcagmgji.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRqd2Nta25neWRjenZjYWdtZ2ppIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI5NTYwODAsImV4cCI6MjEwODUzMjA4MH0.-_pVJJVdrwgInDMxA3braNna0G2eVHtmkGXnw6--Mr8';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Sfx.I.init();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  await AssetCatalog.load();
  await ClothTransition.preload();
  runApp(const ProviderScope(child: EmbunApp()));
}

class EmbunApp extends StatelessWidget {
  const EmbunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Embun',
      debugShowCheckedModeBanner: false,
      theme: embunTheme(),
      home: const _Launcher(),
    );
  }
}

/// Layar awal kosong: begitu muncul, kain menyapu dan LobbyPage
/// menggantikannya. LobbyPage baru dibangun saat kain menutup penuh.
class _Launcher extends StatefulWidget {
  const _Launcher();

  @override
  State<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<_Launcher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Jeda singkat agar frame pertama sempat tampil sebelum kain menyapu.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      Sfx.I.playAny(Snd.winds);
      Navigator.of(context).pushReplacement(
        ClothTransition.route(
          const LobbyPage(),
          style: ClothStyle.daunHayu,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: kSceneInk, child: SizedBox.expand());
}