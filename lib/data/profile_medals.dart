import 'profile_repository.dart';

enum MedalMetric { wargaWins, terbisikWins, completed }

class MedalSeries {
  const MedalSeries(
    this.id,
    this.name,
    this.assetPrefix,
    this.metric,
    this.targets,
  );
  final String id, name, assetPrefix;
  final MedalMetric metric;
  final List<int> targets;

  int valueOf(ProfileDetails profile) {
    if (!profile.googleLinked) return 0;
    final value = switch (metric) {
      MedalMetric.wargaWins => profile.wargaWins,
      MedalMetric.terbisikWins => profile.terbisikWins,
      MedalMetric.completed => profile.completed,
    };
    return value < 0 ? 0 : value;
  }

  String get unit =>
      metric == MedalMetric.completed ? 'pertandingan' : 'kemenangan';
  String requirement(int target) => switch (metric) {
    MedalMetric.wargaWins =>
      'Menang sebagai Warga Desa ${medalNumber(target)} kali.',
    MedalMetric.terbisikWins =>
      'Menang sebagai Si Terbisik ${medalNumber(target)} kali.',
    MedalMetric.completed => 'Selesaikan ${medalNumber(target)} pertandingan.',
  };
}

const medalSeries = [
  MedalSeries(
    'penjaga_desa',
    'Penjaga Desa',
    'medals-wargadesa',
    MedalMetric.wargaWins,
    [1, 5, 10, 25, 50, 100, 250, 500, 1000, 1500],
  ),
  MedalSeries(
    'penguasa_bisikan',
    'Penguasa Bisikan',
    'medals-siterbisik',
    MedalMetric.terbisikWins,
    [1, 3, 5, 10, 25, 50, 100, 200, 500, 1000],
  ),
  MedalSeries(
    'jejak_pengelana',
    'Jejak Pengelana',
    'medals-mainterus',
    MedalMetric.completed,
    [1, 10, 25, 50, 100, 250, 500, 1000, 1500, 3000],
  ),
];
const medalLevels = [
  'I',
  'II',
  'III',
  'IV',
  'V',
  'VI',
  'VII',
  'VIII',
  'IX',
  'X',
];

class ProfileMedal {
  const ProfileMedal(this.series, this.index);
  final MedalSeries series;
  final int index;
  int get target => series.targets[index];
  String get id => '${series.id}_${index + 1}';
  String get level => medalLevels[index];
  String get name => '${series.name} $level';
  String get assetStem =>
      '${series.assetPrefix}-${index == 9 ? 'maks' : index + 1}';
  String get assetPath => 'assets/medals/$assetStem.png';
  int valueOf(ProfileDetails profile) => series.valueOf(profile);
  bool unlocked(ProfileDetails profile) =>
      profile.googleLinked && valueOf(profile) >= target;
  double progress(ProfileDetails profile) =>
      (valueOf(profile) / target).clamp(0.0, 1.0);
}

final profileMedals = List<ProfileMedal>.unmodifiable([
  for (final series in medalSeries)
    for (var index = 0; index < series.targets.length; index++)
      ProfileMedal(series, index),
]);

List<ProfileMedal> earnedMedals(ProfileDetails profile) =>
    profileMedals.where((m) => m.unlocked(profile)).toList(growable: false);

List<ProfileMedal> highestMedals(ProfileDetails profile) => [
  for (final series in medalSeries)
    if (profileMedals
            .where((m) => m.series.id == series.id && m.unlocked(profile))
            .lastOrNull
        case final ProfileMedal medal)
      medal,
];

ProfileMedal? nextMedal(ProfileDetails profile, MedalSeries series) =>
    profileMedals
        .where((m) => m.series.id == series.id && !m.unlocked(profile))
        .firstOrNull;

String medalNumber(int value) {
  final digits = value.toString();
  final groups = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    groups.insert(0, digits.substring(end >= 3 ? end - 3 : 0, end));
  }
  return groups.join('.');
}
