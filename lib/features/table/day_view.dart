import 'dart:async';
import 'dart:math' show sin, pi, min;

import 'package:flutter/foundation.dart' show ValueListenable;
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
import 'day_chrome.dart';
import 'economy_fx.dart';
import 'flip_card.dart';
import 'player_status.dart';

double _c(double v) => v.clamp(0.0, 1.0).toDouble();

const _tabToko = 0;
const _tabMeja = 1;
const _tabGabung = 2;
const _tabBalai = 3;

enum _Mode { phone, landscape, wide }

_Mode _modeFor(BoxConstraints box) {
  if (box.maxWidth >= 940 && box.maxHeight >= 360) return _Mode.wide;
  if (box.maxWidth >= 510 && box.maxHeight < 390) return _Mode.landscape;
  return _Mode.phone;
}

/// Ukuran kartu dan jumlah kolom.
class _Grid {
  final int cols;
  final double w;
  final double gap;
  const _Grid(this.cols, this.w, this.gap);
}

/// Grid kartu Meja berdasarkan lebar yang tersedia.
_Grid _mejaGrid(double aw, double minW) {
  const gap = 10.0;
  const maxW = 140.0;
  final cols = ((aw + gap) / (minW + gap)).floor().clamp(1, 6);
  final w = ((aw - (cols - 1) * gap) / cols).clamp(1.0, maxW);
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

  /// Saldo pada header, titik akhir animasi pembayaran.
  final GlobalKey? balanceKey;

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
    this.balanceKey,
    this.onHandChanged,
  });

  @override
  State<DayView> createState() => _DayViewState();
}

class _DayViewState extends State<DayView> with SingleTickerProviderStateMixin {
  final PageController _pager = PageController(keepPage: false);

  // Jam berdenyut untuk penggabungan kartu dan tawaran tukar.
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();
  double get _pulse => 0.5 + 0.5 * sin(_t.value * 2 * pi);
  int tab = _tabToko;
  // Tab Gabung: kartu lanjutan dan kartu syarat (poin) yang diletakkan di
  // petak, dikenali lewat card_id. Penggabungan baru terjadi saat
  // "Tempatkan" ditekan.
  String? _fuseAdv;
  String? _fusePoin;
  int _deskTab = _tabMeja;
  _Mode _lastMode = _Mode.phone;
  int sel = 0; // indeks kartu toko yang dipilih
  List<Map<String, dynamic>>? offers;
  bool _offersFailed = false;
  int _offersRequest = 0;
  List<Map<String, dynamic>> _guards = []; // perlindungan / cermin aktif
  bool busy = false;

  // Pembukaan toko: kartu dibagikan sebagai punggung, lalu berbalik. Hanya
  // diputar sekali per hari; kembali ke Toko langsung menampilkan muka.
  bool _marketOpened = false;
  Timer? _openTimer;

  // Titik rujukan animasi beli: kartu di rak, pil saldo, dan tab/panel Meja.
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
  Rect? _rectOf(GlobalKey? k) {
    final ro = k?.currentContext?.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
    return ro.localToGlobal(Offset.zero) & ro.size;
  }

  @override
  void initState() {
    super.initState();
    _loadOffers();
    _loadGuards();
    widget.marketTick?.addListener(_loadOffers);
  }

