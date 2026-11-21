import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/melody_asset_variants.dart';

/// Basenames accept WebP or PNG. Bounds affect layout only; files are not edited.
class MelodyArtSpec {
  const MelodyArtSpec(this.path, this.crop, this.decodeWidth, this.aspect);
  final String path;
  final Rect crop;
  final int decodeWidth;
  final double aspect;
}

const melodyArtSpecs = <String, MelodyArtSpec>{
  'titlekalkulasimelodi': MelodyArtSpec(
    'assets/title/titlekalkulasimelodi.png',
    Rect.fromLTRB(0.00782881, 0.00000000, 0.99269311, 0.99756395),
    1024,
    2.30402930,
  ),
  'titlepelataranmelodi': MelodyArtSpec(
    'assets/title/titlepelataranmelodi.png',
    Rect.fromLTRB(0.00000000, 0.00000000, 1.00000000, 1.00000000),
    1024,
    2.66666667,
  ),
  'melodi-petihadiahbuka': MelodyArtSpec(
    'assets/bentang/melodi-petihadiahbuka.png',
    Rect.fromLTRB(0.00000000, 0.00000000, 1.00000000, 1.00000000),
    1024,
    1.77577046,
  ),
  'melodi-petihadiahtutup': MelodyArtSpec(
    'assets/bentang/melodi-petihadiahtutup.png',
    Rect.fromLTRB(0.00000000, 0.00000000, 1.00000000, 1.00000000),
    1024,
    1.77683316,
  ),
  'melodi-angka1': MelodyArtSpec(
    'assets/indikator/melodi-angka1.png',
    Rect.fromLTRB(0.18819777, 0.01913876, 0.82934609, 0.96092504),
    384,
    0.68077900,
  ),
  'melodi-angka2': MelodyArtSpec(
    'assets/indikator/melodi-angka2.png',
    Rect.fromLTRB(0.11483254, 0.02711324, 0.86124402, 0.96570973),
    384,
    0.79524214,
  ),
  'melodi-angka3': MelodyArtSpec(
    'assets/indikator/melodi-angka3.png',
    Rect.fromLTRB(0.10446571, 0.01993620, 0.85566188, 0.99122807),
    384,
    0.77339901,
  ),
  'melodi-garismelodi': MelodyArtSpec(
    'assets/indikator/melodi-garismelodi.png',
    Rect.fromLTRB(0.00341797, 0.27126100, 0.99218750, 0.71407625),
    1024,
    6.70529801,
  ),
  'melodi-timeout': MelodyArtSpec(
    'assets/indikator/melodi-timeout.png',
    Rect.fromLTRB(0.01754386, 0.01381215, 0.99035088, 0.96685083),
    512,
    1.60724638,
  ),
  'melodi-go': MelodyArtSpec(
    'assets/indikator/melodi-go.png',
    Rect.fromLTRB(0.00604230, 0.11049724, 0.98388721, 0.92541436),
    512,
    1.64576271,
  ),
  'melodi-ready': MelodyArtSpec(
    'assets/indikator/melodi-ready.png',
    Rect.fromLTRB(0.03369141, 0.02199413, 0.96533203, 0.98533724),
    512,
    2.90410959,
  ),
  'melodi-break': MelodyArtSpec(
    'assets/indikator/melodi-break.png',
    Rect.fromLTRB(0.05273438, 0.01466276, 0.94873047, 0.96774194),
    512,
    2.82307692,
  ),
  'melodi-good': MelodyArtSpec(
    'assets/indikator/melodi-good.png',
    Rect.fromLTRB(0.09228516, 0.02102497, 0.92236328, 0.98817346),
    512,
    2.30978261,
  ),
  'melodi-perfect': MelodyArtSpec(
    'assets/indikator/melodi-perfect.png',
    Rect.fromLTRB(0.03857422, 0.04105572, 0.96630859, 0.96920821),
    512,
    3.00157978,
  ),
  'melodi-best': MelodyArtSpec(
    'assets/indikator/melodi-best.png',
    Rect.fromLTRB(0.08290422, 0.06551298, 0.92687951, 0.95550062),
    256,
    2.27638889,
  ),
  'melodi-combo': MelodyArtSpec(
    'assets/indikator/melodi-combo.png',
    Rect.fromLTRB(0.05419922, 0.07038123, 0.95117188, 0.93255132),
    256,
    3.12414966,
  ),
  'melodi-bolakuning': MelodyArtSpec(
    'assets/indikator/melodi-bolakuning.png',
    Rect.fromLTRB(0.09170654, 0.10127592, 0.89234450, 0.91228070),
    256,
    0.98721731,
  ),
  'melodi-bolahijau': MelodyArtSpec(
    'assets/indikator/melodi-bolahijau.png',
    Rect.fromLTRB(0.08293461, 0.09649123, 0.89952153, 0.92185008),
    256,
    0.98937198,
  ),
  'melodi-bolamerah': MelodyArtSpec(
    'assets/indikator/melodi-bolamerah.png',
    Rect.fromLTRB(0.13460016, 0.13322632, 0.85827395, 0.87640449),
    256,
    0.98704104,
  ),
  'melodi-bolabiru': MelodyArtSpec(
    'assets/indikator/melodi-bolabiru.png',
    Rect.fromLTRB(0.13855899, 0.13402889, 0.85589865, 0.87720706),
    256,
    0.97840173,
  ),
};
// Retain the original pillar order: Tanah, Akar, Batang, Daun (D F J K).
const melodyLaneArt = [
  'melodi-bolakuning',
  'melodi-bolabiru',
  'melodi-bolamerah',
  'melodi-bolahijau',
];

