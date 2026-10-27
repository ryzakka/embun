import 'dart:async';
import 'dart:math' show sin, pi, min;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'card_tile.dart';
import 'flip_card.dart';

double _c(double v) => v.clamp(0.0, 1.0).toDouble();

/// Tiga susunan layar, dipilih dari ruang yang diberikan induk (bukan ukuran
/// layar), jadi tetap benar di jendela desktop, tablet, dan ponsel diputar:
///
/// * [phone]     panggung pasar penuh + bilah navigasi di bawah. Meja dan
///               Balai naik sebagai panel di atas panggung.
/// * [landscape] panggung di kiri, dok aksi (beli, meja, balai, akhiri hari)
///               di kanan. Untuk layar pendek.
/// * [wide]      panggung pasar + baki kartu di bawahnya, Balai Desa dan
///               tombol akhiri hari di panel kanan.
enum _Mode { phone, landscape, wide }

_Mode _modeFor(BoxConstraints c) {
  final w = c.maxWidth, h = c.maxHeight;
  if (h < 430) return w >= 520 ? _Mode.landscape : _Mode.phone;
  if (w >= 760) return _Mode.wide;
  return _Mode.phone;
}

enum _Panel { none, meja, balai }

/// Ukuran kartu dan jumlah kolom untuk grid kartu di Meja.
class _Grid {
  final int cols;
  final double w;
  final double gap;
  const _Grid(this.cols, this.w, this.gap);
}

_Grid _metrics(double aw) {
  const gap = 10.0;
  const minW = 96.0;
  const maxW = 140.0;
  var cols = ((aw + gap) / (minW + gap)).floor();
  if (cols < 2) cols = 2;
  var w = (aw - (cols - 1) * gap) / cols;
  if (w > maxW) w = maxW;
  return _Grid(cols, w.floorToDouble(), gap);
}

/// Layar hari biasa: Pasar (panggung kartu belanja), Meja (kartumu), Balai
/// (kabar, pemberian, tawaran tukar). Tetap hidup setelah pemain menekan
/// "Akhiri hari", jadi tidak ada layar tunggu yang kosong.
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

  /// Peran gelap yang sedang tampil (bukan samaran): harga ditandai
  /// bulir hitam, bukan tetes embun.
  final bool dark;

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
    this.dark = false,
  });

  @override
  State<DayView> createState() => _DayViewState();
}

class _DayViewState extends State<DayView> {
  _Panel panel = _Panel.none;
  int focus = 0; // kartu pasar yang sedang di tengah panggung
  List<Map<String, dynamic>>? offers;
  bool busy = false;

  // Pembukaan pasar: kartu dibagikan sebagai punggung, lalu berbalik. Hanya
  // diputar sekali per hari; kembali ke Pasar langsung menampilkan muka.
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
    final left = 1 + widget.extraBuy - bought;
    return left < 0 ? 0 : left;
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

  /// Alasan kartu belum bisa dibeli; null bila bisa.
  String? _blockReason(Map<String, dynamic> offer, int price) {
    if (offer['bought'] == true) return 'Sudah kamu beli';
    if (widget.jailed) return 'Kamu dikurung hari ini';
    if (_remaining <= 0) return 'Jatah belanja habis';
    if (price > widget.balance) {
      final lack = _fmt(price - widget.balance);
      return widget.dark ? 'Bulir hitam kurang $lack' : 'Embun kurang $lack';
    }
    return null;
  }

  Future<void> _buy() async {
    final o = offers;
    if (o == null || o.isEmpty) return;
    final id = o[focus.clamp(0, o.length - 1).toInt()]['card_id'] as String;
    await _run(() async {
      await widget.repo.buyCard(widget.gameId, id);
      HapticFeedback.mediumImpact();
      await _loadOffers();
    }, ok: '${_cardName(id)} masuk ke mejamu');
  }

  Future<void> _endDay() =>
      _run(() => widget.repo.finishDay(widget.gameId));

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

  void _togglePanel(_Panel p) =>
      setState(() => panel = panel == p ? _Panel.none : p);

  // ====================== bahan dasar ======================

