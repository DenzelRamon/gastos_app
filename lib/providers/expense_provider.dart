import 'package:flutter/foundation.dart';

import '../data/budget_repository.dart';
import '../data/category_repository.dart';
import '../data/expense_repository.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/expense.dart';
import 'auth_provider.dart' show ViewState;

/// Estado de gastos, categorías y presupuestos.
/// Expone [state] y [errorMessage] para mostrar carga y error en la UI.
class ExpenseProvider extends ChangeNotifier {
  ExpenseProvider({
    required this.expenses,
    required this.categories,
    required this.budgets,
  });

  final ExpenseRepository expenses;
  final CategoryRepository categories;
  final BudgetRepository budgets;

  ViewState state = ViewState.idle;
  String? errorMessage;

  List<Expense> items = [];
  List<Category> categoryList = [];
  List<Budget> budgetList = [];

  /// Se invoca tras cada cambio en gastos/presupuestos (alertas de presupuesto).
  Future<void> Function()? onDataChanged;

  Category? categoryById(String id) {
    for (final c in categoryList) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> load() async {
    await _guard(() async {
      categoryList = await categories.getAll();
      budgetList = await budgets.getAll();
      items = await expenses.getAll();
    }, showLoading: items.isEmpty);
  }

  Future<bool> addExpense(Expense e) =>
      _mutate(() => expenses.create(e));

  Future<bool> updateExpense(Expense e) =>
      _mutate(() => expenses.update(e));

  Future<bool> deleteExpense(String id) =>
      _mutate(() => expenses.delete(id));

  Future<bool> saveBudget(Budget b, {required bool isNew}) =>
      _mutate(() => isNew ? budgets.create(b) : budgets.update(b));

  Future<bool> deleteBudget(String id) =>
      _mutate(() => budgets.delete(id));

  Future<bool> _mutate(Future<void> Function() action) async {
    var ok = false;
    await _guard(() async {
      await action();
      categoryList = await categories.getAll();
      budgetList = await budgets.getAll();
      items = await expenses.getAll();
      ok = true;
    }, showLoading: false);
    if (ok) {
      try {
        await onDataChanged?.call();
      } catch (_) {
        // Una alerta fallida nunca debe invalidar el guardado.
      }
    }
    return ok;
  }

  Future<void> _guard(Future<void> Function() body,
      {required bool showLoading}) async {
    if (showLoading) {
      state = ViewState.loading;
      notifyListeners();
    }
    try {
      await body();
      state = ViewState.success;
      errorMessage = null;
    } catch (e) {
      state = ViewState.error;
      errorMessage = 'No se pudo completar la operación. Intenta de nuevo.';
      if (kDebugMode) debugPrint('ExpenseProvider error: $e');
    }
    notifyListeners();
  }
}
