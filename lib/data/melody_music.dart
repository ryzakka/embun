import 'dart:math' as math;
import 'melody_rules.dart';

/// Full original assets: no clips or speed variants are generated.
class MelodyTrack {
  const MelodyTrack(this.id, this.durationMs, this.bpm, this.beatOffsetMs);
  final String id;
  final int durationMs, beatOffsetMs;
  final double bpm;
  String get asset => 'sound/$id.mp3';
  bool supports(int sessionMs) =>
      durationMs >= sessionMs * 1.25 + melodyFadeMs * 1.25;
  Map<String, dynamic> toJson() => {
    'id': id,
    'asset': asset,
    'duration_ms': durationMs,
    'bpm': bpm,
    'beat_offset_ms': beatOffsetMs,
  };
}

const melodyTracks = [
  MelodyTrack('instrument01', 173448, 120.0, 150),
  MelodyTrack('instrument02', 84360, 120.16, 395),
  MelodyTrack('instrument03', 89352, 121.0, 445),
  MelodyTrack('instrument04', 64800, 123.0, 190),
];
MelodyTrack? melodyTrackFromState(Map? state) {
  final id = (state?['music'] as Map?)?['id'];
  for (final t in melodyTracks) {
    if (t.id == id) return t;
  }
  return null;
}

/// One immutable phrase from the authoritative timeline. music_at_ms is in
/// source-file time, while at is in session time. This keeps speed changes
/// continuous instead of restarting the song every six seconds.
class MelodyMusicFrame {
  const MelodyMusicFrame({
    required this.session,
    required this.asset,
    required this.positionMs,
    required this.rate,
    required this.volume,
    required this.play,
  });
  final String session, asset;
  final double positionMs, rate, volume;
  final bool play;
}

MelodyMusicFrame? melodyMusicFrame(
  Map state,
  int elapsed, {
  required bool muted,
}) {
  final track = melodyTrackFromState(state);
  if (track == null) return null;
  final duration = melodySessionDuration(state);
  final rows = (state['waves'] as List? ?? []).cast<Map>();
  final within = elapsed.clamp(0, duration - 1);
  final wave = within ~/ melodyWaveMs;
  Map? row;
  for (final r in rows) {
    if (r['wave'] == wave) row = r;
  }
  // Do not guess pressure on missing data; pause until its frozen timeline
  // arrives, then resume at the server position.
  final rate = (row?['rate'] as num?)?.toDouble() ?? 1;
  final start = (row?['music_at_ms'] as num?)?.toDouble() ?? 0;
  final position = start + math.max(0, elapsed - wave * melodyWaveMs) * rate;
  final fade = elapsed < duration
      ? 1.0
      : (1 - (elapsed - duration) / melodyFadeMs).clamp(0.0, 1.0);
  return MelodyMusicFrame(
    session: '${state['id']}',
    asset: track.asset,
    positionMs: position,
    rate: rate,
    volume: muted ? 0 : .55 * fade,
    play:
        row != null &&
        !muted &&
        elapsed >= 0 &&
        elapsed < duration + melodyFadeMs,
  );
}

/// Preview uses the same pulse/timeline formula as SQL; the server still owns
/// actual note IDs, scoring and rewards in multiplayer.
List<Map<String, dynamic>> melodyPreviewWaves(
  int durationMs, {
  required bool antagonist,
}) {
  double musicAt = 0;
  return [
    for (var w = 0; w * melodyWaveMs < durationMs; w++)
      ...(() {
        final pressure = (w - 1).clamp(0, 3);
        final rate = 1 + (antagonist ? 0 : pressure) * .05;
        final row = <String, dynamic>{
          'wave': w,
          'pressure': pressure,
          'music_at_ms': musicAt,
          'rate': rate,
        };
        musicAt += math.min(melodyWaveMs, durationMs - w * melodyWaveMs) * rate;
        return [row];
      })(),
  ];
}

List<MelodyNote> melodyPreviewNotes(
  MelodyTrack track,
  int durationMs,
  List<Map<String, dynamic>> waves,
  math.Random rng,
) {
  final result = <MelodyNote>[];
  final beat = 60000 / track.bpm;
  for (final w in waves) {
    final wave = w['wave'] as int;
    final rate = (w['rate'] as num).toDouble();
    final musicAt = (w['music_at_ms'] as num).toDouble();
    final end = math.min((wave + 1) * melodyWaveMs, durationMs);
    var i = math.max(0, ((musicAt - track.beatOffsetMs) / beat).ceil());
    while (true) {
      final at =
          (wave * melodyWaveMs +
                  (track.beatOffsetMs + i * beat - musicAt) / rate)
              .round();
      if (at >= end - 200) break;
      if (at < math.max(450, wave * melodyWaveMs)) {
        i++;
        continue;
      }
      final lane = rng.nextInt(4);
      var hold = i % 6 == 4 ? (beat / rate * 1.2).round() : 0;
      if (at + hold >= end - 200) hold = 0;
      result.add(
        MelodyNote(
          id: wave * 10000 + i * 4 + lane,
          lane: lane,
          at: at,
          hold: hold,
          wave: wave,
        ),
      );
      if (i % 6 == 2) {
        final chord = (lane + 1 + rng.nextInt(3)) % 4;
        result.add(
          MelodyNote(
            id: wave * 10000 + i * 4 + chord,
            lane: chord,
            at: at,
            hold: 0,
            wave: wave,
          ),
        );
      }
      i += hold > 0 ? 2 : 1;
    }
  }
  return result;
}
