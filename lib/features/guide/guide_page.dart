import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../../data/lobby_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import '../table/ability_panel.dart';
import '../table/card_tile.dart';
import '../table/flip_card.dart';

/// Panduan layar penuh dengan tiga tab: Cara Bermain, Karakter, Kartu Item.
/// Dibuka dari menu lobi maupun dari menu di dalam permainan.
///
///   Navigator.of(context).push(
///       MaterialPageRoute(builder: (_) => const GuidePage()));
///
/// Hierarki: (1) tab utama di bawah judul, (2) tab penanda buku per fraksi
/// di atas panel, (3) kontrol segmen untuk jenis kartu, (4) grid kartu.
class GuidePage extends StatelessWidget {
  final int initialTab;
  const GuidePage({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      initialIndex: initialTab,
      child: Scaffold(
        backgroundColor: EmbunColors.bg,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Backdrop(path: landscapePath(30), dim: 0.88),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Kembali',
                          onPressed: () => Navigator.of(context).maybePop(),
                          color: EmbunColors.gold,
                          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        ),
                        const GameIcon('info', size: 30),
                        const SizedBox(width: 8),
                        const Text(
                          'Panduan',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: EmbunColors.gold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    indicatorColor: EmbunColors.gold,
                    indicatorWeight: 3,
                    labelColor: EmbunColors.gold,
                    unselectedLabelColor: Colors.white60,
                    dividerColor: EmbunColors.goldDim.withValues(alpha: 0.35),
                    labelStyle: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w800),
                    unselectedLabelStyle: const TextStyle(fontSize: 13.5),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                    // Label menyusut di layar sempit, tidak pernah terpotong.
                    tabs: const [
                      Tab(child: _TabLabel('Cara Bermain')),
                      Tab(child: _TabLabel('Karakter')),
                      Tab(child: _TabLabel('Kartu Item')),
                      Tab(child: _TabLabel('Kemampuan')),
                    ],
                  ),
                  const Expanded(
                    child: TabBarView(
                      children: [
                        _HowToTab(),
                        _CharactersTab(),
                        _ItemsTab(),
                        _AbilitiesTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// Bahan dasar
// ====================================================================

const _panelBg = Color(0xFF112820);
const _twoColBreakpoint = 900.0;
const _twoColMaxWidth = 1120.0;

class _TabLabel extends StatelessWidget {
  final String text;
  const _TabLabel(this.text);
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(text, maxLines: 1),
  );
}

/// Kemunculan berjenjang: memudar, bergeser, dan membesar dari sedikit lebih
/// kecil. Dipakai untuk bagian halaman, langkah, dan sel grid kartu.
class _Reveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double dx;
  final double dy;
  final double scaleFrom;
  final Curve curve;
  const _Reveal({
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 850),
    this.dx = 0,
    this.dy = 28,
    this.scaleFrom = 0.95,
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: widget.duration);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) {
      if (_c.isCompleted) return child!;
      final v = widget.curve.transform(_c.value);
      final o = Curves.easeOut
          .transform((_c.value / 0.55).clamp(0.0, 1.0).toDouble());
      return Opacity(
        opacity: o,
        child: Transform.translate(
          offset: Offset((1 - v) * widget.dx, (1 - v) * widget.dy),
          child: Transform.scale(
            scale: widget.scaleFrom + (1 - widget.scaleFrom) * v,
            child: child,
          ),
        ),
      );
    },
  );
}

/// Angka yang berhitung naik dari 0; teks non-angka tampil apa adanya.
class _CountUp extends StatelessWidget {
  final String text;
  final TextStyle style;
  const _CountUp(this.text, {required this.style});

  @override
  Widget build(BuildContext context) {
    final n = int.tryParse(text);
    if (n == null) return Text(text, style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: n.toDouble()),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text('${v.round()}', style: style),
    );
  }
}

/// Halaman bergulir yang dipusatkan. Di layar lebar (>= 900 px) dan bila
/// [column] diberikan, bagian dibagi dua kolom (0 = kiri, 1 = kanan);
/// di layar sempit semuanya satu kolom dengan urutan aslinya. Tiap bagian
/// muncul berjenjang.
class _Page extends StatelessWidget {
  final List<Widget> children;
  final Widget? header;
  final int Function(int index)? column;
  final double maxWidth;
  const _Page({
    required this.children,
    this.header,
    this.column,
    this.maxWidth = 1000,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
    final twoCol = column != null && c.maxWidth >= _twoColBreakpoint;
    final w = twoCol ? _twoColMaxWidth : maxWidth;
    final pad = c.maxWidth < 420 ? 10.0 : 14.0;

    Widget stagger(int i, Widget child) => _Reveal(
      delay: Duration(milliseconds: 110 * min(i + 1, 7)),
      child: child,
    );

    final Widget body;
    if (twoCol) {
      final cols = <List<Widget>>[[], []];
      for (var i = 0; i < children.length; i++) {
        cols[column!(i).clamp(0, 1).toInt()].add(stagger(i, children[i]));
      }
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: cols[0])),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: cols[1])),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) stagger(i, children[i]),
        ],
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: w),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pad, 14, pad, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (header != null) _Reveal(dy: 18, child: header!),
              body,
            ],
          ),
        ),
      ),
    );
  });
}

class _Section extends StatelessWidget {
  final String icon;
  final String title;
  final List<Widget> children;
  final Color accent;
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
    this.accent = EmbunColors.gold,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: OrnatePanel(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(icon: icon, title: title),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}

/// Teks dengan **tebal** sederhana.
Widget _rich(String s,
    {double size = 13.5, Color? color, Color bold = EmbunColors.gold}) {
  final parts = s.split('**');
  return Text.rich(
    TextSpan(
      style: TextStyle(fontSize: size, height: 1.45, color: color),
      children: [
        for (var i = 0; i < parts.length; i++)
          TextSpan(
            text: parts[i],
            style: i.isOdd
                ? TextStyle(fontWeight: FontWeight.w800, color: bold)
                : null,
          ),
      ],
    ),
  );
}

Widget _para(String s) =>
    Padding(padding: const EdgeInsets.only(bottom: 8), child: _rich(s));

Widget _bullet(String s, {Color dot = EmbunColors.gold, Color? bold}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1, right: 8, left: 2),
            child: Text('•', style: TextStyle(color: dot)),
          ),
          Expanded(child: _rich(s, bold: bold ?? EmbunColors.gold)),
        ],
      ),
    );

