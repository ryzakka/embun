import '../common/embun_icon.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/asset_catalog.dart';
import '../../data/game_rules.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import '../common/sfx.dart';

BorderSide roomEntryRule([Color color = EmbunColors.gold]) =>
    BorderSide(color: color.withValues(alpha: 0.30));

class RoomEntryFrame extends StatelessWidget {
  final Widget child;
  const RoomEntryFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xD3071510), Color(0x8107130F), Color(0xF007130F)],
        stops: [0, 0.46, 1],
      ),
    ),
    child: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: LayoutBuilder(
            builder: (context, box) => Padding(
              padding: EdgeInsets.symmetric(
                horizontal: box.maxWidth < 450 ? 12 : 24,
              ),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

class RoomEntryHeader extends StatelessWidget {
  final String title;
  final String icon;
  final VoidCallback? onBack;
  final Widget? action;

  const RoomEntryHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.onBack,
    this.action,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Kembali',
            icon: const GameIcon('back2', size: 23),
            onPressed: onBack,
          ),
          if (box.maxWidth >= 320) ...[
            GameIcon(icon, size: 28),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: EmbunColors.cream,
                ),
              ),
            ),
          ),
          ?action,
        ],
      ),
    ),
  );
}

/// Folder gambar slide Buat Ruangan. Daftarkan di pubspec.yaml:
///   - assets/buatruang/
/// Nama berkas (.png atau .webp) memakai awalan `buatruang-`.
const buatRuangDir = 'assets/buatruang';

class CreateRoomView extends StatefulWidget {
  final TextEditingController nameCtrl;
  final String? profileName;
  final bool isPublic;
  final int cycles;
  final int antagonistCount;
  final bool busy;
  final String characterTheme;
  final ValueChanged<String>? onThemeChanged;
  final ValueChanged<bool> onVisibilityChanged;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<int> onAntagonistCountChanged;
  final ValueChanged<String> onCreate;
  final VoidCallback onBack;

  const CreateRoomView({
    super.key,
    required this.nameCtrl,
    this.profileName,
    required this.isPublic,
    required this.cycles,
    required this.antagonistCount,
    required this.busy,
    this.characterTheme = 'default',
    this.onThemeChanged,
    required this.onVisibilityChanged,
    required this.onDurationChanged,
    required this.onAntagonistCountChanged,
    required this.onCreate,
    required this.onBack,
  });

  @override
  State<CreateRoomView> createState() => CreateRoomViewState();
}

/// Publik supaya tombol kembali sistem di lobi bisa mundur satu slide dulu
/// ([goBackSlide]) sebelum keluar dari halaman.
class CreateRoomViewState extends State<CreateRoomView> {
  static const _targets = {2: 12, 4: 20, 6: 24, 8: 26};
  int get _pageCount => widget.profileName == null ? 6 : 5;
  int get _logicalPage => _page + (widget.profileName == null ? 0 : 1);
  static const _iNama = 0,
      _iTema = 1,
      _iAkses = 2,
      _iLama = 3,
      _iTerbisik = 4,
      _iRingkas = 5;

  /// Siklus -> indeks bingkai sethari (0..6). 7 bingkai = satu hari dari
  /// fajar sampai malam; makin lama permainan, makin larut harinya.
  static const _frameOf = {2: 0, 4: 2, 6: 4, 8: 6};

  final _nameFocus = FocusNode();
  final _pc = PageController();
  bool _nameMissing = false;
  int _page = 0;
  late int _frame = _frameOf[widget.cycles] ?? 2;
  Timer? _stepper;
  bool _precached = false;

  int get _days => widget.cycles * kCycleDays;
  int get _target => _targets[widget.cycles] ?? 20;
  bool get _nameEmpty => widget.nameCtrl.text.trim().isEmpty;

  @override
  void initState() {
    super.initState();
    widget.nameCtrl.addListener(_nameChanged);
  }

  @override
  void didUpdateWidget(CreateRoomView old) {
    super.didUpdateWidget(old);
    if (old.nameCtrl != widget.nameCtrl) {
      old.nameCtrl.removeListener(_nameChanged);
      widget.nameCtrl.addListener(_nameChanged);
    }
    if (old.cycles != widget.cycles) _stepToward();
  }

