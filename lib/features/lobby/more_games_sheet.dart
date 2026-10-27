import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/asset_catalog.dart';
import '../common/art.dart';
import '../common/ornate.dart';

class _OtherGame {
  final String title;
  final String desc;
  final String url;
  final String logoStem; // assets/logo/<logoStem>.png
  const _OtherGame({
    required this.title,
    required this.desc,
    required this.url,
    required this.logoStem,
  });

  String get host => Uri.parse(url).host;
}

/// Daftar permainan lain dari pengembang. Tambah / ubah di sini saja.
const _games = <_OtherGame>[
  _OtherGame(
    title: 'Sampahnya!',
    desc: 'Bangun kamar, kelola limbah, atau timbun kost tetangga!',
    url: 'https://sampahnya.vercel.app/',
    logoStem: 'logo-sampahnya',
  ),
  _OtherGame(
    title: 'Linguistic Hegemony',
    desc: 'Mainkan langsung di peramban.',
    url: 'https://linguistify.vercel.app/',
    logoStem: 'logo-linguistichegemony',
  ),
];

/// Buka dialog "Permainan Lainnya".
Future<void> showMoreGames(BuildContext context) => showDialog<void>(
  context: context,
  builder: (ctx) => Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.all(20),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: OrnatePanel(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(icon: 'plus', title: 'Permainan Lainnya'),
              const SizedBox(height: 8),
              const Text(
                'Dari pengembang yang sama. Dibuka di peramban.',
                style: TextStyle(fontSize: 12.5, color: Colors.white60),
              ),
              const SizedBox(height: 12),
              for (final g in _games)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _GameCard(game: g),
                ),
              const SizedBox(height: 2),
              EmbunButton(
                label: 'Tutup',
                icon: 'silang',
                kind: EmbunButtonKind.secondary,
                expand: true,
                height: 46,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

Future<void> _open(BuildContext context, _OtherGame g) async {
  final messenger = ScaffoldMessenger.of(context);
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse(g.url),
        mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok) {
    // Tidak ada peramban / diblokir: salin tautan supaya bisa ditempel sendiri.
    await Clipboard.setData(ClipboardData(text: g.url));
    messenger.showSnackBar(const SnackBar(
        content: Text('Tidak bisa membuka peramban. Tautan disalin.')));
  }
}

class _GameCard extends StatelessWidget {
  final _OtherGame game;
  const _GameCard({required this.game});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.28),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: EmbunColors.goldDim.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        onTap: () => _open(context, game),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 76,
                height: 76,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: EmbunColors.goldDim.withValues(alpha: 0.5)),
                ),
                child: GameImage(
                  path: logoPath(game.logoStem),
                  fit: BoxFit.contain,
                  cacheWidth: 300,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                        color: EmbunColors.gold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      game.desc,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, height: 1.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      game.host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white38),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.open_in_new_rounded,
                  size: 20, color: EmbunColors.gold),
            ],
          ),
        ),
      ),
    );
  }
}