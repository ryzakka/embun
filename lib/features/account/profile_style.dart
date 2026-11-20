import '../common/embun_icon.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../common/art.dart';
import '../common/ornate.dart';

/// Bahan gaya bersama untuk papan medali, statistik, dan sheet profil.
/// Meniru halaman Panduan: terbuka tanpa kotak, garis emas tipis, judul
/// bagian berikon, pilihan berupa teks dengan garis bawah, kemunculan
/// berjenjang.

BorderSide profileRule([Color color = EmbunColors.gold]) =>
    BorderSide(color: color.withValues(alpha: 0.32));

const profileCaps = TextStyle(
  fontSize: 11,
  letterSpacing: 1.4,
  fontWeight: FontWeight.w600,
  color: Colors.white60,
);

/// Memudar, bergeser, dan membesar sedikit; bergiliran menurut [index].
class ProfileReveal extends StatefulWidget {
  const ProfileReveal({
    super.key,
    required this.child,
    this.index = 0,
    this.dx = 0,
    this.dy = 20,
    this.scaleFrom = 0.96,
  });
  final Widget child;
  final int index;
  final double dx, dy, scaleFrom;
  @override
  State<ProfileReveal> createState() => _ProfileRevealState();
}

class _ProfileRevealState extends State<ProfileReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final int ms = 70 * (widget.index > 8 ? 8 : widget.index);
    if (ms == 0) {
      _c.forward();
    } else {
      _timer = Timer(Duration(milliseconds: ms), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        if (_c.isCompleted) return child!;
        final v = Curves.easeOutCubic.transform(_c.value);
        final o = Curves.easeOut.transform(
          (_c.value / 0.55).clamp(0.0, 1.0).toDouble(),
        );
        return Opacity(
          opacity: o,
          child: Transform.translate(
            offset: Offset((1 - v) * widget.dx, (1 - v) * widget.dy),
            child: Transform.scale(
              scale: widget.scaleFrom + (1 - widget.scaleFrom) * v,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Latar bergambar untuk bottom sheet (sheetmedal-latar / sheetprofile-latar
/// di assets/bentang). Gambar menutup seluruh sheet (cover), diberi tirai
/// gelap rata agar teks terang terbaca. Bila gambar tidak ada, jatuh ke latar
/// polos. [fillHeight] true = tinggi tetap 92% layar (untuk isi yang memakai
/// Expanded); false = tinggi mengikuti isi, maksimal 92% layar.
class ProfileSheetFrame extends StatelessWidget {
  const ProfileSheetFrame({
    super.key,
    required this.asset,
    required this.child,
    this.fillHeight = false,
  });
  final String? asset;
  final Widget child;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.92;
    const plain = ColoredBox(color: EmbunColors.bg);
    final body = Stack(
      fit: fillHeight ? StackFit.expand : StackFit.loose,
      children: [
        Positioned.fill(
          child: asset == null
              ? plain
              : Image.asset(
                  asset!,
                  fit: BoxFit.cover,
                  cacheWidth: 1080,
                  errorBuilder: (_, _, _) => plain,
                ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xC707130F), Color(0xE607130F)],
              ),
            ),
          ),
        ),
        child,
      ],
    );
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: fillHeight
          ? SizedBox(height: maxH, child: body)
          : ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: body,
            ),
    );
  }
}

/// Bagian: garis atas, ikon + judul (+ keterangan kanan), lalu isi.
class ProfileSection extends StatelessWidget {
  const ProfileSection({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.accent = EmbunColors.gold,
    this.trailing,
  });
  final String icon, title;
  final String? trailing;
  final List<Widget> children;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 17),
    padding: const EdgeInsets.only(top: 8),
    decoration: BoxDecoration(border: Border(top: profileRule(accent))),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GameIcon(icon, size: 25),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white60,
                ),
              ),
          ],
        ),
        const SizedBox(height: 7),
        ...children,
      ],
    ),
  );
}

/// Baris info berikon dengan garis tipis di dasar.
class ProfileRow extends StatelessWidget {
  const ProfileRow({
    super.key,
    required this.visual,
    required this.title,
    this.text,
    this.label,
    this.extra,
    this.trailing,
    this.accent = EmbunColors.gold,
    this.titleColor = EmbunColors.cream,
    this.visualSize = 44,
    this.onTap,
  });
  final Widget visual;
  final String title;
  final String? text, label;
  final Widget? extra, trailing;
  final Color accent, titleColor;
  final double visualSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
        decoration: BoxDecoration(border: Border(bottom: profileRule(accent))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.square(
              dimension: visualSize,
              child: Center(child: visual),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label != null)
                    Text(label!, style: profileCaps.copyWith(fontSize: 10.5)),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                  if (text != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        text!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  if (extra != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: extra!,
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              Padding(padding: const EdgeInsets.only(top: 4), child: trailing!),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Garis kemajuan tipis, datar.
class ProfileMeter extends StatelessWidget {
  const ProfileMeter({
    super.key,
    required this.value,
    required this.color,
    this.height = 4,
  });
  final double value, height;
  final Color color;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height / 2),
    child: SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.white12),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value.clamp(0.0, 1.0).toDouble(),
            child: ColoredBox(color: color),
          ),
        ],
      ),
    ),
  );
}

/// Pilihan teks terbuka; garis bawah beraksen bila terpilih.
class ProfileTab extends StatelessWidget {
  const ProfileTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.accent,
    this.count,
    this.sub,
    this.icon,
    this.compact = false,
  });
  final String label;
  final String? count, sub, icon;
  final bool selected, compact;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final text = Text.rich(
      TextSpan(
        text: label,
        children: [
          if (count != null)
            TextSpan(
              text: '  $count',
              style: TextStyle(color: accent, fontWeight: FontWeight.w700),
            ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: compact ? TextAlign.center : TextAlign.start,
      style: TextStyle(
        fontSize: compact ? 12.5 : 15,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        color: selected ? accent : EmbunColors.cream,
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            border: Border(
              bottom: selected
                  ? BorderSide(color: accent, width: 2)
                  : profileRule(accent),
            ),
          ),
          child: InkWell(
            onTap: () {
              if (selected) return;
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 4 : 2,
                vertical: compact ? 9 : 11,
              ),
              child: compact
                  ? Center(widthFactor: 1, child: text)
                  : Row(
                      children: [
                        if (icon != null) ...[
                          GameIcon(icon!, size: 26),
                          const SizedBox(width: 9),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              text,
                              if (sub != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    sub!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      height: 1.25,
                                      color: Colors.white60,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Penyaring: judul emas, pilihan aktif di bawahnya, menu popup.
class ProfileFilter extends StatelessWidget {
  const ProfileFilter({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.accent,
  });
  final String title;
  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelect;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final sel = selected.clamp(0, options.length - 1).toInt();
    final active = sel != 0;
    return PopupMenuButton<int>(
      tooltip: title,
      initialValue: sel,
      color: EmbunColors.panel,
      onSelected: (i) {
        HapticFeedback.selectionClick();
        onSelect(i);
      },
      itemBuilder: (_) => [
        for (var i = 0; i < options.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Text(
              options[i],
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: i == sel ? FontWeight.w800 : FontWeight.w500,
                color: i == sel ? EmbunColors.gold : EmbunColors.cream,
              ),
            ),
          ),
      ],
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: active
                ? BorderSide(color: accent, width: 2)
                : profileRule(),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: EmbunColors.gold,
                      ),
                    ),
                    Text(
                      options[sel],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: active ? accent : Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              const EmbunIcon(
                Icons.keyboard_arrow_down,
                size: 20,
                color: EmbunColors.goldDim,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
