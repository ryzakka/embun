import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../common/ornate.dart';
import 'player_status.dart';
import 'voting_view.dart';

/// Actions stay inside the existing private ability dialog.
class MeetingAbilityActions extends StatefulWidget {
  const MeetingAbilityActions({
    super.key,
    required this.id,
    required this.phase,
    required this.repo,
    required this.gameId,
    required this.players,
    required this.target,
    required this.onTarget,
    required this.onUse,
    required this.busy,
  });
  final String id, phase, gameId;
  final GameRepository repo;
  final List<Map<String, dynamic>> players;
  final String? target;
  final ValueChanged<String> onTarget;
  final Future<void> Function() onUse;
  final bool busy;
  @override
  State<MeetingAbilityActions> createState() => _MeetingAbilityActionsState();
}

class _MeetingAbilityActionsState extends State<MeetingAbilityActions> {
  Set<String> _locked = {};
  String? _error;
  Timer? _timer;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    if (widget.id == 'pembaca_niat') {
      _load();
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => _load());
    }
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    try {
      final s = await widget.repo.meetingStatus(widget.gameId);
      if (mounted) {
        setState(() {
          _locked = (s['locked_voters'] as List? ?? []).cast<String>().toSet();
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = errMsg(e));
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _activate() async {
    if (widget.busy || widget.target == null) return;
    if (widget.id == 'buktikan_tuduhan') {
      final name =
          widget.players
              .where((p) => p['user_id'] == widget.target)
              .firstOrNull?['name'] ??
          'pemain ini';
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Tuduh $name sebagai Terbisik?'),
          content: const SingleChildScrollView(
            child: Text(
              'Jika benar, target kehilangan 1 nyawa. Jika salah, kamu kehilangan 1 nyawa. Kartu barang tidak bisa menangkis; hukuman salah tuduh tidak dapat dialihkan.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Buktikan'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    await widget.onUse();
  }

  @override
  Widget build(BuildContext context) {
    final reading = widget.id == 'pembaca_niat';
    if (widget.phase != (reading ? 'voting' : 'discussion')) {
      return Text(
        reading
            ? 'Dipakai saat voting, setelah pemain lain mengunci suara.'
            : 'Dipakai saat musyawarah masih berlangsung.',
        textAlign: TextAlign.center,
      );
    }
    final list = widget.players
        .where(
          (p) =>
              p['user_id'] != widget.repo.myId &&
              (reading ? _locked.contains(p['user_id']) : !isOut(p)),
        )
        .toList();
    final label = switch (widget.id) {
      'buktikan_tuduhan' => 'Buktikan tuduhan',
      'sidang_terbuka' => 'Buka Sidang Terbuka',
      'penanggung_luka' => 'Tanggung satu luka',
      _ => 'Baca suara terkunci',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
        if (list.isEmpty)
          Text(
            reading
                ? 'Belum ada pemain lain yang mengunci suara.'
                : 'Tidak ada sasaran yang tersedia.',
            textAlign: TextAlign.center,
          ),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final p in list)
              ChoiceChip(
                label: Text('${p['name']}'),
                selected: widget.target == p['user_id'],
                onSelected: widget.busy
                    ? null
                    : (_) => widget.onTarget(p['user_id'] as String),
              ),
          ],
        ),
        const SizedBox(height: 12),
        EmbunButton(
          label: label,
          icon: 'centang',
          expand: true,
          onPressed:
              widget.busy || !list.any((p) => p['user_id'] == widget.target)
              ? null
              : _activate,
        ),
      ],
    );
  }
}

/// Public aggregate and public meeting events only; no secret choices here.
class MeetingPanel extends StatefulWidget {
  const MeetingPanel({
    super.key,
    required this.repo,
    required this.gameId,
    required this.day,
  });
  final GameRepository repo;
  final String gameId;
  final int day;
  @override
  State<MeetingPanel> createState() => _MeetingPanelState();
}

class _MeetingPanelState extends State<MeetingPanel> {
  Map<String, dynamic>? _state;
  String? _error;
  Timer? _timer;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _load());
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    try {
      final s = await widget.repo.meetingStatus(widget.gameId);
      if (mounted) {
        setState(() {
          _state = s;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = errMsg(e));
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return TextButton(
        onPressed: _load,
        child: const Text('Muat ulang kegiatan rapat'),
      );
    }
    final poll = _state?['poll'] as Map?;
    final events = (_state?['events'] as List?) ?? [];
    if (poll == null && events.isEmpty) return const SizedBox.shrink();
    final title = poll != null
        ? (poll['closed'] == true
              ? 'Hasil Sidang Terbuka'
              : 'Sidang Terbuka · ${poll['target']}')
        : 'Kegiatan musyawarah';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: const Color(0xFF15303C),
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: const Icon(Icons.forum_rounded, color: Color(0xFF8FCBFF)),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: events.isEmpty
              ? null
              : Text(
                  '${(events.last as Map)['text']}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => _MeetingDialog(
              repo: widget.repo,
              gameId: widget.gameId,
              initial: _state!,
            ),
          ),
        ),
      ),
    );
  }
}

