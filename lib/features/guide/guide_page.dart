import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../../data/lobby_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import '../table/card_tile.dart';

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
      length: 3,
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
                    tabs: const [
                      Tab(text: 'Cara Bermain'),
                      Tab(text: 'Karakter'),
                      Tab(text: 'Kartu Item'),
                    ],
                  ),
                  const Expanded(
                    child: TabBarView(
                      children: [
                        _HowToTab(),
                        _CharactersTab(),
                        _ItemsTab(),
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
const _maxPageWidth = 780.0;

/// Isi dipusatkan dan dibatasi lebarnya di layar lebar.
class _Page extends StatelessWidget {
  final List<Widget> children;
  const _Page({required this.children});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxPageWidth),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        children: children,
      ),
    ),
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
    IntrinsicHeight(
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
  final double gap;
  final double rowGap;
  final int maxCols;

  const _Grid({
    required this.count,
    required this.item,
    this.minCell = 112,
    this.gap = 12,
    this.rowGap = 18,
    this.maxCols = 6,
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
                child: start + j < count ? item(start + j, w) : null,
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
          child: Container(
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
            child: child,
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

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: EmbunColors.goldDim.withValues(alpha: 0.35)),
    ),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: GestureDetector(
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
                  border: Border.all(
                      color: i == selected ? accent : Colors.transparent),
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
                            fontWeight: i == selected
                                ? FontWeight.w800
                                : FontWeight.w600,
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
            ),
          ),
      ],
    ),
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
                  Text(items[i].$1,
                      style: const TextStyle(
                          fontSize: 24,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          color: EmbunColors.gold)),
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
      'Hari ke-12 berakhir dengan daun **minimal 20**.',
      'Si Terbisik **tertangkap**.',
    ]);
    final bad = _winCard('Si Terbisik menang', 'danger', EmbunColors.mist, const [
      'Daun Hayu **habis**.',
      'Hari ke-12 berakhir dengan daun **di bawah 20**.',
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
      children: [
        _stats(),
        _Section(
          icon: 'helaidaun',
          title: 'Tujuan',
          children: [
            _para('**Hayu**, pohon tua desa, sedang meredup. Jumlah daunnya '
                'adalah nyawa desa. Warga berusaha menyelamatkannya; satu orang '
                'di antara kalian, **Si Terbisik**, diam-diam berusaha '
                'menghancurkannya.'),
            const SizedBox(height: 4),
            _wins(),
          ],
        ),
        _Section(
          icon: 'persona',
          title: 'Peran',
          children: [
            _bullet('Di awal, satu orang dipilih acak menjadi Si Terbisik, '
                'sisanya warga. Hanya kamu yang tahu perannya.'),
            _bullet('Nama dan wajahmu diacak. Selama permainan kamu dikenal '
                'dengan **nama kartu karakter** (misalnya "Guru" atau '
                '"Nelayan 2"), bukan nama aslimu.'),
            _bullet('Warga memakai **tetes embun**, Si Terbisik memakai '
                '**bulir hitam**. Keduanya dipakai untuk berbelanja kartu.'),
            _bullet('Hayu mulai dengan 10 dikurangi jumlah pemain daun '
                '(paling sedikit 4).'),
          ],
        ),
        _Section(
          icon: 'hari',
          title: 'Satu siklus (3 hari)',
          children: [
            _para('Permainan berlangsung 12 hari, terbagi menjadi empat '
                'siklus. Tiap siklus: dua hari biasa, lalu satu malam '
                'persembahan.'),
            const SizedBox(height: 4),
            _step(
                1,
                'Hari biasa (dua hari)',
                'Belanja **satu kartu per hari** di Pasar Pagi (tiga tawaran '
                    'acak sesuai fraksimu). Kamu juga bisa **memberi embun** '
                    '(1 sampai 3, maksimal 3 kali sehari), **menukar kartu**, '
                    'mengirim isyarat, dan mengobrol. Kabar pagi dapat mengubah '
                    'harga, memberi bonus, atau membocorkan petunjuk. Tekan '
                    '"Akhiri hari" bila sudah selesai.'),
            _step(
                2,
                'Malam persembahan (hari 3, 6, 9, 12)',
                'Pilih **1 atau 2 kartu** untuk dipersembahkan kepada Hayu. '
                    'Semua kartu, baik maupun jahat, dilempar **tanpa nama '
                    'pemilik**, dan kartu yang sudah dipersembahkan tidak '
                    'kembali. Tiap malam persembahan kamu menerima satu kartu '
                    'dasar. Si Terbisik **wajib menyertakan Papan Penanda** '
                    '(+1 daun, menguras 2 bulir hitam) sebagai samaran.'),
            _step(
                3,
                'Efek',
                'Kartu-kartu dilempar ke Hayu dalam urutan acak, lalu hasilnya '
                    'muncul sebagai gelembung baik atau buruk. Kabut juga '
                    'menggerogoti beberapa daun tiap malam persembahan. Setelah '
                    'itu terbuka **berapa kartu** yang diserahkan tiap pemain, '
                    'tetapi bukan kartu apa.'),
            _step(
                4,
                'Musyawarah',
                'Bicaralah lewat obrolan. Bandingkan petunjuk: hasil '
                    'pemeriksaan pribadi, desas-desus, kabar pagi, dan jumlah '
                    'kartu yang diserahkan.'),
            _step(
                5,
                'Pemungutan suara',
                'Tiap pemain menuduh satu orang atau tidak memilih. Tuduhan '
                    'berlaku bila mendapat **lebih dari separuh** suara pemain '
                    'yang masih di desa.',
                last: true),
          ],
        ),
        _Section(
          icon: 'bulirembun',
          title: 'Embun dan kartu',
          children: [
            _bullet('Embunmu bertambah tiap pagi sesuai **laju** (awalnya 3 '
                'per hari). Pagi pertama tiap siklus baru ada bonus +5.'),
            _bullet('Semua kartu dipakai dengan cara **dipersembahkan** di '
                'malam persembahan, maksimal 2 per malam.'),
            const SizedBox(height: 4),
            _infoRow('donations', 'Persembahan',
                'Efek langsung: menambah daun (kartu baik) atau mengurangi daun (kartu jahat), memberi perlindungan, mencuri embun, dan sebagainya.'),
            _infoRow('item', 'Sekali pakai',
                'Alat pemeriksaan atau trik, misalnya melihat apakah persembahan seseorang tampak baik atau buruk. Hasilnya hanya kamu yang tahu, dan tidak selalu bisa dipercaya.'),
            _infoRow('plus', 'Penguat',
                'Menaikkan laju embun (atau bulir hitam) milikmu untuk seterusnya.'),
            const SizedBox(height: 2),
            _bullet('**Perlindungan** menahan serangan yang mengurangi daun '
                'pada malam itu saja.'),
            _bullet('Ketuk lama sebuah kartu untuk membaca efeknya. Daftar '
                'lengkap ada di tab **Kartu Item**.'),
          ],
        ),
        _Section(
          icon: 'lock',
          title: 'Dua nyawa, kurungan, dan keluar',
          accent: EmbunColors.blood,
          children: [
            _para('Setiap pemain punya **2 nyawa** (dua hati di avatarnya). '
                'Dituduh mayoritas berarti kehilangan satu nyawa.'),
            _step(
                1,
                'Tuduhan pertama: dikurung',
                'Pemain itu dikurung **sampai musyawarah berikutnya** dan Hayu '
                    'kehilangan 1 daun. Akibatnya tampak sama untuk semua '
                    'peran. Yang dikurung tidak bisa membeli kartu dan tidak '
                    'bisa menawarkan tukar kartu, tetapi tetap bisa menerima '
                    'kartu, mempersembahkan kartu yang ia pegang, bicara, dan '
                    'memilih. Beberapa kartu jahat juga bisa mengurung orang.'),
            _step(
                2,
                'Tuduhan kedua: tertangkap atau keluar',
                'Bila ia Si Terbisik, ia **tertangkap** dan warga menang. Bila '
                    'ia warga, ia **keluar dari desa**: perannya terbuka, ia '
                    'hanya bisa menonton, dan Hayu kembali kehilangan 1 daun.',
                last: true),
            _bullet('Bila pemain yang tersisa kurang dari 3, **Si Terbisik '
                'menang**. Salah tuduh itu mahal, jadi pikirkan baik-baik '
                'sebelum menuduh orang yang sama dua kali.',
                dot: EmbunColors.blood, bold: EmbunColors.blood),
          ],
        ),
        _Section(
          icon: 'info',
          title: 'Tips',
          children: [
            _bullet('Satu petunjuk belum tentu benar. Pemeriksaan bisa '
                'dikelabui oleh kartu seperti Topeng, Cermin Khayal, atau '
                'Boneka Sawah.'),
            _bullet('Perhatikan **siapa yang jarang membeli** atau selalu '
                'menyerahkan jumlah kartu yang sama.'),
            _bullet('Isyarat (emoji) bisa dikirim ke semua orang atau satu '
                'pemain, maksimal 8 per hari.'),
            _bullet('Sebagai Si Terbisik, tidak perlu menyerang setiap malam: '
                'persembahan yang tampak biasa adalah samaran terbaikmu.'),
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
  AssetCatalog.I.stems(protagonisDir).where((s) => s != 'default').toList();
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
                  width: 210,
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
                    ? 'Hanya satu pemain per permainan menjadi Si Terbisik. '
                    'Ia memakai wajah gelap ini di layarnya sendiri, '
                    'sementara pemain lain tetap melihat kartu karakter '
                    'biasanya. Wajah gelap terungkap saat permainan berakhir.'
                    : 'Dibagikan acak di awal permainan. Namamu selama bermain '
                    'adalah nama kartu yang kamu dapat (diberi nomor bila '
                    'kembar). Kartu karakter hanya penampilan, tidak mengubah '
                    'kekuatan. Ketuk kartu untuk memperbesar.',
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
                  count: list.length,
                  minCell: 108,
                  item: (i, w) => GestureDetector(
                    onTap: () => _previewCharacter(context, list[i], dark: dark),
                    child: Column(
                      children: [
                        CardArt(
                          path: list[i].path,
                          width: w,
                          glow: dark ? EmbunColors.mist : null,
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

const _kinds = ['persembahan', 'sekali_pakai', 'penguat', 'malam'];

const _kindHelp = {
  'persembahan':
  'Efek langsung saat dipersembahkan: menambah atau mengurangi daun, '
      'memberi perlindungan, mencuri embun, dan sebagainya.',
  'sekali_pakai':
  'Alat pemeriksaan dan trik. Habis setelah dipersembahkan; hasilnya '
      'dilihat pemakainya saja.',
  'penguat':
  'Menaikkan laju embun (atau bulir hitam) pemakainya untuk seterusnya.',
  'malam':
  'Disiapkan di hari biasa dan dipakai saat malam tiba: mencuri embun, '
      'menurunkan laju embun, atau menebalkan kabut. Semua pemain hanya '
      'mendengar bahwa ada serangan, tanpa sasaran.',
};

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
        CardTile(
          def: d,
          fallbackName: '${d['id']}',
          width: w,
          showCost: true,
          badge: base ? 'Dasar' : null,
          onTap: () => showCardPreview(context, d),
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
    int n(String k) => all.where((d) => d['kind'] == k).length;
    // Hanya jenis yang ada pada fraksi ini (Warga tidak punya "Serangan malam").
    final present = [for (final k in _kinds) if (n(k) > 0) k];
    final idx = kindIdx.clamp(0, present.length).toInt();
    final selectedKind = idx == 0 ? null : present[idx - 1];
    final kinds = selectedKind == null ? present : [selectedKind];

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
                    'membaca efeknya. Kartu berlabel "Dasar" tidak dijual; '
                    'dibagikan tiap malam persembahan.'
                    : 'Dibeli dengan **tetes embun**. Ketuk kartu untuk '
                    'membaca efeknya. Kartu berlabel "Dasar" tidak dijual; '
                    'dibagikan tiap malam persembahan.',
                size: 12.5,
                color: Colors.white70,
                bold: accent,
              ),
              const SizedBox(height: 12),
              _Segmented(
                labels: [
                  'Semua',
                  for (final k in present) kindLabel[k] ?? k,
                ],
                counts: [all.length, for (final k in present) n(k)],
                selected: idx,
                accent: accent,
                onSelect: (i) => setState(() => kindIdx = i),
              ),
              const SizedBox(height: 18),
              for (final k in kinds)
                if (n(k) > 0) ...[
                  _groupHeader(
                    kindIcon[k] ?? 'item',
                    kindLabel[k] ?? k,
                    n(k),
                    accent,
                    help: _kindHelp[k],
                  ),
                      () {
                    final list = [
                      for (final d in all)
                        if (d['kind'] == k) d,
                    ];
                    return _Grid(
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