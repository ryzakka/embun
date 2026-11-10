import 'package:flutter/widgets.dart';

import 'announcement_repository.dart';
import 'game_repository.dart';
import 'lobby_repository.dart';

/// Optional repository overrides shared by every route under this scope.
class EmbunData extends InheritedWidget {
  const EmbunData({
    super.key,
    required this.game,
    required this.lobby,
    required this.announcements,
    required super.child,
  });

  final GameRepository game;
  final LobbyRepository lobby;
  final AnnouncementRepository announcements;

  static EmbunData? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<EmbunData>();

  @override
  bool updateShouldNotify(EmbunData oldWidget) =>
      game != oldWidget.game ||
      lobby != oldWidget.lobby ||
      announcements != oldWidget.announcements;
}
