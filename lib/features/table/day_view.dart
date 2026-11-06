import 'dart:async';
import 'dart:math' show sin, pi, min;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import '../common/sfx.dart';
import 'bow_dialog.dart';
import 'card_tile.dart';
import 'economy_fx.dart';
import 'flip_card.dart';
import 'player_status.dart';
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

/// Mode "wide" butuh >= 1000 px lebar: Toko (3 kartu + panel keterangan) dan
/// rel kanan baru muat tanpa meluap. Di bawah itu (tablet, jendela sempit)
/// dipakai susunan ponsel yang bisa digeser. Layar pendek memakai rel samping.
_Mode _modeFor(BoxConstraints c) {
  final w = c.maxWidth, h = c.maxHeight;
  if (w >= 1000 && h >= 480) return _Mode.wide;
  if (h < 460 && w >= 520) return _Mode.landscape;
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

  /// Peran asli pemain ini Si Terbisik (meski sedang tampil sebagai warga).
  /// Dipakai agar Busur Terakhir tampil abu-abu dan tak bisa dipakai.
  final bool isAntag;

  /// Kunci untuk tab / panel Meja bila induk perlu tahu posisinya (animasi
  /// kartu masuk / keluar dari pemain lain). Opsional.
  final GlobalKey? mejaKey;

  /// Dipanggil setelah tangan kartu berubah (mis. kartu kuning dipakai).
  final VoidCallback? onHandChanged;

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
    this.isAntag = false,
    this.mejaKey,
    this.onHandChanged,
  });

  @override
  State<DayView> createState() => _DayViewState();
}

