import 'dart:async';
import 'dart:math' as math;
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
/// kurungan, dan isyarat (emote).
///
/// Isyarat baru tampil besar MENINDIH potret pengirimnya (muncul membal,
/// bergoyang pelan, lalu naik dan memudar), disertai cincin kejut. Di atas
/// potret ada label sasaran ("-> Nama", "Untukmu", atau "Semua"), dan potret
/// sasarannya berpendar dengan lencana emoji kecil di pojok. Seluruhnya
/// berumur [_lifeMs]. Ketuk avatar untuk aksi sosial; tombol 😀 untuk panel
/// isyarat.
class VillageStrip extends StatefulWidget {
  final String myId;
  final List<Map<String, dynamic>> players;

  /// null = stream belum memberi data pertama.
  final List<Map<String, dynamic>>? emotes;
  final Set<String> online;
  final int day;
  final ValueChanged<Map<String, dynamic>> onTapPlayer;
  final VoidCallback onEmoteButton;

  /// Pintasan daftar warga yang juga menampilkan isyarat terakhir di layar sempit.
  final Widget Function(String? emoji, String? sender)? collapsedBuilder;

  /// Ponsel: avatar lebih kecil dan tanpa label status, supaya hemat tinggi.
  final bool compact;

  /// Deretan pendek untuk permainan siang di layar mendatar.
  final bool slim;

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
    this.collapsedBuilder,
    this.compact = false,
    this.slim = false,
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

  /// Umur satu isyarat di layar (ms).
  static const _lifeMs = 4500;

  String _nameOf(String? id) {
    for (final p in widget.players) {
      if (p['user_id'] == id) return p['name'] as String;
    }
    return '?';
  }

  bool _alive(_Bubble b, DateTime now) =>
      now.difference(b.at).inMilliseconds < _lifeMs + 150;

  Widget _cell(Map<String, dynamic> p, DateTime now, double cellW,
      double avatar) {
    final id = p['user_id'] as String;
    final me = id == widget.myId;
    final ready = p['ready'] == true;
    final online = widget.online.contains(id);
    final out = isOut(p);
    final jailed = isJailed(p, widget.day);
    final b = _bubbles[id];
    final live = (b != null && _alive(b, now)) ? b : null;
    // Isyarat terbaru yang ditujukan ke pemain ini.
    _Bubble? incoming;
    for (final o in _bubbles.values) {
      if (o.target == id &&
          _alive(o, now) &&
          (incoming == null || o.at.isAfter(incoming.at))) {
        incoming = o;
      }
    }
    final dot = ready
        ? Colors.greenAccent
        : online
        ? Colors.amberAccent
        : Colors.grey;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: (me || out) ? null : () => widget.onTapPlayer(p),
      child: SizedBox(
        width: cellW,
        child: Column(
          children: [
            SizedBox(
              height: widget.slim ? 8 : (widget.compact ? 14 : 20),
              child: live != null
                  ? Center(child: _targetChip(live, now))
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
                    size: avatar,
                    ring: out
                        ? Colors.white30
                        : jailed
                        ? EmbunColors.blood
                        : me
                        ? EmbunColors.gold
                        : EmbunColors.goldDim.withValues(alpha: 0.8),
                  ),
                ),
                if (incoming != null && !out)
                  Positioned.fill(child: _receiverOverlay(incoming)),
                if (out)
                  const Positioned.fill(
                    child: Center(
                      child: GameIcon('silang', size: 30),
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
                        child: LivesRow(lives: livesLeft(p), size: widget.compact ? 9 : 11),
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
                // Isyarat menindih potret pengirim (paling atas).
                if (live != null && !out)
                  Positioned.fill(child: _senderOverlay(live, avatar)),
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
            if (out && !widget.compact)
              const StatusTag(
                text: 'Keluar', color: Colors.white54, asset: 'keluar', fontSize: 9)
            else if (jailed && !widget.compact)
              const StatusTag(
                  text: 'Dikurung', color: EmbunColors.blood, fontSize: 9),
          ],
        ),
      ),
    );
  }

