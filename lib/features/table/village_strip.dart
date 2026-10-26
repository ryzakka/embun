import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';

class _Bubble {
  final String emoji;
  final String? target;
  final DateTime at;
  _Bubble(this.emoji, this.target, this.at);
}

/// Deretan avatar pemain: titik status (siap / online / luring), gembok
/// kurungan, dan gelembung emote yang muncul sebentar di atas pengirimnya.
/// Ketuk avatar untuk aksi sosial; tombol 😀 untuk panel isyarat.
class VillageStrip extends StatefulWidget {
  final String myId;
  final List<Map<String, dynamic>> players;

  /// null = stream belum memberi data pertama.
  final List<Map<String, dynamic>>? emotes;
  final Set<String> online;
  final int day;
  final ValueChanged<Map<String, dynamic>> onTapPlayer;
  final VoidCallback onEmoteButton;

  const VillageStrip({
    super.key,
    required this.myId,
    required this.players,
    required this.emotes,
    required this.online,
    required this.day,
    required this.onTapPlayer,
    required this.onEmoteButton,
  });

  @override
  State<VillageStrip> createState() => _VillageStripState();
}

class _VillageStripState extends State<VillageStrip> {
  final Set<String> _known = {};
  final Map<String, _Bubble> _bubbles = {};
  bool _primed = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _scan();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant VillageStrip old) {
    super.didUpdateWidget(old);
    _scan();
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  /// Data pertama dianggap riwayat (tidak dimunculkan). Setelah itu, emote
  /// baru jadi gelembung. Memakai jam perangkat sendiri agar tahan selisih
  /// jam dengan server.
  void _scan() {
    final list = widget.emotes;
    if (list == null) return;
    for (final e in list) {
      final id = e['id'] as String;
      if (!_known.add(id)) continue;
      if (!_primed) continue;
      _bubbles[e['user_id'] as String] = _Bubble(
        e['emoji'] as String,
        e['target_id'] as String?,
        DateTime.now(),
      );
    }
    _primed = true;
  }

  String _short(String? id) {
    for (final p in widget.players) {
      if (p['user_id'] == id) {
        final n = p['name'] as String;
        return n.length <= 4 ? n : n.substring(0, 4);
      }
    }
    return '?';
  }

  Widget _cell(Map<String, dynamic> p, DateTime now) {
    final id = p['user_id'] as String;
    final me = id == widget.myId;
    final ready = p['ready'] == true;
    final online = widget.online.contains(id);
    final jailed = p['jailed_day'] == widget.day;
    final b = _bubbles[id];
    final showB = b != null && now.difference(b.at).inSeconds < 6;
    final dot = ready
        ? Colors.greenAccent
        : online
        ? Colors.amberAccent
        : Colors.grey;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: me ? null : () => widget.onTapPlayer(p),
      child: Container(
        width: 62,
        margin: const EdgeInsets.only(right: 6),
        child: Column(
          children: [
            SizedBox(
              height: 20,
              child: showB
                  ? Center(
                child: FittedBox(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      b!.target == null
                          ? b.emoji
                          : '${b.emoji}→${_short(b.target)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              )
                  : null,
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                PlayerAvatar(
                  path: protagonistPath(p['character_card'] as String),
                  size: 34,
                  ring: me ? Colors.amber : Colors.white38,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                  ),
                ),
                if (jailed)
                  const Positioned(
                    left: -4,
                    top: -4,
                    child: Icon(Icons.lock, size: 14, color: Colors.redAccent),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              p['name'] as String,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: me ? Colors.amberAccent : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return SizedBox(
      height: 72,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [for (final p in widget.players) _cell(p, now)],
            ),
          ),
          IconButton(
            tooltip: 'Isyarat',
            onPressed: widget.onEmoteButton,
            icon: const Text('😀', style: TextStyle(fontSize: 22)),
          ),
        ],
      ),
    );
  }
}