import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../../data/embun_data.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../../data/game_rules.dart';
import '../../data/hayu_parts.dart';
import '../../data/lobby_repository.dart';
import '../common/art.dart';
import '../common/character_lock.dart';
import '../common/tutor_companion.dart';
import '../common/ornate.dart';
import '../table/ability_panel.dart';
import '../table/card_tile.dart';
import '../table/flip_card.dart';
import 'learning_frame.dart';

/// Panduan yang bisa dibuka dari lobi maupun meja permainan.
class GuidePage extends StatelessWidget {
  final int initialTab;
  const GuidePage({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      initialIndex: initialTab,
      child: LearningFrame(
        title: 'Panduan',
        icon: 'info',
        background: sceneryPath('perpustakaantua') ?? landscapePath(30),
        navigation: const TabBar(
          indicatorColor: EmbunColors.gold,
          indicatorWeight: 2,
          labelColor: EmbunColors.gold,
          unselectedLabelColor: Colors.white70,
          dividerColor: Colors.transparent,
          labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          unselectedLabelStyle: TextStyle(fontSize: 13),
          labelPadding: EdgeInsets.symmetric(horizontal: 3),
          tabs: [
            Tab(height: 38, child: _TabLabel('Cara Bermain')),
            Tab(height: 38, child: _TabLabel('Karakter')),
            Tab(height: 38, child: _TabLabel('Kartu Item')),
            Tab(height: 38, child: _TabLabel('Kemampuan')),
          ],
        ),
        child: const TabBarView(
          children: [
            _HowToTab(),
            _CharactersTab(),
            _ItemsTab(),
            _AbilitiesTab(),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// Bahan dasar
// ====================================================================

const _twoColBreakpoint = 900.0;
const _twoColMaxWidth = 1120.0;

class _TabLabel extends StatelessWidget {
  final String text;
  const _TabLabel(this.text);
  @override
  Widget build(BuildContext context) =>
      FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1));
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
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
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
      final o = Curves.easeOut.transform(
        (_c.value / 0.55).clamp(0.0, 1.0).toDouble(),
      );
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
      builder: (_, v, _) => Text('${v.round()}', style: style),
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
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
                children: cols[0],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: cols[1],
              ),
            ),
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
    },
  );
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
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 17),
    padding: const EdgeInsets.only(top: 8),
    decoration: BoxDecoration(border: Border(top: learningRule(accent))),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GameIcon(icon, size: 25),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ...children,
      ],
    ),
  );
}

/// Teks dengan **tebal** sederhana.
Widget _rich(
  String s, {
  double size = 13.5,
  Color? color,
  Color bold = EmbunColors.gold,
}) {
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
Widget _step(int n, String title, String body, {bool last = false}) => _Reveal(
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
                child: Text(
                  '$n',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: EmbunColors.gold,
                  ),
                ),
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
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: EmbunColors.cream,
                  ),
                ),
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

/// Baris info berikon, dipisahkan garis tipis.
Widget _infoRow(String icon, String title, String text) => Container(
  margin: const EdgeInsets.only(bottom: 8),
  padding: const EdgeInsets.fromLTRB(2, 3, 2, 7),
  decoration: BoxDecoration(border: Border(bottom: learningRule())),

  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GameIcon(icon, size: 34),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: EmbunColors.cream,
              ),
            ),
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final avail = c.maxWidth.isFinite ? c.maxWidth : 360.0;
      final cols = ((avail + gap) / (minCell + gap))
          .floor()
          .clamp(2, maxCols)
          .toInt();
      final w = ((avail - gap * (cols - 1)) / cols).floorToDouble();
      final rows = <Widget>[];
      for (var start = 0; start < count; start += cols) {
        rows.add(
          Padding(
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
                                milliseconds: min(
                                  60 * (start ~/ cols) + 55 * j,
                                  700,
                                ),
                              ),
                              child: item(start + j, w),
                            ),
                          )
                        : null,
                  ),
                ],
              ],
            ),
          ),
        );
      }
      return Column(children: rows);
    },
  );
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
        fontSize: 12.5,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: color,
      ),
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
  final BoxFit backFit;
  final bool dark;
  final Color glow;
  final Widget front;
  const _GuideFlip({
    required this.width,
    required this.height,
    required this.front,
    this.backPath,
    this.backFit = BoxFit.cover,
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
    final seen =
        o.dy < size.height - 40 &&
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
    backFit: widget.backFit,
    front: widget.front,
  );
}

