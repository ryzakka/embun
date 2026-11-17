import 'player_status.dart';

enum MeetingMomentKind { action, wound, jailed, eliminated, recovered }

class MeetingMoment {
  const MeetingMoment({
    required this.id,
    required this.kind,
    required this.before,
    required this.after,
    required this.day,
    this.caption,
  });
  final String id;
  final MeetingMomentKind kind;
  final Map<String, dynamic> before, after;
  final int day;
  final String? caption;
  String get playerId => '${after['user_id']}';
  bool get eliminated => kind == MeetingMomentKind.eliminated;
}

/// First snapshots are history. Only committed public status changes become
/// new scenes; roles, ability results and private logs are never consulted.
class MeetingBoardTracker {
  Map<String, Map<String, dynamic>>? _players;
  final _events = <String>{};
  bool _eventPrimed = false;
  int _sequence = 0;

  List<MeetingMoment> observePlayers(
    List<Map<String, dynamic>> rows, {
    required int day,
    required String phase,
  }) {
    final old = _players;
    _players = {for (final p in rows) '${p['user_id']}': Map.of(p)};
    if (old == null) return [];
    final moments = <MeetingMoment>[];
    for (final p in rows) {
      final before = old['${p['user_id']}'];
      if (before == null) continue;
      MeetingMomentKind? kind;
      if (!isOut(before) && isOut(p)) {
        kind = MeetingMomentKind.eliminated;
      } else if (isOut(before) && !isOut(p)) {
        kind = MeetingMomentKind.recovered;
      } else if (!isOut(p) && isJailed(p, day) && !isJailed(before, day)) {
        kind = MeetingMomentKind.jailed;
      } else if (!isOut(p) &&
          strikesOf(p) > strikesOf(before) &&
          const ['discussion', 'voting'].contains(phase)) {
        kind = MeetingMomentKind.wound;
      } else if (!isOut(p) &&
          strikesOf(p) < strikesOf(before) &&
          phase == 'discussion') {
        kind = MeetingMomentKind.recovered;
      }
      if (kind != null)
        moments.add(
          MeetingMoment(
            id: 'status-${++_sequence}',
            kind: kind,
            before: Map.of(before),
            after: Map.of(p),
            day: day,
          ),
        );
    }
    return moments;
  }

  List<MeetingMoment> observeEvents(
    List<Map<String, dynamic>> rows, {
    required int day,
  }) {
    final fresh = rows.where((e) => !_events.contains('${e['id']}')).toList();
    _events.addAll(rows.map((e) => '${e['id']}'));
    if (!_eventPrimed) {
      _eventPrimed = true;
      return [];
    }
    final result = <MeetingMoment>[];
    for (final e in fresh) {
      final text = '${e['text'] ?? ''}';
      if (e['day'] != day ||
          !text.startsWith('Rapat:') ||
          text.contains('Buktikan Tuduhanmu'))
        continue;
      final p = _players?['${e['target_id']}'];
      if (p == null) continue;
      result.add(
        MeetingMoment(
          id: 'event-${e['id']}',
          kind: MeetingMomentKind.action,
          before: Map.of(p),
          after: Map.of(p),
          day: day,
          caption: text.substring(6).trim(),
        ),
      );
    }
    return result;
  }
}
