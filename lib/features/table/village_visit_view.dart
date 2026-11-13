import 'dart:async';
import 'dart:math' as math;
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
  Object? _actedVisit; // id kunjungan yang sudah ada tindakannya (pose selesai)
  Object? _collapsedVisit; // kunjungan yang panel layanannya diturunkan pemain
  int _revision = 0;
  bool _busy = false, _loading = false, _finished = false;
  Timer? _timer;
  final ScrollController _phoneRailScroll = ScrollController();
  Color get _accent => widget.isAntag ? EmbunColors.mist : EmbunColors.gold;
  Color _glow(_Place p) => widget.isAntag ? EmbunColors.mist : p.tint;
  String get _currency => widget.isAntag ? 'bulirhitam' : 'bulirembun';
  bool get _reduced => MediaQuery.disableAnimationsOf(context);
  VillageRow? get _visit => _status?['current'] is Map
      ? Map<String, dynamic>.from(_status!['current'])
      : null;
  bool get _waiting => widget.iAmReady || _finished;

  /// Panel layanan di layar sempit: terbuka tiap kali masuk tempat baru.
  /// Diturunkan pemain supaya karakter dan latar terlihat penuh.
  bool get _sheetOpen =>
      _collapsedVisit == null || _collapsedVisit != _visit?['id'];

  void _toggleSheet() {
    final id = _visit?['id'];
    if (id == null) return;
    Sfx.I.click(Snd.click2);
    setState(() => _collapsedVisit = _sheetOpen ? id : null);
  }

  bool get _used => _visit?['action_used'] == true;
  bool get _free => _visit?['invitation_id'] != null;
  String get _letter => widget.isAntag ? 'surat_sakit' : 'surat_dokter';

  /// Tindakan sudah tercatat di kunjungan ini: karakter berpose "selesai".
  bool get _acted {
    final id = _visit?['id'];
    return _used || (id != null && id == _actedVisit);
  }

  void _markActed() {
    final id = _visit?['id'];
    if (!mounted || id == null || id == _actedVisit) return;
    setState(() => _actedVisit = id);
  }

  /// Pose karakter warga: tanya (menyambut) -> periksa (pondok, pasien sudah
  /// dipilih) -> selesai (tindakan tercatat).
  String _moodOf(String place) {
    if (_acted) return 'selesai';
    if (place == 'pondok' && !widget.isAntag && _target != null) {
      return 'periksa';
    }
    return 'tanya';
  }

  String? _popup(String place, String mood) =>
      popupCharPath(antag: widget.isAntag, place: place, mood: mood);

  String get _speaker => widget.isAntag ? 'SI TERBISIK' : 'WARGA DESA';

  /// Kalimat singkat karakter menurut tempat dan pose. Ubah teksnya di sini.
  String? _voiceOf(String place, String mood) {
    if (widget.isAntag) {
      if (_acted) return 'Sudah terlaksana. Kini… menunggulah.';
      return switch (place) {
        'riset' => 'Ssst… setiap ilmu ada harganya. Mau membeli apa malam ini?',
        'sumur' => 'Setetes saja, dan seluruh desa ikut meminumnya.',
        'bengkel' =>
        'Satukan, retakkan. Tak ada yang benar-benar utuh di sini.',
        'pondok' =>
        'Titipkan satu surat. Biar lukanya menunggu pengunjung berikutnya.',
        _ => null,
      };
    }
    return switch ((place, mood)) {
      ('riset', 'selesai') =>
      'Bekalmu sudah di tangan. Semoga cukup untuk persembahan nanti.',
      ('riset', _) =>
      'Persembahan sudah dekat. Pilih bekalmu baik-baik, tiap bulir berharga.',
      ('sumur', 'selesai') =>
      'Terima kasih. Airnya terasa lebih tenang sekarang.',
      ('sumur', _) =>
      'Air sumur ini menghidupi seluruh desa. Satu sumbangan, pengaruhnya sampai akhir.',
      ('bengkel', 'selesai') => 'Sudah menyatu. Hasilnya bagus.',
      ('bengkel', _) =>
      'Kartu lanjutan butuh kartu poin. Satukan keduanya, biar menyala.',
      ('pondok', 'selesai') =>
      'Beres. Perawatan dijadwalkan; hasilnya diumumkan nanti.',
      ('pondok', 'periksa') => 'Tahan sebentar. Biar kuperiksa dulu lukanya.',
      ('pondok', _) => 'Serahkan suratmu, lalu pilih siapa yang kurawat.',
      (_, 'selesai') => 'Pertukaran tercatat. Senang berurusan denganmu.',
      _ => 'Ada yang ingin bertukar? Tawarkan kartumu, atau jawab undangan.',
    };
  }

  Widget _voiceBubble(String place, {String? mood, double maxWidth = 380}) {
    final line = _voiceOf(place, mood ?? _moodOf(place));
    if (line == null) return const SizedBox.shrink();
    return PlaceVoice(
      speaker: _speaker,
      line: line,
      accent: _accent,
      reduced: _reduced,
      maxWidth: maxWidth,
    );
  }

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
    _phoneRailScroll.dispose();
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
      final visitBefore = _visit?['id'];
      final next = await action();
      if (mounted) {
        setState(() {
          _status = next;
          if (visitBefore != null) _actedVisit = visitBefore;
        });
      }
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
    children: [
      _header(p, title, trailing: trailing),
      const SizedBox(height: 16),
      ...children,
    ],
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
                    _text(
                      'Setelah tindakanmu',
                      size: 12,
                      color: Colors.white60,
                    ),
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
    onHandChanged: () {
      _markActed();
      widget.onHandChanged?.call();
    },
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
  Widget _hero(
      _Place p, {
        required bool compact,
        bool tall = true,
        bool voice = false,
      }) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (!compact && tall) ...[_placeMedal(p, 64), const SizedBox(height: 16)],
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
        if (voice) ...[const SizedBox(height: 16), _voiceBubble(p.id)],
      ],
    ],
  );

  /// Lembar dari bawah untuk layar sempit, mengikuti player_sheet: gradien
  /// gelap, sudut atas 26, bingkai emas redup, cahaya ke atas. Pegangannya
  /// bisa diketuk atau diseret untuk menurunkan panel (karakter dan latar
  /// jadi tontonan penuh) lalu membukanya lagi.
  Widget _sheet(
      Widget content, {
        required bool open,
        required double expandedHeight,
      }) => ClipRRect(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [EmbunColors.panelHi, EmbunColors.panel],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border.all(color: _accent.withValues(alpha: .40)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 48,
            left: 0,
            right: 0,
            height: math.max(0, expandedHeight - 48),
            child: Offstage(
              offstage: !open,
              child: TickerMode(
                enabled: open,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: content,
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 48,
            child: Semantics(
              button: true,
              label: open ? 'Turunkan panel layanan' : 'Buka panel layanan',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleSheet,
                onVerticalDragEnd: (d) {
                  final velocity = d.primaryVelocity ?? 0;
                  if ((velocity > 200 && open) || (velocity < -200 && !open)) {
                    _toggleSheet();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 3,
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: .6),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          open ? 'Layanan' : 'Buka layanan',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        open ? 'Lihat latar' : 'Lanjutkan',
                        style: TextStyle(fontSize: 11, color: _accent),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        open
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                        size: 20,
                        color: _accent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _stage(_Place p, Widget content) => LayoutBuilder(
    builder: (context, box) {
      final side =
          box.maxWidth >= 700 || (box.maxWidth >= 600 && box.maxHeight < 400);
      final broad = p.id == 'riset' || p.id == 'bengkel';
      if (!side) return _stageCompact(p, content, box);
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
        padding: EdgeInsets.fromLTRB(28, 12, box.maxWidth > 1000 ? 28 : 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final art = c.maxWidth >= 200
                      ? _popup(p.id, _moodOf(p.id))
                      : null;
                  // Karakter besar berdiri di kiri, sejajar tepi bawah.
                  final h = c.maxHeight * 1.0;
                  final w = math.min(c.maxWidth * .92, h * .9);
                  // Ucapan muncul di sisi kanan kepala bila ada ruang.
                  final voiceLeft = w * .78;
                  final voiceRoom = c.maxWidth - voiceLeft - 8;
                  final showVoice =
                      art != null && voiceRoom >= 220 && c.maxHeight >= 360;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (art != null)
                        Positioned(
                          left: -w * .04,
                          bottom: 0,
                          width: w,
                          height: h,
                          child: _enter(
                            PopupCharacter(
                              path: art,
                              tint: _glow(p),
                              intro: false,
                              reduced: _reduced,
                            ),
                            from: const Offset(-60, 0),
                            delay: .45,
                          ),
                        ),
                      if (showVoice)
                        Positioned(
                          left: voiceLeft,
                          top: 28,
                          child: _enter(
                            _voiceBubble(
                              p.id,
                              maxWidth: math.min(voiceRoom, 340.0),
                            ),
                            from: const Offset(24, 0),
                            delay: .8,
                          ),
                        ),
                      // Papan nama di kaki karakter.
                      Positioned(
                        left: 4,
                        right: 12,
                        bottom: 10,
                        child: _enter(
                          _hero(p, compact: true),
                          from: const Offset(0, 16),
                          delay: .25,
                        ),
                      ),
                    ],
                  );
                },
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
    },
  );

  /// Layar sempit: karakter berdiri di kiri di atas lembar layanan, papan nama
  /// di sebelah kanannya. Lembar dapat diturunkan sehingga karakter tampil
  /// hampir seluruh badan (dan papan nama pindah ke kakinya).
  /// Di ponsel karakter, judul, dan layanan memiliki ruang masing-masing.
  /// Isi layanan tetap mendapat tinggi penuh ketika panel disembunyikan,
  /// sehingga pilihan kartu tidak ter-reset dan tidak meluap saat animasi.
  Widget _stageCompact(_Place p, Widget content, BoxConstraints box) {
    final open = _sheetOpen;
    final height = box.maxHeight;
    final heroHeight = height < 300
        ? 0.0
        : height < 400
        ? 58.0
        : (height * .23).clamp(90.0, 164.0);
    final fullPanelHeight = math.max(56.0, height - heroHeight);
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!open || heroHeight > 0)
          Expanded(
            child: LayoutBuilder(
              builder: (context, heroBox) {
                final tiny = heroBox.maxHeight < 90;
                final art = _phonePopup(p.id, _moodOf(p.id));
                final text = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      maxLines: tiny ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: tiny ? 18 : 23,
                        height: 1.08,
                        fontWeight: FontWeight.w800,
                        color: _accent,
                        shadows: _lift,
                      ),
                    ),
                    if (!tiny && heroBox.maxHeight > 115 * scale) ...[
                      const SizedBox(height: 8),
                      Text(
                        _voiceOf(p.id, _moodOf(p.id)) ?? p.tagline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.3,
                          color: EmbunColors.cream,
                          shadows: _lift,
                        ),
                      ),
                    ],
                  ],
                );
                if (!open && art != null) {
                  return Column(
                    children: [
                      Expanded(
                        child: _phonePortrait(
                          p,
                          _moodOf(p.id),
                          height: heroBox.maxHeight,
                          width: math.min(box.maxWidth * .88, 460.0),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: text,
                      ),
                    ],
                  );
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (art != null && !tiny) ...[
                        _phonePortrait(
                          p,
                          _moodOf(p.id),
                          height: heroBox.maxHeight,
                          width: (box.maxWidth * .46).clamp(136.0, 230.0),
                          zoom: 1.18,
                        ),
                        const SizedBox(width: 12),
                      ] else if (tiny) ...[
                        _placeMedal(p, 28),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: text,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: math.max(0.0, height - math.min(heroHeight, 58.0)),
          ),
          child: AnimatedSize(
            duration: _reduced
                ? Duration.zero
                : const Duration(milliseconds: 240),
            alignment: Alignment.bottomCenter,
            curve: Curves.easeOutCubic,
            child: SizedBox(
              height: open ? fullPanelHeight : 56,
              child: _sheet(
                content,
                open: open,
                expandedHeight: fullPanelHeight,
              ),
            ),
          ),
        ),
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
      onBought: () {
        _markActed();
        widget.onHandChanged?.call();
      },
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_phoneRailScroll.hasClients) return;
      final position = _phoneRailScroll.position;
      final target = (i * 116.0 - (position.viewportDimension - 108) / 2).clamp(
        0.0,
        position.maxScrollExtent,
      );
      _phoneRailScroll.animateTo(
        target,
        duration: _reduced ? Duration.zero : const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
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
                        transform: Matrix4.translationValues(
                          0,
                          sel ? -6 : 0,
                          0,
                        ),
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
                                            EmbunColors.bg.withValues(
                                              alpha: .85,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 3,
                                        ),
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

  Widget _pickerCopy(
      _Place p, {
        required bool short,
        required bool wide,
        bool voice = false,
        double maxWidth = 560,
      }) {
    final req = _requirement(p);
    return ConstrainedBox(
      key: ValueKey(p.id),
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kicker(
            'JELAJAH DESA  ·  ${(_index + 1).toString().padLeft(2, '0')} / ${_places.length.toString().padLeft(2, '0')}',
          ),
          SizedBox(height: short ? 8 : 16),
          if (!short && wide) ...[
            _placeMedal(p, 68),
            const SizedBox(height: 14),
          ],
          _titleReveal(
            p.name,
            size: short
                ? 30
                : wide
                ? 56
                : 34,
          ),
          if (!short) ...[
            const SizedBox(height: 10),
            GildedDivider(color: _accent, width: 200),
          ],
          SizedBox(height: short ? 6 : 10),
          _text(p.tagline, size: short ? 15 : (wide ? 18 : 16), lift: true),
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
          if (voice) ...[
            const SizedBox(height: 14),
            _voiceBubble(p.id, mood: 'tanya'),
          ],
          if (req != null) ...[SizedBox(height: short ? 6 : 12), req],
        ],
      ),
    );
  }

  /// Karakter melangkah ke arah kamera saat Masuk ditekan.
  Widget _greet(Widget child) => AnimatedScale(
    scale: _entering ? 1.14 : 1.0,
    alignment: Alignment.bottomCenter,
    duration: _reduced ? Duration.zero : const Duration(milliseconds: 700),
    curve: Curves.easeInCubic,
    child: AnimatedOpacity(
      opacity: _entering ? 0.0 : 1.0,
      duration: _reduced ? Duration.zero : const Duration(milliseconds: 700),
      curve: Curves.easeIn,
      child: child,
    ),
  );

  /// Pemilih + karakter penyambut tempat terpilih. Layar lebar: karakter besar
  /// di sisi kanan. Layar sempit: karakter berdiri di balik teks, tepat di
  /// atas deretan tempat (lihat [_picker]). Karakter berganti mengikuti arah
  /// geser. Si Terbisik tak punya pose untuk Balai Pertukaran, jadi di sana
  /// hanya pemilih.
  Widget _pickerScene(bool wide) {
    final p = _places[_index];
    final art = wide ? _popup(p.id, 'tanya') : null;
    if (art == null) return _picker(wide);
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight * .98;
        final w = math.min(c.maxWidth * .46, h * .82);
        return Stack(
          children: [
            Positioned(
              right: math.max(16.0, c.maxWidth * .03),
              bottom: 0,
              width: w,
              height: h,
              child: IgnorePointer(
                child: _greet(
                  PopupCharacter(
                    path: art,
                    tint: _glow(p),
                    slide: .12 * _dir,
                    reduced: _reduced,
                  ),
                ),
              ),
            ),
            Positioned.fill(child: _picker(wide)),
          ],
        );
      },
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
                constraints: BoxConstraints(
                  maxWidth: wide ? math.min(560.0, box.maxWidth * .52) : 640.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final art = wide ? null : _popup(p.id, 'tanya');
                          final showArt = art != null && c.maxHeight >= 200;
                          final copy = SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: c.maxHeight,
                              ),
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
                                    voice: wide && !short && c.maxHeight >= 430,
                                    maxWidth: showArt
                                        ? c.maxWidth * .56
                                        : 560.0,
                                  ),
                                ),
                              ),
                            ),
                          );
                          if (!showArt) return copy;
                          // Layar sempit: karakter berdiri di kanan, tepat di
                          // atas deretan tempat, dan keluar sedikit ke tepi.
                          final h = c.maxHeight;
                          final w = math.min(c.maxWidth * .7, h * .8);
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                right: -pad + 4,
                                bottom: 0,
                                width: w,
                                height: h,
                                child: IgnorePointer(
                                  child: _greet(
                                    PopupCharacter(
                                      path: art,
                                      tint: _glow(p),
                                      slide: .12 * _dir,
                                      reduced: _reduced,
                                    ),
                                  ),
                                ),
                              ),
                              copy,
                            ],
                          );
                        },
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

  // Tata letak khusus ponsel. Jalur desktop tetap memakai panggung semula.
  bool _compactLayout(BoxConstraints box) => box.maxWidth < 1000;

  Widget _phoneHeader(_Place p, String? place, int? seconds) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 6, 12, 4),
    child: Row(
      children: [
        if (place != null && !_waiting)
          IconButton(
            tooltip: 'Kembali dari tempat ini',
            onPressed: _busy ? null : _leave,
            icon: const Icon(Icons.arrow_back, size: 22),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _placeMedal(p, 26),
          ),
        Expanded(
          child: Text(
            place == null ? 'Jelajah desa' : p.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              height: 1.15,
              color: EmbunColors.cream,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: widget.balance.toStringAsFixed(1),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GameIcon(_currency, size: 24),
                  const SizedBox(width: 4),
                  Text(
                    widget.balance.toStringAsFixed(1).replaceAll('.', ','),
                    style: const TextStyle(
                      fontSize: 20,
                      color: EmbunColors.cream,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (seconds != null) ...[
          const SizedBox(width: 10),
          Text(
            '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: seconds <= 10 ? EmbunColors.blood : _accent,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _phoneInvitation() {
    final offers = widget.trades
        .where(
          (t) =>
      t['status'] == 'pending' &&
          t['day'] == widget.day &&
          t['to_id'] == widget.repo.myId &&
          t['id'] != _visit?['invitation_id'],
    )
        .toList();
    if (offers.isEmpty || _waiting || _free) return const SizedBox.shrink();
    final t = offers.first;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          const GameIcon('barter', size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_name(t['from_id'])} mengajak bertukar',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
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
            child: const Text('Ke balai'),
          ),
          IconButton(
            tooltip: 'Tolak undangan',
            onPressed: _busy
                ? null
                : () => _act(() async {
              await widget.repo.respondTrade(t['id'] as String, false);
              return widget.repo.villageStatus(widget.gameId);
            }),
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _phoneFrame(_Place p, String? place, int? seconds) => SafeArea(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _phoneHeader(p, place, seconds),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Tooltip(
                    message: _error!,
                    child: Text(
                      _error!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: EmbunColors.blood,
                      ),
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
        _phoneInvitation(),
        Expanded(
          child: _waiting
              ? LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: _waitingView(),
              ),
            ),
          )
              : _status == null
              ? const Center(child: CircularProgressIndicator())
              : place == null
              ? _phonePicker(p)
              : LayoutBuilder(
            builder: (context, box) =>
                _stageCompact(p, _interior(place), box),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Hari ${widget.day} · Kunjungan ${_number('used', 0)}/${_number('limit', 2)}',
                  maxLines: 2,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ),
              if (!_waiting) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 122,
                  child: _button(
                    'Selesai',
                    _busy ? null : _finish,
                    secondary: true,
                    height: 44,
                    icon: 'endday',
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
      ],
    ),
  );

  String? _phonePopup(String place, String mood) {
    final stem = switch (place) {
      'riset' => 'pasarriset',
      'sumur' => 'sumur',
      'bengkel' => 'bengkelkartu',
      'pondok' => 'perawatan',
      _ => 'barter',
    };
    const folder = 'assets/kartu/CharPopUp';
    if (widget.isAntag) {
      return AssetCatalog.I.file(folder, 'popupchar-anta-$stem');
    }
    return AssetCatalog.I.file(folder, 'popupchar-pro-$stem$mood') ??
        AssetCatalog.I.file(folder, 'popupchar-pro-${stem}tanya');
  }

  /// Figur ponsel mengisi panggung dari lebar, bukan dikecilkan mengikuti
  /// tinggi. Bingkai memotong tubuh bagian bawah dan menyatukannya dengan
  /// pijakan bercahaya; tidak menampilkan stiker kecil di tengah udara.
  Widget _phonePortrait(
      _Place p,
      String mood, {
        required double height,
        double? width,
        double zoom = 1,
      }) {
    final art = _phonePopup(p.id, mood);
    if (art == null) return const SizedBox.shrink();
    return SizedBox(
      key: ValueKey('phone-portrait-${p.id}-$mood'),
      height: height,
      width: width,
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, box) {
            final frameWidth = math.min(box.maxWidth, 460.0);
            final figureWidth = frameWidth * zoom;
            final figureHeight = math.max(box.maxHeight, figureWidth * 1.28);
            return ClipRect(
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned(
                    bottom: 0,
                    width: frameWidth,
                    height: 30,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          radius: .75,
                          colors: [
                            _glow(p).withValues(alpha: .26),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    bottom: 0,
                    width: frameWidth,
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (bounds) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0, .80, 1],
                        colors: [Colors.white, Colors.white, Color(0x00FFFFFF)],
                      ).createShader(bounds),
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.topCenter,
                          minWidth: figureWidth,
                          maxWidth: figureWidth,
                          minHeight: figureHeight,
                          maxHeight: figureHeight,
                          child: AnimatedSwitcher(
                            duration: _reduced
                                ? Duration.zero
                                : const Duration(milliseconds: 220),
                            child: SizedBox.expand(
                              key: ValueKey(art),
                              child: GameImage(
                                path: art,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _phoneRail({required bool short}) {
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final height = short ? 66.0 : 98.0 + math.max(0, scale - 1) * 24;
    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        controller: _phoneRailScroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
        child: Row(
          children: [
            for (var i = 0; i < _places.length; i++)
              _phoneRailTile(i, short: short),
          ],
        ),
      ),
    );
  }

  Widget _phoneRailTile(int index, {required bool short}) {
    final p = _places[index], selected = _index == index;
    final locked = p.id == 'pondok' && _ticket == null;
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: GameImage(
        path: firstScenery([p.outside, 'pasar-sianghari']),
        cacheWidth: 240,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: selected,
        label: locked ? '${p.name}, perlu surat perawatan' : p.name,
        child: Material(
          color: selected
              ? _accent.withValues(alpha: .13)
              : const Color(0xB307130F),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: ValueKey('phone-place-${p.id}'),
            onTap: () => _select(index),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: short ? 150 : 108,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? _accent
                      : EmbunColors.goldDim.withValues(alpha: .4),
                  width: selected ? 2 : 1,
                ),
              ),
              child: short
                  ? Row(
                children: [
                  SizedBox(width: 40, height: 40, child: image),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: selected ? _accent : EmbunColors.cream,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              )
                  : Column(
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        image,
                        if (locked)
                          const Align(
                            alignment: Alignment.topRight,
                            child: GameIcon('lock', size: 18),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    p.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? _accent : EmbunColors.cream,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _phonePicker(_Place p) => LayoutBuilder(
    builder: (context, box) {
      final left = (_number('limit', 2) - _number('used', 0))
          .clamp(0, 99)
          .toInt();
      final needLetter = p.id == 'pondok' && _ticket == null;
      final short = box.maxHeight < 380;
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, scene) {
                  final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
                  final art = _phonePopup(p.id, 'tanya');
                  final spacious = scene.maxHeight >= 300 && scale <= 1.35;
                  final copy = Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _text(
                          'TUJUAN ${_index + 1} / ${_places.length}',
                          size: 10,
                          spacing: 1.4,
                          color: _accent,
                          weight: FontWeight.w800,
                          lift: true,
                        ),
                        const SizedBox(height: 7),
                        _title(p.name, size: spacious ? 30 : 24, lift: true),
                        const SizedBox(height: 7),
                        _text(p.tagline, size: 13, lift: true),
                        if (!short && scene.maxHeight >= 400) ...[
                          const SizedBox(height: 7),
                          _text(
                            _description(p),
                            size: 12,
                            color: Colors.white70,
                            lift: true,
                          ),
                        ],
                        if (p.id == 'pondok') ...[
                          const SizedBox(height: 8),
                          _text(
                            needLetter
                                ? 'Butuh ${widget.isAntag ? 'Surat Sakit' : 'Surat Dokter'}'
                                : '${widget.isAntag ? 'Surat Sakit' : 'Surat Dokter'} siap dipakai',
                            size: 12,
                            color: needLetter
                                ? EmbunColors.blood
                                : EmbunColors.leaf,
                            lift: true,
                          ),
                        ],
                      ],
                    ),
                  );
                  Widget figure(double height) => Align(
                    alignment: Alignment.bottomCenter,
                    child: _greet(
                      _phonePortrait(
                        p,
                        'tanya',
                        height: height,
                        width: math.min(scene.maxWidth * .92, 440.0),
                      ),
                    ),
                  );
                  final composition = spacious
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      copy,
                      Expanded(
                        child: art == null
                            ? const SizedBox.shrink()
                            : LayoutBuilder(
                          builder: (context, slot) =>
                              figure(slot.maxHeight),
                        ),
                      ),
                    ],
                  )
                      : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        copy,
                        if (art != null && scene.maxHeight >= 200)
                          figure(
                            (scene.maxHeight * .8).clamp(200.0, 320.0),
                          ),
                      ],
                    ),
                  );
                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragEnd: (details) {
                      final speed = details.primaryVelocity ?? 0;
                      if (speed < -250) {
                        _step(1);
                      } else if (speed > 250) {
                        _step(-1);
                      }
                    },
                    child: composition,
                  );
                },
              ),
            ),
            _phoneRail(short: short),
            const SizedBox(height: 8),
            _button(
              left == 0
                  ? 'Jatah kunjungan habis'
                  : needLetter
                  ? 'Perlu surat perawatan'
                  : 'Masuk ke ${p.name}',
              _busy || left == 0 || needLetter ? null : () => _enterPlace(p.id),
              height: 50,
            ),
            if (!short)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _text(
                  'Tersisa $left kunjungan · Geser pilihan tempat',
                  size: 11,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
      );
    },
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
          TweenAnimationBuilder<double>(
            tween: Tween<double>(
              end: place != null && box.maxWidth < 600
                  ? (_sheetOpen
                  ? (box.maxHeight * .52).clamp(240.0, 460.0).toDouble()
                  : box.maxHeight)
                  : box.maxHeight,
            ),
            duration: reduced
                ? Duration.zero
                : const Duration(milliseconds: 480),
            curve: Curves.easeOutCubic,
            builder: (context, h, _) => PlaceBackdrop(
              path: bg,
              height: place != null && box.maxWidth < 600 ? h : null,
              inside: place != null,
              pushIn: _entering,
              dir: _dir,
              reduced: reduced,
            ),
          ),
          // Peredam warna seperti Backdrop: ungu gelap untuk Si Terbisik.
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color:
                (widget.isAntag
                    ? const Color(0xFF1A1030)
                    : const Color(0xFF07130F))
                    .withValues(alpha: place == null ? .14 : .24),
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
                    // Cahaya mengikuti karakter: kanan di pemilih, kiri di dalam tempat.
                    center: Alignment(place == null ? .5 : -.5, -.2),
                    radius: 1.0,
                    colors: [glow.withValues(alpha: .26), Colors.transparent],
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
                    stops: const [0, .5, 1],
                    colors: [
                      const Color(0x60102018),
                      const Color(0x00102018),
                      EmbunColors.bg.withValues(
                        alpha: place == null ? .84 : .74,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Alas teks di sisi kiri pemilih lebar; latar sisanya dibiarkan terang.
          if (place == null && box.maxWidth > 760)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      stops: const [0, .34, .62],
                      colors: [
                        EmbunColors.bg.withValues(alpha: .66),
                        EmbunColors.bg.withValues(alpha: .26),
                        EmbunColors.bg.withValues(alpha: 0),
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
          if (_compactLayout(box))
            _phoneFrame(selected, place, seconds)
          else
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
                        ? _pickerScene(box.maxWidth > 760)
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
                      _target = null;
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
