import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/asset_catalog.dart';
import '../../data/embun_data.dart';
import '../../data/game_rules.dart';
import '../../data/hayu_effects.dart';
import '../common/art.dart';
import '../common/tutor_companion.dart';
import '../common/ornate.dart';
import '../common/sfx.dart';
import '../table/parts_strip.dart';
import 'learning_frame.dart';

/// Tutorial singkat: halaman yang digeser kiri-kanan, tiap halaman satu
/// gambar kecil (dirakit dari widget dan aset game, bukan tangkapan layar)
/// dan satu paragraf pendek. Tiap halaman punya narasi suara opsional
/// (Snd.tutor, assets/sound/). Bila berkas suara belum ada, halaman tetap
/// jalan tanpa suara.
///
/// Teks memakai angka dari game_rules.dart; nama dan harga kartu contoh
/// hanya ilustrasi.
class TutorialPage extends StatefulWidget {
  const TutorialPage({super.key});

  static const _seenKey = 'tutorial_seen_v1';

  /// True bila tutorial belum pernah dibuka (untuk lencana "Baru" di lobi).
  static Future<bool> isNew() async {
    try {
      final p = await SharedPreferences.getInstance();
      return !(p.getBool(_seenKey) ?? false);
    } catch (_) {
      return false;
    }
  }

  static Future<void> markSeen() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_seenKey, true);
    } catch (_) {}
  }

  @override
  State<TutorialPage> createState() => _TutorialPageState();
}

class _Step {
  final String title;
  final String body;
  final Color accent;
  final Widget Function(Animation<double> pulse) visual;
  final bool hasNarration;
  final TutorPose pose;
  final bool narrationCurrent;
  const _Step(
    this.title,
    this.body,
    this.accent,
    this.visual, {
    this.hasNarration = true,
    required this.pose,
    this.narrationCurrent = true,
  });
}

const _kBlue = Color(0xFF5B9BE8);

