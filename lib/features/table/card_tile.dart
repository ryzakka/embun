import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import '../common/sfx.dart';

const kindLabel = {
  'persembahan': 'Persembahan',
  'sekali_pakai': 'Sekali pakai',
  'penguat': 'Penguat',
  'malam': 'Serangan malam',
  'siang': 'Pakai di siang',
  'poin': 'Kartu poin',
  'lanjutan': 'Kartu lanjutan',
};

const kindIcon = {
  'persembahan': 'donations',
  'sekali_pakai': 'item',
  'penguat': 'plus',
  'malam': 'danger',
  'siang': 'item',
  'poin': 'bulirembun',
  'lanjutan': 'plus',
};

/// Matriks warna: tanpa perubahan.
const _identityMatrix = <double>[
  1, 0, 0, 0, 0,
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  0, 0, 0, 1, 0,
];

/// Matriks warna: abu-abu gelap (luminans x 0,55). Dipakai untuk kartu
/// lanjutan yang belum digabung dengan kartu poin.
const _fadedMatrix = <double>[
  0.117, 0.393, 0.040, 0, 0,
  0.117, 0.393, 0.040, 0, 0,
  0.117, 0.393, 0.040, 0, 0,
  0, 0, 0, 1, 0,
];

List<double> _lerpMatrix(double t) => [
  for (var i = 0; i < 20; i++)
    _identityMatrix[i] + (_fadedMatrix[i] - _identityMatrix[i]) * t,
];

/// Gambar kartu pada pratinjau. Untuk kartu lanjutan, kartu syarat (poin)
/// tampil mini menindih sudut kiri atas gambar, jadi tidak memakan ruang.
/// Ketuk kartu mini untuk membuka/menutup keterangannya di atas gambar.
/// [defs] (bila ada) memberi nama dan harga terbaru; tanpa itu dipakai data
/// bawaan.
class _CardPreviewArt extends StatefulWidget {
  final Map<String, dynamic> def;
  final String path;
  final Color glow;
  final Map<String, Map<String, dynamic>>? defs;
  const _CardPreviewArt({
    required this.def,
    required this.path,
    required this.glow,
    this.defs,
  });

  @override
  State<_CardPreviewArt> createState() => _CardPreviewArtState();
}

class _CardPreviewArtState extends State<_CardPreviewArt> {
  static const double _w = 200;
  static const double _miniW = 62;
  bool _info = false;

  bool get _bad => widget.def['side'] == 'antagonis';

  /// Definisi kartu syarat: dari [defs] bila ada, bila tidak data bawaan.
  Map<String, dynamic> get _req {
    final id = _bad ? 'poin_dna' : 'poin_regenerasi';
    return widget.defs?[id] ??
        {
          'id': id,
          'side': _bad ? 'antagonis' : 'warga',
          'kind': 'poin',
          'art': _bad ? 'rekayasa-poindna' : 'gen-poinregenerasi',
          'name': _bad ? 'Poin DNA' : 'Poin Regenerasi',
          'cost': 16,
        };
  }

