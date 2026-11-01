import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Warna dasar SEMUA adegan layar penuh (pembukaan suara, kurungan,
/// pengusiran, malam, fajar, menuju Hayu, pelemparan kartu).
///
/// Aturan sambungan antar adegan:
///  * setiap adegan MEMUDAR KELUAR ke [kSceneInk], dan
///  * setiap adegan MEMUDAR MASUK dari [kSceneInk], dengan latar yang
///    selalu buram (tidak pernah memakai Opacity pada seluruh adegan),
/// sehingga saat satu adegan diganti adegan berikutnya, layar meja di
/// bawahnya tidak sempat berkedip dan tidak ada lompatan warna.
const Color kSceneInk = Color(0xFF05080F);

/// Lama pemudaran masuk / keluar antar adegan (ms).
const int kSceneFadeInMs = 550;
const int kSceneFadeOutMs = 600;

/// Waktu baca yang pantas untuk [text] (ms): tahan dasar + per huruf, dengan
/// batas bawah dan atas. Dipakai untuk menentukan lama sebuah teks bertahan
/// di layar sebelum adegan boleh berpindah.
int readMs(String? text,
    {int base = 700, int perChar = 55, int min = 1800, int max = 8000}) {
  final n = (text ?? '').trim().length;
  return (base + n * perChar).clamp(min, max).toInt();
}

/// Lapisan penutup gelap [kSceneInk] dengan keburaman [a] (0..1).
Widget sceneVeil(double a) {
  if (a <= 0.004) return const SizedBox.shrink();
  return IgnorePointer(
    child: ColoredBox(
      color: kSceneInk.withValues(alpha: math.min(1.0, a)),
      child: const SizedBox.expand(),
    ),
  );
}

/// Kemajuan 0..1 dari [ms] di antara [a] dan [b] (ms), dihaluskan.
double fadeMs(double ms, double a, double b) {
  final x = ((ms - a) / (b - a)).clamp(0.0, 1.0).toDouble();
  return x * x * (3 - 2 * x);
}