import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/lobby_repository.dart';

const _prologue = [
  'Dahulu, di lembah yang dikelilingi kabut,\nberdiri sebuah pohon tua bernama Hayu.',
  'Selama Hayu berdaun,\nsungai mengalir, buah bergelantungan,\ndan desa tidak pernah gelap.',
  'Suatu musim, kabut turun terlalu lama.\nSatu per satu daun Hayu gugur tanpa angin.',
  'Orang-orang desa berbisik:\npohon itu tidak sedang sakit,\nia sedang dilupakan.',
  'Maka mereka datang,\nmembawa air, doa, dan pita harapan.',
  'Tetapi kabut tidak pernah pergi sendirian.\nIa membisiki satu orang dari desa itu\ndan menitipkan sebutir benih hitam di dadanya.',
];

class PrologueFlow extends StatefulWidget {
  final String gameId;
  final LobbyRepository repo;
  const PrologueFlow({super.key, required this.gameId, required this.repo});
  @override
  State<PrologueFlow> createState() => _PrologueFlowState();
}

enum _Step { story, role, table }

class _PrologueFlowState extends State<PrologueFlow> {
  _Step step = _Step.story;
  int line = 0;
  Timer? timer;
  String? role;
  bool revealed = false;

  @override
  void initState() {
    super.initState();
    widget.repo.myRole(widget.gameId).then((r) {
      if (mounted) setState(() => role = r);
    });
    timer = Timer.periodic(const Duration(seconds: 5), (_) => _next());
  }

  void _next() {
    if (!mounted) return;
    if (line < _prologue.length - 1) {
      setState(() => line++);
    } else {
      timer?.cancel();
      setState(() => step = _Step.role);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (step) {
      case _Step.story:
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            timer?.cancel();
            _next();
            if (step == _Step.story) {
              timer = Timer.periodic(const Duration(seconds: 5), (_) => _next());
            }
          },
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 900),
              child: Padding(
                key: ValueKey(line),
                padding: const EdgeInsets.all(24),
                child: Text(
                  _prologue[line],
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(height: 1.5),
                ),
              ),
            ),
          ),
        );

      case _Step.role:
        final isAntag = role == 'antagonis';
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Tahan untuk melihat perananmu',
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              GestureDetector(
                onTapDown: (_) => setState(() => revealed = true),
                onTapUp: (_) => setState(() => revealed = false),
                onTapCancel: () => setState(() => revealed = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 220,
                  height: 300,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: !revealed
                        ? const Color(0xFF2A3A38)
                        : isAntag
                        ? const Color(0xFF1A1A1F)
                        : const Color(0xFF244A3A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    !revealed
                        ? '?'
                        : isAntag
                        ? 'Si Terbisik\n\nKabut menitipkan bulir hitam padamu.\nHancurkan Hayu tanpa ketahuan.'
                        : 'Warga Desa\n\nSelamatkan Hayu.\nWaspadai satu pengkhianat di antara kalian.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, height: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: role == null
                    ? null
                    : () => setState(() => step = _Step.table),
                child: const Text('Aku sudah ingat'),
              ),
            ],
          ),
        );

      case _Step.table:
        return const Center(
          child: Text('Hari 1: Meja kartu di sini (belum dibuat)'),
        );
    }
  }
}