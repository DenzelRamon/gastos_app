import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../models/expense.dart';
import '../providers/auth_provider.dart' show ViewState;
import '../providers/expense_provider.dart';
import 'expense_form_screen.dart';

class ExpenseListScreen extends StatelessWidget {
  const ExpenseListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ExpenseProvider>();

    Widget body;
    if (p.state == ViewState.loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (p.state == ViewState.error && p.items.isEmpty) {
      body = _ErrorView(message: p.errorMessage, onRetry: p.load);
    } else if (p.items.isEmpty) {
      body = const _EmptyView();
    } else {
      body = RefreshIndicator(
        onRefresh: p.load,
        child: ListView.separated(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: p.items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) => _ExpenseTile(expense: p.items[i]),
        ),
      );
    }

    return Scaffold(
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ExpenseFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Gasto'),
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense});
  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final color = Color(expense.categoryColor ?? 0xFF9E9E9E);
    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async =>
          await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Eliminar gasto'),
              content: Text('¿Eliminar "${expense.description}"?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Eliminar')),
              ],
            ),
          ) ??
          false,
      onDismissed: (_) async {
        final provider = context.read<ExpenseProvider>();
        final messenger = ScaffoldMessenger.of(context);
        final ok = await provider.deleteExpense(expense.id);
        messenger.showSnackBar(SnackBar(
            content: Text(ok ? 'Gasto eliminado' : 'No se pudo eliminar')));
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(Icons.receipt_long_outlined, color: color),
        ),
        title: Text(expense.description),
        subtitle: Text('${expense.categoryName ?? ''} · ${Fmt.date(expense.spentAt)}'),
        trailing: Text(
          Fmt.money(expense.amount),
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
              builder: (_) => ExpenseFormScreen(expense: expense)),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.savings_outlined,
                size: 72, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            const Text('Aún no tienes gastos'),
            const Text('Toca "Gasto" para registrar el primero'),
          ],
        ),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String? message;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 8),
            Text(message ?? 'Ocurrió un error'),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      );
}
