import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/asset_catalog.dart';
import '../../data/profile_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'profile_avatar.dart';
import 'account_status_badge.dart';
import 'player_account_avatar.dart';
import 'profile_medals_view.dart';
import 'profile_stats_view.dart';
import 'profile_style.dart';
import 'medal_claim_scope.dart';

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

/// Sheet profil pemain lain, bergaya Panduan: lembar datar dengan garis emas
/// di tepi atas, kepala berikon dengan garis bawah, isi bergulir tanpa kotak.
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
  builder: (context) => ProfileSheetFrame(
    asset: sceneryPath('sheetprofile-latar'),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(border: Border(bottom: profileRule())),
            child: Row(
              children: [
                const GameIcon('character', size: 27),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: const Text(
                      'Profil Pemain',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: EmbunColors.cream,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup profil',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.pop(context),
                  icon: const GameIcon('silang', size: 22),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
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

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.white60),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final details = _details;
    if (details != null && !details.googleLinked) return _guestView(details);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (details != null) ..._content(details),
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
              onPressed: () => _load(append: details != null),
              child: const Text('Coba lagi'),
            ),
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

  List<Widget> _content(ProfileDetails d) {
    final owner = widget.owner;
    return [
      if (!owner)
        ProfileReveal(
          child: ProfileStatsHero(
            details: d,
            avatar: AccountAvatarBadge(
              linked: true,
              size: 22,
              child: ProfileAvatar(avatarId: d.avatarId, radius: 40),
            ),
          ),
        ),
      ProfileReveal(
        index: 1,
        child: ProfileSection(
          icon: 'info',
          title: owner ? 'Statistik pertandingan' : 'Statistik',
          children: [
            ProfileStatsBoard(details: d, history: _history),
            _note(
              'Hanya pertandingan selesai yang tercatat yang dihitung. Permainan yang dibubarkan tidak masuk statistik.',
            ),
          ],
        ),
      ),
      ProfileReveal(
        index: 2,
        child: owner
            ? ProfileMedalsSummary(profile: d)
            : ProfileSection(
          icon: 'helaidaun',
          title: 'Medali',
          children: [ProfileMedalsSummary(profile: d, framed: false)],
        ),
      ),
      if (owner)
        ProfileSection(
          icon: 'persona',
          title: 'Gelar yang dipasang',
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey('title-${d.title}'),
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
            _note(
              'Semua gelar di daftar ini bisa dipilih. Gelar profil adalah label tampilan.',
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: EmbunColors.gold,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: _acting || _loading || _title == d.title
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
        ),
      ProfileSection(
        icon: 'hari',
        title: 'Riwayat permainan',
        trailing: _history.isEmpty
            ? null
            : '${_history.length}${_more ? '+' : ''} terakhir',
        children: [
          if (_history.isEmpty && !_loading)
            ProfileRow(
              accent: Colors.white,
              visualSize: 30,
              visual: const Icon(Icons.history, size: 22, color: Colors.white38),
              title: 'Belum ada pertandingan selesai yang tercatat.',
              titleColor: Colors.white60,
            ),
          for (var i = 0; i < _history.length; i++)
            ProfileReveal(index: i < 6 ? i : 0, child: _match(_history[i])),
          if (_more && !_loading && _error == null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: EmbunColors.gold),
                onPressed: () => _load(append: true),
                child: const Text('Muat riwayat berikutnya'),
              ),
            ),
        ],
      ),
      if (owner)
        ProfileSection(
          icon: 'lock',
          title: 'Penghapusan akun / data',
          accent: EmbunColors.blood,
          children: [
            if (d.deletionRequest case final request?) ...[
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
        ),
    ];
  }

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
      const SizedBox(height: 4),
      const Text(
        'PEMAIN TAMU',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
          color: Colors.white60,
        ),
      ),
      const SizedBox(height: 20),
      const ProfileRow(
        accent: Colors.white,
        visualSize: 30,
        visual: Icon(Icons.info_outline, size: 22, color: Colors.white54),
        title: 'Statistik belum tersedia',
        text:
        'Pemain ini bermain sebagai tamu, jadi statistik dan riwayat akun belum tersedia.',
      ),
    ],
  );

  /// Satu baris riwayat: ikon hasil, teks, ikon peran, garis bawah menurut hasil.
  Widget _match(ProfileMatch m) {
    final d = m.finishedAt;
    String two(int n) => n.toString().padLeft(2, '0');
    final terbisik = m.side == 'antagonis';
    final accent = terbisik ? EmbunColors.mist : EmbunColors.leaf;
    final role = terbisik ? 'Si Terbisik' : 'Warga Desa';
    return ProfileRow(
      accent: m.won ? EmbunColors.gold : EmbunColors.blood,
      visualSize: 34,
      visual: GameIcon(m.won ? 'centang' : 'silang', size: 30),
      title: '${m.won ? 'Menang' : 'Kalah'} · $role',
      titleColor: m.won ? EmbunColors.gold : EmbunColors.cream,
      text:
      '${two(d.day)}/${two(d.month)}/${d.year} '
          '${two(d.hour)}:${two(d.minute)} · hari ke-${m.days}',
      trailing: Icon(
        terbisik ? Icons.nights_stay_outlined : Icons.shield_outlined,
        size: 22,
        color: accent.withValues(alpha: 0.85),
      ),
    );
  }
}