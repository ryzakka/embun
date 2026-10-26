import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../../data/game_repository.dart';
import '../common/art.dart';
import '../../data/errors.dart';

class VotingView extends StatefulWidget {
  final GameRepository repo;
  final String gameId;
  final List<Map<String, dynamic>> players;

  const VotingView({
    super.key,
    required this.repo,
    required this.gameId,
    required this.players,
  });

  @override
  State<VotingView> createState() => _VotingViewState();
}

class _VotingViewState extends State<VotingView> {
  String? target;
  bool busy = false;

  // Segel suara: tampil sebentar sebelum suara benar-benar dikirim.
  bool stamping = false;
  String? stampId; // null = tidak memilih

  Map<String, dynamic>? _player(String? id) {
    if (id == null) return null;
    for (final p in widget.players) {
      if (p['user_id'] == id) return p;
    }
    return null;
  }

  Future<void> _submit(String? t) async {
    setState(() {
      busy = true;
      stamping = true;
      stampId = t;
    });
    HapticFeedback.heavyImpact();
    Future.delayed(
        const Duration(milliseconds: 380), HapticFeedback.heavyImpact);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    try {
      await widget.repo.submitVote(widget.gameId, t);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errMsg(e))));
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          stamping = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final others =
    widget.players.where((p) => p['user_id'] != widget.repo.myId).toList();
    final need = widget.players.length ~/ 2 + 1;
    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Siapa Si Terbisik?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              'Butuh $need suara. Menuduh warga yang salah akan mengurungnya '
                  'sehari dan Hayu kehilangan 1 daun.',
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final p in others)
                    Builder(builder: (_) {
                      final card = p['character_card'] as String;
                      final id = p['user_id'] as String;
                      final sel = target == id;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutBack,
                        margin: EdgeInsets.symmetric(
                            vertical: 3, horizontal: sel ? 0 : 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: sel ? Colors.redAccent : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: [
                            if (sel)
                              BoxShadow(
                                color: Colors.redAccent.withValues(alpha: 0.45),
                                blurRadius: 16,
                              ),
                          ],
                        ),
                        child: ListTile(
                          selected: sel,
                          selectedTileColor:
                          Colors.redAccent.withValues(alpha: 0.12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          leading: PlayerAvatar(
                            path: protagonistPath(card),
                            size: 46,
                            ring: sel ? Colors.redAccent : Colors.white38,
                          ),
                          title: Text(p['name'] as String),
                          trailing: AnimatedScale(
                            scale: sel ? 1 : 0,
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.elasticOut,
                            child: const Text('👀',
                                style: TextStyle(fontSize: 24)),
                          ),
                          onTap: busy
                              ? null
                              : () {
                            HapticFeedback.selectionClick();
                            setState(() => target = id);
                          },
                        ),
                      );
                    }),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed:
                  busy || target == null ? null : () => _submit(target),
                  child: const Text('Kunci suara'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => _submit(null),
                  child: const Text('Tidak memilih'),
                ),
              ],
            ),
          ],
        ),
        if (stamping) Positioned.fill(child: _VoteStamp(player: _player(stampId))),
      ],
    );
  }
}

/// Segel suara: yang dituduh menghantam ke tengah layar, lalu cap
/// "DITUDUH" menimpa. Tidak memilih mendapat cap abu-abu yang tenang.
/// Hanya tampil di layar pemilih sendiri.
class _VoteStamp extends StatelessWidget {
  final Map<String, dynamic>? player; // null = tidak memilih
  const _VoteStamp({required this.player});

  @override
  Widget build(BuildContext context) {
    final abstain = player == null;
    final color = abstain ? Colors.white60 : Colors.redAccent;
    return AbsorbPointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        builder: (context, t, _) {
          final dimT = Curves.easeOut
              .transform((t / 0.3).clamp(0.0, 1.0).toDouble());
          final land = Curves.easeOutBack
              .transform((t / 0.5).clamp(0.0, 1.0).toDouble());
          final st = Curves.easeOutBack
              .transform(((t - 0.4) / 0.4).clamp(0.0, 1.0).toDouble());
          final flash =
          (1 - (t - 0.45).abs() / 0.08).clamp(0.0, 1.0).toDouble();
          return Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: Colors.black.withValues(alpha: 0.78 * dimT)),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (abstain)
                      Opacity(
                        opacity: (t / 0.3).clamp(0.0, 1.0).toDouble(),
                        child: Icon(Icons.do_not_disturb_alt,
                            size: 80, color: color),
                      )
                    else
                      Opacity(
                        opacity: (t / 0.2).clamp(0.0, 1.0).toDouble(),
                        child: Transform.scale(
                          scale: 2.2 - 1.2 * land,
                          child: PlayerAvatar(
                            path: protagonistPath(
                                player!['character_card'] as String),
                            size: 110,
                            ring: Colors.redAccent,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (!abstain)
                      Text(player!['name'] as String,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 14),
                    Opacity(
                      opacity: st.clamp(0.0, 1.0).toDouble(),
                      child: Transform.rotate(
                        angle: -0.2,
                        child: Transform.scale(
                          scale: 2.6 - 1.6 * st,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: color, width: 4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              abstain ? 'TIDAK MEMILIH' : 'DITUDUH',
                              style: TextStyle(
                                color: color,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (flash > 0.01)
                ColoredBox(color: Colors.white.withValues(alpha: 0.35 * flash)),
            ],
          );
        },
      ),
    );
  }
}