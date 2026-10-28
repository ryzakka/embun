import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../../data/lobby_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import '../table/card_tile.dart';

/// Panduan layar penuh dengan tiga tab: Cara Bermain, Karakter (per fraksi),
/// dan Kartu Item (per fraksi dan jenis). Dibuka dari menu lobi maupun dari
/// menu di dalam permainan.
///
///   Navigator.of(context).push(
///       MaterialPageRoute(builder: (_) => const GuidePage()));
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

/// Isi dipusatkan dan dibatasi lebarnya di layar lebar.
class _Page extends StatelessWidget {
  final List<Widget> children;
  const _Page({required this.children});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 780),
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
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    ),
  );
}

/// Teks dengan **tebal** sederhana.
Widget _rich(String s, {double size = 13.5, Color? color}) {
  final parts = s.split('**');
  return Text.rich(
    TextSpan(
      style: TextStyle(fontSize: size, height: 1.45, color: color),
      children: [
        for (var i = 0; i < parts.length; i++)
          TextSpan(
            text: parts[i],
            style: i.isOdd
                ? const TextStyle(
                fontWeight: FontWeight.w800, color: EmbunColors.gold)
                : null,
          ),
      ],
    ),
  );
}

Widget _para(String s) =>
    Padding(padding: const EdgeInsets.only(bottom: 8), child: _rich(s));

Widget _bullet(String s) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(top: 1, right: 8, left: 2),
        child: Text('•', style: TextStyle(color: EmbunColors.gold)),
      ),
      Expanded(child: _rich(s)),
    ],
  ),
);

Widget _step(int n, String title, String body) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.4),
          border: Border.all(color: EmbunColors.gold, width: 1.5),
        ),
        child: Text('$n',
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: EmbunColors.gold)),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: EmbunColors.cream)),
            const SizedBox(height: 2),
            _rich(body, size: 13, color: Colors.white70),
          ],
        ),
      ),
    ],
  ),
);

// ====================================================================
// Tab 1: Cara Bermain
// ====================================================================

class _HowToTab extends StatelessWidget {
  const _HowToTab();

