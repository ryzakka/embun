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
import 'public_information_links.dart';

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Memulihkan sesi…'),
            ],
          ),
        );
      }
      if (!account.googleAccount) return GoogleLoginPage(account: account);
      if (!account.ready) {
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

class _AccountFrame extends StatelessWidget {
  const _AccountFrame({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: EmbunColors.bg,
    body: Stack(
      fit: StackFit.expand,
      children: [
        Backdrop(path: sceneryPath('rumahdesa-hijau'), dim: .72),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xE612241E),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: EmbunColors.gold.withValues(alpha: .35),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: child,
                  ),
                ),
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
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: account,
    builder: (context, _) => _AccountFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.eco_outlined, color: EmbunColors.gold, size: 52),
          const SizedBox(height: 14),
          const Text(
            'EMBUN',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: 6,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Selamat datang di desa',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, color: EmbunColors.gold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Masuk untuk menyimpan profil dan memakai nama panggilanmu di setiap permainan.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.6, color: Colors.white70),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const ValueKey('google-login'),
            onPressed: account.busy || account.waitingForGoogle
                ? null
                : account.login,
            icon: account.busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: const Text('Masuk dengan Google'),
          ),
          if (account.waitingForGoogle) ...[
            const SizedBox(height: 14),
            const Text(
              'Selesaikan login di halaman Google, lalu kembali ke Embun.',
              textAlign: TextAlign.center,
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
          const SizedBox(height: 16),
          const Text(
            'Kamu dapat memilih nama panggilan setelah masuk.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 12),
          const PublicInformationLinks(),
        ],
      ),
    ),
  );
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.account,
    this.firstSetup = false,
    this.detailsRepository,
  });
  final AccountController account;
  final bool firstSetup;
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

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.account,
    builder: (context, _) {
      final account = widget.account;
      return PopScope(
        canPop: !account.busy && !widget.firstSetup,
        child: _AccountFrame(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.firstSetup)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Kembali',
                      onPressed: account.busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),
                Text(
                  widget.firstSetup ? 'Kenalan dulu, yuk' : 'Profilku',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: EmbunColors.gold,
                  ),
                ),
                const SizedBox(height: 20),
                Center(child: ProfileAvatar(avatarId: _avatar, radius: 38)),
                const SizedBox(height: 20),
                TextFormField(
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
                  decoration: const InputDecoration(
                    labelText: 'Nama panggilan',
                    helperText: 'Nama yang dipakai saat masuk ruangan.',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Pilih avatar',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in profileAvatars.entries)
                      Semantics(
                        selected: _avatar == entry.key,
                        button: true,
                        label: entry.value.$2,
                        child: Tooltip(
                          message: entry.value.$2,
                          child: InkWell(
                            key: ValueKey('avatar-${entry.key}'),
                            borderRadius: BorderRadius.circular(40),
                            onTap: account.busy
                                ? null
                                : () => setState(() => _avatar = entry.key),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  width: 3,
                                  color: _avatar == entry.key
                                      ? EmbunColors.gold
                                      : Colors.transparent,
                                ),
                              ),
                              child: ProfileAvatar(
                                avatarId: entry.key,
                                radius: 25,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                if (account.profile?.email case final email?)
                  Text(
                    'Email Google terhubung\n$email',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                const SizedBox(height: 12),
                if (!widget.firstSetup)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Perubahan nama berlaku saat masuk ruangan berikutnya.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                if (account.error case final message?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        message,
                        style: const TextStyle(color: Color(0xFFFFB5A8)),
                      ),
                    ),
                  ),
                FilledButton(
                  key: const ValueKey('save-profile'),
                  onPressed: account.busy ? null : _save,
                  child: Text(
                    account.busy
                        ? 'Menyimpan…'
                        : widget.firstSetup
                        ? 'Simpan dan lanjutkan'
                        : 'Simpan profil',
                  ),
                ),
                if (!widget.firstSetup)
                  ProfileDetailsPanel(
                    key: ValueKey(account.identity),
                    repository: _detailsRepository!,
                    userId: account.identity!,
                    owner: true,
                  ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: account.busy ? null : account.logout,
                  child: const Text('Keluar akun'),
                ),
                const PublicInformationLinks(),
              ],
            ),
          ),
        ),
      );
    },
  );
}
