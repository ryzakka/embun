import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../../data/game_rules.dart';
import '../common/art.dart';
import 'card_tile.dart';
import 'countdown.dart';
import '../common/ornate.dart';

/// Layar memilih kartu persembahan untuk Hayu: kartu tersusun seperti kipas,
/// pemain memilih 1-2 lalu menekan tombol dan menunggu warga lain. Setelah
/// menyerahkan, kartu yang dikirim tampil sebagai punggung (tidak dibuka),
/// dan layar tetap hidup sampai semua siap.
class OfferingView extends StatefulWidget {
  final GameRepository repo;
  final String gameId;
  final int leaves;
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

  /// Judul fase di kiri, hitung mundur di kanan.
  Widget _header() => Row(
    children: [
      const GameIcon('titlepersembahan', width: 150, height: 40),
      const Spacer(),
      if (widget.deadline != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: EmbunColors.goldDim.withValues(alpha: 0.6)),
          ),
          child: Countdown(deadline: widget.deadline),
        ),
    ],
  );

  /// Takaran daun Hayu 0..30 dengan penanda batas menang, plus kabut malam.
  Widget _gauge() {
    final v = (widget.leaves / kLeavesMax).clamp(0.0, 1.0).toDouble();
    final w = (widget.winLeaves / kLeavesMax).clamp(0.0, 1.0).toDouble();
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const GameIcon('helaidaun', size: 26),
              const SizedBox(width: 6),
              Text('${widget.leaves} daun',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: EmbunColors.gold)),
              const SizedBox(width: 10),
              Expanded(
                child: LayoutBuilder(builder: (context, c) {
                  return SizedBox(
                    height: 14,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 2,
                          child: Container(
                            height: 9,
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: v,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: widget.leaves >= widget.winLeaves
                                      ? EmbunColors.leaf
                                      : EmbunColors.gold,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: c.maxWidth * w - 1,
                          top: 0,
                          child: Container(
                              width: 2,
                              height: 14,
                              color: Colors.white70),
                        ),
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(width: 8),
              Text('menang ≥ ${widget.winLeaves}',
                  style: const TextStyle(fontSize: 10.5, color: Colors.white60)),
            ],
          ),
          if (_fog != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const GameIcon('bulirhitam', size: 18),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('Kabut malam ini: -$_fog daun',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: EmbunColors.mist, fontSize: 11.5)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Dua petak nampan di kiri dan keterangan kartu di kanan.
  Widget _altar() {
    final picked = <Map<String, dynamic>>[
      for (final h in widget.hand)
        if (sel.contains(h['id'])) h
    ];
    // Roti Surplus (wajib) selalu di petak pertama.
    picked.sort((a, b) {
      final sa = a['id'] == _samaranId && widget.isAntag ? 0 : 1;
      final sb = b['id'] == _samaranId && widget.isAntag ? 0 : 1;
      return sa - sb;
    });
    final focus = _handById(_focus) ?? (picked.isEmpty ? null : picked.last);

    Widget slot(int i) {
      final h = i < picked.length ? picked[i] : null;
      const w = 48.0;
      final locked = h != null && widget.isAntag && h['id'] == _samaranId;
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
        child: h == null
            ? Container(
          key: ValueKey('empty$i'),
          width: w,
          height: w * kTallAspect,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.black.withValues(alpha: 0.3),
            border: Border.all(
                color: EmbunColors.goldDim.withValues(alpha: 0.55)),
          ),
          child: Text('${i + 1}',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: EmbunColors.goldDim.withValues(alpha: 0.8))),
        )
            : Stack(
          key: ValueKey('slot${h['id']}'),
          clipBehavior: Clip.none,
          children: [
            CardTile(
              def: widget.defs[h['card_id']],
              fallbackName: '${h['card_id']}',
              width: w,
              selected: true,
              onTap: locked ? null : () => _toggle(h['id'] as String),
            ),
            if (locked)
              const Positioned(
                  right: -4, bottom: -4, child: GameIcon('lock', size: 20)),
          ],
        ),
      );
    }

    final d = focus == null ? null : widget.defs[focus['card_id']];
    final locked = focus != null &&
        widget.isAntag &&
        focus['id'] == _samaranId;
    return SizedBox(
      height: 48 * kTallAspect,
      child: Row(
        children: [
          slot(0),
          const SizedBox(width: 8),
          slot(1),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: EmbunColors.goldDim.withValues(alpha: 0.4)),
              ),
              child: d == null
                  ? const Center(
                child: Text(
                    'Sentuh sebuah kartu untuk melihat efeknya.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.white60)),
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
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: EmbunColors.gold)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                          locked
                              ? 'Wajib · kedok'
                              : (kindLabel[d['kind']] ?? ''),
                          style: const TextStyle(
                              fontSize: 10.5, color: Colors.white54)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Flexible(
                    child: Text('${d['description'] ?? ''}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11.5,
                            height: 1.25,
                            color: Colors.white70)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Kipas kartu di atas alas ayakan rotan.
  Widget _fanArea() {
    final p = sceneryPath('ayakanrotan-temaram');
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (p != null) ...[
            Opacity(opacity: 0.55, child: GameImage(path: p, cacheWidth: 1000)),
            ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
          ] else
            ColoredBox(color: Colors.black.withValues(alpha: 0.3)),
          _fan(),
        ],
      ),
    );
  }

  /// Kartu tersusun melengkung seperti kipas. Kartu terpilih terangkat sedikit,
  /// bertanda "Terpilih", dan muncul di petak nampan di atas.
  Widget _fan() {
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
      final n = hand.length;
      var w = ((c.maxHeight - 34) / kTallAspect).clamp(60.0, 150.0).toDouble();
      var step = w * 0.78;
      final maxSpan = c.maxWidth - w - 8;
      if (n > 1 && step * (n - 1) > maxSpan) {
        step = math.max(maxSpan / (n - 1), 14.0);
      }
      if (n > 1 && step * (n - 1) > maxSpan) {
        w = math.max(56.0, c.maxWidth / (1 + (n - 1) * 0.42) - 4);
        step = (c.maxWidth - w - 8) / (n - 1);
      }
      final total = step * (n - 1) + w;
      final left0 = (c.maxWidth - total) / 2;
      final mid = (n - 1) / 2;

      final order = List<int>.generate(n, (i) => i)
        ..sort((a, b) {
          final sa = sel.contains(hand[a]['id']) ? 1 : 0;
          final sb = sel.contains(hand[b]['id']) ? 1 : 0;
          return sa != sb ? sa - sb : a - b;
        });

      return Stack(
        clipBehavior: Clip.none,
        children: [
          for (final i in order)
            Builder(builder: (_) {
              final hh = hand[i];
              final id = hh['id'] as String;
              final cardId = hh['card_id'] as String;
              final ch = w * kTallAspect;
              final picked = sel.contains(id);
              final off = (i - mid);
              final rot = n == 1
                  ? 0.0
                  : off * math.min(0.07, 0.34 / mid.clamp(1.0, 9.0));
              final drop = off * off * (n > 5 ? 2.0 : 3.5);
              final top = (c.maxHeight - ch) / 2 + 10 + drop - (picked ? 14 : 0);
              return AnimatedPositioned(
                key: ValueKey('fan$id'),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                left: left0 + step * i,
                top: top,
                width: w,
                height: ch,
                child: AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  turns: (picked ? 0 : rot) / (2 * math.pi),
                  child: CardTile(
                    def: widget.defs[cardId],
                    fallbackName: cardId,
                    width: w,
                    selected: picked,
                    tag: picked ? 'Terpilih' : null,
                    onTap: () => _toggle(id),
                  ),
                ),
              );
            }),
        ],
      );
    });
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
                      child: Icon(
                          p['ready'] == true
                              ? Icons.check_rounded
                              : Icons.more_horiz_rounded,
                          size: 12,
                          color: p['ready'] == true
                              ? Colors.black87
                              : Colors.white60),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: EmbunColors.goldDim.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const GameIcon('wait', size: 24),
          const SizedBox(width: 8),
          Text(
              left == 0
                  ? 'Semua sudah menyerahkan...'
                  : 'Menunggu $left warga lagi  (${widget.readyCount}/${widget.total})',
              style: const TextStyle(fontSize: 13.5, color: Colors.white70)),
        ],
      ),
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

  Widget _trayFan() {
    final p = sceneryPath('ayakanrotan-temaram');
    if (p == null) return _sentFan();
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(opacity: 0.6, child: GameImage(path: p, cacheWidth: 1000)),
          ColoredBox(color: Colors.black.withValues(alpha: 0.3)),
          _sentFan(),
        ],
      ),
    );
  }

  // ---------- mode ----------

  Widget _picking(List<Map<String, dynamic>> others) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _header(),
      const SizedBox(height: 6),
      _gauge(),
      const SizedBox(height: 8),
      Text(
        widget.isAntag
            ? 'Roti Surplus wajib disertakan sebagai kedok. Tambah 1 kartu lagi bila mau.'
            : 'Pilih 1-2 kartu untuk dipersembahkan kepada Hayu.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
      const SizedBox(height: 8),
      _altar(),
      const SizedBox(height: 8),
      Expanded(child: _fanArea()),
      const SizedBox(height: 8),
      if (_needsTarget) ...[
        _targets(others),
        const SizedBox(height: 6),
      ],
      EmbunButton(
        label: sel.isEmpty
            ? 'Pilih kartu dulu'
            : 'Persembahkan (${sel.length}/2)',
        icon: 'donations',
        expand: true,
        onPressed: busy || sel.isEmpty ? null : _submit,
      ),
    ],
  );

  Widget _waiting() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _header(),
      const SizedBox(height: 6),
      _gauge(),
      const SizedBox(height: 8),
      Expanded(
        child: _sentCount > 0
            ? _trayFan()
            : Center(
            child: Opacity(
                opacity: 0.8, child: TreePortrait(leaves: widget.leaves))),
      ),
      const SizedBox(height: 8),
      const Text('Persembahanmu sudah diserahkan',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: EmbunColors.gold)),
      const SizedBox(height: 8),
      _roster(),
      const SizedBox(height: 10),
      _statusPill(),
    ],
  );

  /// Sudah keluar dari desa: tidak ada kartu untuk dipilih, hanya menonton.
  Widget _blocked() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _header(),
      const SizedBox(height: 6),
      _gauge(),
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
    for (var i = 0; i < 26; i++) {
      final spd = 0.012 + 0.02 * _r(i, 1);
      final y = 1 - ((time * spd + _r(i, 2)) % 1.0);
      final x = _r(i, 3) + math.sin(time * 0.3 + i) * 0.02;
      final tw = 0.5 + 0.5 * math.sin(time * 0.9 + i * 1.7);
      final a = (0.12 + 0.35 * _r(i, 4)) * (0.4 + 0.6 * tw);
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