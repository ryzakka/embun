import 'dart:math' as math;

import 'game_rules.dart';

/// Dampak kondisi publik Hayu. Ambangnya ditentukan server dan disiarkan
/// sebagai kondisi pada games, sehingga skor internal tidak perlu dibaca.
/// Angkanya mengikuti _akar_mult, _batang_mod, dan _tanah_fog_mod.
enum HayuCondition {
  subur(1.25, 1, -1),
  biasa(1, 0, 0),
  layu(0.75, -1, 1),
  rusak(0.5, -2, 2);

  const HayuCondition(this.akarMultiplier, this.batangShield, this.tanahFog);

  final double akarMultiplier;
  final int batangShield;
  final int tanahFog;

  int get akarPercent => ((akarMultiplier - 1) * 100).round();

  static HayuCondition fromGame(Object? value) =>
      values.where((condition) => condition.name == value).firstOrNull ?? biasa;
}

const int kHayuPartMax = 8;

enum HayuLevel {
  kritis('Kritis'),
  rusak('Rusak'),
  rapuh('Rapuh'),
  layu('Layu'),
  stabil('Stabil'),
  tumbuh('Tumbuh'),
  subur('Subur'),
  kuat('Kuat'),
  prima('Prima');

  const HayuLevel(this.label);

  final String label;

  static HayuLevel fromScore(int score) {
    final step = (score.abs() + 1) ~/ 2;
    return values[stabil.index + step * score.sign];
  }
}

class HayuPartStatus {
  const HayuPartStatus({required this.condition, this.score});

  factory HayuPartStatus.fromGame(Object? condition, Object? score) =>
      HayuPartStatus(
        condition: HayuCondition.fromGame(condition),
        score: score is int ? score.clamp(-kHayuPartMax, kHayuPartMax) : null,
      );

  final HayuCondition condition;
  final int? score;

  HayuLevel? get level => score == null ? null : HayuLevel.fromScore(score!);
  String get toneKey => level?.name ?? condition.name;
  String get label => level?.label ?? condition.name;
  bool get damaged =>
      score == null ? condition == HayuCondition.rusak : score! <= -5;
  int get akarPercent => score == null ? condition.akarPercent : score! * 6;
  double get akarMultiplier =>
      score == null ? condition.akarMultiplier : 1 + akarPercent / 100;
  int get batangShield => score == null ? condition.batangShield : score! ~/ 2;
  int get tanahFog => score == null ? condition.tanahFog : -(score! ~/ 2);

  int get extraWormRemoval => switch (score) {
    null => condition == HayuCondition.subur ? 1 : 0,
    >= 6 => 2,
    >= 2 => 1,
    _ => 0,
  };

  int get extraWormSpawn => switch (score) {
    null => condition == HayuCondition.rusak ? 1 : 0,
    <= -8 => 2,
    <= -4 => 1,
    _ => 0,
  };
}

String hayuAmount(num value, {bool signed = false}) {
  final amount = value
      .abs()
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'\.?0+$'), '')
      .replaceFirst('.', ',');
  if (amount == '0') return amount;
  return '${value < 0
      ? '−'
      : signed
      ? '+'
      : ''}$amount';
}

/// Perkiraan pembayaran berikutnya jika keadaan saat ini bertahan.
/// Urutan hitung mengikuti begin_day: penalti dan batas bawah dulu, lalu
/// pengali Akar bagi Warga atau bonus Daun bagi Terbisik, kemudian bonus siklus.
class HayuIncome {
  HayuIncome({
    required this.day,
    required this.rate,
    required this.penalty,
    required double akarMultiplier,
    required this.leavesBonus,
    required this.cycleBonus,
    required this.isAntagonist,
  }) : minimumAdjustment = math.max(1 - (rate - penalty), 0),
       akarChange = math.max(rate - penalty, 1) * (akarMultiplier - 1);

  final int day;
  final double rate;
  final double penalty;
  final double minimumAdjustment;
  final double akarChange;
  final double leavesBonus;
  final int cycleBonus;
  final bool isAntagonist;

  String get currency => isAntagonist ? 'bulir hitam' : 'embun';

  double get total =>
      rate -
      penalty +
      minimumAdjustment +
      akarChange +
      leavesBonus +
      cycleBonus;

