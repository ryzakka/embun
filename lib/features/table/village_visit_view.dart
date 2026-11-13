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
import 'village_card_picker.dart';
import 'village_exchange_view.dart';
import 'clinic_entry_scene.dart';

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
  String? _error, _target;
  bool _clinicGate = false;
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
    if (_loading || _busy || _clinicGate) return;
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

  Future<bool> _act(Future<VillageRow> Function() action) async {
    if (_busy || _waiting) return false;
    _revision++;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final next = await action();
      if (mounted) setState(() => _status = next);
      widget.onHandChanged?.call();
      return true;
    } catch (e) {
      if (mounted) setState(() => _error = errMsg(e));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    await _act(() => widget.repo.leaveVillagePlace(widget.gameId));
  }

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
  Widget _service(IconData icon, String title, List<Widget> children) =>
      ListView(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 18),
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: _accent),
              const SizedBox(width: 10),
              Expanded(child: _text(title, size: 24, weight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 22),
          ...children,
        ],
      );
  Widget _gap() => const SizedBox(height: 18);
  Widget _well() {
    final bonus = _number('well_bonus', 0),
        step = _number('well_step', .15),
        cap = _number('well_cap', 1.5),
        cost = _number('well_cost', 8);
    final next = (bonus + (widget.isAntag ? -step : step)).clamp(-cap, cap);
    final capped = widget.isAntag ? bonus <= -cap : bonus >= cap;
    return _service(
      Icons.water_drop_outlined,
      widget.isAntag ? 'Cemari sumur' : 'Rawat sumur desa',
      [
        _text(
          'LAJU BERSAMA',
          size: 10,
          color: Colors.white60,
          weight: FontWeight.w800,
        ),
        _text(
          _signed(bonus),
          size: 52,
          color: bonus < 0 ? EmbunColors.blood : EmbunColors.leaf,
          weight: FontWeight.w800,
        ),
        _text('embun / bulir hitam per hari', size: 12, color: Colors.white70),
        _gap(),
        const Divider(color: Color(0x339C8442)),
        _gap(),
        Row(
          children: [
            Icon(
              widget.isAntag ? Icons.trending_down : Icons.trending_up,
              color: _accent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _text('Setelah tindakanmu', size: 12, color: Colors.white60),
                  _text(
                    '${_signed(next)} / hari',
                    size: 24,
                    weight: FontWeight.w800,
                  ),
                ],
              ),
            ),
          ],
        ),
        _gap(),
        _text(
          'Efek menetap hingga gim berakhir, untuk seluruh pemain dan kedua fraksi.',
          size: 12,
          color: Colors.white70,
        ),
        _gap(),
        if (_used)
          _text(
            'Sumbangan tercatat',
            size: 18,
            color: EmbunColors.leaf,
            weight: FontWeight.w800,
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
        const SizedBox(height: 10),
        _text(
          'Batas ${_signed(-cap)} hingga ${_signed(cap)} · 1 tindakan per kunjungan',
          size: 11,
          color: Colors.white54,
        ),
      ],
    );
  }

  Future<void> _choosePatient(
    List<VillageRow> patients,
    String? selected,
  ) async {
    if (_busy || _used) return;
    final id = await showVillageCardPicker(
      context,
      title: 'Siapa yang akan dirawat?',
      options: [
        for (final p in patients)
          VillageCardOption.player(p, myId: widget.repo.myId),
      ],
      selected: selected,
      confirmLabel: 'Rawat pemain ini',
    );
    if (mounted && id != null) setState(() => _target = id);
  }

  Widget _clinic() {
    final patients = widget.players
        .where((p) => p['out_day'] == null && ((p['strikes'] as int?) ?? 0) > 0)
        .toList();
    final patient =
        patients.where((p) => p['user_id'] == _target).firstOrNull ??
        patients.where((p) => p['user_id'] == widget.repo.myId).firstOrNull ??
        patients.firstOrNull;
    final target = patient?['user_id'] as String?;
    final fee = target != null && target != widget.repo.myId
        ? _number('care_other_fee', 12)
        : 0;
    final trapWaiting = _status?['own_trap_waiting'] == true;
    return _service(
      Icons.local_hospital_outlined,
      widget.isAntag ? 'Titipkan jebakan' : 'Pilih perawatan',
      [
        if (widget.isAntag) ...[
          Center(
            child: VillageChoiceCard(
              option: VillageCardOption(
                id: _letter,
                title: 'Surat Keterangan Sakit',
                path: cardArtPath(widget.defs[_letter]),
                subtitle: '−1 nyawa · satu pengunjung',
              ),
              width: 138,
            ),
          ),
          _gap(),
          _text(
            trapWaiting
                ? 'Jebakanmu menunggu pengunjung'
                : 'Satu surat, satu jebakan',
            size: 20,
            color: trapWaiting ? _accent : EmbunColors.cream,
            weight: FontWeight.w800,
          ),
          const SizedBox(height: 8),
          _text(
            'Tetap terpasang sampai seorang pengunjung lain terkena. Kamu tidak menjadi korban jebakanmu sendiri.',
            size: 13,
            color: Colors.white70,
          ),
        ] else if (patient != null) ...[
          LayoutBuilder(
            builder: (context, box) {
              final cardW = box.maxWidth < 330 ? 105.0 : 128.0;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  VillageChoiceCard(
                    option: VillageCardOption.player(
                      patient,
                      myId: widget.repo.myId,
                    ),
                    width: cardW,
                    selected: true,
                    onTap: _busy || _used
                        ? null
                        : () => _choosePatient(patients, target),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _text(
                          'PENERIMA',
                          size: 10,
                          color: Colors.white60,
                          weight: FontWeight.w800,
                        ),
                        const SizedBox(height: 8),
                        _text(
                          '+1 nyawa',
                          size: 26,
                          color: EmbunColors.leaf,
                          weight: FontWeight.w800,
                        ),
                        const SizedBox(height: 12),
                        _text(
                          fee == 0
                              ? 'Tanpa biaya tambahan'
                              : 'Biaya tambahan $fee',
                          size: 13,
                        ),
                        if (!_used)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _choosePatient(patients, target),
                            child: const Text('Ganti pemain'),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ] else
          _text(
            'Semua pemain yang masih di desa memiliki nyawa penuh.',
            size: 16,
          ),
        _gap(),
        const Divider(color: Color(0x339C8442)),
        const SizedBox(height: 12),
        if (_used) ...[
          _text(
            widget.isAntag ? 'Jebakan terpasang' : 'Perawatan dijadwalkan',
            size: 20,
            color: EmbunColors.leaf,
            weight: FontWeight.w800,
          ),
          const SizedBox(height: 8),
          _text(
            'Hasil diumumkan setelah semua pemain selesai menjelajah.',
            size: 12,
            color: Colors.white70,
          ),
        ] else
          _button(
            widget.isAntag ? 'Pasang jebakan' : 'Konfirmasi perawatan',
            _busy ||
                    _ticket == null ||
                    (!widget.isAntag &&
                        (target == null || widget.balance < fee)) ||
                    (widget.isAntag && trapWaiting)
                ? null
                : () => _act(
                    () => widget.repo.useClinicLetter(
                      widget.gameId,
                      _ticket!['id'] as String,
                      target: widget.isAntag ? null : target,
                    ),
                  ),
          ),
        const SizedBox(height: 10),
        _text(
          'Surat habis saat layanan dikonfirmasi. Pemulihan diselesaikan sebelum jebakan.',
          size: 11,
          color: Colors.white54,
        ),
      ],
    );
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
  Widget _hall() => VillageExchangeView(
    key: ValueKey('hall-${_visit?['id']}'),
    repo: widget.repo,
    gameId: widget.gameId,
    day: widget.day,
    hand: widget.hand,
    defs: widget.defs,
    players: widget.players,
    trades: widget.trades,
    invitationId: _visit?['invitation_id'] as String?,
    jailed: widget.jailed,
    busy: _busy,
    onAction: (task) => _act(() async {
      await task();
      return widget.repo.villageStatus(widget.gameId);
    }),
  );
  void _enterPlace(String place) {
    if (_busy || _waiting) return;
    if (place == 'pondok') {
      setState(() => _clinicGate = true);
      return;
    }
    _act(() => widget.repo.enterVillagePlace(widget.gameId, place));
  }

  Widget _stage(String place, Widget content) => LayoutBuilder(
    builder: (context, box) {
      final side =
          box.maxWidth >= 820 || (box.maxWidth >= 600 && box.maxHeight < 400);
      final broad = place == 'riset' || place == 'bengkel';
      final panel = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xD90B1B16), Color(0xF00B1B16)],
          ),
          border: Border.all(color: _accent.withValues(alpha: .22)),
        ),
        child: Padding(padding: const EdgeInsets.all(14), child: content),
      );
      if (side) {
        final width =
            (box.maxWidth *
                    (broad
                        ? .64
                        : place == 'balai'
                        ? .48
                        : .41))
                .clamp(
                  broad ? 380.0 : 320.0,
                  broad
                      ? 900.0
                      : place == 'balai'
                      ? 620.0
                      : 480.0,
                );
        return Padding(
          padding: EdgeInsets.fromLTRB(
            28,
            12,
            box.maxWidth > 1000 ? 28 : 12,
            8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 22, bottom: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _text(
                          'KUNJUNGAN MALAM',
                          size: 10,
                          color: _accent,
                          weight: FontWeight.w800,
                        ),
                        const SizedBox(height: 10),
                        _text(
                          _places.firstWhere((p) => p.$1 == place).$2,
                          size: box.maxHeight < 300 ? 22 : 34,
                          weight: FontWeight.w800,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: width,
                  height: broad
                      ? null
                      : (place == 'sumur'
                                ? 450.0
                                : place == 'pondok'
                                ? 490.0
                                : 540.0)
                            .clamp(0.0, box.maxHeight - 20),
                  child: panel,
                ),
              ),
            ],
          ),
        );
      }
      final desired = switch (place) {
        'sumur' => 430.0,
        'pondok' => 460.0,
        'balai' => 550.0,
        'riset' => 580.0,
        _ => 560.0,
      };
      final height = desired.clamp(
        0.0,
        (box.maxHeight - 36).clamp(0.0, double.infinity),
      );
      return Column(
        children: [
          const Expanded(child: SizedBox()),
          SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: panel,
            ),
          ),
        ],
      );
    },
  );

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
                  _busy || !allowed ? null : () => _enterPlace(p.$1),
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
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: double.infinity,
                  height: place != null && box.maxWidth < 600
                      ? (box.maxHeight * .46).clamp(220.0, 400.0)
                      : box.maxHeight,
                  child: GameImage(path: bg),
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  EmbunColors.bg.withValues(alpha: .42),
                  EmbunColors.bg.withValues(alpha: place == null ? .22 : .06),
                  EmbunColors.bg.withValues(alpha: .75),
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
                      : _stage(place, _interior(place)),
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
          if (_clinicGate)
            Positioned.fill(
              child: ClinicEntryScene(
                letter:
                    widget.defs[_letter] ??
                    {
                      'id': _letter,
                      'kind': 'perawatan',
                      'side': widget.isAntag ? 'antagonis' : 'warga',
                      'name': widget.isAntag
                          ? 'Surat Keterangan Sakit'
                          : 'Surat Dokter',
                    },
                dark: widget.isAntag,
                onSubmit: () =>
                    widget.repo.enterVillagePlace(widget.gameId, 'pondok'),
                onCancel: () => setState(() => _clinicGate = false),
                onEntered: (status) {
                  if (mounted) {
                    setState(() {
                      _status = status;
                      _clinicGate = false;
                    });
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}
