/// Configuración global. Las credenciales se inyectan en tiempo de compilación:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJ...
///
/// Así nunca quedan escritas en el repositorio.
class AppConfig {
  const AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Zona horaria para programar notificaciones.
  static const String timeZoneName = 'America/Mexico_City';

  /// Porcentaje del presupuesto que dispara la alerta preventiva.
  static const double budgetAlertThreshold = 0.8;

  static const String currencyLocale = 'es_MX';
  static const String currencySymbol = '\$';
}
