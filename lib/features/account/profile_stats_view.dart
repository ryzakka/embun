import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/profile_medals.dart';
import '../../data/profile_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'medal_claim_scope.dart';
import 'profile_medals_view.dart';

const _caps = TextStyle(
  fontSize: 11,
  letterSpacing: 1.4,
  fontWeight: FontWeight.w600,
  color: Colors.white60,
);

String _two(int n) => n.toString().padLeft(2, '0');

// ───────────────────────── Hero: cincin tingkat menang + nama ─────────────────────────

/// Avatar di dalam cincin emas yang terisi sesuai tingkat kemenangan, nama
/// besar di sampingnya. [avatar] dibuat oleh pemanggil (ProfileAvatar dkk).
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
    final rate = total <= 0 ? 0.0 : (wins / total).clamp(0.0, 1.0);
    final pct = total <= 0 ? null : (rate * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-.7, 0),
          radius: 1.1,
          colors: [
            EmbunColors.gold.withValues(alpha: .13),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          _RateRing(
            value: rate,
            size: avatarRadius * 2 + 30,
            child: avatar,
          ),
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
                      const Icon(
                        Icons.workspace_premium_outlined,
                        size: 16,
                        color: EmbunColors.gold,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          d.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .6,
                            color: EmbunColors.gold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white30),
                      ),
                      child: Text(
                        pct == null ? '-' : '$pct%',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: EmbunColors.gold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        total <= 0
                            ? 'Belum ada pertandingan selesai'
                            : 'Menang $wins dari $total pertandingan',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
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
    child: SizedBox.square(dimension: size, child: Center(child: child)),
  );
}

class _RateRingPainter extends CustomPainter {
  const _RateRingPainter(this.value);
  final double value;
  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 4.0;
    final rect = (Offset.zero & size).deflate(stroke);
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
    final sweep = 2 * math.pi * value;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 4
        ..color = EmbunColors.gold.withValues(alpha: .45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
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

/// Tiga angka besar, bilah kemenangan, dan kartu 2×2 ala papan prajurit.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _BigStat(
                  label: 'TINGKAT MENANG',
                  value: pct,
                  suffix: '%',
                  color: EmbunColors.gold,
                ),
              ),
              Expanded(
                child: _BigStat(
                  label: 'MENANG WARGA',
                  value: d.wargaWins,
                  color: EmbunColors.leaf,
                ),
              ),
              Expanded(
                child: _BigStat(
                  label: 'MENANG TERBISIK',
                  value: d.terbisikWins,
                  color: EmbunColors.mist,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: 6,
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
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _InfoCard(
                  label: 'PERAN UNGGULAN',
                  accent: !hasRole
                      ? Colors.white38
                      : wargaTop
                      ? EmbunColors.leaf
                      : EmbunColors.mist,
                  visual: Icon(
                    !hasRole
                        ? Icons.help_outline
                        : wargaTop
                        ? Icons.shield_outlined
                        : Icons.nights_stay_outlined,
                    size: 46,
                    color: !hasRole
                        ? Colors.white38
                        : wargaTop
                        ? EmbunColors.leaf
                        : EmbunColors.mist,
                  ),
                  title: !hasRole
                      ? 'Belum ada'
                      : wargaTop
                      ? 'Warga Desa'
                      : 'Si Terbisik',
                  subtitle: !hasRole
                      ? 'Menangkan pertandingan pertama'
                      : '${medalNumber(wargaTop ? d.wargaWins : d.terbisikWins)} kemenangan',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InfoCard(
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
                      ? const Icon(
                    Icons.lock_outline,
                    size: 40,
                    color: Colors.white38,
                  )
                      : MedalArt(medal: topMedal, unlocked: true, size: 64),
                  title: topMedal?.name ?? 'Belum ada',
                  subtitle: topMedal == null
                      ? 'Raih medali pertamamu'
                      : '${received.length}/${profileMedals.length} medali',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _InfoCard(
                  label: 'PERTANDINGAN TERAKHIR',
                  accent: last == null
                      ? Colors.white38
                      : last.won
                      ? EmbunColors.gold
                      : EmbunColors.blood,
                  visual: last == null
                      ? const Icon(
                    Icons.hourglass_empty,
                    size: 40,
                    color: Colors.white38,
                  )
                      : GameIcon(last.won ? 'centang' : 'silang', size: 48),
                  title: last == null
                      ? 'Belum ada'
                      : '${last.won ? 'Menang' : 'Kalah'} · ${last.side == 'antagonis' ? 'Si Terbisik' : 'Warga Desa'}',
                  subtitle: last == null
                      ? 'Belum ada riwayat'
                      : '${_two(last.finishedAt.day)}/${_two(last.finishedAt.month)}/${last.finishedAt.year} · hari ke-${last.days}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InfoCard(
                  label: 'REKOR 5 TERAKHIR',
                  accent: EmbunColors.gold,
                  visual: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 5; i++)
                        _Pip(result: i < streak.length ? streak[i].won : null),
                    ],
                  ),
                  title: streak.isEmpty
                      ? 'Belum ada'
                      : '$streakWins menang dari ${streak.length}',
                  subtitle: '${medalNumber(total)} pertandingan selesai',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
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

class _BigStat extends StatelessWidget {
  const _BigStat({
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
      fontSize: 36,
      height: 1.1,
      fontWeight: FontWeight.w500,
      letterSpacing: 1,
      color: color,
    );
    final v = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: _caps),
        const SizedBox(height: 6),
        if (v == null)
          Text('-', style: style)
        else if (MediaQuery.disableAnimationsOf(context))
          Text('$v$suffix', style: style)
        else
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: v.toDouble()),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, n, _) => Text('${n.round()}$suffix', style: style),
          ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.label,
    required this.visual,
    required this.title,
    required this.subtitle,
    this.accent = EmbunColors.gold,
    this.onTap,
  });
  final String label, title, subtitle;
  final Widget visual;
  final Color accent;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black.withValues(alpha: .30),
    borderRadius: BorderRadius.circular(4),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 12),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: accent.withValues(alpha: .85), width: 2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: _caps.copyWith(fontSize: 10.5)),
            const SizedBox(height: 8),
            SizedBox(height: 66, child: Center(child: visual)),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: EmbunColors.cream,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Satu penanda hasil: true = menang, false = kalah, null = belum ada.
class _Pip extends StatelessWidget {
  const _Pip({required this.result});
  final bool? result;
  @override
  Widget build(BuildContext context) {
    final won = result == true;
    return Container(
      width: 22,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: won ? EmbunColors.gold : Colors.transparent,
        border: Border.all(
          color: result == null ? Colors.white12 : (won ? EmbunColors.gold : Colors.white30),
        ),
        boxShadow: won
            ? [
          BoxShadow(
            color: EmbunColors.gold.withValues(alpha: .5),
            blurRadius: 8,
          ),
        ]
            : null,
      ),
      child: result == null
          ? null
          : Icon(
        won ? Icons.check : Icons.close,
        size: 14,
        color: won ? const Color(0xFF1A1405) : Colors.white38,
      ),
    );
  }
}