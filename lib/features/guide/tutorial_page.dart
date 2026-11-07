import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/asset_catalog.dart';
import '../../data/game_rules.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import '../common/sfx.dart';

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
  const _Step(this.title, this.body, this.accent, this.visual);
}

const _kBlue = Color(0xFF5B9BE8);

class _TutorialPageState extends State<TutorialPage>
    with SingleTickerProviderStateMixin {
  final _pc = PageController();
  int _page = 0;
  bool _voice = true;

  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800))
    ..repeat(reverse: true);

  late final List<_Step> _steps = _buildSteps();

  @override
  void initState() {
    super.initState();
    unawaited(TutorialPage.markSeen());
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
    if (!_voice) {
      unawaited(Sfx.I.stopNarration());
      return;
    }
    unawaited(Sfx.I.narrate(Snd.tutor[i], owner: this));
  }

  void _toggleVoice() {
    setState(() => _voice = !_voice);
    _speak(_page);
  }

  List<_Step> _buildSteps() => [
    _Step(
      'Tujuan',
      'Hayu, pohon desa, harus tumbuh sampai **$kLeavesMax daun**. '
          'Warga menjaganya. **Si Terbisik** ingin menghabiskan semua daunnya.',
      EmbunColors.leaf,
          (p) => const _TreeCompare(),
    ),
    _Step(
      'Peran',
      'Satu pemain adalah **Si Terbisik**, dan hanya ia yang tahu. Warga '
          'harus menemukannya lewat musyawarah dan voting. '
          'Pemain $kMinPlayers sampai $kMaxPlayers orang.',
      EmbunColors.gold,
          (p) => _CardRow(cards: [
        _C(cardBackPath(), 'Warga', glow: EmbunColors.leaf),
        _C(cardBackPath(dark: true), 'Si Terbisik', glow: EmbunColors.blood),
      ]),
    ),
    _Step(
      'Hari dan belanja',
      'Tiap pagi **embunmu bertambah**. Belanjalah di pasar pribadimu, '
          '**satu kartu sehari**. Kartu bisa ditukar dan embun bisa diberikan '
          'ke pemain lain.',
      EmbunColors.gold,
          (p) => const _MarketDemo(),
    ),
    _Step(
      'Kartu hijau dan merah',
      'Kartu **hijau** milik warga: menambah daun, perlindungan, atau alat '
          'periksa. Kartu **merah** milik Si Terbisik: mengurangi daun, '
          'mencuri embun, atau membungkam pemain. Keduanya **dipersembahkan** '
          'ke Hayu.',
      EmbunColors.blood,
          (p) => _CardRow(cards: [
        _C(_art('persembahan', 'warga', 'daunembun'), '+1 daun',
            glow: EmbunColors.leaf),
        _C(_art('persembahan', 'warga', 'kayupagar'), '+3 perlindungan',
            glow: EmbunColors.leaf),
        _C(_art('persembahan', 'antagonis', 'gergaji-manual'), '-2 daun',
            glow: EmbunColors.blood),
        _C(_art('persembahan', 'antagonis', 'racun-sekop'), 'curi embun',
            glow: EmbunColors.blood),
      ]),
    ),
    _Step(
      'Kartu biru: kemampuan',
      'Sebagian warga mendapat **kemampuan khusus** di awal permainan. '
          'Tidak dibeli. Ada yang sekali pakai, ada yang bekerja diam-diam.',
      _kBlue,
          (p) => const _AbilityDemo(),
    ),
    _Step(
      'Kartu ungu: serangan malam',
      'Khusus **Si Terbisik**. Disiapkan di hari biasa, dilancarkan '
          '**saat malam tiba**. Desa hanya tahu ada serangan, bukan '
          'sasarannya.',
      EmbunColors.mist,
          (p) => _CardRow(cards: [
        _C(itemBackPath(night: true), 'Punggung ungu', glow: EmbunColors.mist),
        _C(_art('malam', 'antagonis', 'pompaembun'), 'curi embun'),
        _C(_art('malam', 'antagonis', 'kerikilpanas'), 'bakar kartu'),
      ]),
    ),
    _Step(
      'Kartu kuning',
      'Milik warga. Dipakai di Meja pada hari biasa, **bukan dipersembahkan**: '
          'perisai, cermin, nyawa, embun, atau panah. Busur Terakhir '
          'berbahaya: kalau meleset, kamu yang terkena.',
      EmbunColors.gold,
          (p) => _CardRow(cards: [
        _C(_art('siang', 'warga', 'perisaituduhan'), 'Perisai Tuduhan'),
        _C(_art('siang', 'warga', 'cerminkecil'), 'Cermin Kecil'),
        _C(_art('siang', 'warga', 'busurterakhir'), 'Busur Terakhir'),
      ]),
    ),
    _Step(
      'Kartu lanjutan',
      'Kartu lanjutan dan kartu poin dijual di **Pasar Riset**. Kartu '
          'lanjutan harus **digabung** dengan kartu poin dulu di tab Gabung. Warga: Regenerasi + Poin Regenerasi. Si Terbisik: '
          'Rekayasa + Poin DNA. Poin tingkat 1, 2, dan 3 mengaktifkan '
          '1, 2, atau 3 kartu.',
      EmbunColors.cream,
          (p) => _FuseDemo(pulse: p),
    ),
    _Step(
      'Persembahan',
      'Tiap **$kCycleDays hari** ada malam persembahan. Serahkan '
          '**1 sampai $kOfferingMax kartu** ke Hayu. Semua efek dibuka '
          'bersamaan: daun naik atau turun.',
      EmbunColors.leaf,
          (p) => Column(children: [
        const _CycleStrip(active: 2),
        const SizedBox(height: 16),
        _OfferDemo(pulse: p),
      ]),
    ),
    _Step(
      'Voting',
      'Di musyawarah, pilih siapa yang kamu curigai. Yang mendapat '
          '**suara mayoritas** dituduh: tuduhan pertama **dikurung**, yang '
          'kedua **keluar dari desa**. Setiap pemain punya $kStrikesMax nyawa. '
          'Waktu memilih $kVoteSeconds detik.',
      EmbunColors.blood,
          (p) => const Column(children: [
        _CycleStrip(active: 4),
        SizedBox(height: 12),
        _RingDemo(),
      ]),
    ),
    _Step(
      'Malam',
      'Saat malam, Si Terbisik melancarkan serangan. Warga hanya mendengar '
          'bahwa **ada serangan**, lalu pagi tiba. Selamat bermain!',
      EmbunColors.mist,
          (p) => Column(children: [
        const _CycleStrip(active: 1),
        const SizedBox(height: 16),
        _CardRow(cards: [
          _C(_art('malam', 'antagonis', 'karungcurianmalam'), 'dalam gelap',
              glow: EmbunColors.mist),
          _C(_art('malam', 'antagonis', 'cerminkhayal'), 'tanpa saksi'),
        ]),
      ]),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final last = _page == _steps.length - 1;
    return Scaffold(
      backgroundColor: EmbunColors.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Backdrop(
              path: sceneryPath('balkon-siang') ?? landscapePath(30),
              dim: 0.5),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66000000), Color(0x22000000), Color(0x99000000)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _bar(),
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
                _dots(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 120,
                            child: EmbunButton(
                              label: 'Kembali',
                              kind: EmbunButtonKind.secondary,
                              height: 50,
                              expand: true,
                              onPressed: _page > 0 ? () => _go(-1) : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: EmbunButton(
                              label: last ? 'Mulai bermain' : 'Lanjut',
                              height: 50,
                              expand: true,
                              onPressed: last
                                  ? () => Navigator.of(context).maybePop()
                                  : () => _go(1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar() => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Kembali',
          onPressed: () => Navigator.of(context).maybePop(),
          color: EmbunColors.gold,
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
        const GameIcon('tutor', size: 30),
        const SizedBox(width: 8),
        const Text(
          'Tutorial',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: EmbunColors.gold,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: _voice ? 'Matikan narasi' : 'Nyalakan narasi',
          onPressed: _toggleVoice,
          color: EmbunColors.gold,
          icon: Icon(
              _voice ? Icons.volume_up_rounded : Icons.volume_off_rounded),
        ),
        TextButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          style: TextButton.styleFrom(foregroundColor: Colors.white60),
          icon: const GameIcon('skip2', size: 22),
          label: const Text('Lewati'),
        ),
      ],
    ),
  );

  void _go(int delta) {
    final to = (_page + delta).clamp(0, _steps.length - 1);
    if (to == _page) return;
    _pc.animateToPage(
      to,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _dots() => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _steps.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == _page ? 18 : 7,
            height: 7,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: i == _page
                  ? _steps[i].accent
                  : Colors.white.withValues(alpha: 0.25),
            ),
          ),
      ],
    ),
  );

  static String _chapter(int i) =>
      i < 2 ? 'DASAR' : (i == 2 ? 'GILIRAN' : (i < 8 ? 'KARTU' : 'PUTARAN'));

  Widget _pageOf(_Step s, int i) => LayoutBuilder(
    builder: (context, c) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: math.max(0.0, c.maxHeight - 16)),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. penanda posisi
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(14),
                    border:
                    Border.all(color: s.accent.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    '${_chapter(i)}  ·  ${i + 1} / ${_steps.length}',
                    style: TextStyle(
                        fontSize: 11.5,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w700,
                        color: s.accent),
                  ),
                ),
                const SizedBox(height: 10),
                // 2. judul
                Text(
                  s.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: s.accent,
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 14),
                      Shadow(color: Colors.black, blurRadius: 3),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // 3. gambar
                _stage(s.accent, s.visual(_pulse)),
                const SizedBox(height: 14),
                // 4. penjelasan
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: _rich(s.body, s.accent),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  /// Panggung gambar: panel kaca berbingkai aksen dengan pendar lembut.
  Widget _stage(Color accent, Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.58),
          accent.withValues(alpha: 0.14),
        ],
      ),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.4),
      boxShadow: [
        BoxShadow(color: accent.withValues(alpha: 0.18), blurRadius: 24),
      ],
    ),
    child: child,
  );

  /// Teks dengan **tebal** berwarna aksen.
  Widget _rich(String s, Color accent) {
    final parts = s.split('**');
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 15.5, height: 1.5, color: Colors.white),
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

