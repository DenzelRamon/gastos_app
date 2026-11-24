import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config.dart';
import 'core/secure_store.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting(AppConfig.currencyLocale);

  if (AppConfig.isConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
      // Tokens de sesión en Keychain/Keystore en lugar de SharedPreferences.
      authOptions: FlutterAuthClientOptions(localStorage: SecureLocalStorage()),
    );
  }

  final notifications = NotificationService();
  await notifications.init();

  runApp(GastosApp(notifications: notifications));
}