/// Satu langkah pada garis waktu: lingkaran bernomor dan garis penyambung.
Widget _step(int n, String title, String body, {bool last = false}) =>
    _Reveal(
      dx: -20,
      dy: 0,
      scaleFrom: 0.98,
      delay: Duration(milliseconds: 320 + 120 * (n - 1)),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 30,
              child: Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.45),
                      border: Border.all(color: EmbunColors.gold, width: 1.5),
                    ),
                    child: Text('$n',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: EmbunColors.gold)),
                  ),
                  if (!last)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: EmbunColors.goldDim.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: last ? 0 : 16, top: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: EmbunColors.cream)),
                    const SizedBox(height: 3),
                    _rich(body, size: 13, color: Colors.white70),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

/// Baris info berikon dalam kotak gelap (jenis kartu, dsb.).
Widget _infoRow(String icon, String title, String text) => Container(
  margin: const EdgeInsets.only(bottom: 8),
  padding: const EdgeInsets.all(10),
  decoration: BoxDecoration(
    color: Colors.black.withValues(alpha: 0.28),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: EmbunColors.goldDim.withValues(alpha: 0.3)),
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GameIcon(icon, size: 34),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: EmbunColors.cream)),
            const SizedBox(height: 2),
            _rich(text, size: 12.5, color: Colors.white70),
          ],
        ),
      ),
    ],
  ),
);

/// Grid rapi: kolom selalu sama lebar, memenuhi lebar yang tersedia, dan baris
/// terakhir tetap sejajar (sel kosong menjaga lebar kolom).
class _Grid extends StatelessWidget {
  final int count;
  final Widget Function(int index, double cellWidth) item;
  final double minCell;
  static const double gap = 12;
  static const double rowGap = 18;
  static const int maxCols = 6;

  const _Grid({
    super.key,
    required this.count,
    required this.item,
    this.minCell = 112,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
    final avail = c.maxWidth.isFinite ? c.maxWidth : 360.0;
    final cols =
    ((avail + gap) / (minCell + gap)).floor().clamp(2, maxCols).toInt();
    final w = ((avail - gap * (cols - 1)) / cols).floorToDouble();
    final rows = <Widget>[];
    for (var start = 0; start < count; start += cols) {
      rows.add(Padding(
        padding: EdgeInsets.only(top: start == 0 ? 0 : rowGap),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var j = 0; j < cols; j++) ...[
              if (j > 0) SizedBox(width: gap),
              SizedBox(
                width: w,
                // Kartu muncul membal, bergelombang per baris dan kolom.
                child: start + j < count
                    ? _GridOrder(
                  order: j,
                  child: _Reveal(
                    dy: 24,
                    scaleFrom: 0.82,
                    curve: Curves.easeOutBack,
                    duration: const Duration(milliseconds: 700),
                    delay: Duration(
                        milliseconds:
                        min(60 * (start ~/ cols) + 55 * j, 700)),
                    child: item(start + j, w),
                  ),
                )
                    : null,
              ),
            ],
          ],
        ),
      ));
    }
    return Column(children: rows);
  });
}

/// Nama di bawah kartu: tinggi tetap (dua baris) supaya semua sel sejajar.
Widget _caption(String text, Color color) => SizedBox(
  height: 36,
  child: Center(
    child: Text(
      text,
      maxLines: 2,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
          fontSize: 12.5, height: 1.2, fontWeight: FontWeight.w600, color: color),
    ),
  ),
);

/// Urutan kolom sebuah sel di [_Grid]; dipakai [_GuideFlip] supaya kartu satu
/// baris berbalik bergiliran (kiri ke kanan), bukan serentak.
class _GridOrder extends InheritedWidget {
  final int order;
  const _GridOrder({required this.order, required super.child});

  static int of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GridOrder>()?.order ?? 0;

  @override
  bool updateShouldNotify(_GridOrder old) => old.order != order;
}

/// Kartu di Guide: tampil sebagai PUNGGUNG dulu, lalu berbalik menjadi muka.
/// Baru berbalik saat kartunya benar-benar terlihat di layar (bukan baris
/// yang masih jauh di bawah, dan bukan tab yang belum dibuka), supaya
/// animasinya tidak terbuang sebelum dilihat. Setelah selesai, [front]
/// dikembalikan apa adanya, jadi ketukannya tetap berfungsi.
class _GuideFlip extends StatefulWidget {
  final double width;
  final double height;
  final String? backPath;
  final bool dark;
  final Color glow;
  final Widget front;
  const _GuideFlip({
    required this.width,
    required this.height,
    required this.front,
    this.backPath,
    this.dark = false,
    this.glow = const Color(0xFFFFD866),
  });

  @override
  State<_GuideFlip> createState() => _GuideFlipState();
}

