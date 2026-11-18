import 'package:flutter/material.dart';

import 'data/asset_catalog.dart';
import 'features/common/sfx.dart';
import 'features/preview/preview_catalog.dart';
import 'features/preview/preview_session.dart';
import 'features/table/offering_ceremony.dart';

/// Isolated entry point: no Supabase.initialize, authentication, room or writes.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AssetCatalog.load();
  Sfx.I.init();
  runApp(const OfferingFlamePreviewApp());
}

class OfferingFlamePreviewApp extends StatelessWidget {
  const OfferingFlamePreviewApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Embun · Percobaan Flame',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFFBFD59B),
      scaffoldBackgroundColor: const Color(0xFF091710),
      useMaterial3: true,
    ),
    home: const _PreviewPage(),
  );
}

class _TwoCardPreview extends PreviewSession {
  @override
  Future<List<String>> revealedCards(String gameId, int day) async => [
    'air_suci',
    'racun_ember',
  ];

  @override
  Future<int?> leavesBefore(String gameId) async => 16;

  @override
  Future<List<PreviewRow>> effects(String gameId, int day) async => [
    {'seq': 1, 'kind': 'good', 'label': 'Air Suci · +1 daun', 'card_seq': 1},
    {'seq': 2, 'kind': 'bad', 'label': 'Ember Racun · -1 daun', 'card_seq': 2},
  ];
}

class _PreviewPage extends StatefulWidget {
  const _PreviewPage();
  @override
  State<_PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<_PreviewPage> {
  final _repo = _TwoCardPreview();
  bool _flame = true;
  bool _playing = false;
  bool _finished = false;
  bool _covered = false;
  int _run = 0;

  void _play() {
    Sfx.I.unlockAudio();
    setState(() {
      _run++;
      _playing = true;
      _finished = false;
      _covered = false;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'PERCOBAAN PERSEMBAHAN HAYU',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ChoiceChip(
                  label: const Text('Flame'),
                  selected: _flame,
                  onSelected: (_) => setState(() {
                    _flame = true;
                    _playing = false;
                    _finished = false;
                  }),
                ),
                ChoiceChip(
                  label: const Text('Flutter lama'),
                  selected: !_flame,
                  onSelected: (_) => setState(() {
                    _flame = false;
                    _playing = false;
                    _finished = false;
                  }),
                ),
                FilledButton(
                  onPressed: _play,
                  child: Text(
                    _playing || _finished ? 'Putar ulang' : 'Putar dua kartu',
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              'Pratinjau lokal · satu kartu baik dan satu kartu jahat · tanpa koneksi Supabase',
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: _playing
                ? OfferingCeremony(
                    key: ValueKey('$_run/$_flame'),
                    repo: _repo,
                    gameId: 'flame-offline-preview',
                    day: 1,
                    fallbackLeaves: 16,
                    winLeaves: 30,
                    defs: previewCards,
                    useFlame: _flame,
                    onDone: (covered) {
                      if (!mounted) return;
                      setState(() {
                        _playing = false;
                        _finished = true;
                        _covered = covered;
                      });
                    },
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _finished
                            ? 'Adegan selesai / dilewati.\n${_covered ? 'Hasil kedua kartu telah ditampilkan.' : 'Layar hasil permainan tetap perlu menampilkan hasil kartu.'}\n\nPilih renderer dan putar ulang untuk membandingkan.'
                            : 'Kartu baik menghasilkan kelopak emas.\nKartu jahat menghasilkan serpihan ungu.\n\nKetuk adegan saat berjalan untuk melewati.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 19, height: 1.6),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}
