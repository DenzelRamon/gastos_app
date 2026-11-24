import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/validators.dart';
import '../models/budget.dart';
import '../providers/expense_provider.dart';
import '../services/budget_alert_service.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  Future<List<BudgetProgress>>? _future;

  void _reload() {
    final svc = context.read<BudgetAlertService>();
    setState(() => _future = svc.progress());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _openEditor({Budget? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BudgetEditor(existing: existing),
    );
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    // Recalcula cuando cambian los gastos.
    context.select<ExpenseProvider, int>((p) => p.items.length);

    return Scaffold(
      body: FutureBuilder<List<BudgetProgress>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
                child: OutlinedButton(
                    onPressed: _reload, child: const Text('Reintentar')));
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const Center(
                child: Text('Define un presupuesto semanal o mensual'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: list.length,
            itemBuilder: (_, i) => _BudgetCard(
              progress: list[i],
              onEdit: () => _openEditor(existing: list[i].budget),
              onDelete: () async {
                final ok = await context
                    .read<ExpenseProvider>()
                    .deleteBudget(list[i].budget.id);
                if (ok) _reload();
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Presupuesto'),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard(
      {required this.progress, required this.onEdit, required this.onDelete});
  final BudgetProgress progress;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = progress.overLimit
        ? scheme.error
        : progress.nearLimit
            ? Colors.orange
            : scheme.primary;
    final b = progress.budget;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text('${b.title} · ${b.period.label}',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton(icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
              IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete),
            ]),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress.ratio.clamp(0, 1).toDouble(),
              minHeight: 10,
              color: color,
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: 8),
            Text(
              '${Fmt.money(progress.spent)} de ${Fmt.money(b.limitAmount)} '
              '(${(progress.ratio * 100).round()}%)',
            ),
            Text(
              progress.overLimit
                  ? 'Excedido por ${Fmt.money(-progress.remaining)}'
                  : 'Disponible: ${Fmt.money(progress.remaining)}',
              style: TextStyle(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetEditor extends StatefulWidget {
  const _BudgetEditor({this.existing});
  final Budget? existing;

  @override
  State<_BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends State<_BudgetEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _limitCtrl;
  String? _categoryId;
  late BudgetPeriod _period;

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    _limitCtrl = TextEditingController(
        text: b == null ? '' : b.limitAmount.toStringAsFixed(2));
    _categoryId = b?.categoryId;
    _period = b?.period ?? BudgetPeriod.weekly;
  }

  @override
  void dispose() {
    _limitCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<ExpenseProvider>();
    final nav = Navigator.of(context);
    final limit = Validators.parseAmount(_limitCtrl.text);
    final existing = widget.existing;

    final budget = existing == null
        ? Budget.create(limitAmount: limit, period: _period, categoryId: _categoryId)
        : Budget(
            id: existing.id,
            limitAmount: limit,
            period: _period,
            categoryId: _categoryId,
          );
    final ok = await provider.saveBudget(budget, isNew: existing == null);
    if (mounted) nav.pop(ok);
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.read<ExpenseProvider>().categoryList;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? 'Nuevo presupuesto' : 'Editar presupuesto',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _limitCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: const InputDecoration(
                  labelText: 'Límite', prefixText: '\$ ', border: OutlineInputBorder()),
              validator: Validators.amount,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _categoryId,
              decoration: const InputDecoration(
                  labelText: 'Categoría', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('Todos los gastos')),
                for (final c in categories)
                  DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 12),
            SegmentedButton<BudgetPeriod>(
              segments: [
                for (final p in BudgetPeriod.values)
                  ButtonSegment(value: p, label: Text(p.label)),
              ],
              selected: {_period},
              onSelectionChanged: (s) => setState(() => _period = s.first),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('Guardar')),
          ],
        ),
      ),
    );
  }
}
