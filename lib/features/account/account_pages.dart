import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/profile_avatar_catalog.dart';
import '../../data/profile_repository.dart';
import 'profile_avatar.dart';
import 'profile_details_page.dart';
export 'profile_avatar.dart';
import '../../data/account_controller.dart';
import '../../data/asset_catalog.dart';
import '../../data/player_profile.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'google_sign_in_button.dart';
import 'account_status_badge.dart';
import 'player_account_avatar.dart';
import 'public_information_links.dart';

BorderSide _rule([Color color = EmbunColors.gold]) =>
    BorderSide(color: color.withValues(alpha: 0.30));

/// This gate belongs inside the account-keyed MaterialApp's home. Changing
/// the authenticated account rebuilds that Navigator, clearing old game routes.
class AccountGate extends StatelessWidget {
  const AccountGate({super.key, required this.account, required this.child});
  final AccountController account;
  final Widget child;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: account,
    builder: (context, _) {
      if (account.restoring) {
        return const _AccountFrame(
          child: EmbunLoading(text: 'Memulihkan sesi…'),
        );
      }
      if (!account.googleAccount && !account.guest) {
        return GoogleLoginPage(account: account);
      }
      if (account.googleAccount && !account.ready) {
        return ProfilePage(
          key: ValueKey(account.identity),
          account: account,
          firstSetup: true,
        );
      }
      return child;
    },
  );
}

/// Latar bentang, redaman, dan gradasi: dipakai login dan profil.
class _AccountBackdrop extends StatelessWidget {
  const _AccountBackdrop();

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Backdrop(path: sceneryPath('rumahdesa-hijau'), dim: .5),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x80101C15), Color(0x2207130F), Color(0xDD07130F)],
            stops: [0, 0.45, 1],
          ),
        ),
      ),
    ],
  );
}

