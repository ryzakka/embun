import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../../data/game_rules.dart';
import '../common/art.dart';
import 'card_tile.dart';
import 'day_chrome.dart';
import '../common/ornate.dart';

/// Layar memilih kartu persembahan untuk Hayu: kartu tersusun seperti kipas,
/// pemain memilih 1-2 lalu menekan tombol dan menunggu warga lain. Setelah
/// menyerahkan, kartu yang dikirim tampil sebagai punggung (tidak dibuka),
/// dan layar tetap hidup sampai semua siap.
class OfferingView extends StatefulWidget {
  final GameRepository repo;
  final String gameId;
  final int leaves;
  final int tanahFog;
  final bool isAntag;
  final List<Map<String, dynamic>> hand;
  final Map<String, Map<String, dynamic>> defs;
  final List<Map<String, dynamic>> players;

  /// Sudah menyerahkan (siap) menurut server; layar beralih ke mode tunggu.
  final bool submitted;
  final int readyCount;
  final int total;
  final VoidCallback? onSubmitted;

  /// Sudah keluar dari desa: hanya menonton.
  final bool out;

  /// Batas akhir fase dan batas daun untuk menang (tergantung lama sesi).
  final DateTime? deadline;
  final int winLeaves;

  const OfferingView({
    super.key,
    required this.repo,
    required this.gameId,
    required this.leaves,
    this.tanahFog = 0,
    required this.isAntag,
    required this.hand,
    required this.defs,
    required this.players,
    this.submitted = false,
    this.readyCount = 0,
    this.total = 0,
    this.onSubmitted,
    this.out = false,
    this.deadline,
    this.winLeaves = 20,
  });

  @override
  State<OfferingView> createState() => _OfferingViewState();
}

