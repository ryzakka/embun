import 'dart:async';
import 'dart:math' show sin, pi;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'card_tile.dart';
import 'flip_card.dart';
import 'package:flutter/foundation.dart';

double _c(double v) => v.clamp(0.0, 1.0).toDouble();

const _tabToko = 0;
const _tabBalai = 2;

/// Tiga susunan layar, dipilih dari ruang yang diberikan induk (bukan ukuran
/// layar), jadi tetap benar di jendela desktop, tablet, dan ponsel diputar:
///
/// * [phone]     tiga layar terpisah (Toko, Meja, Balai) yang digeser
///               kiri-kanan, dengan dok navigasi di bawah.
/// * [landscape] sama, tetapi navigasi berupa rel di kiri (layar pendek).
/// * [wide]      satu layar: Toko sebagai panggung utama di kiri; Meja,
///               Balai, dan "Akhiri hari" bertumpuk di rel kanan.
enum _Mode { phone, landscape, wide }

_Mode _modeFor(BoxConstraints c) {
  final w = c.maxWidth, h = c.maxHeight;
  if (h < 430) return w >= 520 ? _Mode.landscape : _Mode.phone;
  if (w >= 760) return _Mode.wide;
  return _Mode.phone;
}

/// Ukuran kartu dan jumlah kolom.
class _Grid {
  final int cols;
  final double w;
  final double gap;
  const _Grid(this.cols, this.w, this.gap);
  double get h => w * 9 / 7;
}

/// Grid kartu Meja berdasarkan lebar yang tersedia.
_Grid _mejaGrid(double aw, double minW) {
  const gap = 10.0;
  const maxW = 140.0;
  var cols = ((aw + gap) / (minW + gap)).floor();
  if (cols < 2) cols = 2;
  var w = (aw - (cols - 1) * gap) / cols;
  if (w > maxW) w = maxW;
  return _Grid(cols, w.floorToDouble(), gap);
}

/// Layar hari biasa: Toko (belanja), Meja (kartumu), Balai (kabar, pemberian,
/// tawaran tukar). Tetap hidup setelah pemain menekan "Akhiri hari", jadi
/// tidak ada lagi layar tunggu yang kosong.
class DayView extends StatefulWidget {
  final GameRepository repo;
  final String gameId;
  final int day;
  final int priceMod;
  final int extraBuy;

  /// Naik tiap kali pasar perlu dimuat ulang dari luar (mis. Pedagang Ulung).
  final ValueListenable<int>? marketTick;
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
    this.marketTick,
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
  final PageController _pager = PageController();
  int tab = _tabToko;
  int sel = 0; // indeks kartu toko yang dipilih
  List<Map<String, dynamic>>? offers;
  bool busy = false;

  // Pembukaan toko: kartu dibagikan sebagai punggung, lalu berbalik. Hanya
  // diputar sekali per hari; kembali ke Toko langsung menampilkan muka.
  bool _marketOpened = false;
  Timer? _openTimer;
  Timer? _kabarTimer;
  bool _kabarHidden = false;

  @override
  void initState() {
    super.initState();
    _loadOffers();
    widget.marketTick?.addListener(_loadOffers);
    // Banner Kabar Pagi di layar Toko menyingkir sendiri supaya kartu lega;
    // isinya tetap bisa dibaca di Balai.
    _kabarTimer = Timer(const Duration(seconds: 9), () {
      if (mounted) setState(() => _kabarHidden = true);
    });
  }

