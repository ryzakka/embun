import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'shader_fx.dart';

/// Pemuat shader efek adegan (selain kain, yang dipegang ClothTransition).
///
/// Semua program dimuat sekali di main(). Tiap adegan membuat instans
/// shader-nya sendiri lewat [make] dan membuangnya di dispose(). Bila efek
/// dimatikan lewat [ShaderFx.enabled] atau programnya gagal dimuat, [make]
/// mengembalikan null: adegan harus memakai painter lamanya.
class FxShaders {
  FxShaders._();

  static ui.FragmentProgram? atmosphere; // kabut + asap kelam
  static ui.FragmentProgram? cardMorph; // kartu baik larut ke kartu gelap
  static ui.FragmentProgram? omenSky; // awan bercahaya petir
  static ui.FragmentProgram? divine; // berkas cahaya + kilau foil
  static ui.FragmentProgram? voteReveal; // kabut tegang + hantaman + vonis

  static Future<void> preload() async {
    Future<ui.FragmentProgram?> load(String asset) async {
      try {
        return await ui.FragmentProgram.fromAsset(asset);
      } catch (e) {
        debugPrint('Shader $asset gagal dimuat, memakai efek lama: $e');
        return null;
      }
    }

    final r = await Future.wait([
      load('shaders/atmosphere.frag'),
      load('shaders/card_morph.frag'),
      load('shaders/omen_sky.frag'),
      load('shaders/divine.frag'),
      load('shaders/vote_reveal.frag'),
    ]);
    atmosphere = r[0];
    cardMorph = r[1];
    omenSky = r[2];
    divine = r[3];
    voteReveal = r[4];
  }

  /// Instans shader baru, atau null bila efek dimatikan / program tak ada.
  static ui.FragmentShader? make(ui.FragmentProgram? program) =>
      ShaderFx.enabled.value ? program?.fragmentShader() : null;

  static final Map<String, ui.Image> _images = {};

  /// Memuat gambar aset sebagai [ui.Image] untuk sampler shader. Hasilnya
  /// disimpan (tidak perlu dibuang). Null bila gagal.
  static Future<ui.Image?> image(String? path, {int width = 640}) async {
    if (path == null) return null;
    final hit = _images[path];
    if (hit != null) return hit;
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
          targetWidth: width);
      final frame = await codec.getNextFrame();
      codec.dispose();
      _images[path] = frame.image;
      return frame.image;
    } catch (e) {
      debugPrint('Gambar $path gagal dimuat untuk shader: $e');
      return null;
    }
  }
}