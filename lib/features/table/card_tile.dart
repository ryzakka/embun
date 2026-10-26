import 'package:flutter/material.dart';

const kindLabel = {
  'persembahan': 'Persembahan',
  'sekali_pakai': 'Sekali pakai',
  'penguat': 'Penguat',
};

class CardTile extends StatelessWidget {
  final Map<String, dynamic>? def;
  final String fallbackName;
  final bool selected;
  final bool dim;
  final bool showCost;
  final int? costOverride; // harga setelah Kabar Pagi
  final String? badge; // mis. 'Terbeli', menggantikan harga
  final VoidCallback? onTap;

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
  });

  @override
  Widget build(BuildContext context) {
    final bad = def?['side'] == 'antagonis';
    final cost = costOverride ?? (def?['cost'] as int?) ?? 0;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: dim ? 0.45 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 140,
          height: 180,
          transform: Matrix4.translationValues(0, selected ? -10 : 0, 0),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: bad ? const Color(0xFF241F2E) : const Color(0xFF1F3A33),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? Colors.amberAccent : Colors.white24,
              width: selected ? 3 : 1,
            ),
          ),
          child: Column(
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
          ),
        ),
      ),
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