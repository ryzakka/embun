import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'ability_panel.dart';

/// Dialog "Infoku": ringkasan pilihan milik pemain sendiri selama permainan.
///
///  * Warga: karakter yang dipilih dan kemampuan acaknya (beserta status
///    terpakai).
///  * Si Terbisik: wajah asli (kartu gelap), wajah samaran yang dilihat desa,
///    dan, bila belum memilih samaran, penanda "Belum memilih".
///
/// Hanya dibaca dari data yang sudah dimuat meja; tidak ada permintaan baru
/// ke server. Isinya rahasia, jadi dialog memberi peringatan agar layar tidak
/// diperlihatkan ke pemain lain.
Future<void> showMyInfoDialog(
    BuildContext context, {
      required bool isAntag,
      required String name,
      required String characterStem,
      int? darkSeed,
      Map<String, dynamic>? abilityDef,
      bool abilityUsed = false,
    }) =>
    showDialog<void>(
      context: context,
      builder: (_) => _MyInfoDialog(
        isAntag: isAntag,
        name: name,
        characterStem: characterStem,
        darkSeed: darkSeed,
        abilityDef: abilityDef,
        abilityUsed: abilityUsed,
      ),
    );

class _MyInfoDialog extends StatelessWidget {
  final bool isAntag;
  final String name;
  final String characterStem;
  final int? darkSeed;
  final Map<String, dynamic>? abilityDef;
  final bool abilityUsed;

  const _MyInfoDialog({
    required this.isAntag,
    required this.name,
    required this.characterStem,
    required this.darkSeed,
    required this.abilityDef,
    required this.abilityUsed,
  });

  static const _purple = Color(0xFFB07CE8);
  static const double _cardW = 128;

  /// Satu kolom: judul kecil, kartu, lalu keterangan di bawahnya.
  Widget _slot({
    required String label,
    required Widget card,
    required String caption,
    String? sub,
    Color accent = EmbunColors.gold,
  }) =>
      SizedBox(
        width: _cardW + 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: accent,
              ),
            ),
            const SizedBox(height: 8),
            card,
            const SizedBox(height: 8),
            Text(
              caption,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13.5, height: 1.2, fontWeight: FontWeight.w700),
            ),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(sub,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11.5, color: Colors.white54)),
            ],
          ],
        ),
      );

  Widget _characterCard(String stem, {Color? glow}) => CardArt(
    path: protagonistPath(stem),
    width: _cardW,
    glow: glow,
  );

  List<Widget> _wargaSlots() {
    final def = abilityDef;
    final id = def == null ? 'biasa' : '${def['id']}';
    final accent = abilityAccent(id);
    return [
      _slot(
        label: 'KARAKTERMU',
        card: _characterCard(characterStem, glow: EmbunColors.leaf),
        caption: characterTitle(characterStem),
        sub: name,
        accent: EmbunColors.leaf,
      ),
      if (def != null)
        _slot(
          label: 'KEMAMPUANMU',
          card: AbilityCardView(def: def, used: abilityUsed, width: _cardW),
          caption: '${def['name']}',
          sub: abilityUsed
              ? 'Sudah terpakai'
              : (def['kind'] == 'pasif' ? 'Pasif' : 'Sekali pakai'),
          accent: accent,
        )
      else
        _slot(
          label: 'KEMAMPUANMU',
          card: SizedBox(
            width: _cardW,
            height: _cardW * kTallAspect,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24, width: 1.5),
              ),
              child: const Center(
                child: Icon(Icons.hourglass_empty_rounded,
                    color: Colors.white38, size: 32),
              ),
            ),
          ),
          caption: 'Belum diketahui',
          accent: Colors.white54,
        ),
    ];
  }

  List<Widget> _antagSlots() {
    final seed = darkSeed;
    final darkPath = seed == null ? null : darkCardPath(seed);
    final hasDisguise = characterStem != 'default';
    return [
      _slot(
        label: 'WAJAH ASLIMU',
        card: darkPath == null
            ? SizedBox(
          width: _cardW,
          height: _cardW * kAntagonisAspect,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              color: Color(0x22B07CE8),
            ),
            child: Center(
              child: Icon(Icons.visibility_off_rounded,
                  color: _purple, size: 34),
            ),
          ),
        )
            : CardArt(path: darkPath, width: _cardW, glow: _purple),
        caption: 'Si Terbisik',
        sub: 'Rahasia',
        accent: _purple,
      ),
      _slot(
        label: 'SAMARANMU',
        card: _characterCard(characterStem, glow: EmbunColors.gold),
        caption: hasDisguise ? characterTitle(characterStem) : 'Belum memilih',
        sub: hasDisguise ? 'Wajahmu di mata desa' : null,
        accent: EmbunColors.gold,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final accent = isAntag ? _purple : EmbunColors.leaf;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: OrnatePanel(
          accent: accent,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Infoku',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: EmbunColors.gold,
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withValues(alpha: 0.7)),
                    ),
                    child: Text(
                      isAntag ? 'Si Terbisik' : 'Warga Desa',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: accent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.start,
                  spacing: 14,
                  runSpacing: 18,
                  children: isAntag ? _antagSlots() : _wargaSlots(),
                ),
                if (!isAntag && abilityDef != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    '${abilityDef!['description']}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12.5, height: 1.4, color: Colors.white70),
                  ),
                ],
                if (isAntag) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Semua pemain hanya melihat wajah samaranmu. Wajah asli '
                        'tetap rahasia sampai permainan berakhir.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12.5, height: 1.4, color: Colors.white70),
                  ),
                ],
                const SizedBox(height: 10),
                const Text(
                  'Hanya kamu yang melihat ini. Jangan perlihatkan layarmu '
                      'ke pemain lain.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: Colors.white38),
                ),
                const Divider(height: 24),
                EmbunButton(
                  label: 'Tutup',
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