import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'player_status.dart';

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

  /// Kunci global per avatar, supaya animasi pemberian tahu posisinya.
  final GlobalKey Function(String userId)? avatarKeyFor;

  const VillageStrip({
    super.key,
    required this.myId,
    required this.players,
    required this.emotes,
    required this.online,
    required this.day,
    required this.onTapPlayer,
    required this.onEmoteButton,
    this.avatarKeyFor,
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
    final out = isOut(p);
    final jailed = isJailed(p, widget.day);
    final b = _bubbles[id];
    final showB = b != null && now.difference(b.at).inSeconds < 6;
    final dot = ready
        ? Colors.greenAccent
        : online
        ? Colors.amberAccent
        : Colors.grey;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: (me || out) ? null : () => widget.onTapPlayer(p),
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
                      b.target == null
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
                Opacity(
                  opacity: out ? 0.35 : 1,
                  child: PlayerAvatar(
                    key: widget.avatarKeyFor?.call(id),
                    path: protagonistPath(p['character_card'] as String),
                    size: 38,
                    ring: out
                        ? Colors.white30
                        : jailed
                        ? EmbunColors.blood
                        : me
                        ? EmbunColors.gold
                        : EmbunColors.goldDim.withValues(alpha: 0.8),
                  ),
                ),
                if (out)
                  const Positioned.fill(
                    child: Center(
                      child: Icon(Icons.close_rounded,
                          size: 30, color: EmbunColors.blood),
                    ),
                  )
                else
                  Positioned(
                    right: -5,
                    bottom: -4,
                    child: ready
                        ? const DecoratedBox(
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF07130F)),
                      child: GameIcon('centang', size: 20),
                    )
                        : Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: dot,
                        shape: BoxShape.circle,
                        border:
                        Border.all(color: Colors.black, width: 1.5),
                      ),
                    ),
                  ),
                // Nyawa: dua hati di kiri bawah avatar.
                if (!out)
                  Positioned(
                    left: -4,
                    bottom: -5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xCC07130F),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 2, vertical: 1),
                        child: LivesRow(lives: livesLeft(p), size: 11),
                      ),
                    ),
                  ),
                if (jailed)
                  Positioned(
                    left: -7,
                    top: -7,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF07130F),
                        border: Border.all(color: EmbunColors.blood, width: 1.5),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(1),
                        child: GameIcon('lock', size: 22),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              p['name'] as String,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: out
                    ? Colors.white38
                    : jailed
                    ? EmbunColors.blood
                    : me
                    ? EmbunColors.gold
                    : Colors.white70,
              ),
            ),
            if (out)
              const StatusTag(text: 'Keluar', color: Colors.white54, fontSize: 9)
            else if (jailed)
              const StatusTag(
                  text: 'Dikurung', color: EmbunColors.blood, fontSize: 9),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return SizedBox(
      height: 92,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [for (final p in widget.players) _cell(p, now)],
            ),
          ),
          Tooltip(
            message: 'Isyarat',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onEmoteButton,
              child: Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0C1B17),
                  border: Border.all(
                      color: EmbunColors.gold.withValues(alpha: 0.7), width: 1.5),
                ),
                child: const Text('😀', style: TextStyle(fontSize: 20)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}