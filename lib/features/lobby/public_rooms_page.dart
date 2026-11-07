import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../../data/lobby_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import '../table/player_status.dart';

/// Bergabung ke ruangan [code]. Mengembalikan null bila berhasil, atau pesan
/// galat yang siap ditampilkan.
typedef JoinRoom = Future<String?> Function(String code);

enum _Sort { newest, busiest }

class _Room {
  final String code;
  final String host;
  final int players;

  /// Umur ruangan (detik) pada saat daftar diambil, dihitung oleh server.
  final int ageS;
  const _Room(this.code, this.host, this.players, this.ageS);

  factory _Room.from(Map<String, dynamic> m) => _Room(
    m['code'] as String,
    m['host_name'] as String,
    (m['players'] as num).toInt(),
    (m['age_s'] as num).toInt(),
  );
}

/// Gabung Ruangan, layar penuh, dengan dua tab: "Pakai Kode" (kode dari
/// teman) dan "Ruangan Publik" (daftar yang bisa langsung dimasuki).
///
/// Namamu diisi di bagian atas (memakai [nameCtrl] milik lobi) dan dipakai
/// kedua tab. [onJoin] yang menjalankan permintaan gabung. Bila berhasil,
/// halaman menutup sendiri dan lobi menampilkan ruangannya. [onCreate]
/// dipanggil setelah halaman ditutup (tombol "Buat ruangan publik" saat
/// daftar kosong). [initialTab]: 0 = Pakai Kode, 1 = Ruangan Publik.
class PublicRoomsPage extends StatefulWidget {
  final LobbyRepository repo;
  final TextEditingController nameCtrl;
  final TextEditingController codeCtrl;
  final JoinRoom onJoin;
  final VoidCallback onCreate;
  final int initialTab;

  const PublicRoomsPage({
    super.key,
    required this.repo,
    required this.nameCtrl,
    required this.codeCtrl,
    required this.onJoin,
    required this.onCreate,
    this.initialTab = 0,
  });

  @override
  State<PublicRoomsPage> createState() => _PublicRoomsPageState();
}

