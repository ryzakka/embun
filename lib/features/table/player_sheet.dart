import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'card_tile.dart' show CardTile, kindLabel;
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
  bool tradingOpen = true,
  required int day,
  required bool iAmJailed,

  /// Dipanggil setelah embun berhasil diberikan (sasaran, jumlah).
  void Function(String targetId, int amount)? onGiveEmbun,

  /// Dipanggil setelah tawaran tukar terkirim (sasaran, baris kartu).
  void Function(String targetId, Map<String, dynamic> hand)? onOfferCard,
}) => showModalBottomSheet<void>(
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
    tradingOpen: tradingOpen,
    day: day,
    iAmJailed: iAmJailed,
    onGiveEmbun: onGiveEmbun,
    onOfferCard: onOfferCard,
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
  final bool tradingOpen;
  final int day;
  final bool iAmJailed;
  final void Function(String targetId, int amount)? onGiveEmbun;
  final void Function(String targetId, Map<String, dynamic> hand)? onOfferCard;
  const _PlayerSheet({
    required this.repo,
    required this.gameId,
    required this.player,
    required this.hand,
    required this.defs,
    required this.balance,
    required this.socialOpen,
    required this.tradingOpen,
    required this.day,
    required this.iAmJailed,
    this.onGiveEmbun,
    this.onOfferCard,
  });

  @override
  State<_PlayerSheet> createState() => _PlayerSheetState();
}

