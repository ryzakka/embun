import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'flip_card.dart';
import 'player_status.dart';

/// Kemampuan acak khusus warga. Definisinya ada di tabel `ability_definitions`;
/// berkas ini hanya tampilan dan pemakaiannya.

IconData abilityIcon(String id) => switch (id) {
  'jangan_bohong' => Icons.visibility_rounded,
  'tumbuhan' => Icons.spa_rounded,
  'pedagang' => Icons.storefront_rounded,
  'lidah_manis' => Icons.record_voice_over_rounded,
  'mata_suci' => Icons.remove_red_eye_rounded,
  'kamera_rekaan' => Icons.photo_camera_rounded,
  'arloji_khayal' => Icons.hourglass_top_rounded,
  'jemari_magis' => Icons.back_hand_rounded,
  'kebangkitan_arwah' => Icons.auto_awesome_rounded,
  'palu_hakim' => Icons.gavel_rounded,
  'kunci_segel' => Icons.vpn_key_rounded,
  _ => Icons.person_outline_rounded,
};

Color abilityAccent(String id) => switch (id) {
  'jangan_bohong' => const Color(0xFF8FC1FF),
  'tumbuhan' => EmbunColors.leaf,
  'pedagang' => EmbunColors.gold,
  'lidah_manis' => const Color(0xFFE8A0C8),
  'mata_suci' => const Color(0xFF7FD8FF),
  'kamera_rekaan' => const Color(0xFFB0B8C8),
  'arloji_khayal' => const Color(0xFF8FA8FF),
  'jemari_magis' => const Color(0xFF9BE08A),
  'kebangkitan_arwah' => const Color(0xFFBFE8FF),
  'palu_hakim' => const Color(0xFFD9A066),
  'kunci_segel' => const Color(0xFFE8C766),
  _ => EmbunColors.goldDim,
};

/// Kemampuan yang dipakai dengan menekan tombol (selain itu bekerja sendiri).
bool abilityIsManual(String id) => const {
  'jangan_bohong',
  'pedagang',
  'mata_suci',
  'kamera_rekaan',
  'arloji_khayal',
  'jemari_magis',
  'kunci_segel',
}.contains(id);

/// Bidang 5:6 memuat semua muka kartu biru dengan bingkai aslinya utuh.
const abilityCardAspect = 1.2;
const _cardBlue = Color(0xFF8FCBFF);

/// Kartu kemampuan memakai ilustrasi asli atau ikon saat ilustrasi tak ada.
class AbilityCardView extends StatelessWidget {
  final Map<String, dynamic> def;
  final bool used;
  final double width;
  const AbilityCardView({
    super.key,
    required this.def,
    this.used = false,
    this.width = 170,
  });

