import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/profile_repository.dart';
import '../../data/profile_medals.dart';
import 'medal_claim_scope.dart';

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

class _RoomAccountStatusState extends State<RoomAccountStatus>
    with WidgetsBindingObserver {
  Map<String, RoomAccountProfile> _links = {};
  int _revision = 0;
  Timer? _timer;
  bool _loading = false;
  String? _receiptKey;
  String get _roster => ([...widget.playerIds]..sort()).join(',');
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  void _refresh() {
    if (mounted &&
        widget.enabled &&
        !_loading &&
        ModalRoute.of(context)?.isCurrent != false &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.hidden &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused) {
      unawaited(_load());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final claims = MedalClaimScope.maybeOf(context);
    final receiptKey = claims == null
        ? ''
        : '${claims.userId}:${claims.initialized}:'
              '${profileMedals.where(claims.isClaimed).map((m) => m.id).join(',')}';
    if (_receiptKey != null && receiptKey != _receiptKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    }
    _receiptKey = receiptKey;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
    _loading = true;
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
    } finally {
      if (mounted && revision == _revision) _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(_links);
}
