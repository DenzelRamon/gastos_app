import '../core/config.dart';
import '../core/formatters.dart';
import '../core/period.dart';
import '../core/secure_store.dart';
import '../data/budget_repository.dart';
import '../data/expense_repository.dart';
import '../models/budget.dart';
import 'notification_service.dart';

/// Progreso de un presupuesto en el periodo actual.
class BudgetProgress {
  const BudgetProgress(this.budget, this.spent);
  final Budget budget;
  final double spent;

  double get ratio => budget.limitAmount == 0 ? 0 : spent / budget.limitAmount;
  double get remaining => budget.limitAmount - spent;
  bool get overLimit => ratio >= 1;
  bool get nearLimit => ratio >= AppConfig.budgetAlertThreshold && !overLimit;
}

/// Calcula el avance de cada presupuesto y dispara notificaciones locales al
/// cruzar el 80 % y el 100 %. Cada umbral avisa una sola vez por periodo.
class BudgetAlertService {
  BudgetAlertService({
    required this.expenses,
    required this.budgets,
    required this.notifications,
    required this.userId,
    SecureStore? store,
  }) : _store = store ?? SecureStore.instance;

  final ExpenseRepository expenses;
  final BudgetRepository budgets;
  final NotificationService notifications;
  final String userId;
  final SecureStore _store;

  Future<List<BudgetProgress>> progress({DateTime? now}) async {
    final ref = now ?? DateTime.now();
    final list = await budgets.getAll();
    final result = <BudgetProgress>[];
    for (final b in list) {
      final range = PeriodRange.of(b.period, ref);
      final spent = await expenses.totalSpent(range.start, range.end,
          categoryId: b.categoryId);
      result.add(BudgetProgress(b, spent));
    }
    return result;
  }

  Future<void> checkAndNotify({DateTime? now}) async {
    final ref = now ?? DateTime.now();
    for (final p in await progress(now: ref)) {
      final range = PeriodRange.of(p.budget.period, ref);
      final base = 'alert_${userId}_${p.budget.id}_${range.key}';
      final pct = (p.ratio * 100).round();

      if (p.overLimit) {
        await _notifyOnce(
          '${base}_100',
          p,
          'Presupuesto superado',
          'Superaste tu presupuesto ${p.budget.period.label.toLowerCase()} de '
              '${p.budget.title} (${Fmt.money(p.spent)} de ${Fmt.money(p.budget.limitAmount)}).',
        );
      } else if (p.nearLimit) {
        await _notifyOnce(
          '${base}_80',
          p,
          'Has superado el 80% de tu presupuesto',
          'Llevas $pct% de tu presupuesto ${p.budget.period.label.toLowerCase()} de '
              '${p.budget.title}. Te quedan ${Fmt.money(p.remaining)}.',
        );
      }
    }
  }

  Future<void> _notifyOnce(
      String key, BudgetProgress p, String title, String body) async {
    if (await _store.contains(key)) return;
    await notifications.showBudgetAlert(
      id: key.hashCode & 0x7fffffff,
      title: title,
      body: body,
    );
    await _store.write(key, '1');
  }
}