// ====================================================================
// Tab penanda buku
// ====================================================================

class _FactionTab {
  final String label;
  final String? count;
  final Color accent;
  const _FactionTab(this.label, this.accent, {this.count});
}

class _FactionSection extends StatelessWidget {
  final List<_FactionTab> tabs;
  final int selected;
  final ValueChanged<int> onSelect;
  final Widget child;
  const _FactionSection({
    required this.tabs,
    required this.selected,
    required this.onSelect,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (tabs.length == 1)
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text(
            '${tabs.first.label} · ${tabs.first.count}',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: tabs.first.accent,
            ),
          ),
        )
      else
        DecoratedBox(
          decoration: BoxDecoration(border: Border(bottom: learningRule())),
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: _FilterLabel(
                    label: tabs[i].label,
                    count: tabs[i].count,
                    accent: tabs[i].accent,
                    selected: i == selected,
                    onSelect: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      const SizedBox(height: 10),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topLeft,
          children: [...previous, ?current],
        ),
        child: KeyedSubtree(key: ValueKey(selected), child: child),
      ),
    ],
  );
}

class _FilterLabel extends StatelessWidget {
  final String label;
  final String? count;
  final Color accent;
  final bool selected;
  final VoidCallback onSelect;

  const _FilterLabel({
    required this.label,
    this.count,
    required this.accent,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: Colors.transparent,
      child: Ink(
        decoration: selected
            ? BoxDecoration(
                border: Border(bottom: BorderSide(color: accent, width: 2)),
              )
            : null,
        child: InkWell(
          onTap: () {
            if (selected) return;
            HapticFeedback.selectionClick();
            onSelect();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 38),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: Center(
                widthFactor: 1,
                child: Text.rich(
                  TextSpan(
                    text: label,
                    children: [
                      if (count != null)
                        TextSpan(
                          text: '  $count',
                          style: TextStyle(color: accent),
                        ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? accent : EmbunColors.cream,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

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

  Widget _cell(int i) => _FilterLabel(
    label: labels[i],
    count: '${counts[i]}',
    accent: accent,
    selected: i == selected,
    onSelect: () => onSelect(i),
  );

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(border: Border(bottom: learningRule(accent))),
    child: LayoutBuilder(
      builder: (context, box) {
        const minCell = 92.0;
        if (box.maxWidth >= minCell * labels.length) {
          return Row(
            children: [
              for (var i = 0; i < labels.length; i++) Expanded(child: _cell(i)),
            ],
          );
        }
        return Wrap(
          spacing: 6,
          children: [for (var i = 0; i < labels.length; i++) _cell(i)],
        );
      },
    ),
  );
}

/// Judul kelompok kartu: ikon, nama, jumlah, dan petunjuk.
Widget _groupHeader(
  String icon,
  String title,
  int count,
  Color accent, {
  String? help,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          GameIcon(icon, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count kartu',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
      if (help != null) ...[
        const SizedBox(height: 6),
        Text(
          help,
          style: const TextStyle(
            fontSize: 12,
            height: 1.4,
            color: Colors.white60,
          ),
        ),
      ],
    ],
  ),
);

Widget _catalogState(String loading, {String? error, VoidCallback? retry}) =>
    Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: error == null
            ? EmbunLoading(text: loading)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GameIcon('alert', size: 30),
                  const SizedBox(height: 5),
                  Text(error, textAlign: TextAlign.center),
                  TextButton.icon(
                    onPressed: retry,
                    icon: const GameIcon('refresh', size: 20),
                    label: const Text('Coba lagi'),
                  ),
                ],
              ),
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
      ('12', 'hari standar'),
      ('3', 'hari / siklus'),
      ('2', 'nyawa'),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 34,
                color: EmbunColors.goldDim.withValues(alpha: 0.35),
              ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _CountUp(
                      items[i].$1,
                      style: const TextStyle(
                        fontSize: 24,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        color: EmbunColors.gold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    items[i].$2,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _winCard(
    String title,
    String icon,
    Color accent,
    List<String> lines,
  ) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(10, 4, 3, 2),
    decoration: BoxDecoration(border: Border(left: learningRule(accent))),

    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GameIcon(icon, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
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
      'Semua Terbisik **tersingkir**.',
    ]);
    final bad =
        _winCard('Si Terbisik menang', 'danger', EmbunColors.mist, const [
          'Daun Hayu **habis**.',
          'Hari terakhir berakhir dengan daun **di bawah batas**.',
          'Di mode klasik, desa **tinggal dua orang**.',
          'Di mode Dua Terbisik, **semua Warga tersingkir**.',
        ]);
    return LayoutBuilder(
      builder: (context, c) {
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Page(
      maxWidth: 780,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TutorCompanion(
            pose: TutorPose.greeting,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kenali desa Hayu',
                  style: TextStyle(
                    color: EmbunColors.cream,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                _para(
                  'Mulai dari tujuan, lalu kenali kartu dan tempat yang bisa kamu kunjungi.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _stats(),
        ],
      ),
      // Bagian tersusun bergantian tanpa daftar indeks yang bisa tertinggal.
      column: (i) => i % 2,
      children: [
        _Section(
          icon: 'helaidaun',
          title: 'Tujuan',
          children: [
            _para(
              '**Hayu**, pohon tua desa, sedang meredup. Jumlah daunnya '
              'adalah nyawa desa: warga berusaha menyelamatkannya, '
              '**Si Terbisik** diam-diam menghancurkannya.',
            ),
            const SizedBox(height: 4),
            _wins(),
          ],
        ),
        _Section(
          icon: 'persona',
          title: 'Peran',
          children: [
            _bullet(
              'Satu pemain acak menjadi Si Terbisik, sisanya warga. '
              'Hanya kamu yang tahu perannya.',
            ),
            _bullet(
              'Namamu diacak menjadi **nama kartu karakter** '
              '(mis. "Guru", "Nelayan 2").',
            ),
            _bullet(
              'Warga berbelanja dengan **tetes embun**, Si Terbisik '
              'dengan **bulir hitam**.',
            ),
            _bullet(
              'Daun awal Hayu: 10 dikurangi jumlah pemain '
              '(minimal 4).',
            ),
          ],
        ),
        _Section(
          icon: 'store',
          title: 'Kunjungan desa',
          children: [
            _para(
              'Malam sebelum persembahan, pilih maksimal **2 tempat**. Panah hanya mengganti tujuan. Jatah terpakai saat masuk; meninggalkan tempat tidak mengembalikannya.',
            ),
            _bullet(
              '**Pasar Riset**: beli kartu poin, kartu lanjutan, dan surat perawatan. Maksimal 2 pembelian; harga +20%.',
            ),
            _bullet(
              '**Sumur Desa**: bayar 8 uang untuk mengubah laju bersama sebesar +0,15 (warga) atau −0,15 (Terbisik) per hari. Bertahan sepanjang gim, batas −1,50 sampai +1,50. Berlaku bagi kedua fraksi.',
            ),
            _bullet(
              '**Bengkel Desa**: aktifkan kartu lanjutan menggunakan kartu poin, atau tingkatkan Stetoskop milik warga. Tidak bisa digabung di Meja hari biasa.',
            ),
            _bullet(
              '**Pondok Perawatan**: perlu surat sesuai peran. Perawatan memulihkan 1 nyawa; pasien lain perlu tambahan 12 uang. Jebakan mengurangi 1 nyawa seorang pengunjung lain, lalu habis. Pemulihan diselesaikan sebelum jebakan.',
            ),
            _bullet(
              '**Balai Pertukaran**: tawarkan kartu. Penerima boleh mengikuti undangan tanpa menghabiskan kunjungan dan kembali ke tempat sebelumnya. Kunjungan gratis hanya untuk tawaran tersebut.',
            ),
          ],
        ),
        _Section(
          icon: 'hari',
          title: 'Satu siklus (3 hari)',
          children: [
            _para(
              'Host memilih lama sesi: 6, 12 (bawaan), 18, atau 24 hari. '
              'Batas daun untuk menang: **12 / 20 / 24 / 26**. Tiap siklus: **2 hari biasa** lalu '
              '**1 malam persembahan**.',
            ),
            const SizedBox(height: 4),
            _step(
              1,
              'Hari biasa (dua hari)',
              'Beli **1 kartu per hari** di Pasar Pagi (4 tawaran acak). '
                  'Boleh memberi embun (1 sampai 3, maks 3 kali sehari), '
                  'mengirim isyarat, dan mengobrol. Tekan '
                  '"Akhiri hari" bila selesai.',
            ),
            _step(
              2,
              'Malam persembahan (hari 3, 6, 9, 12, dst.)',
              'Persembahkan **1 atau 2 kartu** ke Hayu, tanpa nama '
                  'pemilik. Si Terbisik **wajib menyertakan Roti Surplus** '
                  'sebagai samaran.',
            ),
            _step(
              3,
              'Efek',
              'Kartu dilempar acak; hasilnya muncul sebagai gelembung '
                  'baik atau buruk. Kabut ikut menggerogoti daun. Lalu '
                  'terbuka **berapa** kartu tiap pemain, bukan apa.',
            ),
            _step(
              4,
              'Musyawarah',
              'Bandingkan petunjuk lewat obrolan: pemeriksaan pribadi, '
                  'desas-desus, kabar pagi, jumlah kartu.',
            ),
            _step(
              5,
              'Pemungutan suara',
              'Tuduh satu orang atau tidak memilih. Tuduhan sah bila '
                  'mendapat **lebih dari separuh** suara pemain yang '
                  'masih di desa.',
              last: true,
            ),
          ],
        ),
        _Section(
          icon: 'bulirembun',
          title: 'Embun dan kartu',
          children: [
            _bullet(
              'Embun bertambah tiap pagi sesuai **laju** (awal 3). '
              'Pagi pertama tiap siklus ada bonus +5.',
            ),
            _bullet('**Perlindungan** menahan serangan pada malam itu saja.'),
            const SizedBox(height: 4),
            _infoRow(
              'donations',
              'Persembahan',
              'Efek langsung saat dilempar ke Hayu: menambah atau '
                  'mengurangi daun, perlindungan, mencuri embun.',
            ),
            _infoRow(
              'item',
              'Sekali pakai (warga)',
              'Hasil pemeriksaan muncul dalam popup pribadi saat musyawarah. '
                  'Kaca Pembesar dan Lampu Senter memberi angka nyata. '
                  'Lentera menilai persembahan, bukan peran.',
            ),
            _bullet(
              '**Stetoskop** memeriksa peran. Peluang berhasil awal **30%**. '
              'Tingkatkan satu kartu di **Bengkel Desa**: **30 → 50 → 70 → 85 → 100%**, '
              'dengan biaya bertahap **3 / 5 / 7 / 10 embun**. Gagal berarti peran '
              'belum dapat dipastikan. Mulai **85%** kebal pengelabuan; **100%** pasti benar. '
              'Kartu dan peningkatannya habis saat dipakai. Buka ulang hasil lewat **Infoku**.',
            ),
            _infoRow(
              'plus',
              'Penguat',
              'Menaikkan laju embun (atau bulir hitam) untuk seterusnya.',
            ),
            _infoRow(
              'plus',
              'Kartu lanjutan',
              'Harus digabung dengan kartu poin dulu. Lihat bagian di '
                  'bawah.',
            ),
            _infoRow(
              'item',
              'Kartu kuning (warga)',
              'Dipakai di Meja pada hari biasa, bukan dipersembahkan: '
                  'perisai, cermin, embun, nyawa, atau panah.',
            ),
            _bullet(
              '**Perisai Malam** bisa dipasang untuk diri sendiri atau satu '
              'pemain lain sampai akhir sesi. Nama penjaga dirahasiakan dari '
              'penerima. Jika perisai menahan serangan, penjaga mendapat '
              'laporan pribadi.',
            ),
            _infoRow(
              'danger',
              'Serangan malam (Si Terbisik)',
              'Dilancarkan saat malam tiba. Desa hanya tahu ada serangan, '
                  'bukan sasarannya.',
            ),
            const SizedBox(height: 2),
            _bullet(
              'Yang bisa dipersembahkan: Persembahan, Sekali pakai, '
              'Penguat, dan kartu lanjutan yang AKTIF (maks 2 per malam).',
            ),
            _bullet(
              'Tekan lama kartu untuk membaca efeknya. Daftar lengkap '
              'ada di tab **Kartu Item**.',
            ),
          ],
        ),
        _Section(
          icon: 'plus',
          title: 'Kartu lanjutan (kombinasi)',
          children: [
            _para(
              'Kartu lanjutan harus **digabung** dengan satu **kartu '
              'poin** sebelum bisa dipersembahkan.',
            ),
            _bullet('**Warga**: Kartu Regenerasi + Poin Regenerasi.'),
            _bullet('**Si Terbisik**: Kartu Rekayasa + Poin DNA.'),
            const SizedBox(height: 6),
            _step(
              1,
              'Beli keduanya',
              'Beli keduanya di Pasar Riset. Kartu lanjutan yang '
                  'belum digabung tampak pudar, berlabel "Butuh poin".',
            ),
            _step(
              2,
              'Gabungkan di Bengkel Desa',
              'Malam sebelum persembahan: kunjungi **Bengkel Desa**, letakkan satu kartu '
                  'lanjutan dan satu kartu syarat (poin) di petak, lalu '
                  'tekan "Aktifkan kartu". Satu poin habis dan kartu menjadi '
                  '**AKTIF**. Tidak diumumkan, dan boleh walau sedang '
                  'dikurung.',
            ),
            _step(
              3,
              'Persembahkan',
              'Kartu AKTIF dipersembahkan seperti kartu biasa. Yang belum '
                  'aktif ditolak.',
              last: true,
            ),
            const SizedBox(height: 10),
            _bullet(
              '**Harga** mengikuti kartu yang tersedia di Pasar Riset, termasuk kenaikan harga riset.',
            ),
            _bullet(
              '**Kapsul DNA** (Si Terbisik) setara 2 Poin DNA: cukup '
              'untuk dua kartu Rekayasa.',
            ),
            _bullet(
              'Kartu yang ditukar atau dicuri **kehilangan status '
              'AKTIF**. Kartu poin yang mahal juga mudah jadi sasaran '
              'Kerikil Panas dan Curian Malam, jadi gabungkan secepatnya.',
            ),
          ],
        ),
        _Section(
          icon: 'lock',
          title: 'Dua nyawa, kurungan, dan keluar',
          accent: EmbunColors.blood,
          children: [
            _para(
              'Tiap pemain punya **2 nyawa** (dua hati di avatar). '
              'Dituduh mayoritas = kehilangan satu nyawa, dan Hayu '
              'kehilangan 1 daun.',
            ),
            _step(
              1,
              'Tuduhan pertama: dikurung',
              'Dikurung **sampai musyawarah berikutnya**. Tidak bisa '
                  'membeli atau menawarkan tukar kartu, tetapi tetap bisa '
                  'menerima kartu, mempersembahkan, bicara, dan memilih.',
            ),
            _step(
              2,
              'Tuduhan kedua: tertangkap atau keluar',
              'Pemain yang tertuduh **keluar dari desa**. Warga menang '
                  'lewat tuduhan bila semua Terbisik sudah tersingkir.',
              last: true,
            ),
            _bullet(
              'Pada mode klasik, **Si Terbisik menang** jika pemain '
              'tersisa kurang dari $kMinPlayers.',
              dot: EmbunColors.blood,
              bold: EmbunColors.blood,
            ),
            _bullet(
              '**Dua Terbisik** bisa dimulai dengan minimal '
              '$kMinDuaTerbisikPlayers pemain. Mereka saling kenal, '
              'punya obrolan rahasia, dan berbagi satu serangan per malam biasa.',
              dot: EmbunColors.mist,
              bold: EmbunColors.mist,
            ),
          ],
        ),
        _Section(
          icon: 'info',
          title: 'Tips',
          children: [
            _bullet(
              'Satu petunjuk belum tentu benar: Topeng, Cermin Khayal, '
              'dan Boneka Sawah bisa mengelabui pemeriksaan.',
            ),
            _bullet(
              'Perhatikan **siapa yang jarang membeli** atau selalu '
              'menyerahkan jumlah kartu yang sama.',
            ),
            _bullet(
              'Isyarat (emoji) bisa ke semua orang atau satu pemain, '
              'maks 8 per hari.',
            ),
            _bullet(
              'Si Terbisik: tidak perlu menyerang tiap malam. '
              'Persembahan yang tampak biasa adalah samaran terbaik.',
            ),
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
  final String? stem;
  bool get locked => stem != null && !CharacterCatalog.isEnabled(stem!);
  const _Char(this.path, this.label, {this.stem});
}

List<_Char> _protagonists() {
  final stems = protagonistStems(
    includeLocked: true,
  ).where((s) => s != 'default').toList();
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
        return _Char(
          protagonistPath(s),
          (counts[t] ?? 1) > 1 ? '$t $i' : t,
          stem: s,
        );
      }(),
  ];
}

List<_Char> _antagonists() {
  final stems = AssetCatalog.I.stems(antagonisDir);
  return [
    for (var i = 0; i < stems.length; i++)
      _Char(
        AssetCatalog.I.file(antagonisDir, stems[i]),
        stems.length > 1 ? 'Si Terbisik ${i + 1}' : 'Si Terbisik',
      ),
  ];
}

void _previewCharacter(BuildContext context, _Char c, {required bool dark}) {
  if (c.locked) return;
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: EmbunColors.panel,
      elevation: 0,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (c.stem != null)
                  CharacterLock(
                    id: c.stem!,
                    child: CardArt(
                      path: c.path,
                      width: min(210.0, MediaQuery.sizeOf(ctx).height * 0.42),
                    ),
                  )
                else
                  CardArt(
                    path: c.path,
                    width: min(210.0, MediaQuery.sizeOf(ctx).height * 0.42),
                    glow: dark ? EmbunColors.mist : EmbunColors.leaf,
                  ),
                const SizedBox(height: 14),
                Text(
                  c.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: EmbunColors.gold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  dark
                      ? 'Wajah gelap Si Terbisik. Hanya pemiliknya yang '
                            'melihatnya sampai permainan berakhir.'
                      : 'Kartu karakter warga. Dibagikan acak di awal, dan '
                            'namamu selama permainan mengikuti kartu ini.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: Colors.white70,
                  ),
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

  void _catalogChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    CharacterCatalog.revision.addListener(_catalogChanged);
  }

  @override
  void dispose() {
    CharacterCatalog.revision.removeListener(_catalogChanged);
    super.dispose();
  }

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
        _FactionSection(
          tabs: [
            _FactionTab('Warga', EmbunColors.leaf, count: '${good.length}'),
            _FactionTab(
              'Si Terbisik',
              EmbunColors.mist,
              count: '${bad.length}',
            ),
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
                          'mengubah kekuatan. Kartu terkunci tidak bisa dipakai. '
                          'Ketuk kartu aktif untuk memperbesar.',
              ),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Belum ada gambar karakter.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                )
              else
                _Grid(
                  key: ValueKey('char-$faction'),
                  count: list.length,
                  minCell: 108,
                  item: (i, w) => GestureDetector(
                    onTap: list[i].locked
                        ? null
                        : () => _previewCharacter(context, list[i], dark: dark),
                    child: Column(
                      children: [
                        _GuideFlip(
                          width: w,
                          height: w * cardAspectFor(list[i].path),
                          backPath: cardBackPath(dark: dark),
                          dark: dark,
                          glow: dark ? EmbunColors.mist : EmbunColors.leaf,
                          front: list[i].stem == null
                              ? CardArt(
                                  path: list[i].path,
                                  width: w,
                                  glow: dark ? EmbunColors.mist : null,
                                )
                              : CharacterLock(
                                  id: list[i].stem!,
                                  child: CardArt(path: list[i].path, width: w),
                                ),
                        ),
                        const SizedBox(height: 8),
                        _caption(
                          list[i].label,
                          dark ? EmbunColors.mist : EmbunColors.cream,
                        ),
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
  'perawatan',
  'malam',
];

const _itemGroupLabel = {
  'persembahan': 'Persembahan',
  'sekali_pakai': 'Sekali pakai',
  'penguat': 'Penguat',
  'siang': 'Kartu kuning',
  'kombinasi': 'Kombinasi',
  'perawatan': 'Perawatan',
  'malam': 'Serangan malam',
};

const _itemGroupIcon = {
  'persembahan': 'donations',
  'sekali_pakai': 'item',
  'penguat': 'plus',
  'siang': 'item',
  'kombinasi': 'plus',
  'perawatan': 'item',
  'malam': 'danger',
};

const _itemGroupHelp = {
  'perawatan':
      'Beli di Pasar Riset. Surat Dokter memulihkan 1 nyawa di Pondok Perawatan; merawat pemain lain perlu 12 uang tambahan. Surat Keterangan Sakit memasang jebakan yang bertahan sampai seorang pengunjung lain terkena. Surat habis setelah digunakan.',
  'persembahan': 'Efek langsung saat dipersembahkan ke Hayu.',
  'sekali_pakai': 'Alat periksa. Hasilnya hanya dilihat pemakainya.',
  'penguat': 'Menaikkan laju embun (atau bulir hitam) untuk seterusnya.',
  'siang':
      'Khusus warga. Dipakai di Meja pada hari biasa, bukan '
      'dipersembahkan.',
  'kombinasi':
      'Kartu lanjutan harus digabung dengan kartu poin di '
      'Bengkel Desa sebelum bisa dipersembahkan.',
  'malam':
      'Khusus Si Terbisik. Dilancarkan saat malam tiba; desa hanya '
      'tahu ada serangan.',
};

String _itemGroupOf(String? kind) => (kind == 'poin' || kind == 'lanjutan')
    ? 'kombinasi'
    : (kind ?? 'persembahan');

class _ItemsTab extends StatefulWidget {
  const _ItemsTab();
  @override
  State<_ItemsTab> createState() => _ItemsTabState();
}

class _ItemsTabState extends State<_ItemsTab>
    with AutomaticKeepAliveClientMixin {
  late final _data = EmbunData.maybeOf(context);
  Map<String, Map<String, dynamic>>? defs;
  String? error;
  bool loading = false;
  int faction = 0; // 0 = warga (baik), 1 = Si Terbisik (jahat)
  String? kindFilter;
  HayuPart? hayuFilter;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (_data == null) defs = _defsCache;
    if (defs == null) _load();
  }

  Future<Map<String, Map<String, dynamic>>> _fetch() async {
    final repo = _data?.game ?? GameRepository();
    try {
      return await repo.cardDefs();
    } catch (_) {
      // Belum punya sesi? Tabelnya bisa meminta pengguna masuk. Coba sekali
      // dengan sesi anonim (sama seperti saat membuat/gabung ruangan).
      await (_data?.lobby ?? LobbyRepository()).ensureSignedIn();
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
      if (_data == null) _defsCache = d;
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
            showHayuTargets: true,
            badge: base ? 'Dasar' : null,
            onTap: () => showCardPreview(context, d, defs: defs),
          ),
        ),
        const SizedBox(height: 8),
        _caption('${d['name']}', dark ? EmbunColors.mist : EmbunColors.cream),
      ],
    );
  }

  Widget _hayuFilters(Color accent) {
    Widget chip(HayuPart? part) => ChoiceChip(
      key: ValueKey('hayu-filter-${part?.name ?? 'all'}'),
      label: Text(part?.label ?? 'Semua bagian'),
      avatar: part == null
          ? null
          : SizedBox.square(
              dimension: 22,
              child: GameImage(
                path: sceneryPath('pohonindikator-${part.name}'),
                fit: BoxFit.contain,
                cacheWidth: 66,
              ),
            ),
      selected: hayuFilter == part,
      showCheckmark: false,
      selectedColor: accent.withValues(alpha: 0.20),
      side: BorderSide(
        color: accent.withValues(alpha: hayuFilter == part ? 0.90 : 0.32),
      ),
      labelStyle: TextStyle(
        color: hayuFilter == part ? EmbunColors.cream : Colors.white70,
        fontSize: 12,
        fontWeight: hayuFilter == part ? FontWeight.w800 : FontWeight.w600,
      ),
      onSelected: (_) => setState(() => hayuFilter = part),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: const Text(
            'Bagian Hayu',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
        Wrap(
          spacing: 6,
          children: [
            chip(null),
            for (final part in HayuPart.values) chip(part),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (defs == null) {
      return _catalogState(
        'Memuat daftar kartu…',
        error: error,
        retry: loading ? null : _load,
      );
    }

    final good = _cards('warga');
    final bad = _cards('antagonis');
    final dark = faction == 1;
    final all = dark ? bad : good;
    final accent = dark ? EmbunColors.mist : EmbunColors.leaf;
    final filter = hayuFilter;
    final filtered = filter == null
        ? all
        : [
            for (final d in all)
              if (cardHayuParts(d).contains(filter)) d,
          ];
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final d in filtered) {
      final group = _itemGroupOf(d['kind'] as String?);
      (groups[group] ??= []).add(d);
    }
    int n(String g) => groups[g]?.length ?? 0;
    final available = all
        .map((d) => _itemGroupOf(d['kind'] as String?))
        .toSet();
    final present = [
      for (final g in _itemGroups)
        if (available.contains(g)) g,
    ];
    final idx = kindFilter == null ? 0 : present.indexOf(kindFilter!) + 1;
    final shown = [
      for (final g in idx == 0 ? present : [present[idx - 1]])
        if (n(g) > 0) g,
    ];

    List<Map<String, dynamic>> inGroup(String g) {
      final l = groups[g]!;
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
        _FactionSection(
          tabs: [
            _FactionTab('Warga', EmbunColors.leaf, count: '${good.length}'),
            _FactionTab(
              'Si Terbisik',
              EmbunColors.mist,
              count: '${bad.length}',
            ),
          ],
          selected: faction,
          onSelect: (i) => setState(() {
            faction = i;
            kindFilter = null;
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
                counts: [filtered.length, for (final g in present) n(g)],
                selected: idx,
                accent: accent,
                onSelect: (i) => setState(() {
                  kindFilter = i == 0 ? null : present[i - 1];
                }),
              ),
              const SizedBox(height: 12),
              _hayuFilters(accent),
              const SizedBox(height: 14),
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
                    key: ValueKey('$faction-$g-${hayuFilter?.name ?? 'all'}'),
                    count: list.length,
                    minCell: 120,
                    item: (i, w) => _tile(list[i], w, dark),
                  );
                }(),
                const SizedBox(height: 24),
              ],
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      hayuFilter == null
                          ? 'Tidak ada kartu.'
                          : 'Tidak ada kartu yang cocok dengan filter ini.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54),
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
  late final _data = EmbunData.maybeOf(context);
  Map<String, Map<String, dynamic>>? defs;
  String? error;
  bool loading = false;
  int kindIdx = 0; // 0 = semua, 1 = sekali pakai, 2 = pasif

  static const _groups = ['sekali_pakai', 'pasif'];
  static const _groupLabel = {'sekali_pakai': 'Sekali pakai', 'pasif': 'Pasif'};
  static const _groupIcon = {'sekali_pakai': 'item', 'pasif': 'plus'};
  static const _groupHelp = {
    'sekali_pakai':
        'Tekan tombol kemampuan di bilah atas meja (Patuhilah '
        'Padaku: di layar voting). Hanya sekali.',
    'pasif': 'Bekerja otomatis saat syaratnya terpenuhi.',
  };

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (_data == null) defs = _abilityCache;
    if (defs == null) _load();
  }

  Future<Map<String, Map<String, dynamic>>> _fetch() async {
    final repo = _data?.game ?? GameRepository();
    try {
      return await repo.abilityDefs();
    } catch (_) {
      await (_data?.lobby ?? LobbyRepository()).ensureSignedIn();
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
      if (_data == null) _abilityCache = d;
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
        backgroundColor: EmbunColors.panel,
        elevation: 0,
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: AbilityCardView(def: d, width: 170)),
                  const SizedBox(height: 14),
                  Text(
                    '${d['name']}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Text(
                        kind,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${d['description']}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
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
            height: w * abilityCardAspect,
            backPath: abilityBackPath(),
            backFit: BoxFit.contain,
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
      return _catalogState(
        'Memuat daftar kemampuan…',
        error: error,
        retry: loading ? null : _load,
      );
    }

    int n(String k) => _list(k).length;
    final total = n('sekali_pakai') + n('pasif');
    final idx = kindIdx.clamp(0, _groups.length).toInt();
    final shown = idx == 0 ? _groups : [_groups[idx - 1]];
    const accent = EmbunColors.leaf;

    return _Page(
      children: [
        _FactionSection(
          tabs: [_FactionTab('Kemampuan Warga', accent, count: '$total')],
          selected: 0,
          onSelect: (_) {},
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bullet(
                'Setelah kartu karakter hijau terbuka, tiap warga memilih '
                '**satu dari tiga kartu biru tertutup**. Pilihan diacak server '
                'dan hasilnya hanya terlihat oleh pemilik.',
                dot: accent,
                bold: accent,
              ),
              _bullet(
                'Kartu biru tidak bisa dibeli. Kemampuan khusus tidak kembar; '
                '**Hanya Orang Biasa** tetap bisa diperoleh lebih dari satu warga. '
                'Terbisik membuka kartu merah pada tahap yang sama.',
                dot: accent,
                bold: accent,
              ),
              _bullet(
                'Si Terbisik tidak punya kemampuan, tetapi Stetoskop '
                'Pencuri Hati miliknya bisa menyedot kemampuan yang '
                'belum terpakai.',
                dot: accent,
                bold: accent,
              ),
              _bullet(
                'Ketuk kartu untuk membaca efeknya.',
                dot: accent,
                bold: accent,
              ),
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
                    child: Text(
                      'Belum ada kemampuan.',
                      style: TextStyle(color: Colors.white54),
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
