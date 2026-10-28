import 'package:flutter/material.dart';
import '../common/ornate.dart';

/// Status pemain dari baris `game_players`. Satu sumber kebenaran untuk
/// semua layar supaya penanda terkurung / nyawa / keluar selalu sama.
const kMaxStrikes = 2;

/// Sudah keluar dari desa (dituduh mayoritas dua kali).
bool isOut(Map<String, dynamic> p) => p['out_day'] != null;

/// Terkurung pada [day]: dari hari vonis sampai hari vote berikutnya.
bool isJailed(Map<String, dynamic> p, int day) {
  if (isOut(p)) return false;
  final from = p['jailed_day'] as int?;
  if (from == null) return false;
  final until = (p['jailed_until'] as int?) ?? from;
  return from <= day && day <= until;
}

/// Hari terakhir kurungan (hari vote berikutnya), atau null.
int? jailUntil(Map<String, dynamic> p) =>
    (p['jailed_until'] as int?) ?? (p['jailed_day'] as int?);

int strikesOf(Map<String, dynamic> p) => (p['strikes'] as int?) ?? 0;

int livesLeft(Map<String, dynamic> p) =>
    (kMaxStrikes - strikesOf(p)).clamp(0, kMaxStrikes).toInt();

/// Nyawa sebagai deretan hati: penuh = masih ada, kosong = sudah hilang.
class LivesRow extends StatelessWidget {
  final int lives;
  final double size;
  const LivesRow({super.key, required this.lives, this.size = 12});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Sisa $lives nyawa',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < kMaxStrikes; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 1),
            child: Icon(
              i < lives
                  ? Icons.favorite_rounded
                  : Icons.heart_broken_rounded,
              size: size,
              color: i < lives ? EmbunColors.blood : Colors.white30,
            ),
          ),
      ],
    ),
  );
}

/// Label kecil bergaris untuk status: "Dikurung", "Keluar".
class StatusTag extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  final double fontSize;
  const StatusTag({
    super.key,
    required this.text,
    required this.color,
    this.icon,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.8)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: fontSize + 1, color: color),
          const SizedBox(width: 3),
        ],
        Text(text,
            style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    ),
  );
}