import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/validators.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../services/receipt_service.dart';

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

  // Ticket: ruta actual, la que se capturó en esta pantalla y si se guardó.
  String? _receiptPath;
  String? _newReceiptPath;
  bool _saved = false;
  Future<Uint8List?>? _receiptPreview;
  late ReceiptService _receipts;

  bool get _isEdit => widget.expense != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Se guarda la referencia para poder usarla de forma segura en dispose().
    _receipts = context.read<ReceiptService>();
  }

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _amountCtrl = TextEditingController(text: e == null ? '' : e.amount.toStringAsFixed(2));
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _categoryId = e?.categoryId;
    _date = e?.spentAt ?? DateTime.now();
    _receiptPath = e?.receiptPath;
    if (_receiptPath != null) {
      // context.read no está disponible en initState antes del primer frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() =>
            _receiptPreview = context.read<ReceiptService>().load(_receiptPath!));
      });
    }
  }

  Future<void> _captureReceipt({bool gallery = false}) async {
    final svc = context.read<ReceiptService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path =
          gallery ? await svc.pickFromGallery() : await svc.captureReceipt();
      if (path == null || !mounted) return;
      // Descarta una captura previa que aún no se había guardado.
      if (_newReceiptPath != null) await svc.remove(_newReceiptPath!);
      setState(() {
        _newReceiptPath = path;
        _receiptPath = path;
        _receiptPreview = svc.load(path);
      });
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('No se pudo acceder a la cámara. Revisa los permisos.')));
    }
  }

  Future<void> _removeReceipt() async {
    final svc = context.read<ReceiptService>();
    if (_newReceiptPath != null) {
      await svc.remove(_newReceiptPath!);
      _newReceiptPath = null;
    }
    if (!mounted) return;
    setState(() {
      _receiptPath = null;
      _receiptPreview = null;
    });
  }

  @override
  void dispose() {
    // Si se capturó un ticket y el usuario salió sin guardar, bórralo.
    if (!_saved && _newReceiptPath != null) {
      _receipts.remove(_newReceiptPath!);
    }
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
    final oldReceipt = widget.expense?.receiptPath;

    final bool ok;
    if (_isEdit) {
      final updated = widget.expense!.copyWith(
        amount: amount,
        description: description,
        categoryId: _categoryId,
        spentAt: _date,
        note: note,
        receiptPath: _receiptPath,
        clearReceipt: _receiptPath == null,
      );
      ok = await provider.updateExpense(updated);
    } else {
      ok = await provider.addExpense(Expense.create(
        amount: amount,
        description: description,
        categoryId: _categoryId!,
        spentAt: _date,
        note: note.isEmpty ? null : note,
        receiptPath: _receiptPath,
      ));
    }

    if (ok) {
      _saved = true;
      // El ticket anterior queda huérfano si fue reemplazado o eliminado.
      if (oldReceipt != null && oldReceipt != _receiptPath) {
        await _receipts.remove(oldReceipt);
      }
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
            _ReceiptSection(
              hasReceipt: _receiptPath != null,
              preview: _receiptPreview,
              onCamera: _captureReceipt,
              onGallery: () => _captureReceipt(gallery: true),
              onRemove: _removeReceipt,
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

/// Foto del ticket: captura con cámara, vista previa descifrada en memoria.
class _ReceiptSection extends StatelessWidget {
  const _ReceiptSection({
    required this.hasReceipt,
    required this.preview,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });

  final bool hasReceipt;
  final Future<Uint8List?>? preview;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.receipt_long_outlined),
              const SizedBox(width: 8),
              Text('Ticket o factura',
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              if (hasReceipt)
                IconButton(
                  tooltip: 'Quitar foto',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onRemove,
                ),
            ]),
            if (hasReceipt)
              FutureBuilder<Uint8List?>(
                future: preview,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final bytes = snap.data;
                  if (bytes == null) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('No se pudo leer la imagen (archivo faltante o alterado).'),
                    );
                  }
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(bytes, height: 200, width: double.infinity, fit: BoxFit.cover),
                  );
                },
              )
            else
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCamera,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Tomar foto'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galería'),
                  ),
                ),
              ]),
            const SizedBox(height: 6),
            Text('La imagen se guarda cifrada y no sale de tu dispositivo.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
