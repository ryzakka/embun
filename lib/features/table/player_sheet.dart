import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'emote_panel.dart' show kEmotes;
import 'player_status.dart';

/// Aksi terhadap satu pemain: isyarat (semua fase), Beri Embun dan Tukar
/// Kartu (hanya hari biasa, ditegakkan juga oleh server).
///
/// Ponsel: lembar naik dari bawah selebar layar. Desktop/tablet: lembar
/// dipusatkan dengan lebar maksimum 560 supaya tidak melar.
Future<void> showPlayerSheet(
    BuildContext context, {
      required GameRepository repo,
      required String gameId,
      required Map<String, dynamic> player,
      required List<Map<String, dynamic>> hand,
      required Map<String, Map<String, dynamic>> defs,
      required double balance,
      required bool socialOpen,
      required int day,
      required bool iAmJailed,
    }) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _PlayerSheet(
        repo: repo,
        gameId: gameId,
        player: player,
        hand: hand,
        defs: defs,
        balance: balance,
        socialOpen: socialOpen,
        day: day,
        iAmJailed: iAmJailed,
      ),
    );

class _PlayerSheet extends StatefulWidget {
  final GameRepository repo;
  final String gameId;
  final Map<String, dynamic> player;
  final List<Map<String, dynamic>> hand;
  final Map<String, Map<String, dynamic>> defs;
  final double balance;
  final bool socialOpen;
  final int day;
  final bool iAmJailed;
  const _PlayerSheet({
    required this.repo,
    required this.gameId,
    required this.player,
    required this.hand,
    required this.defs,
    required this.balance,
    required this.socialOpen,
    required this.day,
    required this.iAmJailed,
  });

  @override
  State<_PlayerSheet> createState() => _PlayerSheetState();
}

class _PlayerSheetState extends State<_PlayerSheet> {
  bool busy = false;
  bool tradeOpen = false;
  String? err;

  String get _uid => widget.player['user_id'] as String;
  String get _name => widget.player['name'] as String;
  bool get _targetJailed => isJailed(widget.player, widget.day);

  /// [closeWith] != null: tutup sheet lalu tampilkan toast itu.
  Future<void> _run(Future<void> Function() action, {String? closeWith}) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    HapticFeedback.selectionClick();
    setState(() {
      busy = true;
      err = null;
    });
    try {
      await action();
      if (closeWith != null) {
        nav.pop();
        messenger.showSnackBar(SnackBar(content: Text(closeWith)));
        return;
      }
    } catch (e) {
      if (mounted) setState(() => err = errMsg(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _cardName(Map<String, dynamic> h) =>
      (widget.defs[h['card_id']]?['name'] as String?) ?? h['card_id'] as String;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final short = mq.size.height < 480; // ponsel miring
    final card = widget.player['character_card'] as String;
    final tradable =
    widget.hand
        .where((h) =>
    h['card_id'] != 'embun_samaran' && h['card_id'] != 'kunci_segel')
        .toList();
    final medal = short ? 46.0 : 56.0;

    return Container(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.94),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2B2234), Color(0xFF14101B)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(
            color: EmbunColors.goldDim.withValues(alpha: 0.55), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: EmbunColors.gold.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 6),
          // Penanda sibuk tipis di atas; tinggi tetap agar tata letak tidak loncat.
          SizedBox(
            height: 2,
            child: busy
                ? const LinearProgressIndicator(
              color: EmbunColors.gold,
              backgroundColor: Colors.transparent,
            )
                : null,
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, 16 + mq.padding.bottom + mq.viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(card, short),
                  const SizedBox(height: 12),
                  _goldDivider(),
                  const SizedBox(height: 14),
                  _gestures(),
                  const SizedBox(height: 12),
                  if (!widget.socialOpen)
                    const NoticeStrip(
                      icon: 'lock',
                      text:
                      'Memberi embun dan menukar kartu hanya bisa di hari biasa.',
                      accent: EmbunColors.goldDim,
                    )
                  else ...[
                    _giveEmbun(medal),
                    const SizedBox(height: 12),
                    if (widget.iAmJailed)
                      const NoticeStrip(
                        icon: 'lock',
                        text: 'Kamu dikurung: kartu hanya bisa kamu terima, '
                            'tidak bisa kamu tawarkan.',
                        accent: EmbunColors.blood,
                      )
                    else
                      _trade(tradable),
                  ],
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: err == null
                        ? const SizedBox(width: double.infinity)
                        : _errorBox(err!),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(String card, bool short) {
    final avatar = short ? 46.0 : 64.0;
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: EmbunColors.gold.withValues(alpha: 0.4),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: PlayerAvatar(
            path: protagonistPath(card),
            size: avatar,
            ring: EmbunColors.gold,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: short ? 20 : 24,
                  fontWeight: FontWeight.w800,
                  color: EmbunColors.gold,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  LivesRow(lives: livesLeft(widget.player), size: 16),
                  if (_targetJailed)
                    const StatusTag(
                        text: 'Dikurung',
                        color: EmbunColors.blood,
                        icon: Icons.lock_rounded,
                        fontSize: 11),
                ],
              ),
            ],
          ),
        ),
        // Tombol tutup eksplisit: berguna di desktop yang tak bisa menyeret.
        IconButton(
          tooltip: 'Tutup',
          icon: const Icon(Icons.close_rounded, color: Colors.white54),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }

