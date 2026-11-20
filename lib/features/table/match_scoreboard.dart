import 'package:flutter/material.dart';
import '../../data/match_player_stats.dart';
import '../../data/profile_repository.dart';
import '../common/ornate.dart';
import '../account/player_account_avatar.dart';
import '../account/room_medals_view.dart';

class MatchScoreboard extends StatelessWidget {
  const MatchScoreboard({
    super.key,
    required this.rows,
    required this.nameOf,
    required this.accounts,
    this.onViewProfile,
  });
  final List<MatchPlayerStats> rows;
  final String Function(String) nameOf;
  final Map<String, RoomAccountProfile> accounts;
  final ValueChanged<String>? onViewProfile;
  static const _titles = [
    'Poin\naktivitas',
    'Kartu\npersembahan',
    'Kartu\ndibeli',
    'Suara\ndiberikan',
    'Suara\nbenar',
    'Suara\nsalah',
    'Lewat',
    'Embun\nterpakai',
    'Ketepatan\nwarga',
  ];
  num? _value(MatchPlayerStats s, int column) => switch (column) {
    0 => s.activity,
    1 => s.offered,
    2 => s.purchased,
    3 => s.votes,
    4 => s.antagonist == false ? s.right : null,
    5 => s.antagonist == false ? s.wrong : null,
    6 => s.skipped,
    7 => s.spent,
    _ => s.accuracy,
  };
  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final rowHeight = 88.0 + (scale - 1).clamp(0, 2) * 65;
    final headHeight = 68.0 + (scale - 1).clamp(0, 2) * 32;
    final maxima = [
      for (var i = 0; i < _titles.length; i++)
        rows
            .map((s) => _value(s, i))
            .whereType<num>()
            .fold<num>(0, (a, b) => a > b ? a : b),
    ];
    final grid = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: headHeight,
          child: Row(
            children: [
              for (final title in _titles)
                Container(
                  width: 104,
                  height: headHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: EmbunColors.gold.withValues(alpha: .08),
                    border: Border(
                      bottom: BorderSide(
                        color: EmbunColors.gold.withValues(alpha: .4),
                      ),
                    ),
                  ),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: EmbunColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        for (final s in rows)
          SizedBox(
            height: rowHeight,
            child: Row(
              children: [
                for (var col = 0; col < _titles.length; col++)
                  Builder(
                    builder: (context) {
                      final value = _value(s, col);
                      final best =
                          value != null && value > 0 && value == maxima[col];
                      final text = value == null
                          ? '—'
                          : col == 8
                          ? '${(value * 100).round()}%'
                          : '$value';
                      return Container(
                        key: ValueKey('score-${s.userId}-$col'),
                        width: 104,
                        height: rowHeight,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: (best ? EmbunColors.gold : Colors.white)
                              .withValues(alpha: best ? .12 : .025),
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withValues(alpha: .10),
                            ),
                            left: BorderSide(
                              color: Colors.white.withValues(alpha: .05),
                            ),
                          ),
                        ),
                        child: Semantics(
                          label:
                              '${nameOf(s.userId)}, ${_titles[col].replaceAll('\n', ' ')}: $text',
                          child: Text(
                            text,
                            style: TextStyle(
                              fontSize: col == 0 ? 22 : 17,
                              fontWeight: best || col == 0
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: best ? EmbunColors.gold : Colors.white70,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Poin aktivitas: 1 per persembahan, pembelian biasa, atau suara. '
          'Kartu bonus tidak dihitung. Ketepatan warga menghitung suara lewat dalam total.',
          style: TextStyle(fontSize: 12, color: Colors.white60, height: 1.5),
        ),
        const SizedBox(height: 8),
        const Text(
          'Geser tabel mendatar untuk melihat semua kolom. Nama pemain tetap di sisi kiri.',
          style: TextStyle(fontSize: 11, color: Colors.white54),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, box) {
            final identityWidth = box.maxWidth < 500 ? 120.0 : 205.0;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: identityWidth,
                  child: Column(
                    children: [
                      Container(
                        height: headHeight,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 8),
                        child: const Text(
                          'PEMAIN',
                          style: TextStyle(
                            color: EmbunColors.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      for (final s in rows)
                        Container(
                          height: rowHeight,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.white.withValues(alpha: .1),
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  PlayerAccountAvatar(
                                    name: nameOf(s.userId),
                                    googleLinked:
                                        accounts[s.userId]?.googleLinked,
                                    avatarId: accounts[s.userId]?.avatarId,
                                    radius: 12,
                                    onTap: onViewProfile == null
                                        ? null
                                        : () => onViewProfile!(s.userId),
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      nameOf(s.userId),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                s.antagonist == null
                                    ? 'Peran belum tersedia'
                                    : s.antagonist!
                                    ? 'Si Terbisik'
                                    : 'Warga Desa',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: s.antagonist == true
                                      ? EmbunColors.mist
                                      : EmbunColors.leaf,
                                ),
                              ),
                              RoomMedalStrip(
                                userId: s.userId,
                                profile: accounts[s.userId],
                                size: 18,
                                onViewProfile: onViewProfile == null
                                    ? null
                                    : () => onViewProfile!(s.userId),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    key: const ValueKey('match-scoreboard-scroll'),
                    scrollDirection: Axis.horizontal,
                    child: grid,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'Warna emas menandai nilai tertinggi pada kolom. Nilai seri mendapat sorotan yang sama.',
          style: TextStyle(fontSize: 11, color: Colors.white54),
        ),
      ],
    );
  }
}