class _TutorialPageState extends State<TutorialPage>
    with SingleTickerProviderStateMixin {
  final _pc = PageController();
  int _page = 0;
  bool _voice = true;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  late final List<_Step> _steps = _buildSteps();

  @override
  void initState() {
    super.initState();
    if (EmbunData.maybeOf(context) == null) unawaited(TutorialPage.markSeen());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _speak(0);
    });
  }

  @override
  void dispose() {
    Sfx.I.release(this);
    _pc.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _speak(int i) {
    final index = _steps.take(i).where((step) => step.hasNarration).length;
    if (!_voice || !_steps[i].hasNarration ||
        !_steps[i].narrationCurrent || index >= Snd.tutor.length) {
      unawaited(Sfx.I.stopNarration());
      return;
    }
    unawaited(Sfx.I.narrate(Snd.tutor[index], owner: this));
  }

  void _toggleVoice() {
    setState(() => _voice = !_voice);
    _speak(_page);
  }

  /// Urutan narasi mengikuti Snd.tutor dengan melewati langkah tanpa rekaman.
  List<_Step> _buildSteps() => [
    _Step(
      'Selamat datang',
      'Selamat datang di desa **Hayu**. Di antara warga ada seorang '
          'penyusup, **Si Terbisik**. Hayu mulai dengan **daun yang '
          'sedikit**. Tugas warga: merawatnya sampai rimbun dan menemukan '
          'siapa penyusupnya. Jangan mudah percaya pada siapa pun.',
      EmbunColors.leaf,
      (p) => const _HayuGrow(),
      pose: TutorPose.greeting,
    ),
    _Step(
      'Peran',
      'Tiap pemain mendapat peran rahasia. **Warga** bekerja sama menjaga '
          'Hayu; **Si Terbisik** menyusup dan menggagalkannya. Jangan sampai '
          'lawan tahu siapa dirimu. Satu ruangan diisi $kMinPlayers sampai '
          '$kMaxPlayers pemain.',
      EmbunColors.gold,
      (p) => const _RoleDemo(),
      pose: TutorPose.thinking,
    ),
    _Step(
      'Satu siklus',
      'Permainan berjalan dalam **siklus $kCycleDays hari**: dua hari biasa '
          'lalu satu hari **persembahan**, disusul **musyawarah** dan **voting**. '
          'Pada malam sebelum persembahan, pilih maksimal **2 tempat** di desa. '
          'Pasar Riset, Sumur, Bengkel, Pondok, dan Balai punya layanan berbeda.',
      EmbunColors.gold,
      (p) => const _CycleDemo(),
      pose: TutorPose.counting,
      narrationCurrent: false,
    ),
    _Step(
      'Embun',
      'Tiap pagi **embunmu bertambah** sesuai tingkat produksi. Di pagi '
          'pertama setiap siklus ada **tambahan 5 embun**. Embun dipakai '
          'untuk berbelanja dan bisa **diberikan ke pemain lain**.',
      EmbunColors.gold,
      (p) => const _EmbunDemo(),
      pose: TutorPose.heavyWater,
    ),
    _Step(
      'Pagi berbelanja',
      'Di hari biasa, pilih **satu kartu** dari empat penawaran di Pasar '
          'Pagi. Kamu bisa **memberikan embun**, **mengirim isyarat**, dan '
          '**mengobrol**. Pertukaran kartu dilakukan di **Balai Pertukaran** '
          'saat kunjungan. Bila siap, **akhiri hari**.',
      EmbunColors.gold,
      (p) => const _MarketDemo(),
      pose: TutorPose.shopping,
      narrationCurrent: false,
    ),
    _Step(
      'Pasar Riset',
      'Kunjungi **Pasar Riset** pada malam sebelum persembahan. Beli kartu '
          '**poin**, **lanjutan**, atau **surat perawatan** untuk fraksimu. '
          'Harga riset **20% lebih mahal** dan jatah **2 pembelian**, '
          'terpisah dari Pasar Pagi. Menggeser tujuan belum memakai jatah '
          'kunjungan; jatah terpakai saat masuk.',
      EmbunColors.gold,
      (p) => const _ResearchDemo(),
      pose: TutorPose.choosing,
      narrationCurrent: false,
    ),
    _Step(
      'Kartu kombinasi',
      'Kunjungi **Bengkel Desa** untuk menggabungkan kartu lanjutan dengan '
          'kartu poinnya, lalu tekan **Aktifkan kartu**. Warga: Regenerasi + '
          'Poin Regenerasi. Si Terbisik: Rekayasa + Poin DNA. Penggabungan '
          '**tidak tersedia di Meja hari biasa**. Kartu yang sudah aktif '
          'bisa dipersembahkan.',
      EmbunColors.cream,
      (p) => const _FuseDemo(),
      pose: TutorPose.combine,
      narrationCurrent: false,
    ),
    _Step(
      'Informasi palsu',
      'Hasil pemeriksaan tampil dalam **popup pribadi**. Stetoskop mulai '
          'dengan peluang berhasil **30%**; tingkatkan di **Bengkel** sampai '
          '**100%**. Gagal berarti belum pasti. Mulai **85%** kebal pengelabuan. '
          '**Kaca Pembesar** dan **Lampu Senter** memberi angka pasti. '
          '**Lentera** menilai persembahan, bukan peran.',
      _kBlue,
      (p) => const _InspectDemo(),
      pose: TutorPose.question,
      narrationCurrent: false,
    ),
    _Step(
      'Serangan malam',
      'Saat malam, **Si Terbisik** bisa menyerang. Warga hanya tahu bahwa '
          '**ada serangan**, bukan siapa sasarannya. **Kartu perlindungan** '
          'membantu, tetapi hanya berlaku pada malam itu.',
      EmbunColors.mist,
      (p) => const _NightDemo(),
      pose: TutorPose.panic,
    ),
    _Step(
      'Malam persembahan',
      'Tiap **$kCycleDays hari** tiba malam persembahan. Setiap pemain '
          'mempersembahkan **1 atau $kOfferingMax kartu** secara anonim; '
          'desa hanya tahu **jumlahnya**. Si Terbisik **wajib menyertakan '
          'Roti Surplus** sebagai kedok.',
      EmbunColors.leaf,
      (p) => const _OfferDemo(),
      pose: TutorPose.offering,
    ),
    _Step(
      'Musyawarah dan voting',
      'Setelah persembahan, desa **bermusyawarah**: bagikan informasi dan '
          'sampaikan kecurigaan. Lalu **voting** ($kVoteSeconds detik). '
          'Tuduhan sah bila suara yang mendukung **lebih dari separuh** '
          'pemain yang tersisa.',
      EmbunColors.blood,
      (p) => const Column(
        children: [
          _CycleStrip(active: 5),
          SizedBox(height: 12),
          _RingDemo(),
          SizedBox(height: 10),
          _Chip('3 dari 5 pemain = tuduhan sah', EmbunColors.blood),
        ],
      ),
      pose: TutorPose.confused,
    ),
    _Step(
      'Nyawa',
      'Di contoh mode klasik ini, tiap pemain punya **$kStrikesMax nyawa**. '
          'Tuduhan pertama: '
          '**dikurung** sampai musyawarah berikutnya, tak bisa membeli atau '
          'menawar tukar. Tuduhan kedua: bila ia **Si Terbisik**, warga '
          'menang; bila warga, ia **keluar dari desa**. Bila pemain '
          'tersisa kurang dari $kMinPlayers, **Si Terbisik menang**.',
      EmbunColors.blood,
      (p) => const _LivesDemo(),
      pose: TutorPose.tired,
    ),
    _Step(
      'Dua Terbisik',
      'Host bisa memilih **Dua Terbisik** dengan minimal '
          '**$kMinDuaTerbisikPlayers pemain** siap. Kedua Terbisik saling '
          'kenal, bisa berunding di **Obrolan Terbisik**, dan berbagi '
          '**satu serangan per malam biasa**. Untuk menang lewat penyingkiran, '
          'Warga perlu mengalahkan keduanya.',
      EmbunColors.mist,
      (p) => const _Chip('Obrolan Terbisik · 1 serangan', EmbunColors.mist),
      hasNarration: false,
      pose: TutorPose.thinking,
    ),
    _Step(
      'Bagian Hayu',
      'Di ruang baru, **Akar, Batang, dan Tanah** bergerak dari **−8 sampai +8**. '
          'Akar mengubah embun harian Warga tiap poin. Batang mengubah perisai '
          'dan Tanah mengubah kabut tiap dua poin, dihitung dari kondisi awal '
          'persembahan. Tanah juga bisa mengurangi atau menambah ulat. '
          '**Daun** naik menuju target dan membuka +0,5 bulir hitam tiap 5 daun '
          'bagi Terbisik. Ketuk indikator Hayu untuk melihat rinciannya.',
      EmbunColors.leaf,
      (p) => const _HayuPartsDemo(),
      hasNarration: false,
      pose: TutorPose.counting,
    ),
    _Step(
      'Kemenangan',
      'Warga menang seketika bila Hayu mencapai **$kLeavesMax daun**. '
          'Bila hari terakhir tiba, daun harus **di atas batas**: sesi '
          '6 / 12 / 18 / 24 hari memakai batas **12 / 20 / 24 / 26**. '
          'Kurang dari itu, **Si Terbisik menang**. Lama sesi dipilih host.',
      EmbunColors.leaf,
      (p) => const _WinDemo(),
      pose: TutorPose.encourage,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final hasVoice = _steps[_page].hasNarration && _steps[_page].narrationCurrent;
    return LearningFrame(
      title: 'Tutorial',
      icon: 'tutor',
      background: sceneryPath('balkon-siang') ?? landscapePath(30),
      actions: [
        IconButton(
          tooltip: !hasVoice ? 'Narasi belum tersedia untuk bab ini'
              : _voice ? 'Matikan narasi' : 'Nyalakan narasi',
          visualDensity: VisualDensity.compact,
          onPressed: hasVoice ? _toggleVoice : null,
          color: EmbunColors.gold,
          icon: Icon(
            _voice && hasVoice ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Lewati'),
        ),
      ],
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pc,
              itemCount: _steps.length,
              onPageChanged: (i) {
                setState(() => _page = i);
                HapticFeedback.selectionClick();
                _speak(i);
              },
              itemBuilder: (_, i) => _pageOf(_steps[i], i),
            ),
          ),
          _controls(context),
        ],
      ),
    );
  }

  void _go(int delta) {
    final to = (_page + delta).clamp(0, _steps.length - 1);
    if (to == _page) return;
    _pc.animateToPage(
      to,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _controls(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    final stepLabel = 'Langkah ${_page + 1} dari ${_steps.length}';
    final step = _steps[_page];
    final last = _page == _steps.length - 1;
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(top: learningRule(step.accent))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Langkah sebelumnya',
              onPressed: _page > 0 ? () => _go(-1) : null,
              icon: Opacity(
                opacity: _page > 0 ? 1 : 0.45,
                child: const GameIcon('back', size: 23),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        compact ? '${_page + 1} / ${_steps.length}' : stepLabel,
                        semanticsLabel: stepLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: (_page + 1) / _steps.length,
                        color: step.accent,
                        backgroundColor: Colors.white12,
                        minHeight: 3,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 120,
              child: EmbunButton(
                label: last ? 'Selesai' : 'Lanjut',
                height: 42,
                expand: true,
                onPressed: last
                    ? () => Navigator.of(context).maybePop()
                    : () => _go(1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _chapter(int i) => i < 2
      ? 'DASAR'
      : i < 4
      ? 'ALUR'
      : i < 8
      ? 'KARTU'
      : i < 10
      ? 'MALAM'
      : i < 12
      ? 'SIDANG'
      : 'AKHIR';

  Widget _pageOf(_Step step, int index) => LayoutBuilder(
    builder: (context, box) {
      final short = box.maxHeight < 385;
      final wide = box.maxWidth >= (short ? 510 : 650);
      final heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _chapter(index),
            style: TextStyle(
              color: step.accent,
              fontSize: 11,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Semantics(
            header: true,
            child: Text(
              step.title,
              style: TextStyle(
                fontSize: wide && !short ? 39 : 27,
                height: 1.12,
                fontWeight: FontWeight.w900,
                color: EmbunColors.cream,
              ),
            ),
          ),
        ],
      );
      final companion = TutorCompanion(
        key: ValueKey('tutor-${step.pose.name}'),
        pose: step.pose,
        compact: short,
        large: wide && !short,
        accent: step.accent,
        child: heading,
      );
      final explanation = _rich(step.body, step.accent);
      final visual = _stage(
        step.accent,
        step.visual(_pulse),
        maxHeight: wide && short ? math.max(95, box.maxHeight - 20) : 315,
      );
      return SingleChildScrollView(
        key: PageStorageKey(index),
        padding: EdgeInsets.symmetric(
          horizontal: wide ? 18 : 4,
          vertical: short ? 8 : 16,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, box.maxHeight - (short ? 16 : 32)),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: wide ? 1000 : 520),
              child: wide
                  ? Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              companion,
                              const SizedBox(height: 15),
                              explanation,
                            ],
                          ),
                        ),
                        SizedBox(width: short ? 20 : 42),
                        Expanded(flex: 6, child: visual),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        companion,
                        const SizedBox(height: 12),
                        visual,
                        const SizedBox(height: 12),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border(top: learningRule(step.accent)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 11),
                            child: explanation,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
    },
  );

  Widget _stage(Color accent, Widget child, {required double maxHeight}) =>
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [accent.withValues(alpha: 0.12), Colors.transparent],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 400,
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.15,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 7,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  /// Teks dengan **tebal** berwarna aksen.
  Widget _rich(String s, Color accent) {
    final parts = s.split('**');
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          fontSize: 15.5,
          height: 1.5,
          color: Colors.white,
        ),
        children: [
          for (var i = 0; i < parts.length; i++)
            TextSpan(
              text: parts[i],
              style: i.isOdd
                  ? TextStyle(fontWeight: FontWeight.w800, color: accent)
                  : null,
            ),
        ],
      ),
      textAlign: TextAlign.left,
    );
  }
}

