import 'dart:math' show sin, pi;
import 'package:flutter/material.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import 'card_tile.dart';

/// Layar hari biasa: tab Meja (kartumu), Pasar (belanja), Balai (kabar,
/// pemberian, tawaran tukar). Tetap hidup setelah pemain menekan "Akhiri
/// hari", jadi tidak ada lagi layar tunggu yang kosong.
class DayView extends StatefulWidget {
  final GameRepository repo;
  final String gameId;
  final int day;
  final int priceMod;
  final int extraBuy;
  final List<Map<String, dynamic>> hand;
  final Map<String, Map<String, dynamic>> defs;
  final double balance;
  final bool jailed;
  final bool iAmReady;
  final int readyCount;
  final int total;
  final List<Map<String, dynamic>> players;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> trades;

  const DayView({
    super.key,
    required this.repo,
    required this.gameId,
    required this.day,
    required this.priceMod,
    required this.extraBuy,
    required this.hand,
    required this.defs,
    required this.balance,
    required this.jailed,
    required this.iAmReady,
    required this.readyCount,
    required this.total,
    required this.players,
    required this.events,
    required this.trades,
  });

  @override
  State<DayView> createState() => _DayViewState();
}

class _DayViewState extends State<DayView> {
  int tab = 0; // 0 meja, 1 pasar, 2 balai
  List<Map<String, dynamic>>? offers;
  String? selected;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    try {
      final o = await widget.repo.offers(widget.gameId, widget.day);
      if (mounted) setState(() => offers = o);
    } catch (_) {
      if (mounted) setState(() => offers = []);
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _run(Future<void> Function() action, {String? ok}) async {
    setState(() => busy = true);
    try {
      await action();
      if (ok != null && mounted) _toast(ok);
    } catch (e) {
      if (mounted) _toast(errMsg(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _name(String? id) {
    for (final p in widget.players) {
      if (p['user_id'] == id) return p['name'] as String;
    }
    return '?';
  }

  String _cardName(String id) => (widget.defs[id]?['name'] as String?) ?? id;

  int _price(String id) {
    final c = (widget.defs[id]?['cost'] as int?) ?? 0;
    if (c == 0) return 0;
    return (c + widget.priceMod).clamp(1, 99).toInt();
  }

  int get _remaining {
    final bought = (offers ?? []).where((o) => o['bought'] == true).length;
    return 1 + widget.extraBuy - bought;
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  List<Map<String, dynamic>> get _incoming => widget.trades
      .where((t) =>
  t['status'] == 'pending' &&
      t['day'] == widget.day &&
      t['to_id'] == widget.repo.myId)
      .toList();

  List<Map<String, dynamic>> get _outgoing => widget.trades
      .where((t) =>
  t['status'] == 'pending' &&
      t['day'] == widget.day &&
      t['from_id'] == widget.repo.myId)
      .toList();

  Future<void> _buy() async {
    final id = selected;
    if (id == null) return;
    await _run(() async {
      await widget.repo.buyCard(widget.gameId, id);
      if (mounted) setState(() => selected = null);
      await _loadOffers();
    }, ok: '${_cardName(id)} masuk ke mejamu');
  }

  Future<void> _accept(Map<String, dynamic> t) async {
    final tradable =
    widget.hand.where((h) => h['card_id'] != 'embun_samaran').toList();
    if (tradable.isEmpty) {
      _toast('Kamu tidak punya kartu untuk ditukar');
      return;
    }
    final pick = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Tukar ${_cardName(t['give_card_id'] as String)} dengan...'),
        children: [
          for (final h in tradable)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, h['id'] as String),
              child: Text(_cardName(h['card_id'] as String)),
            ),
        ],
      ),
    );
    if (pick == null || !mounted) return;
    await _run(
          () => widget.repo.respondTrade(t['id'] as String, true, returnHand: pick),
      ok: 'Kartu bertukar',
    );
  }

  // ---------- bagian kecil yang dipakai ulang ----------

  Widget _section(String title, {IconData? icon, String? trailing}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: Colors.white60),
          const SizedBox(width: 6),
        ],
        Text(title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const Spacer(),
        if (trailing != null)
          Text(trailing,
              style: const TextStyle(fontSize: 11, color: Colors.white54)),
      ],
    ),
  );

  Widget _chip(IconData icon, String text, {Color? color}) {
    final c = color ?? Colors.white70;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(fontSize: 12, color: c)),
        ],
      ),
    );
  }

  Widget _jailBanner() => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.redAccent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
    ),
    child: const Row(
      children: [
        Icon(Icons.lock, size: 16, color: Colors.redAccent),
        SizedBox(width: 8),
        Expanded(
          child: Text('Kamu dikurung hari ini: tidak bisa berbelanja.',
              style: TextStyle(fontSize: 12, color: Colors.redAccent)),
        ),
      ],
    ),
  );

  Widget _empty(IconData icon, String title, String hint) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 40, color: Colors.white24),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(color: Colors.white60)),
        const SizedBox(height: 2),
        Text(hint,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.white38)),
      ],
    ),
  );

  // ---------- bagian-bagian UI ----------

  /// Fajar menyingsing: spanduk meluncur turun, ikon matahari memantul,
  /// cahaya menyapu dari kiri ke kanan lalu meredup.
  Widget _kabar() {
    final k = widget.events
        .where((e) => e['kind'] == 'kabar' && e['day'] == widget.day)
        .toList();
    if (k.isEmpty) return const SizedBox.shrink();
    final text = '${k.last['text']}';
    return TweenAnimationBuilder<double>(
      key: ValueKey(text),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1400),
      builder: (context, t, _) {
        final rise = Curves.easeOutCubic
            .transform((t / 0.45).clamp(0.0, 1.0).toDouble());
        final pop = Curves.elasticOut
            .transform(((t - 0.15) / 0.6).clamp(0.0, 1.0).toDouble());
        final sweep = ((t - 0.2) / 0.6).clamp(0.0, 1.0).toDouble();
        final glow = (1 - t) * 0.55 + 0.1;
        final mid = Color.lerp(const Color(0xFF332B10),
            const Color(0xFF7A5E1A), sin(sweep * pi))!;
        return Opacity(
          opacity: rise.clamp(0.0, 1.0).toDouble(),
          child: Transform.translate(
            offset: Offset(0, (1 - rise) * -18),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF332B10),
                    mid,
                    const Color(0xFF332B10),
                  ],
                  stops: [
                    (sweep - 0.25).clamp(0.0, 1.0).toDouble(),
                    sweep,
                    (sweep + 0.25).clamp(0.0, 1.0).toDouble(),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border:
                Border.all(color: Colors.amberAccent.withValues(alpha: 0.7)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amberAccent
                        .withValues(alpha: (glow * 0.6).clamp(0.0, 1.0)),
                    blurRadius: 8 + 16 * glow,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Transform.rotate(
                    angle: (1 - pop) * -1.2,
                    child: Transform.scale(
                      scale: (0.4 + 0.6 * pop).clamp(0.1, 1.6).toDouble(),
                      child: const Icon(Icons.wb_twilight,
                          size: 18, color: Colors.amberAccent),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Kabar Pagi: $text',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tabs() {
    final n = _incoming.length;
    Widget item(int i, IconData icon, String label, {int badge = 0}) {
      final sel = tab == i;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => tab = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: sel
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Badge(
                  isLabelVisible: badge > 0,
                  label: Text('$badge'),
                  child: Icon(icon,
                      size: 18,
                      color: sel ? Colors.amberAccent : Colors.white60),
                ),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      color: sel ? Colors.white : Colors.white70,
                    )),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          item(0, Icons.style, 'Meja'),
          item(1, Icons.storefront, 'Pasar'),
          item(2, Icons.campaign, 'Balai', badge: n),
        ],
      ),
    );
  }

  Widget _mejaTab() {
    final hand = widget.hand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.jailed) _jailBanner(),
        _section('Kartu di mejamu',
            icon: Icons.style, trailing: '${hand.length} kartu'),
        Expanded(
          child: hand.isEmpty
              ? _empty(Icons.style, 'Mejamu masih kosong',
              'Beli kartu di Pasar untuk dipersembahkan.')
              : SingleChildScrollView(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in hand)
                  CardTile(
                    def: widget.defs[c['card_id']],
                    fallbackName: c['card_id'] as String,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _pasarTab() {
    final o = offers;
    final remain = _remaining < 0 ? 0 : _remaining;
    final mod = widget.priceMod;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.jailed) _jailBanner(),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _chip(Icons.water_drop, _fmt(widget.balance),
                color: const Color(0xFF7FD3F7)),
            if (!widget.jailed)
              _chip(Icons.shopping_basket, 'Jatah belanja: $remain',
                  color: remain > 0 ? Colors.white70 : Colors.white38),
            if (mod != 0)
              _chip(Icons.sell, 'Harga ${mod > 0 ? '+' : ''}$mod',
                  color: mod < 0 ? Colors.greenAccent : Colors.orangeAccent),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: o == null
              ? const Center(child: CircularProgressIndicator())
              : o.isEmpty
              ? _empty(Icons.storefront, 'Pasar sedang sepi',
              'Belum ada tawaran hari ini.')
              : SingleChildScrollView(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final offer in o)
                  Builder(builder: (_) {
                    final id = offer['card_id'] as String;
                    final price = _price(id);
                    final bought = offer['bought'] == true;
                    final ok = !widget.jailed &&
                        !bought &&
                        remain > 0 &&
                        price <= widget.balance;
                    return CardTile(
                      def: widget.defs[id],
                      fallbackName: id,
                      showCost: true,
                      costOverride: price,
                      badge: bought ? 'Terbeli' : null,
                      selected: selected == id,
                      dim: !ok,
                      onTap: ok ? () => setState(() => selected = id) : null,
                    );
                  }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: busy || selected == null ? null : _buy,
            icon: const Icon(Icons.water_drop, size: 16),
            label: Text(selected == null
                ? 'Pilih kartu untuk dibeli'
                : 'Beli ${_cardName(selected!)} (${_price(selected!)})'),
          ),
        ),
      ],
    );
  }

  Widget _balaiTab() {
    final feed = widget.events
        .where((e) =>
    e['kind'] != 'kabar' &&
        (e['day'] == widget.day || e['day'] == widget.day - 1))
        .toList()
        .reversed
        .toList();
    final inc = _incoming;
    final out = _outgoing;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.white54),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ketuk avatar pemain di atas untuk memberi embun, menukar kartu, atau mengirim isyarat.',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (inc.isNotEmpty) ...[
          _section('Tawaran tukar untukmu',
              icon: Icons.swap_horiz, trailing: '${inc.length}'),
          for (final t in inc)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.amberAccent.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${_name(t['from_id'] as String?)} menawarkan ${_cardName(t['give_card_id'] as String)}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          (widget.defs[t['give_card_id']]?['description']
                          as String?) ??
                              '',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => _run(() =>
                        widget.repo.respondTrade(t['id'] as String, false)),
                    child: const Text('Tolak'),
                  ),
                  FilledButton(
                    onPressed: busy ? null : () => _accept(t),
                    child: const Text('Terima'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
        ],
        if (out.isNotEmpty) ...[
          _section('Menunggu jawaban', icon: Icons.hourglass_top),
          for (final t in out)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${_name(t['to_id'] as String?)} belum menjawab tawaranmu (${_cardName(t['give_card_id'] as String)})',
                style: const TextStyle(fontSize: 12, color: Colors.white60),
              ),
            ),
          const SizedBox(height: 6),
        ],
        _section('Kabar desa', icon: Icons.campaign),
        if (feed.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Belum ada yang terjadi...',
                style: TextStyle(color: Colors.white38)),
          )
        else
          for (final e in feed)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    e['kind'] == 'give' ? Icons.water_drop : Icons.swap_horiz,
                    size: 14,
                    color: e['kind'] == 'give'
                        ? const Color(0xFF7FD3F7)
                        : Colors.amberAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(e['text'] as String,
                        style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  Text('H${e['day']}',
                      style:
                      const TextStyle(fontSize: 10, color: Colors.white38)),
                ],
              ),
            ),
      ],
    );
  }

  Widget _finishBar() {
    final ready = widget.iAmReady;
    final progress =
    widget.total == 0 ? 0.0 : (widget.readyCount / widget.total);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: ready || busy
                ? null
                : () => _run(() => widget.repo.finishDay(widget.gameId)),
            icon: Icon(ready ? Icons.hourglass_top : Icons.nightlight_round,
                size: 18),
            label: Text(ready
                ? 'Menunggu... ${widget.readyCount}/${widget.total} siap'
                : 'Akhiri hari ${widget.day}'),
          ),
        ),
        if (ready)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0).toDouble(),
                minHeight: 4,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (tab) {
      0 => _mejaTab(),
      1 => _pasarTab(),
      _ => _balaiTab(),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _kabar(),
        _tabs(),
        const SizedBox(height: 10),
        Expanded(child: body),
        const SizedBox(height: 8),
        _finishBar(),
      ],
    );
  }
}