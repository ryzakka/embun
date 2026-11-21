import 'dart:math' as math;

/// Shared presentation/rules. Rewards and authoritative scores are server-owned.
const melodyFee = 8;
const melodyMinimumCardCost = 10;
const melodyDurationMs = 30000;
const melodyLabels = [
  'Embun',
  'Persembahan',
  'Taktis',
  'Perawatan',
  'Lanjutan',
  'Poin',
];
const melodyPools = <List<int>>[
  [70, 25, 5, 0, 0, 0],
  [60, 25, 10, 5, 0, 0],
  [45, 25, 15, 5, 9, 1],
  [35, 25, 18, 7, 12, 3],
  [30, 20, 20, 8, 17, 5],
  [25, 15, 20, 7, 25, 8],
  [20, 10, 20, 5, 35, 10],
];
const melodyCoinRanges = <List<int>>[
  [1, 2],
  [3, 5],
  [5, 7],
  [7, 10],
  [10, 12],
  [12, 15],
  [15, 18],
];
const melodyBands = [
  '0–25',
  '26–50',
  '51–65',
  '66–75',
  '76–85',
  '86–95',
  '96–100',
];
int melodyTier(int score) {
  for (var i = 0; i < 6; i++) {
    if (score <= [25, 50, 65, 75, 85, 95][i]) return i;
  }
  return 6;
}

int melodyFinalScore(
  int personal,
  double villageAverage, {
  required bool antagonist,
}) => antagonist
    ? personal.clamp(0, 100).toInt()
    : (personal * .7 + villageAverage * .3).round().clamp(0, 100).toInt();

class MelodyNote {
  const MelodyNote({
    required this.id,
    required this.lane,
    required this.at,
    required this.hold,
    required this.wave,
  });
  final int id, lane, at, hold, wave;
  factory MelodyNote.fromJson(Map json) => MelodyNote(
    id: (json['id'] as num).toInt(),
    lane: (json['lane'] as num).toInt(),
    at: (json['at'] as num).toInt(),
    hold: (json['hold'] as num?)?.toInt() ?? 0,
    wave: (json['wave'] as num?)?.toInt() ?? 0,
  );
}

/// Input judge is deterministic and independent from rendering frame rate.
/// The server re-judges submitted timestamps; this class supplies immediate FX.
class MelodyJudge {
  final Map<int, MelodyNote> _notes = {};
  final Map<int, int> _down = {}, _up = {};
  final Set<int> _judged = {};
  final Map<int, MelodyNote> _held = {};
  final List<Map<String, dynamic>> _queue = [];
  int combo = 0, maxCombo = 0, points = 0, count = 0;
  String feedback = '';
  Iterable<MelodyNote> get notes => _notes.values;
  Set<int> get pressed => _held.keys.toSet();
  bool consumed(int id) => _down.containsKey(id) || _judged.contains(id);
  void addNotes(Iterable<MelodyNote> notes) {
    for (final note in notes) {
      _notes.putIfAbsent(note.id, () => note);
    }
  }

  MelodyNote? down(int lane, int elapsed) {
    if (_held.containsKey(lane) || elapsed < 0 || elapsed > melodyDurationMs) {
      return null;
    }
    final choices =
        _notes.values
            .where(
              (n) =>
                  n.lane == lane &&
                  !_down.containsKey(n.id) &&
                  !_judged.contains(n.id) &&
                  (n.at - elapsed).abs() <= 140,
            )
            .toList()
          ..sort(
            (a, b) => (a.at - elapsed).abs().compareTo((b.at - elapsed).abs()),
          );
    if (choices.isEmpty) {
      feedback = 'Lewat';
      return null;
    }
    final note = choices.first;
    _down[note.id] = elapsed;
    _queue.add({'id': note.id, 'edge': 'down', 'at': elapsed});
    if (note.hold > 0) _held[lane] = note;
    feedback = (elapsed - note.at).abs() <= 60 ? 'Tepat!' : 'Bagus';
    return note;
  }

  void up(int lane, int elapsed) {
    final note = _held.remove(lane);
    if (note == null) return;
    _up[note.id] = elapsed;
    _queue.add({
      'id': note.id,
      'edge': 'up',
      'at': elapsed.clamp(0, 30500).toInt(),
    });
  }

  void releaseAll(int elapsed) {
    for (final lane in _held.keys.toList()) {
      up(lane, elapsed);
    }
  }

  void tick(int elapsed) {
    final due =
        _notes.values
            .where(
              (n) => !_judged.contains(n.id) && elapsed >= n.at + n.hold + 160,
            )
            .toList()
          ..sort(
            (a, b) =>
                a.at == b.at ? a.id.compareTo(b.id) : a.at.compareTo(b.at),
          );
    for (final n in due) {
      final hit = _down[n.id];
      var grade = hit == null
          ? 0
          : ((hit - n.at).abs() <= 60
                ? 100
                : (hit - n.at).abs() <= 140
                ? 70
                : 0);
      if (n.hold > 0) {
        final release = _up[n.id];
        final tail =
            release != null &&
                release >= n.at + n.hold - 140 &&
                release <= n.at + n.hold + 160
            ? 100
            : 0;
        grade = grade > 0 ? (grade + tail) ~/ 2 : 0;
        _held.removeWhere((lane, note) => note.id == n.id);
      }
      _judged.add(n.id);
      count++;
      points += grade;
      if (grade >= 70) {
        combo++;
        maxCombo = math.max(maxCombo, combo);
      } else {
        combo = 0;
        feedback = 'Irama terputus';
      }
    }
  }

  int get score => count == 0
      ? 0
      : (.7 * points / count + 30 * maxCombo / count)
            .round()
            .clamp(0, 100)
            .toInt();
  double get accuracy => count == 0 ? 0 : points / count;
  List<Map<String, dynamic>> takeInputs() {
    final q = List<Map<String, dynamic>>.of(_queue);
    _queue.clear();
    return q;
  }

  void returnInputs(List<Map<String, dynamic>> inputs) =>
      _queue.insertAll(0, inputs);
}