/// At most twenty downsampled images, shared across the table and its painters.
/// All loading happens outside paint; decoded images never reset game or audio.
class MelodyArtCache extends ChangeNotifier {
  static final shared = MelodyArtCache();
  final Map<String, ui.Image> _images = {};
  final Map<String, Future<void>> _pending = {};
  final Set<String> _missing = {};
  late final Future<Set<String>?> _availableAssets = _readAssetManifest();

  Future<Set<String>?> _readAssetManifest() async {
    try {
      return (await AssetManifest.loadFromAssetBundle(
        rootBundle,
      )).listAssets().toSet();
    } catch (_) {
      // Loading individual assets still works if a manifest is unavailable.
      return null;
    }
  }

  bool has(String key) => _images.containsKey(key);
  Future<void> load(String key) {
    if (has(key) || _missing.contains(key)) return Future.value();
    return _pending.putIfAbsent(key, () => _decode(key));
  }

  Future<void> _decode(String key) async {
    final spec = melodyArtSpecs[key];
    if (spec == null) return;
    final available = await _availableAssets;
    final image = await loadMelodyAssetVariant<ui.Image>(spec.path, (
      path,
    ) async {
      ui.Codec? codec;
      try {
        final bytes = await rootBundle.load(path);
        codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          targetWidth: spec.decodeWidth,
        );
        return (await codec.getNextFrame()).image;
      } finally {
        codec?.dispose();
      }
    }, available: available);
    if (image == null) {
      _missing.add(key);
      return;
    }
    _images[key] = image;
    notifyListeners();
  }

  void prepareGameplay() {
    for (final key in [
      ...melodyLaneArt,
      'melodi-perfect',
      'melodi-good',
      'melodi-break',
      'melodi-combo',
      'melodi-best',
      'melodi-garismelodi',
      'melodi-ready',
      'melodi-angka3',
      'melodi-angka2',
      'melodi-angka1',
      'melodi-go',
      'melodi-timeout',
    ]) {
      unawaited(load(key));
    }
  }

  bool paint(
    Canvas c,
    String key,
    Rect bounds, {
    double opacity = 1,
    BoxFit fit = BoxFit.contain,
  }) {
    final im = _images[key], spec = melodyArtSpecs[key];
    if (im == null || spec == null || bounds.isEmpty || opacity <= 0) {
      return false;
    }
    final norm = spec.crop;
    final source = Rect.fromLTRB(
      norm.left * im.width,
      norm.top * im.height,
      norm.right * im.width,
      norm.bottom * im.height,
    );
    final fitted = applyBoxFit(fit, source.size, bounds.size);
    final src = Alignment.center.inscribe(fitted.source, source);
    final dst = Alignment.center.inscribe(fitted.destination, bounds);
    c.drawImageRect(
      im,
      src,
      dst,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0)),
    );
    return true;
  }
}