  BoxDecoration _glassDeco({double radius = 16}) => BoxDecoration(
    color: Colors.black.withValues(alpha: 0.32),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
        color: EmbunColors.goldDim.withValues(alpha: 0.4), width: 1.2),
  );

  /// Kartu kaca untuk satu panel (layar lebar).
  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: _glassDeco(radius: 18),
    child: child,
  );

  Widget _fadeLayout(Widget? current, List<Widget> previous) => Stack(
    fit: StackFit.expand,
    children: [...previous, ?current],
  );

  Widget _section(String title, {String? icon, String? trailing}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        if (icon != null) ...[
          GameIcon(icon, size: 26),
          const SizedBox(width: 6),
        ],
        Text(title,
            style:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
      padding: const EdgeInsets.fromLTRB(3, 2, 9, 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameIcon(icon, size: 22),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: c)),
        ],
      ),
    );
  }

  Widget _empty(String icon, String title, String hint) => Center(
    child: Padding(
      padding: const EdgeInsets.all(12),
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
    ),
  );

  /// Klik kanan (desktop) membuka detail kartu, setara tekan-tahan di ponsel.
  Widget _preview(Map<String, dynamic>? def, Widget child) => def == null
      ? child
      : GestureDetector(
    onSecondaryTap: () => showCardPreview(context, def),
    child: child,
  );

  Widget _readyBar() {
    final progress = widget.total == 0 ? 0.0 : widget.readyCount / widget.total;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(value: _c(progress), minHeight: 4),
      ),
    );
  }

  // ====================== Kabar Pagi ======================

  /// Fajar menyingsing: spanduk meluncur turun, ikon bergema, cahaya
  /// menyapu dari kiri ke kanan lalu meredup.
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
          opacity: _c(rise),
          child: Transform.translate(
            offset: Offset(0, (1 - rise) * -18),
            child: Container(
              width: double.infinity,
              margin: EdgeInsets.only(bottom: compact ? 6 : 10),
              padding: EdgeInsets.fromLTRB(
                  compact ? 6 : 8, compact ? 3 : 6, compact ? 8 : 12, compact ? 3 : 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF332B10),
                    mid,
                    const Color(0xFF332B10),
                  ],
                  stops: [
                    _c(sweep - 0.25),
                    sweep,
                    _c(sweep + 0.25),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: EmbunColors.gold.withValues(alpha: 0.7)),
                boxShadow: [
                  BoxShadow(
                    color: EmbunColors.gold
                        .withValues(alpha: _c(glow * 0.6)),
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
                      child: GameIcon('announcement', size: compact ? 28 : 34),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Kabar Pagi: $text',
                        maxLines: compact ? 2 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12)),
                  ),
                  if (compact)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _kabarHidden = true),
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(8, 6, 2, 6),
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

  // ====================== Pasar: papan, kartu, panel beli ======================

  Widget _statusChips() {
    final mod = widget.priceMod;
    final remain = _remaining;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.jailed)
          _chip('lock', 'Dikurung', color: EmbunColors.blood)
        else
          _chip('item', 'Jatah $remain',
              color: remain > 0 ? Colors.white70 : Colors.white38),
        if (mod != 0) ...[
          const SizedBox(width: 6),
          _chip(mod > 0 ? 'plus' : 'minus', 'Harga ${mod > 0 ? '+' : ''}$mod',
              color: mod < 0 ? Colors.greenAccent : Colors.orangeAccent),
        ],
      ],
    );
  }

  /// Papan pasar: jatuh dari atas, berayun mereda, cahaya menyapu. Memuat
  /// juga jatah belanja dan perubahan harga, jadi tidak perlu baris chip lagi.
  Widget _marketSign() => TweenAnimationBuilder<double>(
    // Setelah pasar pernah dibuka hari ini, papan langsung tampil tenang.
    tween: Tween<double>(begin: _marketOpened ? 1.0 : 0.0, end: 1.0),
    duration: const Duration(milliseconds: 1500),
    builder: (context, t, _) {
      final drop = Curves.easeOutCubic.transform(_c(t / 0.4));
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
              padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF3A2E12),
                    mid,
                    const Color(0xFF3A2E12)
                  ],
                  stops: [_c(sweep - 0.25), sweep, _c(sweep + 0.25)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: EmbunColors.gold.withValues(alpha: 0.6)),
                boxShadow: [
                  BoxShadow(
                    color: EmbunColors.gold
                        .withValues(alpha: 0.25 * (1 - t) + 0.05),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const GameIcon('store', size: 30),
                  const SizedBox(width: 8),
                  const Text('Pasar Pagi',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                          color: EmbunColors.gold)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: _statusChips(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  /// Cap "DIBELI" menghantam kartu yang sudah dibeli.
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

  Widget _marketCard({
    required int i,
    required int n,
    required Map<String, dynamic> offer,
    required double w,
    required double h,
    required double extent,
    required int dealtCount,
  }) {
    final id = offer['card_id'] as String;
    final price = _price(id);
    final bought = offer['bought'] == true;
    final focused = i == focus;
    final canBuy = _blockReason(offer, price) == null;
    final def = widget.defs[id];
    final bad = def?['side'] == 'antagonis';

    final tile = CardTile(
      def: def,
      fallbackName: id,
      width: w,
      showCost: true,
      costOverride: price,
      badge: bought ? 'Terbeli' : null,
      selected: focused && canBuy,
      dim: !canBuy && !focused,
    );
    final front = Stack(
      clipBehavior: Clip.none,
      children: [
        _preview(def, tile),
        if (bought)
          Positioned.fill(child: IgnorePointer(child: _boughtStamp())),
      ],
    );

    return FlipCard(
      key: ValueKey('offer$i-$id'),
      index: i,
      width: w,
      height: h,
      revealed: _marketOpened,
      animate: !_marketOpened,
      dark: bad,
      glow: bad ? EmbunColors.mist : const Color(0xFFFFD866),
      // Tumpukan ada di tengah panggung; tiap kartu dibagikan ke tempatnya.
      dealOffset: Offset(-(i - focus) * extent, 0),
      suspense: n > 2 && i == dealtCount - 1,
      front: front,
    );
  }

  Widget _carouselArea({bool arrows = false}) {
    final o = offers;
    if (o == null) return const EmbunLoading();
    if (o.isEmpty) {
      return _empty('store', 'Pasar sedang sepi', 'Belum ada tawaran hari ini.');
    }
    return LayoutBuilder(builder: (context, c) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _armMarket());
      // Sisakan ruang untuk titik halaman (14) dan kartu terangkat (12).
      final availH = c.maxHeight - 14 - 12;
      var w = availH * 7 / 9;
      final maxW = min(220.0, c.maxWidth * 0.6);
      if (w > maxW) w = maxW;
      if (w < 84) w = 84;
      w = w.floorToDouble();
      final h = w * 9 / 7;
      final extent = w + 14;
      final dealt = (c.maxWidth / extent).ceil().clamp(1, o.length).toInt();
      final f = focus.clamp(0, o.length - 1).toInt();
      return _MarketCarousel(
        key: ValueKey('mc${extent.round()}-${c.maxWidth.round()}-${o.length}'),
        count: o.length,
        initialPage: f,
        viewW: c.maxWidth,
        extent: extent,
        arrows: arrows,
        onFocus: (i) {
          HapticFeedback.selectionClick();
          setState(() => focus = i);
        },
        onTapFocused: (i) {
          final def = widget.defs[o[i]['card_id']];
          if (def != null) showCardPreview(context, def);
        },
        itemBuilder: (i) => _marketCard(
          i: i,
          n: o.length,
          offer: o[i],
          w: w,
          h: h,
          extent: extent,
          dealtCount: dealt,
        ),
      );
    });
  }

  /// Panel beli di bawah panggung: nama, jenis, harga, deskripsi, dan tombol.
  /// Bila tidak bisa dibeli, tombolnya sendiri menyebut alasannya.
  Widget _buyPanel({required bool desc, bool inline = false}) {
    final o = offers;
    if (o == null || o.isEmpty) return const SizedBox.shrink();
    final i = focus.clamp(0, o.length - 1).toInt();
    final offer = o[i];
    final id = offer['card_id'] as String;
    final def = widget.defs[id];
    final bad = def?['side'] == 'antagonis';
    final price = _price(id);
    final reason = _blockReason(offer, price);
    final can = reason == null && !busy;
    final accent = bad ? EmbunColors.mist : EmbunColors.gold;
    final afford = price <= widget.balance;
    final description = '${def?['description'] ?? ''}';

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_cardName(id),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
                color: accent)),
        const SizedBox(height: 2),
        Row(
          children: [
            GameIcon(kindIcon[def?['kind']] ?? 'item', size: 20),
            const SizedBox(width: 4),
            Flexible(
              child: Text(kindLabel[def?['kind']] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.white60)),
            ),
          ],
        ),
      ],
    );

    final pricePill = Container(
      padding: const EdgeInsets.fromLTRB(3, 2, 10, 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: (afford ? EmbunColors.gold : EmbunColors.blood)
                .withValues(alpha: 0.75)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameIcon(bad ? 'bulirhitam' : 'bulirembun', size: 26),
          const SizedBox(width: 4),
          Text('$price',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: afford ? EmbunColors.gold : EmbunColors.blood)),
        ],
      ),
    );

    final descText = !desc
        ? null
        : GestureDetector(
      onTap: def == null ? null : () => showCardPreview(context, def),
      child: Text(description,
          maxLines: inline ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 12, height: 1.3, color: Colors.white70)),
    );

    final button = EmbunButton(
      label: reason ?? 'Beli kartu ini',
      icon: bad ? 'bulirhitam' : 'bulirembun',
      expand: true,
      height: inline ? 50 : 46,
      onPressed: can ? _buy : null,
    );

    // Bagian teks berganti halus saat kartu fokus berpindah.
    Widget swap(Widget child) => AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      layoutBuilder: (cur, prev) => Stack(
        alignment: Alignment.topLeft,
        children: [...prev, ?cur],
      ),
      child: KeyedSubtree(key: ValueKey('$i-$id'), child: child),
    );

    final deco = BoxDecoration(
      color: Colors.black.withValues(alpha: 0.38),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.2),
    );

    if (inline) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        decoration: deco,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: swap(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  title,
                  if (descText != null) ...[
                    const SizedBox(height: 6),
                    descText,
                  ],
                ],
              )),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 232,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(alignment: Alignment.centerRight, child: pricePill),
                  const SizedBox(height: 8),
                  button,
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: deco,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: swap(title)),
              const SizedBox(width: 8),
              pricePill,
            ],
          ),
          if (descText != null) ...[
            const SizedBox(height: 6),
            swap(descText),
          ],
          const SizedBox(height: 8),
          button,
        ],
      ),
    );
  }

  /// Panggung: papan pasar, carousel kartu, dan (opsional) panel beli.
  Widget _stage({
    required bool buy,
    bool inline = false,
    bool desc = true,
    bool arrows = false,
  }) {
    final o = offers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _marketSign(),
        const SizedBox(height: 4),
        Expanded(child: _carouselArea(arrows: arrows)),
        if (buy && o != null && o.isNotEmpty) ...[
          const SizedBox(height: 6),
          _buyPanel(desc: desc, inline: inline),
        ],
      ],
    );
  }

  // ====================== Meja (kartumu) ======================

  Widget _mejaBody() {
    final hand = widget.hand;
    if (hand.isEmpty) {
      return _empty('mydeck2', 'Mejamu masih kosong',
          'Beli kartu di Pasar untuk dipersembahkan.');
    }
    return LayoutBuilder(builder: (context, box) {
      final g = _metrics(box.maxWidth);
      return SingleChildScrollView(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Column(
          children: [
            const Text('Tekan lama kartu untuk membaca efeknya.',
                style: TextStyle(fontSize: 11, color: Colors.white38)),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: g.gap,
              runSpacing: g.gap,
              children: [
                for (final h in hand)
                  _preview(
                    widget.defs[h['card_id']],
                    CardTile(
                      def: widget.defs[h['card_id']],
                      fallbackName: h['card_id'] as String,
                      width: g.w,
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    });
  }

  /// Baki kartu di bawah panggung (layar lebar): kartumu berjajar seperti
  /// kartu di tangan.
  Widget _tray(double height) {
    final hand = widget.hand;
    return SizedBox(
      height: height,
      child: _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const GameIcon('mydeck2', size: 26),
                const SizedBox(width: 8),
                const Text('Mejamu',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                        color: EmbunColors.gold)),
                const Spacer(),
                Text('${hand.length} kartu',
                    style:
                    const TextStyle(fontSize: 11, color: Colors.white54)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: hand.isEmpty
                  ? const Center(
                child: Text(
                    'Beli kartu di Pasar untuk dipersembahkan.',
                    style: TextStyle(fontSize: 12, color: Colors.white38)),
              )
                  : LayoutBuilder(builder: (context, c) {
                final h = (c.maxHeight - 6).clamp(80.0, 400.0).toDouble();
                final w = (h * 7 / 9).floorToDouble();
                return Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final cardRow in hand)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: _preview(
                              widget.defs[cardRow['card_id']],
                              CardTile(
                                def: widget.defs[cardRow['card_id']],
                                fallbackName: cardRow['card_id'] as String,
                                width: w,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ====================== Balai ======================

  Widget _tradeCard(Map<String, dynamic> t) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
    decoration: BoxDecoration(
      color: Colors.black38,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: EmbunColors.gold.withValues(alpha: 0.45)),
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
                style:
                const TextStyle(fontSize: 11, color: Colors.white60),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
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
  );

  Widget _feedRow(Map<String, dynamic> e) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        GameIcon(e['kind'] == 'give' ? 'bulirembun' : 'barter', size: 26),
        const SizedBox(width: 8),
        Expanded(
          child: Text(e['text'] as String,
              style: const TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 8),
        Text('H${e['day']}',
            style: const TextStyle(fontSize: 10, color: Colors.white38)),
      ],
    ),
  );

  Widget _hintCard() => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Row(
      children: [
        GameIcon('info', size: 28),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Ketuk avatar pemain di atas untuk memberi embun, menukar '
                'kartu, atau mengirim isyarat. Tekan lama (atau klik kanan) '
                'sebuah kartu untuk membaca efeknya.',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
        ),
      ],
    ),
  );

  Widget _balaiBody({bool kabar = false}) {
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
        if (kabar && !_kabarHidden) _kabar(compact: true),
        if (inc.isNotEmpty) ...[
          _section('Tawaran tukar untukmu',
              icon: 'barter', trailing: '${inc.length}'),
          for (final t in inc) _tradeCard(t),
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
          for (final e in feed) _feedRow(e),
        const SizedBox(height: 10),
        _hintCard(),
      ],
    );
  }

  /// Balai Desa sebagai panel tetap di kanan (layar lebar), dengan tombol
  /// akhiri hari di dasarnya.
  Widget _balaiCard() {
    final n = _incoming.length;
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            icon: 'announcement',
            title: 'Balai Desa',
            iconSize: 28,
            trailing: n == 0
                ? null
                : _chip('barter', '$n tawaran', color: EmbunColors.gold),
          ),
          const SizedBox(height: 8),
          Expanded(child: _balaiBody()),
          const SizedBox(height: 10),
          _endButton(height: 52),
        ],
      ),
    );
  }

  // ====================== navigasi & akhiri hari ======================

  /// Tombol akhiri hari. Menonjol (hijau) begitu tidak ada lagi yang bisa
  /// dibeli; selain itu tampil tenang supaya tidak tertekan tak sengaja.
  Widget _endButton({double height = 48}) {
    final ready = widget.iAmReady;
    final nothingLeft = _remaining == 0 || widget.jailed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EmbunButton(
          label: ready
              ? 'Siap ${widget.readyCount}/${widget.total}'
              : 'Akhiri hari',
          icon: ready ? 'wait' : 'endday',
          expand: true,
          height: height,
          kind: (ready || !nothingLeft)
              ? EmbunButtonKind.secondary
              : EmbunButtonKind.primary,
          onPressed: ready || busy ? null : _endDay,
        ),
        if (ready) _readyBar(),
      ],
    );
  }

  Widget _navButton({
    required String icon,
    required String label,
    required bool sel,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: sel
              ? EmbunColors.gold.withValues(alpha: 0.16)
              : Colors.black.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: sel
                ? EmbunColors.gold.withValues(alpha: 0.7)
                : EmbunColors.goldDim.withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              child: Opacity(
                  opacity: sel ? 1 : 0.8, child: GameIcon(icon, size: 26)),
            ),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  color: sel ? EmbunColors.cream : Colors.white70,
                )),
          ],
        ),
      ),
    );
  }

  Widget _mejaNav() => _navButton(
    icon: 'mydeck2',
    label: 'Meja · ${widget.hand.length}',
    sel: panel == _Panel.meja,
    onTap: () => _togglePanel(_Panel.meja),
  );

  Widget _balaiNav() => _navButton(
    icon: 'announcement',
    label: 'Balai',
    sel: panel == _Panel.balai,
    badge: _incoming.length,
    onTap: () => _togglePanel(_Panel.balai),
  );

  /// Bilah bawah ponsel: Meja, Balai, dan Akhiri hari dalam satu baris
  /// yang mudah dijangkau ibu jari.
  Widget _navRow() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 78, child: _mejaNav()),
      const SizedBox(width: 6),
      SizedBox(width: 78, child: _balaiNav()),
      const SizedBox(width: 8),
      Expanded(child: _endButton()),
    ],
  );

  /// Dok kanan untuk layar pendek (ponsel mendatar).
  Widget _sideDock() => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buyPanel(desc: false),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _mejaNav()),
            const SizedBox(width: 8),
            Expanded(child: _balaiNav()),
          ],
        ),
        const SizedBox(height: 8),
        _endButton(height: 46),
      ],
    ),
  );

  // ====================== panel yang naik dari bawah ======================

  /// Meja atau Balai sebagai panel yang menutupi panggung, naik dari bawah.
  /// Berada di dalam pohon widget ini (bukan sheet modal), jadi isinya ikut
  /// hidup saat kartu atau tawaran berubah.
  Widget _overlayHost(Widget base, {required bool kabarInBalai}) {
    return Stack(
      children: [
        Positioned.fill(child: base),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: panel == _Panel.none,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              layoutBuilder: _fadeLayout,
              transitionBuilder: (child, anim) {
                final slide = Tween<Offset>(
                    begin: const Offset(0, 0.06), end: Offset.zero)
                    .animate(CurvedAnimation(
                    parent: anim, curve: Curves.easeOutCubic));
                return FadeTransition(
                  opacity: anim,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: panel == _Panel.none
                  ? const SizedBox.shrink(key: ValueKey('none'))
                  : KeyedSubtree(
                key: ValueKey(panel),
                child: _panelCard(kabarInBalai),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _panelCard(bool kabarInBalai) {
    final meja = panel == _Panel.meja;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 10),
      decoration: BoxDecoration(
        color: EmbunColors.panel.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: EmbunColors.gold.withValues(alpha: 0.55), width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GameIcon(meja ? 'mydeck2' : 'announcement', size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(meja ? 'Kartu di mejamu' : 'Balai Desa',
                    style: const TextStyle(
                        color: EmbunColors.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.8)),
              ),
              if (meja)
                Text('${widget.hand.length} kartu',
                    style:
                    const TextStyle(fontSize: 11, color: Colors.white54)),
              MedallionButton(
                icon: 'silang',
                size: 30,
                onTap: () => setState(() => panel = _Panel.none),
              ),
            ],
          ),
          const Divider(height: 8),
          const SizedBox(height: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: meja ? _mejaBody() : _balaiBody(kabar: kabarInBalai),
            ),
          ),
        ],
      ),
    );
  }

  // ====================== susunan per mode ======================

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      switch (_modeFor(box)) {
        case _Mode.phone:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_kabarHidden) _kabar(compact: true),
              Expanded(
                child: _overlayHost(
                  _stage(buy: true),
                  kabarInBalai: false,
                ),
              ),
              const SizedBox(height: 8),
              _navRow(),
            ],
          );
        case _Mode.landscape:
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _overlayHost(
                  _stage(buy: false),
                  kabarInBalai: true,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(width: 236, child: _sideDock()),
            ],
          );
        case _Mode.wide:
          final trayH = (box.maxHeight * 0.3).clamp(160.0, 220.0).toDouble();
          final sideW = (box.maxWidth * 0.28).clamp(290.0, 360.0).toDouble();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _kabar(),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _card(_stage(
                                buy: true, inline: true, arrows: true)),
                          ),
                          const SizedBox(height: 12),
                          _tray(trayH),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(width: sideW, child: _balaiCard()),
                  ],
                ),
              ),
            ],
          );
      }
    });
  }
}

