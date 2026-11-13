import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../../data/server_clock.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import '../common/scene_flow.dart';
import '../common/sfx.dart';
import 'day_view.dart';
import 'research_view.dart';
import 'village_card_picker.dart';
import 'village_exchange_view.dart';
import 'clinic_entry_scene.dart';
import 'village_ambience.dart';

typedef VillageRow = Map<String, dynamic>;

/// Panah hanya memilih tujuan. Jatah dipakai oleh server saat pemain masuk.
///
/// Revisi visual, senada dengan player_sheet / card_tile / countdown:
///  * Ikon medali GameIcon (bukan ikon Material), SectionHeader, NoticeStrip,
///    EmbunButton berikon, panel gelap berbingkai emas redup.
///  * Pemilih tujuan: latar sinematik, judul tempat besar, deretan bidikan
///    tempat bergaya CardTile, satu tombol masuk yang jelas.
///  * Di dalam tempat: adegan memudar masuk dari [kSceneInk]; panel samping
///    memakai OrnatePanel, layar sempit memakai lembar gaya player_sheet.
/// Logika, parameter, dan panggilan repo tidak berubah.
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

class _Place {
  const _Place(
      this.id,
      this.name,
      this.tagline,
      this.outside,
      this.inside,
      this.icon,
      this.tint,
      this.ikon,
      );
  final String id, name, tagline;

  /// Stem `assets/bentang` untuk pemilih (luar) dan di dalam tempat.
  final String outside, inside;

  /// Ikon Material cadangan, dipakai bila ikon medali [ikon] belum ada.
  final IconData icon;

  /// Warna suasana (cahaya di belakang adegan). Sisi Terbisik memakai ungu.
  final Color tint;

  /// Nama ikon medali di assets/ikon. Taruh gambar bernama sama di sana dan
  /// otomatis dipakai menggantikan [icon].
  final String ikon;
}

const _places = [
  _Place(
    'riset',
    'Pasar Riset',
    'Bekal untuk persembahan berikutnya.',
    'pasar-sianghari',
    'pasar-sianghari',
    Icons.auto_stories_outlined,
    Color(0xFFE8C766),
    'store',
  ),
  _Place(
    'sumur',
    'Sumur Desa',
    'Satu sumbangan. Pengaruh sepanjang permainan.',
    'sumur-sianghari',
    'sumur-sianghari',
    Icons.water_drop_outlined,
    Color(0xFF5CC8D6),
    'sumur',
  ),
  _Place(
    'bengkel',
    'Bengkel Desa',
    'Satukan kartu lanjutan dengan kartu poin.',
    'tempat-bengkel',
    'tempatdalam-bengkel',
    Icons.handyman_outlined,
    Color(0xFFE89A4A),
    'bengkel',
  ),
  _Place(
    'pondok',
    'Pondok Perawatan',
    'Sebuah surat membuka layanan pondok.',
    'tempat-pondokperawatan',
    'tempatdalam-pondokperawatan',
    Icons.local_hospital_outlined,
    Color(0xFF7FE0A0),
    'pondok',
  ),
  _Place(
    'balai',
    'Balai Pertukaran',
    'Temui warga lain. Sepakati pertukaran kartu.',
    'tempat-balaitukar',
    'tempatdalam-balaitukar',
    Icons.swap_horiz_rounded,
    Color(0xFFE0A07A),
    'barter',
  ),
];

_Place _placeOf(String id) =>
    _places.firstWhere((p) => p.id == id, orElse: () => _places.last);

/// Bayangan teks supaya judul terbaca di atas gambar apa pun.
const _lift = [
  Shadow(color: Color(0xCC000000), blurRadius: 14, offset: Offset(0, 2)),
];

class _VillageVisitViewState extends State<VillageVisitView> {
  VillageRow? _status;
  String? _error, _target;
  bool _clinicGate = false;
  int _index = 0;
  int _dir = 1; // arah geser terakhir, untuk gerak latar
  bool _entering = false; // menunggu server: kamera mendorong masuk
  int _revision = 0;
  bool _busy = false, _loading = false, _finished = false;
  Timer? _timer;
  Color get _accent => widget.isAntag ? EmbunColors.mist : EmbunColors.gold;
  Color _glow(_Place p) => widget.isAntag ? EmbunColors.mist : p.tint;
  String get _currency => widget.isAntag ? 'bulirhitam' : 'bulirembun';
  bool get _reduced => MediaQuery.disableAnimationsOf(context);
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
    Sfx.I.release(this);
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

  // ---------------------------------------------------------------------
  // Blok bangunan visual (bahasa desain: ornate.dart + player_sheet.dart)
  // ---------------------------------------------------------------------

