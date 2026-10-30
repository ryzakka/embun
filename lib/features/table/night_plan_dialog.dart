import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'card_tile.dart';

/// Dialog Si Terbisik untuk menyiapkan SATU serangan malam (kartu jenis
/// 'malam' yang ia pegang). Kartu dipakai saat malam tiba, setelah hari
/// biasa berakhir. Yang baru menggantikan yang lama; bisa dibatalkan selama
/// hari belum berakhir.
Future<void> showNightPlanDialog(
    BuildContext context, {
      required GameRepository repo,
      required String gameId,
      required int day,
      required List<Map<String, dynamic>> hand,
      required Map<String, Map<String, dynamic>> defs,
      required List<Map<String, dynamic>> others,
      required VoidCallback onChanged,
    }) =>
    showDialog<void>(
      context: context,
      builder: (_) => _NightPlanDialog(
        repo: repo,
        gameId: gameId,
        day: day,
        hand: hand,
        defs: defs,
        others: others,
        onChanged: onChanged,
      ),
    );

class _NightPlanDialog extends StatefulWidget {
  final GameRepository repo;
  final String gameId;
  final int day;
  final List<Map<String, dynamic>> hand;
  final Map<String, Map<String, dynamic>> defs;
  final List<Map<String, dynamic>> others;
  final VoidCallback onChanged;

  const _NightPlanDialog({
    required this.repo,
    required this.gameId,
    required this.day,
    required this.hand,
    required this.defs,
    required this.others,
    required this.onChanged,
  });

  @override
  State<_NightPlanDialog> createState() => _NightPlanDialogState();
}

class _NightPlanDialogState extends State<_NightPlanDialog> {
  Map<String, dynamic>? plan; // rencana yang sudah tersimpan di server
  bool loading = true;
  bool busy = false;
  String? error;
  String? selHand;
  String? target;

  List<Map<String, dynamic>> get _cards => [
    for (final h in widget.hand)
      if (widget.defs[h['card_id']]?['kind'] == 'malam') h,
  ];

  Map<String, dynamic>? _def(String? handId) {
    for (final h in widget.hand) {
      if (h['id'] == handId) return widget.defs[h['card_id']];
    }
    return null;
  }

  bool get _needsTarget {
    final eff = _def(selHand)?['effect'];
    return eff is Map && eff['needs_target'] == true;
  }

  String _nameOf(String? id) {
    for (final p in widget.others) {
      if (p['user_id'] == id) return p['name'] as String;
    }
    return '?';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await widget.repo.nightPlan(widget.gameId, widget.day);
      if (mounted) setState(() => plan = p);
    } catch (_) {
      // tabel belum ada: anggap tidak ada rencana
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repo.armNightCard(widget.gameId,
          handId: selHand, target: _needsTarget ? target : null);
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = errMsg(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _cancelPlan() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repo.armNightCard(widget.gameId);
      widget.onChanged();
      if (mounted) setState(() => plan = null);
    } catch (e) {
      if (mounted) setState(() => error = errMsg(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _planStrip() {
    final hid = plan!['hand_id'] as String?;
    final d = _def(hid);
    final tid = plan!['target_id'] as String?;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: EmbunColors.mist.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EmbunColors.mist.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.nightlight_round, color: EmbunColors.mist),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 13, height: 1.35),
                children: [
                  const TextSpan(text: 'Malam ini: '),
                  TextSpan(
                    text: '${d?['name'] ?? 'kartu'}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: EmbunColors.mist),
                  ),
                  if (tid != null) TextSpan(text: ' → ${_nameOf(tid)}'),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: busy ? null : _cancelPlan,
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cards;
    final selDef = _def(selHand);
    final canSave =
        !busy && selHand != null && (!_needsTarget || target != null);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: OrnatePanel(
          accent: EmbunColors.mist,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.nightlight_round,
                        size: 26, color: EmbunColors.mist),
                    SizedBox(width: 8),
                    Text('Serangan malam',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: EmbunColors.mist)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Siapkan satu kartu di sini; ia dipakai saat malam tiba, '
                      'setelah hari ini berakhir. Semua pemain hanya mendengar '
                      '"Si Terbisik melancarkan serangan", tanpa sasaran dan '
                      'tanpa jenis serangan.',
                  style: TextStyle(
                      fontSize: 12.5, height: 1.4, color: Colors.white60),
                ),
                const SizedBox(height: 14),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  if (plan != null) _planStrip(),
                  if (cards.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Kamu belum punya kartu serangan malam. Belilah di '
                            'Pasar Pagi (kartu bertanda "Serangan malam").',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, height: 1.4),
                      ),
                    )
                  else ...[
                    Text(plan == null ? 'Pilih kartu:' : 'Ganti dengan:',
                        style: const TextStyle(
                            fontSize: 12.5, color: EmbunColors.gold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final h in cards)
                          SizedBox(
                            width: 92,
                            child: Column(
                              children: [
                                CardTile(
                                  def: widget.defs[h['card_id']],
                                  fallbackName: '${h['card_id']}',
                                  width: 92,
                                  selected: selHand == h['id'],
                                  onTap: () => setState(() {
                                    selHand = h['id'] as String;
                                    target = null;
                                  }),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${widget.defs[h['card_id']]?['name'] ?? ''}',
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11.5, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (selDef != null) ...[
                      const SizedBox(height: 10),
                      Text('${selDef['description']}',
                          style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: Colors.white70)),
                    ],
                    if (_needsTarget) ...[
                      const SizedBox(height: 12),
                      const Text('Pilih sasaran:',
                          style: TextStyle(
                              fontSize: 12.5, color: EmbunColors.gold)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (final p in widget.others)
                            ChoiceChip(
                              avatar: PlayerAvatar(
                                path: protagonistPath(
                                    p['character_card'] as String),
                                size: 24,
                              ),
                              label: Text(p['name'] as String),
                              selected: target == p['user_id'],
                              showCheckmark: false,
                              selectedColor:
                              EmbunColors.mist.withValues(alpha: 0.3),
                              onSelected: busy
                                  ? null
                                  : (_) => setState(
                                      () => target = p['user_id'] as String),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    EmbunButton(
                      label: 'Siapkan untuk malam ini',
                      icon: 'show',
                      expand: true,
                      onPressed: canSave ? _save : null,
                    ),
                  ],
                ],
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12.5, color: EmbunColors.blood)),
                ],
                const SizedBox(height: 12),
                EmbunButton(
                  label: 'Tutup',
                  icon: 'silang',
                  kind: EmbunButtonKind.secondary,
                  height: 46,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}