/// Carousel kartu pasar: kartu di tengah membesar dan terang, tetangganya
/// mengecil dan meredup. Ketuk tetangga untuk menggesernya ke tengah; ketuk
/// kartu tengah untuk membaca detailnya. Controller dibuat per ukuran (lihat
/// key di pemanggil), karena viewportFraction tidak bisa diubah belakangan.
class _MarketCarousel extends StatefulWidget {
  final int count;
  final int initialPage;
  final double viewW;
  final double extent;
  final bool arrows;
  final ValueChanged<int> onFocus;
  final ValueChanged<int> onTapFocused;
  final Widget Function(int i) itemBuilder;

  const _MarketCarousel({
    super.key,
    required this.count,
    required this.initialPage,
    required this.viewW,
    required this.extent,
    required this.arrows,
    required this.onFocus,
    required this.onTapFocused,
    required this.itemBuilder,
  });

  @override
  State<_MarketCarousel> createState() => _MarketCarouselState();
}

class _MarketCarouselState extends State<_MarketCarousel> {
  late final PageController _pc = PageController(
    viewportFraction: (widget.extent / widget.viewW).clamp(0.2, 1.0).toDouble(),
    initialPage: widget.initialPage,
  );
  late int _cur = widget.initialPage;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  double _page() => (_pc.hasClients && _pc.position.haveDimensions)
      ? (_pc.page ?? _cur.toDouble())
      : _cur.toDouble();

