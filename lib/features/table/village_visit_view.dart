import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../../data/server_clock.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'day_view.dart';
import 'research_view.dart';

typedef VillageRow = Map<String, dynamic>;

/// Panah hanya memilih tujuan. Jatah dipakai oleh server saat pemain masuk.
class VillageVisitView extends StatefulWidget {
  const VillageVisitView({
    super.key,
    required this.repo,
    required this.gameId,
    required this.day,
    required this.defs,
    required this.hand,
    required this.players,
    required this.trades,
    required this.events,
    required this.balance,
    required this.isAntag,
    required this.jailed,
    required this.iAmReady,
    required this.readyCount,
    required this.total,
    this.deadline,
    this.onHandChanged,
  });
  final GameRepository repo;
  final String gameId;
  final int day;
  final Map<String, VillageRow> defs;
  final List<VillageRow> hand, players, trades, events;
  final double balance;
  final bool isAntag, jailed, iAmReady;
  final int readyCount, total;
  final DateTime? deadline;
  final VoidCallback? onHandChanged;
  @override
  State<VillageVisitView> createState() => _VillageVisitViewState();
}

const _places = [
  (
    'riset',
    'Pasar Riset',
    'Bekal untuk persembahan berikutnya.',
    'pasar-sianghari',
    'pasar-sianghari',
    Icons.auto_stories_outlined,
  ),
  (
    'sumur',
    'Sumur Desa',
    'Satu sumbangan. Pengaruh sepanjang permainan.',
    'sumur-sianghari',
    'sumur-sianghari',
    Icons.water_drop_outlined,
  ),
  (
    'bengkel',
    'Bengkel Desa',
    'Satukan kartu lanjutan dengan kartu poin.',
    'tempat-bengkel',
    'tempatdalam-bengkel',
    Icons.handyman_outlined,
  ),
  (
    'pondok',
    'Pondok Perawatan',
    'Sebuah surat membuka layanan pondok.',
    'tempat-pondokperawatan',
    'tempatdalam-pondokperawatan',
    Icons.local_hospital_outlined,
  ),
  (
    'balai',
    'Balai Pertukaran',
    'Temui warga lain. Sepakati pertukaran kartu.',
    'tempat-balaitukar',
    'tempatdalam-balaitukar',
    Icons.swap_horiz_rounded,
  ),
];

