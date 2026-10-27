import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'emote_panel.dart' show kEmotes;

/// Aksi terhadap satu pemain: isyarat (semua fase), Beri Embun dan Tukar
/// Kartu (hanya hari biasa, ditegakkan juga oleh server).
Future<void> showPlayerSheet(
    BuildContext context, {
      required GameRepository repo,
      required String gameId,
      required Map<String, dynamic> player,
      required List<Map<String, dynamic>> hand,
      required Map<String, Map<String, dynamic>> defs,
      required double balance,
      required bool socialOpen,
    }) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PlayerSheet(
        repo: repo,
        gameId: gameId,
        player: player,
        hand: hand,
        defs: defs,
        balance: balance,
        socialOpen: socialOpen,
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
  const _PlayerSheet({
    required this.repo,
    required this.gameId,
    required this.player,
    required this.hand,
    required this.defs,
    required this.balance,
    required this.socialOpen,
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

  /// [closeWith] != null: tutup sheet lalu tampilkan toast itu.
  Future<void> _run(Future<void> Function() action, {String? closeWith}) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
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

  @override
  Widget build(BuildContext context) {
    final card = widget.player['character_card'] as String;
    final tradable =
    widget.hand.where((h) => h['card_id'] != 'embun_samaran').toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PlayerAvatar(
                    path: protagonistPath(card), size: 54, ring: EmbunColors.gold),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: EmbunColors.gold)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const SectionHeader(icon: 'discuss', title: 'Isyarat', iconSize: 28),
            const SizedBox(height: 6),
            Wrap(
              spacing: 2,
              children: [
                for (final e in kEmotes)
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: busy
                        ? null
                        : () => _run(
                          () => widget.repo
                          .sendEmote(widget.gameId, e, target: _uid),
                      closeWith: '$e terkirim ke $_name',
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(e, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (!widget.socialOpen)
              const NoticeStrip(
                icon: 'lock',
                text: 'Memberi embun dan menukar kartu hanya bisa di hari biasa.',
                accent: EmbunColors.goldDim,
              )
            else ...[
              SectionHeader(
                icon: 'bulirembun',
                title: 'Beri embun',
                iconSize: 28,
                trailing: Text('saldo ${widget.balance.floor()}',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white70)),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 18,
                children: [
                  for (final n in [1, 2, 3])
                    MedallionButton(
                      icon: 'bulirembun',
                      label: '×$n',
                      size: 52,
                      onTap: busy || widget.balance < n
                          ? null
                          : () => _run(
                            () => widget.repo
                            .giveEmbun(widget.gameId, _uid, n),
                        closeWith: 'Kamu memberi $_name $n embun',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              EmbunButton(
                label: tradeOpen ? 'Tutup daftar kartu' : 'Tukar kartu',
                icon: 'barter',
                kind: EmbunButtonKind.secondary,
                expand: true,
                onPressed:
                busy ? null : () => setState(() => tradeOpen = !tradeOpen),
              ),
              if (tradeOpen) ...[
                const SizedBox(height: 6),
                Text(
                  tradable.isEmpty
                      ? 'Tidak ada kartu yang bisa ditukar.'
                      : 'Pilih kartu yang kamu tawarkan. $_name memilih kartu balasannya sendiri.',
                  style: const TextStyle(fontSize: 12, color: Colors.white60),
                ),
                for (final h in tradable)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                        (widget.defs[h['card_id']]?['name'] as String?) ??
                            h['card_id'] as String),
                    subtitle: Text(
                        (widget.defs[h['card_id']]?['description']
                        as String?) ??
                            '',
                        style: const TextStyle(fontSize: 11)),
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
            if (err != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(err!,
                    style:
                    const TextStyle(color: EmbunColors.blood, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}