import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/profile_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'profile_avatar.dart';
import 'account_status_badge.dart';
import 'player_account_avatar.dart';
import 'profile_medals_view.dart';
import 'profile_stats_view.dart';
import 'medal_claim_scope.dart';

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
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      child: OrnatePanel(
        opacity: 0.97,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const GameIcon('character', size: 24),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Profil Pemain',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: EmbunColors.gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Tutup profil',
                  child: MedallionButton(
                    icon: 'silang',
                    size: 34,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    EmbunColors.gold.withValues(alpha: 0.7),
                    EmbunColors.gold.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
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
      if (!append) {
        final claims = MedalClaimScope.maybeOf(context);
        if (claims?.owns(value) == true) {
          // The profile request is complete; receipt failures have their own UI.
          setState(() => _loading = false);
          await claims!.refresh(details: value);
        }
      }
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
          ProfileStatsBoard(details: details, history: _history),
          const SizedBox(height: 12),
          const Text(
            'Hanya pertandingan selesai yang tercatat yang dihitung. Permainan yang dibubarkan tidak masuk statistik.',
            style: TextStyle(fontSize: 12, color: Colors.white60),
          ),
          ProfileMedalsSummary(profile: details),
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

  /// Judul bagian: belah ketupat emas, teks, garis yang memudar, jumlah.
  Widget _sectionLabel(String text, {String? trailing}) => Padding(
    padding: const EdgeInsets.only(top: 26, bottom: 12),
    child: Row(
      children: [
        Transform.rotate(
          angle: 0.7853981633974483,
          child: Container(width: 7, height: 7, color: EmbunColors.gold),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: EmbunColors.gold,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  EmbunColors.gold.withValues(alpha: 0.5),
                  EmbunColors.gold.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 10),
          Text(
            trailing,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white60,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _guestView(ProfileDetails d) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 10),
      Center(
        child: PlayerAccountAvatar(
          name: d.nickname,
          googleLinked: false,
          radius: 44,
        ),
      ),
      const SizedBox(height: 14),
      Text(
        d.nickname,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: EmbunColors.cream,
          shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
        ),
      ),
      const SizedBox(height: 8),
      Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white30),
          ),
          child: const Text(
            'Pemain Tamu',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Colors.white70,
            ),
          ),
        ),
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          border: const Border(
            left: BorderSide(color: Colors.white30, width: 2),
          ),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 20, color: Colors.white54),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Pemain ini bermain sebagai tamu, jadi statistik dan riwayat akun belum tersedia.',
                style: TextStyle(color: Colors.white70, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _visitorView(ProfileDetails d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileStatsHero(
          details: d,
          avatar: AccountAvatarBadge(
            linked: true,
            size: 22,
            child: ProfileAvatar(avatarId: d.avatarId, radius: 40),
          ),
        ),
        _sectionLabel('Statistik'),
        ProfileStatsBoard(details: d, history: _history),
        const SizedBox(height: 10),
        const Text(
          'Hanya pertandingan yang selesai dan tercatat yang dihitung.',
          style: TextStyle(fontSize: 11, color: Colors.white38),
        ),
        _sectionLabel('Medali'),
        ProfileMedalsSummary(profile: d, framed: false),
        _sectionLabel(
          'Riwayat Permainan',
          trailing: _history.isEmpty
              ? null
              : '${_history.length}${_more ? '+' : ''} terakhir',
        ),
        if (_history.isEmpty && !_loading)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white12),
            ),
            child: const Row(
              children: [
                Icon(Icons.history, size: 20, color: Colors.white38),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Belum ada pertandingan selesai yang tercatat.',
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
              ],
            ),
          ),
        for (final match in _history) _visitorMatch(match),
        if (_more && !_loading && _error == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Center(
              child: OutlinedButton(
                onPressed: () => _load(append: true),
                child: const Text('Muat riwayat berikutnya'),
              ),
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

  /// Satu baris riwayat: garis hasil di kiri, ikon hasil, teks, ikon peran.
  Widget _visitorMatch(ProfileMatch m) {
    final d = m.finishedAt;
    String two(int n) => n.toString().padLeft(2, '0');
    final terbisik = m.side == 'antagonis';
    final accent = terbisik ? EmbunColors.mist : EmbunColors.leaf;
    final role = terbisik ? 'Si Terbisik' : 'Warga Desa';
    final edge = m.won ? EmbunColors.gold : EmbunColors.blood;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            border: Border(
              left: BorderSide(
                color: edge.withValues(alpha: m.won ? 0.95 : 0.55),
                width: 3,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                GameIcon(m.won ? 'centang' : 'silang', size: 28),
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
                          fontWeight: FontWeight.w800,
                          color: m.won ? EmbunColors.gold : EmbunColors.cream,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${two(d.day)}/${two(d.month)}/${d.year} '
                            '${two(d.hour)}:${two(d.minute)} · hari ke-${m.days}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  terbisik ? Icons.nights_stay_outlined : Icons.shield_outlined,
                  size: 22,
                  color: accent.withValues(alpha: 0.85),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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