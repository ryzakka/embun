import 'package:flutter/material.dart';
import 'art.dart';

/// Palet diambil dari ikon: hijau hutan gelap, emas, dan krem.
class EmbunColors {
  static const bg = Color(0xFF07130F);
  static const panel = Color(0xFF0F2420);
  static const panelHi = Color(0xFF173A30);
  static const gold = Color(0xFFE8C766);
  static const goldDim = Color(0xFF9C8442);
  static const cream = Color(0xFFF3E9C6);
  static const leaf = Color(0xFF7FE0A0);
  static const mist = Color(0xFFB07CE8);
  static const blood = Color(0xFFE5645A);
}

OutlineInputBorder _ob(Color c, [double w = 1]) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(12),
  borderSide: BorderSide(color: c, width: w),
);

/// Tema seluruh aplikasi: tombol, kolom isian, chip, sheet, dan snackbar
/// ikut gaya emas-hijau supaya serasi dengan ikon medali.
ThemeData embunTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF3E8E7E),
      brightness: Brightness.dark,
    ).copyWith(
      primary: EmbunColors.gold,
      onPrimary: const Color(0xFF1A1405),
      secondary: EmbunColors.leaf,
      surface: EmbunColors.panel,
      onSurface: EmbunColors.cream,
      outline: EmbunColors.goldDim,
    ),
  );
  RoundedRectangleBorder shape(Color edge) => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
    side: BorderSide(color: edge, width: 1.5),
  );
  return base.copyWith(
    scaffoldBackgroundColor: EmbunColors.bg,
    textTheme: base.textTheme
        .apply(bodyColor: EmbunColors.cream, displayColor: EmbunColors.gold),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF245C40),
        foregroundColor: EmbunColors.cream,
        disabledBackgroundColor: const Color(0xFF16221E),
        disabledForegroundColor: Colors.white30,
        shape: shape(EmbunColors.gold.withValues(alpha: 0.7)),
        minimumSize: const Size(0, 48),
        textStyle:
        const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: EmbunColors.gold,
        disabledForegroundColor: Colors.white30,
        shape: shape(EmbunColors.goldDim),
        minimumSize: const Size(0, 48),
        textStyle:
        const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.4),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: EmbunColors.gold),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.black.withValues(alpha: 0.35),
      selectedColor: EmbunColors.gold.withValues(alpha: 0.22),
      side: BorderSide(color: EmbunColors.goldDim.withValues(alpha: 0.6)),
      labelStyle: const TextStyle(color: EmbunColors.cream),
      checkmarkColor: EmbunColors.gold,
      shape: const StadiumBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.35),
      border: _ob(EmbunColors.goldDim.withValues(alpha: 0.5)),
      enabledBorder: _ob(EmbunColors.goldDim.withValues(alpha: 0.5)),
      focusedBorder: _ob(EmbunColors.gold, 1.6),
      labelStyle: const TextStyle(color: Colors.white60),
      hintStyle: const TextStyle(color: Colors.white38),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: EmbunColors.panel,
      modalBackgroundColor: EmbunColors.panel,
      showDragHandle: true,
      dragHandleColor: EmbunColors.goldDim,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        side: BorderSide(
            color: EmbunColors.goldDim.withValues(alpha: 0.7), width: 1.5),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF14301F),
      contentTextStyle: const TextStyle(color: EmbunColors.cream),
      shape: shape(EmbunColors.goldDim),
    ),
    dividerTheme: DividerThemeData(
      color: EmbunColors.goldDim.withValues(alpha: 0.35),
      thickness: 1,
    ),
    progressIndicatorTheme:
    const ProgressIndicatorThemeData(color: EmbunColors.gold),
    listTileTheme: const ListTileThemeData(iconColor: EmbunColors.gold),
  );
}

/// Panel berbingkai emas dengan paku di keempat sudut, meniru punggung kartu.
class OrnatePanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color accent;
  final double opacity;
  const OrnatePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.accent = EmbunColors.gold,
    this.opacity = 0.92,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          EmbunColors.panelHi.withValues(alpha: opacity),
          EmbunColors.panel.withValues(alpha: opacity),
        ],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.5),
      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14)],
    ),
    child: CustomPaint(
      foregroundPainter: _FramePainter(accent, radius),
      child: Padding(padding: padding, child: child),
    ),
  );
}

class _FramePainter extends CustomPainter {
  final Color c;
  final double radius;
  _FramePainter(this.c, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(
      Rect.fromLTWH(5, 5, size.width - 10, size.height - 10),
      Radius.circular((radius - 4).clamp(2.0, 40.0).toDouble()),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = c.withValues(alpha: 0.18),
    );
    final dot = Paint()..color = c.withValues(alpha: 0.7);
    for (final o in [
      const Offset(11, 11),
      Offset(size.width - 11, 11),
      Offset(11, size.height - 11),
      Offset(size.width - 11, size.height - 11),
    ]) {
      canvas.drawCircle(o, 2, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _FramePainter old) =>
      old.c != c || old.radius != radius;
}

/// Judul bagian: ikon medali di kiri, teks emas, garis emas memudar di bawah.
/// Ikon dibuat cukup besar (>= 26) supaya hiasan medalinya masih terbaca.
class SectionHeader extends StatelessWidget {
  final String? icon;
  final String title;
  final Widget? trailing;
  final double iconSize;
  const SectionHeader({
    super.key,
    this.icon,
    required this.title,
    this.trailing,
    this.iconSize = 30,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          if (icon != null) ...[
            GameIcon(icon!, size: iconSize),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: EmbunColors.gold,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.8,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
      const SizedBox(height: 4),
      Container(
        height: 1.5,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            EmbunColors.gold.withValues(alpha: 0.8),
            EmbunColors.gold.withValues(alpha: 0),
          ]),
        ),
      ),
    ],
  );
}