  @override
  Widget build(BuildContext context) {
    return _Page(
      children: [
        _Section(
          icon: 'helaidaun',
          title: 'Tujuan',
          children: [
            _para('**Hayu**, pohon tua desa, sedang meredup. Jumlah daunnya '
                'adalah nyawa desa. Warga berusaha menyelamatkannya; satu orang '
                'di antara kalian, **Si Terbisik**, diam-diam berusaha '
                'menghancurkannya.'),
            _bullet('**Warga menang** bila daun Hayu mencapai 30, bila '
                'permainan sampai hari ke-12 dengan daun minimal 20, atau bila '
                'Si Terbisik tertangkap.'),
            _bullet('**Si Terbisik menang** bila daun Hayu habis, bila hari '
                'ke-12 berakhir dengan daun di bawah 20, atau bila desa tinggal '
                'dua orang.'),
          ],
        ),
        _Section(
          icon: 'persona',
          title: 'Peran',
          children: [
            _bullet('Main bertiga sampai berdelapan. Di awal, satu orang '
                'dipilih acak menjadi Si Terbisik, sisanya warga. Hanya kamu '
                'yang tahu perannya.'),
            _bullet('Nama dan wajahmu diacak. Selama permainan, kamu dikenal '
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
                    'pemilik**. Kartu yang sudah kamu persembahkan tidak '
                    'kembali. Tiap malam persembahan kamu menerima satu kartu '
                    'dasar. Si Terbisik **wajib menyertakan Papan Penanda** '
                    '(+1 daun, menguras 2 bulir hitam) sebagai samaran.'),
            _step(
                3,
                'Efek',
                'Kartu-kartu dilempar ke Hayu dalam urutan acak, lalu hasilnya '
                    'muncul sebagai gelembung baik atau buruk. Kabut juga '
                    'menggerogoti beberapa daun tiap malam persembahan. Setelah '
                    'itu terbukti **berapa kartu** yang diserahkan tiap pemain, '
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
                    'yang masih di desa.'),
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
            _bullet('**Persembahan**: efek langsung, misalnya menambah daun '
                '(kartu baik) atau mengurangi daun (kartu jahat).'),
            _bullet('**Sekali pakai**: alat pemeriksaan atau trik, misalnya '
                'melihat apakah persembahan seseorang tampak baik atau buruk. '
                'Hasilnya hanya kamu yang tahu, dan tidak selalu bisa '
                'dipercaya.'),
            _bullet('**Penguat**: menaikkan laju embunmu untuk seterusnya.'),
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
            _bullet('**Tuduhan pertama**: pemain itu **dikurung** sampai '
                'musyawarah berikutnya dan Hayu kehilangan 1 daun. Akibatnya '
                'tampak sama untuk semua peran.'),
            _bullet('**Dikurung** berarti tidak bisa membeli kartu dan tidak '
                'bisa menawarkan tukar kartu. Ia tetap bisa menerima kartu, '
                'mempersembahkan kartu yang ia pegang, bicara, dan memilih. '
                'Beberapa kartu jahat juga bisa mengurung orang.'),
            _bullet('**Tuduhan kedua**: bila ia Si Terbisik, ia **tertangkap** '
                'dan warga menang. Bila ia warga, ia **keluar dari desa**: '
                'perannya terbuka, ia hanya bisa menonton, dan Hayu kembali '
                'kehilangan 1 daun.'),
            _bullet('Bila pemain yang tersisa kurang dari 3, **Si Terbisik '
                'menang**. Jadi salah tuduh itu mahal: pikirkan baik-baik '
                'sebelum menuduh orang yang sama dua kali.'),
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
        return _Char(
            protagonistPath(s), (counts[t] ?? 1) > 1 ? '$t $i' : t);
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

class _CharactersTab extends StatelessWidget {
  const _CharactersTab();

  Widget _grid(BuildContext context, List<_Char> list,
      {required bool dark, required double maxWidth}) {
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Belum ada gambar karakter.',
            style: TextStyle(color: Colors.white54)),
      );
    }
    final inner = maxWidth - 32 - 28; // padding panel + padding halaman
    final cols = (inner / 120).floor().clamp(2, 6).toInt();
    final w = ((inner - (cols - 1) * 12) / cols).floorToDouble();
    return Wrap(
      spacing: 12,
      runSpacing: 14,
      children: [
        for (final c in list)
          SizedBox(
            width: w,
            child: GestureDetector(
              onTap: () => _previewCharacter(context, c, dark: dark),
              child: Column(
                children: [
                  CardArt(
                    path: c.path,
                    width: w,
                    glow: dark ? EmbunColors.mist : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    c.label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: dark ? EmbunColors.mist : EmbunColors.cream,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final good = _protagonists();
    final bad = _antagonists();
    return LayoutBuilder(builder: (context, c) {
      final maxW = c.maxWidth > 780 ? 780.0 : c.maxWidth;
      return _Page(
        children: [
          _Section(
            icon: 'persona',
            title: 'Warga Desa (Baik)',
            children: [
              _para('Kartu karakter dibagikan **acak** di awal permainan. '
                  'Namamu selama bermain adalah nama kartu yang kamu dapat '
                  '(diberi nomor bila ada yang kembar). Kartu karakter hanya '
                  'penampilan, tidak mengubah kekuatan. Ketuk kartu untuk '
                  'memperbesar.'),
              _grid(context, good, dark: false, maxWidth: maxW),
            ],
          ),
          _Section(
            icon: 'danger',
            title: 'Si Terbisik (Jahat)',
            accent: EmbunColors.mist,
            children: [
              _para('Hanya satu pemain per permainan menjadi Si Terbisik. '
                  'Ia memakai wajah gelap ini di layarnya sendiri, sementara '
                  'pemain lain tetap melihat kartu karakter biasanya. Wajah '
                  'gelap terungkap ketika permainan berakhir.'),
              _grid(context, bad, dark: true, maxWidth: maxW),
            ],
          ),
        ],
      );
    });
  }
}

// ====================================================================
// Tab 3: Kartu Item
// ====================================================================

/// Disimpan selama aplikasi hidup supaya tab tidak memuat ulang.
Map<String, Map<String, dynamic>>? _defsCache;

const _kindOrder = {'persembahan': 0, 'sekali_pakai': 1, 'penguat': 2};

const _kindHelp = {
  'persembahan':
  'Efek langsung saat dipersembahkan: menambah atau mengurangi daun, '
      'memberi perlindungan, mencuri embun, dan sebagainya.',
  'sekali_pakai':
  'Alat pemeriksaan dan trik. Habis setelah dipersembahkan; hasilnya '
      'dilihat pemakainya saja.',
  'penguat':
  'Menaikkan laju embun (atau bulir hitam) pemakainya untuk seterusnya.',
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
  bool dark = false; // false = warga (baik), true = Si Terbisik (jahat)
  String? kind; // null = semua

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

  List<Map<String, dynamic>> _side() {
    final side = dark ? 'antagonis' : 'warga';
    final list = [
      for (final d in (defs ?? {}).values)
        if (d['side'] == side) d,
    ];
    list.sort((a, b) {
      final k = (_kindOrder[a['kind']] ?? 9) - (_kindOrder[b['kind']] ?? 9);
      if (k != 0) return k;
      final c = ((a['cost'] as int?) ?? 0) - ((b['cost'] as int?) ?? 0);
      if (c != 0) return c;
      return '${a['name']}'.compareTo('${b['name']}');
    });
    return list;
  }

  Widget _factionChips() {
    Widget chip(String text, bool isDark, Color accent) => ChoiceChip(
      label: Text(text),
      selected: dark == isDark,
      showCheckmark: false,
      selectedColor: accent.withValues(alpha: 0.25),
      side: BorderSide(
          color: dark == isDark ? accent : accent.withValues(alpha: 0.35)),
      onSelected: (_) => setState(() {
        dark = isDark;
        kind = null;
      }),
    );
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        chip('Warga (Baik)', false, EmbunColors.leaf),
        chip('Si Terbisik (Jahat)', true, EmbunColors.mist),
      ],
    );
  }

  Widget _kindChips(List<Map<String, dynamic>> all) {
    int n(String? k) => k == null
        ? all.length
        : all.where((d) => d['kind'] == k).length;
    Widget chip(String? k, String text) => ChoiceChip(
      label: Text('$text (${n(k)})'),
      selected: kind == k,
      showCheckmark: false,
      onSelected: (_) => setState(() => kind = k),
    );
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        chip(null, 'Semua'),
        chip('persembahan', 'Persembahan'),
        chip('sekali_pakai', 'Sekali pakai'),
        chip('penguat', 'Penguat'),
      ],
    );
  }

  Widget _tile(Map<String, dynamic> d, double w) {
    final base = d['purchasable'] == false;
    return SizedBox(
      width: w,
      child: Column(
        children: [
          CardTile(
            def: d,
            fallbackName: '${d['id']}',
            width: w,
            showCost: true,
            badge: base ? 'Dasar' : null,
            onTap: () => showCardPreview(context, d),
          ),
          const SizedBox(height: 6),
          Text(
            '${d['name']}',
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: dark ? EmbunColors.mist : EmbunColors.cream,
            ),
          ),
          Text(
            kindLabel['${d['kind']}'] ?? '',
            style: const TextStyle(fontSize: 10.5, color: Colors.white54),
          ),
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

    final all = _side();
    final shown =
    kind == null ? all : all.where((d) => d['kind'] == kind).toList();

    return LayoutBuilder(builder: (context, c) {
      final maxW = c.maxWidth > 780 ? 780.0 : c.maxWidth;
      final inner = maxW - 28 - 32;
      final cols = (inner / 130).floor().clamp(2, 6).toInt();
      final w = ((inner - (cols - 1) * 12) / cols).floorToDouble();

      return _Page(
        children: [
          _Section(
            icon: 'item',
            title: dark ? 'Kartu Si Terbisik' : 'Kartu Warga',
            accent: dark ? EmbunColors.mist : EmbunColors.gold,
            children: [
              _factionChips(),
              const SizedBox(height: 10),
              _kindChips(all),
              const SizedBox(height: 10),
              if (kind != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _rich(_kindHelp[kind] ?? '',
                      size: 12.5, color: Colors.white70),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _rich(
                    dark
                        ? 'Dibeli dengan **bulir hitam**. Ketuk kartu untuk '
                        'membaca efeknya. Kartu "Dasar" tidak dijual; '
                        'dibagikan tiap malam persembahan.'
                        : 'Dibeli dengan **tetes embun**. Ketuk kartu untuk '
                        'membaca efeknya. Kartu "Dasar" tidak dijual; '
                        'dibagikan tiap malam persembahan.',
                    size: 12.5,
                    color: Colors.white70,
                  ),
                ),
              if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Tidak ada kartu.',
                      style: TextStyle(color: Colors.white54)),
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 16,
                  children: [for (final d in shown) _tile(d, w)],
                ),
            ],
          ),
        ],
      );
    });
  }
}