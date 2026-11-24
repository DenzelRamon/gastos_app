import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_app/core/period.dart';
import 'package:gastos_app/models/budget.dart';

void main() {
  group('PeriodRange.weekly', () {
    test('la semana empieza en lunes y dura 7 días', () {
      // Miércoles 25 de noviembre de 2026
      final r = PeriodRange.of(BudgetPeriod.weekly, DateTime(2026, 11, 25, 14, 30));
      expect(r.start, DateTime(2026, 11, 23)); // lunes
      expect(r.end, DateTime(2026, 11, 30));
    });

    test('un domingo pertenece a la semana que empezó el lunes anterior', () {
      final r = PeriodRange.of(BudgetPeriod.weekly, DateTime(2026, 11, 29, 23, 59));
      expect(r.start, DateTime(2026, 11, 23));
    });

    test('cruza el cambio de año', () {
      final r = PeriodRange.of(BudgetPeriod.weekly, DateTime(2027, 1, 1));
      expect(r.start, DateTime(2026, 12, 28));
      expect(r.end, DateTime(2027, 1, 4));
    });
  });

  group('PeriodRange.monthly', () {
    test('cubre el mes calendario', () {
      final r = PeriodRange.of(BudgetPeriod.monthly, DateTime(2026, 2, 14));
      expect(r.start, DateTime(2026, 2));
      expect(r.end, DateTime(2026, 3));
    });

    test('diciembre termina el 1 de enero', () {
      final r = PeriodRange.of(BudgetPeriod.monthly, DateTime(2026, 12, 31));
      expect(r.end, DateTime(2027, 1));
    });
  });

  test('key identifica de forma estable el periodo', () {
    final a = PeriodRange.of(BudgetPeriod.weekly, DateTime(2026, 11, 24));
    final b = PeriodRange.of(BudgetPeriod.weekly, DateTime(2026, 11, 27));
    final c = PeriodRange.of(BudgetPeriod.weekly, DateTime(2026, 12, 1));
    expect(a.key, b.key);
    expect(a.key, isNot(c.key));
  });
}
