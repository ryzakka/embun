import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/profile_repository.dart';

/// One scoped request per roster, with public avatar/name data only.
class RoomAccountStatus extends StatefulWidget {
  const RoomAccountStatus({
    super.key,
    required this.gameId,
    required this.playerIds,
    required this.builder,
    this.enabled = true,
    this.loader,
  });
  final String gameId;
  final List<String> playerIds;
  final bool enabled;
  final Future<Map<String, RoomAccountProfile>> Function(String)? loader;
  final Widget Function(Map<String, RoomAccountProfile>) builder;
  @override
  State<RoomAccountStatus> createState() => _RoomAccountStatusState();
}

class _RoomAccountStatusState extends State<RoomAccountStatus> {
  Map<String, RoomAccountProfile> _links = {};
  int _revision = 0;
  String get _roster => ([...widget.playerIds]..sort()).join(',');
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RoomAccountStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldRoster = ([...oldWidget.playerIds]..sort()).join(',');
    if (oldWidget.gameId != widget.gameId ||
        oldRoster != _roster ||
        oldWidget.enabled != widget.enabled) {
      _links = {};
      _load();
    }
  }

  Future<void> _load() async {
    final revision = ++_revision;
    if (!widget.enabled) return;
    try {
      final loader =
          widget.loader ??
          (String id) => SupabaseProfileRepository(
            Supabase.instance.client,
          ).roomPlayers(id);
      final value = await loader(widget.gameId);
      if (mounted && revision == _revision) setState(() => _links = value);
    } catch (_) {
      // Unknown status is not the same as an unlinked account.
      if (mounted && revision == _revision) setState(() => _links = {});
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(_links);
}