  Widget _button(
      String label,
      VoidCallback? action, {
        bool secondary = false,
        double height = 52,
        String? icon,
      }) => EmbunButton(
    label: label,
    icon: icon,
    onPressed: action,
    expand: !secondary,
    height: height,
    kind: secondary ? EmbunButtonKind.secondary : EmbunButtonKind.primary,
  );

  Widget _text(
      String text, {
        double size = 14,
        Color? color,
        FontWeight? weight,
        double height = 1.35,
        double? spacing,
        TextAlign? align,
        bool lift = false,
      }) => Text(
    text,
    textAlign: align,
    style: TextStyle(
      fontSize: size,
      height: height,
      color: color ?? EmbunColors.cream,
      fontWeight: weight,
      letterSpacing: spacing,
      shadows: lift ? _lift : null,
    ),
  );

  /// Judul bergaya player_sheet: emas, tebal, sedikit renggang.
  Widget _title(String text, {double size = 24, bool lift = false}) => _text(
    text,
    size: size,
    color: _accent,
    weight: FontWeight.w800,
    spacing: .4,
    height: 1.08,
    lift: lift,
  );

  /// Judul yang muncul dengan jarak huruf merapat dan memudar masuk.
  Widget _titleReveal(String text, {required double size}) =>
      TweenAnimationBuilder<double>(
        key: ValueKey('reveal-$text'),
        tween: Tween(begin: _reduced ? 1.0 : 0.0, end: 1.0),
        duration: const Duration(milliseconds: 750),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Opacity(
          opacity: v.clamp(0.0, 1.0).toDouble(),
          child: Text(
            text,
            style: TextStyle(
              fontSize: size,
              height: 1.08,
              color: _accent,
              fontWeight: FontWeight.w800,
              letterSpacing: .4 + 7 * (1 - v),
              shadows: _lift,
            ),
          ),
        ),
      );

  /// Ikon medali; bila gambarnya belum ada di assets/ikon, ikon Material.
  Widget _icon(String name, IconData fallback, double size) => SizedBox(
    width: size,
    height: size,
    child: ikonPath(name) != null
        ? GameIcon(name, size: size)
        : Icon(fallback, size: size * .8, color: _accent),
  );

