import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../common/art.dart';
import 'card_tile.dart';
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

  /// Terkurung: tidak boleh menyerahkan persembahan (server ikut menolak).
  final bool jailed;

  /// Sudah keluar dari desa: hanya menonton.
  final bool out;

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
    this.jailed = false,
    this.out = false,
  });

  @override
  State<OfferingView> createState() => _OfferingViewState();
}

class _OfferingViewState extends State<OfferingView> {
  final Set<String> sel = {};
  String? targetId;
  bool busy = false;
  int? _fog;

  /// Jumlah kartu yang baru dikirim (untuk punggung kartu di mode tunggu).
  int _sentCount = 0;

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
    if (widget.isAntag && handId == _samaranId) return; // sumbangan wajib
    HapticFeedback.selectionClick();
    setState(() {
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

  // ---------- kipas kartu ----------

  /// Kartu tersusun melengkung seperti kipas; yang terpilih terangkat.
  Widget _fan() {
    final hand = widget.hand;
    if (hand.isEmpty) {
      return const Center(
        child: Text('Tanganmu kosong. Kamu tidak punya kartu untuk diserahkan.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54)),
      );
    }
    return LayoutBuilder(builder: (context, c) {
      final n = hand.length;
      // Lebar kartu: dibatasi tinggi area (ruang untuk kartu terangkat) dan
      // lebar (sedikit bertumpuk bila banyak kartu).
      var w = ((c.maxHeight - 30) * 7 / 9).clamp(64.0, 150.0).toDouble();
      var step = w * 0.78;
      final maxSpan = c.maxWidth - w - 8;
      if (n > 1 && step * (n - 1) > maxSpan) {
        step = math.max(maxSpan / (n - 1), 14.0);
        if (step < 14) step = 14;
      }
      if (n > 1 && step * (n - 1) > maxSpan) {
        // Masih tak muat: kecilkan kartu.
        w = math.max(56.0, c.maxWidth / (1 + (n - 1) * 0.42) - 4);
        step = (c.maxWidth - w - 8) / (n - 1);
      }
      final h = w * 9 / 7;
      final total = step * (n - 1) + w;
      final left0 = (c.maxWidth - total) / 2;
      final mid = (n - 1) / 2;

      // Gambar kartu terpilih paling akhir (di atas) agar tidak tertutup.
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
              final picked = sel.contains(id);
              final off = (i - mid);
              final rot = n == 1 ? 0.0 : off * math.min(0.07, 0.34 / mid.clamp(1.0, 9.0));
              final drop = off * off * (n > 5 ? 2.0 : 3.5);
              final top = (c.maxHeight - h) / 2 + 8 + drop - (picked ? 26 : 0);
              return AnimatedPositioned(
                key: ValueKey('fan$id'),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                left: left0 + step * i,
                top: top,
                width: w,
                height: h,
                child: AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  turns: (picked ? 0 : rot) / (2 * math.pi),
                  child: CardTile(
                    def: widget.defs[cardId],
                    fallbackName: cardId,
                    width: w,
                    selected: picked,
                    onTap: () => _toggle(id),
                  ),
                ),
              );
            }),
        ],
      );
    });
  }

  /// Punggung kartu yang sudah diserahkan, tersusun kipas kecil.
  Widget _sentFan() {
    final n = _sentCount.clamp(1, 2).toInt();
    return LayoutBuilder(builder: (context, c) {
      final w = ((c.maxHeight - 10) * 7 / 9).clamp(50.0, 110.0).toDouble();
      final h = w * 9 / 7;
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
                        child: GameImage(
                            path: cardBackPath(), cacheWidth: 320),
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

  Widget _header() => Column(
    children: [
      const GameIcon('titlepersembahan', width: 190, height: 50),
      const SizedBox(height: 2),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const GameIcon('helaidaun', size: 30),
          const SizedBox(width: 6),
          Text('${widget.leaves} daun',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: EmbunColors.gold)),
          if (_fog != null) ...[
            const SizedBox(width: 14),
            const GameIcon('bulirhitam', size: 22),
            const SizedBox(width: 4),
            Flexible(
              child: Text('Kabut malam ini: -$_fog daun',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: EmbunColors.mist, fontSize: 12)),
            ),
          ],
        ],
      ),
    ],
  );

  /// Terkurung / keluar: tidak ada kartu untuk dipilih, hanya menunggu.
  Widget _blocked() {
    final title =
    widget.out ? 'Kamu sudah keluar dari desa' : 'Kamu sedang dikurung';
    final body = widget.out
        ? 'Kamu tidak lagi ikut mempersembahkan kartu. Tonton saja bagaimana '
        'nasib Hayu malam ini.'
        : 'Pemain yang dikurung tidak bisa menyerahkan persembahan sampai '
        'musyawarah berikutnya. Kartumu tetap aman di tangan.';
    return Column(
      children: [
        _header(),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GameIcon('lock', size: 72),
                  const SizedBox(height: 12),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: EmbunColors.blood)),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Text(body,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 13, height: 1.35, color: Colors.white70)),
                  ),
                ],
              ),
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: widget.total == 0
                ? 0
                : (widget.readyCount / widget.total).clamp(0.0, 1.0).toDouble(),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 10),
        EmbunButton(
          label: 'Menunggu ${widget.readyCount}/${widget.total} warga...',
          icon: 'wait',
          expand: true,
          kind: EmbunButtonKind.secondary,
          onPressed: null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final others = widget.players
        .where((p) => p['user_id'] != widget.repo.myId)
        .toList();

    if (widget.jailed || widget.out) return _blocked();

    if (widget.submitted) {
      return Column(
        children: [
          _header(),
          const SizedBox(height: 6),
          Expanded(
            child: _sentCount > 0
                ? _sentFan()
                : Center(child: Opacity(opacity: 0.8, child: TreePortrait(leaves: widget.leaves))),
          ),
          const SizedBox(height: 8),
          const Text('Persembahanmu sudah diserahkan',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: EmbunColors.gold)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: widget.total == 0
                  ? 0
                  : (widget.readyCount / widget.total).clamp(0.0, 1.0).toDouble(),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 10),
          EmbunButton(
            label: 'Menunggu ${widget.readyCount}/${widget.total} warga...',
            icon: 'wait',
            expand: true,
            kind: EmbunButtonKind.secondary,
            onPressed: null,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        const SizedBox(height: 4),
        Text(
          widget.isAntag
              ? 'Wajib menyumbang: Papan Penanda sudah terpilih. Tambah 1 kartu lagi jika mau.'
              : 'Pilih 1-2 kartu untuk dipersembahkan kepada Hayu',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        Expanded(child: _fan()),
        if (_needsTarget) ...[
          const Row(
            children: [
              GameIcon('touch', size: 26),
              SizedBox(width: 6),
              Text('Pilih sasaran kartumu:',
                  style: TextStyle(fontSize: 12, color: EmbunColors.gold)),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final p in others)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(p['name'] as String),
                      selected: targetId == p['user_id'],
                      onSelected: (_) =>
                          setState(() => targetId = p['user_id'] as String),
                    ),
                  ),
              ],
            ),
          ),
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
  }
}