import 'package:flutter/material.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../../data/inspection.dart';
import '../common/ornate.dart';
import 'card_tile.dart';

/// Satu tindakan meningkatkan satu kartu, dengan konfirmasi biaya tiap tahap.
class InspectionWorkshop extends StatefulWidget {
  const InspectionWorkshop({
    super.key,
    required this.repo,
    required this.gameId,
    required this.hand,
    required this.defs,
    required this.balance,
    this.readOnly = false,
    this.onChanged,
  });
  final GameRepository repo;
  final String gameId;
  final List<Map<String, dynamic>> hand;
  final Map<String, Map<String, dynamic>> defs;
  final double balance;
  final bool readOnly;
  final VoidCallback? onChanged;
  @override
  State<InspectionWorkshop> createState() => _InspectionWorkshopState();
}

class _InspectionWorkshopState extends State<InspectionWorkshop> {
  String? _selected;
  bool _busy = false;
  final Map<String, int> _confirmed = {};
  double? _confirmedBalance;

  @override
  void didUpdateWidget(covariant InspectionWorkshop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.balance != widget.balance) _confirmedBalance = null;
  }

  Map<String, dynamic> _effective(Map<String, dynamic> card) => {
    ...card,
    'inspection_level':
    (_confirmed['${card['id']}'] ?? 0) > StethoscopeRules.level(card)
        ? _confirmed['${card['id']}']
        : StethoscopeRules.level(card),
  };

  Future<void> _upgrade(Map<String, dynamic> card) async {
    if (_busy || widget.readOnly) return;
    final cost = StethoscopeRules.nextCost(card);
    if (cost == null) return;
    final next = StethoscopeRules.chances[StethoscopeRules.level(card) + 1];
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tingkatkan ke $next%?'),
        content: Text(
          'Bayar $cost embun untuk Stetoskop ini. '
              'Peningkatan bertahan sampai kartu dipakai. '
              '${next >= 80 ? 'Kartu akan kebal pengelabuan.' : 'Kartu masih dapat dipengaruhi pengelabuan.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Bayar $cost embun'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted || widget.readOnly) return;
    setState(() => _busy = true);
    try {
      final result = await widget.repo.upgradeInspectionCard(
        widget.gameId,
        '${card['id']}',
        StethoscopeRules.level(card),
      );
      if (!mounted) return;
      setState(() {
        _confirmed['${card['id']}'] = (result['inspection_level'] as num)
            .toInt();
        _confirmedBalance = (result['balance'] as num).toDouble();
      });
      widget.onChanged?.call();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Stetoskop kini $next%.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errMsg(error))));
      widget.onChanged?.call();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.hand
        .where((h) => h['card_id'] == 'stetoskop')
        .map(_effective)
        .toList();
    if (cards.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Belum ada Stetoskop. Beli di Pasar Pagi, lalu bawa ke Bengkel Desa.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final card =
        cards.where((h) => h['id'] == _selected).firstOrNull ?? cards.first;
    final level = StethoscopeRules.level(card);
    final chance = StethoscopeRules.chance(card);
    final cost = StethoscopeRules.nextCost(card);
    final balance = _confirmedBalance ?? widget.balance;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Pertajam pembacaan peran',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: EmbunColors.cream,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pilih Stetoskop yang ingin ditingkatkan. Setiap kartu menyimpan tingkatnya sendiri.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 174,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cards.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => CardTile(
                key: ValueKey('inspection-card-${cards[i]['id']}'),
                def: widget.defs['stetoskop'],
                inspectionCard: cards[i],
                fallbackName: 'Stetoskop',
                width: 108,
                tag: '${StethoscopeRules.chance(cards[i])}%',
                selected: cards[i]['id'] == card['id'],
                onTap: _busy
                    ? null
                    : () => setState(() => _selected = '${cards[i]['id']}'),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox.square(
                dimension: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: chance / 100,
                        strokeWidth: 5,
                        backgroundColor: Colors.white12,
                        color: chance >= 80
                            ? EmbunColors.leaf
                            : EmbunColors.gold,
                      ),
                    ),
                    Text(
                      '$chance%',
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chance == 100 ? 'Pembacaan pasti' : 'Peluang berhasil',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      chance >= 80
                          ? 'Kebal pengelabuan'
                          : 'Masih rentan pengelabuan',
                      style: TextStyle(
                        color: chance >= 80
                            ? EmbunColors.leaf
                            : EmbunColors.gold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Jika gagal: peran belum dapat dipastikan.',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (var i = 0; i < StethoscopeRules.chances.length; i++)
                Chip(
                  label: Text(
                    '${StethoscopeRules.chances[i]}%${i == level ? ' • kini' : ''}',
                  ),
                  backgroundColor: i <= level
                      ? EmbunColors.leaf.withValues(alpha: .16)
                      : Colors.white.withValues(alpha: .03),
                  side: BorderSide(
                    color: i == level ? EmbunColors.gold : Colors.white12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            cost == null
                ? 'Tingkat tertinggi tercapai.'
                : balance < cost
                ? 'Embun ${balance.toStringAsFixed(1)} · Perlu $cost'
                : 'Embun ${balance.toStringAsFixed(1)} → ${(balance - cost).toStringAsFixed(1)}',
            style: TextStyle(
              color: cost != null && balance < cost
                  ? EmbunColors.blood
                  : Colors.white70,
            ),
          ),
          const SizedBox(height: 10),
          EmbunButton(
            label: cost == null
                ? 'Sudah 100%'
                : 'Naik ke ${StethoscopeRules.chances[level + 1]}% · $cost',
            icon: 'bulirembun',
            expand: true,
            onPressed:
            _busy || widget.readOnly || cost == null || balance < cost
                ? null
                : () => _upgrade(card),
          ),
          const SizedBox(height: 10),
          const Text(
            'Biaya bertahap: 3 / 5 / 7 / 10 embun. Kartu dan seluruh peningkatannya habis saat dipersembahkan.',
            style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}