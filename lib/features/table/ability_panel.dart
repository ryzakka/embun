import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';

/// Kemampuan acak khusus warga. Definisinya ada di tabel `ability_definitions`;
/// berkas ini hanya tampilan dan pemakaiannya.

IconData abilityIcon(String id) => switch (id) {
  'jangan_bohong' => Icons.visibility_rounded,
  'tumbuhan' => Icons.spa_rounded,
  'pedagang' => Icons.storefront_rounded,
  'lidah_manis' => Icons.record_voice_over_rounded,
  _ => Icons.person_outline_rounded,
};

Color abilityAccent(String id) => switch (id) {
  'jangan_bohong' => const Color(0xFF8FC1FF),
  'tumbuhan' => EmbunColors.leaf,
  'pedagang' => EmbunColors.gold,
  'lidah_manis' => const Color(0xFFE8A0C8),
  _ => EmbunColors.goldDim,
};

/// Kemampuan yang dipakai dengan menekan tombol (selain itu bekerja sendiri).
bool abilityIsManual(String id) => id == 'jangan_bohong' || id == 'pedagang';

/// Kartu kemampuan (rasio 3:4). Memakai gambar di assets/kartu/kemampuan bila
/// ada; bila belum, tampil sebagai kartu berikon.
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
    final h = width * 4 / 3;
    return Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1F3A33), Color(0xFF0C1B17)],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.85), width: 2),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 22),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (art != null)
              GameImage(path: art, cacheWidth: (width * 2).round())
            else
              Padding(
                padding: EdgeInsets.all(width * 0.08),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(abilityIcon(id), size: width * 0.38, color: accent),
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
                          fontSize: width * 0.075, color: Colors.white54),
                    ),
                  ],
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
                        horizontal: width * 0.08, vertical: width * 0.03),
                    decoration: BoxDecoration(
                      border: Border.all(color: EmbunColors.blood, width: 2.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('TERPAKAI',
                        style: TextStyle(
                            fontSize: width * 0.11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: EmbunColors.blood)),
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
      required VoidCallback onUsed,
      bool intro = false,
    }) =>
    showDialog<void>(
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

  Future<void> _use() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final r = await widget.repo.useAbility(widget.gameId, target: target);
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
    child: Text(text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12.5, height: 1.4, color: color)),
  );

  Widget _resultPanel() {
    final r = result!;
    final res = '${r['result']}';
    final (Color color, IconData icon) = switch (res) {
      'benar' => (EmbunColors.blood, Icons.warning_amber_rounded),
      'ragu' => (EmbunColors.gold, Icons.help_outline_rounded),
      'bukan' => (EmbunColors.leaf, Icons.check_circle_outline_rounded),
      _ => (EmbunColors.gold, Icons.storefront_rounded),
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
          Icon(icon, size: 36, color: color),
          const SizedBox(height: 6),
          if (isRead) ...[
            Text('Firasatmu tentang ${r['target']}',
                style: const TextStyle(fontSize: 12.5, color: Colors.white70)),
            const SizedBox(height: 4),
            Text('"${r['phrase']}"',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 6),
            const Text('Firasat bisa keliru. Hanya kamu yang mendengarnya.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: Colors.white54)),
          ] else
            Text('${r['message']}',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  /// Bagian bawah: penjelasan status atau tombol pemakaian.
  Widget _actions() {
    if (result != null) return _resultPanel();

    if (!abilityIsManual(_id)) {
      final text = switch (_id) {
        'tumbuhan' => 'Bekerja otomatis. Laju embunmu sudah naik sejak awal.',
        'lidah_manis' => _usedNow
            ? 'Sudah terpakai: tuduhan pertamamu sudah dilewati.'
            : 'Bekerja otomatis saat kamu pertama kali dituduh mayoritas.',
        _ => 'Tidak ada yang perlu dipakai. Kamu warga desa biasa.',
      };
      return _note(text);
    }

    if (_usedNow) return _note('Kemampuan ini sudah terpakai.');

    if (_id == 'jangan_bohong') {
      final can = widget.phase == 'day' || widget.phase == 'discussion';
      if (!can) {
        return _note(
            'Firasat hanya bisa didengar saat hari biasa atau musyawarah.');
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Pilih satu pemain:',
              style: TextStyle(fontSize: 12.5, color: EmbunColors.gold)),
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
        _note('Kartu termahal di Pasar Pagimu hari ini yang belum kamu beli '
            'akan menjadi milikmu, gratis.'),
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
                  const Text('Kemampuan rahasiamu',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: EmbunColors.gold)),
                  const SizedBox(height: 12),
                ],
                Center(
                    child: AbilityCardView(
                        def: widget.def, used: _usedNow, width: 170)),
                const SizedBox(height: 14),
                Text('${widget.def['name']}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: accent)),
                const SizedBox(height: 4),
                Center(
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accent.withValues(alpha: 0.7)),
                    ),
                    child: Text(kind,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: accent)),
                  ),
                ),
                const SizedBox(height: 10),
                Text('${widget.def['description']}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, height: 1.4)),
                if (widget.intro)
                  _note('Hanya kamu yang tahu kemampuan ini. Kamu boleh '
                      'mengaku punya kemampuan apa pun, atau tidak sama sekali.'),
                const Divider(height: 24),
                _actions(),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12.5, color: EmbunColors.blood)),
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