  @override
  void dispose() {
    widget.nameCtrl.removeListener(_nameChanged);
    _stepper?.cancel();
    _pc.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _nameChanged() {
    if (!mounted) return;
    setState(() {
      if (_nameMissing && !_nameEmpty) _nameMissing = false;
    });
  }

  // ---------------------------------------------------------------- latar

  String? _img(String stem, [String? fallback]) =>
      AssetCatalog.I.file(buatRuangDir, 'buatruang-$stem') ??
      (fallback == null
          ? null
          : AssetCatalog.I.file(buatRuangDir, 'buatruang-$fallback')) ??
      sceneryPath('rumahdesa-hijau');

  String? _fig(String stem) =>
      AssetCatalog.I.file(buatRuangDir, 'buatruang-$stem');

  String _dayStem(int i) => 'sethari0${i + 1}';

  String? get _bg {
    switch (_logicalPage) {
      case _iNama:
        return _img('setnama');
      case _iTema:
        return _img(
          widget.characterTheme == tiongkokTheme ? 'temalukisantiongkok'
              : widget.characterTheme == manhwaTheme ? 'temamanhwaedition' : 'temadefault',
        );
      case _iAkses:
        return _img(
          widget.isPublic ? 'ruangpublik-latar' : 'ruangprivat-latar',
        );
      case _iLama:
      case _iRingkas:
        return _img(_dayStem(_frame));
      default:
        return widget.antagonistCount == 2
            ? _img('siterbisikdua-latar', 'siterbisiksatu-latar')
            : _img('siterbisiksatu-latar');
    }
  }

  String? get _figurePath {
    switch (_logicalPage) {
      case _iTema:
        return _fig(widget.characterTheme == tiongkokTheme ? 'temalukisantiongkok-char'
            : widget.characterTheme == manhwaTheme ? 'temamanhwaedition-char' : 'temadefault-char');
      case _iAkses:
        return _fig(widget.isPublic ? 'ruangpublik-char' : 'ruangprivat-char');
      case _iTerbisik:
      case _iRingkas:
        return _fig(
          widget.antagonistCount == 2
              ? 'siterbisikdua-char'
              : 'siterbisiksatu-char',
        );
      default:
        return null;
    }
  }

  /// Bingkai hari bergeser satu-satu ke target, jadi matahari tampak bergerak.
  void _stepToward() {
    _stepper?.cancel();
    _stepper = Timer.periodic(const Duration(milliseconds: 420), (t) {
      final goal = _frameOf[widget.cycles] ?? 2;
      if (!mounted || _frame == goal) {
        t.cancel();
        return;
      }
      setState(() => _frame += goal > _frame ? 1 : -1);
    });
  }

  void _precacheDays() {
    if (_precached) return;
    _precached = true;
    for (var i = 0; i < 7; i++) {
      final p = AssetCatalog.I.file(buatRuangDir, 'buatruang-${_dayStem(i)}');
      if (p != null) {
        precacheImage(ResizeImage(AssetImage(p), width: 1400), context);
      }
    }
  }

  // ------------------------------------------------------------ navigasi

  void _animate(int i) => _pc.animateToPage(
    i,
    duration: const Duration(milliseconds: 380),
    curve: Curves.easeOutCubic,
  );

  void _goTo(int i) {
    if (widget.busy || i == _page) return;
    if (i > 0 && _nameEmpty) {
      setState(() => _nameMissing = true);
      if (_page != _iNama) {
        _animate(_iNama);
      } else {
        _nameFocus.requestFocus();
      }
      return;
    }
    Sfx.I.playAny(Snd.winds);
    _animate(i);
  }

  void _next() {
    if (widget.busy) return;
    if (_page < _pageCount - 1) {
      _goTo(_page + 1);
    } else {
      _submit();
    }
  }

  /// true bila ada slide sebelumnya dan sudah mundur satu slide.
  bool goBackSlide() {
    if (widget.busy || _page == 0) return false;
    _animate(_page - 1);
    return true;
  }

  void _back() {
    if (!goBackSlide()) widget.onBack();
  }

  void _submit() {
    if (widget.busy) return;
    final name = widget.nameCtrl.text.trim();
    if (name.isEmpty) {
      _goTo(_iNama);
      return;
    }
    FocusScope.of(context).unfocus();
    widget.onCreate(name);
  }

  void _pick(VoidCallback apply) {
    HapticFeedback.selectionClick();
    Sfx.I.click(Snd.click2);
    apply();
  }

  // --------------------------------------------------------------- bangun

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final sz = box.biggest;
      final wide = sz.width >= 710;
      final frameW = sz.width < 1120 ? sz.width : 1120.0;
      final padH = sz.width < 450 ? 12.0 : 24.0;
      final band = (!wide && sz.height >= 560) ? sz.height * 0.34 : 0.0;
      final hasFigure = _figurePath != null;
      final inset = (sz.width - frameW) / 2;
      final last = _page == _pageCount - 1;
      final canSwipe = !widget.busy && (_page != _iNama || !_nameEmpty);

      final pages = PageView(
        controller: _pc,
        physics: canSwipe
            ? const PageScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        onPageChanged: (i) {
          setState(() => _page = i);
          if (i != _iNama) FocusScope.of(context).unfocus();
          if (i >= _iAkses) _precacheDays();
        },
        children: [
          if (widget.profileName == null) _slideNama(wide),
          _slideTema(wide),
          _slideAkses(wide),
          _slideLama(wide),
          _slideTerbisik(wide),
          _slideRingkasan(wide),
        ],
      );

      return Stack(
        fit: StackFit.expand,
        children: [
          _SceneBackdrop(path: _bg),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: wide ? Alignment.centerLeft : Alignment.topCenter,
                end: wide ? Alignment.centerRight : Alignment.bottomCenter,
                colors: wide
                    ? const [
                        Color(0xE607130F),
                        Color(0xB007130F),
                        Color(0x2207130F),
                        Color(0x0007130F),
                      ]
                    : const [
                        Color(0x55000000),
                        Color(0x1A000000),
                        Color(0xCC07130F),
                        Color(0xF207130F),
                      ],
                stops: wide
                    ? const [0, 0.42, 0.72, 1]
                    : const [0, 0.2, 0.46, 1],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0xC007130F),
                ],
                stops: [0, 0.74, 1],
              ),
            ),
          ),
          if (wide)
            Positioned(
              top: 0,
              bottom: 0,
              right: inset,
              width: frameW * 0.54,
              child: IgnorePointer(
                child: _figure(Alignment.bottomRight, const Offset(70, 0)),
              ),
            ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: padH),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(bottom: roomEntryRule()),
                        ),
                        child: RoomEntryHeader(
                          title: 'Buat Ruangan',
                          icon: 'roomcreate',
                          onBack: widget.busy ? null : _back,
                        ),
                      ),
                      if (band > 0)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeOutCubic,
                          height: hasFigure ? band : 0,
                          child: ClipRect(
                            child: IgnorePointer(
                              child: _figure(
                                Alignment.bottomCenter,
                                const Offset(0, 50),
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        child: wide
                            ? Row(
                                children: [
                                  SizedBox(
                                    width: (frameW - padH * 2) * 0.46,
                                    child: pages,
                                  ),
                                  const Expanded(child: SizedBox()),
                                ],
                              )
                            : pages,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(top: roomEntryRule()),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              Expanded(child: _dots()),
                              SizedBox(
                                width: last
                                    ? (wide ? 264.0 : 190.0)
                                    : (wide ? 200.0 : 140.0),
                                child: EmbunButton(
                                  label: last
                                      ? (widget.busy
                                            ? 'Membuat ruangan…'
                                            : 'Buat Ruangan')
                                      : 'Lanjut',
                                  icon: last
                                      ? (widget.busy ? 'wait' : 'roomcreate')
                                      : null,
                                  expand: true,
                                  height: 45,
                                  onPressed: widget.busy ? null : _next,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _figure(Alignment align, Offset from) {
    final p = _figurePath;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      layoutBuilder: (cur, prev) => Stack(
        fit: StackFit.expand,
        alignment: align,
        children: [...prev, ?cur],
      ),
      child: p == null
          ? const SizedBox.shrink(key: ValueKey('tanpa-sosok'))
          : _Appear(
              key: ValueKey(p),
              from: from,
              child: GameImage(
                path: p,
                fit: BoxFit.contain,
                alignment: align,
                cacheWidth: 1100,
              ),
            ),
    );
  }

  Widget _dots() => Row(
    children: [
      for (var i = 0; i < _pageCount; i++)
        Semantics(
          button: true,
          label: 'Langkah ${i + 1} dari $_pageCount',
          selected: i == _page,
          child: InkResponse(
            radius: 16,
            onTap: () => _goTo(i),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                width: i == _page ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: i == _page
                      ? EmbunColors.gold
                      : (i < _page ? EmbunColors.goldDim : Colors.white24),
                ),
              ),
            ),
          ),
        ),
    ],
  );

  // --------------------------------------------------------------- slide

  Widget _slide(
    bool wide, {
    required String title,
    String? caption,
    required List<Widget> children,
  }) => SingleChildScrollView(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: EdgeInsets.fromLTRB(2, wide ? 26 : 14, 2, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: TextStyle(
              fontSize: wide ? 30 : 25,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: EmbunColors.cream,
              shadows: const [Shadow(color: Colors.black87, blurRadius: 14)],
            ),
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 6),
          Text(
            caption,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: Colors.white70,
            ),
          ),
        ],
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );

  Widget _option({
    required String icon,
    required String label,
    required String sub,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          border: Border(
            bottom: selected
                ? BorderSide(color: accent, width: 2)
                : roomEntryRule(accent),
          ),
        ),
        child: InkWell(
          onTap: widget.busy || selected ? null : () => _pick(onTap),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Row(
              children: [
                GameIcon(icon, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: selected ? accent : EmbunColors.cream,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected) EmbunIcon(Icons.check, size: 20, color: accent),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _slideNama(bool wide) => _slide(
    wide,
    title: 'Namamu',
    caption: 'Nama yang dilihat pemain lain di ruangan.',
    children: [
      TextField(
        controller: widget.nameCtrl,
        focusNode: _nameFocus,
        enabled: !widget.busy,
        textInputAction: TextInputAction.next,
        textCapitalization: TextCapitalization.words,
        maxLength: 20,
        onSubmitted: (_) => _next(),
        style: const TextStyle(fontSize: 18, color: EmbunColors.cream),
        decoration: InputDecoration(
          filled: false,
          hintText: 'Tulis namamu',
          hintStyle: const TextStyle(color: Colors.white38),
          counterText: '',
          errorText: _nameMissing ? 'Isi namamu dulu' : null,
          prefixIcon: const Padding(
            padding: EdgeInsets.all(8),
            child: GameIcon('identity', size: 26),
          ),
          border: UnderlineInputBorder(
            borderSide: BorderSide(
              color: EmbunColors.gold.withValues(alpha: 0.4),
            ),
          ),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: EmbunColors.gold.withValues(alpha: 0.4),
            ),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: EmbunColors.gold, width: 2),
          ),
        ),
      ),
    ],
  );

  Widget _slideTema(bool wide) => _slide(
    wide,
    title: 'Tema kartu karakter',
    caption: widget.profileName == null
        ? 'Menentukan cara semua pemain memilih kartu karakter.'
        : 'Bermain sebagai ${widget.profileName}. Pilih tema kartu untuk ruanganmu.',
    children: [
      _option(
        icon: 'character',
        label: 'Default',
        sub: 'Pemilihan kartu karakter seperti biasa.',
        selected: widget.characterTheme == defaultTheme,
        accent: EmbunColors.leaf,
        onTap: () => widget.onThemeChanged?.call('default'),
      ),
      _option(
        icon: 'customization',
        label: 'Manhwa Style',
        sub:
            'Tokoh dipilih bergiliran, lalu semua pemain memilih pakaian '
            'masing-masing.',
        selected: widget.characterTheme == 'manhwa',
        accent: EmbunColors.leaf,
        onTap: () => widget.onThemeChanged?.call('manhwa'),
      ),
      _option(
        icon: 'customization',
        label: 'Lukisan Tiongkok',
        sub: 'Tokoh dipilih bergiliran. Setiap tokoh saat ini memiliki satu penampilan utama.',
        selected: widget.characterTheme == tiongkokTheme,
        accent: EmbunColors.gold,
        onTap: () => widget.onThemeChanged?.call(tiongkokTheme),
      ),
    ],
  );

  Widget _slideAkses(bool wide) => _slide(
    wide,
    title: 'Akses ruangan',
    caption: 'Siapa saja yang bisa menemukan dan masuk ke ruanganmu.',
    children: [
      _option(
        icon: 'lock',
        label: 'Privat',
        sub: 'Pemain bisa masuk dengan kode yang kamu bagikan.',
        selected: !widget.isPublic,
        accent: EmbunColors.gold,
        onTap: () => widget.onVisibilityChanged(false),
      ),
      _option(
        icon: 'persona',
        label: 'Publik',
        sub: 'Pemain bisa menemukan ruanganmu di daftar publik.',
        selected: widget.isPublic,
        accent: EmbunColors.gold,
        onTap: () => widget.onVisibilityChanged(true),
      ),
    ],
  );

  Widget _slideLama(bool wide) => _slide(
    wide,
    title: 'Lama permainan',
    caption: 'Makin lama, makin larut harinya.',
    children: [
      for (final c in _targets.keys)
        _option(
          icon: 'hari',
          label: '${c * kCycleDays} hari${c == 4 ? ' · bawaan' : ''}',
          sub: 'Target ${_targets[c]} daun di akhir hari ke-${c * kCycleDays}',
          selected: widget.cycles == c,
          accent: EmbunColors.leaf,
          onTap: () => widget.onDurationChanged(c),
        ),
      const SizedBox(height: 12),
      _targetNote(),
    ],
  );

  Widget _slideTerbisik(bool wide) => _slide(
    wide,
    title: 'Jumlah antagonis',
    caption: 'Berapa Terbisik yang menyusup di antara warga.',
    children: [
      for (final n in const [1, 2])
        _option(
          icon: 'danger',
          label: antagonistModeLabel(n),
          sub:
              '${minPlayersFor(n)}–$kMaxPlayers pemain'
              '${n == 2 ? ' · mulai setelah minimal $kMinDuaTerbisikPlayers pemain siap' : ''}',
          selected: widget.antagonistCount == n,
          accent: EmbunColors.mist,
          onTap: () => widget.onAntagonistCountChanged(n),
        ),
    ],
  );

  Widget _summaryRow(String label, String value, int page) => Semantics(
    button: true,
    label: 'Ubah $label',
    child: Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(border: Border(bottom: roomEntryRule())),
        child: InkWell(
          onTap: widget.busy ? null : () => _goTo(page),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: EmbunColors.gold,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      color: EmbunColors.cream,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Ubah',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _slideRingkasan(bool wide) => _slide(
    wide,
    title: 'Siap dibuat',
    caption: 'Periksa pilihanmu, lalu buat ruangan.',
    children: [
      _summaryRow(
        'Nama',
        _nameEmpty ? '—' : widget.nameCtrl.text.trim(),
        _iNama,
      ),
      _summaryRow(
        'Tema',
        characterThemeLabel(widget.characterTheme),
        _iTema,
      ),
      _summaryRow('Akses', widget.isPublic ? 'Publik' : 'Privat', _iAkses),
      _summaryRow(
        'Lama',
        '$_days hari${widget.cycles == 4 ? ' (bawaan)' : ''} · target $_target daun',
        _iLama,
      ),
      _summaryRow(
        'Antagonis',
        '${antagonistModeLabel(widget.antagonistCount)} · '
            '${minPlayersFor(widget.antagonistCount)}–$kMaxPlayers pemain',
        _iTerbisik,
      ),
      const SizedBox(height: 12),
      _targetNote(),
    ],
  );

  Widget _targetNote() => Text.rich(
    TextSpan(
      children: [
        const TextSpan(text: 'Warga menang dengan minimal '),
        TextSpan(
          text: '$_target daun',
          style: const TextStyle(
            color: EmbunColors.leaf,
            fontWeight: FontWeight.w800,
          ),
        ),
        TextSpan(
          text:
              ' di akhir hari ke-$_days, atau dengan $kLeavesMax daun lebih cepat.',
        ),
      ],
    ),
    style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.white70),
  );
}

/// Latar slide: gambar berganti dengan memudar. Diperbesar sedikit supaya
/// tepi gambar (bila ada bingkai tipis) terpotong di luar layar.
class _SceneBackdrop extends StatelessWidget {
  final String? path;
  const _SceneBackdrop({required this.path});

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const ColoredBox(color: EmbunColors.bg),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 650),
        layoutBuilder: (cur, prev) =>
            Stack(fit: StackFit.expand, children: [...prev, ?cur]),
        child: Transform.scale(
          key: ValueKey(path),
          scale: 1.05,
          child: GameImage(path: path, cacheWidth: 1400),
        ),
      ),
      const ColoredBox(color: Color(0x3307130F)),
    ],
  );
}

/// Muncul pelan dari arah [from] sambil memudar masuk.
class _Appear extends StatefulWidget {
  final Widget child;
  final Offset from;
  const _Appear({super.key, required this.child, required this.from});

  @override
  State<_Appear> createState() => _AppearState();
}

class _AppearState extends State<_Appear> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (_, child) {
      final t = Curves.easeOutCubic.transform(_c.value);
      return Opacity(
        opacity: t,
        child: Transform.translate(offset: widget.from * (1 - t), child: child),
      );
    },
  );
}
