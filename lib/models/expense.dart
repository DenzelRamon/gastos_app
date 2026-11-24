import 'package:uuid/uuid.dart';

/// Gasto. Pertenece a una [Category].
///
/// `note` y la imagen del ticket son datos sensibles: se cifran antes de
/// escribirse en disco y no se sincronizan con la nube.
class Expense {
  Expense({
    required this.id,
    required this.amount,
    required this.description,
    required this.categoryId,
    required this.spentAt,
    this.note,
    this.receiptPath,
    this.categoryName,
    this.categoryColor,
    DateTime? updatedAt,
    this.synced = false,
  }) : updatedAt = updatedAt ?? DateTime.now().toUtc();

  factory Expense.create({
    required double amount,
    required String description,
    required String categoryId,
    required DateTime spentAt,
    String? note,
    String? receiptPath,
  }) =>
      Expense(
        id: const Uuid().v4(),
        amount: amount,
        description: description,
        categoryId: categoryId,
        spentAt: spentAt,
        note: note,
        receiptPath: receiptPath,
      );

  final String id;
  final double amount;
  final String description;
  final String categoryId;
  final DateTime spentAt;
  final String? note;
  final String? receiptPath;
  final String? categoryName; // solo lectura (JOIN)
  final int? categoryColor; // solo lectura (JOIN)
  final DateTime updatedAt;
  final bool synced;

  Expense copyWith({
    double? amount,
    String? description,
    String? categoryId,
    DateTime? spentAt,
    String? note,
    String? receiptPath,
    bool clearReceipt = false,
  }) =>
      Expense(
        id: id,
        amount: amount ?? this.amount,
        description: description ?? this.description,
        categoryId: categoryId ?? this.categoryId,
        spentAt: spentAt ?? this.spentAt,
        note: note ?? this.note,
        receiptPath: clearReceipt ? null : (receiptPath ?? this.receiptPath),
      );

  /// Fila para SQLite. [noteEnc] es la nota ya cifrada.
  Map<String, Object?> toRow({String? noteEnc}) => {
        'id': id,
        'category_id': categoryId,
        'amount': amount,
        'description': description,
        'note_enc': noteEnc,
        'receipt_path': receiptPath,
        'spent_at': spentAt.toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'synced': 0,
        'deleted': 0,
      };

  factory Expense.fromRow(Map<String, Object?> m, {String? note}) => Expense(
        id: m['id'] as String,
        amount: (m['amount'] as num).toDouble(),
        description: m['description'] as String,
        categoryId: m['category_id'] as String,
        spentAt: DateTime.parse(m['spent_at'] as String).toLocal(),
        note: note,
        receiptPath: m['receipt_path'] as String?,
        categoryName: m['category_name'] as String?,
        categoryColor: m['category_color'] as int?,
        updatedAt: DateTime.parse(m['updated_at'] as String),
        synced: (m['synced'] as int) == 1,
      );
}
