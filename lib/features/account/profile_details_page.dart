import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/profile_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'profile_avatar.dart';
import 'account_status_badge.dart';
import 'player_account_avatar.dart';

/// Deliberately only wired from the waiting room and final result screen.
BorderSide _profileRule([Color color = EmbunColors.gold]) =>
    BorderSide(color: color.withValues(alpha: 0.30));

InputDecoration _flatField() => InputDecoration(
  filled: false,
  contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
  border: UnderlineInputBorder(
    borderSide: BorderSide(color: EmbunColors.gold.withValues(alpha: 0.4)),
  ),
  enabledBorder: UnderlineInputBorder(
    borderSide: BorderSide(color: EmbunColors.gold.withValues(alpha: 0.4)),
  ),
  focusedBorder: const UnderlineInputBorder(
    borderSide: BorderSide(color: EmbunColors.gold, width: 2),
  ),
);

/// Sheet profil pemain lain: kartu berbingkai emas yang melayang di atas
/// layar, dengan kepala bagian, lalu kartu pemain yang bisa digulir.
Future<void> showPlayerProfile(
    BuildContext context, {
      required String gameId,
      required String userId,
      ProfileRepository? repository,
    }) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  elevation: 0,
  backgroundColor: Colors.transparent,
  shape: const RoundedRectangleBorder(),
  constraints: const BoxConstraints(maxWidth: 580),
  builder: (context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: OrnatePanel(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              icon: 'character',
              title: 'Profil Pemain',
              trailing: MedallionButton(
                icon: 'silang',
                size: 34,
                onTap: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 20),
                child: ProfileDetailsPanel(
                  userId: userId,
                  gameId: gameId,
                  repository:
                  repository ??
                      SupabaseProfileRepository(Supabase.instance.client),
                ),
              ),
            ),
          ],
        ),
      ),
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
    padding: const EdgeInsets.only(top: 26, bottom: 10),
    child: DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: _profileRule())),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: SizedBox(
          width: double.infinity,
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: EmbunColors.gold,
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final details = _details;
    if (details != null && !details.googleLinked) return _guestView(details);
    if (!widget.owner && details != null) return _visitorView(details);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (details != null) ...[
          if (!widget.owner) ...[
            Center(
              child: AccountAvatarBadge(
                linked: true,
                child: ProfileAvatar(avatarId: details.avatarId, radius: 48),
              ),
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
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _stat('Selesai', details.completed, first: true),
                ),
                _vRule(),
                Expanded(
                  child: _stat('Menang · Warga Desa', details.wargaWins),
                ),
                _vRule(),
                Expanded(
                  child: _stat('Menang · Si Terbisik', details.terbisikWins),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
              decoration: _flatField(),
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
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
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
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: EmbunColors.blood,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: _acting || _loading ? null : _requestDeletion,
                  icon: const Icon(Icons.person_remove_outlined),
                  label: const Text('Minta penghapusan akun / data'),
                ),
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

  // ===== Tampilan kartu pemain (pemain lain, hanya baca) =====

  Widget _guestView(ProfileDetails d) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Center(
        child: PlayerAccountAvatar(
          name: d.nickname,
          googleLinked: false,
          radius: 44,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        d.nickname,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: EmbunColors.cream,
        ),
      ),
      const SizedBox(height: 10),
      const Text(
        'Pemain ini bermain sebagai tamu, jadi statistik dan riwayat akun belum tersedia.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white60),
      ),
    ],
  );

  Widget _visitorView(ProfileDetails d) {
    final wins = d.wargaWins + d.terbisikWins;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _hero(d),
        const SizedBox(height: 18),
        _winBar(d, wins),
        const SizedBox(height: 12),
        // IntrinsicHeight: di dalam area gulir tinggi tak terbatas, jadi
        // stretch tanpa ini melempar galat layout dan memutus isi di bawahnya.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _tile('Pertandingan', d.completed, EmbunColors.cream),
              ),
              _vRule(),
              Expanded(
                child: _tile('Menang Warga', d.wargaWins, EmbunColors.leaf),
              ),
              _vRule(),
              Expanded(
                child: _tile(
                  'Menang Terbisik',
                  d.terbisikWins,
                  EmbunColors.mist,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Hanya pertandingan yang selesai dan tercatat yang dihitung.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: Colors.white54),
        ),
        const SizedBox(height: 20),
        const SectionHeader(icon: 'mydeck', title: 'Riwayat Permainan'),
        const SizedBox(height: 10),
        if (_history.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'Belum ada pertandingan selesai yang tercatat.',
              style: TextStyle(color: Colors.white60),
            ),
          ),
        for (final match in _history) _visitorMatch(match),
        if (_more && !_loading && _error == null)
          Center(
            child: TextButton(
              onPressed: () => _load(append: true),
              child: const Text('Muat riwayat berikutnya'),
            ),
          ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_error != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFFB5A8)),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () => _load(append: true),
              child: const Text('Coba lagi'),
            ),
          ),
        ],
      ],
    );
  }

  /// Avatar berbingkai cahaya emas, nama, dan gelar sebagai pita.
  Widget _hero(ProfileDetails d) => Column(
    children: [
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: EmbunColors.gold.withValues(alpha: 0.85),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: EmbunColors.gold.withValues(alpha: 0.35),
              blurRadius: 24,
            ),
          ],
        ),
        child: AccountAvatarBadge(
          linked: true,
          size: 22,
          child: ProfileAvatar(avatarId: d.avatarId, radius: 46),
        ),
      ),
      const SizedBox(height: 14),
      Text(
        d.nickname,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: EmbunColors.cream,
          shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
        ),
      ),
      if (d.title.isNotEmpty) ...[
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.workspace_premium_outlined,
              size: 17,
              color: EmbunColors.gold,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                d.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: EmbunColors.gold,
                ),
              ),
            ),
          ],
        ),
      ],
    ],
  );

  /// Bilah tingkat kemenangan: hijau = menang Warga, ungu = menang Terbisik,
  /// sisanya (gelap) = kalah.
  Widget _winBar(ProfileDetails d, int wins) {
    final total = d.completed;
    final lost = (total - wins).clamp(0, total).toInt();
    final pct = total <= 0 ? null : (wins * 100 / total).round().clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'Tingkat kemenangan',
              style: TextStyle(fontSize: 12.5, color: Colors.white70),
            ),
            const Spacer(),
            Text(
              pct == null ? '-' : '$pct%',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: EmbunColors.gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 8,
            color: Colors.white.withValues(alpha: 0.10),
            child: total <= 0
                ? null
                : Row(
              children: [
                if (d.wargaWins > 0)
                  Expanded(
                    flex: d.wargaWins,
                    child: const ColoredBox(color: EmbunColors.leaf),
                  ),
                if (d.terbisikWins > 0)
                  Expanded(
                    flex: d.terbisikWins,
                    child: const ColoredBox(color: EmbunColors.mist),
                  ),
                if (lost > 0)
                  Expanded(flex: lost, child: const SizedBox.shrink()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tile(String label, int count, Color accent) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: accent,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11.5,
            height: 1.2,
            color: Colors.white70,
          ),
        ),
      ],
    ),
  );

  Widget _visitorMatch(ProfileMatch m) {
    final d = m.finishedAt;
    String two(int n) => n.toString().padLeft(2, '0');
    final terbisik = m.side == 'antagonis';
    final accent = terbisik ? EmbunColors.mist : EmbunColors.leaf;
    final role = terbisik ? 'Si Terbisik' : 'Warga Desa';
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: _profileRule())),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            GameIcon(m.won ? 'centang' : 'silang', size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${m.won ? 'Menang' : 'Kalah'} · $role',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: m.won ? accent : EmbunColors.cream,
                    ),
                  ),
                  Text(
                    '${two(d.day)}/${two(d.month)}/${d.year} '
                        '${two(d.hour)}:${two(d.minute)} · hari ke-${m.days}',
                    style: const TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vRule() =>
      Container(width: 1, color: EmbunColors.gold.withValues(alpha: 0.30));

  Widget _stat(String label, int count, {bool first = false}) => Padding(
    padding: EdgeInsets.fromLTRB(first ? 0 : 14, 4, 10, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: EmbunColors.cream,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            height: 1.25,
            color: Colors.white70,
          ),
        ),
      ],
    ),
  );

  Widget _match(ProfileMatch match) {
    final date = match.finishedAt;
    String two(int n) => n.toString().padLeft(2, '0');
    final role = match.side == 'antagonis' ? 'Si Terbisik' : 'Warga Desa';
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: _profileRule())),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            GameIcon(match.won ? 'centang' : 'silang', size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${match.won ? 'Menang' : 'Kalah'} · $role',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: match.won ? EmbunColors.gold : EmbunColors.cream,
                    ),
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
      ),
    );
  }
}