class _C {
  final String? path;
  final String label;
  final Color? glow;
  const _C(this.path, this.label, {this.glow});
}

/// Deretan kartu dengan keterangan di bawahnya; ukuran menyesuaikan lebar.
class _CardRow extends StatelessWidget {
  final List<_C> cards;
  const _CardRow({required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final n = cards.length;
      final w = ((c.maxWidth - n * 12) / n).clamp(44.0, 100.0).toDouble();
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final k in cards)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                children: [
                  CardArt(path: k.path, width: w, glow: k.glow),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: w + 8,
                    child: Text(
                      k.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: const TextStyle(
                          fontSize: 11.5, height: 1.2, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    });
  }
}

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
          fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

// ------------------------- gambar per halaman -------------------------

/// Alur satu siklus; [active] menandai tahap yang sedang dijelaskan.
class _CycleStrip extends StatelessWidget {
  final int active;
  const _CycleStrip({required this.active});

  static const _items = [
    ('hari', 'Hari'),
    ('', 'Malam'),
    ('helaidaun', 'Persembahan'),
    ('discuss', 'Musyawarah'),
    ('vote', 'Voting'),
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
                child: Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.4),
                    border: Border.all(
                      color: i == active
                          ? EmbunColors.gold
                          : Colors.white24,
                      width: i == active ? 2 : 1,
                    ),
                  ),
                  child: _items[i].$1.isEmpty
                      ? const Icon(Icons.nightlight_round,
                      size: 24, color: EmbunColors.mist)
                      : GameIcon(_items[i].$1, size: 28),
                ),
              ),
              const SizedBox(height: 4),
              Text(_items[i].$2,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight:
                      i == active ? FontWeight.w800 : FontWeight.w500,
                      color:
                      i == active ? EmbunColors.gold : Colors.white54)),
            ],
          ),
        ),
        if (i < _items.length - 1)
          const Padding(
            padding: EdgeInsets.only(top: 11),
            child: Icon(Icons.chevron_right_rounded,
                size: 16, color: Colors.white30),
          ),
      ],
    ],
  );
}

