import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../../data/lobby_repository.dart';
import '../common/art.dart';
import '../table/table_page.dart';
import '../../data/game_repository.dart';

class _Line {
  final String text;
  final String scene;
  const _Line(this.text, this.scene);
}

const _prologue = [
  _Line('Dahulu, di lembah yang dikelilingi kabut,\nberdiri sebuah pohon tua bernama Hayu.',
      'lembah-hijau0'),
  _Line('Selama Hayu berdaun,\nsungai mengalir, buah bergelantungan,\ndan desa tidak pernah gelap.',
      'rumahdesa-hijau'),
  _Line('Suatu musim, kabut turun terlalu lama.\nSatu per satu daun Hayu gugur tanpa angin.',
      'lembah-hijau3'),
  _Line('Orang-orang desa berbisik:\npohon itu tidak sedang sakit,\nia sedang dilupakan.',
      'rumahdesa-gersang'),
  _Line('Maka mereka datang,\nmembawa air, doa, dan pita harapan.',
      'pohon-zoom'),
  _Line('Tetapi kabut tidak pernah pergi sendirian.\nIa membisiki satu orang dari desa itu\ndan menitipkan sebutir benih hitam di dadanya.',
      'lembah-hijau5'),
];

class PrologueFlow extends StatefulWidget {
  final String gameId;
  final LobbyRepository repo;
  const PrologueFlow({super.key, required this.gameId, required this.repo});

  @override
  State<PrologueFlow> createState() => _PrologueFlowState();
}

enum _Step { story, shuffling, role }

class _PrologueFlowState extends State<PrologueFlow>
    with SingleTickerProviderStateMixin {
  _Step step = _Step.story;
  int line = 0;
  Timer? timer;
  String? role;
  int darkSeed = 0;
  String myCard = 'default';
  bool revealed = false;
  final _gr = GameRepository();
  Timer? _beat;

  // Controller untuk animasi putar/kocok kartu
  late final AnimationController _shuffleCtrl;
  List<String> randomStems = [];
  int shuffleIndex = 0;
  Timer? _shuffleTimer;

  @override
  void initState() {
    super.initState();
    randomStems = AssetCatalog.I.stems(protagonisDir);
    _shuffleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    widget.repo.mySecret(widget.gameId).then((s) {
      if (mounted && s != null) {
        setState(() {
          role = s['role'] as String?;
          darkSeed = (s['dark_seed'] as int?) ?? 0;
        });
      }
    });
    widget.repo.players(widget.gameId).first.then((rows) {
      final me = rows.where((p) => p['user_id'] == widget.repo.myId);
      if (mounted && me.isNotEmpty) {
        setState(() {
          myCard = me.first['character_card'] as String;
        });
      }
    });
    _startTimer();

    _gr.tick(widget.gameId).catchError((_) {});
    _beat = Timer.periodic(const Duration(seconds: 8), (_) {
      _gr.tick(widget.gameId).catchError((_) {});
    });
  }

  void _startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 5), (_) => _next());
  }

  void _next() {
    if (!mounted) return;
    if (line < _prologue.length - 1) {
      setState(() => line++);
    } else {
      _toShuffling();
    }
  }

  void _toShuffling() {
    if (step != _Step.story) return;
    timer?.cancel();
    if (!mounted) return;
    setState(() => step = _Step.shuffling);
    HapticFeedback.heavyImpact();

    // Efek kocok kartu berputar cepat selama 2 detik sebelum masuk ke kartu akhir
    _shuffleTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted && randomStems.isNotEmpty) {
        setState(() {
          shuffleIndex = Random().nextInt(randomStems.length);
        });
      }
    });

    _shuffleCtrl.forward().whenComplete(() {
      _shuffleTimer?.cancel();
      if (mounted) setState(() => step = _Step.role);
    });
  }

  void _openTable() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TablePage(gameId: widget.gameId, role: role!),
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    _beat?.cancel();
    _shuffleCtrl.dispose();
    _shuffleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scene = step == _Step.story
        ? _prologue[line].scene
        : 'desajembatan-keringgulita';
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Backdrop(path: sceneryPath(scene), dim: 0.5),
          SafeArea(
            child: step == _Step.story
                ? _story()
                : step == _Step.shuffling
                ? _shufflingStep()
                : _roleStep(),
          ),
        ],
      ),
    );
  }

  Widget _story() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _next();
        if (step == _Step.story) _startTimer();
      },
      child: Stack(
        children: [
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 900),
              child: Padding(
                key: ValueKey(line),
                padding: const EdgeInsets.all(28),
                child: Text(
                  _prologue[line].text,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    height: 1.5,
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 12),
                      Shadow(color: Colors.black, blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: TextButton(onPressed: _toShuffling, child: const Text('Lewati')),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text('Ketuk untuk lanjut',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shufflingStep() {
    final displayCard = randomStems.isNotEmpty
        ? protagonistPath(randomStems[shuffleIndex])
        : null;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Mengocok nasib dan peran di desa...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _shuffleCtrl,
            builder: (_, child) {
              return Transform.rotate(
                angle: _shuffleCtrl.value * 20 * pi,
                child: Transform.scale(
                  scale: 1.0 + 0.3 * sin(_shuffleCtrl.value * pi),
                  child: CardArt(path: displayCard, width: 140),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _cardBack(double w, double h) => Container(
    key: const ValueKey('back'),
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: const Color(0xFF2A3A38),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white24, width: 2),
    ),
    child: const Center(
      child: Icon(Icons.help_outline, size: 64, color: Colors.white54),
    ),
  );

  Widget _roleStep() {
    final isAntag = role == 'antagonis';
    final String? cardPath = role == null
        ? null
        : isAntag
        ? darkCardPath(darkSeed)
        : protagonistPath(myCard);
    final glow = isAntag ? const Color(0xFFB07CE8) : const Color(0xFF7FE0A0);

    return LayoutBuilder(builder: (context, c) {
      final cardH = (c.maxHeight - 190).clamp(150.0, 340.0).toDouble();
      final cardW = cardH * 3 / 4;
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTapDown: (_) => setState(() => revealed = true),
                onTapUp: (_) => setState(() => revealed = false),
                onTapCancel: () => setState(() => revealed = false),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: revealed
                      ? CardArt(
                    key: const ValueKey('front'),
                    path: cardPath,
                    width: cardW,
                    glow: glow,
                  )
                      : _cardBack(cardW, cardH),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 76,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: revealed
                      ? Padding(
                    key: const ValueKey('txt'),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Text(isAntag ? 'Si Terbisik' : 'Warga Desa',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: glow)),
                        const SizedBox(height: 4),
                        Text(
                          isAntag
                              ? 'Kabut menitipkan bulir hitam padamu. Hancurkan Hayu tanpa ketahuan.'
                              : 'Selamatkan Hayu. Waspadai satu pengkhianat di antara kalian.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                      : const Text('Tahan kartu untuk melihat perananmu',
                      key: ValueKey('hint')),
                ),
              ),
              FilledButton(
                onPressed: role == null ? null : _openTable,
                child: const Text('Aku sudah ingat'),
              ),
            ],
          ),
        ),
      );
    });
  }
}