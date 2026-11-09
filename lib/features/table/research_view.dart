import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'card_tile.dart';

/// Pasar Riset: fase singkat di awal tiap hari biasa. Hanya menjual kartu
/// poin dan kartu lanjutan, dengan harga lebih mahal dari Pasar Pagi. Stok
/// tetap dan jatah belinya terpisah dari jatah Pasar Pagi. Harga dan jatah
/// dihitung server; layar ini hanya menampilkannya.
class ResearchView extends StatefulWidget {
  final GameRepository repo;
  final String gameId;
  final int day;
  final Map<String, Map<String, dynamic>> defs;
  final double balance;
  final bool jailed;

  /// Sudah menekan "Selesai" (siap) menurut server.
  final bool iAmReady;
  final int readyCount;
  final int total;
  final bool dark;
  final VoidCallback? onBought;

  const ResearchView({
    super.key,
    required this.repo,
    required this.gameId,
    required this.day,
    required this.defs,
    required this.balance,
    required this.jailed,
    required this.iAmReady,
    required this.readyCount,
    required this.total,
    this.dark = false,
    this.onBought,
  });

  @override
  State<ResearchView> createState() => _ResearchViewState();
}

class _ResearchViewState extends State<ResearchView> {
  List<Map<String, dynamic>> _items = const [];
  int _limit = 2;
  int _bought = 0;
  bool _loaded = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.repo.researchStock(widget.gameId);
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(
            (r['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
        _limit = (r['limit'] as num?)?.toInt() ?? 2;
        _bought = (r['bought'] as num?)?.toInt() ?? 0;
        _loaded = true;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = errMsg(e));
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  int get _left => (_limit - _bought).clamp(0, 99).toInt();
  bool get _closed => widget.iAmReady || widget.jailed;

  Future<void> _buy(Map<String, dynamic> it) async {
    final id = it['card_id'] as String;
    final name = (widget.defs[id]?['name'] as String?) ?? id;
    setState(() => _busy = true);
    try {
      await widget.repo.buyResearch(widget.gameId, id);
      widget.onBought?.call();
      _toast('$name masuk ke tanganmu.');
      await _load();
    } catch (e) {
      _toast(errMsg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    try {
      await widget.repo.finishResearch(widget.gameId);
    } catch (e) {
      _toast(errMsg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.dark ? EmbunColors.mist : EmbunColors.gold;
    return LayoutBuilder(builder: (context, box) {
      final inner = box.maxWidth - 24;
      final cols = inner >= 620 ? 4 : (inner >= 400 ? 3 : 2);
      final tile = ((inner - 24 - (cols - 1) * 12) / cols)
          .clamp(96.0, 150.0)
          .toDouble();
      return Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  children: [
                    _header(accent),
                    const SizedBox(height: 12),
                    if (widget.jailed)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text(
                            'Kamu sedang dikurung dan tidak bisa berbelanja.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: EmbunColors.blood)),
                      ),
                    if (_error != null)
                      Text(_error!,
                          style: const TextStyle(color: EmbunColors.blood))
                    else if (!_loaded)
                      const Padding(
                          padding: EdgeInsets.all(24), child: EmbunLoading())
                    else if (_items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Belum ada kartu riset yang dijual.',
                              style: TextStyle(color: Colors.white60)),
                        )
                      else
                        ..._sections(tile, accent),
                  ],
                ),
              ),
            ),
          ),
          _footer(),
        ],
      );
    });
  }

  Widget _header(Color accent) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: accent.withValues(alpha: 0.5)),
    ),
    child: Column(
      children: [
        ikonPath('title-pasarriset') != null
            ? const GameIcon('title-pasarriset', width: 210, height: 48)
            : Text('Pasar Riset',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: accent)),
        const SizedBox(height: 2),
        const Text(
          'Kartu poin dan lanjutan, +20% dari harga biasa.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: Colors.white70),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _stat('Embunmu', '${widget.balance.floor()}',
                    accent)),
            const SizedBox(width: 10),
            Expanded(
                child: _stat(
                    'Jatah riset',
                    '$_left / $_limit',
                    _left > 0 ? EmbunColors.leaf : Colors.white38)),
          ],
        ),
      ],
    ),
  );

  Widget _stat(String label, String value, Color c) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.white60)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: c)),
      ],
    ),
  );

  List<Widget> _sections(double tile, Color accent) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final it in _items) {
      final k = (widget.defs[it['card_id']]?['kind'] as String?) ?? 'poin';
      groups.putIfAbsent(k, () => []).add(it);
    }
    const titles = {
      'poin': 'Kartu poin',
      'lanjutan': 'Kartu lanjutan',
    };
    const hints = {
      'poin': 'Bahan untuk mengisi kartu lanjutan.',
      'lanjutan': 'Perlu digabung dengan kartu poin sebelum bisa dipakai.',
    };
    final out = <Widget>[];
    for (final k in const ['poin', 'lanjutan']) {
      final list = groups[k];
      if (list == null || list.isEmpty) continue;
      out.add(Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: Colors.white60),
              children: [
                TextSpan(
                    text: titles[k],
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: accent)),
                TextSpan(text: '   ${hints[k]}'),
              ],
            ),
          ),
        ),
      ));
      out.add(Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 14,
        children: [for (final it in list) _tile(it, tile)],
      ));
      out.add(const SizedBox(height: 14));
    }
    return out;
  }

  Widget _footer() => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.55),
      border: Border(
          top: BorderSide(
              color: EmbunColors.goldDim.withValues(alpha: 0.5))),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: EmbunButton(
          label: widget.iAmReady
              ? 'Menunggu ${widget.readyCount}/${widget.total}'
              : 'Selesai riset',
          expand: true,
          onPressed: (widget.iAmReady || _busy) ? null : _finish,
        ),
      ),
    ),
  );

  Widget _tile(Map<String, dynamic> it, double w) {
    final id = it['card_id'] as String;
    final price = (it['price'] as num).toInt();
    final done = it['bought'] == true;
    final afford = widget.balance >= price;
    final can = !_closed && !done && _left > 0 && afford && !_busy;
    final label = done
        ? 'Terbeli'
        : (!afford && !_closed && _left > 0)
        ? 'Embun kurang'
        : 'Beli · $price';
    return SizedBox(
      width: w,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CardTile(
            def: widget.defs[id],
            fallbackName: id,
            width: w,
            showCost: true,
            costOverride: price,
            tag: done ? null : '+20%',
            dim: !can,
          ),
          const SizedBox(height: 8),
          EmbunButton(
            label: label,
            expand: true,
            height: 40,
            kind: can ? EmbunButtonKind.primary : EmbunButtonKind.secondary,
            onPressed: can ? () => _buy(it) : null,
          ),
        ],
      ),
    );
  }
}