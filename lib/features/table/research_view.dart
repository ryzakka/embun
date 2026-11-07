import 'package:flutter/material.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'card_tile.dart';
import 'player_status.dart';

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
    final price = (it['price'] as num).toInt();
    final name = (widget.defs[id]?['name'] as String?) ?? id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Beli $name?'),
        content: Text('Harga $price embun. Jatah riset tersisa $_left.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Beli')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
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
      final cols = box.maxWidth >= 640 ? 4 : (box.maxWidth >= 420 ? 3 : 2);
      final tile = ((box.maxWidth - 24 - (cols - 1) * 10) / cols)
          .clamp(96.0, 150.0)
          .toDouble();
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        child: Column(
          children: [
            Text('Pasar Riset',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: accent)),
            const SizedBox(height: 4),
            const Text(
              'Kartu poin dan lanjutan dijual di sini, +20% dari harga biasa.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                StatusTag(
                    text: 'Embun ${widget.balance.floor()}', color: accent),
                StatusTag(
                    text: 'Jatah riset $_left/$_limit',
                    color: _left > 0 ? EmbunColors.leaf : Colors.white38),
              ],
            ),
            const SizedBox(height: 14),
            if (widget.jailed)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text('Kamu sedang dikurung dan tidak bisa berbelanja.',
                    style: TextStyle(color: EmbunColors.blood)),
              ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: EmbunColors.blood))
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
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 12,
                  children: [
                    for (final it in _items) _tile(it, tile),
                  ],
                ),
            const SizedBox(height: 18),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: EmbunButton(
                label: widget.iAmReady
                    ? 'Menunggu ${widget.readyCount}/${widget.total}'
                    : 'Selesai riset',
                expand: true,
                onPressed: (widget.iAmReady || _busy) ? null : _finish,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _tile(Map<String, dynamic> it, double w) {
    final id = it['card_id'] as String;
    final price = (it['price'] as num).toInt();
    final done = it['bought'] == true;
    final afford = widget.balance >= price;
    final can = !_closed && !done && _left > 0 && afford && !_busy;
    return CardTile(
      def: widget.defs[id],
      fallbackName: id,
      width: w,
      showCost: true,
      costOverride: price,
      badge: done ? 'Terbeli' : null,
      tag: done ? null : '+20%',
      dim: !can,
      onTap: can ? () => _buy(it) : null,
    );
  }
}