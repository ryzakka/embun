import 'package:flutter/material.dart';
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
  final ValueChanged<int> onSubmitted;

  const OfferingView({
    super.key,
    required this.repo,
    required this.gameId,
    required this.leaves,
    required this.isAntag,
    required this.hand,
    required this.defs,
    required this.onSubmitted,
  });

  @override
  State<OfferingView> createState() => _OfferingViewState();
}

class _OfferingViewState extends State<OfferingView> {
  final Set<String> sel = {};
  bool busy = false;
  bool _pre = false;

  String? get _samaranId {
    for (final h in widget.hand) {
      if (h['card_id'] == 'embun_samaran') return h['id'] as String;
    }
    return null;
  }

  void _toggle(String handId) {
    if (widget.isAntag && handId == _samaranId) return; // sumbangan wajib
    setState(() {
      if (sel.contains(handId)) {
        sel.remove(handId);
      } else if (sel.length < 2) {
        sel.add(handId);
      }
    });
  }

  Future<void> _submit() async {
    final n = sel.length;
    setState(() => busy = true);
    try {
      await widget.repo.submitOffering(widget.gameId, sel.toList());
      widget.onSubmitted(n);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final samaran = widget.isAntag ? _samaranId : null;
    if (samaran != null && !_pre) {
      sel.add(samaran);
      _pre = true;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(child: TreePortrait(leaves: widget.leaves)),
              const SizedBox(height: 6),
              Text('${widget.leaves} daun',
                  style: Theme.of(context).textTheme.titleLarge),
              Text(
                widget.isAntag
                    ? 'Wajib menyumbang: Embun Samaran sudah terpilih. Tambah 1 kartu lagi jika mau.'
                    : 'Hari persembahan: serahkan 1-2 kartu',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
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