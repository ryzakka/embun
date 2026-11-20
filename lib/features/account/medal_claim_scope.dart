import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/account_controller.dart';
import '../../data/medal_claims.dart';
import '../../data/profile_repository.dart';
import '../../data/supabase_account_repository.dart';

class MedalClaimScope extends InheritedNotifier<MedalClaimsController> {
  const MedalClaimScope({
    super.key,
    required MedalClaimsController controller,
    required super.child,
  }) : super(notifier: controller);
  static MedalClaimsController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MedalClaimScope>()?.notifier;
}

/// Lives above the Navigator; metadata updates preserve this controller/routes.
class MedalClaimHost extends StatefulWidget {
  const MedalClaimHost({
    super.key,
    required this.account,
    required this.child,
    this.controller,
  });
  final AccountController account;
  final Widget child;
  final MedalClaimsController? controller;
  @override
  State<MedalClaimHost> createState() => _MedalClaimHostState();
}

class _MedalClaimHostState extends State<MedalClaimHost> {
  MedalClaimsController? _owned;
  @override
  void initState() {
    super.initState();
    widget.account.addListener(_changed);
    _sync();
  }

  void _sync() {
    final id = widget.account.googleAccount ? widget.account.identity : null;
    final repository = widget.account.repository;
    if (_owned?.userId != id) {
      _owned?.dispose();
      _owned = null;
    }
    if (widget.controller == null &&
        id != null &&
        _owned == null &&
        repository is SupabaseAccountRepository) {
      _owned = MedalClaimsController(
        userId: id,
        profiles: SupabaseProfileRepository(repository.client),
        receipts: SupabaseMedalReceiptRepository(repository.client),
      );
    }
  }

  void _changed() {
    if (mounted) setState(_sync);
  }

  @override
  void didUpdateWidget(covariant MedalClaimHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.account != oldWidget.account) {
      oldWidget.account.removeListener(_changed);
      widget.account.addListener(_changed);
      _owned?.dispose();
      _owned = null;
    }
    _sync();
  }

  @override
  void dispose() {
    widget.account.removeListener(_changed);
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller ?? _owned;
    return controller == null ||
            !widget.account.googleAccount ||
            widget.account.identity != controller.userId
        ? widget.child
        : MedalClaimScope(controller: controller, child: widget.child);
  }
}

/// Refresh only while the lobby route is visible, plus on app resume.
class MedalLobbyMonitor extends StatefulWidget {
  const MedalLobbyMonitor({super.key, required this.child});
  final Widget child;
  @override
  State<MedalLobbyMonitor> createState() => _MedalLobbyMonitorState();
}

class _MedalLobbyMonitorState extends State<MedalLobbyMonitor>
    with WidgetsBindingObserver {
  MedalClaimsController? _claims;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _refresh() {
    if (mounted &&
        ModalRoute.of(context)?.isCurrent != false &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.hidden) {
      unawaited(_claims?.refresh());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final claims = MedalClaimScope.maybeOf(context);
    if (claims == _claims) return;
    _claims = claims;
    _timer?.cancel();
    if (claims != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
      _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
    }
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
  Widget build(BuildContext context) => widget.child;
}

class MedalNotification extends StatelessWidget {
  const MedalNotification({super.key, required this.child, this.userId});
  final Widget child;
  final String? userId;
  @override
  Widget build(BuildContext context) {
    final claims = MedalClaimScope.maybeOf(context);
    final visible =
        claims?.hasPending == true &&
        (userId == null || claims!.userId == userId);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (visible)
          Positioned(
            top: 0,
            right: 0,
            child: IgnorePointer(
              child: Semantics(
                label:
                    '${claims!.pending.length} medali baru, buka profil untuk klaim',
                child: Container(
                  key: const ValueKey('new-medal-dot'),
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF10251D),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
