/// Validación y saneamiento de entradas del usuario.
/// Cada método devuelve `null` si es válido o el mensaje de error en español.
class Validators {
  const Validators._();

  static final RegExp _emailRe = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

  static String? email(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Ingresa tu correo';
    if (v.length > 254 || !_emailRe.hasMatch(v)) return 'Correo no válido';
    return null;
  }

  /// Mínimo 8 caracteres con mayúscula, minúscula y número.
  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Ingresa tu contraseña';
    if (v.length < 8) return 'Mínimo 8 caracteres';
    if (v.length > 72) return 'Máximo 72 caracteres';
    if (!RegExp(r'[a-z]').hasMatch(v)) return 'Incluye una minúscula';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Incluye una mayúscula';
    if (!RegExp(r'\d').hasMatch(v)) return 'Incluye un número';
    return null;
  }

  static String? amount(String? value) {
    final n = double.tryParse((value ?? '').trim());
    if (n == null || n <= 0) return 'Ingresa un monto mayor a 0';
    return null;
  }

  static String? description(String? value) {
    final v = sanitize(value ?? '');
    if (v.isEmpty) return 'Ingresa una descripción';
    if (v.length < 2) return 'Mínimo 2 caracteres';
    if (v.length > 80) return 'Máximo 80 caracteres';
    return null;
  }

  static String? note(String? value) {
    if ((value ?? '').length > 500) return 'Máximo 500 caracteres';
    return null;
  }

  /// Colapsa espacios y recorta extremos.
  static String sanitize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  static double parseAmount(String value) => double.parse(value.trim());
}
