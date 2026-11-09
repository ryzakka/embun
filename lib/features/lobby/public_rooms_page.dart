import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../../data/game_rules.dart';
import '../../data/lobby_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'room_entry_view.dart';

/// Mengembalikan null bila berhasil, atau pesan galat yang siap ditampilkan.
typedef JoinRoom = Future<String?> Function(String code);

enum _Sort { newest, busiest }

class _Room {
  final String code, host;
  final int players, ageS;

  const _Room(this.code, this.host, this.players, this.ageS);

  factory _Room.from(Map<String, dynamic> row) => _Room(
    row['code'] as String,
    row['host_name'] as String,
    (row['players'] as num).toInt(),
    (row['age_s'] as num).toInt(),
  );
}

/// Satu nama dipakai untuk masuk lewat kode atau dari daftar ruangan publik.
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

class _PublicRoomsPageState extends State<PublicRoomsPage> {
  static const _pollEvery = Duration(seconds: 8);

  final _nameFocus = FocusNode();
  final _searchCtrl = TextEditingController();

  List<_Room>? _rooms;
  DateTime _fetchedAt = DateTime.now();
  Object? _loadError;
  bool _refreshing = false;
  String? _joiningCode;
  bool _nameMissing = false;
  bool _codeMissing = false;
  _Sort _sort = _Sort.newest;
  Timer? _timer;
  late int _tab = widget.initialTab.clamp(0, 1).toInt();

  bool get _isPublic => _tab == 1;
  bool get _joining => _joiningCode != null;
  String get _query => _searchCtrl.text;

