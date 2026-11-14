import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../../data/lobby_repository.dart';
import '../common/ornate.dart';
import '../table/ability_panel.dart';
import '../table/flip_card.dart';

/// Tiga kartu biru dari server. Identitas kartu tertutup tidak dikirim ke UI.
class AbilityPick extends StatefulWidget {
  const AbilityPick({
    super.key,
    required this.repo,
    required this.gameId,
    required this.onDone,
  });
  final LobbyRepository repo;
  final String gameId;
  final VoidCallback onDone;

  @override
  State<AbilityPick> createState() => _AbilityPickState();
}

class _AbilityPickState extends State<AbilityPick> {
  Map<String, dynamic>? _draft;
  String? _error;
  int? _selected;
  bool _busy = false;
  bool _done = false;
  static const _blue = Color(0xFF8FCBFF);
  bool get _chosen => _draft?['chosen'] == true;
  Map<String, dynamic>? get _ability {
    final value = _draft?['ability'];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final draft = await widget.repo.myAbilityDraft(widget.gameId);
      if (mounted) {
        setState(() {
          _draft = draft;
          _selected = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = errMsg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    if (_busy || _chosen || _selected == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final draft = await widget.repo.chooseAbility(
        widget.gameId,
        _selected! + 1,
      );
      if (mounted) setState(() => _draft = draft);
    } catch (e) {
      // Termasuk koneksi putus setelah server menyimpan pilihan: Muat ulang
      // mengambil hasil yang sama, tidak melakukan pemilihan kedua.
      if (mounted) setState(() => _error = errMsg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _continue() {
    if (_done || !_chosen || _ability == null) return;
    _done = true;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF07131E),
    child: SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 720,
                  minHeight: math.max(0, box.maxHeight - 40),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'PROLOG · KEMAMPUAN',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _blue,
                        fontSize: 12,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _chosen
                          ? 'Kemampuan Rahasiamu'
                          : 'Pilih Kartu Kemampuanmu',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _chosen
                          ? 'Hanya kamu yang melihat kartu ini.'
                          : 'Tiga kartu biru diacak untukmu. Pilih satu kartu tertutup, '
                                'lalu kunci pilihanmu untuk membukanya.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_chosen && _ability != null)
                      _result(_ability!)
                    else if (_draft != null)
                      _cards()
                    else if (_busy)
                      const Center(
                        child: CircularProgressIndicator(color: _blue),
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.orangeAccent),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _load,
                        child: const Text('Muat ulang'),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (_chosen && _ability != null)
                      EmbunButton(
                        label: 'Aku sudah mengerti',
                        icon: 'centang',
                        onPressed: _continue,
                      )
                    else if (_draft != null)
                      EmbunButton(
                        label: _busy ? 'Mengunci pilihan…' : 'Kunci pilihan',
                        icon: 'lock',
                        onPressed: _busy || _selected == null ? null : _confirm,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _cards() => LayoutBuilder(
    builder: (context, box) {
      final count = (_draft?['count'] as int?) ?? 0;
      final width = math.min(
        180.0,
        math.max(0.0, (box.maxWidth - 12 * (count - 1)) / math.max(1, count)),
      );
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Semantics(
              label: 'Kartu kemampuan ${i + 1}',
              selected: _selected == i,
              button: true,
              child: InkWell(
                key: ValueKey('ability-slot-${i + 1}'),
                onTap: _busy ? null : () => setState(() => _selected = i),
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: width,
                  child: Column(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selected == i ? _blue : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: CardBackFace(
                          width: math.max(0, width - 6),
                          height: math.max(0, width - 6) * abilityCardAspect,
                          backPath: abilityBackPath(),
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Kartu ${i + 1}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    },
  );

  Widget _result(Map<String, dynamic> def) => Column(
    children: [
      FlipCard(
        key: const ValueKey('chosen-ability'),
        index: 0,
        width: 170,
        height: 170 * abilityCardAspect,
        revealed: true,
        backPath: abilityBackPath(),
        backFit: BoxFit.contain,
        glow: _blue,
        front: AbilityCardView(def: def, width: 170),
      ),
      const SizedBox(height: 18),
      Text(
        '${def['name']}',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _blue,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        def['kind'] == 'pasif' ? 'PASIF' : 'SEKALI PAKAI',
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 11,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        '${def['description'] ?? ''}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, height: 1.5),
      ),
    ],
  );
}