  @override
  Widget build(BuildContext context) {
    final id = '${def['id']}';
    final accent = abilityAccent(id);
    final art = abilityArtPath(def);
    final h = width * abilityCardAspect;
    return Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF15283B), Color(0xFF0A1726)],
        ),
        border: Border.all(color: _cardBlue.withValues(alpha: 0.40)),
        boxShadow: [
          BoxShadow(color: _cardBlue.withValues(alpha: 0.19), blurRadius: 16),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (art != null)
              GameImage(
                path: art,
                fit: BoxFit.contain,
                cacheWidth: (width * 2).round(),
              )
            else
              Padding(
                padding: EdgeInsets.all(width * 0.08),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: width * 0.84,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          abilityIcon(id),
                          size: width * 0.38,
                          color: accent,
                        ),
                        SizedBox(height: width * 0.07),
                        Text(
                          '${def['name']}',
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: width * 0.105,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            color: EmbunColors.gold,
                          ),
                        ),
                        SizedBox(height: width * 0.04),
                        Text(
                          def['kind'] == 'pasif' ? 'Pasif' : 'Sekali pakai',
                          style: TextStyle(
                            fontSize: width * 0.075,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (used) ...[
              Positioned.fill(
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.55)),
              ),
              Center(
                child: Transform.rotate(
                  angle: -0.2,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: width * 0.08,
                      vertical: width * 0.03,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: EmbunColors.blood, width: 2.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      def['kind'] == 'pasif' ? 'NONAKTIF' : 'TERPAKAI',
                      style: TextStyle(
                        fontSize: width * 0.11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: EmbunColors.blood,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dialog kemampuan: kartu, penjelasan, dan (bila bisa) tombol pemakaian.
/// [intro] true = pengungkapan di awal permainan.
Future<void> showAbilityDialog(
  BuildContext context, {
  required Map<String, dynamic> def,
  required bool used,
  required GameRepository repo,
  required String gameId,
  required String phase,
  required bool jailed,
  required List<Map<String, dynamic>> others,

  /// Semua pemain yang masih di desa, termasuk diri sendiri (Kunci Segel
  /// boleh membebaskan diri sendiri).
  required List<Map<String, dynamic>> everyone,
  required int day,
  required VoidCallback onUsed,
  bool intro = false,
}) => showDialog<void>(
  context: context,
  barrierDismissible: !intro,
  builder: (_) => _AbilityDialog(
    def: def,
    used: used,
    repo: repo,
    gameId: gameId,
    phase: phase,
    jailed: jailed,
    others: others,
    everyone: everyone,
    day: day,
    onUsed: onUsed,
    intro: intro,
  ),
);

class _AbilityDialog extends StatefulWidget {
  final Map<String, dynamic> def;
  final bool used;
  final GameRepository repo;
  final String gameId;
  final String phase;
  final bool jailed;
  final List<Map<String, dynamic>> others;
  final List<Map<String, dynamic>> everyone;
  final int day;
  final VoidCallback onUsed;
  final bool intro;

  const _AbilityDialog({
    required this.def,
    required this.used,
    required this.repo,
    required this.gameId,
    required this.phase,
    required this.jailed,
    required this.others,
    required this.everyone,
    required this.day,
    required this.onUsed,
    required this.intro,
  });

  @override
  State<_AbilityDialog> createState() => _AbilityDialogState();
}

class _AbilityDialogState extends State<_AbilityDialog> {
  String? target;
  bool busy = false;
  String? error;
  Map<String, dynamic>? result;

  String get _id => '${widget.def['id']}';
  bool get _usedNow => widget.used || result != null;

  Future<void> _use({String? option}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final r = await widget.repo.useAbility(
        widget.gameId,
        target: target,
        option: option,
      );
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() => result = r);
      widget.onUsed();
    } catch (e) {
      if (mounted) setState(() => error = errMsg(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _note(String text, {Color color = Colors.white60}) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12.5, height: 1.4, color: color),
    ),
  );

  Widget _resultPanel() {
    final r = result!;
    final res = '${r['result']}';
    final (color, icon) = switch (res) {
      'benar' => (EmbunColors.blood, 'alert'),
      'ragu' => (EmbunColors.gold, 'question'),
      'bukan' => (EmbunColors.leaf, 'centang'),
      _ => (abilityAccent(_id), null),
    };
    final isRead = _id == 'jangan_bohong';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.8), width: 1.5),
      ),
      child: Column(
        children: [
          if (icon != null)
            GameIcon(icon, size: 36)
          else
            Icon(abilityIcon(_id), size: 36, color: color),
          const SizedBox(height: 6),
          if (isRead) ...[
            Text(
              'Firasatmu tentang ${r['target']}',
              style: const TextStyle(fontSize: 12.5, color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              '"${r['phrase']}"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Firasat bisa keliru. Hanya kamu yang mendengarnya.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: Colors.white54),
            ),
          ] else
            Text(
              '${r['message']}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
        ],
      ),
    );
  }

  bool get _phaseOk => switch (_id) {
    'mata_suci' => widget.phase == 'day' || widget.phase == 'discussion',
    'kamera_rekaan' => widget.phase == 'day',
    'arloji_khayal' => widget.phase == 'discussion' || widget.phase == 'voting',
    'jemari_magis' => widget.phase == 'day',
    'kunci_segel' => widget.phase == 'day',
    _ => false,
  };

  String get _phaseHint => switch (_id) {
    'mata_suci' => 'Mata batin hanya terbuka saat hari biasa atau musyawarah.',
    'kamera_rekaan' => 'Kamera hanya bisa dipasang di hari biasa.',
    'arloji_khayal' => 'Arloji hanya bisa diputar saat musyawarah atau voting.',
    'jemari_magis' => 'Jemari hanya bisa menyentuh Hayu di hari biasa.',
    'kunci_segel' => 'Kunci Segel hanya bisa dipakai di hari biasa.',
    _ => '',
  };

  /// Dikurung (sudah atau akan mulai), belum keluar dari desa.
  bool _hasJail(Map<String, dynamic> p) {
    if (isOut(p)) return false;
    final from = p['jailed_day'] as int?;
    if (from == null) return false;
    final until = (p['jailed_until'] as int?) ?? from;
    return until >= widget.day;
  }

  Widget _picker(List<Map<String, dynamic>> list, String empty) {
    if (list.isEmpty) return _note(empty);
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final p in list)
          ChoiceChip(
            avatar: PlayerAvatar(
              path: protagonistPath(p['character_card'] as String),
              size: 24,
            ),
            label: Text(
              p['user_id'] == widget.repo.myId
                  ? '${p['name']} (kamu)'
                  : p['name'] as String,
            ),
            selected: target == p['user_id'],
            showCheckmark: false,
            selectedColor: abilityAccent(_id).withValues(alpha: 0.28),
            onSelected: busy
                ? null
                : (_) => setState(() => target = p['user_id'] as String),
          ),
      ],
    );
  }

  Future<void> _confirmSacrifice() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Berkorban untuk Hayu?'),
        content: const Text(
          'Hayu langsung +10 daun, tetapi kamu keluar dari desa saat malam '
          'tiba. Jika Hayu mencapai 30 daun, pengorbanan dibayar saat itu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Berkorban'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) _use(option: 'ten');
  }

  /// Tombol pemakaian untuk kemampuan manual yang baru.
  Widget _newActions() {
    if (!_phaseOk) return _note(_phaseHint);
    const gap = SizedBox(height: 10);
    switch (_id) {
      case 'mata_suci':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _note(
              'Harga: 1 nyawa, dibayar pada malam hari biasa berikutnya.',
              color: EmbunColors.gold,
            ),
            gap,
            const Text(
              'Pilih satu pemain:',
              style: TextStyle(fontSize: 12.5, color: EmbunColors.gold),
            ),
            const SizedBox(height: 8),
            _picker(widget.others, 'Tidak ada pemain lain.'),
            const SizedBox(height: 12),
            EmbunButton(
              label: 'Buka mata batin',
              icon: 'show',
              expand: true,
              onPressed: busy || target == null ? null : () => _use(),
            ),
          ],
        );
      case 'kamera_rekaan':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _note(
              'Hasilnya muncul pada musyawarah berikutnya. Kamera mencatat '
              'serangan yang dilancarkan, termasuk bila tertangkis.',
            ),
            gap,
            EmbunButton(
              label: 'Pasang kamera',
              icon: 'show',
              expand: true,
              onPressed: busy ? null : () => _use(),
            ),
          ],
        );
      case 'arloji_khayal':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _note(
              'Menambah 60 detik pada fase yang sedang berjalan, tanpa '
              'menyebut namamu.',
            ),
            gap,
            EmbunButton(
              label: 'Putar arloji',
              icon: 'timer',
              expand: true,
              onPressed: busy ? null : () => _use(),
            ),
          ],
        );
      case 'jemari_magis':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _note(
              'Harga dibayar malam ini. Jika Hayu mencapai 30 daun, '
              'harga dibayar saat itu dan warga menang.',
            ),
            gap,
            EmbunButton(
              label: '+5 daun, harga 1 nyawa',
              icon: 'plus',
              expand: true,
              onPressed: busy ? null : () => _use(option: 'five'),
            ),
            const SizedBox(height: 8),
            EmbunButton(
              label: '+10 daun, berkorban diri',
              icon: 'plus',
              kind: EmbunButtonKind.secondary,
              expand: true,
              height: 46,
              onPressed: busy ? null : _confirmSacrifice,
            ),
          ],
        );
      case 'kunci_segel':
        final jailed = [
          for (final p in widget.everyone)
            if (_hasJail(p)) p,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Pilih pemain yang dikurung:',
              style: TextStyle(fontSize: 12.5, color: EmbunColors.gold),
            ),
            const SizedBox(height: 8),
            _picker(jailed, 'Tidak ada yang sedang dikurung.'),
            const SizedBox(height: 12),
            EmbunButton(
              label: 'Bebaskan',
              icon: 'lock',
              expand: true,
              onPressed: busy || target == null ? null : () => _use(),
            ),
          ],
        );
    }
    return const SizedBox.shrink();
  }

  /// Bagian bawah: penjelasan status atau tombol pemakaian.
  Widget _actions() {
    if (result != null) return _resultPanel();

    if (!abilityIsManual(_id)) {
      final text = switch (_id) {
        'tumbuhan' =>
          _usedNow
              ? 'Bonus laju embun sudah dinonaktifkan.'
              : 'Bekerja otomatis. Laju dasar embunmu naik 0,75 sejak awal.',
        'lidah_manis' =>
          _usedNow
              ? 'Si Lidah Manis sudah tidak aktif.'
              : 'Bekerja otomatis pada tuduhan mayoritas pertama yang akan '
                    'mengurungmu. Tuduhan tetap tercatat.',
        'kebangkitan_arwah' =>
          _usedNow
              ? 'Kebangkitan Arwah sudah tidak aktif.'
              : 'Bekerja otomatis jika kamu akan tersingkir karena voting atau '
                    'Busur Terakhir. Kamu bangkit dengan 1 nyawa sebagai warga biasa.',
        'palu_hakim' =>
          _usedNow
              ? 'Palu sudah tidak tersedia untuk voting berikutnya.'
              : 'Dipakai di layar voting: nyalakan "Patuhilah Padaku" sebelum '
                    'mengunci tuduhan. Suaramu berbobot 2.',
        _ => 'Tidak ada yang perlu dipakai. Kamu warga desa biasa.',
      };
      return _note(text);
    }

    if (_usedNow) return _note('Kemampuan ini sudah terpakai.');

    if (_id != 'jangan_bohong' && _id != 'pedagang') return _newActions();

    if (_id == 'jangan_bohong') {
      final can = widget.phase == 'day' || widget.phase == 'discussion';
      if (!can) {
        return _note(
          'Firasat hanya bisa didengar saat hari biasa atau musyawarah.',
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Pilih satu pemain:',
            style: TextStyle(fontSize: 12.5, color: EmbunColors.gold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final p in widget.others)
                ChoiceChip(
                  avatar: PlayerAvatar(
                    path: protagonistPath(p['character_card'] as String),
                    size: 24,
                  ),
                  label: Text(p['name'] as String),
                  selected: target == p['user_id'],
                  showCheckmark: false,
                  selectedColor: EmbunColors.gold.withValues(alpha: 0.28),
                  onSelected: busy
                      ? null
                      : (_) => setState(() => target = p['user_id'] as String),
                ),
            ],
          ),
          const SizedBox(height: 12),
          EmbunButton(
            label: 'Dengarkan firasat',
            icon: 'show',
            expand: true,
            onPressed: busy || target == null ? null : _use,
          ),
        ],
      );
    }

    // pedagang
    if (widget.phase != 'day') {
      return _note('Pedagang hanya datang saat hari biasa.');
    }
    if (widget.jailed) {
      return _note('Kamu sedang dikurung, jadi tidak bisa berbelanja.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _note(
          'Kartu termahal di Pasar Pagimu hari ini yang belum kamu beli '
          'akan menjadi milikmu, gratis.',
        ),
        const SizedBox(height: 10),
        EmbunButton(
          label: 'Panggil pedagang',
          icon: 'store',
          expand: true,
          onPressed: busy ? null : _use,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = abilityAccent(_id);
    final kind = widget.def['kind'] == 'pasif' ? 'Pasif' : 'Sekali pakai';
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: OrnatePanel(
          accent: accent,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.intro) ...[
                  const Text(
                    'Kemampuan rahasiamu',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: EmbunColors.gold,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // Pengungkapan di awal: kartu muncul sebagai punggung
                // kemampuan, lalu berbalik.
                Center(
                  child: widget.intro
                      ? FlipCard(
                          index: 0,
                          width: 170,
                          height: 170 * abilityCardAspect,
                          revealed: true,
                          glow: _cardBlue,
                          backPath: abilityBackPath(),
                          backFit: BoxFit.contain,
                          front: AbilityCardView(
                            def: widget.def,
                            used: _usedNow,
                            width: 170,
                          ),
                        )
                      : AbilityCardView(
                          def: widget.def,
                          used: _usedNow,
                          width: 170,
                        ),
                ),
                const SizedBox(height: 14),
                Text(
                  '${widget.def['name']}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accent.withValues(alpha: 0.7)),
                    ),
                    child: Text(
                      kind,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${widget.def['description']}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                if (widget.intro)
                  _note(
                    'Hanya kamu yang tahu kemampuan ini. Kamu boleh '
                    'mengaku punya kemampuan apa pun, atau tidak sama sekali.',
                  ),
                const Divider(height: 24),
                _actions(),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: EmbunColors.blood,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                EmbunButton(
                  label: widget.intro ? 'Mengerti' : 'Tutup',
                  icon: 'silang',
                  kind: EmbunButtonKind.secondary,
                  height: 46,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
