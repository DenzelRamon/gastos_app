import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/config.dart';

/// Notificaciones locales: alertas inmediatas de presupuesto y un
/// recordatorio semanal programado (domingos 20:00).
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int weeklyReminderId = 1;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'budget_alerts',
      'Alertas de presupuesto',
      channelDescription: 'Avisos cuando te acercas o superas tu presupuesto',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(AppConfig.timeZoneName));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings);
  }

  /// Pide permiso (Android 13+ / iOS). Devuelve true si fue concedido.
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final a = await android?.requestNotificationsPermission();
    final i = await ios?.requestPermissions(alert: true, badge: true, sound: true);
    return (a ?? i ?? true);
  }

  /// Alerta inmediata; [id] estable por presupuesto/umbral evita duplicados.
  Future<void> showBudgetAlert({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      await _plugin.show(id, title, body, _details);
    } catch (e) {
      if (kDebugMode) debugPrint('No se pudo mostrar la notificación: $e');
    }
  }

  /// Recordatorio semanal programado: cada domingo a las 20:00.
  Future<void> scheduleWeeklyReminder() async {
    await _plugin.zonedSchedule(
      weeklyReminderId,
      'Revisa tu presupuesto semanal',
      'Cierra la semana: revisa cuánto gastaste y cuánto te queda.',
      nextInstanceOf(DateTime.sunday, 20),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  /// Próxima fecha futura con el día de semana y hora indicados.
  @visibleForTesting
  static tz.TZDateTime nextInstanceOf(int weekday, int hour, {tz.TZDateTime? now}) {
    final current = now ?? tz.TZDateTime.now(tz.local);
    var date = tz.TZDateTime(tz.local, current.year, current.month, current.day, hour);
    while (date.weekday != weekday || !date.isAfter(current)) {
      date = date.add(const Duration(days: 1));
    }
    return date;
  }
}