// ------------------------- bahan gambar kecil -------------------------

String? _art(String kind, String side, String stem) =>
    cardArtPath({'kind': kind, 'side': side, 'art': stem, 'id': stem});

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.7)),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );
}

// ------------------------- gambar per halaman -------------------------

double _sg(double t, double a, double b) =>
    ((t - a) / (b - a)).clamp(0.0, 1.0).toDouble();
double _sm(double x) => x * x * (3 - 2 * x);

/// Jam kecil untuk satu gambar: [builder] menerima waktu 0..1 yang berulang
/// (atau bolak-balik bila [reverse]) dan arahnya (true = maju).
class _Loop extends StatefulWidget {
  final int ms;
  final bool reverse;
  final Widget Function(BuildContext context, double t, bool fwd) builder;
  const _Loop({required this.ms, required this.builder, this.reverse = false});

  @override
  State<_Loop> createState() => _LoopState();
}

class _LoopState extends State<_Loop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.ms),
  );

  @override
  void initState() {
    super.initState();
    widget.reverse ? _c.repeat(reverse: true) : _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) =>
        widget.builder(context, _c.value, _c.status != AnimationStatus.reverse),
  );
}

/// Satu kartu dengan keterangan, bisa diredupkan, berpendar, dan berlencana.
class _CardCol extends StatelessWidget {
  final String? path;
  final String label;
  final double w;
  final Color? glow;
  final double opacity;
  final String? badge;
  final Color badgeColor;
  const _CardCol({
    required this.path,
    required this.label,
    required this.w,
    this.glow,
    this.opacity = 1,
    this.badge,
    this.badgeColor = EmbunColors.gold,
  });

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: opacity.clamp(0.0, 1.0).toDouble(),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CardArt(path: path, width: w, glow: glow),
            if (badge != null)
              Positioned(right: -8, top: -8, child: _Chip(badge!, badgeColor)),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: w + 10,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.2,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Alur satu siklus; [active] menandai tahap yang sedang dijelaskan.
class _CycleStrip extends StatelessWidget {
  final int active;
  const _CycleStrip({required this.active});