  /// Label sasaran di atas potret pengirim.
  Widget _targetChip(_Bubble b, DateTime now) {
    final toMe = b.target == widget.myId;
    final text = b.target == null
        ? 'Semua'
        : toMe
        ? 'Untukmu'
        : '→ ${_nameOf(b.target)}';
    final color = toMe ? EmbunColors.gold : Colors.white;
    return _Timed(
      key: ValueKey('t${b.at.microsecondsSinceEpoch}'),
      ms: _lifeMs,
      builder: (t) {
        final inK = Curves.easeOutBack.transform(_seg(t, 0, 0.1));
        final out = _seg(t, 0.86, 1);
        return Opacity(
          opacity: ((1 - out) * _seg(t, 0, 0.06)).clamp(0.0, 1.0).toDouble(),
          child: Transform.scale(
            scale: 0.7 + 0.3 * inK,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.8)),
                ),
                child: Text(text,
                    maxLines: 1,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Emoji besar menindih potret pengirim: membal masuk, bergoyang pelan,
  /// lalu naik dan memudar. Cincin kejut keluar saat tiba.
  Widget _senderOverlay(_Bubble b, double size) {
    return IgnorePointer(
      child: _Timed(
        key: ValueKey('s${b.at.microsecondsSinceEpoch}'),
        ms: _lifeMs,
        builder: (t) {
          final pop =
          Curves.elasticOut.transform(_seg(t, 0, 0.16)).clamp(0.0, 1.4);
          final out = Curves.easeIn.transform(_seg(t, 0.84, 1));
          final ring = Curves.easeOut.transform(_seg(t, 0, 0.22));
          final wob = math.sin(t * math.pi * 6) * 0.07 * (1 - out);
          final beat = 1 + math.sin(t * math.pi * 9) * 0.035 * (1 - out);
          return Opacity(
            opacity: (1 - out).clamp(0.0, 1.0).toDouble(),
            child: Transform.translate(
              offset: Offset(0, -size * 0.45 * out),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  if (ring < 1)
                    Transform.scale(
                      scale: 0.9 + 0.9 * ring,
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: EmbunColors.gold
                                  .withValues(alpha: 0.9 * (1 - ring)),
                              width: 3),
                        ),
                      ),
                    ),
                  Transform.scale(
                    scale: (pop * beat).toDouble(),
                    child: Transform.rotate(
                      angle: wob,
                      child: Container(
                        width: size,
                        height: size,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.45),
                        ),
                        child: Text(b.emoji,
                            style: TextStyle(fontSize: size * 0.68, height: 1)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Potret sasaran: cincin emas berdenyut + lencana emoji kecil di pojok.
  Widget _receiverOverlay(_Bubble b) {
    return IgnorePointer(
      child: _Timed(
        key: ValueKey('r${b.at.microsecondsSinceEpoch}'),
        ms: _lifeMs,
        builder: (t) {
          final out = _seg(t, 0.86, 1);
          final pulse = (math.sin(t * math.pi * 6) + 1) / 2;
          final badge = Curves.elasticOut.transform(_seg(t, 0.04, 0.2));
          return Opacity(
            opacity: (1 - out).clamp(0.0, 1.0).toDouble(),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: EmbunColors.gold
                              .withValues(alpha: 0.55 + 0.45 * pulse),
                          width: 2.5),
                      boxShadow: [
                        BoxShadow(
                            color: EmbunColors.gold
                                .withValues(alpha: 0.35 * pulse),
                            blurRadius: 10),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: -7,
                  top: -7,
                  child: Transform.scale(
                    scale: badge.clamp(0.0, 1.4).toDouble(),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.9),
                        border: Border.all(color: EmbunColors.gold, width: 1.2),
                      ),
                      child: Text(b.emoji,
                          style: const TextStyle(fontSize: 13, height: 1)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _collapsedEmotes(DateTime now) {
    MapEntry<String, _Bubble>? newest;
    for (final entry in _bubbles.entries) {
      if (_alive(entry.value, now) &&
          (newest == null || entry.value.at.isAfter(newest.value.at))) {
        newest = entry;
      }
    }
    final recent = newest;
    final sender = recent == null ? null : _nameOf(recent.key);
    if (widget.collapsedBuilder case final build?) {
      return build(recent?.value.emoji, sender);
    }
    return IconButton(
      tooltip: recent == null ? 'Isyarat' : 'Isyarat dari $sender',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      onPressed: widget.onEmoteButton,
      icon: recent == null
          ? const Icon(Icons.emoji_emotions_outlined, size: 19)
          : Text(recent.value.emoji, style: const TextStyle(fontSize: 18)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 90) return _collapsedEmotes(now);
        // Sel melebar membagi ruang bila semua pemain muat (seperti slot lobi);
        // bila tidak, deretan bisa digulir dengan lebar sel tetap.
        final cp = widget.compact;
        final gap = 6.0;
        final minW = cp ? 46.0 : 56.0;
        final maxW = cp ? 64.0 : 84.0;
        final scrollW = cp ? 52.0 : 62.0;
        final avail = box.maxWidth - (cp ? 50 : 56); // ruang tombol isyarat
        final n = widget.players.length;
        final fits = n > 0 && n * minW + (n - 1) * gap <= avail;
        final cellW = fits
            ? ((avail - (n - 1) * gap) / n).clamp(minW, maxW).toDouble()
            : scrollW;
        final avatar = widget.slim
            ? 28.0
            : (cellW * 0.62)
                  .clamp(cp ? 30.0 : 36.0, cp ? 40.0 : 52.0)
                  .toDouble();
        final Widget list = fits
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < n; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    _cell(widget.players[i], now, cellW, avatar),
                  ],
                ],
              )
            : ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final p in widget.players)
                    Padding(
                      padding: EdgeInsets.only(right: gap),
                      child: _cell(p, now, cellW, avatar),
                    ),
                ],
              );
        final extra = (MediaQuery.textScalerOf(context).scale(10) - 10).clamp(
          0.0,
          24.0,
        );
        return _strip(
          list,
          avatar + (widget.slim ? 26 : (cp ? 36 : 54)) + extra * (cp ? 1 : 2),
        );
      },
    );
  }

  Widget _strip(Widget list, double height) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(child: list),
          Tooltip(
            message: 'Isyarat',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onEmoteButton,
              child: Container(
                width: widget.compact ? 38 : 44,
                height: widget.compact ? 38 : 44,
                margin: EdgeInsets.symmetric(horizontal: widget.compact ? 4 : 6),
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
double _seg(double v, double a, double b) =>
    ((v - a) / (b - a)).clamp(0.0, 1.0).toDouble();

/// Animasi sekali jalan selama [ms], lalu menghilang (tak menggambar apa pun).
/// Beri key unik per isyarat supaya isyarat baru memulai dari awal.
class _Timed extends StatefulWidget {
  final int ms;
  final Widget Function(double t) builder;
  const _Timed({super.key, required this.ms, required this.builder});

  @override
  State<_Timed> createState() => _TimedState();
}

class _TimedState extends State<_Timed> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: Duration(milliseconds: widget.ms))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) =>
    _c.isCompleted ? const SizedBox.shrink() : widget.builder(_c.value),
  );
}