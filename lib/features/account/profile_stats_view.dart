import '../common/embun_icon.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/profile_medals.dart';
import '../../data/profile_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'medal_claim_scope.dart';
import 'profile_medals_view.dart';
import 'profile_style.dart';

String _two(int n) => n.toString().padLeft(2, '0');

// ───────────────────────── Hero: cincin tingkat menang + nama ─────────────────────────

/// Avatar di dalam cincin emas yang terisi sesuai tingkat kemenangan, nama
/// di sampingnya. Tanpa latar kotak; [avatar] dibuat oleh pemanggil.
class ProfileStatsHero extends StatelessWidget {
  const ProfileStatsHero({
    super.key,
    required this.details,
    required this.avatar,
    this.avatarRadius = 40,
  });
  final ProfileDetails details;
  final Widget avatar;
  final double avatarRadius;

  @override
  Widget build(BuildContext context) {
    final d = details;
    final total = d.completed;
    final wins = d.wargaWins + d.terbisikWins;
    final rate = total <= 0 ? 0.0 : (wins / total).clamp(0.0, 1.0).toDouble();
    final pct = total <= 0 ? null : (rate * 100).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
      child: Row(
        children: [
          _RateRing(value: rate, size: avatarRadius * 2 + 30, child: avatar),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.nickname,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .4,
                    color: EmbunColors.cream,
                    shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
                  ),
                ),
                if (d.title.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const GameIcon('persona', size: 20),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          d.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .6,
                            color: EmbunColors.gold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.white70,
                    ),
                    children: [
                      TextSpan(
                        text: pct == null ? '-' : '$pct%',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: EmbunColors.gold,
                        ),
                      ),
                      TextSpan(
                        text: total <= 0
                            ? '  Belum ada pertandingan selesai'
                            : '  Menang $wins dari $total pertandingan',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RateRing extends StatelessWidget {
  const _RateRing({
    required this.value,
    required this.size,
    required this.child,
  });
  final double value, size;
  final Widget child;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _RateRingPainter(value),
    child: SizedBox.square(
      dimension: size,
      child: Center(child: child),
    ),
  );
}

class _RateRingPainter extends CustomPainter {
  const _RateRingPainter(this.value);
  final double value;
  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.0;
    final rect = (Offset.zero & size).deflate(stroke + 1);
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white12,
    );
    if (value <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke
        ..color = EmbunColors.gold,
    );
  }

  @override
  bool shouldRepaint(covariant _RateRingPainter old) => old.value != value;
}

// ───────────────────────── Papan statistik ─────────────────────────

/// Tiga angka besar dipisah garis tegak tipis, bilah kemenangan, lalu
/// baris-baris fakta berikon (dua kolom di layar lebar).
class ProfileStatsBoard extends StatelessWidget {
  const ProfileStatsBoard({
    super.key,
    required this.details,
    required this.history,
  });
  final ProfileDetails details;
  final List<ProfileMatch> history;

