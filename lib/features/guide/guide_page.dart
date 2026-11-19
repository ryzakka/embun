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
// Pembangun kartu: tiga kolom terbuka (daftar | pencarian + grid |
// penyaring), dipisah garis tipis seperti bagian lain halaman ini.
// ====================================================================

const _builderWide = 880.0;

/// Satu pilihan di kolom kiri.
class _BSide {
  final String label;
  final String? sub;
  final String icon;
  final Color accent;
  final int count;
  const _BSide(this.label, this.icon, this.accent, this.count, {this.sub});
}

/// Satu penyaring di kolom kanan: judul, pilihan, dan pilihan aktif.
class _BFilter {
  final String title;
  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelect;
  const _BFilter(this.title, this.options, this.selected, this.onSelect);
}

/// Rentang angka (harga) untuk deretan angka di atas grid.
class _CostBucket {
  final String label;
  final int min;
  final int max;
  const _CostBucket(this.label, this.min, this.max);
  bool has(int c) => c >= min && c <= max;
}

/// Satu angka per harga; bila lebih dari 8 harga berbeda, harga terbesar
/// digabung menjadi "N+".
List<_CostBucket> _costBuckets(Iterable<int> costs) {
  final list = costs.toSet().toList()..sort();
  if (list.length <= 8) {
    return [for (final c in list) _CostBucket('$c', c, c)];
  }
  return [
    for (final c in list.take(7)) _CostBucket('$c', c, c),
    _CostBucket('${list[7]}+', list[7], 1 << 30),
  ];
}