  /// Ikon tempat dengan cahaya seperti avatar di player_sheet.
  Widget _placeMedal(_Place p, double size) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: _glow(p).withValues(alpha: .4),
          blurRadius: 18,
          spreadRadius: 1,
        ),
      ],
    ),
    child: _icon(p.ikon, p.icon, size),
  );

  /// Label kecil huruf kapital dengan garis penanda di kirinya.
  Widget _kicker(String text, {Color? color}) {
    final c = color ?? _accent;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 22, height: 2, color: c),
        const SizedBox(width: 8),
        Flexible(
          child: _text(
            text,
            size: 11,
            color: c,
            weight: FontWeight.w800,
            spacing: 2,
            lift: true,
          ),
        ),
      ],
    );
  }

  /// Seperti _countChip di player_sheet.
  Widget _countChip(String text, {Color? color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .4),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: EmbunColors.goldDim.withValues(alpha: .5)),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: color ?? _accent,
      ),
    ),
  );

  /// Seperti _Panel di player_sheet; [highlight] = ringkasan beraksen emas.
  Widget _sub(Widget child, {bool highlight = false}) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: LinearGradient(
        begin: highlight ? Alignment.topLeft : Alignment.topCenter,
        end: highlight ? Alignment.bottomRight : Alignment.bottomCenter,
        colors: highlight
            ? [
          _accent.withValues(alpha: .14),
          Colors.black.withValues(alpha: .25),
        ]
            : [
          Colors.black.withValues(alpha: .36),
          Colors.black.withValues(alpha: .22),
        ],
      ),
      border: Border.all(
        color: highlight
            ? _accent.withValues(alpha: .55)
            : EmbunColors.goldDim.withValues(alpha: .32),
      ),
    ),
    child: child,
  );

  /// Bilah status di kepala layar: kapsul gelap berbingkai, ikon di kiri,
  /// angka tebal (bentuk yang sama dengan Countdown).
  Widget _hud(String icon, String text, Color color) => Container(
    padding: const EdgeInsets.fromLTRB(2, 2, 12, 2),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .4),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: .8)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameIcon(icon, size: 28),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );

  /// Titik jatah kunjungan: terang = masih ada, kosong = sudah terpakai.
  Widget _pips() {
    final limit = _number('limit', 2).toInt().clamp(0, 6).toInt();
    final used = _number('used', 0).toInt();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < limit; i++)
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < used ? Colors.transparent : _accent,
              border: Border.all(
                color: _accent.withValues(alpha: .7),
                width: 1.2,
              ),
            ),
          ),
      ],
    );
  }

  /// Animasi masuk satu kali per kunjungan (kunci = id kunjungan). Mulai
  /// sedikit terlambat supaya adegan sempat memudar masuk dulu.
  Widget _enter(Widget child, {Offset from = Offset.zero, double delay = .3}) =>
      TweenAnimationBuilder<double>(
        key: ValueKey('enter-${_visit?['id']}'),
        tween: Tween(begin: 0.0, end: 1.0),
        duration: _reduced ? Duration.zero : const Duration(milliseconds: 900),
        curve: Interval(delay, 1.0, curve: Curves.easeOutCubic),
        builder: (context, v, child) => Opacity(
          opacity: v.clamp(0.0, 1.0).toDouble(),
          child: Transform.translate(
            offset: Offset(from.dx * (1 - v), from.dy * (1 - v)),
            child: child,
          ),
        ),
        child: child,
      );

  /// Kepala layanan: SectionHeader (ikon medali + judul emas + garis emas
  /// memudar). Bila ikon medali tempat belum ada, ikon Material sebagai ganti.
  Widget _header(_Place p, String title, {Widget? trailing}) {
    final has = ikonPath(p.ikon) != null;
    return SectionHeader(
      icon: has ? p.ikon : null,
      leading: has
          ? null
          : Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(p.icon, size: 26, color: EmbunColors.gold),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: EmbunColors.gold,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
      title: title,
      trailing: trailing,
      iconSize: 30,
    );
  }

  Widget _service(
      _Place p,
      String title,
      List<Widget> children, {
        Widget? trailing,
      }) => ListView(
    padding: const EdgeInsets.fromLTRB(2, 0, 2, 16),
    children: [_header(p, title, trailing: trailing), const SizedBox(height: 16), ...children],
  );
  Widget _gap() => const SizedBox(height: 14);

  /// Pita keberhasilan setelah tindakan tercatat.
  Widget _done(String title, [String? note]) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: EmbunColors.leaf.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: EmbunColors.leaf.withValues(alpha: .6)),
    ),
    child: Row(
      children: [
        const GameIcon('centang', size: 30),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _text(
                title,
                size: 16,
                color: EmbunColors.leaf,
                weight: FontWeight.w800,
              ),
              if (note != null) ...[
                const SizedBox(height: 4),
                _text(note, size: 12, color: Colors.white70),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  // ---------------------------------------------------------------------
  // Sumur: pengukur laju bersama
  // ---------------------------------------------------------------------

  Widget _gauge(num bonus, num next, num cap) => LayoutBuilder(
    builder: (context, box) {
      final w = box.maxWidth;
      double pos(num v) =>
          ((v + cap) / (2 * cap)).clamp(0.0, 1.0).toDouble() * w;
      final fill = bonus < 0 ? EmbunColors.blood : EmbunColors.leaf;
      final start = bonus < 0 ? pos(bonus) : pos(0);
      final span = (pos(bonus) - pos(0)).abs();
      const dur = Duration(milliseconds: 600);
      return SizedBox(
        height: 54,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 20,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: dur,
              curve: Curves.easeOutCubic,
              left: start,
              width: span,
              top: 20,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: fill.withValues(alpha: .5),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: w / 2 - .5,
              top: 14,
              child: Container(width: 1, height: 20, color: Colors.white38),
            ),
            AnimatedPositioned(
              duration: dur,
              curve: Curves.easeOutCubic,
              left: pos(next) - 7,
              top: 17,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _accent, width: 1.5),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: dur,
              curve: Curves.easeOutCubic,
              left: pos(bonus) - 9,
              top: 15,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fill,
                  border: Border.all(color: EmbunColors.cream, width: 2),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 38,
              child: _text(_signed(-cap), size: 11, color: Colors.white54),
            ),
            Positioned(
              right: 0,
              top: 38,
              child: _text(_signed(cap), size: 11, color: Colors.white54),
            ),
          ],
        ),
      );
    },
  );

  Widget _well() {
    final bonus = _number('well_bonus', 0),
        step = _number('well_step', .15),
        cap = _number('well_cap', 1.5),
        cost = _number('well_cost', 8);
    final next = (bonus + (widget.isAntag ? -step : step)).clamp(-cap, cap);
    final capped = widget.isAntag ? bonus <= -cap : bonus >= cap;
    return _service(
      _placeOf('sumur'),
      widget.isAntag ? 'Cemari sumur' : 'Rawat sumur desa',
      trailing: _used ? _countChip('Tercatat', color: EmbunColors.leaf) : null,
      [
        _sub(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _text(
                'LAJU BERSAMA',
                size: 10,
                color: Colors.white60,
                weight: FontWeight.w800,
                spacing: 1.8,
              ),
              _text(
                _signed(bonus),
                size: 52,
                height: 1.1,
                color: bonus < 0 ? EmbunColors.blood : EmbunColors.leaf,
                weight: FontWeight.w800,
              ),
              _text(
                'embun / bulir hitam per hari',
                size: 12,
                color: Colors.white70,
              ),
              const SizedBox(height: 12),
              _gauge(bonus, next, cap),
            ],
          ),
        ),
        _gap(),
        _sub(
          highlight: true,
          Row(
            children: [
              Icon(
                widget.isAntag ? Icons.trending_down : Icons.trending_up,
                color: _accent,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _text('Setelah tindakanmu', size: 12, color: Colors.white60),
                    _title('${_signed(next)} / hari'),
                  ],
                ),
              ),
              if (!capped) _countChip(_signed(next - bonus)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const NoticeStrip(
          icon: 'info',
          text:
          'Efek menetap hingga gim berakhir, untuk seluruh pemain dan kedua fraksi.',
        ),
        _gap(),
        if (_used)
          _done('Sumbangan tercatat')
        else
          _button(
            capped
                ? 'Batas sumur tercapai'
                : '${widget.isAntag ? 'Cemari' : 'Sumbangkan'} · $cost',
            _busy || capped || widget.balance < cost
                ? null
                : () => _act(() => widget.repo.contributeWell(widget.gameId)),
            icon: capped ? null : _currency,
          ),
        const SizedBox(height: 10),
        _text(
          'Batas ${_signed(-cap)} hingga ${_signed(cap)} · 1 tindakan per kunjungan',
          size: 11,
          color: Colors.white54,
          align: TextAlign.center,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Pondok perawatan
  // ---------------------------------------------------------------------

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
      _placeOf('pondok'),
      widget.isAntag ? 'Titipkan jebakan' : 'Pilih perawatan',
      trailing: _used ? _countChip('Tercatat', color: EmbunColors.leaf) : null,
      [
        if (widget.isAntag) ...[
          _sub(
            highlight: true,
            Column(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withValues(alpha: .4),
                        blurRadius: 26,
                      ),
                    ],
                  ),
                  child: VillageChoiceCard(
                    option: VillageCardOption(
                      id: _letter,
                      title: 'Surat Keterangan Sakit',
                      path: cardArtPath(widget.defs[_letter]),
                      subtitle: '−1 nyawa · satu pengunjung',
                    ),
                    width: 150,
                  ),
                ),
                const SizedBox(height: 12),
                _title(
                  trapWaiting
                      ? 'Jebakanmu menunggu pengunjung'
                      : 'Satu surat, satu jebakan',
                  size: 18,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const NoticeStrip(
            icon: 'alert',
            text:
            'Tetap terpasang sampai seorang pengunjung lain terkena. Kamu tidak menjadi korban jebakanmu sendiri.',
          ),
        ] else if (patient != null) ...[
          _sub(
            highlight: true,
            LayoutBuilder(
              builder: (context, box) {
                final cardW = box.maxWidth < 320 ? 104.0 : 128.0;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: EmbunColors.leaf.withValues(alpha: .28),
                            blurRadius: 26,
                          ),
                        ],
                      ),
                      child: VillageChoiceCard(
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
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _text(
                            'PENERIMA',
                            size: 10,
                            color: Colors.white60,
                            weight: FontWeight.w800,
                            spacing: 1.8,
                          ),
                          const SizedBox(height: 4),
                          _text(
                            '+1 nyawa',
                            size: 28,
                            height: 1.1,
                            color: EmbunColors.leaf,
                            weight: FontWeight.w800,
                          ),
                          const SizedBox(height: 10),
                          _countChip(
                            fee == 0
                                ? 'Tanpa biaya tambahan'
                                : 'Biaya tambahan $fee',
                            color: fee == 0 ? EmbunColors.leaf : _accent,
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
          ),
        ] else
          _sub(
            _text(
              'Semua pemain yang masih di desa memiliki nyawa penuh.',
              size: 15,
            ),
          ),
        _gap(),
        if (_used)
          _done(
            widget.isAntag ? 'Jebakan terpasang' : 'Perawatan dijadwalkan',
            'Hasil diumumkan setelah semua pemain selesai menjelajah.',
          )
        else
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
            icon: 'centang',
          ),
        const SizedBox(height: 4),
        const NoticeStrip(
          icon: 'info',
          text:
          'Surat habis saat layanan dikonfirmasi. Pemulihan diselesaikan sebelum jebakan.',
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
    // Kamera mendorong masuk selagi server memproses; begitu status tiba,
    // adegan dalam membuka lewat IrisReveal.
    setState(() => _entering = true);
    _act(() => widget.repo.enterVillagePlace(widget.gameId, place)).then((ok) {
      if (!mounted) return;
      setState(() => _entering = false);
      if (ok) {
        Sfx.I.playAny(
          place == 'bengkel' ? Snd.fires : Snd.winds,
          owner: this,
          tag: 'enter',
          replace: true,
        );
      }
    });
  }

  // ---------------------------------------------------------------------
  // Di dalam tempat: panggung
  // ---------------------------------------------------------------------

  /// Judul tempat sebagai pusat visual adegan.
  Widget _hero(_Place p, {required bool compact, bool tall = true}) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (!compact && tall) ...[
        _placeMedal(p, 64),
        const SizedBox(height: 16),
      ],
      _kicker('KUNJUNGAN MALAM'),
      SizedBox(height: compact ? 6 : 12),
      _title(
        p.name,
        size: compact
            ? 30
            : tall
            ? 46
            : 30,
        lift: true,
      ),
      if (!compact) ...[
        const SizedBox(height: 12),
        GildedDivider(color: _accent, width: 200),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: _text(p.tagline, size: 17, lift: true),
        ),
      ],
    ],
  );

  /// Lembar dari bawah untuk layar sempit, mengikuti player_sheet: gradien
  /// gelap, sudut atas 26, bingkai emas redup, cahaya ke atas, pegangan.
  Widget _sheet(Widget content) => Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [EmbunColors.panelHi, EmbunColors.panel],
      ),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      border: Border.all(
        color: (widget.isAntag ? EmbunColors.mist : EmbunColors.goldDim)
            .withValues(alpha: .55),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: _accent.withValues(alpha: .16),
          blurRadius: 28,
          offset: const Offset(0, -6),
        ),
      ],
    ),
    child: Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 44,
          height: 4,
          decoration: BoxDecoration(
            color: EmbunColors.goldDim.withValues(alpha: .7),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: content,
          ),
        ),
      ],
    ),
  );

  Widget _stage(_Place p, Widget content) => LayoutBuilder(
    builder: (context, box) {
      final side =
          box.maxWidth >= 820 || (box.maxWidth >= 600 && box.maxHeight < 400);
      final broad = p.id == 'riset' || p.id == 'bengkel';
      if (side) {
        final width =
        (box.maxWidth *
            (broad
                ? .64
                : p.id == 'balai'
                ? .48
                : .41))
            .clamp(
          broad ? 380.0 : 320.0,
          broad
              ? 900.0
              : p.id == 'balai'
              ? 620.0
              : 480.0,
        )
            .toDouble();
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
                child: _enter(
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 22, bottom: 28),
                      child: _hero(p, compact: false, tall: box.maxHeight >= 300),
                    ),
                  ),
                  from: const Offset(-24, 0),
                  delay: .2,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: _enter(
                  SizedBox(
                    width: width,
                    height: broad
                        ? null
                        : (p.id == 'sumur'
                        ? 470.0
                        : p.id == 'pondok'
                        ? 510.0
                        : 540.0)
                        .clamp(0.0, box.maxHeight - 20)
                        .toDouble(),
                    child: OrnatePanel(
                      accent: _accent,
                      radius: 22,
                      opacity: .95,
                      padding: const EdgeInsets.all(14),
                      child: content,
                    ),
                  ),
                  from: const Offset(48, 0),
                ),
              ),
            ],
          ),
        );
      }
      final desired = switch (p.id) {
        'sumur' => 500.0,
        'pondok' => 520.0,
        'balai' => 550.0,
        'riset' => 580.0,
        _ => 560.0,
      };
      final height = desired
          .clamp(0.0, (box.maxHeight - 36).clamp(0.0, double.infinity))
          .toDouble();
      return Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => c.maxHeight < 96
                  ? const SizedBox.shrink()
                  : _enter(
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: _hero(p, compact: true),
                  ),
                ),
                from: const Offset(0, 14),
                delay: .2,
              ),
            ),
          ),
          _enter(
            SizedBox(
              height: height,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 580),
                  child: _sheet(content),
                ),
              ),
            ),
            from: const Offset(0, 64),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_accent.withValues(alpha: .16), EmbunColors.panel],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: .6)),
        boxShadow: [
          BoxShadow(color: _accent.withValues(alpha: .18), blurRadius: 16),
        ],
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        children: [
          const GameIcon('barter', size: 30),
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
    );
  }

  // ---------------------------------------------------------------------
  // Pemilih tujuan
  // ---------------------------------------------------------------------

  void _select(int i, {int? dir}) {
    if (i == _index) return;
    Sfx.I.click(Snd.click2);
    setState(() {
      _dir = dir ?? (i > _index ? 1 : -1);
      _index = i;
    });
  }

  void _step(int d) =>
      _select((_index + d + _places.length) % _places.length, dir: d);

  /// Bidikan tempat, bergaya CardTile: yang terpilih terangkat, berbingkai
  /// emas tebal dan berdenyut; yang terkunci tampak kelabu.
  Widget _rail({required bool short}) => SizedBox(
    height: short ? 58 : 104,
    child: Row(
      children: [
        for (var i = 0; i < _places.length; i++)
          Expanded(child: _railItem(i, short)),
      ],
    ),
  );

  static const _grayscale = ColorFilter.matrix(<double>[
    .2126, .7152, .0722, 0, 0, //
    .2126, .7152, .0722, 0, 0,
    .2126, .7152, .0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  Widget _railItem(int i, bool short) {
    final p = _places[i];
    final sel = i == _index;
    final locked = p.id == 'pondok' && _ticket == null;
    final art = firstScenery([p.outside, 'pasar-sianghari']);
    final dur = _reduced ? Duration.zero : const Duration(milliseconds: 180);
    Widget image = GameImage(path: art, cacheWidth: 240);
    if (locked) image = ColorFiltered(colorFilter: _grayscale, child: image);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Semantics(
        button: true,
        selected: sel,
        label: locked ? '${p.name}, perlu surat perawatan' : p.name,
        child: Tooltip(
          message: p.name,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _select(i),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: AnimatedContainer(
                        duration: dur,
                        curve: Curves.easeOutCubic,
                        transform: Matrix4.translationValues(0, sel ? -6 : 0, 0),
                        child: PulsingGlow(
                          active: sel,
                          color: _accent,
                          child: AnimatedContainer(
                            duration: dur,
                            curve: Curves.easeOutCubic,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F3A33),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: sel
                                    ? _accent
                                    : EmbunColors.goldDim.withValues(alpha: .6),
                                width: sel ? 2.6 : 1.2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Opacity(
                                opacity: sel ? 1 : .7,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    image,
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            EmbunColors.bg.withValues(alpha: .85),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 3),
                                        child: _icon(p.ikon, p.icon, 22),
                                      ),
                                    ),
                                    if (locked)
                                      const Align(
                                        alignment: Alignment.topRight,
                                        child: Padding(
                                          padding: EdgeInsets.all(3),
                                          child: GameIcon('lock', size: 18),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!short)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.5,
                        letterSpacing: .3,
                        fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                        color: sel ? _accent : Colors.white54,
                        shadows: _lift,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Syarat masuk sebagai NoticeStrip di atas alas gelap supaya terbaca di
  /// atas gambar.
  Widget? _requirement(_Place p) {
    if (p.id != 'pondok') return null;
    final ok = _ticket != null;
    final name = widget.isAntag ? 'Surat Keterangan Sakit' : 'Surat Dokter';
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: NoticeStrip(
          icon: ok ? 'centang' : 'lock',
          text: ok ? '$name siap dipakai' : 'Butuh $name untuk masuk',
          accent: ok ? EmbunColors.leaf : EmbunColors.blood,
        ),
      ),
    );
  }

  String _description(_Place p) => switch (p.id) {
    'riset' => 'Poin, kartu lanjutan, dan surat perawatan. Harga riset +20%.',
    'sumur' =>
    widget.isAntag
        ? 'Cemari sumur untuk menghambat laju seluruh desa.'
        : 'Sumbangkan embun untuk menaikkan laju seluruh desa.',
    'bengkel' =>
    'Pilih kartu lanjutan dan kartu poin. Penggabungan mengaktifkan kartu.',
    'pondok' =>
    widget.isAntag
        ? 'Pasang jebakan yang menetap sampai terpicu.'
        : 'Rawat diri, atau bayar tambahan untuk merawat pemain lain.',
    _ =>
    'Tawarkan kartu dan jawab undangan. Penerima undangan boleh datang tanpa memakai jatah.',
  };

  Widget _pickerCopy(_Place p, {required bool short, required bool wide}) {
    final req = _requirement(p);
    return Column(
      key: ValueKey(p.id),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _kicker(
          'JELAJAH DESA  ·  ${(_index + 1).toString().padLeft(2, '0')} / ${_places.length.toString().padLeft(2, '0')}',
        ),
        SizedBox(height: short ? 8 : 16),
        if (!short) ...[_placeMedal(p, 68), const SizedBox(height: 14)],
        _titleReveal(
          p.name,
          size: short
              ? 30
              : wide
              ? 56
              : 42,
        ),
        if (!short) ...[
          const SizedBox(height: 10),
          GildedDivider(color: _accent, width: 200),
        ],
        SizedBox(height: short ? 6 : 10),
        _text(p.tagline, size: short ? 15 : 18, lift: true),
        if (!short) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: _accent, width: 2)),
            ),
            child: _text(
              _description(p),
              size: 14,
              color: Colors.white70,
              lift: true,
            ),
          ),
        ],
        if (req != null) ...[SizedBox(height: short ? 6 : 12), req],
      ],
    );
  }

  Widget _picker(bool wide) {
    final p = _places[_index];
    final left = (_number('limit', 2) - _number('used', 0))
        .clamp(0, 99)
        .toInt();
    final needLetter = p.id == 'pondok' && _ticket == null;
    final allowed = left > 0 && !needLetter;
    return LayoutBuilder(
      builder: (context, box) {
        final short = box.maxHeight < 360;
        final pad = wide ? 48.0 : 20.0;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v <= -250) {
              _step(1);
            } else if (v >= 250) {
              _step(-1);
            }
          },
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, short ? 4 : 12, pad, 6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) => SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: c.maxHeight),
                            child: Align(
                              alignment: wide
                                  ? Alignment.centerLeft
                                  : Alignment.bottomLeft,
                              child: AnimatedSwitcher(
                                duration: _reduced
                                    ? Duration.zero
                                    : const Duration(milliseconds: 320),
                                layoutBuilder: (current, previous) => Stack(
                                  alignment: wide
                                      ? Alignment.centerLeft
                                      : Alignment.bottomLeft,
                                  children: [...previous, ?current],
                                ),
                                transitionBuilder: (child, anim) =>
                                    FadeTransition(
                                      opacity: anim,
                                      child: SlideTransition(
                                        position: Tween(
                                          begin: const Offset(0, .05),
                                          end: Offset.zero,
                                        ).animate(anim),
                                        child: child,
                                      ),
                                    ),
                                child: _pickerCopy(
                                  p,
                                  short: short,
                                  wide: wide,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: short ? 8 : 14),
                    _rail(short: short),
                    SizedBox(height: short ? 8 : 14),
                    EmbunButton(
                      label: left == 0
                          ? 'Jatah kunjungan habis'
                          : needLetter
                          ? 'Perlu surat perawatan'
                          : 'Masuk ke ${p.name}',
                      expand: true,
                      onPressed: _busy || !allowed
                          ? null
                          : () => _enterPlace(p.id),
                    ),
                    const SizedBox(height: 8),
                    _text(
                      left == 0
                          ? 'Tidak ada kunjungan tersisa malam ini.'
                          : 'Masuk memakai 1 dari $left kunjungan tersisa · Ketuk atau geser untuk memilih tujuan',
                      size: 11.5,
                      color: Colors.white70,
                      lift: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _waitingView() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: OrnatePanel(
          accent: _accent,
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GameIcon('wait', size: 68),
              const SizedBox(height: 14),
              _title('Kunjungan selesai', size: 24),
              const SizedBox(height: 8),
              _text(
                'Menunggu ${widget.readyCount}/${widget.total} pemain. Hasil pondok dan persembahan menyusul.',
                size: 14,
                color: Colors.white70,
                align: TextAlign.center,
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: widget.total > 0
                      ? (widget.readyCount / widget.total).clamp(0.0, 1.0)
                      : null,
                  minHeight: 6,
                  color: _accent,
                  backgroundColor: Colors.white12,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final current = _visit, place = current?['place'] as String?;
    final selected = place == null ? _places[_index] : _placeOf(place);
    final seconds = widget.deadline
        ?.difference(ServerClock.now())
        .inSeconds
        .clamp(0, 9999);
    final bg = firstScenery([
      place == null ? selected.outside : selected.inside,
      'pasar-sianghari',
      'sumur-sianghari',
    ]);
    final glow = _glow(selected);
    final reduced = _reduced;
    return LayoutBuilder(
      builder: (context, box) => Stack(
        fit: StackFit.expand,
        children: [
          // Latar sinematik: Ken Burns (tak pernah di bawah kBentangZoom),
          // bergeser sesuai arah geser, dan mendorong masuk saat Masuk ditekan.
          PlaceBackdrop(
            path: bg,
            height: place != null && box.maxWidth < 600
                ? (box.maxHeight * .46).clamp(220.0, 400.0).toDouble()
                : null,
            inside: place != null,
            pushIn: _entering,
            dir: _dir,
            reduced: reduced,
          ),
          // Peredam warna seperti Backdrop: ungu gelap untuk Si Terbisik.
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color:
                (widget.isAntag
                    ? const Color(0xFF1A1030)
                    : const Color(0xFF07130F))
                    .withValues(alpha: place == null ? .38 : .5),
              ),
            ),
          ),
          // Cahaya suasana menurut tempat.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: reduced
                    ? Duration.zero
                    : const Duration(milliseconds: 500),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-.55, -.25),
                    radius: 1.0,
                    colors: [glow.withValues(alpha: .16), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          // Berkas cahaya, partikel khas tempat, dan vinyet.
          Positioned.fill(
            child: PlaceAmbience(
              key: ValueKey('amb-${selected.id}-${place != null}'),
              kind: ambienceFor(selected.id),
              tint: glow,
              dark: widget.isAntag,
              inside: place != null,
            ),
          ),
          // Kilau menyapu tiap kali tujuan berganti.
          if (place == null)
            Positioned.fill(
              child: SweepGlint(
                key: ValueKey('glint-$_index'),
                tint: glow,
                dir: _dir,
              ),
            ),
          // Gradien atas-bawah yang sama dengan meja siang (table_page).
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, .45, 1],
                    colors: [
                      const Color(0x60102018),
                      const Color(0x00102018),
                      EmbunColors.bg.withValues(alpha: place == null ? .94 : .86),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Adegan memudar masuk dari tinta. Di pemilih: pemudaran biasa.
          // Di dalam tempat: lubang cahaya membuka dari tengah.
          if (place == null)
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                key: ValueKey('veil-pilih-${current?['id']}'),
                tween: Tween(begin: 1.0, end: 0.0),
                duration: reduced
                    ? Duration.zero
                    : const Duration(milliseconds: kSceneFadeInMs + 150),
                curve: Curves.easeOut,
                builder: (context, a, _) => sceneVeil(a),
              ),
            )
          else
            Positioned.fill(
              child: IrisReveal(
                key: ValueKey('iris-$place-${current?['id']}'),
                accent: glow,
                reduced: reduced,
                center: const Alignment(0, .05),
              ),
            ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 16, 6),
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
                            )
                          else
                            const SizedBox(width: 4),
                          Flexible(
                            child: _text(
                              place == null
                                  ? 'Malam sebelum persembahan'
                                  : 'Kembali ke desa',
                              size: 13,
                              color: Colors.white70,
                              weight: FontWeight.w700,
                              spacing: .4,
                              lift: true,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _hud(
                            _currency,
                            widget.balance
                                .toStringAsFixed(1)
                                .replaceAll('.', ','),
                            EmbunColors.cream,
                          ),
                          if (seconds != null) ...[
                            const SizedBox(width: 8),
                            _hud(
                              'timer',
                              '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                              seconds <= 10 ? EmbunColors.blood : _accent,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                    padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
                    decoration: BoxDecoration(
                      color: EmbunColors.blood.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: EmbunColors.blood.withValues(alpha: .6),
                      ),
                    ),
                    child: Row(
                      children: [
                        const GameIcon('alert', size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: EmbunColors.blood,
                              fontSize: 12.5,
                              height: 1.3,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Coba lagi',
                          onPressed: _busy ? null : _load,
                          icon: const GameIcon('refresh', size: 22),
                        ),
                      ],
                    ),
                  ),
                _invitations(),
                Expanded(
                  child: _waiting
                      ? _waitingView()
                      : _status == null
                      ? const Center(child: CircularProgressIndicator())
                      : place == null
                      ? _picker(box.maxWidth > 760)
                      : _stage(_placeOf(place), _interior(place)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 8,
                    spacing: 18,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _pips(),
                          const SizedBox(width: 6),
                          _text(
                            'Kunjungan ${_number('used', 0)}/${_number('limit', 2)} · Hari ${widget.day}',
                            size: 12,
                            color: Colors.white70,
                            lift: true,
                          ),
                        ],
                      ),
                      if (!_waiting)
                        _button(
                          'Selesai menjelajah',
                          _busy ? null : _finish,
                          secondary: true,
                          height: 44,
                          icon: 'endday',
                        ),
                    ],
                  ),
                ),
                if (_busy) const LinearProgressIndicator(minHeight: 2),
              ],
            ),
          ),
          if (place != null && !_waiting)
            Positioned.fill(
              child: PlaceTitleCard(
                key: ValueKey('title-$place-${current?['id']}'),
                kicker: 'MEMASUKI',
                title: selected.name,
                accent: _accent,
                reduced: reduced,
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