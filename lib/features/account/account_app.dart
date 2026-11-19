import 'package:flutter/material.dart';
import '../../data/account_controller.dart';
import '../common/ornate.dart';
import 'account_scope.dart';
import 'account_pages.dart';

/// One navigation stack per authenticated user. Metadata/token updates keep
/// the same stack; sign-out or a different user disposes all previous routes.
class AccountApplication extends StatelessWidget {
  const AccountApplication({
    super.key,
    required this.account,
    required this.home,
    this.builder,
  });
  final AccountController account;
  final Widget home;
  final TransitionBuilder? builder;
  @override
  Widget build(BuildContext context) => AccountScope(
    controller: account,
    child: AnimatedBuilder(
      animation: account,
      builder: (context, _) => MaterialApp(
        key: ValueKey('embun-account-${account.identity ?? 'signed-out'}'),
        title: 'Embun',
        debugShowCheckedModeBanner: false,
        theme: embunTheme(),
        builder: builder,
        home: AccountGate(account: account, child: home),
      ),
    ),
  );
}
