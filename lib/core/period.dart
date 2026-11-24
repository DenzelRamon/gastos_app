import '../models/budget.dart';

/// Rango [start, end) de un periodo de presupuesto en hora local.
class PeriodRange {
  const PeriodRange(this.start, this.end);
  final DateTime start;
  final DateTime end;

  /// Identificador estable del periodo (sirve para no repetir alertas).
  String get key =>
      '${start.year}${start.month.toString().padLeft(2, '0')}${start.day.toString().padLeft(2, '0')}';

  /// Semana lunes-domingo o mes calendario que contiene a [ref].
  static PeriodRange of(BudgetPeriod period, DateTime ref) {
    switch (period) {
      case BudgetPeriod.weekly:
        final day = DateTime(ref.year, ref.month, ref.day);
        final start = day.subtract(Duration(days: day.weekday - DateTime.monday));
        return PeriodRange(start, DateTime(start.year, start.month, start.day + 7));
      case BudgetPeriod.monthly:
        return PeriodRange(
          DateTime(ref.year, ref.month),
          DateTime(ref.year, ref.month + 1),
        );
    }
  }
}
