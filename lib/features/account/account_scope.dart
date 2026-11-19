import 'package:flutter/widgets.dart';
import '../../data/account_controller.dart';

class AccountScope extends InheritedNotifier<AccountController> {
  const AccountScope({
    super.key,
    required AccountController controller,
    required super.child,
  }) : super(notifier: controller);
  static AccountController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccountScope>()?.notifier;
}