/// Aksi berbentuk medali: ikon besar dengan keterangan di bawahnya.
/// Dipakai untuk aksi kecil yang berdiri sendiri (kirim, salin, riwayat,
/// beri embun, lewati). Nonaktif = abu-abu dan pudar; ditekan = mengecil.
/// [clip] memotong ikon menjadi bulat di atas latar hijau gelap, jadi kotak
/// hitam di sudut ikon yang belum transparan tidak kelihatan.
class MedallionButton extends StatefulWidget {
  final String icon;
  final String? label;
  final VoidCallback? onTap;
  final double size;
  final bool selected;
  final String? badge;
  final bool clip;
  const MedallionButton({
    super.key,
    required this.icon,
    this.label,
    required this.onTap,
    this.size = 44,
    this.selected = false,
    this.badge,
    this.clip = true,
  });

  @override
  State<MedallionButton> createState() => _MedallionButtonState();
}

class _MedallionButtonState extends State<MedallionButton> {
  bool _down = false;

  void _set(bool v) {
    if (mounted && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final on = w.onTap != null;
    Widget icon = GameIcon(w.icon, size: w.size);
    if (w.clip) {
      icon = ClipOval(
        child: ColoredBox(color: const Color(0xFF0A1A15), child: icon),
      );
    }
    if (!on) {
      icon = Opacity(
        opacity: 0.45,
        child: ColorFiltered(
          colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
          child: icon,
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: w.onTap,
      onTapDown: on ? (_) => _set(true) : null,
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.9 : 1,
        duration: const Duration(milliseconds: 90),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 52, minHeight: 44),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: w.selected
                          ? [
                        BoxShadow(
                          color: EmbunColors.gold.withValues(alpha: 0.55),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ]
                          : null,
                    ),
                    child: icon,
                  ),
                  if (w.badge != null)
                    Positioned(
                      right: -4,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: EmbunColors.gold,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          w.badge!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1405),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (w.label != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    w.label!,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      color: w.selected ? EmbunColors.gold : Colors.white70,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum EmbunButtonKind { primary, secondary, danger }

/// Tombol utama bergaya medali: ikon besar di kiri, label tebal, bingkai
/// emas. Tingginya sengaja 52 supaya ikon bisa 32 px dan tetap terbaca.
class EmbunButton extends StatelessWidget {
  final String label;
  final String? icon;
  final VoidCallback? onPressed;
  final EmbunButtonKind kind;
  final bool expand;
  final double height;
  const EmbunButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.kind = EmbunButtonKind.primary,
    this.expand = false,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final on = onPressed != null;
    final List<Color> fill;
    final Color edge;
    switch (kind) {
      case EmbunButtonKind.primary:
        fill = const [Color(0xFF2E7350), Color(0xFF173F2E)];
        edge = EmbunColors.gold;
      case EmbunButtonKind.secondary:
        fill = const [Color(0xFF16231F), Color(0xFF0C1714)];
        edge = EmbunColors.goldDim;
      case EmbunButtonKind.danger:
        fill = const [Color(0xFF6A2330), Color(0xFF3A1019)];
        edge = EmbunColors.blood;
    }
    final radius = BorderRadius.circular(16);
    Widget? ic = icon == null ? null : GameIcon(icon!, size: height * 0.62);
    if (!on && ic != null) {
      ic = Opacity(
        opacity: 0.45,
        child: ColorFiltered(
          colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
          child: ic,
        ),
      );
    }
    final body = Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: on
              ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: fill,
          )
              : null,
          color: on ? null : const Color(0xFF16201C),
          borderRadius: radius,
          border: Border.all(
            color: on ? edge.withValues(alpha: 0.85) : Colors.white12,
            width: 1.5,
          ),
          boxShadow: on
              ? [BoxShadow(color: edge.withValues(alpha: 0.18), blurRadius: 10)]
              : null,
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (ic != null) ...[ic, const SizedBox(width: 10)],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.5,
                        color: on ? EmbunColors.cream : Colors.white38,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: body) : body;
  }
}

/// Kotak pemberitahuan (petunjuk, rahasia, peringatan) dengan ikon medali.
class NoticeStrip extends StatelessWidget {
  final String icon;
  final String text;
  final Color accent;
  const NoticeStrip({
    super.key,
    required this.icon,
    required this.text,
    this.accent = EmbunColors.gold,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: accent.withValues(alpha: 0.7)),
    ),
    child: Row(
      children: [
        GameIcon(icon, size: 30),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
      ],
    ),
  );
}