class _GuideFlipState extends State<_GuideFlip> {
  bool _revealed = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // Cek berkala: tahan bila scroll atau pergantian tab terjadi setelah
    // kartu dibuat. Berhenti sendiri begitu kartu terlihat.
    _poll = Timer.periodic(const Duration(milliseconds: 200), (_) => _check());
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (_revealed || !mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final size = MediaQuery.sizeOf(context);
    final o = box.localToGlobal(Offset.zero);
    final seen = o.dy < size.height - 40 &&
        o.dy + box.size.height > 0 &&
        o.dx < size.width &&
        o.dx + box.size.width > 0;
    if (!seen) return;
    _poll?.cancel();
    setState(() => _revealed = true);
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FlipCard(
    index: _GridOrder.of(context),
    width: widget.width,
    height: widget.height,
    revealed: _revealed,
    dark: widget.dark,
    glow: widget.glow,
    backPath: widget.backPath,
    front: widget.front,
  );
}

// ====================================================================
// Tab penanda buku
// ====================================================================

class _BmTab {
  final String label;
  final String? count;
  final Color accent;
  const _BmTab(this.label, this.accent, {this.count});
}

/// Panel dengan tab penanda buku di atasnya. Tab terpilih menyatu dengan
/// panel (tanpa garis pemisah) dan bergaris warna fraksi; tab lain lebih
/// pendek dan redup. Lebar tab sama rata.
class _BookmarkPanel extends StatelessWidget {
  final List<_BmTab> tabs;
  final int selected;
  final ValueChanged<int> onSelect;
  final Widget child;
  const _BookmarkPanel({
    required this.tabs,
    required this.selected,
    required this.onSelect,
    required this.child,
  });

  static const _tabH = 48.0;
  static const _edge = 1.5;

  Widget _tab(int i) {
    final t = tabs[i];
    final sel = i == selected;
    final edgeColor = sel ? t.accent : t.accent.withValues(alpha: 0.4);
    const topRound = BorderRadius.vertical(top: Radius.circular(14));
    const innerRound =
    BorderRadius.vertical(top: Radius.circular(14 - _edge));

    final label = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              t.label,
              style: TextStyle(
                fontSize: sel ? 14.5 : 13,
                fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                color: sel ? t.accent : Colors.white60,
              ),
            ),
          ),
        ),
        if (t.count != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: (sel ? t.accent : Colors.white)
                  .withValues(alpha: sel ? 0.18 : 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(t.count!,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: sel ? t.accent : Colors.white54)),
          ),
        ],
      ],
    );

    return Padding(
      padding: EdgeInsets.only(
          left: i == 0 ? 0 : 3, right: i == tabs.length - 1 ? 0 : 3),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (i != selected) {
            HapticFeedback.selectionClick();
            onSelect(i);
          }
        },
        child: Align(
          alignment: Alignment.bottomCenter,
          // Tab terpilih menutup garis atas panel; yang lain bertumpu di atasnya.
          // Garis tab dibuat dari dua lapis (luar = warna garis, dalam = warna
          // isi) supaya sisi bawah terbuka tanpa Border tak seragam.
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: sel ? _tabH : _tabH - 10,
            margin: EdgeInsets.only(bottom: sel ? 0 : _edge),
            decoration: BoxDecoration(color: edgeColor, borderRadius: topRound),
            padding: const EdgeInsets.fromLTRB(_edge, _edge, _edge, 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: sel ? _panelBg : const Color(0xFF0A1511),
                borderRadius: innerRound,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: label,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final acc = tabs[selected].accent;
    final last = tabs.length - 1;
    const round = Radius.circular(16);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: _tabH - _edge),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
            decoration: BoxDecoration(
              color: _panelBg,
              borderRadius: BorderRadius.only(
                topLeft: selected == 0 ? Radius.zero : round,
                topRight: selected == last ? Radius.zero : round,
                bottomLeft: round,
                bottomRight: round,
              ),
              border: Border.all(color: acc, width: _edge),
              boxShadow: [
                BoxShadow(
                    color: acc.withValues(alpha: 0.12), blurRadius: 18),
              ],
            ),
            // Pindah fraksi: isi lama memudar, isi baru meluncur masuk, tinggi
            // panel menyesuaikan mulus, dan warna garis ikut berganti.
            child: AnimatedSize(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 380),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeIn,
                layoutBuilder: (cur, prev) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...prev, ?cur],
                ),
                transitionBuilder: (w, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween<Offset>(
                        begin: const Offset(0.04, 0), end: Offset.zero)
                        .animate(a),
                    child: w,
                  ),
                ),
                child: KeyedSubtree(key: ValueKey(selected), child: child),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: _tabH,
          child: Row(
            children: [for (var i = 0; i < tabs.length; i++) Expanded(child: _tab(i))],
          ),
        ),
      ],
    );
  }
}

/// Kontrol segmen satu baris: sel sama lebar, label dan jumlah bertumpuk.
class _Segmented extends StatelessWidget {
  final List<String> labels;
  final List<int> counts;
  final int selected;
  final Color accent;
  final ValueChanged<int> onSelect;
  const _Segmented({
    required this.labels,
    required this.counts,
    required this.selected,
    required this.accent,
    required this.onSelect,
  });

  /// Lebar minimal satu sel; di bawah itu baris dibuat bisa digeser.
  static const _minCell = 84.0;

  Widget _cell(int i) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {
      if (i != selected) {
        HapticFeedback.selectionClick();
        onSelect(i);
      }
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 46,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: i == selected
            ? accent.withValues(alpha: 0.22)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border:
        Border.all(color: i == selected ? accent : Colors.transparent),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                labels[i],
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight:
                  i == selected ? FontWeight.w800 : FontWeight.w600,
                  color: i == selected ? accent : Colors.white70,
                ),
              ),
              Text(
                '${counts[i]}',
                style: TextStyle(
                  fontSize: 10.5,
                  color: i == selected
                      ? accent.withValues(alpha: 0.9)
                      : Colors.white38,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: EmbunColors.goldDim.withValues(alpha: 0.35)),
    ),
    child: LayoutBuilder(builder: (context, c) {
      final scroll = c.maxWidth / labels.length < _minCell;
      if (!scroll) {
        return Row(
          children: [
            for (var i = 0; i < labels.length; i++) Expanded(child: _cell(i)),
          ],
        );
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              SizedBox(width: _minCell, child: _cell(i)),
          ],
        ),
      );
    }),
  );
}

