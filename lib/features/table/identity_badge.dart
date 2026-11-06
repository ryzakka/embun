import 'package:flutter/material.dart';
import '../common/art.dart';
import '../common/ornate.dart';

/// Warna peran: hijau = Warga, ungu = Si Terbisik.
class RoleColors {
  static const warga = Color(0xFF6FBF73);
  static const terbisik = Color(0xFFB07CE8);
  static Color of(bool dark) => dark ? terbisik : warga;
}

/// Identitas pemain, tanpa kotak: avatar bercincin warna peran, di sampingnya
/// label peran kecil berwarna (titik + "WARGA" / "SI TERBISIK") lalu nama
/// karakter yang tebal. Warna dan ukuran yang membawa hierarki, bukan bingkai.
/// Ketuk untuk membuka Infoku.
class IdentityBadge extends StatelessWidget {
  final String? avatarPath;
  final bool dark;
  final String characterName;
  final String? playerName;
  final String? hint;
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
    final sub = compact ? null : (hint ?? playerName);
    return Semantics(
      button: onTap != null,
      label: 'Perananmu: ${dark ? 'Si Terbisik' : 'Warga'}, $characterName',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayerAvatar(path: avatarPath, size: compact ? 40 : 50, ring: c),
            const SizedBox(width: 9),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration:
                        BoxDecoration(color: c, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        dark ? 'SI TERBISIK' : 'WARGA',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: c,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    characterName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 15 : 17,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      color: EmbunColors.cream,
                    ),
                  ),
                  if (sub != null && sub.isNotEmpty)
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11.5, color: Colors.white70),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}