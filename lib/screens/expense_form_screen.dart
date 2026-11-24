import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/validators.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';

/// Crea o edita un gasto. Si [expense] es null, es una alta.
class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({super.key, this.expense});
  final Expense? expense;

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _noteCtrl;
  String? _categoryId;
  late DateTime _date;
  bool _saving = false;

  bool get _isEdit => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _amountCtrl = TextEditingController(text: e == null ? '' : e.amount.toStringAsFixed(2));
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _categoryId = e?.categoryId;
    _date = e?.spentAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day,
          _date.hour, _date.minute));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<ExpenseProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _saving = true);

    final amount = Validators.parseAmount(_amountCtrl.text);
    final description = Validators.sanitize(_descCtrl.text);
    final note = _noteCtrl.text.trim();

    final bool ok;
    if (_isEdit) {
      final updated = widget.expense!.copyWith(
        amount: amount,
        description: description,
        categoryId: _categoryId,
        spentAt: _date,
        note: note,
      );
      ok = await provider.updateExpense(updated);
    } else {
      ok = await provider.addExpense(Expense.create(
        amount: amount,
        description: description,
        categoryId: _categoryId!,
        spentAt: _date,
        note: note.isEmpty ? null : note,
      ));
    }

    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      nav.pop();
    } else {
      messenger.showSnackBar(SnackBar(
          content: Text(provider.errorMessage ?? 'Error al guardar')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<ExpenseProvider>().categoryList;

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Editar gasto' : 'Nuevo gasto')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Monto',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
              validator: Validators.amount,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(),
              ),
              validator: Validators.description,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _categoryId,
              decoration: const InputDecoration(
                labelText: 'Categoría',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final c in categories)
                  DropdownMenuItem(
                    value: c.id,
                    child: Row(children: [
                      CircleAvatar(radius: 6, backgroundColor: Color(c.colorValue)),
                      const SizedBox(width: 8),
                      Text(c.name),
                    ]),
                  ),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
              validator: (v) => v == null ? 'Elige una categoría' : null,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fecha',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(Fmt.date(_date)),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteCtrl,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Nota privada (se guarda cifrada)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: Validators.note,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(_isEdit ? 'Guardar cambios' : 'Guardar gasto'),
            ),
          ],
        ),
      ),
    );
  }
}
