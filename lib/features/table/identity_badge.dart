import 'package:flutter/material.dart';
import '../common/art.dart';
import '../common/ornate.dart';

/// Warna peran. Hijau = Warga, ungu = Si Terbisik. Dipakai konsisten di
/// kartu identitas, cincin avatar, dan lencana peran supaya peran pemain
/// terbaca sekilas tanpa harus membuka "Infoku".
class RoleColors {
  static const warga = Color(0xFF6FBF73);
  static const terbisik = Color(0xFFB07CE8);
  static Color of(bool dark) => dark ? terbisik : warga;
}

/// Kartu identitas pemain di bilah atas layar hari.
///
/// Hierarki dari atas ke bawah:
///  1. lencana peran berwarna penuh ("WARGA" / "SI TERBISIK"),
///  2. nama karakter yang dipegang (mis. "Pandai Besi"),
///  3. nama pemain, atau keterangan samaran (hanya bila [compact] false).
///
/// Latar dan bingkai memakai warna peran, jadi tampil jelas tanpa perlu
/// disentuh atau difokuskan. Ketuk untuk membuka Infoku.
class IdentityBadge extends StatelessWidget {
  final String? avatarPath;

  /// true = tampil sebagai Si Terbisik (wajah gelap), false = warga.
  final bool dark;
  final String characterName;
  final String? playerName;

  /// Baris kecil tambahan, mis. "Samaran: Pandai Besi".
  final String? hint;

  /// Ringkas untuk ponsel: avatar lebih kecil, tanpa baris nama pemain.
  final bool compact;
  final VoidCallback? onTap;

  const IdentityBadge({
    super.key,
    required this.avatarPath,
    required this.dark,
    required this.characterName,
    this.playerName,
    this.hint,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = RoleColors.of(dark);
    final role = dark ? 'SI TERBISIK' : 'WARGA';
    final avatar = compact ? 44.0 : 56.0;
    final sub = compact ? null : (hint ?? playerName);

    return Semantics(
      button: onTap != null,
      label: 'Perananmu: ${dark ? 'Si Terbisik' : 'Warga'}, $characterName',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(6, 6, compact ? 10 : 14, 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                c.withValues(alpha: 0.30),
                c.withValues(alpha: 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.withValues(alpha: 0.9), width: 1.6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlayerAvatar(path: avatarPath, size: avatar, ring: c),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            dark
                                ? Icons.visibility_off_rounded
                                : Icons.park_rounded,
                            size: 12,
                            color: const Color(0xFF0B1410),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            role,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              color: Color(0xFF0B1410),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      characterName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 14 : 16,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        color: EmbunColors.cream,
                      ),
                    ),
                    if (sub != null && sub.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11.5, color: Colors.white70),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}