/// Judul kelompok di dalam panel: ikon, judul, jumlah, dan garis.
Widget _groupHeader(String icon, String title, int count, Color accent,
    {String? help}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GameIcon(icon, size: 28),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: accent)),
              const SizedBox(width: 8),
              Text('$count kartu',
                  style: const TextStyle(fontSize: 12, color: Colors.white54)),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 1,
                  color: accent.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
          if (help != null) ...[
            const SizedBox(height: 6),
            Text(help,
                style: const TextStyle(
                    fontSize: 12, height: 1.4, color: Colors.white60)),
          ],
        ],
      ),
    );

// ====================================================================
// Tab 1: Cara Bermain
// ====================================================================

class _HowToTab extends StatelessWidget {
  const _HowToTab();

  Widget _stats() {
    const items = [
      ('3-8', 'pemain'),
      ('12', 'hari'),
      ('3', 'hari / siklus'),
      ('2', 'nyawa'),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EmbunColors.goldDim.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(
                  width: 1,
                  height: 34,
                  color: EmbunColors.goldDim.withValues(alpha: 0.35)),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _CountUp(items[i].$1,
                        style: const TextStyle(
                            fontSize: 24,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            color: EmbunColors.gold)),
                  ),
                  const SizedBox(height: 2),
                  Text(items[i].$2,
                      style: const TextStyle(
                          fontSize: 11.5, color: Colors.white60)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _winCard(String title, String icon, Color accent, List<String> lines) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.65), width: 1.3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GameIcon(icon, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: accent)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final l in lines) _bullet(l, dot: accent, bold: accent),
          ],
        ),
      );

  Widget _wins() {
    final good = _winCard('Warga menang', 'helaidaun', EmbunColors.leaf, const [
      'Daun Hayu mencapai **30**.',
      'Hari terakhir berakhir dengan daun **di atas batas** (12 hari: **20**).',
      'Si Terbisik **tertangkap**.',
    ]);
    final bad = _winCard('Si Terbisik menang', 'danger', EmbunColors.mist, const [
      'Daun Hayu **habis**.',
      'Hari terakhir berakhir dengan daun **di bawah batas**.',
      'Desa **tinggal dua orang**.',
    ]);
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 520) {
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: good),
              const SizedBox(width: 10),
              Expanded(child: bad),
            ],
          ),
        );
      }
      return Column(children: [good, const SizedBox(height: 10), bad]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _Page(
      maxWidth: 780,
      header: _stats(),
      // Layar lebar: kiri = Tujuan, Siklus, Kartu lanjutan; kanan = sisanya.
      column: (i) => const [0, 1, 0, 1, 0, 1, 1][i],
      children: [
        _Section(
          icon: 'helaidaun',
          title: 'Tujuan',
          children: [
            _para('**Hayu**, pohon tua desa, sedang meredup. Jumlah daunnya '
                'adalah nyawa desa: warga berusaha menyelamatkannya, '
                '**Si Terbisik** diam-diam menghancurkannya.'),
            const SizedBox(height: 4),
            _wins(),
          ],
        ),
        _Section(
          icon: 'persona',
          title: 'Peran',
          children: [
            _bullet('Satu pemain acak menjadi Si Terbisik, sisanya warga. '
                'Hanya kamu yang tahu perannya.'),
            _bullet('Namamu diacak menjadi **nama kartu karakter** '
                '(mis. "Guru", "Nelayan 2").'),
            _bullet('Warga berbelanja dengan **tetes embun**, Si Terbisik '
                'dengan **bulir hitam**.'),
            _bullet('Daun awal Hayu: 10 dikurangi jumlah pemain '
                '(minimal 4).'),
          ],
        ),
        _Section(
          icon: 'hari',
          title: 'Satu siklus (3 hari)',
          children: [
            _para('Host memilih lama sesi: 6, 12 (bawaan), 18, atau 24 hari. '
                'Batas daun untuk menang: **12 / 20 / 24 / 26**. Tiap siklus: **2 hari biasa** lalu '
                '**1 malam persembahan**.'),
            const SizedBox(height: 4),
            _step(
                1,
                'Hari biasa (dua hari)',
                'Beli **1 kartu per hari** di Pasar Pagi (4 tawaran acak). '
                    'Boleh memberi embun (1 sampai 3, maks 3 kali sehari), '
                    'menukar kartu, mengirim isyarat, dan mengobrol. Tekan '
                    '"Akhiri hari" bila selesai.'),
            _step(
                2,
                'Malam persembahan (hari 3, 6, 9, 12, dst.)',
                'Persembahkan **1 atau 2 kartu** ke Hayu, tanpa nama '
                    'pemilik. Si Terbisik **wajib menyertakan Roti Surplus** '
                    'sebagai samaran.'),
            _step(
                3,
                'Efek',
                'Kartu dilempar acak; hasilnya muncul sebagai gelembung '
                    'baik atau buruk. Kabut ikut menggerogoti daun. Lalu '
                    'terbuka **berapa** kartu tiap pemain, bukan apa.'),
            _step(
                4,
                'Musyawarah',
                'Bandingkan petunjuk lewat obrolan: pemeriksaan pribadi, '
                    'desas-desus, kabar pagi, jumlah kartu.'),
            _step(
                5,
                'Pemungutan suara',
                'Tuduh satu orang atau tidak memilih. Tuduhan sah bila '
                    'mendapat **lebih dari separuh** suara pemain yang '
                    'masih di desa.',
                last: true),
          ],
        ),
        _Section(
          icon: 'bulirembun',
          title: 'Embun dan kartu',
          children: [
            _bullet('Embun bertambah tiap pagi sesuai **laju** (awal 3). '
                'Pagi pertama tiap siklus ada bonus +5.'),
            _bullet('**Perlindungan** menahan serangan pada malam itu saja.'),
            const SizedBox(height: 4),
            _infoRow('donations', 'Persembahan',
                'Efek langsung saat dilempar ke Hayu: menambah atau '
                    'mengurangi daun, perlindungan, mencuri embun.'),
            _infoRow('item', 'Sekali pakai (warga)',
                'Alat periksa. Hasilnya hanya kamu yang tahu, dan tidak '
                    'selalu benar.'),
            _infoRow('plus', 'Penguat',
                'Menaikkan laju embun (atau bulir hitam) untuk seterusnya.'),
            _infoRow('plus', 'Kartu lanjutan',
                'Harus digabung dengan kartu poin dulu. Lihat bagian di '
                    'bawah.'),
            _infoRow('item', 'Kartu kuning (warga)',
                'Dipakai di Meja pada hari biasa, bukan dipersembahkan: '
                    'perisai, cermin, embun, nyawa, atau panah.'),
            _infoRow('danger', 'Serangan malam (Si Terbisik)',
                'Dilancarkan saat malam tiba. Desa hanya tahu ada serangan, '
                    'bukan sasarannya.'),
            const SizedBox(height: 2),
            _bullet('Yang bisa dipersembahkan: Persembahan, Sekali pakai, '
                'Penguat, dan kartu lanjutan yang AKTIF (maks 2 per malam).'),
            _bullet('Tekan lama kartu untuk membaca efeknya. Daftar lengkap '
                'ada di tab **Kartu Item**.'),
          ],
        ),
        _Section(
          icon: 'plus',
          title: 'Kartu lanjutan (kombinasi)',
          children: [
            _para('Kartu lanjutan harus **digabung** dengan satu **kartu '
                'poin** sebelum bisa dipersembahkan.'),
            _bullet('**Warga**: Kartu Regenerasi + Poin Regenerasi.'),
            _bullet('**Si Terbisik**: Kartu Rekayasa + Poin DNA.'),
            const SizedBox(height: 6),
            _step(
                1,
                'Beli keduanya',
                'Keduanya muncul acak di Pasar Pagi. Kartu lanjutan yang '
                    'belum digabung tampak pudar, berlabel "Butuh poin".'),
            _step(
                2,
                'Gabungkan di tab Gabung',
                'Hari biasa: buka tab **Gabung**, letakkan satu kartu '
                    'lanjutan dan satu kartu syarat (poin) di petak, lalu '
                    'tekan "Tempatkan". Satu poin habis dan kartu menjadi '
                    '**AKTIF**. Tidak diumumkan, dan boleh walau sedang '
                    'dikurung.'),
            _step(
                3,
                'Persembahkan',
                'Kartu AKTIF dipersembahkan seperti kartu biasa. Yang belum '
                    'aktif ditolak.',
                last: true),
            const SizedBox(height: 10),
            _bullet('**Harga**: kartu lanjutan 5 + poin 16, sekitar 21 '
                'embun per kombinasi.'),
            _bullet('**Kapsul DNA** (Si Terbisik) setara 2 Poin DNA: cukup '
                'untuk dua kartu Rekayasa.'),
            _bullet('Kartu yang ditukar atau dicuri **kehilangan status '
                'AKTIF**. Kartu poin yang mahal juga mudah jadi sasaran '
                'Kerikil Panas dan Curian Malam, jadi gabungkan secepatnya.'),
          ],
        ),
        _Section(
          icon: 'lock',
          title: 'Dua nyawa, kurungan, dan keluar',
          accent: EmbunColors.blood,
          children: [
            _para('Tiap pemain punya **2 nyawa** (dua hati di avatar). '
                'Dituduh mayoritas = kehilangan satu nyawa, dan Hayu '
                'kehilangan 1 daun.'),
            _step(
                1,
                'Tuduhan pertama: dikurung',
                'Dikurung **sampai musyawarah berikutnya**. Tidak bisa '
                    'membeli atau menawarkan tukar kartu, tetapi tetap bisa '
                    'menerima kartu, mempersembahkan, bicara, dan memilih.'),
            _step(
                2,
                'Tuduhan kedua: tertangkap atau keluar',
                'Si Terbisik **tertangkap** dan warga menang. Warga '
                    '**keluar dari desa**: perannya terbuka dan ia hanya '
                    'bisa menonton.',
                last: true),
            _bullet('Pemain tersisa kurang dari 3: **Si Terbisik menang**. '
                'Pikirkan baik-baik sebelum menuduh orang yang sama dua '
                'kali.',
                dot: EmbunColors.blood, bold: EmbunColors.blood),
          ],
        ),
        _Section(
          icon: 'info',
          title: 'Tips',
          children: [
            _bullet('Satu petunjuk belum tentu benar: Topeng, Cermin Khayal, '
                'dan Boneka Sawah bisa mengelabui pemeriksaan.'),
            _bullet('Perhatikan **siapa yang jarang membeli** atau selalu '
                'menyerahkan jumlah kartu yang sama.'),
            _bullet('Isyarat (emoji) bisa ke semua orang atau satu pemain, '
                'maks 8 per hari.'),
            _bullet('Si Terbisik: tidak perlu menyerang tiap malam. '
                'Persembahan yang tampak biasa adalah samaran terbaik.'),
          ],
        ),
      ],
    );
  }
}