  static const _items = <(String, IconData?, String)>[
    ('', Icons.science_rounded, 'Riset'),
    ('hari', null, 'Hari'),
    ('', Icons.nightlight_round, 'Malam'),
    ('helaidaun', null, 'Persembahan'),
    ('discuss', null, 'Musyawarah'),
    ('vote', null, 'Voting'),
  ];

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < _items.length; i++) ...[
        Expanded(
          child: Column(
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: i == active ? 1 : 0.45,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.4),
                    border: Border.all(
                      color: i == active ? EmbunColors.gold : Colors.white24,
                      width: i == active ? 2 : 1,
                    ),
                    boxShadow: i == active
                        ? [
                            BoxShadow(
                              color: EmbunColors.gold.withValues(alpha: 0.4),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                  child: _items[i].$2 != null
                      ? Icon(
                          _items[i].$2,
                          size: 22,
                          color: i == 2 ? EmbunColors.mist : EmbunColors.gold,
                        )
                      : GameIcon(_items[i].$1, size: 26),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _items[i].$3,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: i == active ? FontWeight.w800 : FontWeight.w500,
                  color: i == active ? EmbunColors.gold : Colors.white54,
                ),
              ),
            ],
          ),
        ),
        if (i < _items.length - 1)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 14,
              color: Colors.white30,
            ),
          ),
      ],
    ],
  );
}

/// Kotak keterangan yang berganti halus.
Widget _caption(Object key, String text, {Color color = Colors.white}) =>
    AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: Container(
        key: ValueKey(key),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.3, color: color),
        ),
      ),
    );

/// 1. Hayu tumbuh dari nyaris mati sampai rimbun, lalu digerogoti lagi.
class _HayuGrow extends StatelessWidget {
  const _HayuGrow();

  static const _stages = [
    'pohon9',
    'pohon8',
    'pohon6',
    'pohon4',
    'pohon2',
    'pohon0',
  ];

  @override
  Widget build(BuildContext context) => _Loop(
    ms: 6500,
    reverse: true,
    builder: (context, t, fwd) {
      final paths = [
        for (final s in _stages)
          if (AssetCatalog.I.file(pohonDir, s) != null)
            AssetCatalog.I.file(pohonDir, s)!,
      ];
      final e = _sm(_sg(t, 0.08, 0.92));
      final last = paths.isEmpty ? 0 : paths.length - 1;
      final pos = e * last;
      final lo = pos.floor().clamp(0, last).toInt();
      final hi = (lo + 1).clamp(0, last).toInt();
      final fr = _sm((pos - lo).clamp(0.0, 1.0).toDouble());
      final leaves = (3 + (kLeavesMax - 3) * e).round();
      return Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (paths.isNotEmpty)
                    GameImage(path: paths[lo], cacheWidth: 900),
                  if (paths.isNotEmpty && hi != lo)
                    Opacity(
                      opacity: fr,
                      child: GameImage(path: paths[hi], cacheWidth: 900),
                    ),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: _Chip(
                      'Daun $leaves / $kLeavesMax',
                      fwd ? EmbunColors.leaf : EmbunColors.blood,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _caption(
            fwd,
            fwd
                ? 'Warga merawat Hayu: daunnya bertambah'
                : 'Si Terbisik menggerogotinya: daunnya berkurang',
            color: fwd ? EmbunColors.leaf : EmbunColors.blood,
          ),
        ],
      );
    },
  );
}

/// 2. Peran: dua punggung kartu bergantian disorot.
class _RoleDemo extends StatelessWidget {
  const _RoleDemo();

  @override
  Widget build(BuildContext context) => _Loop(
    ms: 6000,
    builder: (context, t, _) {
      final warga = t < 0.5;
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardCol(
                path: cardBackPath(),
                label: 'Warga',
                w: 92,
                glow: warga ? EmbunColors.leaf : null,
                opacity: warga ? 1 : 0.5,
              ),
              const SizedBox(width: 22),
              _CardCol(
                path: cardBackPath(dark: true),
                label: 'Si Terbisik',
                w: 92,
                glow: warga ? null : EmbunColors.blood,
                opacity: warga ? 0.5 : 1,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _caption(
            warga,
            warga
                ? 'Warga bekerja sama menjaga Hayu'
                : 'Si Terbisik menyusup dan menggagalkannya',
            color: warga ? EmbunColors.leaf : EmbunColors.blood,
          ),
        ],
      );
    },
  );
}

/// 3. Satu siklus: tahap-tahap berganti sendiri.
class _CycleDemo extends StatelessWidget {
  const _CycleDemo();

  static const _caps = [
    'Kunjungan malam: pilih Pasar Riset untuk kartu poin dan lanjutan',
    'Hari: belanja, tukar kartu, dan mengobrol',
    'Malam: Si Terbisik bisa menyerang',
    'Persembahan: tiap $kCycleDays hari, kartu dipersembahkan anonim',
    'Musyawarah: bicarakan siapa yang mencurigakan',
    'Voting: tuduh satu orang',
  ];

  @override
  Widget build(BuildContext context) => _Loop(
    ms: 13000,
    builder: (context, t, _) {
      final i = (t * 6).floor().clamp(0, 5).toInt();
      return Column(
        children: [
          _CycleStrip(active: i),
          const SizedBox(height: 16),
          _caption(i, _caps[i], color: EmbunColors.gold),
        ],
      );
    },
  );
}

/// 4. Embun: pagi menambah, awal siklus +5, lalu bisa diberikan.
class _EmbunDemo extends StatelessWidget {
  const _EmbunDemo();