class _TreeCompare extends StatelessWidget {
  const _TreeCompare();

  Widget _box(int leaves, String label, Color col) => Column(
    children: [
      TreePortrait(leaves: leaves),
      const SizedBox(height: 8),
      Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 12.5, fontWeight: FontWeight.w700, color: col),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
          child: _box(kLeavesMax, 'Warga menang\n$kLeavesMax daun',
              EmbunColors.leaf)),
      const SizedBox(width: 10),
      Expanded(
          child: _box(
              2, 'Si Terbisik menang\ndaun habis', EmbunColors.blood)),
    ],
  );
}

class _MarketDemo extends StatelessWidget {
  const _MarketDemo();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          GameIcon('bulirembun', size: 24),
          SizedBox(width: 6),
          Text(
            'Embunmu: 8',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: EmbunColors.gold),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _CardRow(cards: [
        _C(_art('persembahan', 'warga', 'daunembun'), '2 embun'),
        _C(_art('persembahan', 'warga', 'emberair'), '5 embun'),
        _C(_art('persembahan', 'warga', 'kayupagar'), '6 embun'),
        _C(_art('sekali_pakai', 'warga', 'lenteralawas'), '4 embun'),
      ]),
    ],
  );
}

class _AbilityDemo extends StatelessWidget {
  const _AbilityDemo();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      CardArt(path: abilityBackPath(), width: 96, glow: _kBlue),
      const SizedBox(height: 14),
      const Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          _Chip('Jangan Bohong', _kBlue),
          _Chip('Kunci Segel', _kBlue),
          _Chip('Patuhilah Padaku', _kBlue),
          _Chip('Kebangkitan Arwah', _kBlue),
        ],
      ),
    ],
  );
}