// ====================================================================
// Tab 2: Karakter
// ====================================================================

class _Char {
  final String? path;
  final String label;
  const _Char(this.path, this.label);
}

List<_Char> _protagonists() {
  final stems =
  protagonistStems().where((s) => s != 'default').toList();
  final counts = <String, int>{};
  for (final s in stems) {
    counts[characterTitle(s)] = (counts[characterTitle(s)] ?? 0) + 1;
  }
  final seen = <String, int>{};
  return [
    for (final s in stems)
          () {
        final t = characterTitle(s);
        final i = seen[t] = (seen[t] ?? 0) + 1;
        return _Char(protagonistPath(s), (counts[t] ?? 1) > 1 ? '$t $i' : t);
      }(),
  ];
}

List<_Char> _antagonists() {
  final stems = AssetCatalog.I.stems(antagonisDir);
  return [
    for (var i = 0; i < stems.length; i++)
      _Char(AssetCatalog.I.file(antagonisDir, stems[i]),
          stems.length > 1 ? 'Si Terbisik ${i + 1}' : 'Si Terbisik'),
  ];
}

void _previewCharacter(BuildContext context, _Char c, {required bool dark}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: OrnatePanel(
          accent: dark ? EmbunColors.mist : EmbunColors.gold,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CardArt(
                  path: c.path,
                  width: min(210.0, MediaQuery.sizeOf(ctx).height * 0.42),
                  glow: dark ? EmbunColors.mist : EmbunColors.leaf,
                ),
                const SizedBox(height: 14),
                Text(c.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: EmbunColors.gold)),
                const SizedBox(height: 6),
                Text(
                  dark
                      ? 'Wajah gelap Si Terbisik. Hanya pemiliknya yang '
                      'melihatnya sampai permainan berakhir.'
                      : 'Kartu karakter warga. Dibagikan acak di awal, dan '
                      'namamu selama permainan mengikuti kartu ini.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12.5, height: 1.4, color: Colors.white70),
                ),
                const SizedBox(height: 14),
                EmbunButton(
                  label: 'Tutup',
                  icon: 'silang',
                  kind: EmbunButtonKind.secondary,
                  height: 46,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _CharactersTab extends StatefulWidget {
  const _CharactersTab();
  @override
  State<_CharactersTab> createState() => _CharactersTabState();
}

class _CharactersTabState extends State<_CharactersTab>
    with AutomaticKeepAliveClientMixin {
  int faction = 0; // 0 = warga (baik), 1 = Si Terbisik (jahat)

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final good = _protagonists();
    final bad = _antagonists();
    final dark = faction == 1;
    final list = dark ? bad : good;
    final accent = dark ? EmbunColors.mist : EmbunColors.leaf;

    return _Page(
      children: [
        _BookmarkPanel(
          tabs: [
            _BmTab('Warga (Baik)', EmbunColors.leaf, count: '${good.length}'),
            _BmTab('Si Terbisik (Jahat)', EmbunColors.mist,
                count: '${bad.length}'),
          ],
          selected: faction,
          onSelect: (i) => setState(() => faction = i),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _groupHeader(
                dark ? 'danger' : 'persona',
                dark ? 'Wajah gelap' : 'Kartu karakter',
                list.length,
                accent,
                help: dark
                    ? 'Dipakai Si Terbisik di layarnya sendiri; pemain lain '
                    'tetap melihat kartu karakter biasa. Terungkap saat '
                    'permainan berakhir. Ketuk kartu untuk memperbesar.'
                    : 'Dibagikan acak di awal; namamu mengikuti kartu ini '
                    '(diberi nomor bila kembar). Hanya penampilan, tidak '
                    'mengubah kekuatan. Ketuk kartu untuk memperbesar.',
              ),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('Belum ada gambar karakter.',
                        style: TextStyle(color: Colors.white54)),
                  ),
                )
              else
                _Grid(
                  key: ValueKey('char-$faction'),
                  count: list.length,
                  minCell: 108,
                  item: (i, w) => GestureDetector(
                    onTap: () => _previewCharacter(context, list[i], dark: dark),
                    child: Column(
                      children: [
                        _GuideFlip(
                          width: w,
                          height: w * cardAspectFor(list[i].path),
                          backPath: cardBackPath(dark: dark),
                          dark: dark,
                          glow: dark ? EmbunColors.mist : EmbunColors.leaf,
                          front: CardArt(
                            path: list[i].path,
                            width: w,
                            glow: dark ? EmbunColors.mist : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _caption(list[i].label,
                            dark ? EmbunColors.mist : EmbunColors.cream),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ====================================================================
// Tab 3: Kartu Item
// ====================================================================

/// Disimpan selama aplikasi hidup supaya tab tidak memuat ulang.
Map<String, Map<String, dynamic>>? _defsCache;

/// Kelompok kartu di tab ini. Kartu poin dan kartu lanjutan digabung dalam
/// satu kelompok "Kombinasi" supaya segmen tetap sedikit.
const _itemGroups = [
  'persembahan',
  'sekali_pakai',
  'penguat',
  'siang',
  'kombinasi',
  'malam',
];

const _itemGroupLabel = {
  'persembahan': 'Persembahan',
  'sekali_pakai': 'Sekali pakai',
  'penguat': 'Penguat',
  'siang': 'Kartu kuning',
  'kombinasi': 'Kombinasi',
  'malam': 'Serangan malam',
};

const _itemGroupIcon = {
  'persembahan': 'donations',
  'sekali_pakai': 'item',
  'penguat': 'plus',
  'siang': 'item',
  'kombinasi': 'plus',
  'malam': 'danger',
};

const _itemGroupHelp = {
  'persembahan': 'Efek langsung saat dipersembahkan ke Hayu.',
  'sekali_pakai': 'Alat periksa. Hasilnya hanya dilihat pemakainya.',
  'penguat': 'Menaikkan laju embun (atau bulir hitam) untuk seterusnya.',
  'siang': 'Khusus warga. Dipakai di Meja pada hari biasa, bukan '
      'dipersembahkan.',
  'kombinasi': 'Kartu lanjutan harus digabung dengan kartu poin di tab '
      'Gabung sebelum bisa dipersembahkan.',
  'malam': 'Khusus Si Terbisik. Dilancarkan saat malam tiba; desa hanya '
      'tahu ada serangan.',
};

String _itemGroupOf(String? kind) =>
    (kind == 'poin' || kind == 'lanjutan') ? 'kombinasi' : (kind ?? 'persembahan');

class _ItemsTab extends StatefulWidget {
  const _ItemsTab();
  @override
  State<_ItemsTab> createState() => _ItemsTabState();
}

class _ItemsTabState extends State<_ItemsTab>
    with AutomaticKeepAliveClientMixin {
  Map<String, Map<String, dynamic>>? defs = _defsCache;
  String? error;
  bool loading = false;
  int faction = 0; // 0 = warga (baik), 1 = Si Terbisik (jahat)
  int kindIdx = 0; // 0 = semua, 1..3 = jenis

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (defs == null) _load();
  }

  Future<Map<String, Map<String, dynamic>>> _fetch() async {
    final repo = GameRepository();
    try {
      return await repo.cardDefs();
    } catch (_) {
      // Belum punya sesi? Tabelnya bisa meminta pengguna masuk. Coba sekali
      // dengan sesi anonim (sama seperti saat membuat/gabung ruangan).
      await LobbyRepository().ensureSignedIn();
      return await repo.cardDefs();
    }
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final d = await _fetch();
      _defsCache = d;
      if (mounted) setState(() => defs = d);
    } catch (e) {
      if (mounted) setState(() => error = errMsg(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> _cards(String side) {
    final list = [
      for (final d in (defs ?? {}).values)
        if (d['side'] == side) d,
    ];
    list.sort((a, b) {
      final c = ((a['cost'] as int?) ?? 0) - ((b['cost'] as int?) ?? 0);
      if (c != 0) return c;
      return '${a['name']}'.compareTo('${b['name']}');
    });
    return list;
  }

  Widget _tile(Map<String, dynamic> d, double w, bool dark) {
    final base = d['purchasable'] == false;
    return Column(
      children: [
        _GuideFlip(
          width: w,
          height: w * cardAspectForDef(d),
          // Punggung menurut jenis kartu: warga hijau, antagonis merah,
          // malam ungu, siang kuning, Rekayasa/Regenerasi bergambar DNA.
          backPath: itemBackFor(d),
          dark: dark,
          glow: dark
              ? EmbunColors.mist
              : d['kind'] == 'siang'
              ? EmbunColors.gold
              : EmbunColors.leaf,
          front: CardTile(
            def: d,
            fallbackName: '${d['id']}',
            width: w,
            showCost: true,
            badge: base ? 'Dasar' : null,
            onTap: () => showCardPreview(context, d, defs: defs),
          ),
        ),
        const SizedBox(height: 8),
        _caption('${d['name']}', dark ? EmbunColors.mist : EmbunColors.cream),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (defs == null) {
      return Center(
        child: error == null
            ? const EmbunLoading(text: 'Memuat daftar kartu...')
            : Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GameIcon('alert', size: 56),
              const SizedBox(height: 10),
              Text(error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 14),
              EmbunButton(
                label: 'Coba lagi',
                icon: 'wait',
                onPressed: loading ? null : _load,
              ),
            ],
          ),
        ),
      );
    }

    final good = _cards('warga');
    final bad = _cards('antagonis');
    final dark = faction == 1;
    final all = dark ? bad : good;
    final accent = dark ? EmbunColors.mist : EmbunColors.leaf;
    int n(String g) =>
        all.where((d) => _itemGroupOf(d['kind'] as String?) == g).length;
    // Hanya kelompok yang ada pada fraksi ini.
    final present = [for (final g in _itemGroups) if (n(g) > 0) g];
    final idx = kindIdx.clamp(0, present.length).toInt();
    final shown = idx == 0 ? present : [present[idx - 1]];

    List<Map<String, dynamic>> inGroup(String g) {
      final l = [
        for (final d in all)
          if (_itemGroupOf(d['kind'] as String?) == g) d,
      ];
      // Kombinasi: kartu lanjutan dulu, lalu kartu poin; sisanya menurut harga.
      l.sort((a, b) {
        final ak = a['kind'] == 'poin' ? 1 : 0;
        final bk = b['kind'] == 'poin' ? 1 : 0;
        if (ak != bk) return ak - bk;
        final c = ((a['cost'] as int?) ?? 0) - ((b['cost'] as int?) ?? 0);
        if (c != 0) return c;
        return '${a['name']}'.compareTo('${b['name']}');
      });
      return l;
    }

    return _Page(
      children: [
        _BookmarkPanel(
          tabs: [
            _BmTab('Warga (Baik)', EmbunColors.leaf, count: '${good.length}'),
            _BmTab('Si Terbisik (Jahat)', EmbunColors.mist,
                count: '${bad.length}'),
          ],
          selected: faction,
          onSelect: (i) => setState(() {
            faction = i;
            kindIdx = 0;
          }),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _rich(
                dark
                    ? 'Dibeli dengan **bulir hitam**. Ketuk kartu untuk '
                    'detail. Label "Dasar" = tidak dijual, dibagikan tiap '
                    'malam persembahan.'
                    : 'Dibeli dengan **tetes embun**. Ketuk kartu untuk '
                    'detail. Label "Dasar" = tidak dijual, dibagikan tiap '
                    'malam persembahan.',
                size: 12.5,
                color: Colors.white70,
                bold: accent,
              ),
              const SizedBox(height: 12),
              _Segmented(
                labels: [
                  'Semua',
                  for (final g in present) _itemGroupLabel[g] ?? g,
                ],
                counts: [all.length, for (final g in present) n(g)],
                selected: idx,
                accent: accent,
                onSelect: (i) => setState(() => kindIdx = i),
              ),
              const SizedBox(height: 18),
              for (final g in shown) ...[
                _groupHeader(
                  _itemGroupIcon[g] ?? 'item',
                  _itemGroupLabel[g] ?? g,
                  n(g),
                  accent,
                  help: _itemGroupHelp[g],
                ),
                    () {
                  final list = inGroup(g);
                  return _Grid(
                    key: ValueKey('$faction-$g-$idx'),
                    count: list.length,
                    minCell: 120,
                    item: (i, w) => _tile(list[i], w, dark),
                  );
                }(),
                const SizedBox(height: 24),
              ],
              if (all.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('Tidak ada kartu.',
                        style: TextStyle(color: Colors.white54)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}


// ====================================================================
// Tab 4: Kemampuan
// ====================================================================

Map<String, Map<String, dynamic>>? _abilityCache;

class _AbilitiesTab extends StatefulWidget {
  const _AbilitiesTab();
  @override
  State<_AbilitiesTab> createState() => _AbilitiesTabState();
}

class _AbilitiesTabState extends State<_AbilitiesTab>
    with AutomaticKeepAliveClientMixin {
  Map<String, Map<String, dynamic>>? defs = _abilityCache;
  String? error;
  bool loading = false;
  int kindIdx = 0; // 0 = semua, 1 = sekali pakai, 2 = pasif

  static const _groups = ['sekali_pakai', 'pasif'];
  static const _groupLabel = {'sekali_pakai': 'Sekali pakai', 'pasif': 'Pasif'};
  static const _groupIcon = {'sekali_pakai': 'item', 'pasif': 'plus'};
  static const _groupHelp = {
    'sekali_pakai': 'Tekan tombol kemampuan di bilah atas meja (Patuhilah '
        'Padaku: di layar voting). Hanya sekali.',
    'pasif': 'Bekerja otomatis saat syaratnya terpenuhi.',
  };

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (defs == null) _load();
  }

  Future<Map<String, Map<String, dynamic>>> _fetch() async {
    final repo = GameRepository();
    try {
      return await repo.abilityDefs();
    } catch (_) {
      await LobbyRepository().ensureSignedIn();
      return await repo.abilityDefs();
    }
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final d = await _fetch();
      _abilityCache = d;
      if (mounted) setState(() => defs = d);
    } catch (e) {
      if (mounted) setState(() => error = errMsg(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// Urut: sekali pakai dulu, lalu pasif; "Hanya Orang Biasa" paling akhir.
  List<Map<String, dynamic>> _list(String kind) {
    final list = [
      for (final d in (defs ?? {}).values)
        if (d['kind'] == kind) d,
    ];
    list.sort((a, b) {
      final ab = a['id'] == 'biasa' ? 1 : 0;
      final bb = b['id'] == 'biasa' ? 1 : 0;
      if (ab != bb) return ab - bb;
      return '${a['name']}'.compareTo('${b['name']}');
    });
    return list;
  }

  void _info(Map<String, dynamic> d) {
    final id = '${d['id']}';
    final accent = abilityAccent(id);
    final kind = d['kind'] == 'pasif' ? 'Pasif' : 'Sekali pakai';
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: OrnatePanel(
            accent: accent,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: AbilityCardView(def: d, width: 170)),
                  const SizedBox(height: 14),
                  Text('${d['name']}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: accent)),
                  const SizedBox(height: 4),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border:
                        Border.all(color: accent.withValues(alpha: 0.7)),
                      ),
                      child: Text(kind,
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: accent)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('${d['description']}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, height: 1.4)),
                  const Divider(height: 24),
                  EmbunButton(
                    label: 'Tutup',
                    icon: 'silang',
                    kind: EmbunButtonKind.secondary,
                    height: 46,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> d, double w) {
    final accent = abilityAccent('${d['id']}');
    return GestureDetector(
      onTap: () => _info(d),
      child: Column(
        children: [
          _GuideFlip(
            width: w,
            height: w * kTallAspect,
            backPath: abilityBackPath(),
            glow: accent,
            front: AbilityCardView(def: d, width: w),
          ),
          const SizedBox(height: 8),
          _caption('${d['name']}', accent),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (defs == null) {
      return Center(
        child: error == null
            ? const EmbunLoading(text: 'Memuat daftar kemampuan...')
            : Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GameIcon('alert', size: 56),
              const SizedBox(height: 10),
              Text(error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 14),
              EmbunButton(
                label: 'Coba lagi',
                icon: 'wait',
                onPressed: loading ? null : _load,
              ),
            ],
          ),
        ),
      );
    }

    int n(String k) => _list(k).length;
    final total = n('sekali_pakai') + n('pasif');
    final idx = kindIdx.clamp(0, _groups.length).toInt();
    final shown = idx == 0 ? _groups : [_groups[idx - 1]];
    const accent = EmbunColors.leaf;

    return _Page(
      children: [
        _BookmarkPanel(
          tabs: [
            _BmTab('Kemampuan Warga', accent, count: '$total'),
          ],
          selected: 0,
          onSelect: (_) {},
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bullet('Tiap warga mendapat **satu kemampuan acak**. Tidak '
                  'bisa dibeli dan tidak ada yang kembar.',
                  dot: accent, bold: accent),
              _bullet('Jumlah kemampuan nyata: **0** (3 pemain), **1** '
                  '(4-5), **2** (6-7), **3** (8). Sisanya warga biasa.',
                  dot: accent, bold: accent),
              _bullet('Si Terbisik tidak punya kemampuan, tetapi Stetoskop '
                  'Pencuri Hati miliknya bisa menyedot kemampuan yang '
                  'belum terpakai.',
                  dot: accent, bold: accent),
              _bullet('Ketuk kartu untuk membaca efeknya.',
                  dot: accent, bold: accent),
              const SizedBox(height: 8),
              _Segmented(
                labels: ['Semua', for (final k in _groups) _groupLabel[k]!],
                counts: [total, for (final k in _groups) n(k)],
                selected: idx,
                accent: accent,
                onSelect: (i) => setState(() => kindIdx = i),
              ),
              const SizedBox(height: 18),
              for (final k in shown)
                if (n(k) > 0) ...[
                  _groupHeader(
                    _groupIcon[k]!,
                    _groupLabel[k]!,
                    n(k),
                    accent,
                    help: _groupHelp[k],
                  ),
                      () {
                    final list = _list(k);
                    return _Grid(
                      key: ValueKey('ab-$k-$idx'),
                      count: list.length,
                      minCell: 120,
                      item: (i, w) => _tile(list[i], w),
                    );
                  }(),
                  const SizedBox(height: 24),
                ],
              if (total == 0)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('Belum ada kemampuan.',
                        style: TextStyle(color: Colors.white54)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}