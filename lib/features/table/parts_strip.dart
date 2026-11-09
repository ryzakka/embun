import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';

/// Lencana satu bagian Hayu (assets/bentang/pohonindikator-akar|batang|tanah).
/// Kondisi memengaruhi tampilan: layu memucat dengan cincin kuning, rusak
/// menggelap dengan cincin merah, subur berpendar hijau.
class PartBadge extends StatelessWidget {
  final String part; // 'akar' | 'batang' | 'tanah'
  final String cond; // 'subur' | 'biasa' | 'layu' | 'rusak'
  final double size;
  const PartBadge(this.part, this.cond, {super.key, this.size = 28});

  static const _desat = ColorFilter.matrix(<double>[
    0.55, 0.30, 0.10, 0, 0,
    0.20, 0.65, 0.10, 0, 0,
    0.20, 0.30, 0.45, 0, 0,
    0, 0, 0, 1, 0,
  ]);
  static const _dark = ColorFilter.matrix(<double>[
    0.30, 0.15, 0.05, 0, 0,
    0.10, 0.25, 0.05, 0, 0,
    0.10, 0.15, 0.20, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final col = PartsStrip.colorOf(cond);
    final p = sceneryPath('pohonindikator-$part');
    Widget img = GameImage(
        path: p, fit: BoxFit.contain, cacheWidth: (size * 3).round());
    if (cond == 'layu') img = ColorFiltered(colorFilter: _desat, child: img);
    if (cond == 'rusak') img = ColorFiltered(colorFilter: _dark, child: img);
    final glow = cond == 'biasa'
        ? null
        : [BoxShadow(color: col.withValues(alpha: 0.55), blurRadius: size * 0.35)];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: cond == 'biasa' ? null : Border.all(color: col, width: 1.5),
        boxShadow: glow,
      ),
      child: p == null
          ? Icon(PartsStrip.fallbackIcon(part), size: size * 0.7, color: col)
          : img,
    );
  }
}

/// Kondisi tiga bagian Hayu selain daun: Akar, Batang, Tanah.
/// Skor aslinya tersembunyi; pemain hanya melihat kondisinya.
class PartsStrip extends StatelessWidget {
  final String akar;
  final String batang;
  final String tanah;
  final bool compact;
  final int leaves;
  final int winLeaves;
  const PartsStrip({
    super.key,
    required this.akar,
    required this.batang,
    required this.tanah,
    this.compact = false,
    this.leaves = 0,
    this.winLeaves = 20,
  });

  static Color colorOf(String c) => switch (c) {
    'subur' => const Color(0xFF7BD88F),
    'layu' => Colors.amber,
    'rusak' => const Color(0xFFE5484D),
    _ => Colors.white54,
  };

  static IconData fallbackIcon(String part) => switch (part) {
    'akar' => Icons.water_drop,
    'batang' => Icons.park,
    _ => Icons.landscape,
  };

  static String partName(String part) => switch (part) {
    'akar' => 'Akar',
    'batang' => 'Batang',
    _ => 'Tanah',
  };

  Widget _one(String part, String c) {
    final col = colorOf(c);
    return Tooltip(
      message: '${partName(part)}: $c',
      child: compact
          ? Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: PartBadge(part, c, size: 20),
      )
          : Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            PartBadge(part, c, size: 26),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(partName(part),
                      maxLines: 1,
                      style: const TextStyle(
                          fontSize: 10.5,
                          height: 1.1,
                          color: Colors.white60)),
                  Text(c,
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          color: col)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = [_one('akar', akar), _one('batang', batang), _one('tanah', tanah)];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showPartsSheet(context,
          akar: akar,
          batang: batang,
          tanah: tanah,
          leaves: leaves,
          winLeaves: winLeaves),
      child: Container(
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
            : const EdgeInsets.fromLTRB(8, 4, 6, 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(compact ? 12 : 10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: compact
            ? Row(mainAxisSize: MainAxisSize.min, children: items)
            : Column(mainAxisSize: MainAxisSize.min, children: items),
      ),
    );
  }
}

const _effectText = <String, Map<String, String>>{
  'akar': {
    'subur': 'Embun harian warga bertambah 25%.',
    'biasa': 'Embun harian warga normal.',
    'layu': 'Embun harian warga berkurang 25%.',
    'rusak': 'Embun harian warga tinggal separuh.',
  },
  'batang': {
    'subur': 'Perlindungan malam persembahan +1.',
    'biasa': 'Perlindungan malam persembahan normal.',
    'layu': 'Perlindungan malam persembahan -1.',
    'rusak': 'Perlindungan malam persembahan -2.',
  },
  'tanah': {
    'subur': 'Kabut lebih tipis dan ulat senyap lebih cepat lenyap.',
    'biasa': 'Kabut dan ulat senyap normal.',
    'layu': 'Kabut sedikit lebih tebal.',
    'rusak': 'Kabut jauh lebih tebal dan satu ulat senyap tambahan tiap malam.',
  },
};

const _partDesc = <String, String>{
  'akar': 'Akar menyerap embun dari tanah dan menghidupi seluruh desa.',
  'batang': 'Batang menopang Hayu dan menahan serangan malam.',
  'tanah': 'Tanah di kaki Hayu menentukan kabut dan hama.',
};

/// Sheet penjelasan: gambar zoom tiap bagian, kondisinya, dan pengaruhnya.
Future<void> showPartsSheet(
    BuildContext context, {
      required String akar,
      required String batang,
      required String tanah,
      required int leaves,
      required int winLeaves,
    }) {
  final conds = {'akar': akar, 'batang': batang, 'tanah': tanah};
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF121812),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, sc) => ListView(
        controller: sc,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          const Center(
            child: Text('Keadaan Hayu',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
                'Angka bagian disembunyikan; hanya kondisinya yang terlihat. '
                    'Perubahan baru terasa di malam persembahan berikutnya.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white60)),
          ),
          const SizedBox(height: 12),
          _PartCard(
            zoom: 'pohonindikator-zoomdedaunan',
            badge: SizedBox(
              width: 44,
              height: 44,
              child: GameImage(
                  path: sceneryPath('pohonindikator-daun'),
                  fit: BoxFit.contain,
                  cacheWidth: 132),
            ),
            title: 'Daun',
            status: '$leaves daun',
            color: const Color(0xFF7BD88F),
            desc: 'Warga menang bila daun mencapai $winLeaves.',
            effect: 'Daun bertambah dan berkurang lewat persembahan.',
          ),
          for (final part in const ['akar', 'batang', 'tanah'])
            _PartCard(
              zoom: 'pohonindikator-zoom$part',
              badge: PartBadge(part, conds[part]!, size: 44),
              title: PartsStrip.partName(part),
              status: conds[part]!,
              color: PartsStrip.colorOf(conds[part]!),
              desc: _partDesc[part]!,
              effect: _effectText[part]![conds[part]!]!,
            ),
        ],
      ),
    ),
  );
}

class _PartCard extends StatelessWidget {
  final String zoom;
  final Widget badge;
  final String title;
  final String status;
  final Color color;
  final String desc;
  final String effect;
  const _PartCard({
    required this.zoom,
    required this.badge,
    required this.title,
    required this.status,
    required this.color,
    required this.desc,
    required this.effect,
  });

  @override
  Widget build(BuildContext context) {
    final z = sceneryPath(zoom);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: GameImage(path: z, cacheWidth: 900),
          ),
          Positioned.fill(
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.62)),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                badge,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Text(status,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: color)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(desc,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70)),
                      const SizedBox(height: 4),
                      Text(effect,
                          style: const TextStyle(fontSize: 12.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}