class _FuseDemo extends StatelessWidget {
  final Animation<double> pulse;
  const _FuseDemo({required this.pulse});

  Widget _sym(String s) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Text(
      s,
      style: const TextStyle(
          fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white54),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = ((c.maxWidth - 2 * 40 - 24) / 3).clamp(44.0, 88.0).toDouble();
      final adv = _art('lanjutan', 'warga', 'gen-bibitlab');
      final poin = _art('poin', 'warga', 'gen-poinregenerasi');
      return AnimatedBuilder(
        animation: pulse,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(children: [
              CardArt(path: adv, width: w),
              const SizedBox(height: 8),
              const Text('Lanjutan',
                  style: TextStyle(fontSize: 11.5, color: Colors.white70)),
            ]),
            Padding(
                padding: EdgeInsets.only(top: w * 0.55), child: _sym('+')),
            Column(children: [
              CardArt(path: poin, width: w),
              const SizedBox(height: 8),
              const Text('Poin',
                  style: TextStyle(fontSize: 11.5, color: Colors.white70)),
            ]),
            Padding(
                padding: EdgeInsets.only(top: w * 0.55), child: _sym('=')),
            Column(children: [
              CardArt(
                path: adv,
                width: w,
                glow: EmbunColors.leaf
                    .withValues(alpha: 0.4 + 0.5 * pulse.value),
              ),
              const SizedBox(height: 8),
              const _Chip('AKTIF', EmbunColors.leaf),
            ]),
          ],
        ),
      );
    });
  }
}

class _OfferDemo extends StatelessWidget {
  final Animation<double> pulse;
  const _OfferDemo({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: pulse,
          builder: (context, _) {
            final v = 12 + 3 * pulse.value;
            return Column(
              children: [
                Text(
                  'Daun Hayu: ${v.round()} / $kLeavesMax',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: EmbunColors.leaf),
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
                    widthFactor: (v / kLeavesMax).clamp(0.0, 1.0).toDouble(),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: EmbunColors.leaf,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        _CardRow(cards: [
          _C(_art('persembahan', 'warga', 'doabersama'), '+3 daun',
              glow: EmbunColors.leaf),
          _C(_art('persembahan', 'antagonis', 'gergaji-manual'), '-2 daun',
              glow: EmbunColors.blood),
        ]),
      ],
    );
  }
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
      vsync: this, duration: const Duration(milliseconds: 6000))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _from = [2, 3, 1]; // pemilih (indeks segi lima)

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      const h = 230.0;
      const cw = 42.0;
      final ch = cw * kProtagonistAspect;
      final center = Offset(w / 2, h / 2);
      final r = math.min(w / 2 - cw, h / 2 - ch / 2 - 6).clamp(30.0, 200.0)
          .toDouble();
      final pos = [
        for (var k = 0; k < 5; k++)
          center +
              Offset(math.cos(-math.pi / 2 + 2 * math.pi * k / 5),
                  math.sin(-math.pi / 2 + 2 * math.pi * k / 5)) *
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
                        pos: pos, from: _from, to: 0, prog: prog, inset: ch / 2 + 4),
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
                        color: maj > 0.5 ? EmbunColors.blood : EmbunColors.gold,
                        border: Border.all(
                            color: const Color(0xFF05080F), width: 1.5),
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
    });
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
            head, Paint()..color = EmbunColors.blood.withValues(alpha: 0.95));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ArrowsPainter old) => true;
}