  @override
  Widget build(BuildContext context) => _Loop(
    ms: 8000,
    builder: (context, t, _) {
      final base = 6 + 3 * _sg(t, 0.12, 0.3);
      final bonus = 5 * _sg(t, 0.46, 0.56);
      final give = 3 * _sg(t, 0.78, 0.88);
      final v = (base + bonus - give).round();
      final stage = t < 0.38 ? 0 : (t < 0.7 ? 1 : 2);
      const caps = [
        'Tiap pagi embunmu bertambah sesuai produksi',
        'Pagi pertama tiap siklus: tambahan 5 embun',
        'Embun bisa diberikan ke pemain lain',
      ];
      return Column(
        children: [
          SizedBox(
            height: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (stage == 0)
                  for (var i = 0; i < 3; i++)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: -10 + 70 * _sm(_sg(t, 0.02 + i * 0.05, 0.28)),
                      child: Opacity(
                        opacity: (1 - _sg(t, 0.2 + i * 0.03, 0.3)),
                        child: Align(
                          alignment: Alignment(-0.3 + i * 0.3, 0),
                          child: const GameIcon('bulirembun', size: 30),
                        ),
                      ),
                    ),
                Positioned(
                  bottom: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const GameIcon('bulirembun', size: 32),
                      const SizedBox(width: 8),
                      Text(
                        '$v',
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: EmbunColors.gold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (stage == 1)
                  Positioned(
                    top: 0,
                    child: Transform.scale(
                      scale: 0.7 + 0.3 * _sm(_sg(t, 0.4, 0.5)),
                      child: const _Chip('+5', EmbunColors.leaf),
                    ),
                  ),
                if (stage == 2)
                  Positioned(
                    right: 30 + 40 * (1 - _sm(_sg(t, 0.72, 0.9))),
                    top: 6,
                    child: Opacity(
                      opacity: _sg(t, 0.72, 0.8),
                      child: Column(
                        children: [
                          CardArt(path: cardBackPath(), width: 34),
                          const SizedBox(height: 2),
                          const _Chip('+3', EmbunColors.gold),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _caption(stage, caps[stage]),
        ],
      );
    },
  );
}

/// 5. Pasar Pagi: kartu disorot satu per satu, satu dibeli, lalu aksi lain.
class _MarketDemo extends StatelessWidget {
  const _MarketDemo();

  static const _chips = [
    ('1 kartu / hari', EmbunColors.gold),
    ('Dar embun', EmbunColors.leaf),
    ('Isyarat', _kBlue),
    ('Obrolan', EmbunColors.mist),
    ('Akhiri hari', EmbunColors.cream),
  ];

  @override
  Widget build(BuildContext context) => _Loop(
    ms: 10000,
    builder: (context, t, _) {
      final scan = (_sg(t, 0.04, 0.4) * 4).floor().clamp(0, 3).toInt();
      final bought = t >= 0.45;
      final pick = 2;
      final emb = bought ? 3 : 8;
      final chip = t < 0.45
          ? -1
          : (_sg(t, 0.5, 0.98) * 5).floor().clamp(0, 4).toInt();
      final arts = [
        (_art('persembahan', 'warga', 'daunembun'), '2 embun'),
        (_art('persembahan', 'warga', 'emberair'), '5 embun'),
        (_art('persembahan', 'warga', 'kayupagar'), '5 embun'),
        (_art('sekali_pakai', 'warga', 'lenteralawas'), '4 embun'),
      ];
      return LayoutBuilder(
        builder: (context, c) {
          final w = ((c.maxWidth - 4 * 22) / 4).clamp(48.0, 84.0).toDouble();
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const GameIcon('bulirembun', size: 24),
                  const SizedBox(width: 6),
                  Text(
                    'Embunmu: $emb',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: EmbunColors.gold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < 4; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _CardCol(
                        path: arts[i].$1,
                        label: arts[i].$2,
                        w: w,
                        glow: (bought ? i == pick : i == scan && t < 0.4)
                            ? EmbunColors.gold
                            : null,
                        opacity: bought && i != pick ? 0.4 : 1,
                        badge: bought && i == pick ? 'Dibeli' : null,
                        badgeColor: EmbunColors.leaf,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _chips.length; i++)
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: chip == -1 || chip == i ? 1 : 0.4,
                      child: _Chip(_chips[i].$1, _chips[i].$2),
                    ),
                ],
              ),
            ],
          );
        },
      );
    },
  );
}

/// 6. Pasar Riset: harga naik 20%, jatah 2 pembelian.
class _ResearchDemo extends StatelessWidget {
  const _ResearchDemo();

  @override
  Widget build(BuildContext context) => _Loop(
    ms: 10000,
    builder: (context, t, _) {
      final up = t >= 0.28;
      final left = t < 0.58 ? 2 : (t < 0.82 ? 1 : 0);
      final buyA = t >= 0.58;
      final buyB = t >= 0.82;
      final adv = _art('lanjutan', 'warga', 'gen-bibitlab');
      final poin = _art('poin', 'warga', 'gen-poinregenerasi');
      return LayoutBuilder(
        builder: (context, c) {
          final w = ((c.maxWidth - 3 * 24) / 2).clamp(60.0, 100.0).toDouble();
          Widget col(String? path, String name, int base, bool bought) =>
              _CardCol(
                path: path,
                label:
                    '$name\n${up ? '${(base * 1.2).ceil()}' : '$base'} embun',
                w: w,
                glow: bought ? EmbunColors.leaf : null,
                opacity: bought ? 0.55 : 1,
                badge: bought ? 'Dibeli' : (up ? '+20%' : null),
                badgeColor: bought ? EmbunColors.leaf : EmbunColors.gold,
              );
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.science_rounded,
                    size: 20,
                    color: EmbunColors.gold,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Pasar Riset',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: EmbunColors.gold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _Chip(
                    'Jatah $left / 2',
                    left > 0 ? EmbunColors.leaf : Colors.white38,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  col(poin, 'Kartu poin', 10, buyA),
                  const SizedBox(width: 24),
                  col(adv, 'Kartu lanjutan', 20, buyB),
                ],
              ),
              const SizedBox(height: 12),
              _caption(
                t < 0.28 ? 0 : (left == 0 ? 2 : 1),
                t < 0.28
                    ? 'Hanya menjual kartu poin dan lanjutan'
                    : (left == 0
                          ? 'Jatah habis: stok tetap, jatah terpisah dari Pasar Pagi'
                          : 'Harganya 20% lebih mahal dari harga biasa'),
                color: EmbunColors.gold,
              ),
            ],
          );
        },
      );
    },
  );
}

