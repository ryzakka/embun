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

/// Kolom tetap (maks. [maxCols]); kartu kecil, sisanya digulir.
_Grid _fixedCols(double aw, int n, double gap, double maxCols, double maxW) {
  final cols = min(n, maxCols.toInt()).clamp(1, 99).toInt();
  var w = (aw - (cols - 1) * gap) / cols;
  if (w > maxW) w = maxW;
  return _Grid(cols, w.floorToDouble(), gap);
}

/// Susunan yang memuat semua [n] kartu dalam ruang [aw] x [ah] dengan kartu
/// sebesar mungkin. Seri dimenangkan susunan dengan kolom lebih banyak
/// (satu baris lebih rapi daripada dua).
_Grid _fit(double aw, double ah, int n,
    {double gap = 14, double minW = 100, double maxW = 210}) {
  var bestCols = 1;
  var bestW = 0.0;
  for (var cols = 1; cols <= n; cols++) {
    final rows = (n / cols).ceil();
    var w = (aw - (cols - 1) * gap) / cols;
    final byH = ((ah - 24 - (rows - 1) * gap) / rows) * 7 / 9;
    if (byH < w) w = byH;
    if (w > maxW) w = maxW;
    if (w >= bestW) {
      bestW = w;
      bestCols = cols;
    }
  }
  if (bestW < minW) {
    bestW = minW;
    bestCols = ((aw + gap) / (minW + gap)).floor().clamp(1, n).toInt();
  }
  return _Grid(bestCols, bestW.floorToDouble(), gap);
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

enum _DetailStyle { bar, plate, column }

/// Layar hari biasa: Toko (belanja), Meja (kartumu), Balai (kabar, pemberian,
/// tawaran tukar). Tetap hidup setelah pemain menekan "Akhiri hari", jadi
/// tidak ada lagi layar tunggu yang kosong.
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
    // Banner Kabar Pagi di layar Toko menyingkir sendiri supaya kartu lega;
    // isinya tetap bisa dibaca di Balai.
    _kabarTimer = Timer(const Duration(seconds: 9), () {
      if (mounted) setState(() => _kabarHidden = true);
    });
  }

  @override
  void dispose() {
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

  void _select(int i) {
    if (i == sel) {
      final o = offers;
      final def = o == null ? null : widget.defs[o[i]['card_id']];
      if (def != null) showCardPreview(context, def);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => sel = i);
  }

  Future<void> _buy() async {
    final o = offers;
    if (o == null || o.isEmpty) return;
    final id = o[sel.clamp(0, o.length - 1).toInt()]['card_id'] as String;
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

  /// Papan toko: jatuh dari atas, berayun mereda, cahaya menyapu. Memuat
  /// jatah belanja dan perubahan harga di sisi kanannya.
  Widget _marketSign({bool big = false}) => TweenAnimationBuilder<double>(
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
              padding: EdgeInsets.fromLTRB(big ? 12 : 6, big ? 6 : 3, big ? 14 : 8, big ? 6 : 3),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF3A2E12),
                    mid,
                    const Color(0xFF3A2E12)
                  ],
                  stops: [_c(sweep - 0.25), sweep, _c(sweep + 0.25)],
                ),
                borderRadius: BorderRadius.circular(big ? 14 : 12),
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
                  GameIcon('store', size: big ? 40 : 30),
                  SizedBox(width: big ? 12 : 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Pasar Pagi',
                          style: TextStyle(
                              fontSize: big ? 21 : 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: big ? 1.2 : 0.6,
                              color: EmbunColors.gold)),
                      if (big)
                        const Text('Satu kartu bisa dibeli tiap jatah',
                            style: TextStyle(
                                fontSize: 11, color: Colors.white60)),
                    ],
                  ),
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

  /// Titik asal kartu saat dibagikan: tumpukan di tengah area yang terlihat.
  Offset _dealOffset(_Grid g, int i, int n, double aw, double viewH) {
    final rows = (n / g.cols).ceil();
    final r = i ~/ g.cols;
    final col = i % g.cols;
    final inRow = (r == rows - 1) ? n - r * g.cols : g.cols;
    final rowW = inRow * g.w + (inRow - 1) * g.gap;
    final x = (aw - rowW) / 2 + col * (g.w + g.gap) + g.w / 2;
    final totalH = rows * g.h + (rows - 1) * g.gap;
    final top = totalH + 24 < viewH ? (viewH - totalH) / 2 : 16.0;
    final y = top + r * (g.h + g.gap) + g.h / 2;
    return Offset(aw / 2 - x, viewH / 2 - y);
  }

  Widget _marketCard(int i, int n, Map<String, dynamic> offer, _Grid g,
      double aw, double viewH) {
    final id = offer['card_id'] as String;
    final price = _price(id);
    final bought = offer['bought'] == true;
    final picked = i == sel;
    final blocked = _blockReason(offer, price) != null;
    final def = widget.defs[id];
    final bad = def?['side'] == 'antagonis';

    final tile = CardTile(
      def: def,
      fallbackName: id,
      width: g.w,
      showCost: true,
      costOverride: price,
      badge: bought ? 'Terbeli' : null,
      selected: picked,
      dim: blocked && !picked,
      onTap: () => _select(i),
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
      width: g.w,
      height: g.h,
      revealed: _marketOpened,
      animate: !_marketOpened,
      dark: bad,
      glow: bad ? EmbunColors.mist : const Color(0xFFFFD866),
      dealOffset: _dealOffset(g, i, n, aw, viewH),
      suspense: n > 2 && i == n - 1,
      front: front,
    );
  }

  /// Area kartu toko. [fit] memuat semua kartu tanpa gulir (desktop);
  /// bila tidak, kolom tetap dan sisanya digulir (ponsel).
  Widget _marketView({
    bool fit = false,
    double maxW = 124,
    double minW = 92,
    double gap = 10,
    int cols = 3,
  }) {
    final o = offers;
    if (o == null) return const EmbunLoading();
    if (o.isEmpty) {
      return _empty('store', 'Toko sedang sepi', 'Belum ada tawaran hari ini.');
    }
    return LayoutBuilder(builder: (context, c) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _armMarket());
      // Sisakan ruang agar pendar kartu tidak terpotong tepi gulir.
      final aw = c.maxWidth - 16;
      final n = o.length;
      final g = fit
          ? _fit(aw, c.maxHeight, n, gap: gap, minW: minW, maxW: maxW)
          : _fixedCols(aw, n, gap, cols.toDouble(), maxW);
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: g.gap,
                runSpacing: g.gap,
                children: [
                  for (var i = 0; i < n; i++)
                    _marketCard(i, n, o[i], g, aw, c.maxHeight),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  /// Rincian kartu terpilih dan tombol beli. Bila belum bisa dibeli, alasannya
  /// tertulis di bawah jenis kartu.
  Widget _detail(_DetailStyle style) {
    final o = offers;
    if (o == null || o.isEmpty) return const SizedBox.shrink();
    final i = sel.clamp(0, o.length - 1).toInt();
    final offer = o[i];
    final id = offer['card_id'] as String;
    final def = widget.defs[id];
    final bad = def?['side'] == 'antagonis';
    final price = _price(id);
    final bought = offer['bought'] == true;
    final reason = _blockReason(offer, price);
    final can = reason == null && !busy;
    final accent = bad ? EmbunColors.mist : EmbunColors.gold;
    final afford = price <= widget.balance;
    final big = style == _DetailStyle.plate;
    final description = '${def?['description'] ?? ''}';

    final pill = Container(
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
          GameIcon(bad ? 'bulirhitam' : 'bulirembun', size: big ? 30 : 26),
          const SizedBox(width: 4),
          Text('$price',
              style: TextStyle(
                  fontSize: big ? 18 : 15,
                  fontWeight: FontWeight.bold,
                  color: afford ? EmbunColors.gold : EmbunColors.blood)),
        ],
      ),
    );

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_cardName(id),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: big ? 20 : 16,
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
        if (reason != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(reason,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: bought ? Colors.white54 : EmbunColors.blood)),
          ),
        const SizedBox(height: 4),
        Text(description,
            maxLines: style == _DetailStyle.bar ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: big ? 13 : 12,
                height: 1.3,
                color: Colors.white70)),
      ],
    );

    final swapInfo = AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      layoutBuilder: (cur, prev) => Stack(
        alignment: Alignment.topLeft,
        children: [...prev, ?cur],
      ),
      child: KeyedSubtree(key: ValueKey('$i-$id'), child: info),
    );

    Widget button(double h, String label) => EmbunButton(
      label: bought ? 'Terbeli' : label,
      icon: bad ? 'bulirhitam' : 'bulirembun',
      expand: true,
      height: h,
      onPressed: can ? _buy : null,
    );

    final deco = BoxDecoration(
      color: Colors.black.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.2),
    );

    switch (style) {
      case _DetailStyle.bar:
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: deco,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: swapInfo),
              const SizedBox(width: 10),
              SizedBox(
                width: 112,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(alignment: Alignment.centerRight, child: pill),
                    const SizedBox(height: 6),
                    button(44, 'Beli'),
                  ],
                ),
              ),
            ],
          ),
        );
      case _DetailStyle.plate:
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
          decoration: deco,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: swapInfo),
              const SizedBox(width: 22),
              SizedBox(
                width: 250,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(alignment: Alignment.centerRight, child: pill),
                    const SizedBox(height: 10),
                    button(54, 'Beli kartu ini'),
                  ],
                ),
              ),
            ],
          ),
        );
      case _DetailStyle.column:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: deco,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              swapInfo,
              const SizedBox(height: 8),
              Row(
                children: [
                  pill,
                  const SizedBox(width: 8),
                  Expanded(child: button(44, 'Beli')),
                ],
              ),
            ],
          ),
        );
    }
  }

  /// Layar Toko di ponsel.
  Widget _tokoPage({required bool side}) {
    final hasKabar = !_kabarHidden &&
        widget.events
            .any((e) => e['kind'] == 'kabar' && e['day'] == widget.day);
    if (side) {
      // Layar pendek: kartu di kiri, rincian di kanan.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _marketSign(),
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _marketView(
                      fit: true, minW: 84, maxW: 120, gap: 8),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 232,
                  child: SingleChildScrollView(
                      child: _detail(_DetailStyle.column)),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _marketSign(),
        const SizedBox(height: 4),
        if (hasKabar) _kabar(compact: true),
        Expanded(child: _marketView()),
        const SizedBox(height: 6),
        _detail(_DetailStyle.bar),
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

  /// Panggung utama: bingkai emas berhias, papan toko, kartu besar sebaris,
  /// lalu rincian dan tombol beli. Ini pusat perhatian layar.
  Widget _marketHero() => OrnatePanel(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _marketSign(big: true),
        const SizedBox(height: 6),
        Expanded(
          child: _marketView(fit: true, minW: 110, maxW: 220, gap: 18),
        ),
        const SizedBox(height: 8),
        _detail(_DetailStyle.plate),
      ],
    ),
  );

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