class _PublicRoomsPageState extends State<PublicRoomsPage>
    with SingleTickerProviderStateMixin {
  static const _maxPlayers = 8;
  static const _pollEvery = Duration(seconds: 8);

  final _scroll = ScrollController();
  final _nameFocus = FocusNode();
  final _searchCtrl = TextEditingController();
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat(reverse: true);

  List<_Room>? _rooms;
  DateTime _fetchedAt = DateTime.now();
  Object? _loadError;
  bool _refreshing = false;
  String? _joiningCode;
  bool _nameMissing = false;
  _Sort _sort = _Sort.newest;
  String _query = '';
  Timer? _timer;
  late int _tab = widget.initialTab.clamp(0, 1).toInt();

  @override
  void initState() {
    super.initState();
    _load();
    // RLS membatasi realtime `games` ke anggota, jadi daftar disegarkan berkala.
    _timer = Timer.periodic(_pollEvery, (_) {
      if (_joiningCode == null) _load(quiet: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    _scroll.dispose();
    _nameFocus.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _load({bool quiet = false}) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final raw = await widget.repo.publicGames();
      if (!mounted) return;
      setState(() {
        _rooms = [for (final m in raw) _Room.from(m)];
        _fetchedAt = DateTime.now();
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      // Penyegaran diam-diam yang gagal tidak mengganggu daftar yang ada.
      if (!quiet || _rooms == null) setState(() => _loadError = e);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  /// true bila nama masih kosong (kolom nama disorot dan diberi fokus).
  bool _needName() {
    if (widget.nameCtrl.text.trim().isNotEmpty) return false;
    setState(() => _nameMissing = true);
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    _nameFocus.requestFocus();
    return true;
  }

  /// Tab "Pakai Kode": gabung dengan kode yang diketik.
  Future<void> _joinByCode() async {
    if (_joiningCode != null) return;
    if (_needName()) return;
    final code = widget.codeCtrl.text.trim();
    if (code.isEmpty) return _toast('Isi kode ruangan dulu');
    setState(() {
      _joiningCode = code;
      _nameMissing = false;
    });
    final err = await widget.onJoin(code);
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _joiningCode = null);
    _toast(err);
  }

  Future<void> _join(_Room r) async {
    if (_joiningCode != null) return;
    if (_needName()) return;
    setState(() {
      _joiningCode = r.code;
      _nameMissing = false;
    });
    final err = await widget.onJoin(r.code);
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _joiningCode = null);
    _toast(err);
    _load(quiet: true); // ruangan mungkin sudah penuh atau sudah dimulai
  }

  List<_Room> _visible() {
    final q = _query.trim().toLowerCase();
    final list = [
      for (final r in _rooms ?? const <_Room>[])
        if (q.isEmpty ||
            r.code.toLowerCase().contains(q) ||
            r.host.toLowerCase().contains(q))
          r,
    ];
    list.sort((a, b) {
      if (_sort == _Sort.busiest) {
        final c = b.players.compareTo(a.players);
        if (c != 0) return c;
      }
      return a.ageS.compareTo(b.ageS);
    });
    return list;
  }

  String _ageText(int s) {
    if (s < 45) return 'baru saja';
    final m = (s / 60).round();
    if (m < 60) return '$m mnt lalu';
    return '${s ~/ 3600} jam lalu';
  }

  // ============================ kerangka ============================

  @override
  Widget build(BuildContext context) {
    final rooms = _rooms;
    return PopScope(
      canPop: _joiningCode == null,
      child: Scaffold(
        backgroundColor: const Color(0xFF050A08),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Backdrop(path: sceneryPath('rumahdesa-hijau'), dim: 0.62),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 940),
                  child: Column(
                    children: [
                      _topBar(rooms?.length),
                      _sharedTop(),
                      Expanded(
                          child: _tab == 0 ? _codeTab() : _content(rooms)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(int? count) {
    final sub = _tab == 0
        ? 'Masukkan kode dari temanmu'
        : count == null
        ? 'Memuat daftar...'
        : count == 0
        ? 'Belum ada ruangan yang dibuka'
        : '$count ruangan menunggu pemain';
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Kembali',
            onPressed:
            _joiningCode != null ? null : () => Navigator.pop(context),
            color: EmbunColors.gold,
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
          const GameIcon('jointoroom', size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gabung Ruangan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: EmbunColors.gold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                  ),
                ),
                Text(sub,
                    style:
                    const TextStyle(fontSize: 12, color: Colors.white60)),
              ],
            ),
          ),
          SizedBox(
            width: 48,
            height: 48,
            child: _tab == 0
                ? null
                : _refreshing
                ? const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
                : IconButton(
              tooltip: 'Muat ulang',
              color: EmbunColors.gold,
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _load,
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(List<_Room>? rooms) {
    if (rooms == null) {
      return _loadError == null ? _skeleton() : _failed();
    }
    final visible = _visible();
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                children: [
                  if (_loadError != null)
                    NoticeStrip(
                      icon: 'alert',
                      text: 'Gagal memuat ulang: ${errMsg(_loadError!)}',
                      accent: EmbunColors.blood,
                    ),
                  if (rooms.length > 4) _controls(rooms.length, visible.length),
                ],
              ),
            ),
          ),
          if (rooms.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _empty())
          else if (visible.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _noMatch())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 460,
                  mainAxisExtent: 100,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 14,
                ),
                itemCount: visible.length,
                itemBuilder: (_, i) => _card(visible[i]),
              ),
            ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Text(
                'Daftar disegarkan otomatis. Tarik ke bawah untuk memuat ulang.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================ bagian atas daftar ============================

  /// Bagian yang dipakai kedua tab: kolom nama dan pemilih tab.
  Widget _sharedTop() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
    child: Column(
      children: [
        _namePanel(),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _tabButton(
                  label: 'Pakai Kode', icon: 'roomcode', index: 0),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _tabButton(
                  label: 'Ruangan Publik', icon: 'persona', index: 1),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _tabButton(
      {required String label, required String icon, required int index}) {
    final on = _tab == index;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _joiningCode != null ? null : () => setState(() => _tab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: on
              ? EmbunColors.leaf.withValues(alpha: 0.22)
              : Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: on
                ? EmbunColors.gold
                : EmbunColors.goldDim.withValues(alpha: 0.4),
            width: on ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GameIcon(icon, size: 26),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: on ? FontWeight.bold : FontWeight.w500,
                  color: on ? EmbunColors.gold : EmbunColors.cream,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tab "Pakai Kode".
  Widget _codeTab() => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: OrnatePanel(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: widget.codeCtrl,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _joinByCode(),
                decoration: const InputDecoration(
                  labelText: 'Kode ruangan',
                  prefixIcon: Padding(
                    padding: EdgeInsets.all(6),
                    child: GameIcon('roomcode', size: 30),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              EmbunButton(
                label: _joiningCode != null ? 'Masuk...' : 'Gabung',
                icon: _joiningCode != null ? 'wait' : 'joinroom',
                expand: true,
                onPressed: _joiningCode != null ? null : _joinByCode,
              ),
              const SizedBox(height: 12),
              const Text(
                'Belum punya kode? Buka tab Ruangan Publik untuk melihat '
                    'ruangan yang sedang menunggu pemain.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _namePanel() => OrnatePanel(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
    child: TextField(
      controller: widget.nameCtrl,
      focusNode: _nameFocus,
      maxLength: 20,
      textInputAction: TextInputAction.done,
      onChanged: (_) {
        if (_nameMissing) setState(() => _nameMissing = false);
      },
      decoration: InputDecoration(
        labelText: 'Namamu',
        counterText: '',
        errorText: _nameMissing ? 'Isi namamu dulu untuk bergabung' : null,
        prefixIcon: const Padding(
          padding: EdgeInsets.all(6),
          child: GameIcon('identity', size: 30),
        ),
      ),
    ),
  );

  Widget _controls(int total, int shown) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      children: [
        TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'Cari kode atau nama host',
            isDense: true,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
              tooltip: 'Hapus pencarian',
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _searchCtrl.clear();
                setState(() => _query = '');
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ChoiceChip(
              label: const Text('Terbaru'),
              selected: _sort == _Sort.newest,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => setState(() => _sort = _Sort.newest),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Paling ramai'),
              selected: _sort == _Sort.busiest,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => setState(() => _sort = _Sort.busiest),
            ),
            const Spacer(),
            if (shown != total)
              Text('$shown dari $total',
                  style: const TextStyle(fontSize: 12, color: Colors.white54)),
          ],
        ),
      ],
    ),
  );

  // ============================ kartu ruangan ============================

  Widget _pips(int n) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < _maxPlayers; i++)
        Container(
          width: 9,
          height: 9,
          margin: EdgeInsets.only(left: i == 0 ? 0 : 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < n ? EmbunColors.leaf : Colors.transparent,
            border: Border.all(
              color: i < n ? EmbunColors.leaf : Colors.white30,
            ),
          ),
        ),
    ],
  );

  Widget _card(_Room r) {
    final joining = _joiningCode == r.code;
    final locked = _joiningCode != null && !joining;
    final age = r.ageS + DateTime.now().difference(_fetchedAt).inSeconds;
    final almostFull = r.players >= _maxPlayers - 1;
    final fresh = !almostFull && age < 120;

    final card = Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: almostFull
              ? EmbunColors.gold.withValues(alpha: 0.75)
              : EmbunColors.goldDim.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
              border: Border.all(
                  color: EmbunColors.goldDim.withValues(alpha: 0.5)),
            ),
            child: const GameIcon('host', size: 42),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ruangan ${r.host}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                    color: EmbunColors.gold,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    _pips(r.players),
                    const SizedBox(width: 8),
                    Text('${r.players}/$_maxPlayers',
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: EmbunColors.cream)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${r.code}  ·  ${_ageText(age)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11.5,
                      letterSpacing: 0.4,
                      color: Colors.white54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          EmbunButton(
            label: joining ? 'Masuk...' : 'Gabung',
            icon: joining ? 'wait' : 'joinroom',
            height: 46,
            onPressed: (joining || locked) ? null : () => _join(r),
          ),
        ],
      ),
    );

    return Semantics(
      label: 'Ruangan ${r.host}, ${r.players} dari $_maxPlayers pemain, '
          'kode ${r.code}',
      child: Opacity(
        opacity: locked ? 0.55 : 1,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: card),
            if (almostFull)
              const Positioned(
                top: -8,
                right: 16,
                child: StatusTag(
                    text: 'Hampir penuh', color: EmbunColors.gold),
              )
            else if (fresh)
              const Positioned(
                top: -8,
                right: 16,
                child: StatusTag(text: 'Baru', color: EmbunColors.leaf),
              ),
          ],
        ),
      ),
    );
  }

  // ============================ keadaan lain ============================

  Widget _skeleton() => AnimatedBuilder(
    animation: _pulse,
    builder: (_, _) => ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (_, _) => Opacity(
        opacity: 0.25 + 0.25 * _pulse.value,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: EmbunColors.goldDim.withValues(alpha: 0.4)),
          ),
        ),
      ),
    ),
  );

  Widget _stateMessage({
    required String icon,
    required String title,
    required String body,
    Widget? action,
  }) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(opacity: 0.55, child: GameIcon(icon, size: 72)),
                const SizedBox(height: 14),
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: EmbunColors.gold)),
                const SizedBox(height: 6),
                Text(body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12.5, height: 1.4, color: Colors.white60)),
                if (action != null) ...[
                  const SizedBox(height: 18),
                  action,
                ],
              ],
            ),
          ),
        ),
      );

  Widget _empty() => _stateMessage(
    icon: 'persona',
    title: 'Belum ada ruangan publik',
    body: 'Jadilah yang pertama. Buat ruangan publik dan pemain lain '
        'bisa bergabung dari daftar ini.',
    action: EmbunButton(
      label: 'Buat ruangan publik',
      icon: 'roomcreate',
      expand: true,
      onPressed: () {
        Navigator.pop(context);
        widget.onCreate();
      },
    ),
  );

  Widget _noMatch() => _stateMessage(
    icon: 'persona',
    title: 'Tidak ada yang cocok',
    body: 'Tidak ada ruangan dengan kode atau host "${_query.trim()}".',
    action: EmbunButton(
      label: 'Hapus pencarian',
      icon: 'silang',
      kind: EmbunButtonKind.secondary,
      height: 46,
      onPressed: () {
        _searchCtrl.clear();
        setState(() => _query = '');
      },
    ),
  );

  Widget _failed() => _stateMessage(
    icon: 'alert',
    title: 'Daftar tidak bisa dimuat',
    body: errMsg(_loadError!),
    action: EmbunButton(
      label: 'Coba lagi',
      kind: EmbunButtonKind.secondary,
      height: 46,
      onPressed: _refreshing ? null : () => _load(),
    ),
  );
}