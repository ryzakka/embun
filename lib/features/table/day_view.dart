import 'dart:async';
import 'dart:math' show sin, pi, min;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'card_tile.dart';
import 'flip_card.dart';

double _c(double v) => v.clamp(0.0, 1.0).toDouble();

/// Ukuran kartu dan jumlah kolom, dihitung dari lebar yang tersedia.
class _Grid {
  final int cols;
  final double w;
  final double gap;
  const _Grid(this.cols, this.w, this.gap);
  double get h => w * 9 / 7;
}

_Grid _metrics(double aw) {
  const gap = 10.0;
  final minW = aw < 600 ? 120.0 : 140.0;
  const maxW = 164.0;
  var cols = ((aw + gap) / (minW + gap)).floor();
  if (cols < 2) cols = 2;
  var w = (aw - (cols - 1) * gap) / cols;
  if (w > maxW) w = maxW;
  // Bulatkan ke bawah: selisih desimal bisa membuat Wrap turun satu kolom.
  return _Grid(cols, w.floorToDouble(), gap);
}

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

  // Pembukaan pasar: kartu dibagikan sebagai punggung, lalu berbalik. Hanya
  // diputar sekali per hari; kembali ke tab Pasar langsung menampilkan muka.
  bool _marketOpened = false;
  Timer? _openTimer;
  bool _kabarHidden = false;

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  @override
  void dispose() {
    _openTimer?.cancel();
    super.dispose();
  }

  /// Jeda sesaat setelah punggung kartu terbagi, baru berbalik.
  void _armMarket() {
    if (_marketOpened || _openTimer != null) return;
    _openTimer = Timer(const Duration(milliseconds: 750), () {
      if (mounted) setState(() => _marketOpened = true);
    });
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
      HapticFeedback.mediumImpact();
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

  Widget _section(String title, {String? icon, String? trailing}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        if (icon != null) ...[
          GameIcon(icon, size: 26),
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

  Widget _chip(String icon, String text, {Color? color}) {
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
          GameIcon(icon, size: 22),
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
        GameIcon('lock', size: 26),
        SizedBox(width: 8),
        Expanded(
          child: Text('Kamu dikurung hari ini: tidak bisa berbelanja.',
              style: TextStyle(fontSize: 12, color: Colors.redAccent)),
        ),
      ],
    ),
  );

  Widget _empty(String icon, String title, String hint) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(opacity: 0.55, child: GameIcon(icon, size: 64)),
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
  Widget _kabar({bool compact = false}) {
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
              margin: EdgeInsets.only(bottom: compact ? 6 : 10),
              padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 12, vertical: compact ? 6 : 8),
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
                      child: const GameIcon('announcement', size: 30),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Kabar Pagi: $text',
                        maxLines: compact ? 3 : null,
                        overflow: compact ? TextOverflow.ellipsis : null,
                        style: const TextStyle(fontSize: 12)),
                  ),
                  if (compact)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _kabarHidden = true),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: GameIcon('x', size: 22),
                      ),
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
    Widget item(int i, String icon, String label, {int badge = 0}) {
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
                  child: Opacity(
                      opacity: sel ? 1 : 0.6,
                      child: GameIcon(icon, size: 28)),
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
          item(0, 'mydeck2', 'Meja'),
          item(1, 'store', 'Pasar'),
          item(2, 'announcement', 'Balai', badge: n),
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
            icon: 'mydeck2', trailing: '${hand.length} kartu'),
        Expanded(
          child: hand.isEmpty
              ? _empty('mydeck2', 'Mejamu masih kosong',
              'Beli kartu di Pasar untuk dipersembahkan.')
              : LayoutBuilder(builder: (context, box) {
            final g = _metrics(box.maxWidth);
            return SingleChildScrollView(
              padding: const EdgeInsets.only(top: 14, bottom: 8),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: g.gap,
                runSpacing: g.gap,
                children: [
                  for (final h in hand)
                    CardTile(
                      def: widget.defs[h['card_id']],
                      fallbackName: h['card_id'] as String,
                      width: g.w,
                    ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  /// Posisi tumpukan dikurangi posisi akhir kartu ke-[i]: titik asal saat
  /// kartu dibagikan. Tumpukan berada di tengah area yang terlihat.
  Offset _dealOffset(_Grid g, int i, int n, double aw, double viewH) {
    final rows = (n / g.cols).ceil();
    final r = i ~/ g.cols;
    final col = i % g.cols;
    final inRow = (r == rows - 1) ? n - r * g.cols : g.cols;
    final rowW = inRow * g.w + (inRow - 1) * g.gap;
    final x = (aw - rowW) / 2 + col * (g.w + g.gap) + g.w / 2;
    final totalH = rows * g.h + (rows - 1) * g.gap;
    final y = 14 + r * (g.h + g.gap) + g.h / 2;
    final vh = viewH > 22 ? viewH - 22 : viewH;
    final deckY = 14 + min(totalH, vh) / 2;
    return Offset(aw / 2 - x, deckY - y);
  }

  /// Papan pasar: jatuh dari atas, berayun mereda, cahaya menyapu.
  Widget _marketSign(int n) => TweenAnimationBuilder<double>(
    // Setelah pasar pernah dibuka hari ini, papan langsung tampil tenang.
    tween: Tween<double>(begin: _marketOpened ? 1.0 : 0.0, end: 1.0),
    duration: const Duration(milliseconds: 1500),
    builder: (context, t, _) {
      final drop =
      Curves.easeOutCubic.transform(_c(t / 0.4));
      final swing = sin(t * pi * 5) * 0.10 * (1 - t);
      final sweep = _c((t - 0.2) / 0.7);
      final mid = Color.lerp(const Color(0xFF3A2E12),
          const Color(0xFF8A6A20), sin(sweep * pi))!;
      return Opacity(
        opacity: _c(drop),
        child: Transform.rotate(
          angle: swing,
          alignment: Alignment.topCenter,
          child: Transform.translate(
            offset: Offset(0, (1 - drop) * -26),
            child: Container(
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF3A2E12), mid, const Color(0xFF3A2E12)],
                  stops: [_c(sweep - 0.25), sweep, _c(sweep + 0.25)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.amberAccent.withValues(alpha: 0.6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amberAccent
                        .withValues(alpha: 0.25 * (1 - t) + 0.05),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const GameIcon('store', size: 28),
                  const SizedBox(width: 8),
                  const Text('Pasar Pagi',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                  const Spacer(),
                  Text('$n kartu hari ini',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white70)),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  /// Cap "TERBELI" menghantam kartu yang sudah dibeli.
  Widget _boughtStamp() => Center(
    child: TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: _c(t * 2),
        child: Transform.rotate(
          angle: -0.3,
          child: Transform.scale(scale: 2.2 - 1.2 * t, child: child),
        ),
      ),
      child: const GameIcon('dibeli', width: 104, height: 56),
    ),
  );

  Widget _marketCard(int i, int n, Map<String, dynamic> offer, _Grid g,
      double aw, double viewH, int remain) {
    final id = offer['card_id'] as String;
    final price = _price(id);
    final bought = offer['bought'] == true;
    final ok = !widget.jailed &&
        !bought &&
        remain > 0 &&
        price <= widget.balance;
    final def = widget.defs[id];
    final bad = def?['side'] == 'antagonis';

    final tile = CardTile(
      def: def,
      fallbackName: id,
      width: g.w,
      showCost: true,
      costOverride: price,
      badge: bought ? 'Terbeli' : null,
      selected: selected == id,
      dim: !ok,
      onTap: ok
          ? () {
        HapticFeedback.selectionClick();
        setState(() => selected = id);
      }
          : null,
    );
    final front = Stack(
      clipBehavior: Clip.none,
      children: [
        tile,
        if (bought)
          Positioned.fill(child: IgnorePointer(child: _boughtStamp())),
      ],
    );

    return FlipCard(
      key: ValueKey('offer$i-$id'),
      index: i,
      width: g.w,
      height: g.h,
      revealed: _marketOpened,
      animate: !_marketOpened,
      dark: bad,
      glow: bad ? const Color(0xFFB07CE8) : const Color(0xFFFFD866),
      dealOffset: _dealOffset(g, i, n, aw, viewH),
      suspense: n > 2 && i == n - 1,
      front: front,
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
            _chip('bulirembun', _fmt(widget.balance),
                color: const Color(0xFF7FD3F7)),
            if (!widget.jailed)
              _chip('item', 'Jatah belanja: $remain',
                  color: remain > 0 ? Colors.white70 : Colors.white38),
            if (mod != 0)
              _chip(mod > 0 ? 'plus' : 'minus', 'Harga ${mod > 0 ? '+' : ''}$mod',
                  color: mod < 0 ? Colors.greenAccent : Colors.orangeAccent),
          ],
        ),
        const SizedBox(height: 10),
        if (o != null && o.isNotEmpty) ...[
          _marketSign(o.length),
          const SizedBox(height: 4),
        ],
        Expanded(
          child: o == null
              ? const Center(child: CircularProgressIndicator())
              : o.isEmpty
              ? _empty('store', 'Pasar sedang sepi',
              'Belum ada tawaran hari ini.')
              : LayoutBuilder(builder: (context, c) {
            _armMarket();
            final g = _metrics(c.maxWidth);
            return SingleChildScrollView(
              padding: const EdgeInsets.only(top: 14, bottom: 8),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: g.gap,
                runSpacing: g.gap,
                children: [
                  for (var i = 0; i < o.length; i++)
                    _marketCard(i, o.length, o[i], g, c.maxWidth,
                        c.maxHeight, remain),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: EmbunButton(
            label: selected == null
                ? 'Pilih kartu untuk dibeli'
                : 'Beli ${_cardName(selected!)} (${_price(selected!)})',
            icon: selected != null &&
                widget.defs[selected]?['side'] == 'antagonis'
                ? 'bulirhitam'
                : 'bulirembun',
            expand: true,
            onPressed: busy || selected == null ? null : _buy,
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
              GameIcon('info', size: 26),
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
              icon: 'barter', trailing: '${inc.length}'),
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
                  MedallionButton(
                    icon: 'silang',
                    label: 'Tolak',
                    size: 44,
                    onTap: busy
                        ? null
                        : () => _run(() =>
                        widget.repo.respondTrade(t['id'] as String, false)),
                  ),
                  const SizedBox(width: 8),
                  MedallionButton(
                    icon: 'centang',
                    label: 'Terima',
                    size: 44,
                    onTap: busy ? null : () => _accept(t),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
        ],
        if (out.isNotEmpty) ...[
          _section('Menunggu jawaban', icon: 'wait'),
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
        _section('Kabar desa', icon: 'announcement'),
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
                  GameIcon(e['kind'] == 'give' ? 'bulirembun' : 'barter',
                      size: 24),
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
          child: EmbunButton(
            label: ready
                ? 'Menunggu... ${widget.readyCount}/${widget.total} siap'
                : 'Akhiri hari ${widget.day}',
            icon: ready ? 'wait' : 'endday',
            expand: true,
            onPressed: ready || busy
                ? null
                : () => _run(() => widget.repo.finishDay(widget.gameId)),
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

  /// Bilah bawah untuk ponsel: tiga tab (ikon di atas label) dan tombol
  /// "Akhiri hari" ringkas di satu baris, mudah dijangkau ibu jari.
  Widget _bottomBar() {
    final n = _incoming.length;
    final ready = widget.iAmReady;
    final progress =
    widget.total == 0 ? 0.0 : (widget.readyCount / widget.total);

    Widget item(int i, String icon, String label, {int badge = 0}) {
      final sel = tab == i;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => tab = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: sel
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Badge(
                  isLabelVisible: badge > 0,
                  label: Text('$badge'),
                  child: Opacity(
                      opacity: sel ? 1 : 0.6,
                      child: GameIcon(icon, size: 32)),
                ),
                const SizedBox(height: 2),
                Text(label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      color: sel ? Colors.white : Colors.white70,
                    )),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              item(0, 'mydeck2', 'Meja'),
              item(1, 'store', 'Pasar'),
              item(2, 'announcement', 'Balai', badge: n),
              const SizedBox(width: 6),
              SizedBox(
                width: 104,
                child: FilledButton(
                  onPressed: ready || busy
                      ? null
                      : () => _run(() => widget.repo.finishDay(widget.gameId)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 8),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GameIcon(ready ? 'wait' : 'endday', size: 24),
                      const SizedBox(height: 2),
                      Text(
                        ready
                            ? '${widget.readyCount}/${widget.total} siap'
                            : 'Akhiri hari ${widget.day}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, height: 1.1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (ready)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _c(progress),
                minHeight: 3,
              ),
            ),
          ),
      ],
    );
  }

  Widget _fadeLayout(Widget? current, List<Widget> previous) => Stack(
    fit: StackFit.expand,
    children: [...previous, ?current],
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      // Lebar panel (bukan layar): sempit = ponsel.
      final narrow = box.maxWidth < 560;
      final Widget content = switch (tab) {
        0 => _mejaTab(),
        1 => _pasarTab(),
        _ => _balaiTab(),
      };
      final body = AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        layoutBuilder: _fadeLayout,
        child: KeyedSubtree(key: ValueKey(tab), child: content),
      );

      if (narrow) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_kabarHidden) _kabar(compact: true),
            Expanded(child: body),
            const SizedBox(height: 8),
            _bottomBar(),
          ],
        );
      }
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
    });
  }
}