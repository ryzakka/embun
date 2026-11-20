import '../common/embun_icon.dart';
import 'package:flutter/material.dart';
import 'google_sign_in_button.dart';

/// Missing/unknown status should omit this widget, rather than label a guest.
class AccountStatusBadge extends StatelessWidget {
  const AccountStatusBadge({super.key, required this.linked, this.size = 20});
  final bool linked;
  final double size;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: linked ? 'Terhubung ke Google' : 'Belum menautkan akun Google',
    child: Semantics(
      label: linked ? 'Terhubung ke Google' : 'Belum menautkan akun Google',
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(linked ? 3 : 0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: linked ? Colors.white : const Color(0xFF203B30),
        ),
        child: linked
            ? GoogleLogo(size: size - 6)
            : EmbunIcon(Icons.person_outline, size: size - 2, color: Colors.white60),
      ),
    ),
  );
}

class AccountAvatarBadge extends StatelessWidget {
  const AccountAvatarBadge({
    super.key,
    required this.linked,
    required this.child,
    this.size = 20,
  });
  final bool linked;
  final Widget child;
  final double size;
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      child,
      Positioned(
        right: -2,
        bottom: -2,
        child: AccountStatusBadge(linked: linked, size: size),
      ),
    ],
  );
}