class _OfferingViewState extends State<OfferingView>
    with SingleTickerProviderStateMixin {
  final Set<String> sel = {};
  String? targetId;
  bool busy = false;
  int? _fog;

  /// Jumlah kartu yang baru dikirim (untuk punggung kartu di mode tunggu).
  int _sentCount = 0;

  /// Kartu yang keterangannya sedang ditampilkan.
  String? _focus;

  late final AnimationController _drift =
  AnimationController(vsync: this, duration: const Duration(seconds: 40))
    ..repeat();

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  String? get _samaranId {
    for (final h in widget.hand) {
      if (h['card_id'] == 'embun_samaran') return h['id'] as String;
    }
    return null;
  }

  bool get _needsTarget {
    for (final h in widget.hand) {
      if (!sel.contains(h['id'])) continue;
      final eff = widget.defs[h['card_id']]?['effect'];
      if (eff is Map && eff['needs_target'] == true) return true;
    }
    return false;
  }

  /// Si Terbisik wajib menyumbang Embun Samaran: pilih otomatis begitu
  /// kartunya ada di tangan (tangan bisa tiba belakangan).
  /// Pilihan yang kartunya sudah tidak ada di tangan dibuang dulu, supaya
  /// sisa pilihan lama tidak ikut terkirim dan ditolak server.
  void _preselect() {
    final ids = {for (final h in widget.hand) h['id'] as String};
    sel.removeWhere((x) => !ids.contains(x));
    if (!widget.isAntag) return;
    final s = _samaranId;
    if (s == null || sel.contains(s)) return;
    if (sel.length >= 2) sel.remove(sel.first);
    sel.add(s);
  }

  @override
  void initState() {
    super.initState();
    _preselect();
    widget.repo.fogFor(widget.players.length).then((v) {
      if (mounted) setState(() => _fog = v);
    });
  }

  @override
  void didUpdateWidget(covariant OfferingView old) {
    super.didUpdateWidget(old);
    if (!widget.submitted) _preselect();
  }

  void _toggle(String handId) {
    if (widget.isAntag && handId == _samaranId) {
      setState(() => _focus = handId); // sumbangan wajib: hanya tampilkan
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _focus = handId;
      if (sel.contains(handId)) {
        sel.remove(handId);
      } else if (sel.length < 2) {
        sel.add(handId);
      } else {
        // Sudah 2 kartu: ganti pilihan tertua (kecuali sumbangan wajib).
        final drop = sel.firstWhere(
                (x) => !(widget.isAntag && x == _samaranId),
            orElse: () => '');
        if (drop.isNotEmpty) {
          sel.remove(drop);
          sel.add(handId);
        }
      }
      if (!_needsTarget) targetId = null;
    });
  }

  Future<void> _submit() async {
    if (_needsTarget && targetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih sasaran kartumu dulu')),
      );
      return;
    }
    final n = sel.length;
    setState(() => busy = true);
    try {
      await widget.repo.submitOffering(
        widget.gameId,
        sel.toList(),
        target: _needsTarget ? targetId : null,
      );
      HapticFeedback.mediumImpact();
      if (mounted) setState(() => _sentCount = n);
      widget.onSubmitted?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errMsg(e))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // ---------- bagian layar ----------

  Map<String, dynamic>? _handById(String? id) {
    if (id == null) return null;
    for (final h in widget.hand) {
      if (h['id'] == id) return h;
    }
    return null;
  }

  Widget _header({bool wide = false}) => Container(
    decoration: tableEdge(widget.isAntag ? EmbunColors.mist : EmbunColors.gold),
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: wide
        ? Row(children: [
            const GameIcon('titlepersembahan', width: 143, height: 34),
            const SizedBox(width: 16),
            Expanded(child: _gauge()),
          ])
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GameIcon('titlepersembahan', width: 125, height: 28),
              _gauge(),
            ],
          ),
  );

  /// Takaran daun Hayu 0..30 dengan penanda batas menang. Satu baris, tanpa kotak.
  Widget _gauge() {
    final v = (widget.leaves / kLeavesMax).clamp(0.0, 1.0).toDouble();
    final w = (widget.winLeaves / kLeavesMax).clamp(0.0, 1.0).toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const GameIcon('helaidaun', size: 24),
            const SizedBox(width: 6),
            Text('${widget.leaves}',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: EmbunColors.gold)),
            const SizedBox(width: 10),
            Expanded(
              child: LayoutBuilder(builder: (context, c) {
                return SizedBox(
                  height: 12,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 2,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: v,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: widget.leaves >= widget.winLeaves
                                    ? EmbunColors.leaf
                                    : EmbunColors.gold,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: c.maxWidth * w - 1,
                        top: 0,
                        child: Container(
                            width: 2, height: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(width: 8),
            Text('${widget.winLeaves}',
                style: const TextStyle(fontSize: 12, color: Colors.white60)),
          ],
        ),
        if (_fog case final baseFog?)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Kabut dasar + Tanah: ${math.max(0, baseFog + widget.tanahFog)} daun hilang',
              style: const TextStyle(color: EmbunColors.mist, fontSize: 11.5),
            ),
          ),
      ],
    );
  }

  /// Keterangan kartu yang terakhir disentuh.
  Widget _info() {
    final picked = <Map<String, dynamic>>[
      for (final h in widget.hand)
        if (sel.contains(h['id'])) h
    ];
    final focus = _handById(_focus) ?? (picked.isEmpty ? null : picked.last);
    final d = focus == null ? null : widget.defs[focus['card_id']];
    final locked =
        focus != null && widget.isAntag && focus['id'] == _samaranId;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: d == null
          ? Center(
        child: Text(
            widget.isAntag
                ? 'Roti Surplus wajib disertakan sebagai kedok.'
                : 'Pilih 1-2 kartu untuk dipersembahkan kepada Hayu. '
                'Sentuh kartu untuk melihat efeknya.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12.5, height: 1.3, color: Colors.white60)),
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Flexible(
                child: Text('${d['name'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: EmbunColors.gold)),
              ),
              const SizedBox(width: 8),
              Text(locked ? 'Wajib · kedok' : (kindLabel[d['kind']] ?? ''),
                  style:
                  const TextStyle(fontSize: 11, color: Colors.white54)),
            ],
          ),
          const SizedBox(height: 3),
          Text('${d['description'] ?? ''}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, height: 1.3, color: Colors.white70)),
        ],
      ),
    );
  }

  /// Kartu tersusun rata satu baris dengan jarak; bila terlalu banyak, bisa
  /// digeser ke samping. Kartu terpilih terangkat dan bertepi emas.
  Widget _cardRow() {
    final hand = widget.hand;
    if (hand.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Tanganmu kosong. Kamu tidak punya kartu untuk diserahkan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60)),
        ),
      );
    }
    return LayoutBuilder(builder: (context, c) {
      const gap = 10.0, lift = 14.0, side = 12.0;
      final n = hand.length;
      final byHeight = (c.maxHeight - lift - 8) / kTallAspect;
      final byWidth = (c.maxWidth - side * 2 - gap * (n - 1)) / n;
      // Muat satu baris bila lebar kartu tidak kurang dari 66; selain itu geser.
      final w = math.min(byHeight, math.max(byWidth, 66.0))
          .clamp(28.0, 130.0)
          .toDouble();
      return Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: side),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: c.maxWidth - side * 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var i = 0; i < n; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  _cardAt(hand[i], w, lift),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _cardAt(Map<String, dynamic> h, double w, double lift) {
    final id = h['id'] as String;
    final cardId = h['card_id'] as String;
    final picked = sel.contains(id);
    final locked = widget.isAntag && id == _samaranId;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(top: picked ? 0 : lift, bottom: picked ? lift : 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CardTile(
            def: widget.defs[cardId],
            fallbackName: cardId,
            width: w,
            selected: picked,
            tag: picked ? (locked ? 'Wajib' : 'Terpilih') : null,
            onTap: () => _toggle(id),
          ),
          if (locked)
            const Positioned(
                right: -4, top: -4, child: GameIcon('lock', size: 22)),
        ],
      ),
    );
  }

  /// Pilihan sasaran: deretan wajah pemain dengan cincin pilihan.
  Widget _targets(List<Map<String, dynamic>> others) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      const Row(
        children: [
          GameIcon('touch', size: 24),
          SizedBox(width: 6),
          Text('Pilih sasaran kartumu',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: EmbunColors.gold)),
        ],
      ),
      const SizedBox(height: 6),
      SizedBox(
        height: 66,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final p in others)
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => targetId = p['user_id'] as String);
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      PlayerAvatar(
                        path: protagonistPath(
                            (p['character_card'] as String?) ?? 'default'),
                        size: 40,
                        ring: targetId == p['user_id']
                            ? EmbunColors.gold
                            : Colors.white30,
                      ),
                      const SizedBox(height: 3),
                      SizedBox(
                        width: 56,
                        child: Text('${p['name']}',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: targetId == p['user_id']
                                    ? FontWeight.bold
                                    : FontWeight.w400,
                                color: targetId == p['user_id']
                                    ? EmbunColors.gold
                                    : Colors.white70)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );

  /// Siapa yang sudah menyerahkan: wajah dengan tanda centang. Hanya status,
  /// bukan isi persembahan.
  Widget _roster() => Wrap(
    alignment: WrapAlignment.center,
    spacing: 14,
    runSpacing: 8,
    children: [
      for (final p in widget.players)
        SizedBox(
          width: 60,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Opacity(
                    opacity: p['ready'] == true ? 1 : 0.55,
                    child: PlayerAvatar(
                      path: protagonistPath(
                          (p['character_card'] as String?) ?? 'default'),
                      size: 42,
                      ring: p['ready'] == true
                          ? EmbunColors.leaf
                          : Colors.white30,
                    ),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: p['ready'] == true
                            ? EmbunColors.leaf
                            : Colors.black87,
                        border: Border.all(
                            color: p['ready'] == true
                                ? EmbunColors.leaf
                                : Colors.white38),
                      ),
                      child: GameIcon(
                        p['ready'] == true ? 'centang' : 'wait',
                        size: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                  p['user_id'] == widget.repo.myId ? 'Kamu' : '${p['name']}',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: Colors.white70)),
            ],
          ),
        ),
    ],
  );

  Widget _statusPill() {
    final left = (widget.total - widget.readyCount).clamp(0, 99).toInt();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const GameIcon('wait', size: 22),
        const SizedBox(width: 8),
        Text(
            left == 0
                ? 'Semua sudah menyerahkan...'
                : 'Menunggu $left warga lagi  (${widget.readyCount}/${widget.total})',
            style: const TextStyle(fontSize: 13, color: Colors.white70)),
      ],
    );
  }

  /// Punggung kartu yang sudah diserahkan, tersusun kipas kecil.
  Widget _sentFan() {
    final n = _sentCount.clamp(1, 2).toInt();
    return LayoutBuilder(builder: (context, c) {
      final w = ((c.maxHeight - 10) / kTallAspect).clamp(50.0, 110.0).toDouble();
      final h = w * kTallAspect;
      return Center(
        child: SizedBox(
          width: w * 1.8,
          height: h + 8,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < n; i++)
                Transform.translate(
                  offset: Offset((i - (n - 1) / 2) * w * 0.5, 0),
                  child: Transform.rotate(
                    angle: (i - (n - 1) / 2) * 0.14,
                    child: Container(
                      width: w,
                      height: h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                              color: EmbunColors.gold.withValues(alpha: 0.35),
                              blurRadius: 14),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        // Punggung sama untuk semua pemain: tidak membocorkan peran.
                        child: GameImage(path: itemBackPath(), cacheWidth: 320),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _picking(List<Map<String, dynamic>> others) => LayoutBuilder(
    builder: (context, box) {
      final wide = box.maxWidth >= 485;
      final action = EmbunButton(
        label: sel.isEmpty ? 'Pilih kartu dulu' : 'Persembahkan (${sel.length}/2)',
        icon: 'donations',
        expand: true,
        height: 44,
        onPressed: busy || sel.isEmpty ? null : _submit,
      );
      final detail = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _info(),
          if (_needsTarget) _targets(others),
        ],
      );
      final Widget content;
      if (wide) {
        content = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _cardRow()),
            Container(
              width: (box.maxWidth * 0.30).clamp(185.0, 305.0),
              padding: const EdgeInsets.fromLTRB(8, 2, 2, 0),
              decoration: tableEdge(EmbunColors.gold, vertical: true),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: Center(child: SingleChildScrollView(child: detail))),
                  action,
                ],
              ),
            ),
          ],
        );
      } else if (box.maxHeight < 410) {
        content = ListView(
          children: [SizedBox(height: 148, child: _cardRow()), detail, action],
        );
      } else {
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _cardRow()),
            DecoratedBox(decoration: tableEdge(EmbunColors.gold, top: true), child: detail),
            action,
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_header(wide: wide), Expanded(child: content)],
      );
    },
  );

  Widget _waiting() => LayoutBuilder(
    builder: (context, box) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(wide: box.maxWidth >= 485),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: (box.maxHeight * 0.37).clamp(90.0, 205.0),
                    child: _sentCount > 0
                        ? _sentFan()
                        : Center(child: TreePortrait(leaves: widget.leaves)),
                  ),
                  const SizedBox(height: 5),
                  const Text('Persembahanmu sudah diserahkan', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                      color: EmbunColors.gold)),
                  const SizedBox(height: 7),
                  _roster(),
                  const SizedBox(height: 7),
                  _statusPill(),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  /// Sudah keluar dari desa: tidak ada kartu untuk dipilih, hanya menonton.
  Widget _blocked() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _header(),
      Expanded(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const GameIcon('lock', size: 64),
                const SizedBox(height: 10),
                const Text('Kamu sudah keluar dari desa',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: EmbunColors.blood)),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: const Text(
                      'Kamu tidak lagi ikut mempersembahkan kartu. Tonton saja '
                          'bagaimana nasib Hayu malam ini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13, height: 1.35, color: Colors.white70)),
                ),
              ],
            ),
          ),
        ),
      ),
      _roster(),
      const SizedBox(height: 10),
      _statusPill(),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final others = widget.players
        .where((p) => p['user_id'] != widget.repo.myId)
        .toList();
    final Widget content = widget.out
        ? _blocked()
        : (widget.submitted ? _waiting() : _picking(others));
    return Stack(
      fit: StackFit.expand,
      children: [
        // Bara dan daun melayang pelan di latar.
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _drift,
            builder: (context, _) => CustomPaint(
              painter: _DriftPainter(_drift.value * 40, widget.isAntag),
            ),
          ),
        ),
        content,
      ],
    );
  }
}

/// Bara emas (ungu bagi Si Terbisik) yang naik pelan dan berkelip.
class _DriftPainter extends CustomPainter {
  final double time;
  final bool dark;
  const _DriftPainter(this.time, this.dark);

  static double _r(int i, int k) {
    final v = math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
    return v - v.floor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final col = dark ? const Color(0xFFB07CE8) : const Color(0xFFFFE08A);
    for (var i = 0; i < 12; i++) {
      final spd = 0.012 + 0.02 * _r(i, 1);
      final y = 1 - ((time * spd + _r(i, 2)) % 1.0);
      final x = _r(i, 3) + math.sin(time * 0.3 + i) * 0.02;
      final tw = 0.5 + 0.5 * math.sin(time * 0.9 + i * 1.7);
      final a = (0.10 + 0.25 * _r(i, 4)) * (0.4 + 0.6 * tw);
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        1.1 + 2.2 * _r(i, 5),
        Paint()
          ..color = col.withValues(alpha: a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DriftPainter old) => true;
}