import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/app_info.dart';
import 'data/asset_catalog.dart';
import 'data/embun_data.dart';
import 'features/common/cloth_transition.dart';
import 'features/common/fx_shaders.dart';
import 'features/common/ornate.dart';
import 'features/common/scene_flow.dart';
import 'features/common/sfx.dart';
import 'features/lobby/lobby_page.dart';
import 'features/preview/preview_panel.dart';
import 'features/preview/preview_session.dart';

const _previewBuild = bool.fromEnvironment('EMBUN_UI_PREVIEW');

// Sementara ditanam langsung. Kunci "anon" memang publik; keamanan dijaga RLS.
// JANGAN pernah menaruh kunci "service_role" di sini.
const supabaseUrl = 'https://djwcmkngydczvcagmgji.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRqd2Nta25neWRjenZjYWdtZ2ppIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI5NTYwODAsImV4cCI6MjEwODUzMjA4MH0.-_pVJJVdrwgInDMxA3braNna0G2eVHtmkGXnw6--Mr8';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Sfx.I.init();
  if (!_previewBuild) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }
  await AssetCatalog.load();
  await ClothTransition.preload();
  await FxShaders.preload();
  runApp(
    const ProviderScope(child: _previewBuild ? _PreviewBuild() : EmbunApp()),
  );
}

class EmbunApp extends StatelessWidget {
  const EmbunApp({super.key, this.previewPanel});

  final WidgetBuilder? previewPanel;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Embun',
      debugShowCheckedModeBanner: false,
      theme: embunTheme(),
      home: _Launcher(previewPanel: previewPanel),
    );
  }
}

class _PreviewBuild extends StatefulWidget {
  const _PreviewBuild();

  @override
  State<_PreviewBuild> createState() => _PreviewBuildState();
}

class _PreviewBuildState extends State<_PreviewBuild> {
  final _session = PreviewSession();

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EmbunData(
    game: _session,
    lobby: _session,
    announcements: _session,
    child: EmbunApp(previewPanel: (_) => PreviewPanel(session: _session)),
  );
}

/// Layar awal kosong: begitu muncul, kain menyapu dan LobbyPage
/// menggantikannya. LobbyPage baru dibangun saat kain menutup penuh.
class _Launcher extends StatefulWidget {
  const _Launcher({this.previewPanel});

  final WidgetBuilder? previewPanel;

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
          LobbyPage(previewPanel: widget.previewPanel),
          style: ClothStyle.daunHayu,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => Material(
    color: kSceneInk,
    child: SizedBox.expand(
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              builder: (_, v, child) => Opacity(opacity: v, child: child),
              child: Text(
                AppInfo.tag,
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 4,
                  color: EmbunColors.gold.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}