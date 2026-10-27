import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../common/art.dart';
import 'card_tile.dart';

class OfferingView extends StatefulWidget {
  final GameRepository repo;
  final String gameId;
  final int leaves;
  final bool isAntag;
  final List<Map<String, dynamic>> hand;
  final Map<String, Map<String, dynamic>> defs;
  final List<Map<String, dynamic>> players;
  final ValueChanged<int> onSubmitted;

  const OfferingView({
    super.key,
    required this.repo,
    required this.gameId,
    required this.leaves,
    required this.isAntag,
    required this.hand,
    required this.defs,
    required this.players,
    required this.onSubmitted,
  });

  @override
  State<OfferingView> createState() => _OfferingViewState();
}

class _OfferingViewState extends State<OfferingView> {
  final Set<String> sel = {};
  String? targetId;
  bool busy = false;
  int? _fog;

  String? get _samaranId {
    for (final h in widget.hand) {
      if (h['card_id'] == 'embun_samaran') return h['id'] as String;
    }
    return null;
  }

  bool get _needsTarget {
    for (final h in widget.hand) {
      if (!sel.contains(h['id'])) continue;
      final eff = widget.defs[h['card_id']]?['effect'];
      if (eff is Map && eff['needs_target'] == true) return true;
    }
    return false;
  }

  /// Si Terbisik wajib menyumbang Embun Samaran: pilih otomatis begitu
  /// kartunya ada di tangan (tangan bisa tiba belakangan).
  /// Pilihan yang kartunya sudah tidak ada di tangan dibuang dulu, supaya
  /// sisa pilihan lama tidak ikut terkirim dan ditolak server.
  void _preselect() {
    final ids = {for (final h in widget.hand) h['id'] as String};
    sel.removeWhere((x) => !ids.contains(x));
    if (!widget.isAntag) return;
    final s = _samaranId;
    if (s == null || sel.contains(s)) return;
    if (sel.length >= 2) sel.remove(sel.first);
    sel.add(s);
  }

  @override
  void initState() {
    super.initState();
    _preselect();
    widget.repo.fogFor(widget.players.length).then((v) {
      if (mounted) setState(() => _fog = v);
    });
  }

  @override
  void didUpdateWidget(covariant OfferingView old) {
    super.didUpdateWidget(old);
    _preselect();
  }

  void _toggle(String handId) {
    if (widget.isAntag && handId == _samaranId) return; // sumbangan wajib
    HapticFeedback.selectionClick();
    setState(() {
      if (sel.contains(handId)) {
        sel.remove(handId);
      } else if (sel.length < 2) {
        sel.add(handId);
      } else {
        // Sudah 2 kartu: ganti pilihan tertua (kecuali sumbangan wajib).
        final drop = sel.firstWhere(
                (x) => !(widget.isAntag && x == _samaranId),
            orElse: () => '');
        if (drop.isNotEmpty) {
          sel.remove(drop);
          sel.add(handId);
        }
      }
      if (!_needsTarget) targetId = null;
    });
  }

  Future<void> _submit() async {
    if (_needsTarget && targetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pilih sasaran kartumu dulu')),
      );
      return;
    }
    final n = sel.length;
    setState(() => busy = true);
    try {
      await widget.repo.submitOffering(
        widget.gameId,
        sel.toList(),
        target: _needsTarget ? targetId : null,
      );
      HapticFeedback.mediumImpact();
      widget.onSubmitted(n);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errMsg(e))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final others = widget.players
        .where((p) => p['user_id'] != widget.repo.myId)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              const GameIcon('titlepersembahan', width: 180, height: 36),
              const SizedBox(height: 6),
              Expanded(child: TreePortrait(leaves: widget.leaves)),
              const SizedBox(height: 6),
              Text('${widget.leaves} daun',
                  style: Theme.of(context).textTheme.titleLarge),
              Text(
                widget.isAntag
                    ? 'Wajib menyumbang: Papan Penanda sudah terpilih. Tambah 1 kartu lagi jika mau.'
                    : 'Hari persembahan: serahkan 1-2 kartu',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              if (_fog != null)
                Text(
                  'Malam ini kabut akan menggerogoti $_fog daun.',
                  style: const TextStyle(
                      color: Color(0xFFB07CE8), fontSize: 12),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
        if (_needsTarget) ...[
          const SizedBox(height: 6),
          const Text('Pilih sasaran kartumu:',
              style: TextStyle(fontSize: 12, color: Colors.amberAccent)),
          const SizedBox(height: 4),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final p in others)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(p['name'] as String),
                      selected: targetId == p['user_id'],
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) =>
                          setState(() => targetId = p['user_id'] as String),
                    ),
                  ),
              ],
            ),
          ),
        ],
        SizedBox(
          height: 196,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(top: 14),
            itemCount: widget.hand.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final h = widget.hand[i];
              final id = h['id'] as String;
              final cardId = h['card_id'] as String;
              return CardTile(
                def: widget.defs[cardId],
                fallbackName: cardId,
                selected: sel.contains(id),
                onTap: () => _toggle(id),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: busy || sel.isEmpty ? null : _submit,
            child: Text('Serahkan (${sel.length}/2)'),
          ),
        ),
      ],
    );
  }
}