/// 7. Kartu kombinasi: lanjutan + poin, Aktifkan kartu, jadi AKTIF.
class _FuseDemo extends StatelessWidget {
  const _FuseDemo();

  Widget _slot(double w, Widget? child, {bool on = false}) => Container(
    width: w,
    height: w * kTallAspect,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: on
            ? EmbunColors.gold
            : EmbunColors.goldDim.withValues(alpha: 0.5),
        width: on ? 1.6 : 1,
      ),
      color: Colors.black.withValues(alpha: 0.3),
    ),
    child: child,
  );

  Widget _sym(String s) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Text(
      s,
      style: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w900,
        color: Colors.white54,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => _Loop(
    ms: 8000,
    builder: (context, t, _) => LayoutBuilder(
      builder: (context, c) {
        final w = ((c.maxWidth - 2 * 40 - 24) / 3).clamp(48.0, 88.0).toDouble();
        final adv = _art('lanjutan', 'warga', 'gen-bibitlab');
        final poin = _art('poin', 'warga', 'gen-poinregenerasi');
        final a = _sm(_sg(t, 0.08, 0.22));
        final b = _sm(_sg(t, 0.28, 0.42));
        final press = t > 0.52 && t < 0.62;
        final done = _sm(_sg(t, 0.64, 0.76));
        final Widget advCard = Opacity(
          opacity: a,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - a)),
            child: CardArt(path: adv, width: w - 4),
          ),
        );
        final Widget poinCard = Opacity(
          opacity: b,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - b)),
            child: CardArt(path: poin, width: w - 4),
          ),
        );
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    _slot(w, advCard, on: a > 0.5 && b < 0.5),
                    const SizedBox(height: 6),
                    const Text(
                      'Lanjutan',
                      style: TextStyle(fontSize: 11.5, color: Colors.white70),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.only(top: w * 0.55),
                  child: _sym('+'),
                ),
                Column(
                  children: [
                    _slot(w, poinCard, on: b > 0.5 && done < 0.5),
                    const SizedBox(height: 6),
                    const Text(
                      'Poin',
                      style: TextStyle(fontSize: 11.5, color: Colors.white70),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.only(top: w * 0.55),
                  child: _sym('='),
                ),
                Column(
                  children: [
                    _slot(
                      w,
                      Opacity(
                        opacity: done,
                        child: Transform.scale(
                          scale: 0.85 + 0.15 * done,
                          child: CardArt(
                            path: adv,
                            width: w - 4,
                            glow: EmbunColors.leaf.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                      on: done > 0.5,
                    ),
                    const SizedBox(height: 6),
                    Opacity(
                      opacity: done,
                      child: const _Chip('AKTIF', EmbunColors.leaf),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            AnimatedScale(
              duration: const Duration(milliseconds: 150),
              scale: press ? 0.94 : 1,
              child: _Chip(
                'Bengkel Desa  ›  Aktifkan kartu',
                press ? EmbunColors.gold : EmbunColors.cream,
              ),
            ),
            const SizedBox(height: 10),
            _caption(
              done > 0.5 ? 1 : 0,
              done > 0.5
                  ? 'Kini aktif: siap dipersembahkan saat malam persembahan'
                  : 'Gabungkan kartu lanjutan dengan kartu poinnya',
              color: done > 0.5 ? EmbunColors.leaf : Colors.white,
            ),
          ],
        );
      },
    ),
  );
}

/// 8. Informasi palsu: hasil asli, lalu dipalsukan.
class _InspectDemo extends StatelessWidget {
  const _InspectDemo();

  static const _fakers = ['Topeng', 'Cermin Khayal', 'Boneka Sawah'];

  @override
  Widget build(BuildContext context) => _Loop(
    ms: 9000,
    builder: (context, t, _) {
      final masked = t >= 0.4;
      final fk = t < 0.62
          ? -1
          : (_sg(t, 0.62, 0.98) * 3).floor().clamp(0, 2).toInt();
      final col = masked ? EmbunColors.leaf : EmbunColors.blood;
      return Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CardArt(
                path: cardBackPath(),
                width: 86,
                glow: col.withValues(alpha: 0.5),
              ),
              Positioned(
                right: -12,
                top: -12,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.75),
                    border: Border.all(color: col, width: 1.6),
                  ),
                  child: Icon(
                    masked
                        ? Icons.theater_comedy_rounded
                        : Icons.search_rounded,
                    size: 20,
                    color: col,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: KeyedSubtree(
              key: ValueKey(masked),
              child: _Chip(
                masked
                    ? 'Yang kamu lihat: tampak bersih'
                    : 'Hasil asli: mencurigakan',
                col,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _fakers.length; i++)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: fk == -1 || fk == i ? 1 : 0.4,
                  child: _Chip(_fakers[i], EmbunColors.mist),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _caption(
            masked ? 1 : 0,
            masked
                ? 'Stetoskop di bawah 80% masih bisa dipengaruhi pengelabuan'
                : 'Pemeriksaan bersifat pribadi: hanya kamu yang melihat',
            color: _kBlue,
          ),
        ],
      );
    },
  );
}

/// 9. Serangan malam: serangan datang, sasaran tak diumumkan, perlindungan.
class _NightDemo extends StatelessWidget {
  const _NightDemo();

  @override
  Widget build(BuildContext context) => _Loop(
    ms: 9000,
    builder: (context, t, _) {
      final atk = _sm(_sg(t, 0.06, 0.2));
      final unk = _sm(_sg(t, 0.32, 0.45));
      final prot = _sm(_sg(t, 0.58, 0.72));
      final stage = t < 0.3 ? 0 : (t < 0.56 ? 1 : 2);
      const caps = [
        'Si Terbisik menyerang saat malam',
        'Warga hanya tahu ada serangan, bukan siapa sasarannya',
        'Kartu perlindungan hanya berlaku pada malam itu',
      ];
      return Column(
        children: [
          const _CycleStrip(active: 2),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardCol(
                path: _art('malam', 'antagonis', 'kerikilpanas'),
                label: 'Serangan',
                w: 78,
                glow: EmbunColors.blood,
                opacity: atk,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 38, 14, 0),
                child: Opacity(
                  opacity: unk,
                  child: const Text(
                    '?',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
              _CardCol(
                path: _art('persembahan', 'warga', 'kayupagar'),
                label: 'Perlindungan',
                w: 78,
                glow: EmbunColors.leaf,
                opacity: prot,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _caption(stage, caps[stage], color: EmbunColors.mist),
        ],
      );
    },
  );
}

/// 10. Malam persembahan: jumlah kartu terlihat, isinya rahasia.
class _OfferDemo extends StatelessWidget {
  const _OfferDemo();

  @override
  Widget build(BuildContext context) => _Loop(
    ms: 11000,
    builder: (context, t, _) {
      const counts = [1, 2, 1, 2];
      final shown = (_sg(t, 0.05, 0.45) * 4).floor().clamp(0, 4).toInt();
      final reveal = _sm(_sg(t, 0.78, 0.92));
      final roti = t >= 0.5 && t < 0.76;
      final leaves = 12 + (3 * reveal).round();
      final stage = t < 0.48 ? 0 : (t < 0.77 ? 1 : 2);
      const caps = [
        'Setiap pemain mempersembahkan 1 atau 2 kartu, secara anonim',
        'Si Terbisik wajib menyertakan Roti Surplus sebagai kedok',
        'Isi persembahan terungkap: ada yang menambah, ada yang mengurangi daun',
      ];
      return Column(
        children: [
          const _CycleStrip(active: 3),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 4; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  child: Opacity(
                    opacity: i < shown ? 1 : 0.35,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CardArt(
                          path: cardBackPath(dark: i == 3 && roti),
                          width: 50,
                        ),
                        if (i < shown)
                          Positioned(
                            right: -6,
                            top: -8,
                            child: _Chip('${counts[i]}', EmbunColors.gold),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: roti ? 1 : 0,
            child: const _Chip(
              'Roti Surplus wajib (Si Terbisik)',
              EmbunColors.blood,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Daun Hayu: $leaves / $kLeavesMax',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: EmbunColors.leaf,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(5),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (leaves / kLeavesMax).clamp(0.0, 1.0).toDouble(),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: EmbunColors.leaf,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _caption(stage, caps[stage], color: EmbunColors.leaf),
        ],
      );
    },
  );
}

/// 12. Nyawa: dua nyawa, kurungan, lalu keluar.
class _LivesDemo extends StatelessWidget {
  const _LivesDemo();

  Widget _hearts(int left) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < kStrikesMax; i++)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            i < left ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 30,
            color: i < left ? EmbunColors.blood : Colors.white30,
          ),
        ),
    ],
  );

  Widget _stage(bool on, Widget top, String title, String sub, Color col) =>
      Expanded(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: on ? 1 : 0.4,
          child: Column(
            children: [
              SizedBox(
                height: 38,
                child: Center(
                  child: FittedBox(fit: BoxFit.scaleDown, child: top),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: col,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.25,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _arrow() => const Padding(
    padding: EdgeInsets.only(top: 9),
    child: Icon(Icons.chevron_right_rounded, color: Colors.white30),
  );

  @override
  Widget build(BuildContext context) => _Loop(
    ms: 10000,
    builder: (context, t, _) {
      final s = t < 0.28 ? 0 : (t < 0.58 ? 1 : (t < 0.84 ? 2 : 3));
      final hearts = s == 0 ? kStrikesMax : (s == 1 ? kStrikesMax - 1 : 0);
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _stage(
                s == 0,
                _hearts(kStrikesMax),
                'Awal',
                '$kStrikesMax nyawa',
                EmbunColors.cream,
              ),
              _arrow(),
              _stage(
                s == 1,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _hearts(kStrikesMax - 1),
                    const SizedBox(width: 6),
                    const GameIcon('lock', size: 26),
                  ],
                ),
                'Tuduhan 1',
                'Dikurung sampai musyawarah berikutnya',
                EmbunColors.gold,
              ),
              _arrow(),
              _stage(
                s >= 2,
                _hearts(0),
                'Tuduhan 2',
                'Si Terbisik tertangkap, atau warga keluar dari desa',
                EmbunColors.blood,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _caption(s, switch (s) {
            0 => 'Tiap pemain punya $kStrikesMax nyawa',
            1 =>
              'Dikurung: tak bisa membeli atau menawar tukar, tapi masih bisa bicara dan memilih',
            2 =>
              'Tuduhan kedua: Si Terbisik tertangkap dan warga menang, atau warga biasa keluar',
            _ =>
              'Bila pemain tersisa kurang dari 3, Si Terbisik langsung menang',
          }, color: hearts == 0 ? EmbunColors.blood : EmbunColors.gold),
        ],
      );
    },
  );
}

/// Contoh indikator Hayu dengan tiga perubahan bertahap.
class _HayuPartsDemo extends StatelessWidget {
  const _HayuPartsDemo();

  @override
  Widget build(BuildContext context) => _Loop(
    ms: 9000,
    builder: (context, t, _) {
      final index = (t * 3).floor().clamp(0, 2);
      final (leaves, akar, batang, tanah) = const [
        (12, 0, 0, 0),
        (16, 3, 2, -3),
        (20, 6, 4, -7),
      ][index];
      final effects = HayuEffects.fromGame({
        'hayu_rules_version': 2,
        'leaves': leaves,
        'win_leaves': 20,
        'akar_score': akar,
        'batang_score': batang,
        'tanah_score': tanah,
      });
      return Column(
        children: [
          SizedBox(height: 126, child: Center(child: TreePortrait(leaves: leaves))),
          const SizedBox(height: 12),
          PartsStrip(
            effects: effects,
            onTap: () => showPartsSheet(context, effects: effects),
          ),
        ],
      );
    },
  );
}

/// Kemenangan: lama sesi menggeser batas daun.
class _WinDemo extends StatelessWidget {
  const _WinDemo();

  static const _days = [6, 12, 18, 24];
  static const _need = [12, 20, 24, 26];

  @override
  Widget build(BuildContext context) => _Loop(
    ms: 12000,
    builder: (context, t, _) {
      final i = (t * 4).floor().clamp(0, 3).toInt();
      const have = 21;
      final win = have >= _need[i];
      return LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          double x(int leaves) => w * leaves / kLeavesMax;
          return Column(
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  for (var k = 0; k < 4; k++)
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: k == i ? 1 : 0.4,
                      child: _Chip(
                        '${_days[k]} hari',
                        k == i ? EmbunColors.gold : Colors.white54,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Daun Hayu: $have / $kLeavesMax',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: EmbunColors.leaf,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: have / kLeavesMax,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: win ? EmbunColors.leaf : EmbunColors.blood,
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutCubic,
                      left: x(_need[i]) - 1,
                      top: -4,
                      child: Container(
                        width: 2,
                        height: 22,
                        color: EmbunColors.gold,
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutCubic,
                      left: (x(_need[i]) - 40).clamp(0.0, w - 80).toDouble(),
                      top: 22,
                      width: 80,
                      child: Text(
                        'batas ${_need[i]}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: EmbunColors.gold,
                        ),
                      ),
                    ),
                    const Positioned(
                      right: 0,
                      top: 22,
                      child: Text(
                        '30: menang langsung',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: EmbunColors.leaf,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _caption(
                i,
                win
                    ? 'Sesi ${_days[i]} hari: 21 daun cukup, warga menang'
                    : 'Sesi ${_days[i]} hari: 21 daun belum cukup, Si Terbisik menang',
                color: win ? EmbunColors.leaf : EmbunColors.blood,
              ),
            ],
          );
        },
      );
    },
  );
}

/// Lima pemain di segi lima; tiga panah suara masuk ke satu kartu sampai
/// mayoritas (3 dari 5), lalu berulang.
class _RingDemo extends StatefulWidget {
  const _RingDemo();

  @override
  State<_RingDemo> createState() => _RingDemoState();
}

class _RingDemoState extends State<_RingDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 6000),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _from = [2, 3, 1]; // pemilih (indeks segi lima)

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        const h = 230.0;
        const cw = 42.0;
        final ch = cw * kProtagonistAspect;
        final center = Offset(w / 2, h / 2);
        final r = math
            .min(w / 2 - cw, h / 2 - ch / 2 - 6)
            .clamp(30.0, 200.0)
            .toDouble();
        final pos = [
          for (var k = 0; k < 5; k++)
            center +
                Offset(
                      math.cos(-math.pi / 2 + 2 * math.pi * k / 5),
                      math.sin(-math.pi / 2 + 2 * math.pi * k / 5),
                    ) *
                    r,
        ];
        return SizedBox(
          width: w,
          height: h,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              final prog = [
                for (var i = 0; i < 3; i++)
                  ((t - (0.10 + 0.2 * i)) / 0.18).clamp(0.0, 1.0).toDouble(),
              ];
              final count = prog.where((p) => p >= 1).length;
              final maj = _seg(t, 0.72, 0.80) * (1 - _seg(t, 0.94, 1.0));
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ArrowsPainter(
                        pos: pos,
                        from: _from,
                        to: 0,
                        prog: prog,
                        inset: ch / 2 + 4,
                      ),
                    ),
                  ),
                  for (var k = 0; k < 5; k++)
                    Positioned(
                      left: pos[k].dx - cw / 2,
                      top: pos[k].dy - ch / 2,
                      child: CardArt(
                        path: cardBackPath(),
                        width: cw,
                        glow: k == 0 && maj > 0
                            ? EmbunColors.blood.withValues(alpha: maj)
                            : null,
                      ),
                    ),
                  if (count > 0)
                    Positioned(
                      left: pos[0].dx + cw / 2 - 12,
                      top: pos[0].dy - ch / 2 - 10,
                      child: Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: maj > 0.5
                              ? EmbunColors.blood
                              : EmbunColors.gold,
                          border: Border.all(
                            color: const Color(0xFF05080F),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: maj > 0.5
                                ? Colors.white
                                : const Color(0xFF07130F),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: center.dy - 10,
                    child: Opacity(
                      opacity: maj,
                      child: const Text(
                        'MAYORITAS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w900,
                          color: EmbunColors.blood,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

double _seg(double v, double a, double b) =>
    ((v - a) / (b - a)).clamp(0.0, 1.0).toDouble();

class _ArrowsPainter extends CustomPainter {
  final List<Offset> pos;
  final List<int> from;
  final int to;
  final List<double> prog;
  final double inset;
  const _ArrowsPainter({
    required this.pos,
    required this.from,
    required this.to,
    required this.prog,
    required this.inset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < from.length; i++) {
      final p = prog[i];
      if (p <= 0) continue;
      final a = pos[from[i]];
      final b = pos[to];
      final d = b - a;
      final len = d.distance;
      if (len < 1) continue;
      final u = d / len;
      final s = a + u * inset;
      final e = b - u * inset;
      final cur = Offset.lerp(s, e, Curves.easeInCubic.transform(p))!;
      canvas.drawLine(
        s,
        cur,
        Paint()
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..color = EmbunColors.blood.withValues(alpha: 0.85),
      );
      if (p >= 1) {
        final n = Offset(-u.dy, u.dx);
        final head = Path()
          ..moveTo(e.dx, e.dy)
          ..lineTo(e.dx - u.dx * 9 + n.dx * 5, e.dy - u.dy * 9 + n.dy * 5)
          ..lineTo(e.dx - u.dx * 9 - n.dx * 5, e.dy - u.dy * 9 - n.dy * 5)
          ..close();
        canvas.drawPath(
          head,
          Paint()..color = EmbunColors.blood.withValues(alpha: 0.95),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ArrowsPainter old) => true;
}