/// A measured, accessible image with a readable fallback while loading or when
/// an optional asset is absent. This never changes input or timing behavior.
class MelodyArtView extends StatelessWidget {
  const MelodyArtView(
    this.art, {
    super.key,
    this.width,
    required this.height,
    required this.label,
    this.fallback,
    this.fit = BoxFit.contain,
  });
  final String art, label;
  final double? width;
  final double height;
  final Widget? fallback;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    final cache = MelodyArtCache.shared;
    unawaited(cache.load(art));
    return Semantics(
      image: true,
      label: label,
      child: ExcludeSemantics(
        child: SizedBox(
          width: width ?? height * (melodyArtSpecs[art]?.aspect ?? 1),
          height: height,
          child: AnimatedBuilder(
            animation: cache,
            builder: (_, _) => cache.has(art)
                ? CustomPaint(painter: _MelodyArtPainter(art, fit))
                : Center(
                    child:
                        fallback ??
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFF3E9C6),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _MelodyArtPainter extends CustomPainter {
  _MelodyArtPainter(this.keyName, this.fit);
  final String keyName;
  final BoxFit fit;
  @override
  void paint(Canvas canvas, Size size) => MelodyArtCache.shared.paint(
    canvas,
    keyName,
    Offset.zero & size,
    fit: fit,
  );
  @override
  bool shouldRepaint(_MelodyArtPainter old) => true;
}

class MelodyCounterArt extends StatelessWidget {
  const MelodyCounterArt({
    super.key,
    required this.combo,
    required this.best,
    this.compact = false,
  });
  final int combo, best;
  final bool compact;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 18,
    runSpacing: 4,
    children: [
      for (final row in [
        ('melodi-combo', 'Combo', combo),
        ('melodi-best', 'Best', best),
      ])
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MelodyArtView(
              row.$1,
              width: compact ? 58 : 76,
              height: compact ? 22 : 28,
              label: row.$2,
            ),
            const SizedBox(width: 7),
            Text(
              '${row.$3}',
              style: TextStyle(
                color: const Color(0xFFF3E9C6),
                fontSize: compact ? 19 : 23,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
    ],
  );
}

/// Presentation only. The server has already credited this reward exactly once.
class MelodyRewardChest extends StatefulWidget {
  const MelodyRewardChest({
    super.key,
    required this.child,
    this.reduced = false,
  });
  final Widget child;
  final bool reduced;
  @override
  State<MelodyRewardChest> createState() => _MelodyRewardChestState();
}

class _MelodyRewardChestState extends State<MelodyRewardChest> {
  bool _opened = false;
  @override
  void initState() {
    super.initState();
    unawaited(MelodyArtCache.shared.load('melodi-petihadiahtutup'));
    unawaited(MelodyArtCache.shared.load('melodi-petihadiahbuka'));
  }

  void _open() {
    if (!_opened) setState(() => _opened = true);
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Semantics(
        button: !_opened,
        label: _opened
            ? 'Peti hadiah terbuka'
            : 'Buka peti untuk melihat hadiah',
        child: InkWell(
          onTap: _opened ? null : _open,
          borderRadius: BorderRadius.circular(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 1672 / 941,
              child: LayoutBuilder(
                builder: (_, box) => AnimatedSwitcher(
                  duration: Duration(milliseconds: widget.reduced ? 0 : 450),
                  child: MelodyArtView(
                    _opened
                        ? 'melodi-petihadiahbuka'
                        : 'melodi-petihadiahtutup',
                    key: ValueKey(_opened),
                    width: box.maxWidth,
                    height: box.maxHeight,
                    label: _opened
                        ? 'Peti hadiah terbuka'
                        : 'Peti hadiah tertutup',
                    fit: BoxFit.cover,
                    fallback: Center(
                      child: Icon(
                        _opened ? Icons.redeem : Icons.card_giftcard,
                        size: 64,
                        color: const Color(0xFFE8C766),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      if (!_opened)
        TextButton(
          onPressed: _open,
          child: const Text('Ketuk peti untuk melihat hadiah'),
        ),
      if (_opened) widget.child,
    ],
  );
}
