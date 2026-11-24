import 'package:uuid/uuid.dart';

enum BudgetPeriod {
  weekly('weekly', 'Semanal'),
  monthly('monthly', 'Mensual');

  const BudgetPeriod(this.key, this.label);
  final String key;
  final String label;

  static BudgetPeriod fromKey(String key) =>
      BudgetPeriod.values.firstWhere((p) => p.key == key,
          orElse: () => BudgetPeriod.monthly);
}

/// Presupuesto por periodo. Si [categoryId] es null aplica a todos los gastos.
class Budget {
  Budget({
    required this.id,
    required this.limitAmount,
    required this.period,
    this.categoryId,
    this.categoryName,
    DateTime? updatedAt,
    this.synced = false,
  }) : updatedAt = updatedAt ?? DateTime.now().toUtc();

  factory Budget.create({
    required double limitAmount,
    required BudgetPeriod period,
    String? categoryId,
  }) =>
      Budget(
        id: const Uuid().v4(),
        limitAmount: limitAmount,
        period: period,
        categoryId: categoryId,
      );

  final String id;
  final double limitAmount;
  final BudgetPeriod period;
  final String? categoryId;
  final String? categoryName; // solo lectura (JOIN)
  final DateTime updatedAt;
  final bool synced;

  String get title => categoryName ?? 'Todos los gastos';

  Map<String, Object?> toRow() => {
        'id': id,
        'category_id': categoryId,
        'limit_amount': limitAmount,
        'period': period.key,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'synced': 0,
        'deleted': 0,
      };

  factory Budget.fromRow(Map<String, Object?> m) => Budget(
        id: m['id'] as String,
        limitAmount: (m['limit_amount'] as num).toDouble(),
        period: BudgetPeriod.fromKey(m['period'] as String),
        categoryId: m['category_id'] as String?,
        categoryName: m['category_name'] as String?,
        updatedAt: DateTime.parse(m['updated_at'] as String),
        synced: (m['synced'] as int) == 1,
      );
}
