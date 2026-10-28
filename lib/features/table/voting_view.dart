import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../../data/game_repository.dart';
import '../common/art.dart';
import '../../data/errors.dart';
import '../common/ornate.dart';
import 'player_status.dart';

class VotingView extends StatefulWidget {
  final GameRepository repo;
  final String gameId;
  /// Hanya pemain yang masih di desa.
  final List<Map<String, dynamic>> players;
  final int day;

  const VotingView({
    super.key,
    required this.repo,
    required this.gameId,
    required this.players,
    required this.day,
  });

  @override
  State<VotingView> createState() => _VotingViewState();
}

class _VotingViewState extends State<VotingView>
    with SingleTickerProviderStateMixin {
  String? target;
  bool busy = false;

  // Segel suara: tampil sebentar sebelum suara benar-benar dikirim.
  bool stamping = false;
  String? stampId; // null = tidak memilih

  // Denyut cahaya merah pada kartu yang dipilih. Hanya berjalan saat ada
  // pilihan supaya tidak memboroskan frame.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _player(String? id) {
    if (id == null) return null;
    for (final p in widget.players) {
      if (p['user_id'] == id) return p;
    }
    return null;
  }

  /// Ketuk kartu: memilih, atau ketuk lagi untuk membatalkan.
  void _select(String id) {
    HapticFeedback.selectionClick();
    setState(() => target = target == id ? null : id);
    if (target == null) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  Future<void> _submit(String? t) async {
    _pulse.stop();
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
    var ok = false;
    try {
      await widget.repo.submitVote(widget.gameId, t);
      ok = true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errMsg(e))));
      }
    } finally {
      if (mounted) {
        // Setelah sukses, tombol tetap terkunci sampai stream menandai
        // pemain siap; hanya galat yang membukanya lagi.
        setState(() {
          if (!ok) busy = false;
          stamping = false;
        });
        if (!ok && target != null && !_pulse.isAnimating) {
          _pulse.repeat(reverse: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final others =
    widget.players.where((p) => p['user_id'] != widget.repo.myId).toList();
    final need = widget.players.length ~/ 2 + 1;
    final size = MediaQuery.sizeOf(context);
    final short = size.height < 480; // ponsel miring

    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(icon: 'vote', title: 'Siapa Si Terbisik?'),
            SizedBox(height: short ? 4 : 8),
            _RulesPanel(need: need, compact: short),
            SizedBox(height: short ? 6 : 10),
            Expanded(child: _suspects(others, short)),
            SizedBox(height: short ? 6 : 10),
            _actionBar(short),
          ],
        ),
        if (stamping)
          Positioned.fill(child: _VoteStamp(player: _player(stampId))),
      ],
    );
  }

  Widget _suspects(List<Map<String, dynamic>> others, bool short) {
    if (others.isEmpty) {
      return const Center(
        child: Text('Belum ada pemain lain di desa.',
            style: TextStyle(color: Colors.white60)),
      );
    }
    return LayoutBuilder(builder: (context, c) {
      // Ponsel: 2-3 kolom. Desktop: kartu tidak melebar, kolom bertambah.
      final maxExtent = c.maxWidth < 420 ? 190.0 : 210.0;
      return GridView.builder(
        // Ruang untuk cahaya kartu yang tidak terpotong tepi daftar.
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxExtent,
          mainAxisSpacing: short ? 8 : 12,
          crossAxisSpacing: short ? 8 : 12,
          childAspectRatio: short ? 1.35 : 0.95,
        ),
        itemCount: others.length,
        itemBuilder: (_, i) {
          final p = others[i];
          final id = p['user_id'] as String;
          final sel = target == id;
          return _SuspectCard(
            player: p,
            selected: sel,
            dimmed: busy && !sel,
            enabled: !busy,
            jailed: isJailed(p, widget.day),
            pulse: _pulse,
            onTap: () => _select(id),
          );
        },
      );
    });
  }

  Widget _actionBar(bool short) {
    final chosen = _player(target);
    final canLock = !busy && target != null;

    final status = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: chosen == null
          ? Text(
        'Pilih satu pemain untuk dituduh.',
        key: const ValueKey('none'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: Colors.white60),
      )
          : Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 14, color: Colors.white70),
          children: [
            const TextSpan(text: 'Kamu menuduh  '),
            TextSpan(
              text: chosen['name'] as String,
              style: const TextStyle(
                color: EmbunColors.blood,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (strikesOf(chosen) >= 1)
              const TextSpan(
                text: '\nSudah dituduh sekali. Bila mayoritas sepakat, '
                    'ia KELUAR dari desa (atau tertangkap, jika Si Terbisik).',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: EmbunColors.gold,
                ),
              ),
          ],
        ),
        key: ValueKey('sel${chosen['user_id']}'),
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );

    final lock = EmbunButton(
      label: 'Kunci suara',
      icon: 'lock',
      expand: true,
      onPressed: canLock ? () => _submit(target) : null,
    );
    final skip = EmbunButton(
      label: 'Tidak memilih',
      icon: 'skip',
      kind: EmbunButtonKind.secondary,
      expand: true,
      onPressed: busy ? null : () => _submit(null),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          padding: EdgeInsets.fromLTRB(10, short ? 6 : 10, 10, short ? 6 : 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: (target != null ? EmbunColors.blood : EmbunColors.goldDim)
                  .withValues(alpha: 0.5),
            ),
          ),
          child: LayoutBuilder(builder: (context, c) {
            final stacked = c.maxWidth < 340;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                status,
                SizedBox(height: short ? 6 : 10),
                if (stacked) ...[
                  lock,
                  const SizedBox(height: 8),
                  skip,
                ] else
                  Row(
                    children: [
                      Expanded(flex: 3, child: lock),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: skip),
                    ],
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// Aturan singkat dalam satu panel. Jumlah suara dibuat menonjol.
class _RulesPanel extends StatelessWidget {
  final int need;
  final bool compact;
  const _RulesPanel({required this.need, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 6 : 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EmbunColors.goldDim.withValues(alpha: 0.3)),
      ),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(
              fontSize: 12, height: 1.35, color: Colors.white60),
          children: [
            TextSpan(
              text: 'Butuh $need suara. ',
              style: const TextStyle(
                color: EmbunColors.gold,
                fontWeight: FontWeight.w800,
              ),
            ),
            const TextSpan(
              text: 'Tuduhan pertama: dikurung sampai musyawarah berikutnya '
                  'dan Hayu kehilangan 1 daun. Tuduhan kedua: Si Terbisik '
                  'tertangkap, tapi warga yang salah tuduh keluar dari desa. '
                  'Tiap pemain punya 2 nyawa.',
            ),
          ],
        ),
        maxLines: compact ? 2 : null,
        overflow: compact ? TextOverflow.ellipsis : TextOverflow.clip,
      ),
    );
  }
}