  Widget _goldDivider() => Container(
    height: 1.5,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.transparent,
          EmbunColors.gold.withValues(alpha: 0.7),
          Colors.transparent,
        ],
      ),
    ),
  );

  Widget _gestures() => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(icon: 'discuss', title: 'Isyarat', iconSize: 28),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in kEmotes)
              _EmoteTile(
                emoji: e,
                onTap: busy
                    ? null
                    : () => _run(
                      () => widget.repo
                      .sendEmote(widget.gameId, e, target: _uid),
                  closeWith: '$e terkirim ke $_name',
                ),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _giveEmbun(double medal) {
    final poor = widget.balance < 1;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: 'bulirembun',
            title: 'Beri embun',
            iconSize: 28,
            trailing: Text('saldo ${widget.balance.floor()}',
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final n in [1, 2, 3])
                MedallionButton(
                  icon: 'bulirembun',
                  label: '×$n',
                  size: medal,
                  onTap: busy || widget.balance < n
                      ? null
                      : () => _run(
                        () => widget.repo.giveEmbun(widget.gameId, _uid, n),
                    closeWith: 'Kamu memberi $_name $n embun',
                  ),
                ),
            ],
          ),
          if (poor) ...[
            const SizedBox(height: 10),
            const Text(
              'Saldo embunmu belum cukup untuk memberi.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ],
      ),
    );
  }

  Widget _trade(List<Map<String, dynamic>> tradable) {
    return _Panel(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EmbunButton(
              label: tradeOpen ? 'Tutup daftar kartu' : 'Tukar kartu',
              icon: 'barter',
              kind: EmbunButtonKind.secondary,
              expand: true,
              onPressed:
              busy ? null : () => setState(() => tradeOpen = !tradeOpen),
            ),
            if (tradeOpen) ...[
              const SizedBox(height: 10),
              Text(
                tradable.isEmpty
                    ? 'Tidak ada kartu yang bisa ditukar.'
                    : _targetJailed
                    ? '$_name sedang dikurung, jadi ia hanya bisa menerima. '
                    'Kartu ini diberikan tanpa balasan.'
                    : 'Pilih kartu yang kamu tawarkan. $_name memilih kartu '
                    'balasannya sendiri.',
                style: const TextStyle(
                    fontSize: 12, height: 1.35, color: Colors.white60),
              ),
              const SizedBox(height: 8),
              for (final h in tradable)
                _CardTile(
                  name: _cardName(h),
                  description:
                  (widget.defs[h['card_id']]?['description'] as String?) ??
                      '',
                  onTap: busy
                      ? null
                      : () => _run(
                        () => widget.repo.proposeTrade(
                        widget.gameId, _uid, h['id'] as String),
                    closeWith: 'Tawaran dikirim ke $_name',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _errorBox(String message) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: EmbunColors.blood.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: EmbunColors.blood.withValues(alpha: 0.6)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline_rounded,
            size: 18, color: EmbunColors.blood),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  color: EmbunColors.blood, fontSize: 12.5, height: 1.3)),
        ),
      ],
    ),
  );
}

/// Bingkai satu kelompok aksi: latar gelap, garis emas tipis.
class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.28),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: EmbunColors.goldDim.withValues(alpha: 0.28)),
    ),
    child: child,
  );
}

/// Satu isyarat: ubin 48x48 (target ketuk yang nyaman di ponsel).
class _EmoteTile extends StatelessWidget {
  final String emoji;
  final VoidCallback? onTap;
  const _EmoteTile({required this.emoji, required this.onTap});

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? 0.45 : 1,
    child: Material(
      color: Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 26)),
          ),
        ),
      ),
    ),
  );
}

/// Satu kartu yang bisa ditawarkan dalam tukar kartu.
class _CardTile extends StatelessWidget {
  final String name;
  final String description;
  final VoidCallback? onTap;
  const _CardTile({
    required this.name,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(description,
                            style: const TextStyle(
                                fontSize: 11.5,
                                height: 1.3,
                                color: Colors.white60)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: EmbunColors.gold),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}