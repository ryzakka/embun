import 'package:flutter/foundation.dart';

/// Saklar tunggal untuk SEMUA efek berbasis shader (kain terhempas, dan efek
/// shader lain yang menyusul). Bawaannya menyala. Bila dimatikan, setiap
/// efek kembali ke tampilan biasa seperti sebelum ada shader.
///
/// Diubah dari menu beranda (lobi), sama seperti tombol suara. Tiap efek
/// membaca nilainya saat akan diputar, jadi tidak perlu memulai ulang.
class ShaderFx {
  ShaderFx._();

  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);
}