import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';

const kindLabel = {
  'persembahan': 'Persembahan',
  'sekali_pakai': 'Sekali pakai',
  'penguat': 'Penguat',
};

/// Pratinjau besar kartu (tekan-tahan di kartu mana pun): gambar, nama,
/// jenis, dan deskripsi efek. Deskripsi tidak tercetak di gambar, jadi
/// pemain membacanya di sini.
Future<void> showCardPreview(BuildContext context, Map<String, dynamic> def) {
  final bad = def['side'] == 'antagonis';
  final glow = bad ? const Color(0xFFB07CE8) : const Color(0xFF7FE0A0);
  final path = cardArtPath(def);
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: const Color(0xFF14221F),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (path != null) ...[
                CardArt(path: path, width: 200, glow: glow),
                const SizedBox(height: 14),
              ],
              Text('${def['name'] ?? ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              Text(kindLabel[def['kind']] ?? '',
                  style: const TextStyle(fontSize: 12, color: Colors.white54)),
              const SizedBox(height: 8),
              Text('${def['description'] ?? ''}', textAlign: TextAlign.center),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup'),
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

  /// Lebar tile; tinggi selalu lebar * 9 / 7 (140 -> 180, ukuran lama).
  /// Dihitung dari ruang yang tersedia supaya pas di ponsel maupun desktop.
  final double width;

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
    this.width = 140,
  });

  @override
  Widget build(BuildContext context) {
    final bad = def?['side'] == 'antagonis';
    final cost = costOverride ?? (def?['cost'] as int?) ?? 0;
    final path = cardArtPath(def);
    final d = def;

    return GestureDetector(
      onTap: onTap,
      onLongPress: d == null ? null : () => showCardPreview(context, d),
      child: Opacity(
        opacity: dim ? 0.45 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: width,
          height: width * 9 / 7,
          transform: Matrix4.translationValues(0, selected ? -10 : 0, 0),
          padding: path == null ? const EdgeInsets.all(10) : EdgeInsets.zero,
          decoration: BoxDecoration(
            color: bad ? const Color(0xFF241F2E) : const Color(0xFF1F3A33),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? Colors.amberAccent : Colors.white24,
              width: selected ? 3 : 1,
            ),
          ),
          child: path == null
              ? _textBody(bad, cost)
              : _artBody(path, bad, cost, d != null),
        ),
      ),
    );
  }

  /// Gambar kartu memenuhi tile; harga di pojok kanan atas.
  Widget _artBody(String path, bool bad, int cost, bool hasInfo) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GameImage(path: path, cacheWidth: 320),
          if (showCost)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(bad ? Icons.circle : Icons.water_drop,
                        size: 12,
                        color: bad
                            ? const Color(0xFFB9A3D0)
                            : const Color(0xFF7FD3F7)),
                    const SizedBox(width: 3),
                    Text(badge ?? '$cost',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          if (hasInfo)
            const Positioned(
              left: 6,
              bottom: 6,
              child: Icon(Icons.info_outline,
                  size: 16,
                  color: Colors.white70,
                  shadows: [Shadow(color: Colors.black, blurRadius: 6)]),
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
              Icon(bad ? Icons.circle : Icons.water_drop,
                  size: 14,
                  color: bad
                      ? const Color(0xFF6A5A7A)
                      : const Color(0xFF7FD3F7)),
              const SizedBox(width: 4),
              Text(badge ?? '$cost'),
            ],
          ),
      ],
    );
  }
}

/// Punggung kartu: sama untuk semua kartu agar identitas penyerah tidak bocor.
class CardBack extends StatelessWidget {
  const CardBack({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 70,
    height: 100,
    decoration: BoxDecoration(
      color: const Color(0xFF2B3B52),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white38, width: 2),
    ),
    child: const Icon(Icons.eco, color: Colors.white54, size: 32),
  );
}