/// Pilihan di kolom kiri: teks terbuka, garis bawah emas/aksen bila terpilih.
class _BPanelTile extends StatelessWidget {
  final _BSide side;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;
  const _BPanelTile({
    required this.side,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final a = side.accent;
    final label = Text.rich(
      TextSpan(
        text: side.label,
        children: [
          TextSpan(
            text: '  ${side.count}',
            style: TextStyle(color: a, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: compact ? TextAlign.center : TextAlign.start,
      style: TextStyle(
        fontSize: compact ? 12.5 : 15,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        color: selected ? a : EmbunColors.cream,
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            border: Border(
              bottom: selected
                  ? BorderSide(color: a, width: 2)
                  : learningRule(a),
            ),
          ),
          child: InkWell(
            onTap: () {
              if (selected) return;
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 4 : 2,
                vertical: compact ? 9 : 11,
              ),
              child: compact
                  ? Center(widthFactor: 1, child: label)
                  : Row(
                children: [
                  GameIcon(side.icon, size: 26),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        label,
                        if (side.sub != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              side.sub!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                height: 1.25,
                                color: Colors.white60,
                              ),
                            ),
                          ),
                      ],
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
}

/// Penyaring: judul emas, pilihan aktif di bawahnya, garis tipis di dasar.
class _BFilterRow extends StatelessWidget {
  final _BFilter filter;
  final Color accent;
  const _BFilterRow({required this.filter, required this.accent});

  @override
  Widget build(BuildContext context) {
    final f = filter;
    final sel = f.selected.clamp(0, f.options.length - 1).toInt();
    final active = sel != 0;
    return PopupMenuButton<int>(
      tooltip: f.title,
      initialValue: sel,
      color: EmbunColors.panel,
      onSelected: (i) {
        HapticFeedback.selectionClick();
        f.onSelect(i);
      },
      itemBuilder: (_) => [
        for (var i = 0; i < f.options.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Text(
              f.options[i],
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: i == sel ? FontWeight.w800 : FontWeight.w500,
                color: i == sel ? EmbunColors.gold : EmbunColors.cream,
              ),
            ),
          ),
      ],
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: active
                ? BorderSide(color: accent, width: 2)
                : learningRule(),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: EmbunColors.gold,
                      ),
                    ),
                    Text(
                      f.options[sel],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: active ? accent : Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 20,
                color: EmbunColors.goldDim,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kolom pencarian: hanya garis bawah, tanpa kotak isian.
class _BSearch extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _BSearch({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    textInputAction: TextInputAction.search,
    style: const TextStyle(fontSize: 14, color: EmbunColors.cream),
    decoration: InputDecoration(
      isDense: true,
      filled: false,
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
      suffixIcon: controller.text.isEmpty
          ? const Icon(Icons.search, size: 20, color: EmbunColors.gold)
          : IconButton(
        tooltip: 'Hapus',
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.close, size: 20, color: EmbunColors.gold),
        onPressed: controller.clear,
      ),
      border: UnderlineInputBorder(
        borderSide: BorderSide(color: EmbunColors.gold.withValues(alpha: 0.32)),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: EmbunColors.gold.withValues(alpha: 0.32)),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: EmbunColors.gold, width: 2),
      ),
    ),
  );
}

/// Deretan angka (harga) di atas grid: teks saja, garis bawah bila terpilih.
class _BNumberBar extends StatelessWidget {
  final String? icon;
  final List<String> labels;
  final int selected;
  final Color accent;
  final ValueChanged<int> onSelect;
  const _BNumberBar({
    this.icon,
    required this.labels,
    required this.selected,
    required this.accent,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        if (icon != null) ...[
          GameIcon(icon!, size: 26),
          const SizedBox(width: 6),
        ],
        for (var i = 0; i < labels.length; i++)
          Semantics(
            button: true,
            selected: i == selected,
            child: Material(
              color: Colors.transparent,
              child: Ink(
                decoration: i == selected
                    ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: accent, width: 2),
                  ),
                )
                    : null,
                child: InkWell(
                  onTap: () {
                    if (i == selected) return;
                    HapticFeedback.selectionClick();
                    onSelect(i);
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 38,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: i == 0 ? 13 : 16,
                            fontWeight: i == selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: i == selected ? accent : EmbunColors.cream,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

Widget _builderEmpty(String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 28),
  child: Center(
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white54),
    ),
  ),
);

/// Kerangka halaman: layar lebar = tiga kolom terbuka (daftar, pencarian +
/// grid, penyaring) dipisah garis tegak tipis; layar sempit = satu kolom
/// bergulir dengan urutan yang sama. Tanpa kotak atau bingkai.
class _BuilderFrame extends StatelessWidget {
  final List<_BSide> sides;
  final int side;
  final ValueChanged<int> onSide;
  final TextEditingController search;
  final String searchHint;
  final Widget? numbers;
  final List<_BFilter> filters;
  final String resultText;
  final Widget? note;
  final Widget body;
  const _BuilderFrame({
    required this.sides,
    required this.side,
    required this.onSide,
    required this.search,
    required this.searchHint,
    required this.filters,
    required this.resultText,
    required this.body,
    this.numbers,
    this.note,
  });

  Color get _accent => sides[side.clamp(0, sides.length - 1).toInt()].accent;

  Widget _header() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        resultText,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: _accent,
        ),
      ),
      if (note != null) ...[const SizedBox(height: 6), note!],
      const SizedBox(height: 14),
    ],
  );

  Widget _filterRow(_BFilter f) => _BFilterRow(filter: f, accent: _accent);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final wide = box.maxWidth >= _builderWide;

      if (wide) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 220,
                child: _Reveal(
                  dx: -24,
                  dy: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(right: learningRule(_accent)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(right: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < sides.length; i++)
                            _BPanelTile(
                              side: sides[i],
                              selected: i == side,
                              onTap: () => onSide(i),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Reveal(
                        dy: -16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _BSearch(controller: search, hint: searchHint),
                            if (numbers != null) ...[
                              const SizedBox(height: 8),
                              numbers!,
                            ],
                            const SizedBox(height: 6),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border(bottom: learningRule(_accent)),
                              ),
                              child: const SizedBox(height: 1),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _header(),
                              body,
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (filters.isNotEmpty)
                SizedBox(
                  width: 230,
                  child: _Reveal(
                    dx: 24,
                    dy: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(left: learningRule(_accent)),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(left: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final f in filters)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: _filterRow(f),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }

      final pad = box.maxWidth < 420 ? 10.0 : 14.0;
      final half = (box.maxWidth - pad * 2 - 14) / 2;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(pad, 10, pad, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final i in List.generate(sides.length, (i) => i))
                  Expanded(
                    child: _BPanelTile(
                      side: sides[i],
                      selected: i == side,
                      compact: true,
                      onTap: () => onSide(i),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _BSearch(controller: search, hint: searchHint),
            if (numbers != null) ...[const SizedBox(height: 6), numbers!],
            if (filters.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  for (final f in filters)
                    SizedBox(
                      width: filters.length == 1 ? box.maxWidth - pad * 2 : half,
                      child: _filterRow(f),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            _header(),
            body,
          ],
        ),
      );
    },
  );
}

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
  int status = 0; // 0 = semua, 1 = terbuka, 2 = terkunci
  final _search = TextEditingController();

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    CharacterCatalog.revision.addListener(_changed);
    _search.addListener(_changed);
  }

  @override
  void dispose() {
    CharacterCatalog.revision.removeListener(_changed);
    _search.dispose();
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
    final accent = dark ? EmbunColors.mist : EmbunColors.leaf;
    final q = _search.text.trim().toLowerCase();
    final list = [
      for (final c in dark ? bad : good)
        if ((status == 0 || c.locked == (status == 2)) &&
            (q.isEmpty || c.label.toLowerCase().contains(q)))
          c,
    ];

    return _BuilderFrame(
      sides: [
        _BSide('Warga', 'persona', EmbunColors.leaf, good.length,
            sub: 'Kartu karakter'),
        _BSide('Si Terbisik', 'danger', EmbunColors.mist, bad.length,
            sub: 'Wajah gelap'),
      ],
      side: faction,
      onSide: (i) => setState(() {
        faction = i;
        status = 0;
      }),
      search: _search,
      searchHint: 'Cari karakter',
      filters: [
        _BFilter(
          'Status',
          const ['Semua', 'Terbuka', 'Terkunci'],
          status,
              (i) => setState(() => status = i),
        ),
      ],
      resultText: '${list.length} kartu',
      note: _rich(
        dark
            ? 'Dipakai Si Terbisik di layarnya sendiri; pemain lain tetap '
            'melihat kartu karakter biasa. Terungkap saat permainan '
            'berakhir. Ketuk kartu untuk memperbesar.'
            : 'Dibagikan acak di awal; namamu mengikuti kartu ini (diberi '
            'nomor bila kembar). Hanya penampilan, tidak mengubah '
            'kekuatan. Kartu terkunci tidak bisa dipakai. Ketuk kartu '
            'aktif untuk memperbesar.',
        size: 12,
        color: Colors.white60,
        bold: accent,
      ),
      body: list.isEmpty
          ? _builderEmpty(
        (dark ? bad : good).isEmpty
            ? 'Belum ada gambar karakter.'
            : 'Tidak ada kartu yang cocok.',
      )
          : _Grid(
        key: ValueKey('char-$faction-$status'),
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
  int costIdx = 0; // 0 = semua harga
  int stockIdx = 0; // 0 = semua, 1 = dijual, 2 = dasar
  final _search = TextEditingController();

  void _onSearch() {
    if (mounted) setState(() {});
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearch);
    if (_data == null) defs = _defsCache;
    if (defs == null) _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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

    final available = all
        .map((d) => _itemGroupOf(d['kind'] as String?))
        .toSet();
    final present = [
      for (final g in _itemGroups)
        if (available.contains(g)) g,
    ];
    final kindSel = kindFilter == null ? 0 : present.indexOf(kindFilter!) + 1;
    final buckets = _costBuckets([
      for (final d in all) (d['cost'] as int?) ?? 0,
    ]);
    final costSel = costIdx.clamp(0, buckets.length).toInt();
    final q = _search.text.trim().toLowerCase();

    int rank(Map<String, dynamic> d) {
      final i = _itemGroups.indexOf(_itemGroupOf(d['kind'] as String?));
      return i < 0 ? 99 : i;
    }

    final list = [
      for (final d in all)
        if ((hayuFilter == null || cardHayuParts(d).contains(hayuFilter)) &&
            (kindSel == 0 ||
                _itemGroupOf(d['kind'] as String?) == present[kindSel - 1]) &&
            (stockIdx == 0 || (d['purchasable'] == false) == (stockIdx == 2)) &&
            (costSel == 0 ||
                buckets[costSel - 1].has((d['cost'] as int?) ?? 0)) &&
            (q.isEmpty ||
                '${d['name']}'.toLowerCase().contains(q) ||
                '${d['description'] ?? ''}'.toLowerCase().contains(q)))
          d,
    ];
    // Kelompok menurut urutan tetap; kombinasi: kartu lanjutan dulu, lalu
    // kartu poin; sisanya menurut harga, lalu nama.
    list.sort((a, b) {
      final g = rank(a) - rank(b);
      if (g != 0) return g;
      final ak = a['kind'] == 'poin' ? 1 : 0;
      final bk = b['kind'] == 'poin' ? 1 : 0;
      if (ak != bk) return ak - bk;
      final c = ((a['cost'] as int?) ?? 0) - ((b['cost'] as int?) ?? 0);
      if (c != 0) return c;
      return '${a['name']}'.compareTo('${b['name']}');
    });

    final kindHelp = kindSel == 0 ? null : _itemGroupHelp[present[kindSel - 1]];

    return _BuilderFrame(
      sides: [
        _BSide('Warga', 'persona', EmbunColors.leaf, good.length,
            sub: 'Dibeli dengan tetes embun'),
        _BSide('Si Terbisik', 'danger', EmbunColors.mist, bad.length,
            sub: 'Dibeli dengan bulir hitam'),
      ],
      side: faction,
      onSide: (i) => setState(() {
        faction = i;
        kindFilter = null;
        costIdx = 0;
        stockIdx = 0;
      }),
      search: _search,
      searchHint: 'Cari kartu',
      numbers: _BNumberBar(
        icon: dark ? 'danger' : 'bulirembun',
        labels: ['Semua', for (final b in buckets) b.label],
        selected: costSel,
        accent: accent,
        onSelect: (i) => setState(() => costIdx = i),
      ),
      filters: [
        _BFilter(
          'Jenis Kartu',
          ['Semua', for (final g in present) _itemGroupLabel[g] ?? g],
          kindSel,
              (i) => setState(() => kindFilter = i == 0 ? null : present[i - 1]),
        ),
        _BFilter(
          'Bagian Hayu',
          ['Semua bagian', for (final p in HayuPart.values) p.label],
          hayuFilter == null ? 0 : HayuPart.values.indexOf(hayuFilter!) + 1,
              (i) => setState(
                () => hayuFilter = i == 0 ? null : HayuPart.values[i - 1],
          ),
        ),
        _BFilter(
          'Ketersediaan',
          const ['Semua', 'Dijual', 'Dasar (dibagikan)'],
          stockIdx,
              (i) => setState(() => stockIdx = i),
        ),
      ],
      resultText: '${list.length} kartu',
      note: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _rich(
            'Ketuk kartu untuk detail. Label **Dasar** = tidak dijual, '
                'dibagikan tiap malam persembahan.',
            size: 12,
            color: Colors.white60,
            bold: accent,
          ),
          if (kindHelp != null) ...[
            const SizedBox(height: 6),
            _rich(kindHelp, size: 12, color: Colors.white70, bold: accent),
          ],
        ],
      ),
      body: list.isEmpty
          ? _builderEmpty(
        all.isEmpty ? 'Tidak ada kartu.' : 'Tidak ada kartu yang cocok.',
      )
          : _Grid(
        key: ValueKey(
          '$faction-${kindFilter ?? 'all'}-${hayuFilter?.name ?? 'all'}'
              '-$stockIdx-$costSel',
        ),
        count: list.length,
        minCell: 120,
        item: (i, w) => _tile(list[i], w, dark),
      ),
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
  int modeIdx = 0; // 0 = semua, 1 = ditekan manual, 2 = bekerja sendiri
  final _search = TextEditingController();

  void _onSearch() {
    if (mounted) setState(() {});
  }

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
    _search.addListener(_onSearch);
    if (_data == null) defs = _abilityCache;
    if (defs == null) _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
    const accent = EmbunColors.leaf;
    final q = _search.text.trim().toLowerCase();

    final list = [
      for (final k in idx == 0 ? _groups : [_groups[idx - 1]])
        for (final d in _list(k))
          if ((modeIdx == 0 ||
              abilityIsManual('${d['id']}') == (modeIdx == 1)) &&
              (q.isEmpty ||
                  '${d['name']}'.toLowerCase().contains(q) ||
                  '${d['description'] ?? ''}'.toLowerCase().contains(q)))
            d,
    ];

    final help = idx == 0 ? null : _groupHelp[_groups[idx - 1]];

    return _BuilderFrame(
      sides: [
        _BSide('Semua', 'item', accent, total, sub: 'Kemampuan warga'),
        for (final k in _groups)
          _BSide(
            _groupLabel[k]!,
            _groupIcon[k]!,
            accent,
            n(k),
            sub: _groupHelp[k],
          ),
      ],
      side: idx,
      onSide: (i) => setState(() => kindIdx = i),
      search: _search,
      searchHint: 'Cari kemampuan',
      filters: [
        _BFilter(
          'Cara Pakai',
          const ['Semua', 'Ditekan manual', 'Bekerja sendiri'],
          modeIdx,
              (i) => setState(() => modeIdx = i),
        ),
      ],
      resultText: '${list.length} kartu',
      note: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (help != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _rich(
                help,
                size: 12,
                color: Colors.white70,
                bold: accent,
              ),
            ),
          _rich(
            'Ketuk kartu untuk membaca efeknya.',
            size: 12,
            color: Colors.white60,
            bold: accent,
          ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              dense: true,
              iconColor: EmbunColors.gold,
              collapsedIconColor: EmbunColors.gold,
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              title: const Text(
                'Cara kerja kemampuan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: EmbunColors.gold,
                ),
              ),
              children: [
                _bullet(
                  'Lima kemampuan rapat baru tidak bisa ditangkis atau '
                      'dipadamkan kartu kuning/ungu. Penanggung Luka hanya '
                      'memindahkan satu luka. Warisan Suara memberi satu suara '
                      'terakhir sesuai jadwal, tanpa mengembalikan aksi pemain.',
                  dot: accent,
                  bold: accent,
                ),
                _bullet(
                  'Setelah kartu karakter hijau terbuka, tiap warga memilih '
                      '**satu dari tiga kartu biru tertutup**. Pilihan diacak '
                      'server dan hasilnya hanya terlihat oleh pemilik.',
                  dot: accent,
                  bold: accent,
                ),
                _bullet(
                  'Kartu biru tidak bisa dibeli. Kemampuan khusus tidak '
                      'kembar; **Hanya Orang Biasa** tetap bisa diperoleh lebih '
                      'dari satu warga. Terbisik membuka kartu merah pada tahap '
                      'yang sama.',
                  dot: accent,
                  bold: accent,
                ),
                _bullet(
                  'Si Terbisik tidak punya kemampuan, tetapi Stetoskop '
                      'Pencuri Hati miliknya bisa menyedot kemampuan yang belum '
                      'terpakai.',
                  dot: accent,
                  bold: accent,
                ),
              ],
            ),
          ),
        ],
      ),
      body: list.isEmpty
          ? _builderEmpty(
        total == 0 ? 'Belum ada kemampuan.' : 'Tidak ada kartu yang cocok.',
      )
          : _Grid(
        key: ValueKey('ab-$idx-$modeIdx'),
        count: list.length,
        minCell: 120,
        item: (i, w) => _tile(list[i], w),
      ),
    );
  }
}