  @override
  Widget build(BuildContext context) {
    final main = CardArt(path: widget.path, width: _w, glow: widget.glow);
    if (widget.def['kind'] != 'lanjutan') return main;

    final req = _req;
    final reqPath = cardArtPath(req);
    final name = '${req['name'] ?? ''}';
    final cost = req['cost'] as int?;
    final accent = _bad ? EmbunColors.mist : EmbunColors.gold;
    final info = _bad
        ? 'Gabungkan kartu ini dengan $name di Meja (hari biasa) agar AKTIF '
        'dan bisa dipersembahkan. Kapsul DNA juga bisa dipakai: satu '
        'kapsul cukup untuk dua kartu Rekayasa. Poin habis sekali pakai.'
        : 'Gabungkan kartu ini dengan $name di Meja (hari biasa) agar AKTIF '
        'dan bisa dipersembahkan. Poin habis sekali pakai.';

    return SizedBox(
      width: _w,
      height: _w * cardAspectFor(widget.path),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          main,
          // Keterangan: menutupi bagian bawah gambar, tidak mengubah tata letak.
          if (_info)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: GestureDetector(
                onTap: () => setState(() => _info = false),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accent.withValues(alpha: 0.7)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          cost == null
                              ? 'Syarat: $name'
                              : 'Syarat: $name ($cost)',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: accent)),
                      const SizedBox(height: 4),
                      Text(info,
                          style: const TextStyle(
                              fontSize: 11.5,
                              height: 1.35,
                              color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
          // Kartu syarat mini, menindih sudut kiri atas.
          Positioned(
            top: -8,
            left: -8,
            child: GestureDetector(
              onTap: () {
                Sfx.I.click(Snd.clickTung);
                setState(() => _info = !_info);
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    foregroundDecoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accent, width: 1.8),
                    ),
                    child: reqPath != null
                        ? CardArt(path: reqPath, width: _miniW, glow: accent)
                        : SizedBox(
                      width: _miniW,
                      height: _miniW * 1.5,
                      child: Center(
                          child: GameIcon(
                              _bad ? 'bulirhitam' : 'bulirembun',
                              size: 40)),
                    ),
                  ),
                  Positioned(
                    right: -5,
                    bottom: -5,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                        border: Border.all(color: accent, width: 1.4),
                      ),
                      child: Icon(Icons.info_outline, size: 13, color: accent),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pratinjau besar kartu (tekan-tahan di kartu mana pun): gambar, nama,
/// jenis, harga, dan deskripsi efek. Deskripsi tidak tercetak di gambar, jadi
/// pemain membacanya di sini.
///
/// Bila [actionLabel] dan [onAction] diisi (mis. kartu kuning di Meja), muncul
/// tombol utama di atas "Tutup"; dialog menutup dulu, baru [onAction] jalan.
Future<void> showCardPreview(
    BuildContext context,
    Map<String, dynamic> def, {
      String? actionLabel,
      Future<void> Function()? onAction,
      Map<String, Map<String, dynamic>>? defs,
    }) {
  final bad = def['side'] == 'antagonis';
  final glow = bad
      ? EmbunColors.mist
      : def['kind'] == 'siang'
      ? EmbunColors.gold
      : EmbunColors.leaf;
  final act = onAction;
  final path = cardArtPath(def);
  final cost = def['cost'] as int?;
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(20),
      child: OrnatePanel(
        accent: bad ? EmbunColors.mist : EmbunColors.gold,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (path != null) ...[
                _CardPreviewArt(
                    def: def, path: path, glow: glow, defs: defs),
                const SizedBox(height: 14),
              ],
              Text('${def['name'] ?? ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: EmbunColors.gold)),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GameIcon(kindIcon[def['kind']] ?? 'item', size: 28),
                  const SizedBox(width: 6),
                  Text(kindLabel[def['kind']] ?? '',
                      style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  if (cost != null) ...[
                    const SizedBox(width: 16),
                    GameIcon(bad ? 'bulirhitam' : 'bulirembun', size: 28),
                    const SizedBox(width: 4),
                    Text('$cost',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: EmbunColors.gold)),
                  ],
                ],
              ),
              const Divider(height: 22),
              Text('${def['description'] ?? ''}', textAlign: TextAlign.center),
              const SizedBox(height: 14),
              if (actionLabel != null && act != null) ...[
                EmbunButton(
                  label: actionLabel,
                  icon: 'centang',
                  expand: true,
                  onPressed: () {
                    Navigator.pop(ctx);
                    act();
                  },
                ),
                const SizedBox(height: 8),
              ],
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
  );
}

class CardTile extends StatelessWidget {
  final Map<String, dynamic>? def;
  final String fallbackName;
  final bool selected;
  final bool dim;
  final bool showCost;
  final int? costOverride; // harga setelah Kabar Pagi
  final String? badge; // mis. 'Terbeli', menggantikan harga
  final VoidCallback? onTap;

  /// Tampil abu-abu (kartu yang tak bisa dipakai pemegangnya).
  final bool gray;

  /// Gambar kartu memudar jadi abu-abu gelap (kartu lanjutan yang belum
  /// digabung dengan kartu poin). Hanya gambarnya; label dan harga tetap
  /// terang. Berubah dengan transisi halus saat kartu menjadi aktif.
  final bool faded;

  /// Lebar tile; tinggi = lebar * [aspect]. Dihitung dari ruang yang tersedia
  /// supaya pas di ponsel maupun desktop.
  final double width;

  /// Tinggi/lebar; null = ikut jenis kartu ([cardAspectForDef]): antagonis
  /// dan malam 2:3, item protagonis 9/7.
  final double? aspect;

  /// Label kecil di pojok kiri atas (mis. "AKTIF" / "Butuh poin").
  final String? tag;

  /// Jumlah kartu sama yang ditumpuk; lencana "xN" di pojok kanan bawah
  /// muncul bila lebih dari 1.
  final int count;

  const CardTile({
    super.key,
    required this.def,
    required this.fallbackName,
    this.selected = false,
    this.dim = false,
    this.showCost = false,
    this.costOverride,
    this.badge,
    this.onTap,
    this.gray = false,
    this.faded = false,
    this.width = 140,
    this.aspect,
    this.tag,
    this.count = 1,
  });

  @override
  Widget build(BuildContext context) {
    final bad = def?['side'] == 'antagonis';
    final cost = costOverride ?? (def?['cost'] as int?) ?? 0;
    final path = cardArtPath(def);
    final d = def;
    final h = width * (aspect ?? cardAspectForDef(def));

    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
        Sfx.I.click(Snd.clickTung);
        onTap!();
      },
      onLongPress: d == null ? null : () => showCardPreview(context, d),
      child: _Grayscale(
        on: gray,
        child: Opacity(
          opacity: dim ? 0.45 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: width,
            height: h,
            transform: Matrix4.translationValues(0, selected ? -10 : 0, 0),
            padding: path == null ? const EdgeInsets.all(10) : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: faded
                  ? const Color(0xFF1C1F1E)
                  : bad
                  ? const Color(0xFF241F2E)
                  : const Color(0xFF1F3A33),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? EmbunColors.gold
                    : EmbunColors.goldDim.withValues(alpha: 0.6),
                width: selected ? 3 : 1.2,
              ),
              boxShadow: selected
                  ? [
                BoxShadow(
                    color: EmbunColors.gold.withValues(alpha: 0.45),
                    blurRadius: 14),
              ]
                  : null,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                path == null
                    ? _textBody(bad, cost)
                    : _artBody(path, bad, cost, d != null),
                if (count > 1)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: EmbunColors.gold.withValues(alpha: 0.8)),
                      ),
                      child: Text('\u00d7$count',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: EmbunColors.gold)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Gambar kartu; memudar halus ke abu-abu gelap bila [faded].
  Widget _image(String path) {
    final img = GameImage(path: path, cacheWidth: 320);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: faded ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      child: img,
      builder: (context, t, child) {
        if (t <= 0.001) return child!;
        return ColorFiltered(
          colorFilter: ColorFilter.matrix(_lerpMatrix(t)),
          child: child,
        );
      },
    );
  }

  /// Gambar kartu memenuhi tile; harga di pojok kanan atas.
  Widget _artBody(String path, bool bad, int cost, bool hasInfo) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _image(path),
          if (showCost)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.fromLTRB(2, 1, 8, 1),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: EmbunColors.gold.withValues(alpha: 0.7)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GameIcon(bad ? 'bulirhitam' : 'bulirembun', size: 24),
                    const SizedBox(width: 3),
                    Text(badge ?? '$cost',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: EmbunColors.gold)),
                  ],
                ),
              ),
            ),
          if (tag != null)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: (tag == 'AKTIF' ? EmbunColors.leaf : EmbunColors.goldDim)
                          .withValues(alpha: 0.9)),
                ),
                child: Text(tag!,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: tag == 'AKTIF'
                            ? EmbunColors.leaf
                            : EmbunColors.gold)),
              ),
            ),
          if (selected)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: GameIcon('dipilih', width: width * 0.7, height: width * 0.3),
              ),
            ),
          if (hasInfo && !selected)
            const Positioned(
              left: 6,
              bottom: 6,
              child: GameIcon('info', size: 24),
            ),
        ],
      ),
    );
  }

  /// Tampilan teks lama, dipakai bila gambar kartu belum ada.
  Widget _textBody(bool bad, int cost) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(def?['name'] ?? fallbackName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(kindLabel[def?['kind']] ?? '',
            style: const TextStyle(fontSize: 11, color: Colors.white54)),
        const SizedBox(height: 6),
        Expanded(
          child: Text(def?['description'] ?? '',
              style: const TextStyle(fontSize: 12)),
        ),
        if (showCost)
          Row(
            children: [
              GameIcon(bad ? 'bulirhitam' : 'bulirembun', size: 24),
              const SizedBox(width: 4),
              Text(badge ?? '$cost'),
            ],
          ),
      ],
    );
  }
}

/// Punggung kartu item: sama untuk semua kartu agar identitas penyerah tidak
/// bocor. [dark] hanya untuk kartu milik sendiri; jangan dipakai pada kartu
/// yang terlihat pemain lain.
class CardBack extends StatelessWidget {
  final bool dark;
  const CardBack({super.key, this.dark = false});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: SizedBox(
      width: 70,
      height: dark ? 105 : 100, // dark = 2:3
      child: GameImage(path: itemBackPath(dark: dark), cacheWidth: 200),
    ),
  );
}

/// Mengubah anak menjadi hitam-putih bila [on].
class _Grayscale extends StatelessWidget {
  final bool on;
  final Widget child;
  const _Grayscale({required this.on, required this.child});

  @override
  Widget build(BuildContext context) => on
      ? ColorFiltered(
    colorFilter: const ColorFilter.matrix(<double>[
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0, 0, 0, 1, 0,
    ]),
    child: child,
  )
      : child;
}