class _DayViewState extends State<DayView>
    with SingleTickerProviderStateMixin {
  final PageController _pager = PageController();

  // Jam berdenyut: tombol akhiri hari, tawaran tukar, dan lencana Balai.
  late final AnimationController _t = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600))
    ..repeat();
  double get _pulse => 0.5 + 0.5 * sin(_t.value * 2 * pi);
  int tab = _tabToko;
  int sel = 0; // indeks kartu toko yang dipilih
  List<Map<String, dynamic>>? offers;
  List<Map<String, dynamic>> _guards = []; // perlindungan / cermin aktif
  bool busy = false;

  // Pembukaan toko: kartu dibagikan sebagai punggung, lalu berbalik. Hanya
  // diputar sekali per hari; kembali ke Toko langsung menampilkan muka.
  bool _marketOpened = false;
  Timer? _openTimer;
  Timer? _kabarTimer;
  bool _kabarHidden = false;

  // Titik rujukan animasi beli: kartu di rak, pil saldo, dan tab/panel Meja.
  final GlobalKey _payKey = GlobalKey();
  final GlobalKey _ownMejaKey = GlobalKey();
  GlobalKey get _mejaKey => widget.mejaKey ?? _ownMejaKey;
  final List<GlobalKey> _offerKeys = [];

  GlobalKey _offerKey(int i) {
    while (_offerKeys.length <= i) {
      _offerKeys.add(GlobalKey());
    }
    return _offerKeys[i];
  }

  /// Persegi widget dalam koordinat layar, atau null bila belum terpasang.
  Rect? _rectOf(GlobalKey k) {
    final ro = k.currentContext?.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
    return ro.localToGlobal(Offset.zero) & ro.size;
  }

  @override
  void initState() {
    super.initState();
    _loadOffers();
    _loadGuards();
    widget.marketTick?.addListener(_loadOffers);
    // Banner Kabar Pagi di layar Toko menyingkir sendiri supaya kartu lega;
    // isinya tetap bisa dibaca di Balai, atau dibuka lagi lewat lencana.
    _hideKabarLater();
  }

  void _hideKabarLater() {
    _kabarTimer?.cancel();
    _kabarTimer = Timer(const Duration(seconds: 9), () {
      if (mounted) setState(() => _kabarHidden = true);
    });
  }

  void _showKabar() {
    setState(() => _kabarHidden = false);
    _hideKabarLater();
  }

  bool get _hasKabar => widget.events
      .any((e) => e['kind'] == 'kabar' && e['day'] == widget.day);

  /// Slot banner Kabar Pagi yang melipat mulus saat menyingkir.
  Widget _kabarSlot({required bool compact}) => AnimatedSize(
    duration: const Duration(milliseconds: 280),
    curve: Curves.easeOutCubic,
    alignment: Alignment.topCenter,
    child: (!_kabarHidden && _hasKabar)
        ? _kabar(compact: compact)
        : const SizedBox(width: double.infinity),
  );

  @override
  void dispose() {
    _t.dispose();
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

  Future<void> _loadGuards() async {
    final r = await widget.repo.myGuards(widget.gameId);
    if (mounted) setState(() => _guards = r);
  }

  /// Kartu kuning di Meja: ketuk -> pratinjau dengan tombol "Pakai sekarang".
  bool _isBow(Map<String, dynamic>? def) {
    final e = def?['effect'];
    return e is Map && e['day'] == 'shoot';
  }

  Future<void> _useDayCard(Map<String, dynamic> h) async {
    final def = widget.defs[h['card_id']];
    if (def == null) return;
    final bow = _isBow(def);

    // Kartu kuning warga di tangan Si Terbisik (hasil curian) tak bisa dipakai.
    if (widget.isAntag && def['side'] == 'warga') {
      await showCardPreview(context, def);
      if (mounted) _toast('Kartu warga tidak bisa dipakai Si Terbisik.');
      return;
    }

    await showCardPreview(
      context,
      def,
      actionLabel: bow ? 'Bidik' : 'Pakai sekarang',
      onAction: () async {
        String? target;
        if (bow) {
          if (!mounted) return;
          target = await showBowTargetDialog(
            context,
            players: widget.players,
            myId: widget.repo.myId,
          );
          if (target == null) return;
        }
        await _run(() async {
          final r = await widget.repo
              .useDayCard(widget.gameId, h['id'] as String, target: target);
          if (!mounted) return;
          if (r['mode'] == 'shoot') HapticFeedback.heavyImpact();
          _toast('${r['message'] ?? 'Kartu dipakai'}');
          if (r['mode'] == 'reroll_market') await _loadOffers();
          await _loadGuards();
          widget.onHandChanged?.call();
        });
      },
    );
  }

  /// Label di kartu lanjutan: "AKTIF" bila sudah digabung dengan poin.
  String? _handTag(Map<String, dynamic> h) {
    if (widget.defs[h['card_id']]?['kind'] != 'lanjutan') return null;
    return h['charged'] == true ? 'AKTIF' : 'Butuh poin';
  }

  String get _poinName => widget.isAntag ? 'Poin DNA' : 'Poin Regenerasi';

  /// Kartu lanjutan di Meja: ketuk -> pratinjau dengan tombol
  /// "Gabungkan dengan Poin". Kartu aktif lalu bisa dipersembahkan.
  Future<void> _useAdvanced(Map<String, dynamic> h) async {
    final def = widget.defs[h['card_id']];
    if (def == null) return;
    final mine = def['side'] == (widget.isAntag ? 'antagonis' : 'warga');
    if (h['charged'] == true || !mine) {
      await showCardPreview(context, def);
      if (mounted) {
        _toast(h['charged'] == true
            ? 'Kartu ini sudah aktif. Persembahkan di malam persembahan.'
            : 'Kartu ini bukan untuk perananmu, jadi tidak bisa diaktifkan.');
      }
      return;
    }
    await showCardPreview(
      context,
      def,
      actionLabel: 'Gabungkan dengan $_poinName',
      onAction: () => _run(() async {
        final r = await widget.repo.fuseCards(widget.gameId, h['id'] as String);
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        _toast('${r['message'] ?? 'Kartu aktif'}');
        widget.onHandChanged?.call();
      }),
    );
  }

  Future<void> _showPoinHint(Map<String, dynamic> h) async {
    final def = widget.defs[h['card_id']];
    if (def == null) return;
    await showCardPreview(context, def);
    if (mounted) {
      _toast('Ketuk kartu lanjutanmu untuk menggabungkannya dengan $_poinName.');
    }
  }

  /// Lencana perlindungan / cermin yang masih berlaku sampai akhir sesi.
  Widget? _guardStrip() {
    final active = _guards
        .where((q) => ((q['until_day'] as int?) ?? 0) >= widget.day)
        .toList();
    if (active.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final q in active)
            StatusTag(
              text: switch (q['kind']) {
                'mirror' => 'Cermin Kecil aktif',
                'accuse' => 'Perisai Tuduhan aktif',
                _ => 'Perisai Malam aktif',
              },
              color: EmbunColors.gold,
              icon: switch (q['kind']) {
                'mirror' => Icons.flip_rounded,
                'accuse' => Icons.gavel_rounded,
                _ => Icons.shield_rounded,
              },
              fontSize: 11,
            ),
        ],
      ),
    );
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
    h['card_id'] != 'embun_samaran' &&
        widget.defs[h['card_id']]?['kind'] != 'malam')
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
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (widget.jailed)
          _chip('lock', 'Dikurung', color: EmbunColors.blood)
        else
          _chip('item', 'Jatah $remain',
              color: remain > 0 ? Colors.white70 : Colors.white38),
        if (mod != 0)
          _chip(mod > 0 ? 'plus' : 'minus', 'Harga ${mod > 0 ? '+' : ''}$mod',
              color: mod < 0 ? Colors.greenAccent : Colors.orangeAccent),
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

  Future<void> _buyOffer(String id, int index) {
    // Ukur posisi SEBELUM membeli: sesudahnya rak dimuat ulang.
    final from = _rectOf(_offerKey(index));
    final to = _rectOf(_mejaKey);
    final pay = _rectOf(_payKey);
    final price = _price(id);
    final def = widget.defs[id];
    return _run(() async {
      await widget.repo.buyCard(widget.gameId, id);
      if (mounted && from != null) {
        // Haptic sudah ada di dalam animasi terbang.
        showCardFlight(
          context,
          def: def,
          from: from,
          to: to,
          pay: pay,
          price: price,
          dark: def?['side'] == 'antagonis',
        );
      } else {
        HapticFeedback.mediumImpact();
        Sfx.I.play(Snd.buy);
      }
      await _loadOffers();
    }, ok: '${_cardName(id)} masuk ke mejamu');
  }

  /// Hitungan saldo berbentuk pil emas di pojok kanan atas panel.
  Widget _balancePill({double size = 30}) => BalanceFx(
    key: _payKey,
    balance: widget.balance,
    day: widget.day,
    dark: widget.dark,
    side: FxSide.left,
    builder: (context, shown) => Container(
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
          Text(_fmt(shown),
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: EmbunColors.gold)),
        ],
      ),
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
    final h = w * cardAspectForDef(def);

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
          KeyedSubtree(
            key: _offerKey(i),
            child: FlipCard(
              key: ValueKey('offer$i-$id'),
              index: i,
              width: w,
              height: h,
              revealed: _marketOpened,
              animate: !_marketOpened,
              dark: bad,
              // Pasar pribadi: item warga hijau, item antagonis merah,
              // serangan malam ungu.
              backPath: itemBackFor(def),
              glow: bad ? EmbunColors.mist : const Color(0xFFFFD866),
              dealOffset: Offset(dealX, 0),
              suspense: n > 2 && i == n - 1,
              front: front,
            ),
          ),
          const SizedBox(height: 8),
          EmbunButton(
            label: bought ? 'Terbeli' : 'Beli',
            expand: true,
            height: 38,
            kind: can ? EmbunButtonKind.primary : EmbunButtonKind.secondary,
            onPressed: can ? () => _buyOffer(id, i) : null,
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
      var maxA = kItemAspect;
      for (final e in o) {
        final a = cardAspectForDef(widget.defs[e['card_id']]);
        if (a > maxA) maxA = a;
      }
      final byH = (c.maxHeight - chrome) / maxA;
      if (byH < w) w = byH;
      w = w.clamp(72.0, 190.0).toDouble().floorToDouble();
      final row = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < n; i++) ...[
            if (i > 0) const SizedBox(width: gap),
            _shopCol(i, n, o[i], w, gap),
          ],
        ],
      );
      // Ruang terlalu sempit untuk n kolom minimum: gulir ke samping,
      // jangan meluap.
      final rowW = n * w + (n - 1) * gap;
      return Center(
        child: SingleChildScrollView(
          child: rowW > c.maxWidth
              ? SizedBox(
            width: c.maxWidth,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: row,
            ),
          )
              : row,
        ),
      );
    });
  }

  /// Panel info di samping (seperti panel "Upgrade"): kabar, status, uraian
  /// kartu yang disentuh, dan tombol lewati (akhiri hari).
  Widget _shopInfo() {
    final o = offers;
    var descKey = 'none';
    Widget desc = const SizedBox.shrink();
    if (o != null && o.isNotEmpty) {
      final i = sel.clamp(0, o.length - 1).toInt();
      final id = o[i]['card_id'] as String;
      final def = widget.defs[id];
      final bad = def?['side'] == 'antagonis';
      final reason = _blockReason(o[i], _price(id));
      descKey = '$i-$id-${reason ?? 'ok'}';
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
            ],
          ),
          const Divider(height: 16),
          // Keterangan berganti dengan memudar dan meluncur saat kartu lain dipilih.
          Expanded(
            child: SingleChildScrollView(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                layoutBuilder: (cur, prev) => Stack(
                  alignment: Alignment.topLeft,
                  children: [...prev, ?cur],
                ),
                transitionBuilder: (w, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween<Offset>(
                        begin: const Offset(0, 0.06), end: Offset.zero)
                        .animate(a),
                    child: w,
                  ),
                ),
                child: KeyedSubtree(key: ValueKey(descKey), child: desc),
              ),
            ),
          ),
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

  /// Keterangan ringkas kartu terpilih untuk ponsel, tempat panel samping
  /// tidak muat: nama, jenis, efek (dua baris), dan alasan belum bisa dibeli.
  Widget _shopInfoCompact() {
    final o = offers;
    if (o == null || o.isEmpty) return const SizedBox.shrink();
    final i = sel.clamp(0, o.length - 1).toInt();
    final id = o[i]['card_id'] as String;
    final def = widget.defs[id];
    final bad = def?['side'] == 'antagonis';
    final reason = _blockReason(o[i], _price(id));
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      transitionBuilder: (w, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween<Offset>(
              begin: const Offset(0, 0.12), end: Offset.zero)
              .animate(a),
          child: w,
        ),
      ),
      child: Container(
        key: ValueKey('c$i-$id-${reason ?? 'ok'}'),
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: (bad ? EmbunColors.mist : EmbunColors.gold)
                  .withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GameIcon(kindIcon[def?['kind']] ?? 'item', size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_cardName(id)} · ${kindLabel[def?['kind']] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: bad ? EmbunColors.mist : EmbunColors.gold)),
                  const SizedBox(height: 2),
                  Text('${def?['description'] ?? ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11.5, height: 1.3, color: Colors.white70)),
                  if (reason != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(reason,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: EmbunColors.blood)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Panel toko. Hierarki: (1) judul + saldo, (2) status jatah / harga,
  /// (3) kartu dan tombol Beli, (4) keterangan kartu terpilih. Bagian (2)
  /// dan (4) menyesuaikan tinggi yang tersedia.
  Widget _shopPanel({required bool wide}) =>
      LayoutBuilder(builder: (context, box) {
        final short = box.maxHeight < 400;
        final showCompact = !wide && box.maxHeight >= 470;
        final infoW = (box.maxWidth * 0.34).clamp(210.0, 270.0).toDouble();
        return OrnatePanel(
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
                  // Kabar Pagi yang sudah menyingkir bisa dibuka lagi.
                  if (_kabarHidden && _hasKabar) ...[
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _showKabar,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: _chip('announcement', 'Kabar',
                            color: EmbunColors.gold),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  _balancePill(size: wide ? 32 : 26),
                ],
              ),
              if (!short) ...[
                const SizedBox(height: 6),
                _statusChips(),
              ],
              const SizedBox(height: 8),
              Expanded(
                child: wide
                    ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _shopMat(_shopColumns())),
                    const SizedBox(width: 16),
                    SizedBox(width: infoW, child: _shopInfo()),
                  ],
                )
                    : _shopMat(_shopColumns()),
              ),
              if (showCompact) _shopInfoCompact(),
            ],
          ),
        );
      });

  /// Layar Toko di ponsel / layar pendek.
  Widget _tokoPage({required bool side}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _kabarSlot(compact: true),
      Expanded(child: _shopPanel(wide: false)),
    ],
  );


  // ====================== Meja ======================

  /// Alas Meja: meja kayu bertinta; anyaman gelap bila peran gelap tampil.
  Widget _mejaBody({double minW = 96}) {
    final p = sceneryPath(widget.dark ? 'anyaman-gelap' : 'mejaku');
    if (p == null) return _mejaBodyInner(minW: minW);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Anyaman (peran gelap) diputar bila bidangnya potret; meja kayu
          // (`mejaku`) adalah pemandangan, jadi tidak pernah diputar.
          OrientedImage(
              path: p, cacheWidth: 900, rotateWhenTall: widget.dark),
          ColoredBox(
              color: Colors.black.withValues(alpha: widget.dark ? 0.3 : 0.45)),
          Padding(
            padding: const EdgeInsets.all(4),
            child: _mejaBodyInner(minW: minW),
          ),
        ],
      ),
    );
  }

  /// Alas Toko: tikar anyaman. Gelap untuk peran gelap, rusak bila dikurung
  /// (tak bisa berbelanja), temaram selain itu.
  Widget _shopMat(Widget child) {
    final p = sceneryPath(widget.jailed
        ? 'anyaman-rusak'
        : widget.dark
        ? 'anyaman-gelap'
        : 'anyaman-temaram');
    if (p == null) return child;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          OrientedImage(path: p, cacheWidth: 900),
          ColoredBox(color: Colors.black.withValues(alpha: 0.4)),
          child,
        ],
      ),
    );
  }

  Widget _mejaBodyInner({double minW = 96}) {
    final hand = widget.hand;
    final strip = _guardStrip();
    if (hand.isEmpty) {
      final empty = _empty('mydeck2', 'Mejamu masih kosong',
          'Beli kartu di Toko untuk dipersembahkan.');
      return strip == null
          ? empty
          : Column(children: [strip, Expanded(child: empty)]);
    }
    final hasDay = hand.any((h) {
      final k = widget.defs[h['card_id']]?['kind'];
      return k == 'siang' || k == 'lanjutan';
    });
    return LayoutBuilder(builder: (context, box) {
      final g = _mejaGrid(box.maxWidth, minW);
      return SingleChildScrollView(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Column(
          children: [
            if (strip != null) strip,
            Text(
                hasDay
                    ? 'Tekan lama kartu untuk membaca efeknya. Ketuk kartu kuning atau kartu lanjutan untuk memakainya.'
                    : 'Tekan lama kartu untuk membaca efeknya.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.white38)),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: g.gap,
              runSpacing: g.gap,
              children: [
                // Kartu baru muncul membal; kartu lama tidak diulang
                // (kunci per baris tangan).
                for (var i = 0; i < hand.length; i++)
                  _Pop(
                    key: ValueKey('hand-${hand[i]['id'] ?? i}'),
                    index: i,
                    child: _preview(
                      widget.defs[hand[i]['card_id']],
                      CardTile(
                        def: widget.defs[hand[i]['card_id']],
                        fallbackName: hand[i]['card_id'] as String,
                        width: g.w,
                        gray: widget.isAntag &&
                            widget.defs[hand[i]['card_id']]?['kind'] == 'siang' &&
                            widget.defs[hand[i]['card_id']]?['side'] == 'warga',
                        tag: _handTag(hand[i]),
                        onTap: switch (widget.defs[hand[i]['card_id']]?['kind']) {
                          'siang' => () => _useDayCard(hand[i]),
                          'lanjutan' => () => _useAdvanced(hand[i]),
                          'poin' => () => _showPoinHint(hand[i]),
                          _ => null,
                        },
                      ),
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

  /// Tawaran masuk: meluncur dari kanan dengan pantulan, lalu berpendar
  /// emas berdenyut sampai dijawab.
  Widget _tradeCard(Map<String, dynamic> t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TweenAnimationBuilder<double>(
      key: ValueKey('trade-${t['id']}'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Opacity(
        opacity: _c(v * 2),
        child: Transform.translate(
            offset: Offset((1 - v) * 70, 0), child: child),
      ),
      child: AnimatedBuilder(
        animation: _t,
        child: _tradeCardBase(t),
        builder: (context, child) {
          final p = _pulse;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: EmbunColors.gold.withValues(alpha: 0.08 + 0.22 * p),
                  blurRadius: 8 + 10 * p,
                  spreadRadius: 0.5 * p,
                ),
              ],
            ),
            child: child,
          );
        },
      ),
    ),
  );

  Widget _tradeCardBase(Map<String, dynamic> t) => Container(
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
      key: i == 1 ? _mejaKey : null,
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
            // Lencana tawaran tukar berdenyut agar tidak terlewat.
            AnimatedBuilder(
              animation: _t,
              builder: (context, child) => Transform.scale(
                scale: badge > 0
                    ? 1 + 0.14 * sin(_t.value * 2 * pi * 2).abs()
                    : 1.0,
                child: child,
              ),
              child: Badge(
                isLabelVisible: badge > 0,
                label: Text('$badge'),
                child: Opacity(
                    opacity: on ? 1 : 0.65,
                    child: GameIcon(_tabIcons[i], size: 25)),
              ),
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
    final btn = EmbunButton(
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
    if (ready || !nothingLeft || busy) return btn;
    // Tidak ada lagi yang bisa dibeli: tombol berpendar emas mengajak lanjut.
    return AnimatedBuilder(
      animation: _t,
      child: btn,
      builder: (context, child) {
        final p = _pulse;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: EmbunColors.gold.withValues(alpha: 0.16 + 0.3 * p),
                blurRadius: 10 + 14 * p,
                spreadRadius: 0.5 + 1.5 * p,
              ),
            ],
          ),
          child: child,
        );
      },
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
          child: KeyedSubtree(
            key: _mejaKey,
            child: _railPanel(
              icon: 'mydeck2',
              title: 'Mejamu',
              trailing: Text('${widget.hand.length} kartu',
                  style: const TextStyle(fontSize: 12, color: Colors.white60)),
              child: _mejaBody(minW: 84),
            ),
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
              _kabarSlot(compact: false),
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
/// Muncul membal (memudar + membesar dari 70%). Kartu yang sudah ada tidak
/// mengulang karena widget ini dikunci per kartu; yang baru masuk bergelombang
/// menurut urutannya.
class _Pop extends StatelessWidget {
  final int index;
  final Widget child;
  const _Pop({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 0, end: 1),
    duration: Duration(milliseconds: 420 + 55 * min(index, 8)),
    curve: Curves.easeOutBack,
    builder: (context, v, c) => Opacity(
      opacity: _c(v * 1.6),
      child: Transform.scale(scale: 0.7 + 0.3 * v, child: c),
    ),
    child: child,
  );
}