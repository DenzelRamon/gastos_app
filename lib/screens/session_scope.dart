import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/crypto_service.dart';
import '../core/secure_store.dart';
import '../data/budget_repository.dart';
import '../data/category_repository.dart';
import '../data/database_helper.dart';
import '../data/expense_repository.dart';
import '../providers/expense_provider.dart';
import '../providers/sync_provider.dart';
import '../services/budget_alert_service.dart';
import '../services/notification_service.dart';
import '../services/receipt_service.dart';
import '../services/sync_service.dart';
import 'home_screen.dart';

/// Crea todo lo que depende del usuario autenticado: base de datos local,
/// llave de cifrado, repositorios y providers. Se destruye al cerrar sesión.
class SessionScope extends StatefulWidget {
  const SessionScope({super.key, required this.userId});
  final String userId;

  @override
  State<SessionScope> createState() => _SessionScopeState();
}

class _SessionScopeState extends State<SessionScope> {
  late final CryptoService _crypto;
  late final ExpenseRepository _expenses;
  late final CategoryRepository _categories;
  late final BudgetRepository _budgets;
  late final ReceiptService _receipts;
  late final ExpenseProvider _expenseProvider;
  late final SyncProvider _syncProvider;
  BudgetAlertService? _alerts;
  Future<void>? _ready;

  @override
  void initState() {
    super.initState();
    _crypto = CryptoService(SecureStore.instance, widget.userId);
    _expenses = ExpenseRepository(_crypto);
    _categories = CategoryRepository();
    _budgets = BudgetRepository();
    _receipts = ReceiptService(_crypto);
    _expenseProvider = ExpenseProvider(
      expenses: _expenses,
      categories: _categories,
      budgets: _budgets,
    );
    _syncProvider = SyncProvider(SyncService())
      ..onSynced = () => _expenseProvider.load();
    _ready = _bootstrap();
  }

  Future<void> _bootstrap() async {
    await DatabaseHelper.instance.open(widget.userId);
    await _expenseProvider.load();
    if (!mounted) return;

    final notifications = context.read<NotificationService>();
    _alerts = BudgetAlertService(
      expenses: _expenses,
      budgets: _budgets,
      notifications: notifications,
      userId: widget.userId,
    );
    _expenseProvider.onDataChanged = _alerts!.checkAndNotify;

    // Tareas de arranque que no bloquean la pantalla.
    () async {
      try {
        if (await notifications.requestPermission()) {
          await notifications.scheduleWeeklyReminder();
        }
        await _alerts!.checkAndNotify();
      } catch (_) {}
      await _syncProvider.sync();
    }();
  }

  @override
  void dispose() {
    _expenseProvider.dispose();
    _syncProvider.dispose();
    DatabaseHelper.instance.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError || _alerts == null) {
          return const Scaffold(
            body: Center(child: Text('No se pudo abrir tu base de datos local.')),
          );
        }
        return MultiProvider(
          providers: [
            Provider<ExpenseRepository>.value(value: _expenses),
            Provider<ReceiptService>.value(value: _receipts),
            Provider<BudgetAlertService>.value(value: _alerts!),
            ChangeNotifierProvider<ExpenseProvider>.value(value: _expenseProvider),
            ChangeNotifierProvider<SyncProvider>.value(value: _syncProvider),
          ],
          child: const HomeScreen(),
        );
      },
    );
  }
}