  List<(String, num)> get components => [
    ('Laju dasar', rate),
    if (penalty != 0) ('Penalti laju', -penalty),
    if (minimumAdjustment != 0) ('Batas minimum', minimumAdjustment),
    if (akarChange != 0) ('Efek Akar', akarChange),
    if (leavesBonus != 0) ('Bonus Daun Hayu', leavesBonus),
    if (cycleBonus != 0) ('Awal siklus', cycleBonus),
  ];
}

class HayuEffects {
  const HayuEffects({
    required this.akar,
    required this.batang,
    required this.tanah,
    required this.leaves,
    required this.winLeaves,
    required this.worms,
    this.expandedRules = false,
    this.leavesChange,
    this.income,
  });

  factory HayuEffects.fromGame(
    Map<String, dynamic> game, {
    Map<String, dynamic>? playerState,
    bool isAntagonist = false,
  }) {
    final expanded = ((game['hayu_rules_version'] as int?) ?? 1) >= 2;
    HayuPartStatus part(String key) => HayuPartStatus.fromGame(
      game['${key}_c'],
      expanded ? game['${key}_score'] : null,
    );
    final akar = part('akar');
    final leaves = (game['leaves'] as int?) ?? 0;
    final winLeaves = (game['win_leaves'] as int?) ?? 20;
    final day = (game['day'] as int?) ?? 0;
    final maxDay = game['max_day'] as int?;
    final cycle = (game['cycle_len'] as int?) ?? kCycleDays;
    final nextDay = day + 1;
    final rate = (playerState?['rate'] as num?)?.toDouble();
    final penaltyUntil = (playerState?['penalty_until'] as int?) ?? 0;
    final penalty = penaltyUntil >= nextDay
        ? (playerState?['rate_penalty'] as num?)?.toDouble() ?? 0.0
        : 0.0;
    // Nilai sebelum persembahan tetap tersimpan pada hari berikutnya.
    // Bandingkan hanya selama fase yang masih merujuk persembahan yang sama.
    final leavesBefore =
        const {'effects', 'discussion', 'voting'}.contains(game['phase'])
        ? game['leaves_before_effects'] as int?
        : null;

    return HayuEffects(
      akar: akar,
      batang: part('batang'),
      tanah: part('tanah'),
      expandedRules: expanded,
      leaves: leaves,
      winLeaves: winLeaves,
      worms: (game['lingering_worms'] as int?) ?? 0,
      leavesChange: leavesBefore == null ? null : leaves - leavesBefore,
      income:
          rate != null &&
              day > 0 &&
              game['status'] != 'finished' &&
              (maxDay == null || nextDay <= maxDay)
          ? HayuIncome(
              day: nextDay,
              rate: rate,
              penalty: penalty,
              akarMultiplier: isAntagonist ? 1 : akar.akarMultiplier,
              leavesBonus: isAntagonist ? _leavesBonus(leaves, expanded) : 0,
              cycleBonus: nextDay % (cycle > 0 ? cycle : kCycleDays) == 1
                  ? 5
                  : 0,
              isAntagonist: isAntagonist,
            )
          : null,
    );
  }

  final HayuPartStatus akar;
  final HayuPartStatus batang;
  final HayuPartStatus tanah;
  final int leaves;
  final int winLeaves;
  final int worms;
  final bool expandedRules;
  final int? leavesChange;
  final HayuIncome? income;

  int get missingLeaves => math.max(winLeaves - leaves, 0);
  double get antagonistLeavesBonus => _leavesBonus(leaves, expandedRules);

  static double _leavesBonus(int leaves, bool expanded) => expanded
      ? (leaves.clamp(0, kLeavesMax) ~/ 5) * 0.5
      : (leaves ~/ 10).toDouble();

  HayuLevel get leafLevel => switch (leaves) {
    >= kLeavesMax => HayuLevel.prima,
    >= 25 => HayuLevel.kuat,
    >= 20 => HayuLevel.subur,
    >= 15 => HayuLevel.tumbuh,
    >= 10 => HayuLevel.stabil,
    >= 5 => HayuLevel.layu,
    _ => HayuLevel.kritis,
  };

  int get damageLeafLoss {
    final damaged = [akar, batang, tanah].where((part) => part.damaged).length;
    if (expandedRules && damaged == 3) return 2;
    return damaged >= 2 ? 1 : 0;
  }
}
