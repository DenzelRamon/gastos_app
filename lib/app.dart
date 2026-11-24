import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/config.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/session_scope.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';

class GastosApp extends StatelessWidget {
  const GastosApp({super.key, required this.notifications});
  final NotificationService notifications;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gastos App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal, brightness: Brightness.dark),
      ),
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX'), Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AppConfig.isConfigured
          ? MultiProvider(
              providers: [
                Provider<NotificationService>.value(value: notifications),
                ChangeNotifierProvider<AuthProvider>(
                  create: (_) => AuthProvider(AuthService()),
                ),
              ],
              child: const AuthGate(),
            )
          : const _MissingConfigScreen(),
    );
  }
}

/// Muestra el login o la app según exista sesión.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthProvider>().userId;
    if (userId == null) return const LoginScreen();
    // La llave fuerza a recrear toda la sesión si cambia de usuario.
    return SessionScope(key: ValueKey(userId), userId: userId);
  }
}

class _MissingConfigScreen extends StatelessWidget {
  const _MissingConfigScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Faltan las credenciales de Supabase.\n\n'
            'Ejecuta la app con:\n'
            'flutter run --dart-define=SUPABASE_URL=... '
            '--dart-define=SUPABASE_ANON_KEY=...',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