class _PlayerSheetState extends State<_PlayerSheet> {
  bool busy = false;
  bool tradeOpen = false;
  String? _pickCard; // card_id yang dipilih untuk ditawarkan
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

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final short = mq.size.height < 480; // ponsel miring
    final card = widget.player['character_card'] as String;
    final tradable = widget.hand
        .where(
          (h) =>
              h['card_id'] != 'embun_samaran' &&
              widget.defs[h['card_id']]?['kind'] != 'malam',
        )
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
          color: EmbunColors.goldDim.withValues(alpha: 0.55),
          width: 1.2,
        ),
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
              color: EmbunColors.goldDim.withValues(alpha: 0.7),
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
                16,
                8,
                16,
                16 + mq.padding.bottom + mq.viewInsets.bottom,
              ),
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
                        text:
                            'Kamu dikurung: kartu hanya bisa kamu terima, '
                            'tidak bisa kamu tawarkan.',
                        accent: EmbunColors.blood,
                      )
                    else if (widget.tradingOpen)
                      _trade(tradable)
                    else
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Tukar kartu saat kunjungan malam di Balai Pertukaran.',
                        ),
                      ),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            EmbunColors.gold.withValues(alpha: 0.13),
            Colors.transparent,
          ],
        ),
        border: Border.all(color: EmbunColors.goldDim.withValues(alpha: 0.28)),
      ),
      child: Row(
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
              // Subur bila nyawa penuh dan bebas; layu bila nyawa berkurang,
              // dikurung, atau sudah keluar.
              wreath:
                  (!isOut(widget.player) &&
                      !_targetJailed &&
                      livesLeft(widget.player) >= kMaxStrikes)
                  ? 'subur'
                  : 'layu',
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
                        asset: 'lock',
                        fontSize: 11,
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Tombol tutup eksplisit: berguna di desktop yang tak bisa menyeret.
          IconButton(
            tooltip: 'Tutup',
            icon: const GameIcon('x', size: 21),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
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
                        () => widget.repo.sendEmote(
                          widget.gameId,
                          e,
                          target: _uid,
                        ),
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
            trailing: Text(
              'saldo ${widget.balance.floor()}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
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
                      : () => _run(() async {
                          await widget.repo.giveEmbun(widget.gameId, _uid, n);
                          widget.onGiveEmbun?.call(_uid, n);
                        }, closeWith: 'Kamu memberi $_name $n embun'),
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

  Widget _countChip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: EmbunColors.goldDim.withValues(alpha: 0.5)),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: EmbunColors.gold,
      ),
    ),
  );

  Widget _trade(List<Map<String, dynamic>> tradable) {
    // Kartu sama ditumpuk (xN); yang ditawarkan satu per satu.
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final h in tradable) {
      groups.putIfAbsent(h['card_id'] as String, () => []).add(h);
    }
    final ids = groups.keys.toList();
    final picked = _pickCard != null && groups.containsKey(_pickCard)
        ? _pickCard
        : null;
    final pickedDef = picked == null ? null : widget.defs[picked];

    return _Panel(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: busy
                  ? null
                  : () => setState(() {
                      tradeOpen = !tradeOpen;
                      if (!tradeOpen) _pickCard = null;
                    }),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const GameIcon('barter', size: 30),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Tukar kartu',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: EmbunColors.gold,
                        ),
                      ),
                    ),
                    _countChip('${tradable.length} kartu'),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: tradeOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: const Icon(
                        Icons.expand_more_rounded,
                        color: EmbunColors.gold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (tradeOpen) ...[
              const SizedBox(height: 6),
              Text(
                tradable.isEmpty
                    ? 'Tidak ada kartu yang bisa ditukar.'
                    : _targetJailed
                    ? '$_name sedang dikurung, jadi ia hanya bisa menerima. '
                          'Kartu ini diberikan tanpa balasan.'
                    : 'Pilih kartu yang kamu tawarkan. $_name memilih kartu '
                          'balasannya sendiri.',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Colors.white60,
                ),
              ),
              if (tradable.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(child: GameIcon('mydeck2', size: 56)),
                )
              else ...[
                // Deretan kartu bergambar, digeser ke samping.
                SizedBox(
                  height: 100 * 1.5 + 26,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
                    itemCount: ids.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final id = ids[i];
                      return Align(
                        alignment: Alignment.topCenter,
                        child: CardTile(
                          def: widget.defs[id],
                          fallbackName: id,
                          width: 100,
                          selected: id == picked,
                          dim: picked != null && id != picked,
                          count: groups[id]!.length,
                          onTap: busy
                              ? null
                              : () => setState(
                                  () => _pickCard = id == picked ? null : id,
                                ),
                        ),
                      );
                    },
                  ),
                ),
                Text(
                  picked == null
                      ? 'Ketuk kartu untuk memilih. Tahan untuk memperbesar.'
                      : 'Ketuk lagi untuk membatalkan pilihan.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.white38),
                ),
                // Ringkasan kartu terpilih + konfirmasi.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: picked == null
                      ? const SizedBox(width: double.infinity)
                      : Container(
                          key: ValueKey(picked),
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                EmbunColors.gold.withValues(alpha: 0.14),
                                Colors.black.withValues(alpha: 0.25),
                              ],
                            ),
                            border: Border.all(
                              color: EmbunColors.gold.withValues(alpha: 0.55),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      (pickedDef?['name'] as String?) ?? picked,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: EmbunColors.gold,
                                      ),
                                    ),
                                  ),
                                  if (kindLabel[pickedDef?['kind']] != null)
                                    _countChip(kindLabel[pickedDef?['kind']]!),
                                ],
                              ),
                              if (((pickedDef?['description'] as String?) ?? '')
                                  .isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  pickedDef!['description'] as String,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    height: 1.35,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              EmbunButton(
                                label: _targetJailed
                                    ? 'Berikan ke $_name'
                                    : 'Tawarkan ke $_name',
                                icon: 'kirim',
                                expand: true,
                                onPressed: busy
                                    ? null
                                    : () {
                                        final h = groups[picked]!.first;
                                        _run(
                                          () async {
                                            await widget.repo.proposeTrade(
                                              widget.gameId,
                                              _uid,
                                              h['id'] as String,
                                            );
                                            widget.onOfferCard?.call(_uid, h);
                                          },
                                          closeWith: _targetJailed
                                              ? 'Kartu diberikan ke $_name'
                                              : 'Tawaran dikirim ke $_name',
                                        );
                                      },
                              ),
                            ],
                          ),
                        ),
                ),
              ],
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
        const GameIcon('alert', size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: EmbunColors.blood,
              fontSize: 12.5,
              height: 1.3,
            ),
          ),
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
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.36),
          Colors.black.withValues(alpha: 0.22),
        ],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: EmbunColors.goldDim.withValues(alpha: 0.32)),
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