  @override
  void dispose() {
    widget.marketTick?.removeListener(_loadOffers);
    _openTimer?.cancel();
    _kabarTimer?.cancel();
    _pager.dispose();
    super.dispose();
  }

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
    // Kartu bonus Pedagang Ulung tidak memakai jatah belanja.
    final bought = (offers ?? [])
        .where((o) => o['bought'] == true && o['bonus'] != true)
        .length;
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
    if (widget.jailed) return 'Dikurung sampai musyawarah berikutnya';
    if (_remaining <= 0) return 'Jatah belanja habis';
    if (price > widget.balance) {
      final lack = _fmt(price - widget.balance);
      return widget.dark ? 'Bulir hitam kurang $lack' : 'Embun kurang $lack';
    }
    return null;
  }

  Future<void> _endDay() =>
      _run(() => widget.repo.finishDay(widget.gameId));

  Future<void> _accept(Map<String, dynamic> t) async {
    // Terkurung: tidak boleh menyerahkan kartu, jadi hanya menerima.
    if (widget.jailed) {
      await _run(
            () => widget.repo.respondTrade(t['id'] as String, true),
        ok: 'Kartu diterima',
      );
      return;
    }
    final tradable =
    widget.hand
        .where((h) =>
    h['card_id'] != 'embun_samaran' && h['card_id'] != 'kunci_segel')
        .toList();
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

  void _goTab(int i) {
    if (i == tab) return;
    setState(() => tab = i);
    if (!_pager.hasClients) return;
    if ((i - (_pager.page ?? tab.toDouble())).abs() > 1.5) {
      _pager.jumpToPage(i);
    } else {
      _pager.animateToPage(i,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic);
    }
  }

  // ====================== bahan dasar ======================

  BoxDecoration _glassDeco({double radius = 16}) => BoxDecoration(
    color: Colors.black.withValues(alpha: 0.32),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
        color: EmbunColors.goldDim.withValues(alpha: 0.4), width: 1.2),
  );

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: _glassDeco(radius: 18),
    child: child,
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

  Widget _progress({double height = 4}) {
    final p = widget.total == 0 ? 0.0 : widget.readyCount / widget.total;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(value: _c(p), minHeight: height),
    );
  }

  /// Judul layar: ikon medali, judul emas, keterangan di kanan.
  Widget _pageHeader(String icon, String title, {String? trailing}) =>
      SectionHeader(
        icon: icon,
        title: title,
        iconSize: 28,
        trailing: trailing == null
            ? null
            : Text(trailing,
            style: const TextStyle(fontSize: 12, color: Colors.white60)),
      );

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
                  compact ? 6 : 10, compact ? 3 : 6, compact ? 8 : 14, compact ? 3 : 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF332B10),
                    mid,
                    const Color(0xFF332B10),
                  ],
                  stops: [_c(sweep - 0.25), sweep, _c(sweep + 0.25)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: EmbunColors.gold.withValues(alpha: 0.7)),
                boxShadow: [
                  BoxShadow(
                    color: EmbunColors.gold.withValues(alpha: _c(glow * 0.6)),
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
                      child: GameIcon('announcement', size: compact ? 28 : 36),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Kabar Pagi: $text',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: compact ? 12 : 13)),
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

  // ====================== Toko ======================

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


  // ====================== Pasar Pagi (gaya Secret Shop) ======================

  Future<void> _buyOffer(String id) => _run(() async {
    await widget.repo.buyCard(widget.gameId, id);
    HapticFeedback.mediumImpact();
    await _loadOffers();
  }, ok: '${_cardName(id)} masuk ke mejamu');

  /// Hitungan saldo berbentuk pil emas di pojok kanan atas panel.
  Widget _balancePill({double size = 30}) => Container(
    padding: const EdgeInsets.fromLTRB(4, 2, 12, 2),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: EmbunColors.gold.withValues(alpha: 0.8)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameIcon(widget.dark ? 'bulirhitam' : 'bulirembun', size: size),
        const SizedBox(width: 4),
        Text(_fmt(widget.balance),
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: EmbunColors.gold)),
      ],
    ),
  );

  /// Satu kolom toko: nama di atas, kartu, tombol Beli, harga di bawahnya.
  Widget _shopCol(int i, int n, Map<String, dynamic> offer, double w,
      double gap) {
    final id = offer['card_id'] as String;
    final def = widget.defs[id];
    final bad = def?['side'] == 'antagonis';
    final price = _price(id);
    final bought = offer['bought'] == true;
    final reason = _blockReason(offer, price);
    final can = reason == null && !busy;
    final afford = price <= widget.balance;
    final accent = bad ? EmbunColors.mist : EmbunColors.gold;
    final h = w * 9 / 7;

    final tile = CardTile(
      def: def,
      fallbackName: id,
      width: w,
      badge: bought ? 'Terbeli' : null,
      selected: i == sel,
      dim: reason != null && !bought && i != sel,
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => sel = i);
      },
    );
    final front = Stack(
      clipBehavior: Clip.none,
      children: [
        _preview(def, tile),
        if (bought) Positioned.fill(child: IgnorePointer(child: _boughtStamp())),
      ],
    );

    // Kartu dibagikan dari tengah deretan.
    final dealX = ((n - 1) / 2 - i) * (w + gap);

    return SizedBox(
      width: w,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 22,
            child: Center(
              child: Text(_cardName(id),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                      color: accent)),
            ),
          ),
          const SizedBox(height: 6),
          FlipCard(
            key: ValueKey('offer$i-$id'),
            index: i,
            width: w,
            height: h,
            revealed: _marketOpened,
            animate: !_marketOpened,
            dark: bad,
            glow: bad ? EmbunColors.mist : const Color(0xFFFFD866),
            dealOffset: Offset(dealX, 0),
            suspense: n > 2 && i == n - 1,
            front: front,
          ),
          const SizedBox(height: 8),
          EmbunButton(
            label: bought ? 'Terbeli' : 'Beli',
            expand: true,
            height: 38,
            kind: can ? EmbunButtonKind.primary : EmbunButtonKind.secondary,
            onPressed: can ? () => _buyOffer(id) : null,
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GameIcon(bad ? 'bulirhitam' : 'bulirembun', size: 22),
                const SizedBox(width: 3),
                Text('$price',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: afford ? EmbunColors.gold : EmbunColors.blood)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shopColumns() {
    final o = offers;
    if (o == null) return const EmbunLoading();
    if (o.isEmpty) {
      return _empty('store', 'Toko sedang sepi', 'Belum ada tawaran hari ini.');
    }
    return LayoutBuilder(builder: (context, c) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _armMarket());
      const gap = 12.0;
      const chrome = 22 + 6 + 8 + 38 + 4 + 24 + 12.0;
      final n = o.length;
      var w = (c.maxWidth - 8 - (n - 1) * gap) / n;
      final byH = (c.maxHeight - chrome) * 7 / 9;
      if (byH < w) w = byH;
      w = w.clamp(60.0, 190.0).toDouble().floorToDouble();
      return Center(
        child: SingleChildScrollView(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < n; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                _shopCol(i, n, o[i], w, gap),
              ],
            ],
          ),
        ),
      );
    });
  }

  /// Panel info di samping (seperti panel "Upgrade"): kabar, status, uraian
  /// kartu yang disentuh, dan tombol lewati (akhiri hari).
  Widget _shopInfo() {
    final o = offers;
    Widget desc = const SizedBox.shrink();
    if (o != null && o.isNotEmpty) {
      final i = sel.clamp(0, o.length - 1).toInt();
      final id = o[i]['card_id'] as String;
      final def = widget.defs[id];
      final bad = def?['side'] == 'antagonis';
      final reason = _blockReason(o[i], _price(id));
      desc = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_cardName(id),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: bad ? EmbunColors.mist : EmbunColors.gold)),
          const SizedBox(height: 2),
          Row(
            children: [
              GameIcon(kindIcon[def?['kind']] ?? 'item', size: 20),
              const SizedBox(width: 4),
              Text(kindLabel[def?['kind']] ?? '',
                  style: const TextStyle(fontSize: 11, color: Colors.white60)),
            ],
          ),
          const SizedBox(height: 6),
          Text('${def?['description'] ?? ''}',
              style: const TextStyle(
                  fontSize: 12.5, height: 1.35, color: Colors.white70)),
          if (reason != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(reason,
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: EmbunColors.blood)),
            ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: EmbunColors.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const GameIcon('info', size: 24),
              const SizedBox(width: 6),
              const Text('Keterangan',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: EmbunColors.gold)),
              const Spacer(),
              _statusChips(),
            ],
          ),
          const Divider(height: 16),
          Expanded(child: SingleChildScrollView(child: desc)),
          const SizedBox(height: 8),
          _endButton(height: 46),
          if (widget.iAmReady) ...[
            const SizedBox(height: 6),
            _progress(),
          ],
        ],
      ),
    );
  }

  /// Panel toko: judul + hitungan saldo, tiga kolom kartu, panel info.
  Widget _shopPanel({required bool wide}) => OrnatePanel(
    padding: EdgeInsets.fromLTRB(
        wide ? 20 : 12, wide ? 14 : 10, wide ? 20 : 12, wide ? 16 : 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            GameIcon('store', size: wide ? 38 : 30),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Pasar Pagi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: wide ? 22 : 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: EmbunColors.gold)),
            ),
            _balancePill(size: wide ? 32 : 26),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: wide
              ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _shopColumns()),
              const SizedBox(width: 16),
              SizedBox(width: 240, child: _shopInfo()),
            ],
          )
              : _shopColumns(),
        ),
      ],
    ),
  );

  /// Layar Toko di ponsel / layar pendek.
  Widget _tokoPage({required bool side}) {
    final hasKabar = !_kabarHidden &&
        widget.events
            .any((e) => e['kind'] == 'kabar' && e['day'] == widget.day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasKabar) _kabar(compact: true),
        Expanded(child: _shopPanel(wide: false)),
      ],
    );
  }


  // ====================== Meja ======================

  Widget _mejaBody({double minW = 96}) {
    final hand = widget.hand;
    if (hand.isEmpty) {
      return _empty('mydeck2', 'Mejamu masih kosong',
          'Beli kartu di Toko untuk dipersembahkan.');
    }
    return LayoutBuilder(builder: (context, box) {
      final g = _mejaGrid(box.maxWidth, minW);
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

  Widget _mejaPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _pageHeader('mydeck2', 'Kartu di mejamu',
          trailing: '${widget.hand.length} kartu'),
      const SizedBox(height: 6),
      Expanded(child: _mejaBody()),
    ],
  );

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
              if (widget.jailed) ...[
                const SizedBox(height: 4),
                const Text(
                  'Kamu dikurung: kartu ini diterima tanpa balasan.',
                  style: TextStyle(fontSize: 11, color: EmbunColors.gold),
                ),
              ],
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
        if (kabar) _kabar(),
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

  Widget _balaiPage() {
    final n = _incoming.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pageHeader('announcement', 'Balai Desa',
            trailing: n == 0 ? null : '$n tawaran'),
        const SizedBox(height: 8),
        Expanded(child: _balaiBody(kabar: true)),
      ],
    );
  }

  // ====================== navigasi ======================

  static const _tabIcons = ['store', 'mydeck2', 'announcement'];

  Widget _tab(int i) {
    final labels = ['Toko', 'Meja · ${widget.hand.length}', 'Balai'];
    final on = tab == i;
    final badge = i == _tabBalai ? _incoming.length : 0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _goTab(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: on ? EmbunColors.gold.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: on
                ? EmbunColors.gold.withValues(alpha: 0.65)
                : Colors.transparent,
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
                  opacity: on ? 1 : 0.65,
                  child: GameIcon(_tabIcons[i], size: 25)),
            ),
            Text(labels[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  color: on ? EmbunColors.cream : Colors.white70,
                )),
          ],
        ),
      ),
    );
  }

  /// Tombol akhiri hari. Menonjol (hijau) begitu tidak ada lagi yang bisa
  /// dibeli; selain itu tampil tenang supaya tidak tertekan tak sengaja.
  Widget _endButton({double height = 48, bool short = false}) {
    final ready = widget.iAmReady;
    final nothingLeft = _remaining == 0 || widget.jailed;
    return EmbunButton(
      label: ready
          ? (short ? '${widget.readyCount}/${widget.total}' : 'Menunggu ${widget.readyCount}/${widget.total}')
          : (short ? 'Akhiri' : 'Akhiri hari ${widget.day}'),
      icon: ready ? 'wait' : 'endday',
      expand: true,
      height: height,
      kind: (ready || !nothingLeft)
          ? EmbunButtonKind.secondary
          : EmbunButtonKind.primary,
      onPressed: ready || busy ? null : _endDay,
    );
  }

  /// Dok bawah ponsel: tiga tab dan tombol akhiri hari dalam satu baris.
  Widget _dock() => Container(
    padding: const EdgeInsets.all(6),
    decoration: _glassDeco(radius: 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.iAmReady)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
            child: _progress(height: 3),
          ),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++) Expanded(child: _tab(i)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(flex: 2, child: _endButton(short: true)),
          ],
        ),
      ],
    ),
  );

  /// Rel kiri untuk layar pendek.
  Widget _sideRail() => Container(
    width: 78,
    padding: const EdgeInsets.all(6),
    decoration: _glassDeco(radius: 20),
    child: Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  _tab(i),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
        ),
        MedallionButton(
          icon: widget.iAmReady ? 'wait' : 'endday',
          label: widget.iAmReady
              ? '${widget.readyCount}/${widget.total}'
              : 'Akhiri',
          size: 40,
          onTap: widget.iAmReady || busy ? null : _endDay,
        ),
      ],
    ),
  );

  Widget _pager3({required bool side}) => PageView(
    controller: _pager,
    onPageChanged: (i) => setState(() => tab = i),
    children: [
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: _tokoPage(side: side)),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: _mejaPage()),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: _balaiPage()),
    ],
  );

  // ====================== desktop ======================

  /// Panggung utama: panel Pasar Pagi dengan panel info di sisinya.
  Widget _marketHero() => _shopPanel(wide: true);

  Widget _railPanel({
    required String icon,
    required String title,
    Widget? trailing,
    required Widget child,
  }) =>
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
                icon: icon, title: title, iconSize: 28, trailing: trailing),
            const SizedBox(height: 8),
            Expanded(child: child),
          ],
        ),
      );

  /// Rel kanan: Meja, Balai, lalu tombol akhiri hari yang selalu terlihat.
  Widget _rail() {
    final n = _incoming.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: _railPanel(
            icon: 'mydeck2',
            title: 'Mejamu',
            trailing: Text('${widget.hand.length} kartu',
                style: const TextStyle(fontSize: 12, color: Colors.white60)),
            child: _mejaBody(minW: 84),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          flex: 4,
          child: _railPanel(
            icon: 'announcement',
            title: 'Balai Desa',
            trailing: n == 0
                ? null
                : _chip('barter', '$n tawaran', color: EmbunColors.gold),
            child: _balaiBody(),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: _glassDeco(radius: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _endButton(height: 56),
              if (widget.iAmReady) ...[
                const SizedBox(height: 8),
                _progress(),
              ],
            ],
          ),
        ),
      ],
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
              Expanded(child: _pager3(side: false)),
              const SizedBox(height: 8),
              _dock(),
            ],
          );
        case _Mode.landscape:
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sideRail(),
              const SizedBox(width: 10),
              Expanded(child: _pager3(side: true)),
            ],
          );
        case _Mode.wide:
          final sideW = (box.maxWidth * 0.30).clamp(300.0, 380.0).toDouble();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _kabar(),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _marketHero()),
                    const SizedBox(width: 14),
                    SizedBox(width: sideW, child: _rail()),
                  ],
                ),
              ),
            ],
          );
      }
    });
  }
}