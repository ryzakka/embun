import 'dart:async';
import 'package:flutter/foundation.dart';
import 'player_profile.dart';

abstract class AccountRepository {
  PlayerProfile? get current;
  Stream<PlayerProfile?> get changes;
  Future<PlayerProfile?> restore();
  Future<bool> signInWithGoogle();
  Future<PlayerProfile> saveProfile({
    required String userId,
    required String nickname,
    required String avatarId,
  });
  Future<void> signOut();
}

/// OAuth browser launch is not a successful login. Only auth snapshots open
/// the gate. Auth errors retain the current session; signedOut clears it.
class AccountController extends ChangeNotifier {
  AccountController(
    this.repository, {
    this.loginWait = const Duration(seconds: 60),
  });
  final AccountRepository repository;
  final Duration loginWait;
  PlayerProfile? profile;
  bool restoring = true, busy = false, waitingForGoogle = false;
  String? error;
  StreamSubscription<PlayerProfile?>? _subscription;
  Timer? _waitTimer;
  bool _disposed = false;
  int _revision = 0;

  bool get googleAccount => profile?.googleAccount ?? false;
  bool get ready => profile?.complete ?? false;
  String? get identity => googleAccount ? profile!.userId : null;

  Future<void> start() async {
    if (_subscription != null || _disposed) return;
    _subscription = repository.changes.listen(
      _accept,
      onError: (Object e) {
        if (_disposed) return;
        error = 'Sesi belum dapat diperbarui. Periksa koneksi internetmu.';
        notifyListeners();
      },
    );
    final revision = _revision;
    try {
      final restored = await repository.restore();
      if (!_disposed && _revision == revision) _accept(restored);
    } catch (_) {
      if (!_disposed && _revision == revision) {
        profile = null;
        error =
            'Belum dapat memulihkan sesi. Coba masuk kembali saat koneksi tersedia.';
      }
    } finally {
      if (!_disposed) {
        restoring = false;
        notifyListeners();
      }
    }
  }

  void _accept(PlayerProfile? value) {
    if (_disposed) return;
    _revision++;
    profile = value;
    error = null;
    if (googleAccount) cancelLoginWait(notify: false);
    notifyListeners();
  }

  Future<void> login() async {
    if (busy || waitingForGoogle || _disposed) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final launched = await repository.signInWithGoogle();
      if (_disposed) return;
      if (!launched) {
        error = 'Halaman Google tidak dapat dibuka. Coba lagi.';
      } else if (!googleAccount) {
        waitingForGoogle = true;
        _waitTimer?.cancel();
        _waitTimer = Timer(loginWait, () {
          if (_disposed) return;
          waitingForGoogle = false;
          error = 'Login belum selesai. Kamu dapat mencoba kembali.';
          notifyListeners();
        });
      }
    } catch (_) {
      if (!_disposed) {
        error = 'Login Google belum tersedia. Coba lagi beberapa saat.';
      }
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void cancelLoginWait({bool notify = true}) {
    _waitTimer?.cancel();
    _waitTimer = null;
    waitingForGoogle = false;
    if (notify && !_disposed) notifyListeners();
  }

  Future<bool> save(String name, String avatarId) async {
    if (busy || _disposed || !googleAccount) return false;
    final nameError = nicknameError(name);
    if (nameError != null || !profileAvatarIds.contains(avatarId)) {
      error = nameError ?? 'Pilih avatar yang tersedia.';
      notifyListeners();
      return false;
    }
    final userId = profile!.userId;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final saved = await repository.saveProfile(
        userId: userId,
        nickname: normalizeNickname(name),
        avatarId: avatarId,
      );
      if (_disposed || profile?.userId != userId || saved.userId != userId) {
        return false;
      }
      _accept(saved);
      return true;
    } catch (_) {
      if (!_disposed && profile?.userId == userId) {
        error = 'Profil belum tersimpan. Periksa koneksi dan coba lagi.';
      }
      return false;
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> logout() async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await repository.signOut();
      if (!_disposed) _accept(null);
    } catch (_) {
      if (!_disposed) error = 'Belum dapat keluar akun. Coba lagi.';
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _waitTimer?.cancel();
    super.dispose();
  }
}