class _MeetingDialog extends StatefulWidget {
  const _MeetingDialog({
    required this.repo,
    required this.gameId,
    required this.initial,
  });
  final GameRepository repo;
  final String gameId;
  final Map<String, dynamic> initial;
  @override
  State<_MeetingDialog> createState() => _MeetingDialogState();
}

class _MeetingDialogState extends State<_MeetingDialog> {
  late Map<String, dynamic> _state = widget.initial;
  bool _busy = false, _loading = false;
  String? _error;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _load());
  }

  Future<void> _load() async {
    if (_busy || _loading) return;
    _loading = true;
    try {
      final s = await widget.repo.meetingStatus(widget.gameId);
      if (mounted) setState(() => _state = s);
    } catch (e) {
      if (mounted) setState(() => _error = errMsg(e));
    } finally {
      _loading = false;
    }
  }

  Future<void> _vote(String choice) async {
    final poll = _state['poll'] as Map?;
    if (poll == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final s = await widget.repo.submitMeetingOpinion(
        widget.gameId,
        '${poll['id']}',
        choice,
      );
      if (mounted) setState(() => _state = s);
    } catch (e) {
      if (mounted) setState(() => _error = errMsg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final poll = _state['poll'] as Map?;
    final counts = poll?['counts'] as Map?;
    const labels = {
      'curiga': 'Curiga',
      'ragu': 'Belum yakin',
      'percaya': 'Percaya',
    };
    return AlertDialog(
      title: const Text('Kegiatan musyawarah'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (poll != null) ...[
                Text(
                  'Sidang Terbuka: ${poll['target']}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text('${poll['answered']}/${poll['total']} jawaban · anonim'),
                if (poll['closed'] == true) ...[
                  for (final e in labels.entries)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('${e.value}: ${counts?[e.key] ?? 0}'),
                    ),
                  const Text(
                    'Pendapat pemain, bukan bukti fraksi. Tidak menghasilkan hukuman.',
                  ),
                ] else ...[
                  const Text(
                    'Hanya jumlah akhir yang diumumkan. Jawaban tidak dapat diganti.',
                  ),
                  if (poll['my_choice'] != null)
                    Text('Jawabanmu: ${labels[poll['my_choice']]}'),
                  if (poll['can_answer'] == true && poll['my_choice'] == null)
                    for (final e in labels.entries)
                      TextButton(
                        onPressed: _busy ? null : () => _vote(e.key),
                        child: Text(e.value),
                      ),
                ],
                const Divider(),
              ],
              for (final e in (_state['events'] as List? ?? []))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('${(e as Map)['text']}'),
                ),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}

/// Only an explicit server right lets an eliminated player vote.
class HeritageVotingView extends StatefulWidget {
  const HeritageVotingView({
    super.key,
    required this.repo,
    required this.gameId,
    required this.day,
    required this.players,
    required this.readyCount,
    this.hasHammer = false,
    this.onHammerUsed,
  });
  final GameRepository repo;
  final String gameId;
  final int day, readyCount;
  final bool hasHammer;
  final VoidCallback? onHammerUsed;
  final List<Map<String, dynamic>> players;
  @override
  State<HeritageVotingView> createState() => _HeritageVotingViewState();
}

class _HeritageVotingViewState extends State<HeritageVotingView> {
  Map<String, dynamic>? _state;
  String? _error;
  Timer? _timer;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _load());
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    try {
      final s = await widget.repo.meetingStatus(widget.gameId);
      if (mounted) {
        setState(() {
          _state = s;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = errMsg(e));
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: TextButton(
          onPressed: _load,
          child: const Text('Muat ulang hak suara'),
        ),
      );
    }
    if (_state == null) return const Center(child: CircularProgressIndicator());
    if (_state!['can_vote'] != true) {
      return const Center(child: Text('Kamu hanya menonton pemungutan suara.'));
    }
    return Column(
      children: [
        if (_state!['heritage'] == true)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Warisan Suara · satu suara terakhir',
              style: TextStyle(color: Color(0xFF8FCBFF)),
            ),
          ),
        Expanded(
          child: VotingView(
            key: ValueKey('heritage-${widget.day}'),
            repo: widget.repo,
            gameId: widget.gameId,
            players: widget.players,
            day: widget.day,
            locked: _state!['voted'] == true,
            readyCount: (_state!['locked_voters'] as List? ?? []).length,
            hasHammer: widget.hasHammer,
            onHammerUsed: widget.onHammerUsed,
            total: (_state!['eligible_total'] as int?) ?? widget.players.length,
          ),
        ),
      ],
    );
  }
}