  void _go(int i) => _pc.animateToPage(
    i.clamp(0, widget.count - 1).toInt(),
    duration: const Duration(milliseconds: 320),
    curve: Curves.easeOutCubic,
  );

  Widget _arrow(bool left) {
    final enabled = left ? _cur > 0 : _cur < widget.count - 1;
    return Positioned(
      left: left ? 0 : null,
      right: left ? null : 0,
      top: 0,
      bottom: 0,
      child: Center(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: enabled ? 1 : 0.25,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? () => _go(_cur + (left ? -1 : 1)) : null,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black54,
                border: Border.all(
                    color: EmbunColors.gold.withValues(alpha: 0.7)),
              ),
              child: Icon(
                left ? Icons.chevron_left : Icons.chevron_right,
                color: EmbunColors.gold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final behavior = ScrollConfiguration.of(context).copyWith(
      dragDevices: {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      },
    );
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              ScrollConfiguration(
                behavior: behavior,
                child: PageView.builder(
                  controller: _pc,
                  clipBehavior: Clip.none,
                  itemCount: widget.count,
                  onPageChanged: (i) {
                    setState(() => _cur = i);
                    widget.onFocus(i);
                  },
                  itemBuilder: (_, i) => AnimatedBuilder(
                    animation: _pc,
                    builder: (_, child) {
                      final d = (_page() - i).abs().clamp(0.0, 1.0).toDouble();
                      return Opacity(
                        opacity: 1 - 0.4 * d,
                        child: Transform.scale(scale: 1 - 0.15 * d, child: child),
                      );
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () =>
                      i == _cur ? widget.onTapFocused(i) : _go(i),
                      child: Center(child: widget.itemBuilder(i)),
                    ),
                  ),
                ),
              ),
              if (widget.arrows && widget.count > 1) ...[
                _arrow(true),
                _arrow(false),
              ],
            ],
          ),
        ),
        SizedBox(
          height: 14,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.count > 1)
                for (var i = 0; i < widget.count; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: i == _cur ? 18 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: i == _cur
                          ? EmbunColors.gold
                          : Colors.white24,
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}