  @override
  void didUpdateWidget(covariant DayView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.marketTick != widget.marketTick) {
      oldWidget.marketTick?.removeListener(_loadOffers);
      widget.marketTick?.addListener(_loadOffers);
    }
  }

  @override
  void dispose() {
    _t.dispose();
    widget.marketTick?.removeListener(_loadOffers);
    _openTimer?.cancel();
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
    final request = ++_offersRequest;
    if (_offersFailed) setState(() => _offersFailed = false);
    try {
      final next = await widget.repo.offers(widget.gameId, widget.day);
      if (!mounted || request != _offersRequest) return;
      final previous = offers;
      final selectedId = previous == null || previous.isEmpty
          ? null
          : previous[_selectedOffer]['card_id'];
      final index = next.indexWhere((row) => row['card_id'] == selectedId);
      setState(() {
        offers = next;
        sel = index < 0 ? 0 : index;
      });
    } catch (_) {
      if (!mounted || request != _offersRequest) return;
      setState(() => _offersFailed = true);
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
          final r = await widget.repo.useDayCard(
            widget.gameId,
            h['id'] as String,
            target: target,
          );
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
    final d = widget.defs[h['card_id']];
    if (d?['kind'] != 'lanjutan') return null;
    if (d?['side'] != (widget.isAntag ? 'antagonis' : 'warga')) return null;
    return h['charged'] == true ? 'AKTIF' : 'Butuh poin';
  }

  /// Kartu lanjutan yang belum digabung dengan poin: gambarnya memudar.
  bool _isDormant(Map<String, dynamic> h) =>
      widget.defs[h['card_id']]?['kind'] == 'lanjutan' && h['charged'] != true;

  String get _poinName => widget.isAntag ? 'Poin DNA' : 'Poin Regenerasi';

  /// Buka Gabung dan tempatkan kartu pilihan bila ada.
  void _openGabung([String? advCardId]) {
    if (advCardId != null) setState(() => _fuseAdv = advCardId);
    _goTab(_tabGabung);
  }

  /// Kartu lanjutan di Meja: ketuk -> hanya pratinjau. Penggabungan dengan
  /// kartu syarat dilakukan di tab Gabung.
  Future<void> _useAdvanced(Map<String, dynamic> h) async {
    final def = widget.defs[h['card_id']];
    if (def == null) return;
    final mine = def['side'] == (widget.isAntag ? 'antagonis' : 'warga');
    if (h['charged'] == true || !mine) {
      await showCardPreview(context, def, defs: widget.defs);
      if (mounted) {
        _toast(
          h['charged'] == true
              ? 'Kartu ini sudah aktif. Persembahkan di malam persembahan.'
              : 'Kartu ini bukan untuk perananmu, jadi tidak bisa diaktifkan.',
        );
      }
      return;
    }
    await showCardPreview(
      context,
      def,
      defs: widget.defs,
      actionLabel: 'Buka tab Gabung',
      onAction: () async {
        if (mounted) _openGabung(h['card_id'] as String);
      },
    );
  }

  /// Hitung kartu di tangan yang cocok untuk tab Gabung: kartu lanjutan
  /// milik perananmu yang belum aktif, dan kartu syarat (poin) sepihak.
  /// Dikelompokkan per jenis kartu, dengan jumlahnya.
  ({List<(String, int)> adv, List<(String, int)> poin}) _fuseCandidates() {
    final mySide = widget.isAntag ? 'antagonis' : 'warga';
    final adv = <String, int>{}, poin = <String, int>{};
    for (final h in widget.hand) {
      final d = widget.defs[h['card_id']];
      if (d == null || d['side'] != mySide) continue;
      final id = h['card_id'] as String;
      if (d['kind'] == 'lanjutan' && h['charged'] != true) {
        adv[id] = (adv[id] ?? 0) + 1;
      } else if (d['kind'] == 'poin') {
        poin[id] = (poin[id] ?? 0) + 1;
      }
    }
    return (
      adv: [for (final e in adv.entries) (e.key, e.value)],
      poin: [for (final e in poin.entries) (e.key, e.value)],
    );
  }

  /// Tempatkan: gabungkan kartu lanjutan di petak dengan kartu syarat.
  Future<void> _doFuse() async {
    final advId = _fuseAdv;
    if (advId == null || _fusePoin == null) return;
    Map<String, dynamic>? row;
    for (final h in widget.hand) {
      if (h['card_id'] == advId && h['charged'] != true) {
        row = h;
        break;
      }
    }
    if (row == null) {
      setState(() => _fuseAdv = null);
      _toast('Kartu lanjutan itu sudah tidak ada di mejamu.');
      return;
    }
    final handId = row['id'] as String;
    await _run(() async {
      final r = await widget.repo.fuseCards(widget.gameId, handId);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _fuseAdv = null;
        _fusePoin = null;
      });
      _toast('${r['message'] ?? 'Kartu aktif'}');
      widget.onHandChanged?.call();
    });
  }

  Future<void> _showPoinHint(Map<String, dynamic> h) async {
    final def = widget.defs[h['card_id']];
    if (def == null) return;
    await showCardPreview(context, def, defs: widget.defs);
    if (mounted) {
      _toast('Gabungkan $_poinName dengan kartu lanjutanmu di tab Gabung.');
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

  void _toast(String message) {
    final landscape = _lastMode == _Mode.landscape;
    final scale = MediaQuery.textScalerOf(context).scale(15) / 15;
    final stacked =
        _lastMode == _Mode.phone &&
        MediaQuery.sizeOf(context).width < 420 &&
        scale > 1.25;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          landscape ? 100 : 12,
          0,
          12,
          landscape ? 12 : (stacked ? 120 : 76),
        ),
      ),
    );
  }

  Future<void> _run(Future<void> Function() action, {String? ok}) async {
    if (busy) return;
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
      .where(
        (t) =>
            t['status'] == 'pending' &&
            t['day'] == widget.day &&
            t['to_id'] == widget.repo.myId,
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

  Future<void> _endDay() => _run(() => widget.repo.finishDay(widget.gameId));

  Future<void> _accept(Map<String, dynamic> t) async {
    // Terkurung: tidak boleh menyerahkan kartu, jadi hanya menerima.
    if (widget.jailed) {
      await _run(
        () => widget.repo.respondTrade(t['id'] as String, true),
        ok: 'Kartu diterima',
      );
      return;
    }
    final tradable = widget.hand
        .where(
          (h) =>
              h['card_id'] != 'embun_samaran' &&
              widget.defs[h['card_id']]?['kind'] != 'malam',
        )
        .toList();
    if (tradable.isEmpty) {
      _toast('Kamu tidak punya kartu untuk ditukar');
      return;
    }
    final pick = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(
          'Tukar ${_cardName(t['give_card_id'] as String)} dengan...',
        ),
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

  void _goTab(int index) {
    if (_lastMode == _Mode.wide) {
      if (index == _deskTab) return;
      HapticFeedback.selectionClick();
      setState(() {
        _deskTab = index;
        tab = index;
      });
      return;
    }
    if (!_pager.hasClients || (_pager.page ?? tab.toDouble()) == index) return;
    HapticFeedback.selectionClick();
    if ((index - (_pager.page ?? tab.toDouble())).abs() > 1.5) {
      _pager.jumpToPage(index);
    } else {
      _pager.animateToPage(
        index,
        duration: const Duration(milliseconds: 230),
        curve: Curves.easeOutCubic,
      );
    }
  }

  // ====================== bahan dasar ======================

  Color get _accent => widget.dark ? EmbunColors.mist : EmbunColors.gold;

  Widget _section(String title, {String? icon, String? trailing}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        if (icon != null) ...[
          GameIcon(icon, size: 22),
          const SizedBox(width: 7),
        ],
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),
        if (trailing != null) Text(trailing, style: dayCaption),
      ],
    ),
  );

  Widget _chip(String icon, String text, {Color? color}) {
    final ink = color ?? EmbunColors.cream;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ink.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GameIcon(icon, size: 16),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(String icon, String title, String hint, {Widget? action}) =>
      Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GameIcon(icon, size: 42),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: EmbunColors.cream,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(hint, textAlign: TextAlign.center, style: dayCaption),
              ?action,
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

  Future<void> _buyOffer(String id, int index) {
    // Ukur posisi SEBELUM membeli: sesudahnya rak dimuat ulang.
    final from = _rectOf(_offerKey(index));
    final to = _rectOf(_mejaKey);
    final pay = _rectOf(widget.balanceKey);
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

  // ====================== Pasar Pagi ======================

  Widget _marketStatus() => Wrap(
    spacing: 5,
    runSpacing: 4,
    alignment: WrapAlignment.end,
    children: [
      _chip(
        widget.jailed ? 'lock' : 'item',
        widget.jailed ? 'Dikurung' : 'Jatah $_remaining',
        color: widget.jailed ? EmbunColors.blood : _accent,
      ),
      if (widget.priceMod != 0)
        _chip(
          widget.priceMod > 0 ? 'plus' : 'minus',
          'Harga ${widget.priceMod > 0 ? '+' : ''}${widget.priceMod}',
          color: widget.priceMod < 0 ? EmbunColors.leaf : Colors.orangeAccent,
        ),
    ],
  );

  Widget _offerTile(
    Map<String, dynamic> offer,
    int index,
    int columns,
    double width,
  ) {
    final id = offer['card_id'] as String;
    final def = widget.defs[id];
    final dark = def?['side'] == 'antagonis';
    final bought = offer['bought'] == true;
    final selected = index == _selectedOffer;
    final price = _price(id);
    final name = _cardName(id);
    final currency = dark ? 'bulirhitam' : 'bulirembun';

    return SizedBox(
      width: width,
      child: Semantics(
        selected: selected,
        button: true,
        label: bought ? '$name, terbeli' : '$name, harga $price',
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              HapticFeedback.selectionClick();
              Sfx.I.click(Snd.clickTung);
              setState(() => sel = index);
            },
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 11),
                  KeyedSubtree(
                    key: _offerKey(index),
                    child: FlipCard(
                      key: ValueKey('offer$index-$id'),
                      index: index,
                      width: width,
                      height: width * cardAspectForDef(def),
                      revealed: _marketOpened,
                      animate: !_marketOpened,
                      dark: dark,
                      backPath: itemBackFor(def),
                      glow: dark ? EmbunColors.mist : EmbunColors.gold,
                      dealOffset: Offset(
                        ((columns - 1) / 2 - index % columns) * width,
                        0,
                      ),
                      suspense:
                          index >= 2 && index == (offers?.length ?? 0) - 1,
                      front: _preview(
                        def,
                        CardTile(
                          def: def,
                          fallbackName: id,
                          width: width,
                          selected: selected,
                          dim: bought && !selected,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? EmbunColors.cream : Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xEA0A1813),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _accent.withValues(
                            alpha: selected ? 0.64 : 0.25,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GameIcon(bought ? 'centang' : currency, size: 16),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                bought ? 'Terbeli' : '$price',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: bought
                                      ? EmbunColors.leaf
                                      : price > widget.balance
                                      ? const Color(0xFFF38B80)
                                      : EmbunColors.gold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  int get _selectedOffer => offers == null || offers!.isEmpty
      ? 0
      : sel.clamp(0, offers!.length - 1).toInt();

  Widget _marketOffers() {
    final list = offers;
    if (_offersFailed && (list == null || list.isEmpty)) {
      return _empty(
        'store',
        'Pasar gagal dimuat',
        'Coba ambil lagi penawaran hari ini.',
        action: TextButton(
          onPressed: _loadOffers,
          child: const Text('Coba lagi'),
        ),
      );
    }
    if (list == null) {
      return const Center(
        child: SingleChildScrollView(
          child: EmbunLoading(text: 'Memuat Pasar Pagi…'),
        ),
      );
    }
    if (list.isEmpty) {
      return _empty(
        'store',
        'Pasar sedang sepi',
        'Belum ada tawaran hari ini.',
      );
    }

    return LayoutBuilder(
      builder: (context, box) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _armMarket();
        });
        const gap = 8.0;
        const inset = 8.0;
        final available = box.maxWidth - 2 * inset;
        final twoRows =
            available >= 285 &&
            available <= 425 &&
            box.maxHeight >= 365 &&
            list.length >= 4;
        final columns = twoRows
            ? 2
            : ((available + gap) / (52 + gap))
                  .floor()
                  .clamp(1, min(4, list.length))
                  .toInt();
        final byWidth = (available - (columns - 1) * gap) / columns;
        final byHeight =
            ((twoRows ? box.maxHeight / 2 : box.maxHeight) - 66) / kTallAspect;
        final width = min(
          byWidth,
          byHeight.clamp(50.0, 162.0),
        ).clamp(1.0, 162.0).floorToDouble();
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(inset),
            child: SizedBox(
              width: width * columns + (columns - 1) * gap,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: gap,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < list.length; i++)
                    _offerTile(list[i], i, columns, width),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _marketSelection({
    required bool side,
    required bool short,
    required bool inline,
  }) {
    final list = offers;
    if (list == null || list.isEmpty) return const SizedBox.shrink();
    final index = _selectedOffer;
    final offer = list[index];
    final id = offer['card_id'] as String;
    final def = widget.defs[id];
    final price = _price(id);
    final reason = _blockReason(offer, price);
    final kind = kindLabel[def?['kind']] ?? 'Kartu';
    final description = def?['description'] as String? ?? '';
    final title = Row(
      children: [
        GameIcon(kindIcon[def?['kind']] ?? 'item', size: 27),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                side && !short ? kind.toUpperCase() : kind,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: short
                    ? dayOverline.copyWith(letterSpacing: 0.3)
                    : dayOverline,
              ),
              Text(
                _cardName(id),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: EmbunColors.cream,
                  fontWeight: FontWeight.w800,
                  fontSize: side && !short ? 18 : 14,
                ),
              ),
            ],
          ),
        ),
        if (def != null)
          IconButton(
            tooltip: 'Detail ${_cardName(id)}',
            visualDensity: VisualDensity.compact,
            onPressed: () => showCardPreview(context, def, defs: widget.defs),
            icon: const GameIcon('info', size: 22),
          ),
      ],
    );
    final details = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        if ((side || !short) && description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              description,
              style: dayCaption,
              maxLines: side && !short ? null : 2,
              overflow: side && !short ? null : TextOverflow.ellipsis,
            ),
          ),
        if (reason != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              reason,
              maxLines: side ? null : 1,
              overflow: side ? null : TextOverflow.ellipsis,
              style: dayCaption.copyWith(
                color: offer['bought'] == true
                    ? EmbunColors.leaf
                    : const Color(0xFFF3B591),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );

    final buy = EmbunButton(
      label: offer['bought'] == true ? 'Terbeli' : 'Beli · $price',
      icon: offer['bought'] == true
          ? 'centang'
          : def?['side'] == 'antagonis'
          ? 'bulirhitam'
          : 'bulirembun',
      expand: true,
      height: 42,
      onPressed: reason == null && !busy ? () => _buyOffer(id, index) : null,
    );
    if (side) {
      return Container(
        decoration: tableEdge(_accent, vertical: true),
        padding: const EdgeInsets.fromLTRB(10, 4, 3, 5),
        child: LayoutBuilder(
          builder: (context, box) {
            if (box.maxHeight < 72) {
              return SingleChildScrollView(
                child: Column(children: [details, buy]),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: SingleChildScrollView(child: details)),
                const SizedBox(height: 4),
                buy,
              ],
            );
          },
        ),
      );
    }
    return Container(
      decoration: tableEdge(_accent, top: true),
      padding: const EdgeInsets.fromLTRB(3, 2, 3, 5),
      child: inline
          ? Row(
              children: [
                Expanded(child: details),
                const SizedBox(width: 10),
                SizedBox(width: 154, child: buy),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [details, const SizedBox(height: 4), buy],
            ),
    );
  }

  Widget _shopPanel() => LayoutBuilder(
    builder: (context, box) {
      final short = box.maxHeight < 350;
      final hasOffers = offers?.isNotEmpty == true;
      final split = short && box.maxWidth >= 435 && hasOffers;
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final tight = box.maxHeight < 220 + 70 * (scale - 1).clamp(0, 1);
      final details = _marketSelection(
        side: split,
        short: short,
        inline: !split && box.maxWidth >= 425,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _dayHeading('store', 'Pasar Pagi', trailing: _marketStatus()),
            if (split)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _marketOffers()),
                    SizedBox(
                      width: (box.maxWidth * 0.30).clamp(165.0, 245.0),
                      child: details,
                    ),
                  ],
                ),
              )
            else if (tight && hasOffers)
              Expanded(
                child: ListView(
                  children: [
                    SizedBox(height: 177, child: _marketOffers()),
                    details,
                  ],
                ),
              )
            else ...[
              Expanded(child: _marketOffers()),
              if (hasOffers) details,
            ],
          ],
        ),
      );
    },
  );

  Widget _dayHeading(String icon, String title, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        GameIcon(icon, size: 27),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: EmbunColors.cream,
            ),
          ),
        ),
        if (trailing != null)
          Flexible(
            child: Align(alignment: Alignment.centerRight, child: trailing),
          ),
      ],
    ),
  );

  // ====================== Meja ======================

  // ---- Meja: kartu dikelompokkan menurut fungsinya ----

  /// 0 = pakai di siang, 1 = kombinasi (lanjutan + poin), 2 = serangan malam,
  /// 3 = untuk persembahan (sisanya).
  int _mejaGroupOf(String? kind) => switch (kind) {
    'siang' => 0,
    'lanjutan' || 'poin' => 1,
    'malam' => 2,
    _ => 3,
  };

  static const _mejaGroupInfo = [
    ('item', 'Pakai di siang', 'Ketuk kartu untuk memakainya saat itu juga.'),
    ('plus', 'Kombinasi', 'Gabungkan di tab Gabung, lalu persembahkan.'),
    ('danger', 'Serangan malam', 'Dilancarkan saat malam tiba.'),
    ('donations', 'Untuk persembahan', 'Dipersembahkan di malam persembahan.'),
  ];

  /// Kartu yang sama (dan berstatus sama) ditumpuk jadi satu, dengan lencana
  /// jumlah. Urutan: kelompok, lalu yang perlu perhatian, lalu harga.
  List<List<Map<String, dynamic>>> _mejaStacks() {
    final byKey = <String, List<Map<String, dynamic>>>{};
    for (final h in widget.hand) {
      (byKey['${h['card_id']}|${h['charged'] == true}'] ??= []).add(h);
    }
    final stacks = byKey.values.toList();
    Map<String, dynamic>? def(List<Map<String, dynamic>> s) =>
        widget.defs[s.first['card_id']];
    int rank(List<Map<String, dynamic>> s) {
      final d = def(s);
      final g = _mejaGroupOf(d?['kind'] as String?);
      // Dalam Kombinasi: lanjutan dulu, lalu poin.
      final sub = d?['kind'] == 'poin' ? 1 : 0;
      return g * 10 + sub;
    }

    stacks.sort((x, y) {
      final r = rank(x) - rank(y);
      if (r != 0) return r;
      // Kartu lanjutan yang belum aktif didahulukan.
      final cx = x.first['charged'] == true ? 1 : 0;
      final cy = y.first['charged'] == true ? 1 : 0;
      if (cx != cy) return cx - cy;
      final kx = ((def(x)?['cost'] as int?) ?? 0);
      final ky = ((def(y)?['cost'] as int?) ?? 0);
      if (kx != ky) return ky - kx;
      return '${def(x)?['name']}'.compareTo('${def(y)?['name']}');
    });
    return stacks;
  }

  Widget _mejaGroupHeader(int g, int count) {
    final (icon, title, _) = _mejaGroupInfo[g];
    final accent = widget.dark ? EmbunColors.mist : EmbunColors.gold;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GameIcon(icon, size: 22),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 1,
                  color: accent.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Petunjuk singkat bila ada kartu lanjutan / poin yang belum dipasangkan.
  Widget? _comboHint() {
    final mySide = widget.isAntag ? 'antagonis' : 'warga';
    var dormant = 0, poin = 0;
    for (final h in widget.hand) {
      final d = widget.defs[h['card_id']];
      if (d == null || d['side'] != mySide) continue;
      if (d['kind'] == 'lanjutan' && h['charged'] != true) dormant++;
      if (d['kind'] == 'poin') {
        final eff = d['effect'];
        poin += (eff is Map ? (eff['poin'] as num?)?.toInt() : null) ?? 1;
      }
    }
    if (dormant == 0 && poin == 0) return null;
    final ready = dormant > 0 && poin > 0;
    final String text;
    if (ready) {
      final n = dormant < poin ? dormant : poin;
      text =
          'Poinmu cukup untuk mengaktifkan $n kartu lanjutan. '
          'Buka tab Gabung untuk menempatkannya.';
    } else if (dormant > 0) {
      text =
          'Kartu lanjutanmu belum aktif. Beli $_poinName di Toko, '
          'lalu gabungkan di tab Gabung.';
    } else {
      text =
          '$_poinName tersimpan. Beli kartu lanjutan di Toko, '
          'lalu gabungkan di tab Gabung.';
    }
    final c = ready ? EmbunColors.gold : Colors.white70;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: ready ? () => _openGabung() : null,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const GameIcon('plus', size: 26),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 12, height: 1.35, color: c),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mejaBody({double minW = 96}) {
    final hand = widget.hand;
    final strip = _guardStrip();
    if (hand.isEmpty) {
      final empty = _empty(
        'mydeck2',
        'Mejamu masih kosong',
        'Beli kartu di Toko untuk dipersembahkan.',
      );
      return strip == null
          ? empty
          : Column(
              children: [
                strip,
                Expanded(child: empty),
              ],
            );
    }
    final stacks = _mejaStacks();
    final combo = _comboHint();
    final mySide = widget.isAntag ? 'antagonis' : 'warga';

    return LayoutBuilder(
      builder: (context, box) {
        final g = _mejaGrid(box.maxWidth - 16, minW);
        final sections = <Widget>[];
        var pop = 0;
        for (var gi = 0; gi < _mejaGroupInfo.length; gi++) {
          final inGroup = [
            for (final s in stacks)
              if (_mejaGroupOf(
                    widget.defs[s.first['card_id']]?['kind'] as String?,
                  ) ==
                  gi)
                s,
          ];
          if (inGroup.isEmpty) continue;
          final total = inGroup.fold<int>(0, (a, s) => a + s.length);
          sections.add(_mejaGroupHeader(gi, total));
          sections.add(
            Wrap(
              alignment: WrapAlignment.start,
              spacing: g.gap,
              runSpacing: g.gap,
              children: [
                for (final s in inGroup)
                  // Kartu baru muncul membal; kunci per jenis + status.
                  _Pop(
                    key: ValueKey(
                      'hand-${s.first['card_id']}-'
                      '${s.first['charged'] == true}',
                    ),
                    index: pop++,
                    child: _preview(
                      widget.defs[s.first['card_id']],
                      CardTile(
                        def: widget.defs[s.first['card_id']],
                        fallbackName: s.first['card_id'] as String,
                        width: g.w,
                        count: s.length,
                        gray:
                            (widget.isAntag &&
                                widget.defs[s.first['card_id']]?['kind'] ==
                                    'siang' &&
                                widget.defs[s.first['card_id']]?['side'] ==
                                    'warga') ||
                            (widget.defs[s.first['card_id']]?['kind'] ==
                                    'lanjutan' &&
                                widget.defs[s.first['card_id']]?['side'] !=
                                    mySide),
                        tag: _handTag(s.first),
                        faded: _isDormant(s.first),
                        onTap:
                            switch (widget.defs[s.first['card_id']]?['kind']) {
                              'siang' => () => _useDayCard(s.first),
                              'lanjutan' => () => _useAdvanced(s.first),
                              'poin' => () => _showPoinHint(s.first),
                              _ =>
                                widget.defs[s.first['card_id']] == null
                                    ? null
                                    : () => showCardPreview(
                                        context,
                                        widget.defs[s.first['card_id']]!,
                                        defs: widget.defs,
                                      ),
                            },
                      ),
                    ),
                  ),
              ],
            ),
          );
          sections.add(const SizedBox(height: 16));
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ?strip,
              const Text(
                'Pilih kartu untuk melihat detail atau aksi yang tersedia.',
                style: dayCaption,
              ),
              const SizedBox(height: 10),
              ?combo,
              ...sections,
            ],
          ),
        );
      },
    );
  }

  // ====================== Gabung ======================

  /// Petak kosong / terisi untuk satu kartu. Ketuk petak terisi untuk
  /// mengosongkannya lagi.
  Widget _fuseSlot({
    required int step,
    required String label,
    required String? cardId,
    required double w,
    required VoidCallback onClear,
    required bool faded,
  }) {
    final h = w * kTallAspect;
    if (cardId == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: w,
            height: h,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.07),
                  Colors.black.withValues(alpha: 0.35),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: EmbunColors.goldDim.withValues(alpha: 0.6),
                width: 1.4,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _stepBadge(step, false),
                const SizedBox(height: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Pilih di bawah',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: Colors.white54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text(' ', style: TextStyle(fontSize: 10)),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CardTile(
          def: widget.defs[cardId],
          fallbackName: cardId,
          width: w,
          faded: faded,
          selected: true,
          onTap: onClear,
        ),
        const SizedBox(height: 4),
        const Text(
          'Ketuk untuk melepas',
          style: TextStyle(fontSize: 10, color: Colors.white60),
        ),
      ],
    );
  }

  Widget _stepBadge(int n, bool done) => Container(
    width: 24,
    height: 24,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: done ? EmbunColors.gold : Colors.black.withValues(alpha: 0.4),
      border: Border.all(
        color: done ? EmbunColors.gold : EmbunColors.goldDim,
        width: 1.2,
      ),
    ),
    child: done
        ? const Icon(Icons.check_rounded, size: 15, color: Colors.black87)
        : Text(
            '$n',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: EmbunColors.gold,
            ),
          ),
  );

  /// Tiga langkah: lanjutan, syarat, tempatkan. Yang selesai bercentang.
  Widget _fuseSteps(bool hasAdv, bool hasPoin) {
    Widget item(int n, String t, bool done) => Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _stepBadge(n, done),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              t,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: done ? EmbunColors.gold : Colors.white60,
              ),
            ),
          ),
        ],
      ),
    );
    return Row(
      children: [
        item(1, 'Lanjutan', hasAdv),
        item(2, 'Syarat', hasPoin),
        item(3, 'Tempatkan', false),
      ],
    );
  }

  Widget _fuseTray(
    String title,
    String? icon,
    List<(String, int)> items,
    String? picked,
    _Grid g,
    ValueChanged<String?> onPick, {
    required bool faded,
    required String hint,
  }) {
    final total = items.fold<int>(0, (a, e) => a + e.$2);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: tableEdge(_accent, top: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                GameIcon(icon, size: 24),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$total',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                faded
                    ? 'Belum ada kartu lanjutan yang perlu diaktifkan.'
                    : 'Belum ada $_poinName. Belilah di Toko atau Pasar Riset.',
                style: const TextStyle(fontSize: 12, color: Colors.white60),
              ),
            )
          else
            Wrap(
              alignment: WrapAlignment.center,
              spacing: g.gap,
              runSpacing: g.gap,
              children: [
                for (final it in items)
                  CardTile(
                    key: ValueKey('fuse-${it.$1}'),
                    def: widget.defs[it.$1],
                    fallbackName: it.$1,
                    width: g.w,
                    count: it.$2,
                    selected: picked == it.$1,
                    faded: faded,
                    dim: picked != null && picked != it.$1,
                    onTap: () => onPick(picked == it.$1 ? null : it.$1),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _gabungBody({double minW = 96}) {
    final c = _fuseCandidates();
    // Pilihan yang sudah tidak ada di tangan dilepas otomatis.
    final advOk = _fuseAdv != null && c.adv.any((e) => e.$1 == _fuseAdv);
    final poinOk = _fusePoin != null && c.poin.any((e) => e.$1 == _fusePoin);
    final adv = advOk ? _fuseAdv : null;
    final poin = poinOk ? _fusePoin : null;
    if (c.adv.isEmpty && c.poin.isEmpty) {
      return _empty(
        'plus',
        'Belum ada yang bisa digabung',
        'Beli kartu lanjutan dan $_poinName di Toko atau Pasar Riset, '
            'lalu gabungkan di sini.',
      );
    }
    final ready = adv != null && poin != null;
    return LayoutBuilder(
      builder: (context, box) {
        final g = _mejaGrid(box.maxWidth - 24, minW);
        final slotW = ((box.maxWidth - 88) / 2).clamp(1.0, 130.0);
        final advName = adv == null ? null : _cardName(adv);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                child: Column(
                  children: [
                    _fuseSteps(adv != null, poin != null),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fuseSlot(
                          step: 1,
                          label: 'Kartu lanjutan',
                          cardId: adv,
                          w: slotW,
                          faded: poin == null,
                          onClear: () => setState(() => _fuseAdv = null),
                        ),
                        SizedBox(
                          height: slotW * kTallAspect,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Center(
                              child: Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.45),
                                  border: Border.all(
                                    color: EmbunColors.gold.withValues(
                                      alpha: ready ? 1 : 0.5,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  '+',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: EmbunColors.gold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        _fuseSlot(
                          step: 2,
                          label: 'Kartu syarat',
                          cardId: poin,
                          w: slotW,
                          faded: false,
                          onClear: () => setState(() => _fusePoin = null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        ready
                            ? '$advName siap diaktifkan.'
                            : adv == null && poin == null
                            ? 'Pilih satu kartu lanjutan dan satu kartu syarat.'
                            : adv == null
                            ? 'Tinggal pilih kartu lanjutan.'
                            : 'Tinggal pilih kartu syarat.',
                        key: ValueKey('$ready$adv$poin'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: ready ? EmbunColors.gold : Colors.white70,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    EmbunButton(
                      label: ready ? 'Aktifkan kartu' : 'Pilih kedua kartu',
                      icon: 'plus',
                      expand: true,
                      height: 48,
                      kind: ready
                          ? EmbunButtonKind.primary
                          : EmbunButtonKind.secondary,
                      onPressed: ready && !busy ? _doFuse : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _fuseTray(
                'Kartu lanjutan',
                'plus',
                c.adv,
                adv,
                g,
                (id) => setState(() => _fuseAdv = id),
                faded: true,
                hint: 'Belum aktif. Butuh satu kartu syarat.',
              ),
              _fuseTray(
                'Kartu syarat',
                'bulirembun',
                c.poin,
                poin,
                g,
                (id) => setState(() => _fusePoin = id),
                faded: false,
                hint: 'Dipakai untuk mengaktifkan kartu lanjutan.',
              ),
            ],
          ),
        );
      },
    );
  }

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
          offset: Offset((1 - v) * 70, 0),
          child: child,
        ),
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
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                (widget.defs[t['give_card_id']]?['description'] as String?) ??
                    '',
                style: const TextStyle(fontSize: 11, color: Colors.white60),
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
              : () => _run(
                  () => widget.repo.respondTrade(t['id'] as String, false),
                ),
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
    decoration: tableEdge(_accent),
    child: Row(
      children: [
        GameIcon(e['kind'] == 'give' ? 'bulirembun' : 'barter', size: 26),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            e['text'] as String,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'H${e['day']}',
          style: const TextStyle(fontSize: 10, color: Colors.white60),
        ),
      ],
    ),
  );

  Widget _hintCard() => Container(
    padding: const EdgeInsets.all(10),
    child: const Row(
      children: [
        GameIcon('info', size: 28),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Buka daftar warga atau ketuk avatar untuk memberi embun, menukar '
            'kartu, atau mengirim isyarat. Tekan lama (atau klik kanan) '
            'sebuah kartu untuk membaca efeknya.',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ),
      ],
    ),
  );

  Widget _balaiBody() {
    final feed = widget.events
        .where(
          (e) =>
              e['kind'] != 'kabar' &&
              (e['day'] == widget.day || e['day'] == widget.day - 1),
        )
        .toList()
        .reversed
        .toList();
    final inc = _incoming;
    final out = _outgoing;
    final news = widget.events
        .where((e) => e['kind'] == 'kabar' && e['day'] == widget.day)
        .lastOrNull;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (news != null) ...[
          _section('Kabar Pagi', icon: 'announcement'),
          _feedRow(news),
          const SizedBox(height: 6),
        ],
        if (inc.isNotEmpty) ...[
          _section(
            'Tawaran tukar untukmu',
            icon: 'barter',
            trailing: '${inc.length}',
          ),
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
            child: Text(
              'Belum ada yang terjadi...',
              style: TextStyle(color: Colors.white60),
            ),
          )
        else
          for (final e in feed) _feedRow(e),
        const SizedBox(height: 10),
        _hintCard(),
      ],
    );
  }

  // ====================== Ruang kerja siang ======================

  static const _tabIcons = ['store', 'mydeck2', 'plus', 'announcement'];
  static const _tabLabels = ['Toko', 'Meja', 'Gabung', 'Balai'];

  Widget _tabButton(int index, {required bool wide, bool vertical = false}) {
    final active = index == (wide ? _deskTab : tab);
    final badge = switch (index) {
      _tabMeja => widget.hand.length,
      _tabGabung => _readyPairs,
      _tabBalai => _incoming.length,
      _ => 0,
    };
    final label = _tabLabels[index];

    final icon = Badge(
      isLabelVisible: badge > 0,
      label: Text('$badge'),
      backgroundColor: index == _tabBalai ? EmbunColors.blood : _accent,
      textColor: const Color(0xFF07130F),
      child: GameIcon(_tabIcons[index], size: vertical ? 16 : 22),
    );
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: vertical ? 10 : 11,
        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
        color: active ? EmbunColors.cream : Colors.white70,
      ),
    );

    return Semantics(
      selected: active,
      button: true,
      label: badge > 0 ? '$label, $badge' : label,
      child: Material(
        key: index == _tabMeja ? _mejaKey : null,
        color: Colors.transparent,
        child: Ink(
          decoration: active ? tableEdge(_accent, vertical: vertical) : null,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _goTab(index),
            child: ExcludeSemantics(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 2,
                  vertical: vertical ? 0 : 4,
                ),
                child: vertical
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          icon,
                          const SizedBox(width: 3),
                          Flexible(child: text),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [icon, const SizedBox(height: 2), text],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  int get _readyPairs {
    final choices = _fuseCandidates();
    final advanced = choices.adv.fold<int>(0, (sum, card) => sum + card.$2);
    final points = choices.poin.fold<int>(0, (sum, card) => sum + card.$2);
    return min(advanced, points);
  }

  Widget _endButton() {
    final ready = widget.iAmReady;
    if (ready) {
      return Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Menunggu ${widget.readyCount}/${widget.total}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              _progress(height: 3),
            ],
          ),
        ),
      );
    }
    return EmbunButton(
      label: 'Akhiri hari',
      expand: true,
      height: 45,
      kind: _remaining == 0 || widget.jailed
          ? EmbunButtonKind.primary
          : EmbunButtonKind.secondary,
      onPressed: busy ? null : _endDay,
    );
  }

  Widget _dock() => LayoutBuilder(
    builder: (context, box) {
      final scale = MediaQuery.textScalerOf(context).scale(15) / 15;
      final stacked = box.maxWidth < 390 && scale > 1.25;
      final tabs = Row(
        children: [
          for (final index in const [_tabToko, _tabMeja, _tabGabung, _tabBalai])
            Expanded(child: _tabButton(index, wide: false)),
        ],
      );
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: tableEdge(_accent),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [tabs, const SizedBox(height: 4), _endButton()],
              )
            : Row(
                children: [
                  Expanded(child: tabs),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: box.maxWidth < 360 ? 110 : 132,
                    child: _endButton(),
                  ),
                ],
              ),
      );
    },
  );

  Widget _sideRail() => Container(
    width: 80,
    padding: const EdgeInsets.all(4),
    child: Column(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final index in const [
                _tabToko,
                _tabMeja,
                _tabGabung,
                _tabBalai,
              ])
                Expanded(child: _tabButton(index, wide: false, vertical: true)),
            ],
          ),
        ),
        if (widget.iAmReady)
          Tooltip(
            message: 'Menunggu ${widget.readyCount}/${widget.total} pemain',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${widget.readyCount}/${widget.total}', style: dayCaption),
                const SizedBox(height: 3),
                _progress(height: 3),
              ],
            ),
          )
        else
          IconButton(
            tooltip: 'Akhiri hari',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF214B37),
              padding: EdgeInsets.zero,
              minimumSize: const Size(40, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: busy ? null : _endDay,
            icon: const GameIcon('endday', size: 26),
          ),
      ],
    ),
  );

  Widget _handPage(int index, {bool wide = false}) {
    final dense = _lastMode == _Mode.landscape;
    final icon = _tabIcons[index];
    final title = switch (index) {
      _tabMeja => 'Meja kartu',
      _tabGabung => 'Gabung kartu',
      _ => 'Balai Desa',
    };
    final content = switch (index) {
      _tabMeja => _mejaBody(minW: wide ? 76 : 85),
      _tabGabung => _gabungBody(minW: wide ? 76 : 85),
      _ => _balaiBody(),
    };
    return Padding(
      padding: EdgeInsets.all(dense ? 7 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dayHeading(
            icon,
            title,
            trailing: index == _tabMeja
                ? _chip('mydeck2', '${widget.hand.length} kartu')
                : null,
          ),
          SizedBox(height: dense ? 4 : 8),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _pages() => PageView(
    controller: _pager,
    onPageChanged: (index) {
      if (tab != index) {
        setState(() {
          tab = index;
          if (index != _tabToko) _deskTab = index;
        });
      }
    },
    children: [
      _shopPanel(),
      for (final index in const [_tabMeja, _tabGabung, _tabBalai])
        _handPage(index),
    ],
  );

  Widget _desktopRail() => Container(
    decoration: tableEdge(_accent, vertical: true),
    padding: const EdgeInsets.only(left: 7, bottom: 5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final index in const [_tabMeja, _tabGabung, _tabBalai])
              Expanded(child: _tabButton(index, wide: true)),
          ],
        ),
        Expanded(child: _handPage(_deskTab, wide: true)),
        _endButton(),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final previous = _lastMode;
      _lastMode = _modeFor(box);
      if (previous != _lastMode && _lastMode != _Mode.wide) {
        final page = tab;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pager.hasClients && tab == page) {
            _pager.jumpToPage(page);
          }
        });
      }
      switch (_lastMode) {
        case _Mode.phone:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _dock(),
              const SizedBox(height: 2),
              Expanded(child: _pages()),
            ],
          );
        case _Mode.landscape:
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sideRail(),
              const SizedBox(width: 7),
              Expanded(child: _pages()),
            ],
          );
        case _Mode.wide:
          final width = (box.maxWidth * 0.32).clamp(292.0, 400.0).toDouble();
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _shopPanel()),
              const SizedBox(width: 12),
              SizedBox(width: width, child: _desktopRail()),
            ],
          );
      }
    },
  );
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
