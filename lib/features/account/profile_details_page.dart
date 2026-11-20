import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/profile_repository.dart';
import '../common/ornate.dart';
import 'profile_avatar.dart';

/// Deliberately only wired from the waiting room and final result screen.
Future<void> showPlayerProfile(
  BuildContext context, {
  required String gameId,
  required String userId,
  ProfileRepository? repository,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: const Color(0xFF11271E),
  builder: (context) => FractionallySizedBox(
    heightFactor: .9,
    child: Column(
      children: [
        ListTile(
          title: const Text('Profil pemain'),
          trailing: IconButton(
            tooltip: 'Tutup profil',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: ProfileDetailsPanel(
                  userId: userId,
                  gameId: gameId,
                  repository:
                      repository ??
                      SupabaseProfileRepository(Supabase.instance.client),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  ),
);

class ProfileDetailsPanel extends StatefulWidget {
  const ProfileDetailsPanel({
    super.key,
    required this.repository,
    required this.userId,
    this.gameId,
    this.owner = false,
  });
  final ProfileRepository repository;
  final String userId;
  final String? gameId;
  final bool owner;
  @override
  State<ProfileDetailsPanel> createState() => _ProfileDetailsPanelState();
}

class _ProfileDetailsPanelState extends State<ProfileDetailsPanel> {
  ProfileDetails? _details;
  final _history = <ProfileMatch>[];
  String _title = '';
  bool _loading = true, _more = false, _acting = false;
  String? _error, _actionError, _notice;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool append = false}) async {
    final revision = ++_revision;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = await widget.repository.load(
        userId: widget.userId,
        gameId: widget.gameId,
        offset: append ? _history.length : 0,
      );
      if (!mounted || revision != _revision) return;
      setState(() {
        _details = value;
        if (!append) {
          _history.clear();
          _title = value.title;
        }
        _history.addAll(value.history);
        _more = value.hasMore;
      });
    } catch (_) {
      if (!mounted || revision != _revision) return;
      setState(
        () => _error = widget.owner
            ? 'Data profil belum dapat dimuat. Periksa koneksi lalu coba lagi.'
            : 'Profil belum dapat dimuat. Coba lagi di lobi atau hasil akhir ruangan yang sama.',
      );
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  Future<void> _act(Future<void> Function() action, String notice) async {
    if (_acting) return;
    setState(() {
      _acting = true;
      _actionError = null;
      _notice = null;
    });
    try {
      await action();
      if (!mounted) return;
      setState(() => _notice = notice);
      await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _actionError =
              'Belum berhasil disimpan. Periksa koneksi lalu coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _requestDeletion() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Minta penghapusan akun dan data?'),
        content: const Text(
          'Permintaan akan dicatat untuk ditinjau pengelola Embun. Akun belum langsung dihapus. Setelah diproses, profil, statistik dan riwayat pribadi tidak dapat dipulihkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ajukan permintaan'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _act(
        widget.repository.requestDeletion,
        'Permintaan penghapusan tercatat. Menunggu peninjauan pengelola.',
      );
    }
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: EmbunColors.gold,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final details = _details;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (details != null) ...[
          if (!widget.owner) ...[
            Center(
              child: ProfileAvatar(avatarId: details.avatarId, radius: 48),
            ),
            const SizedBox(height: 12),
            Text(
              details.nickname,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            if (details.title.isNotEmpty)
              Text(
                details.title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: EmbunColors.gold),
              ),
            const Text(
              'Informasi profil · hanya baca',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
          ],
          _heading('Statistik pertandingan'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _stat('Selesai', details.completed),
              _stat('Menang · Warga Desa', details.wargaWins),
              _stat('Menang · Si Terbisik', details.terbisikWins),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Hanya pertandingan selesai yang tercatat yang dihitung. Permainan yang dibubarkan tidak masuk statistik.',
            style: TextStyle(fontSize: 12, color: Colors.white60),
          ),
          if (widget.owner) ...[
            _heading('Gelar yang dipasang'),
            DropdownButtonFormField<String>(
              key: ValueKey('title-${details.title}'),
              initialValue: profileTitles.contains(_title) ? _title : '',
              isExpanded: true,
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text(
                    'Tanpa gelar',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                for (final title in profileTitles)
                  DropdownMenuItem(
                    value: title,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _acting || _loading
                  ? null
                  : (v) => setState(() => _title = v ?? ''),
            ),
            const SizedBox(height: 8),
            const Text(
              'Semua gelar di daftar ini bisa dipilih. Gelar profil adalah label tampilan.',
              style: TextStyle(fontSize: 12, color: Colors.white60),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _acting || _loading || _title == details.title
                    ? null
                    : () => _act(
                        () => widget.repository.equipTitle(_title),
                        'Gelar berhasil dipasang.',
                      ),
                icon: const Icon(Icons.workspace_premium_outlined),
                label: const Text('Pasang gelar'),
              ),
            ),
          ],
          _heading('Riwayat permainan'),
          if (_history.isEmpty)
            const Text('Belum ada pertandingan selesai yang tercatat.'),
          for (final match in _history) _match(match),
          if (_more && !_loading && _error == null)
            TextButton(
              onPressed: () => _load(append: true),
              child: const Text('Muat riwayat berikutnya'),
            ),
          if (widget.owner) ...[
            _heading('Penghapusan akun / data'),
            if (details.deletionRequest case final request?) ...[
              Text(
                request['status'] == 'pending'
                    ? 'Permintaan tercatat · menunggu peninjauan pengelola.'
                    : 'Status permintaan: ${request['status']}',
              ),
              SelectableText(
                'Nomor permintaan: ${request['id']}',
                style: const TextStyle(fontSize: 12, color: Colors.white60),
              ),
            ] else
              OutlinedButton.icon(
                onPressed: _acting || _loading ? null : _requestDeletion,
                icon: const Icon(Icons.person_remove_outlined),
                label: const Text('Minta penghapusan akun / data'),
              ),
          ],
        ],
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_error != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              _error!,
              style: const TextStyle(color: Color(0xFFFFB5A8)),
            ),
          ),
          TextButton(
            onPressed: () => _load(append: details != null),
            child: const Text('Coba lagi'),
          ),
        ],
        if (_actionError != null)
          Text(_actionError!, style: const TextStyle(color: Color(0xFFFFB5A8))),
        if (_notice != null)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_notice!),
            ),
          ),
        if (_acting) const LinearProgressIndicator(),
      ],
    );
  }

  Widget _stat(String label, int count) => Container(
    constraints: const BoxConstraints(minWidth: 105),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$count',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    ),
  );

  Widget _match(ProfileMatch match) {
    final date = match.finishedAt;
    String two(int n) => n.toString().padLeft(2, '0');
    final role = match.side == 'antagonis' ? 'Si Terbisik' : 'Warga Desa';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            match.won ? Icons.emoji_events_outlined : Icons.history,
            color: match.won ? EmbunColors.gold : Colors.white54,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${match.won ? 'Menang' : 'Kalah'} · $role',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${two(date.day)}/${two(date.month)}/${date.year} '
                  '${two(date.hour)}:${two(date.minute)} · hari ke-${match.days}',
                  style: const TextStyle(fontSize: 12, color: Colors.white60),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
