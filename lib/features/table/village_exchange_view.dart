import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../../data/game_repository.dart';
import '../common/ornate.dart';
import 'village_card_picker.dart';

class VillageExchangeView extends StatefulWidget {
  const VillageExchangeView({
    super.key,
    required this.repo,
    required this.gameId,
    required this.day,
    required this.hand,
    required this.defs,
    required this.players,
    required this.trades,
    required this.onAction,
    this.invitationId,
    this.jailed = false,
    this.busy = false,
  });
  final GameRepository repo;
  final String gameId;
  final int day;
  final List<Map<String, dynamic>> hand, players, trades;
  final Map<String, Map<String, dynamic>> defs;
  final Future<bool> Function(Future<void> Function()) onAction;
  final String? invitationId;
  final bool jailed, busy;
  @override
  State<VillageExchangeView> createState() => _VillageExchangeViewState();
}

class _VillageExchangeViewState extends State<VillageExchangeView> {
  String? _handId, _targetId;
  late int _tab = widget.invitationId != null ? 1 : 0;
  bool _choosing = false;
  List<Map<String, dynamic>> get _tradable => widget.hand
      .where(
        (h) =>
            h['card_id'] != 'embun_samaran' &&
            widget.defs[h['card_id']]?['kind'] != 'malam',
      )
      .toList();
  List<Map<String, dynamic>> get _incoming => widget.trades
      .where(
        (t) =>
            t['status'] == 'pending' &&
            t['day'] == widget.day &&
            t['to_id'] == widget.repo.myId &&
            (widget.invitationId == null || t['id'] == widget.invitationId),
      )
      .toList();
  List<Map<String, dynamic>> get _outgoing => widget.trades
      .where(
        (t) =>
            t['status'] == 'pending' &&
            t['day'] == widget.day &&
            t['from_id'] == widget.repo.myId,
      )
      .toList();
  bool get _locked => widget.busy || _choosing;
  Future<void> _pick(
    bool player,
    List<VillageCardOption> options,
    String? current,
  ) async {
    if (_locked) return;
    setState(() => _choosing = true);
    final id = await showVillageCardPicker(
      context,
      title: player ? 'Pilih pemain tujuan' : 'Pilih kartu yang ditawarkan',
      options: options,
      selected: current,
    );
    if (!mounted) return;
    setState(() {
      _choosing = false;
      if (id != null) {
        if (player) {
          _targetId = id;
        } else {
          _handId = id;
        }
      }
    });
  }

  Future<void> _accept(Map<String, dynamic> trade) async {
    if (_locked) return;
    if (widget.jailed) {
      await widget.onAction(
        () => widget.repo.respondTrade(trade['id'] as String, true),
      );
      return;
    }
    setState(() => _choosing = true);
    final hand = await showVillageCardPicker(
      context,
      title:
          'Balasan untuk ${widget.defs[trade['give_card_id']]?['name'] ?? 'kartu ini'}',
      options: [
        for (final h in _tradable) VillageCardOption.item(h, widget.defs),
      ],
      confirmLabel: 'Terima dan tukar kartu',
    );
    if (!mounted) return;
    setState(() => _choosing = false);
    if (hand != null) {
      await widget.onAction(
        () => widget.repo.respondTrade(
          trade['id'] as String,
          true,
          returnHand: hand,
        ),
      );
    }
  }

