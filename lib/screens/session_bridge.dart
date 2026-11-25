import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../data/expense_repository.dart';
import '../providers/expense_provider.dart';
import '../providers/sync_provider.dart';
import '../services/budget_alert_service.dart';
import '../services/receipt_service.dart';

/// Las rutas que se abren con Navigator.push o showModalBottomSheet cuelgan
/// del Navigator de MaterialApp, por encima de los providers de la sesión.
/// Este puente vuelve a proveerlos dentro de la nueva ruta.
class SessionBridge {
  const SessionBridge._();

  static Widget wrap(BuildContext from, Widget child) {
    return MultiProvider(
      providers: [
        Provider<ExpenseRepository>.value(value: from.read<ExpenseRepository>()),
        Provider<ReceiptService>.value(value: from.read<ReceiptService>()),
        Provider<BudgetAlertService>.value(value: from.read<BudgetAlertService>()),
        ChangeNotifierProvider<ExpenseProvider>.value(value: from.read<ExpenseProvider>()),
        ChangeNotifierProvider<SyncProvider>.value(value: from.read<SyncProvider>()),
      ],
      child: child,
    );
  }
}