class _VillageVisitViewState extends State<VillageVisitView> {
  VillageRow? _status;
  String? _error, _target, _offerTarget, _offerHand;
  int _index = 0;
  int _revision = 0;
  bool _busy = false, _loading = false, _finished = false;
  Timer? _timer;
  Color get _accent => widget.isAntag ? EmbunColors.mist : EmbunColors.gold;
  VillageRow? get _visit => _status?['current'] is Map
      ? Map<String, dynamic>.from(_status!['current'])
      : null;
  bool get _waiting => widget.iAmReady || _finished;
  bool get _used => _visit?['action_used'] == true;
  bool get _free => _visit?['invitation_id'] != null;
  String get _letter => widget.isAntag ? 'surat_sakit' : 'surat_dokter';
  VillageRow? get _ticket =>
      widget.hand.where((h) => h['card_id'] == _letter).firstOrNull;
  num _number(String key, num fallback) => _status?[key] as num? ?? fallback;
  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
      if (ServerClock.now().second % 5 == 0) _load();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading || _busy) return;
    _loading = true;
    final revision = _revision;
    try {
      final next = await widget.repo.villageStatus(widget.gameId);
      if (mounted && !_busy && revision == _revision) {
        setState(() {
          _status = next;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && _status == null) setState(() => _error = errMsg(e));
    } finally {
      _loading = false;
    }
  }

  Future<void> _act(Future<VillageRow> Function() action) async {
    if (_busy || _waiting) return;
    _revision++;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final next = await action();
      if (mounted) setState(() => _status = next);
      widget.onHandChanged?.call();
    } catch (e) {
      if (mounted) setState(() => _error = errMsg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() =>
      _act(() => widget.repo.leaveVillagePlace(widget.gameId));
  Future<void> _finish() async {
    await _act(() async {
      await widget.repo.finishVillageVisits(widget.gameId);
      if (mounted) setState(() => _finished = true);
      return _status ?? {};
    });
  }

  String _signed(num value) =>
      '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2).replaceAll('.', ',')}';
  String _name(Object? id) =>
      widget.players.where((p) => p['user_id'] == id).firstOrNull?['name']
          as String? ??
      'Pemain';

  Widget _button(
    String label,
    VoidCallback? action, {
    bool secondary = false,
  }) => secondary
      ? OutlinedButton(
          onPressed: action,
          child: Text(label, textAlign: TextAlign.center),
        )
      : FilledButton(
          onPressed: action,
          child: Text(label, textAlign: TextAlign.center),
        );
  Widget _text(
    String text, {
    double size = 14,
    Color? color,
    FontWeight? weight,
  }) => Text(
    text,
    style: TextStyle(
      fontSize: size,
      height: 1.35,
      color: color ?? EmbunColors.cream,
      fontWeight: weight,
    ),
  );
  Widget _service(IconData icon, String title, List<Widget> children) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(20),
        children: [
          Icon(icon, size: 44, color: _accent),
          const SizedBox(height: 18),
          _text(title, size: 26, weight: FontWeight.w800),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
  Widget _gap() => const SizedBox(height: 16);

  Widget _well() {
    final bonus = _number('well_bonus', 0),
        step = _number('well_step', .15),
        cap = _number('well_cap', 1.5);
    final cost = _number('well_cost', 8);
    final capped = widget.isAntag ? bonus <= -cap : bonus >= cap;
    final change = widget.isAntag ? -step : step;
    final next = (bonus + change).clamp(-cap, cap);
    return _service(
      Icons.water_drop_outlined,
      widget.isAntag ? 'Kotori sumur' : 'Rawat sumur desa',
      [
        _text('Laju bersama', color: Colors.white70),
        _text(
          '${_signed(bonus)} / hari',
          size: 40,
          color: bonus < 0 ? EmbunColors.blood : EmbunColors.leaf,
          weight: FontWeight.w800,
        ),
        _gap(),
        _text(
          'Berlaku bagi seluruh pemain sampai permainan berakhir, termasuk Si Terbisik.',
        ),
        _gap(),
        _text(
          'Setelah tindakanmu: ${_signed(next)} / hari',
          weight: FontWeight.bold,
        ),
        _text(
          'Biaya $cost • Batas ${_signed(-cap)} sampai ${_signed(cap)}',
          size: 12,
          color: Colors.white70,
        ),
        _gap(),
        if (_used)
          _text(
            'Tindakan sumur sudah dilakukan pada kunjungan ini.',
            color: EmbunColors.leaf,
          )
        else
          _button(
            capped
                ? 'Batas sumur tercapai'
                : '${widget.isAntag ? 'Cemari' : 'Sumbangkan'} · $cost',
            _busy || capped || widget.balance < cost
                ? null
                : () => _act(() => widget.repo.contributeWell(widget.gameId)),
          ),
      ],
    );
  }

  Widget _clinic() {
    final patients = widget.players
        .where((p) => p['out_day'] == null && ((p['strikes'] as int?) ?? 0) > 0)
        .toList();
    final ids = patients.map((p) => p['user_id'] as String).toSet();
    final target = ids.contains(_target)
        ? _target
        : ids.contains(widget.repo.myId)
        ? widget.repo.myId
        : ids.firstOrNull;
    final fee = target != null && target != widget.repo.myId
        ? _number('care_other_fee', 12)
        : 0;
    return _service(Icons.local_hospital_outlined, 'Pondok Perawatan', [
      _text(
        widget.isAntag
            ? 'Pasang jebakan rahasia untuk satu pengunjung lain.'
            : 'Serahkan Surat Dokter untuk memulihkan satu nyawa.',
      ),
      _gap(),
      if (widget.isAntag) ...[
        _text(
          'Jebakan menetap sampai terkena. Satu pengunjung selain pemasang akan kehilangan 1 nyawa. Korban dipilih saat semua kunjungan berakhir.',
        ),
        _gap(),
        if (_status?['own_trap_waiting'] == true)
          _text('Jebakanmu masih menunggu pengunjung.', color: _accent),
      ] else ...[
        if (patients.isEmpty)
          _text('Semua pemain yang masih di desa memiliki nyawa penuh.')
        else
          DropdownButtonFormField<String>(
            key: ValueKey('patient-$target'),
            initialValue: target,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Penerima perawatan'),
            items: [
              for (final p in patients)
                DropdownMenuItem(
                  value: p['user_id'] as String,
                  child: Text(
                    '${p['name']}${p['user_id'] == widget.repo.myId ? ' · Kamu' : ''}',
                  ),
                ),
            ],
            onChanged: _busy || _used
                ? null
                : (id) => setState(() => _target = id),
          ),
        _gap(),
        _text(
          'Biaya tambahan: $fee. Perawatan diproses sebelum jebakan ketika kunjungan selesai.',
          size: 13,
          color: Colors.white70,
        ),
      ],
      _gap(),
      if (_used)
        _text(
          'Surat telah digunakan. Hasil diumumkan setelah semua pemain selesai.',
          color: EmbunColors.leaf,
        )
      else
        _button(
          widget.isAntag
              ? 'Gunakan surat · Pasang jebakan'
              : 'Gunakan surat · Pulihkan 1 nyawa',
          _busy ||
                  _ticket == null ||
                  (!widget.isAntag &&
                      (target == null || widget.balance < fee)) ||
                  (widget.isAntag && _status?['own_trap_waiting'] == true)
              ? null
              : () => _act(
                  () => widget.repo.useClinicLetter(
                    widget.gameId,
                    _ticket!['id'] as String,
                    target: widget.isAntag ? null : target,
                  ),
                ),
        ),
      if (_ticket == null && !_used)
        _text(
          'Beli ${widget.isAntag ? 'Surat Keterangan Sakit' : 'Surat Dokter'} di Pasar Riset.',
          size: 12,
          color: Colors.white70,
        ),
    ]);
  }

  DayView _desk(DayTab tab) => DayView(
    key: ValueKey('${_visit?['id']}-$tab'),
    repo: widget.repo,
    gameId: widget.gameId,
    day: widget.day,
    priceMod: 0,
    extraBuy: 0,
    initialTab: tab,
    venueMode: true,
    visitsEnabled: true,
    hand: widget.hand,
    defs: widget.defs,
    balance: widget.balance,
    jailed: widget.jailed,
    iAmReady: _waiting,
    readyCount: widget.readyCount,
    total: widget.total,
    players: widget.players,
    events: widget.events,
    trades: _free
        ? widget.trades
              .where((t) => t['id'] == _visit?['invitation_id'])
              .toList()
        : widget.trades,
    dark: widget.isAntag,
    isAntag: widget.isAntag,
    onHandChanged: widget.onHandChanged,
  );
  Widget _hall() {
    final cards = widget.hand
        .where(
          (h) =>
              h['card_id'] != 'embun_samaran' &&
              widget.defs[h['card_id']]?['kind'] != 'malam',
        )
        .toList();
    final others = widget.players
        .where((p) => p['user_id'] != widget.repo.myId && p['out_day'] == null)
        .toList();
    final selectedHand = cards.any((h) => h['id'] == _offerHand)
        ? _offerHand
        : null;
    final selectedTarget = others.any((p) => p['user_id'] == _offerTarget)
        ? _offerTarget
        : null;
    return Column(
      children: [
        if (_free)
          Padding(
            padding: const EdgeInsets.all(12),
            child: _text(
              'Kunjungan undangan · Tanpa memakai jatah. Kembali untuk melanjutkan tempat sebelumnya.',
              size: 12,
              color: _accent,
            ),
          ),
        if (!_free && !widget.jailed)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('offer-target-$selectedTarget'),
                        initialValue: selectedTarget,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Tawarkan kepada',
                        ),
                        items: [
                          for (final p in others)
                            DropdownMenuItem(
                              value: p['user_id'] as String,
                              child: Text(p['name'] as String),
                            ),
                        ],
                        onChanged: _busy
                            ? null
                            : (id) => setState(() => _offerTarget = id),
                      ),
                    ),
                    SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('offer-card-$selectedHand'),
                        initialValue: selectedHand,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Kartu yang kamu tawarkan',
                        ),
                        items: [
                          for (final h in cards)
                            DropdownMenuItem(
                              value: h['id'] as String,
                              child: Text(
                                widget.defs[h['card_id']]?['name'] as String? ??
                                    'Kartu',
                              ),
                            ),
                        ],
                        onChanged: _busy
                            ? null
                            : (id) => setState(() => _offerHand = id),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _button(
                    'Kirim tawaran',
                    _busy || selectedHand == null || selectedTarget == null
                        ? null
                        : () => _act(() async {
                            await widget.repo.proposeTrade(
                              widget.gameId,
                              selectedTarget,
                              selectedHand,
                            );
                            return widget.repo.villageStatus(widget.gameId);
                          }),
                  ),
                ),
              ],
            ),
          ),
        Expanded(child: _desk(DayTab.hall)),
      ],
    );
  }

  Widget _interior(String place) => switch (place) {
    'riset' => ResearchView(
      key: ValueKey(_visit?['id']),
      repo: widget.repo,
      gameId: widget.gameId,
      day: widget.day,
      defs: widget.defs,
      balance: widget.balance,
      jailed: widget.jailed,
      iAmReady: _waiting,
      readyCount: widget.readyCount,
      total: widget.total,
      dark: widget.isAntag,
      onBought: widget.onHandChanged,
      onReturn: _leave,
    ),
    'sumur' => _well(),
    'pondok' => _clinic(),
    'bengkel' => _desk(DayTab.merge),
    _ => _hall(),
  };
  Widget _invitations() {
    final incoming = widget.trades
        .where(
          (t) =>
              t['status'] == 'pending' &&
              t['day'] == widget.day &&
              t['to_id'] == widget.repo.myId &&
              t['id'] != _visit?['invitation_id'],
        )
        .toList();
    if (incoming.isEmpty || _waiting || _free) return const SizedBox.shrink();
    final t = incoming.first;
    return Material(
      color: EmbunColors.panelHi,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            Text(
              '${_name(t['from_id'])} mengundangmu bertukar${incoming.length > 1 ? ' · ${incoming.length} tawaran' : ''}',
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _act(
                      () => widget.repo.enterVillagePlace(
                        widget.gameId,
                        'balai',
                        invitation: t['id'] as String,
                      ),
                    ),
              child: const Text('Ke balai · Gratis'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _act(() async {
                      await widget.repo.respondTrade(t['id'] as String, false);
                      return widget.repo.villageStatus(widget.gameId);
                    }),
              child: const Text('Tolak'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _picker(bool wide) {
    final p = _places[_index];
    final left = (_number('limit', 2) - _number('used', 0)).clamp(0, 2);
    final allowed = left > 0 && (_index != 3 || _ticket != null);
    final description = switch (p.$1) {
      'riset' => 'Poin, kartu lanjutan, dan surat perawatan. Harga riset +20%.',
      'sumur' =>
        widget.isAntag
            ? 'Cemari sumur untuk menghambat laju seluruh desa.'
            : 'Sumbangkan embun untuk menaikkan laju seluruh desa.',
      'bengkel' =>
        'Pilih kartu lanjutan dan kartu poin. Penggabungan mengaktifkan kartu.',
      'pondok' =>
        widget.isAntag
            ? 'Syarat: Surat Keterangan Sakit. Pasang jebakan yang menetap sampai terpicu.'
            : 'Syarat: Surat Dokter. Rawat diri, atau bayar tambahan untuk merawat pemain lain.',
      _ =>
        'Tawarkan kartu dan jawab undangan. Penerima undangan boleh datang tanpa memakai jatah.',
    };
    final controls = Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Tempat sebelumnya',
                onPressed: () => setState(() => _index = (_index + 4) % 5),
                icon: const Icon(Icons.chevron_left),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _button(
                  left == 0
                      ? 'Jatah kunjungan habis'
                      : _index == 3 && _ticket == null
                      ? 'Perlu surat perawatan'
                      : 'Masuk · 1 kunjungan',
                  _busy || !allowed
                      ? null
                      : () => _act(
                          () => widget.repo.enterVillagePlace(
                            widget.gameId,
                            p.$1,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                tooltip: 'Tempat berikutnya',
                onPressed: () => setState(() => _index = (_index + 1) % 5),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _text(
            'Panah memilih tujuan · Tersisa $left kunjungan',
            size: 12,
            color: Colors.white70,
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, box) {
        final short = box.maxHeight < 360;
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              wide ? 48 : 22,
              short ? 8 : 20,
              wide ? 48 : 22,
              8,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: short ? 0 : box.maxHeight - 155,
                        ),
                        child: Align(
                          alignment: wide
                              ? Alignment.centerLeft
                              : Alignment.bottomLeft,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _text(
                                'JELAJAH DESA  ·  ${_index + 1} / ${_places.length}',
                                size: 12,
                                color: _accent,
                                weight: FontWeight.w800,
                              ),
                              SizedBox(height: short ? 8 : 18),
                              if (!short) ...[
                                Icon(p.$6, size: 40, color: _accent),
                                const SizedBox(height: 14),
                              ],
                              _text(
                                p.$2,
                                size: short
                                    ? 28
                                    : wide
                                    ? 48
                                    : 36,
                                weight: FontWeight.w800,
                              ),
                              SizedBox(height: short ? 8 : 16),
                              _text(p.$3, size: short ? 15 : 18),
                              const SizedBox(height: 12),
                              _text(description, color: Colors.white70),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  controls,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _visit, place = current?['place'] as String?;
    final selected = place == null
        ? _places[_index]
        : _places.firstWhere((p) => p.$1 == place);
    final seconds = widget.deadline
        ?.difference(ServerClock.now())
        .inSeconds
        .clamp(0, 9999);
    final bg = firstScenery([
      place == null ? selected.$4 : selected.$5,
      'pasar-sianghari',
      'sumur-sianghari',
    ]);
    return LayoutBuilder(
      builder: (context, box) => Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: SizedBox.expand(
              key: ValueKey(bg),
              child: GameImage(path: bg),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  EmbunColors.bg.withValues(alpha: .6),
                  EmbunColors.bg.withValues(alpha: place == null ? .4 : .92),
                  EmbunColors.bg.withValues(alpha: .97),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (place != null && !_waiting)
                            IconButton(
                              tooltip: 'Kembali dari tempat ini',
                              onPressed: _busy ? null : _leave,
                              icon: const Icon(Icons.arrow_back),
                            ),
                          Flexible(
                            child: _text(
                              place == null
                                  ? 'Malam sebelum persembahan'
                                  : selected.$2,
                              size: 16,
                              weight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GameIcon(
                            widget.isAntag ? 'bulirhitam' : 'bulirembun',
                            size: 24,
                          ),
                          const SizedBox(width: 5),
                          _text(
                            widget.balance
                                .toStringAsFixed(1)
                                .replaceAll('.', ','),
                            size: 22,
                            weight: FontWeight.w800,
                          ),
                          const SizedBox(width: 18),
                          if (seconds != null)
                            _text(
                              '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                              color: _accent,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  Material(
                    color: const Color(0xDD4D201E),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Expanded(child: Text(_error!)),
                          IconButton(
                            tooltip: 'Coba lagi',
                            onPressed: _busy ? null : _load,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                    ),
                  ),
                _invitations(),
                Expanded(
                  child: _waiting
                      ? _service(
                          Icons.nights_stay_outlined,
                          'Kunjungan selesai',
                          [
                            _text(
                              'Menunggu ${widget.readyCount}/${widget.total} pemain. Hasil pondok dan persembahan menyusul.',
                            ),
                          ],
                        )
                      : _status == null
                      ? const Center(child: CircularProgressIndicator())
                      : place == null
                      ? _picker(box.maxWidth > 760)
                      : _interior(place),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 8,
                    spacing: 18,
                    children: [
                      _text(
                        'Kunjungan ${_number('used', 0)}/${_number('limit', 2)} · Hari ${widget.day}',
                        size: 12,
                        color: Colors.white70,
                      ),
                      if (!_waiting)
                        _button(
                          'Selesai menjelajah',
                          _busy ? null : _finish,
                          secondary: true,
                        ),
                    ],
                  ),
                ),
                if (_busy) const LinearProgressIndicator(minHeight: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