  Widget _empty(String title, String message) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        const Icon(Icons.swap_horiz, size: 36, color: EmbunColors.goldDim),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60, height: 1.4),
        ),
      ],
    ),
  );
  Widget _compose() {
    if (widget.jailed) {
      return _empty(
        'Kamu sedang dikurung',
        'Kamu bisa menerima pemberian melalui undangan, tetapi belum bisa menawarkan kartu.',
      );
    }
    final reserved = _outgoing.map((t) => t['give_hand_id']).toSet();
    final cards = _tradable.where((h) => !reserved.contains(h['id'])).toList();
    final others = widget.players
        .where((p) => p['user_id'] != widget.repo.myId && p['out_day'] == null)
        .toList();
    if (cards.isEmpty || others.isEmpty) {
      return _empty(
        'Belum ada yang bisa ditawarkan',
        'Selesaikan tawaran yang menunggu, atau lengkapi kartu di Pasar Riset.',
      );
    }
    final hand =
        cards.where((h) => h['id'] == _handId).firstOrNull ?? cards.first;
    final player =
        others.where((p) => p['user_id'] == _targetId).firstOrNull ??
        others.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Susun penawaran',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Ketuk kartu untuk mengganti pilihan.',
          style: TextStyle(fontSize: 12, color: Colors.white60),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, box) {
            final width = ((box.maxWidth - 46) / 2).clamp(80.0, 150.0);
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VillageChoiceCard(
                  option: VillageCardOption.item(hand, widget.defs),
                  width: width,
                  caption: 'Kartu darimu · Ganti',
                  onTap: _locked
                      ? null
                      : () => _pick(false, [
                          for (final h in cards)
                            VillageCardOption.item(h, widget.defs),
                        ], hand['id'] as String),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 65, left: 6, right: 6),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 22,
                    color: EmbunColors.goldDim,
                  ),
                ),
                VillageChoiceCard(
                  option: VillageCardOption.player(
                    player,
                    myId: widget.repo.myId,
                  ),
                  width: width,
                  caption: 'Penerima · Ganti',
                  onTap: _locked
                      ? null
                      : () => _pick(true, [
                          for (final p in others)
                            VillageCardOption.player(p, myId: widget.repo.myId),
                        ], player['user_id'] as String),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _locked
              ? null
              : () async {
                  final success = await widget.onAction(
                    () => widget.repo.proposeTrade(
                      widget.gameId,
                      player['user_id'] as String,
                      hand['id'] as String,
                    ),
                  );
                  if (success && mounted) setState(() => _tab = 2);
                },
          child: const Text('Kirim tawaran'),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
            'Penerima menentukan kartu balasan dan menyetujui pertukaran.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.white60, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _offer(Map<String, dynamic> trade, {required bool incoming}) {
    final id = incoming ? trade['from_id'] : trade['to_id'];
    final player = widget.players.where((p) => p['user_id'] == id).firstOrNull;
    final item = widget.defs[trade['give_card_id']];
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            incoming
                ? 'Tawaran dari ${player?['name'] ?? 'pemain'}'
                : 'Untuk ${player?['name'] ?? 'pemain'}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, box) {
              final width = ((box.maxWidth - 44) / 2).clamp(84.0, 142.0);
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (player != null)
                    VillageChoiceCard(
                      option: VillageCardOption.player(
                        player,
                        myId: widget.repo.myId,
                      ),
                      width: width,
                    ),
                  const Padding(
                    padding: EdgeInsets.only(top: 60, left: 7, right: 7),
                    child: Icon(Icons.swap_horiz, color: EmbunColors.goldDim),
                  ),
                  VillageChoiceCard(
                    option: VillageCardOption(
                      id: trade['id'] as String,
                      title: item?['name'] as String? ?? 'Kartu',
                      path: cardArtPath(item),
                      subtitle: incoming
                          ? 'Ditawarkan kepadamu'
                          : 'Kartu darimu',
                    ),
                    width: width,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          if (incoming)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _locked
                        ? null
                        : () => widget.onAction(
                            () => widget.repo.respondTrade(
                              trade['id'] as String,
                              false,
                            ),
                          ),
                    child: const Text('Tolak'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _locked || (!widget.jailed && _tradable.isEmpty)
                        ? null
                        : () => _accept(trade),
                    child: Text(
                      widget.jailed ? 'Terima kartu' : 'Pilih balasan',
                    ),
                  ),
                ),
              ],
            ),
          if (!incoming)
            const Text(
              'Menunggu persetujuan penerima',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: EmbunColors.gold),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final incoming = _incoming,
        outgoing = _outgoing,
        free = widget.invitationId != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (free)
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 8, 8, 14),
            child: Text(
              'UNDANGAN · TANPA MEMAKAI JATAH',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.3,
                color: EmbunColors.gold,
                fontWeight: FontWeight.w800,
              ),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final t in [
                  (0, 'Tawarkan'),
                  (1, 'Untukmu ${incoming.length}'),
                  (2, 'Menunggu ${outgoing.length}'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(t.$2),
                      selected: _tab == t.$1,
                      onSelected: _locked
                          ? null
                          : (_) => setState(() => _tab = t.$1),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 18, 8, 12),
            children: [
              if (!free && _tab == 0)
                _compose()
              else if (_tab == 1 || free) ...[
                if (incoming.isEmpty)
                  _empty(
                    free ? 'Tawaran sudah selesai' : 'Belum ada tawaran',
                    'Kamu dapat kembali ke tempat sebelumnya.',
                  ),
                for (final trade in incoming) _offer(trade, incoming: true),
              ] else ...[
                if (outgoing.isEmpty)
                  _empty(
                    'Belum ada tawaran menunggu',
                    'Kirim penawaran kartu melalui tab Tawarkan.',
                  ),
                for (final trade in outgoing) _offer(trade, incoming: false),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