  @override
  Widget build(BuildContext context) {
    final d = details;
    final total = d.completed;
    final wins = d.wargaWins + d.terbisikWins;
    final lost = (total - wins).clamp(0, total).toInt();
    final pct = total <= 0
        ? null
        : (wins * 100 / total).round().clamp(0, 100).toInt();

    final scoped = MedalClaimScope.maybeOf(context);
    final claims = scoped?.owns(d) == true ? scoped : null;
    final received = earnedMedals(
      claims?.profile ?? d,
    ).where((m) => claims == null || claims.isClaimed(m)).toList();
    final topMedal = received.isEmpty
        ? null
        : received.reduce((a, b) => b.index > a.index ? b : a);

    final recent = [...history]
      ..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
    final last = recent.firstOrNull;
    final streak = recent.take(5).toList();
    final streakWins = streak.where((m) => m.won).length;

    final hasRole = d.wargaWins > 0 || d.terbisikWins > 0;
    final wargaTop = d.wargaWins >= d.terbisikWins;
    final roleColor = !hasRole
        ? Colors.white38
        : wargaTop
        ? EmbunColors.leaf
        : EmbunColors.mist;

    final rows = <Widget>[
      ProfileRow(
        label: 'PERAN UNGGULAN',
        accent: roleColor,
        visual: EmbunIcon(
          !hasRole
              ? Icons.help_outline
              : wargaTop
              ? Icons.shield_outlined
              : Icons.nights_stay_outlined,
          size: 34,
          color: roleColor,
        ),
        title: !hasRole
            ? 'Belum ada'
            : wargaTop
            ? 'Warga Desa'
            : 'Si Terbisik',
        text: !hasRole
            ? 'Menangkan pertandingan pertama'
            : '${medalNumber(wargaTop ? d.wargaWins : d.terbisikWins)} kemenangan',
      ),
      ProfileRow(
        label: 'MEDALI TERTINGGI',
        accent: topMedal?.tintColor ?? Colors.white38,
        onTap: topMedal == null
            ? null
            : () => showMedalDetails(
                context,
                claims?.profile ?? d,
                topMedal,
                claims: claims,
              ),
        visual: topMedal == null
            ? const EmbunIcon(Icons.lock_outline, size: 30, color: Colors.white38)
            : MedalArt(medal: topMedal, unlocked: true, size: 44),
        title: topMedal?.name ?? 'Belum ada',
        text: topMedal == null
            ? 'Raih medali pertamamu'
            : '${received.length}/${profileMedals.length} medali',
      ),
      ProfileRow(
        label: 'PERTANDINGAN TERAKHIR',
        accent: last == null
            ? Colors.white38
            : last.won
            ? EmbunColors.gold
            : EmbunColors.blood,
        visual: last == null
            ? const EmbunIcon(Icons.hourglass_empty, size: 30, color: Colors.white38)
            : GameIcon(last.won ? 'centang' : 'silang', size: 34),
        title: last == null
            ? 'Belum ada'
            : '${last.won ? 'Menang' : 'Kalah'} · ${last.side == 'antagonis' ? 'Si Terbisik' : 'Warga Desa'}',
        text: last == null
            ? 'Belum ada riwayat'
            : '${_two(last.finishedAt.day)}/${_two(last.finishedAt.month)}/${last.finishedAt.year} · hari ke-${last.days}',
      ),
      ProfileRow(
        label: 'REKOR 5 TERAKHIR',
        visual: const GameIcon('hari', size: 32),
        title: streak.isEmpty
            ? 'Belum ada'
            : '$streakWins menang dari ${streak.length}',
        text: '${medalNumber(total)} pertandingan selesai',
        extra: Row(
          children: [
            for (var i = 0; i < 5; i++)
              _Pip(result: i < streak.length ? streak[i].won : null),
          ],
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _Num(
                label: 'TINGKAT MENANG',
                value: pct,
                suffix: '%',
                color: EmbunColors.gold,
              ),
            ),
            _divider(),
            Expanded(
              child: _Num(
                label: 'MENANG WARGA',
                value: d.wargaWins,
                color: EmbunColors.leaf,
              ),
            ),
            _divider(),
            Expanded(
              child: _Num(
                label: 'MENANG TERBISIK',
                value: d.terbisikWins,
                color: EmbunColors.mist,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: 5,
            color: Colors.white12,
            child: total <= 0
                ? null
                : Row(
                    children: [
                      if (d.wargaWins > 0)
                        Expanded(
                          flex: d.wargaWins,
                          child: const ColoredBox(color: EmbunColors.leaf),
                        ),
                      if (d.terbisikWins > 0)
                        Expanded(
                          flex: d.terbisikWins,
                          child: const ColoredBox(color: EmbunColors.mist),
                        ),
                      if (lost > 0)
                        Expanded(flex: lost, child: const SizedBox.shrink()),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth < 520) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < rows.length; i++)
                    ProfileReveal(index: i, child: rows[i]),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < rows.length; i += 2)
                  ProfileReveal(
                    index: i ~/ 2,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: rows[i]),
                        const SizedBox(width: 16),
                        Expanded(
                          child: i + 1 < rows.length
                              ? rows[i + 1]
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 46,
    color: EmbunColors.goldDim.withValues(alpha: 0.35),
  );
}

extension on ProfileMedal {
  // Warna tingkat sama dengan yang dipakai papan medali.
  Color get tintColor => const [
    Color(0xFFD99058),
    Color(0xFFD99058),
    Color(0xFFCBD5DF),
    Color(0xFFCBD5DF),
    EmbunColors.gold,
    EmbunColors.gold,
    Color(0xFF3FD6B0),
    Color(0xFF3FD6B0),
    EmbunColors.mist,
    Color(0xFFFF8FB1),
  ][index];
}

class _Num extends StatelessWidget {
  const _Num({
    required this.label,
    required this.value,
    required this.color,
    this.suffix = '',
  });
  final String label, suffix;
  final int? value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 30,
      height: 1.1,
      fontWeight: FontWeight.w800,
      color: color,
    );
    final v = value;
    Widget numberLabel(int n) => suffix == '%'
        ? Semantics(label: '$n persen', child: ExcludeSemantics(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('$n', style: style),
              const SizedBox(width: 3),
              const GameIcon('persen', size: 24),
            ])))
        : Text('$n$suffix', style: style);
    final Widget number = v == null
        ? Text('-', style: style)
        : MediaQuery.disableAnimationsOf(context)
        ? numberLabel(v)
        : TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: v.toDouble()),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (_, n, _) => numberLabel(n.round()),
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(fit: BoxFit.scaleDown, child: number),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: profileCaps.copyWith(fontSize: 10, letterSpacing: 1.1),
        ),
      ],
    );
  }
}

/// Satu penanda hasil: true = menang, false = kalah, null = belum ada.
class _Pip extends StatelessWidget {
  const _Pip({required this.result});
  final bool? result;
  @override
  Widget build(BuildContext context) {
    final won = result == true;
    return Container(
      width: 20,
      height: 20,
      margin: const EdgeInsets.only(right: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: won ? EmbunColors.gold.withValues(alpha: .12) : Colors.transparent,
        border: Border.all(
          color: result == null
              ? Colors.white12
              : (won ? EmbunColors.gold : Colors.white30),
        ),
      ),
      child: result == null
          ? null
          : EmbunIcon(
              won ? Icons.check : Icons.close,
        asset: won ? 'centang' : 'silang',
              size: 16,
              color: won ? const Color(0xFF1A1405) : Colors.white38,
            ),
    );
  }
}
