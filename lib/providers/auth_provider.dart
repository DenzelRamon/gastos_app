import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

enum ViewState { idle, loading, success, error }

/// Estado de autenticación con bloqueo temporal tras intentos fallidos.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._service) {
    _sub = _service.authChanges.listen((_) => notifyListeners());
  }

  static const int maxAttempts = 5;
  static const Duration lockDuration = Duration(seconds: 30);

  final AuthService _service;
  late final StreamSubscription<dynamic> _sub;

  ViewState state = ViewState.idle;
  String? errorMessage;
  String? infoMessage;
  int _failedAttempts = 0;
  DateTime? _lockedUntil;

  String? get userId => _service.currentUserId;
  String? get email => _service.currentEmail;

  bool get isLocked =>
      _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!);

  int get lockSecondsLeft => isLocked
      ? _lockedUntil!.difference(DateTime.now()).inSeconds + 1
      : 0;

  Future<void> signIn(String email, String password) async {
    if (isLocked) {
      _fail('Demasiados intentos. Espera $lockSecondsLeft s.');
      return;
    }
    await _run(() async {
      await _service.signIn(email, password);
      _failedAttempts = 0;
    }, onFailure: _registerFailure);
  }

  Future<void> signUp(String email, String password) async {
    await _run(() async {
      final hasSession = await _service.signUp(email, password);
      if (!hasSession) {
        infoMessage = 'Cuenta creada. Revisa tu correo para confirmarla.';
      }
    });
  }

  Future<void> signOut() => _service.signOut();

  Future<void> _run(Future<void> Function() action,
      {void Function()? onFailure}) async {
    state = ViewState.loading;
    errorMessage = null;
    infoMessage = null;
    notifyListeners();
    try {
      await action();
      state = ViewState.success;
    } on AuthFailure catch (e) {
      onFailure?.call();
      _fail(e.message);
      return;
    }
    notifyListeners();
  }

  void _registerFailure() {
    _failedAttempts++;
    if (_failedAttempts >= maxAttempts) {
      _lockedUntil = DateTime.now().add(lockDuration);
      _failedAttempts = 0;
    }
  }

  void _fail(String message) {
    state = ViewState.error;
    errorMessage = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