/// Bingkai terpusat tanpa kotak: isi langsung di atas latar.
class _AccountFrame extends StatelessWidget {
  const _AccountFrame({required this.child, this.maxWidth = 480});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: EmbunColors.bg,
    body: Stack(
      fit: StackFit.expand,
      children: [
        const _AccountBackdrop(),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: child,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class GoogleLoginPage extends StatelessWidget {
  const GoogleLoginPage({super.key, required this.account});
  final AccountController account;
  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final logoH = (screenH * 0.32).clamp(130.0, 300.0).toDouble();
    return AnimatedBuilder(
      animation: account,
      builder: (context, _) => _AccountFrame(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, 22 * (1 - t)),
              child: child,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: logoH,
                child: GameImage(
                  path:
                      logoPath('ikon-transparent') ??
                      logoPath('ikonapp-transparent'),
                  fit: BoxFit.contain,
                  cacheWidth: 900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Selamat datang di desa',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: EmbunColors.gold,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 14)],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Masuk untuk menyimpan profil dan memakai nama panggilanmu '
                'di setiap permainan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  height: 1.55,
                  color: Colors.white70,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
                ),
              ),
              const SizedBox(height: 22),
              GoogleSignInButton(
                key: const ValueKey('google-login'),
                onPressed: account.busy || account.waitingForGoogle
                    ? null
                    : account.login,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                key: const ValueKey('continue-guest'),
                onPressed: account.busy || account.waitingForGoogle
                    ? null
                    : account.continueAsGuest,
                icon: const Icon(Icons.person_outline),
                label: const Text('Main sebagai tamu'),
              ),
              const Text(
                'Permainan sebagai tamu belum disimpan di akun Anda.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white60),
              ),
              if (account.busy) ...[
                const SizedBox(height: 10),
                Semantics(
                  liveRegion: true,
                  child: const Text(
                    'Menyiapkan sesi…',
                    style: TextStyle(fontSize: 12.5, color: Colors.white70),
                  ),
                ),
              ],
              if (account.waitingForGoogle) ...[
                const SizedBox(height: 14),
                const Text(
                  'Selesaikan login di halaman Google, lalu kembali ke Embun.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                TextButton(
                  onPressed: account.cancelLoginWait,
                  child: const Text('Login dibatalkan? Coba lagi'),
                ),
              ],
              if (account.error case final message?)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFFFB5A8)),
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              const Text(
                'Kamu dapat memilih nama panggilan setelah masuk.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(border: Border(top: _rule())),
                child: const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: PublicInformationLinks(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.account,
    this.firstSetup = false,
    this.detailsRepository,
    this.guestName = 'Tamu',
  });
  final AccountController account;
  final bool firstSetup;
  final String guestName;
  final ProfileRepository? detailsRepository;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.account.profile?.initialNickname ?? '',
  );
  late String _avatar = widget.account.profile?.avatarId ?? 'penjaga_hayu';
  late final ProfileRepository? _detailsRepository = widget.firstSetup
      ? null
      : widget.detailsRepository ??
            SupabaseProfileRepository(Supabase.instance.client);
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final saved = await widget.account.save(_name.text, _avatar);
    if (mounted && saved && !widget.firstSetup) Navigator.of(context).pop();
  }

  Widget _header(AccountController account) => DecoratedBox(
    decoration: BoxDecoration(border: Border(bottom: _rule())),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (widget.firstSetup)
            const SizedBox(width: 12)
          else
            IconButton(
              tooltip: 'Kembali',
              icon: const GameIcon('back', size: 23),
              onPressed: account.busy
                  ? null
                  : () => Navigator.of(context).pop(),
            ),
          if (widget.firstSetup) ...[
            const GameIcon('character', size: 28),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                widget.firstSetup ? 'Kenalan dulu, yuk' : 'Profilku',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: EmbunColors.cream,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: _rule())),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: SizedBox(
          width: double.infinity,
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: EmbunColors.gold,
            ),
          ),
        ),
      ),
    ),
  );

  /// Avatar terpilih besar dan namanya.
  Widget _preview(bool wide) => Column(
    children: [
      AccountAvatarBadge(
        linked: true,
        child: ProfileAvatar(avatarId: _avatar, radius: wide ? 70 : 52),
      ),
      const SizedBox(height: 8),
      Text(
        profileAvatars[_avatar]?.$2 ?? 'Avatar',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: EmbunColors.gold,
        ),
      ),
    ],
  );

  Widget _nameField(AccountController account) => TextFormField(
    key: const ValueKey('profile-nickname'),
    controller: _name,
    enabled: !account.busy,
    maxLength: 20,
    validator: (value) => nicknameError(value ?? ''),
    textCapitalization: TextCapitalization.words,
    textInputAction: TextInputAction.done,
    onFieldSubmitted: (_) {
      if (!account.busy) _save();
    },
    style: const TextStyle(fontSize: 18, color: EmbunColors.cream),
    decoration: InputDecoration(
      filled: false,
      labelText: 'Nama panggilan',
      helperText: 'Nama yang dipakai saat masuk ruangan.',
      border: UnderlineInputBorder(
        borderSide: BorderSide(color: EmbunColors.gold.withValues(alpha: 0.4)),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: EmbunColors.gold.withValues(alpha: 0.4)),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: EmbunColors.gold, width: 2),
      ),
    ),
  );

  Widget _picker(AccountController account, bool wide) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionTitle('Pilih avatar'),
      LayoutBuilder(
        builder: (context, box) {
          // 10 avatar = 2 baris x 5 kolom; ukuran mengikuti lebar yang ada.
          const cols = 5;
          final gap = wide ? 10.0 : 4.0;
          final cell = ((box.maxWidth - gap * (cols - 1)) / cols)
              .floorToDouble();
          final radius = ((cell - 12) / 2).clamp(18.0, 46.0).toDouble();
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final entry in profileAvatars.entries)
                SizedBox(
                  width: cell,
                  height: cell,
                  child: Center(
                    child: Semantics(
                      selected: _avatar == entry.key,
                      button: true,
                      label: entry.value.$2,
                      child: Tooltip(
                        message: entry.value.$2,
                        child: InkResponse(
                          key: ValueKey('avatar-${entry.key}'),
                          radius: radius + 6,
                          onTap: account.busy
                              ? null
                              : () => setState(() => _avatar = entry.key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                width: 3,
                                color: _avatar == entry.key
                                    ? EmbunColors.gold
                                    : Colors.transparent,
                              ),
                              boxShadow: _avatar == entry.key
                                  ? [
                                      BoxShadow(
                                        color: EmbunColors.gold.withValues(
                                          alpha: 0.35,
                                        ),
                                        blurRadius: 14,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Opacity(
                              opacity: _avatar == entry.key ? 1 : 0.8,
                              child: ProfileAvatar(
                                avatarId: entry.key,
                                radius: radius,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );

  Widget _emailNote(AccountController account) {
    final email = account.profile?.email;
    if (email == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Email Google terhubung',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
          Text(
            email,
            style: const TextStyle(fontSize: 13.5, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _saveBlock(AccountController account) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (!widget.firstSetup)
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'Perubahan nama berlaku saat masuk ruangan berikutnya.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      if (account.error case final message?)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Semantics(
            liveRegion: true,
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFFFB5A8)),
            ),
          ),
        ),
      EmbunButton(
        key: const ValueKey('save-profile'),
        label: account.busy
            ? 'Menyimpan…'
            : widget.firstSetup
            ? 'Simpan dan lanjutkan'
            : 'Simpan profil',
        icon: account.busy ? 'wait' : 'simpan',
        expand: true,
        height: 46,
        onPressed: account.busy ? null : _save,
      ),
    ],
  );

  Widget _logout(AccountController account) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8),
      ),
      onPressed: account.busy ? null : account.logout,
      icon: const GameIcon('keluar', size: 22),
      label: const Text('Keluar akun'),
    ),
  );

  Widget _details(AccountController account) => widget.firstSetup
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 6),
          child: ProfileDetailsPanel(
            key: ValueKey(account.identity),
            repository: _detailsRepository!,
            userId: account.identity!,
            owner: true,
          ),
        );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.account,
    builder: (context, _) {
      final account = widget.account;
      if (account.guest) {
        return GuestAccountPage(account: account, name: widget.guestName);
      }
      return PopScope(
        canPop: !account.busy && !widget.firstSetup,
        child: Scaffold(
          backgroundColor: EmbunColors.bg,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const _AccountBackdrop(),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final wide = box.maxWidth >= 820;
                        final padH = box.maxWidth < 450 ? 14.0 : 24.0;
                        final body = wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 332,
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 32),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _preview(true),
                                          const SizedBox(height: 20),
                                          _nameField(account),
                                          _emailNote(account),
                                          const SizedBox(height: 18),
                                          _saveBlock(account),
                                          if (!widget.firstSetup) ...[
                                            const SizedBox(height: 8),
                                            _logout(account),
                                          ],
                                          const SizedBox(height: 12),
                                          const Align(
                                            alignment: Alignment.centerLeft,
                                            child: PublicInformationLinks(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        border: Border(left: _rule()),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          left: 32,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            _picker(account, true),
                                            _details(account),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _preview(false),
                                  const SizedBox(height: 16),
                                  _nameField(account),
                                  const SizedBox(height: 18),
                                  _picker(account, false),
                                  _emailNote(account),
                                  const SizedBox(height: 16),
                                  _saveBlock(account),
                                  _details(account),
                                  const SizedBox(height: 12),
                                  if (!widget.firstSetup) _logout(account),
                                  const PublicInformationLinks(),
                                ],
                              );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: padH),
                              child: _header(account),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                padding: EdgeInsets.fromLTRB(
                                  padH,
                                  wide ? 26 : 18,
                                  padH,
                                  32,
                                ),
                                child: Form(key: _form, child: body),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Guests have session information, not an editable persistent profile.
class GuestAccountPage extends StatelessWidget {
  const GuestAccountPage({
    super.key,
    required this.account,
    this.name = 'Tamu',
  });
  final AccountController account;
  final String name;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: account,
    builder: (context, _) => _AccountFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Kembali',
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          Center(
            child: PlayerAccountAvatar(
              name: name,
              googleLinked: false,
              radius: 44,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Bermain sebagai tamu',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: EmbunColors.gold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Pengguna belum menautkan akun Google.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Permainan belum disimpan di akun Anda. Tautkan ke Google untuk menyimpan profil, statistik, dan riwayat pertandingan berikutnya.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 12),
          const Text(
            'Sesi tamu dapat dilanjutkan di perangkat ini selama sesi masih tersimpan.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 20),
          GoogleSignInButton(
            key: const ValueKey('link-google'),
            label: 'Tautkan ke Google',
            onPressed: account.busy || account.waitingForGoogle
                ? null
                : account.login,
          ),
          TextButton(
            onPressed: account.busy || account.waitingForGoogle
                ? null
                : () => account.login(useExistingAccount: true),
            child: const Text('Masuk ke akun Google yang sudah ada'),
          ),
          if (account.waitingForGoogle) ...[
            const Text(
              'Selesaikan proses di halaman Google.',
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: account.cancelLoginWait,
              child: const Text('Batalkan / coba lagi'),
            ),
          ],
          if (account.error case final message?)
            Text(message, style: const TextStyle(color: Color(0xFFFFB5A8))),
          const SizedBox(height: 12),
          TextButton(
            onPressed: account.busy ? null : account.logout,
            child: const Text('Keluar dari sesi tamu'),
          ),
          const PublicInformationLinks(),
        ],
      ),
    ),
  );
}