  @override
  void initState() {
    super.initState();
    if (_isPublic) _load();
    // Realtime games hanya terlihat oleh anggota ruangan.
    _timer = Timer.periodic(_pollEvery, (_) {
      if (_isPublic && !_joining) _load(quiet: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _nameFocus.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _selectTab(int tab) {
    if (_joining || tab == _tab) return;
    FocusScope.of(context).unfocus();
    setState(() => _tab = tab);
    if (_isPublic) _load(quiet: _rooms != null);
  }

  Future<void> _load({bool quiet = false}) async {
    if (_refreshing || _joining) return;
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
      if (!quiet || _rooms == null) setState(() => _loadError = e);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _join(String code, {bool fromList = false}) async {
    if (_joining) return;
    if (widget.nameCtrl.text.trim().isEmpty) {
      setState(() => _nameMissing = true);
      _nameFocus.requestFocus();
      if (_nameFocus.context case final field?) {
        unawaited(
          Scrollable.ensureVisible(
            field,
            duration: const Duration(milliseconds: 200),
          ),
        );
      }
      return;
    }
    if (code.isEmpty) {
      setState(() => _codeMissing = true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _joiningCode = code;
      _nameMissing = false;
      _codeMissing = false;
    });
    String? error;
    try {
      error = await widget.onJoin(code);
    } catch (e) {
      error = errMsg(e);
    }
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _joiningCode = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    if (fromList) _load(quiet: true);
  }

  List<_Room> _visible(List<_Room> rooms) {
    final q = _query.trim().toLowerCase();
    final list = [
      for (final r in rooms)
        if (q.isEmpty ||
            r.code.toLowerCase().contains(q) ||
            r.host.toLowerCase().contains(q))
          r,
    ];
    list.sort((a, b) {
      if (_sort == _Sort.busiest) {
        final count = b.players.compareTo(a.players);
        if (count != 0) return count;
      }
      return a.ageS.compareTo(b.ageS);
    });
    return list;
  }

  String _ageText(int seconds) {
    if (seconds < 45) return 'Baru saja';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '${minutes.clamp(1, 59)} mnt lalu';
    return '${seconds ~/ 3600} jam lalu';
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_joining,
    child: Scaffold(
      backgroundColor: EmbunColors.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Backdrop(path: sceneryPath('rumahdesa-hijau'), dim: 0.40),
          RoomEntryFrame(
            child: LayoutBuilder(
              builder: (context, box) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Visibility(
                    visible: box.maxHeight >= 160,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(bottom: roomEntryRule()),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RoomEntryHeader(
                            title: 'Gabung Ruangan',
                            icon: 'jointoroom',
                            onBack: _joining
                                ? null
                                : () => Navigator.of(context).pop(),
                            action: _isPublic
                                ? IconButton(
                                    tooltip: 'Muat ulang',
                                    color: EmbunColors.gold,
                                    icon: Opacity(
                                      opacity: _refreshing || _joining ? 0.45 : 1,
                                      child: const GameIcon('refresh', size: 25),
                                    ),
                                    onPressed: _refreshing || _joining
                                        ? null
                                        : _load,
                                  )
                                : null,
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 388),
                            child: Row(
                              children: [
                                Expanded(child: _tabButton('Pakai Kode', 0)),
                                Expanded(
                                  child: _tabButton('Ruangan Publik', 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(child: _isPublic ? _publicTab() : _codeTab()),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _tabButton(String label, int index) {
    final selected = _tab == index;
    return Semantics(
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: selected
              ? const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: EmbunColors.gold, width: 2),
                  ),
                )
              : null,
          child: InkWell(
            onTap: _joining ? null : () => _selectTab(index),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 43),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: selected ? EmbunColors.gold : EmbunColors.cream,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _nameField() => TextField(
    controller: widget.nameCtrl,
    focusNode: _nameFocus,
    enabled: !_joining,
    maxLength: 20,
    textCapitalization: TextCapitalization.words,
    textInputAction: _isPublic ? TextInputAction.done : TextInputAction.next,
    onChanged: (_) {
      if (_nameMissing) setState(() => _nameMissing = false);
    },
    decoration: InputDecoration(
      labelText: 'Namamu',
      counterText: '',
      errorText: _nameMissing ? 'Isi namamu dulu' : null,
      prefixIcon: const Padding(
        padding: EdgeInsets.all(8),
        child: GameIcon('identity', size: 24),
      ),
    ),
  );

  Widget _codeTab() => SingleChildScrollView(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _nameField(),
            const SizedBox(height: 14),
            TextField(
              controller: widget.codeCtrl,
              enabled: !_joining,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              maxLength: 8,
              onChanged: (_) {
                if (_codeMissing) setState(() => _codeMissing = false);
              },
              onSubmitted: (_) => _join(widget.codeCtrl.text.trim()),
              decoration: InputDecoration(
                labelText: 'Kode ruangan',
                counterText: '',
                errorText: _codeMissing ? 'Isi kode ruangan dulu' : null,
                prefixIcon: const Padding(
                  padding: EdgeInsets.all(8),
                  child: GameIcon('roomcode', size: 24),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Masukkan kode 5 huruf yang dibagikan host.',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 16),
            EmbunButton(
              label: _joining ? 'Sedang masuk…' : 'Gabung',
              icon: _joining ? 'wait' : 'joinroom',
              expand: true,
              height: 45,
              onPressed: _joining
                  ? null
                  : () => _join(widget.codeCtrl.text.trim()),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _publicTab() => LayoutBuilder(
    builder: (context, box) {
      final roomy = box.maxWidth >= 760;
      final wide =
          roomy ||
          (box.maxWidth >= 520 && MediaQuery.sizeOf(context).height < 450);
      final list = _roomList(showName: !wide);
      if (!wide) return list;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: roomy ? 268 : 184,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, 20, 23, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _nameField(),
                  const SizedBox(height: 8),
                  const Text(
                    'Nama ini akan terlihat oleh pemain lain.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border(left: roomEntryRule())),
              child: Padding(
                padding: const EdgeInsets.only(left: 22),
                child: list,
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _roomList({required bool showName}) {
    final rooms = _rooms;
    final visible = rooms == null ? const <_Room>[] : _visible(rooms);
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        key: const PageStorageKey('public-rooms'),
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showName) ...[_nameField(), const SizedBox(height: 14)],
                  if (rooms != null && _loadError != null) ...[
                    const Text(
                      'Gagal memuat ulang. Daftar terakhir masih ditampilkan.',
                      style: TextStyle(color: EmbunColors.blood, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (rooms != null && rooms.isNotEmpty) ...[
                    _search(),
                    const SizedBox(height: 10),
                    _listHeader(rooms.length, visible.length),
                  ],
                ],
              ),
            ),
          ),
          if (rooms == null)
            SliverToBoxAdapter(
              child: _loadError == null || _refreshing ? _loading() : _failed(),
            )
          else if (rooms.isEmpty)
            SliverToBoxAdapter(child: _empty())
          else if (visible.isEmpty)
            SliverToBoxAdapter(child: _noMatch())
          else
            SliverList.builder(
              itemCount: visible.length,
              itemBuilder: (context, index) => _roomRow(visible[index]),
            ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
        ],
      ),
    );
  }

  Widget _search() => Row(
    children: [
      Expanded(
        child: TextField(
          controller: _searchCtrl,
          enabled: !_joining,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Cari kode/host',
            isDense: true,
            prefixIcon: const Icon(Icons.search_rounded, size: 19),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Hapus pencarian',
                    icon: const GameIcon('x', size: 18),
                    onPressed: _joining ? null : _clearSearch,
                  ),
          ),
        ),
      ),
      const SizedBox(width: 5),
      PopupMenuButton<_Sort>(
        tooltip: 'Urutkan',
        icon: const Icon(Icons.sort_rounded, color: EmbunColors.gold),
        enabled: !_joining,
        initialValue: _sort,
        onSelected: (sort) => setState(() => _sort = sort),
        itemBuilder: (_) => const [
          PopupMenuItem(value: _Sort.newest, child: Text('Terbaru')),
          PopupMenuItem(value: _Sort.busiest, child: Text('Paling ramai')),
        ],
      ),
    ],
  );

  Widget _listHeader(int total, int shown) => DecoratedBox(
    decoration: BoxDecoration(border: Border(bottom: roomEntryRule())),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Menunggu pemain',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: EmbunColors.cream,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              shown == total ? '$total ruangan' : '$shown dari $total ruangan',
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _roomRow(_Room room) {
    final joining = _joiningCode == room.code;
    final age = room.ageS + DateTime.now().difference(_fetchedAt).inSeconds;
    final nearlyFull = room.players >= kMaxPlayers - 1;
    final accent = nearlyFull ? EmbunColors.gold : EmbunColors.leaf;
    final ratio = (room.players / kMaxPlayers).clamp(0.0, 1.0).toDouble();
    return DecoratedBox(
      key: ValueKey(room.code),
      decoration: BoxDecoration(border: Border(bottom: roomEntryRule())),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            if (MediaQuery.sizeOf(context).width >= 800) ...[
              const GameIcon('host', size: 33),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.host,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    semanticsLabel: 'Ruangan ${room.host}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: EmbunColors.cream,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    children: [
                      Text(
                        'Kode ${room.code}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        _ageText(age),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 7,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 38,
                        child: LinearProgressIndicator(
                          value: ratio,
                          color: accent,
                          backgroundColor: Colors.white12,
                          minHeight: 3,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      Text(
                        '${room.players}/$kMaxPlayers pemain',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                      if (nearlyFull)
                        const Text(
                          'Hampir penuh',
                          style: TextStyle(
                            fontSize: 11,
                            color: EmbunColors.gold,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: EmbunButton(
                label: joining ? 'Masuk…' : 'Gabung',
                height: 43,
                onPressed: _joining
                    ? null
                    : () => _join(room.code, fromList: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loading() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        SizedBox.square(
          dimension: 17,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 10),
        Flexible(child: Text('Memuat ruangan publik…')),
      ],
    ),
  );

  Widget _stateMessage({
    required String icon,
    required String title,
    required String message,
    required Widget action,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GameIcon(icon, size: 34),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: EmbunColors.cream,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            action,
          ],
        ),
      ),
    ),
  );

  Widget _empty() => _stateMessage(
    icon: 'persona',
    title: 'Belum ada ruangan publik',
    message: 'Buat ruangan agar pemain lain bisa bergabung dari sini.',
    action: TextButton.icon(
      icon: const GameIcon('roomcreate', size: 22),
      label: const Text('Buat ruangan publik'),
      onPressed: () {
        Navigator.of(context).pop();
        widget.onCreate();
      },
    ),
  );

  Widget _noMatch() => _stateMessage(
    icon: 'roomcode',
    title: 'Tidak ada yang cocok',
    message: 'Coba kode atau nama host yang lain.',
    action: TextButton(
      onPressed: _clearSearch,
      child: const Text('Bersihkan pencarian'),
    ),
  );

  Widget _failed() => _stateMessage(
    icon: 'alert',
    title: 'Daftar tidak bisa dimuat',
    message: errMsg(_loadError!),
    action: TextButton.icon(
      onPressed: _load,
      icon: const GameIcon('refresh', size: 20),
      label: const Text('Coba lagi'),
    ),
  );

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {});
  }
}
