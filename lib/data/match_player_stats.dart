class MatchPlayerStats {
  MatchPlayerStats({required this.userId, required this.antagonist});
  final String userId;
  final bool? antagonist;
  int offered = 0, purchased = 0, bonusCards = 0, spent = 0;
  int votes = 0, right = 0, wrong = 0, skipped = 0;
  int get activity => offered + purchased + votes;
  double? get accuracy =>
      antagonist == false && votes > 0 ? right / votes : null;
}

/// Match recap only. No account totals, rewards, or game rules are modified.
Map<String, MatchPlayerStats> matchPlayerStats({
  required Iterable<String> userIds,
  required Map<String, Map<String, dynamic>> secrets,
  required Map<String, Map<String, dynamic>> definitions,
  required Map<String, dynamic> recap,
}) {
  final result = {
    for (final id in userIds)
      id: MatchPlayerStats(
        userId: id,
        antagonist: switch (secrets[id]?['role']) {
          'warga' => false,
          'antagonis' => true,
          _ => null,
        },
      ),
  };
  Iterable<Map> rows(String key) =>
      (recap[key] as List? ?? const []).whereType<Map>();
  for (final row in rows('offerings')) {
    final value = result[row['user_id']];
    if (value != null) value.offered++;
  }
  for (final row in rows('purchases')) {
    final value = result[row['user_id']];
    if (value == null) continue;
    if (row['bonus'] == true) {
      value.bonusCards++;
      continue;
    }
    value.purchased++;
    final price = row['cost'] ?? definitions[row['card_id']]?['cost'];
    if (price is num && price >= 0) value.spent += price.toInt();
  }
  for (final row in rows('votes')) {
    final value = result[row['user_id']];
    if (value == null) continue;
    value.votes++;
    final target = row['target_id'];
    if (target == null) {
      value.skipped++;
      continue;
    }
    if (value.antagonist != false) continue;
    final role = secrets[target]?['role'];
    if (role == 'antagonis') {
      value.right++;
    } else if (role == 'warga') {
      value.wrong++;
    }
  }
  return result;
}
