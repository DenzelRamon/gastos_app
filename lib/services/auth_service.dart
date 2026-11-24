import 'package:supabase_flutter/supabase_flutter.dart';

/// Error de autenticación con mensaje seguro para mostrar al usuario.
class AuthFailure implements Exception {
  AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthService {
  GoTrueClient get _auth => Supabase.instance.client.auth;

  String? get currentUserId => _auth.currentUser?.id;
  String? get currentEmail => _auth.currentUser?.email;
  Stream<AuthState> get authChanges => _auth.onAuthStateChange;

  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithPassword(email: email.trim(), password: password);
    } on AuthException {
      // Mensaje genérico: no revela si el correo existe.
      throw AuthFailure('Correo o contraseña incorrectos');
    } catch (_) {
      throw AuthFailure('No se pudo conectar. Revisa tu internet.');
    }
  }

  /// Devuelve `true` si la sesión quedó iniciada y `false` si Supabase exige
  /// confirmar el correo antes de entrar.
  Future<bool> signUp(String email, String password) async {
    try {
      final res = await _auth.signUp(email: email.trim(), password: password);
      return res.session != null;
    } on AuthException catch (e) {
      if (e.statusCode == '429') {
        throw AuthFailure('Demasiados intentos. Espera un momento.');
      }
      throw AuthFailure('No se pudo crear la cuenta. Intenta con otro correo.');
    } catch (_) {
      throw AuthFailure('No se pudo conectar. Revisa tu internet.');
    }
  }

  Future<void> signOut() => _auth.signOut();
}