/// Kartu tersangka: potret besar di tengah, cincin dan cahaya merah
/// berdenyut saat dipilih, pemain lain meredup saat suara dikunci.
class _SuspectCard extends StatelessWidget {
  final Map<String, dynamic> player;
  final bool selected;
  final bool dimmed;
  final bool enabled;
  final bool jailed;
  final Animation<double> pulse;
  final VoidCallback onTap;

  const _SuspectCard({
    required this.player,
    required this.selected,
    required this.dimmed,
    required this.enabled,
    required this.jailed,
    required this.pulse,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = player['name'] as String;
    final card = player['character_card'] as String;
    const radius = 18.0;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: 'Tuduh $name',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: dimmed ? 0.45 : 1,
        child: AnimatedScale(
          scale: selected ? 1.04 : 1,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          child: AnimatedBuilder(
            animation: pulse,
            builder: (context, child) {
              final glow = selected ? 0.30 + 0.30 * pulse.value : 0.0;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      (selected ? EmbunColors.blood : Colors.white)
                          .withValues(alpha: selected ? 0.22 : 0.06),
                      Colors.black.withValues(alpha: 0.45),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: selected
                        ? EmbunColors.blood
                        : EmbunColors.goldDim.withValues(alpha: 0.4),
                    width: selected ? 2.5 : 1.5,
                  ),
                  boxShadow: [
                    if (selected)
                      BoxShadow(
                        color: EmbunColors.blood.withValues(alpha: glow),
                        blurRadius: 14 + 12 * pulse.value,
                        spreadRadius: 1,
                      ),
                  ],
                ),
                child: child,
              );
            },
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(radius),
                onTap: enabled ? onTap : null,
                child: LayoutBuilder(builder: (context, c) {
                  // Nyawa (dan label Dikurung) ikut memakan tinggi, jadi potret mengecil.
                  final avatar =
                  (c.maxHeight * (jailed ? 0.40 : 0.48)).clamp(36.0, 96.0);
                  return Stack(
                    children: [
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PlayerAvatar(
                                path: protagonistPath(card),
                                size: avatar.toDouble(),
                                ring: selected
                                    ? EmbunColors.blood
                                    : EmbunColors.goldDim,
                              ),
                              SizedBox(height: c.maxHeight < 110 ? 4 : 10),
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color:
                                  selected ? Colors.white : Colors.white70,
                                ),
                              ),
                              SizedBox(height: c.maxHeight < 110 ? 2 : 5),
                              LivesRow(lives: livesLeft(player), size: 15),
                              if (jailed) ...[
                                const SizedBox(height: 4),
                                const StatusTag(
                                    text: 'Dikurung',
                                    color: EmbunColors.blood,
                                    icon: Icons.lock_rounded),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: AnimatedScale(
                          scale: selected ? 1 : 0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.elasticOut,
                          child: const GameIcon('danger', size: 32),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Segel suara: yang dituduh menghantam ke tengah layar, layar bergetar
/// dan cap "DITUDUH" menimpa. Tidak memilih mendapat cap abu-abu yang
/// tenang. Hanya tampil di layar pemilih sendiri.
class _VoteStamp extends StatelessWidget {
  final Map<String, dynamic>? player; // null = tidak memilih
  const _VoteStamp({required this.player});

  @override
  Widget build(BuildContext context) {
    final abstain = player == null;
    final color = abstain ? Colors.white60 : Colors.redAccent;
    final size = MediaQuery.sizeOf(context);
    final avatar =
    (math.min(size.width, size.height) * 0.28).clamp(64.0, 130.0).toDouble();
    final stampW = (size.width * 0.6).clamp(160.0, 260.0).toDouble();

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
          // Getar singkat saat cap menghantam, lalu mereda.
          final k = ((t - 0.45) / 0.25).clamp(0.0, 1.0).toDouble();
          final shake = (t > 0.45 && t < 0.7)
              ? math.sin(k * 40) * 7 * (1 - k)
              : 0.0;

          return Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: Colors.black.withValues(alpha: 0.80 * dimT)),
              if (!abstain)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.95,
                      colors: [
                        Colors.transparent,
                        Colors.redAccent.withValues(alpha: 0.35 * dimT),
                      ],
                      stops: const [0.45, 1.0],
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(shake, shake * 0.6),
                child: Center(
                  // Menyusut otomatis di layar pendek (ponsel miring).
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (abstain)
                            Opacity(
                              opacity: (t / 0.3).clamp(0.0, 1.0).toDouble(),
                              child: const GameIcon('silang', size: 80),
                            )
                          else
                            Opacity(
                              opacity: (t / 0.2).clamp(0.0, 1.0).toDouble(),
                              child: Transform.scale(
                                scale: 2.2 - 1.2 * land,
                                child: PlayerAvatar(
                                  path: protagonistPath(
                                      player!['character_card'] as String),
                                  size: avatar,
                                  ring: Colors.redAccent,
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          if (!abstain)
                            Text(
                              player!['name'] as String,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                          const SizedBox(height: 16),
                          Opacity(
                            opacity: st.clamp(0.0, 1.0).toDouble(),
                            child: Transform.rotate(
                              angle: -0.2,
                              child: Transform.scale(
                                scale: 2.6 - 1.6 * st,
                                child: abstain
                                    ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: color, width: 4),
                                    borderRadius:
                                    BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'TIDAK MEMILIH',
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 4,
                                    ),
                                  ),
                                )
                                    : GameIcon('tertuduh',
                                    width: stampW,
                                    height: stampW * 90 / 220),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (flash > 0.01)
                ColoredBox(
                    color: Colors.white.withValues(alpha: 0.35 * flash)),
            ],
          );
        },
      ),
    );
  }
}