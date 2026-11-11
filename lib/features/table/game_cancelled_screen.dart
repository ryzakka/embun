import 'package:flutter/material.dart';

import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'endgame_aura.dart';

class GameCancelledScreen extends StatefulWidget {
  const GameCancelledScreen({
    super.key,
    required this.leaves,
    required this.day,
    required this.players,
    required this.secrets,
    required this.onExit,
    this.reason,
  });

  final int leaves;
  final int day;
  final List<Map<String, dynamic>> players;
  final Future<Map<String, Map<String, dynamic>>> secrets;
  final VoidCallback onExit;
  final String? reason;

  @override
  State<GameCancelledScreen> createState() => _GameCancelledScreenState();
}

class _GameCancelledScreenState extends State<GameCancelledScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
    } else {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    color: EmbunColors.bg,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Backdrop(path: landscapePath(widget.leaves), dim: 0.78),
        AnimatedBuilder(
          animation: _motion,
          builder: (context, _) => EndgameAura(
            color: EmbunColors.gold,
            time: _motion.value * 24,
            intensity: 0.5,
          ),
        ),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'KISAH TERHENTI',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: EmbunColors.gold,
                              letterSpacing: 2.4,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height < 500
                                ? 100
                                : 180,
                            child: TreePortrait(leaves: widget.leaves),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Permainan\ndibubarkan',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 32,
                              height: 1.08,
                              fontWeight: FontWeight.w800,
                              color: EmbunColors.cream,
                            ),
                          ),
                          if (widget.reason case final reason?
                              when reason.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              reason,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                height: 1.4,
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 24,
                            runSpacing: 10,
                            children: [
                              _metric('timer', 'Hari ${widget.day}'),
                              _metric('helaidaun', '${widget.leaves} daun'),
                              _metric(
                                'persona',
                                '${widget.players.length} pemain',
                              ),
                            ],
                          ),
                          FutureBuilder<Map<String, Map<String, dynamic>>>(
                            future: widget.secrets,
                            builder: (context, snapshot) {
                              final antagonists =
                                  snapshot.data?.entries
                                      .where(
                                        (entry) =>
                                            entry.value['role'] == 'antagonis',
                                      )
                                      .toList() ??
                                  [];
                              if (antagonists.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Divider(height: 36),
                                  const Text(
                                    'Identitas Terbisik',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  for (final entry in antagonists)
                                    _identity(entry.key, entry.value),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                    child: EmbunButton(
                      label: 'Kembali ke balai',
                      icon: 'home',
                      expand: true,
                      onPressed: widget.onExit,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _metric(String icon, String value) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      GameIcon(icon, size: 20),
      const SizedBox(width: 6),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    ],
  );

  Widget _identity(String id, Map<String, dynamic> secret) {
    final player = widget.players.where((p) => p['user_id'] == id).firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          PlayerAvatar(
            path: darkCardPath((secret['dark_seed'] as int?) ?? 0),
            size: 44,
            ring: EmbunColors.mist,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${player?['name'] ?? 'Pemain'}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  characterTitle(
                    player?['character_card'] as String? ?? 'default',
                  ),
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          const Text(
            'Si Terbisik',
            style: TextStyle(color: EmbunColors.mist, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
