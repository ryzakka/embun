import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/errors.dart';
import '../../data/lobby_repository.dart';
import '../common/ornate.dart';

/// Daftar ruangan publik. Mengembalikan kode ruangan yang dipilih, atau null.
Future<String?> showPublicRooms(BuildContext context, LobbyRepository repo) =>
    showDialog<String>(
      context: context,
      builder: (_) => _PublicRoomsDialog(repo: repo),
    );

class _PublicRoomsDialog extends StatefulWidget {
  final LobbyRepository repo;
  const _PublicRoomsDialog({required this.repo});

  @override
  State<_PublicRoomsDialog> createState() => _PublicRoomsDialogState();
}

class _PublicRoomsDialogState extends State<_PublicRoomsDialog> {
  List<Map<String, dynamic>>? _rooms;
  Object? _error;
  bool _loading = true;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    // RLS membatasi realtime `games` ke anggota, jadi daftar disegarkan berkala.
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _loading = true);
    try {
      final r = await widget.repo.publicGames();
      if (!mounted) return;
      setState(() {
        _rooms = r;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Galat saat penyegaran diam-diam tidak menimpa daftar yang sudah ada.
        if (!quiet || _rooms == null) _error = e;
        _loading = false;
      });
    }
  }

  Widget _body() {
    if (_loading && _rooms == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _rooms == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(errMsg(_error!),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: EmbunColors.blood)),
      );
    }
    final rooms = _rooms ?? const <Map<String, dynamic>>[];
    if (rooms.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Belum ada ruangan publik. Buat ruanganmu sendiri dan nyalakan '
              '"Ruangan publik".',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, height: 1.4),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: rooms.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _RoomTile(
        room: rooms[i],
        onJoin: () => Navigator.pop(context, rooms[i]['code'] as String),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
        child: OrnatePanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                icon: 'persona',
                title: 'Ruangan Publik',
                trailing: IconButton(
                  tooltip: 'Muat ulang',
                  icon: const Icon(Icons.refresh_rounded,
                      color: EmbunColors.gold),
                  onPressed: _load,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(child: _body()),
              const SizedBox(height: 12),
              EmbunButton(
                label: 'Tutup',
                icon: 'silang',
                kind: EmbunButtonKind.secondary,
                expand: true,
                height: 46,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  final Map<String, dynamic> room;
  final VoidCallback onJoin;
  const _RoomTile({required this.room, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final n = room['players'] as int;
    return Material(
      color: Colors.black.withValues(alpha: 0.28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: EmbunColors.goldDim.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onJoin,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ruangan ${room['host_name']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: EmbunColors.gold)),
                    const SizedBox(height: 2),
                    Text('Kode ${room['code']}  ·  $n/8 pemain',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white60)),
                  ],
                ),
              ),
              const Icon(Icons.login_rounded, color: EmbunColors.gold),
            ],
          ),
        ),
      ),
    );
  }
}