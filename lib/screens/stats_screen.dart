import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../data/expense_repository.dart';
import '../providers/expense_provider.dart';

class _StatsData {
  _StatsData(this.byCategory, this.months, this.monthTotals);
  final List<CategoryTotal> byCategory;
  final List<DateTime> months;
  final List<double> monthTotals;
}

/// Gráfico de pastel (mes actual por categoría) y barras (últimos 6 meses),
/// dibujados con la librería `fl_chart`.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Future<_StatsData>? _future;

  Future<_StatsData> _load(ExpenseRepository repo) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    final end = DateTime(now.year, now.month + 1);
    final byCat = await repo.totalsByCategory(start, end);

    final months = <DateTime>[];
    final totals = <double>[];
    for (var i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i);
      months.add(m);
      totals.add(await repo.totalSpent(m, DateTime(m.year, m.month + 1)));
    }
    return _StatsData(byCat, months, totals);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ExpenseRepository>();
    // Reconstruye el futuro cuando cambia la lista de gastos.
    context.select<ExpenseProvider, int>((p) => p.items.length);
    _future = _load(repo);

    return FutureBuilder<_StatsData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || snap.data == null) {
          return const Center(child: Text('No se pudieron cargar las estadísticas'));
        }
        final data = snap.data!;
        final total = data.byCategory.fold<double>(0, (s, c) => s + c.total);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Este mes por categoría',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Total: ${Fmt.money(total)}'),
            const SizedBox(height: 16),
            if (data.byCategory.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('Sin gastos este mes')),
              )
            else ...[
              SizedBox(
                height: 220,
                child: PieChart(PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 44,
                  sections: [
                    for (final c in data.byCategory)
                      PieChartSectionData(
                        value: c.total,
                        color: Color(c.colorValue),
                        radius: 56,
                        title: '${(c.total / total * 100).round()}%',
                        titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                  ],
                )),
              ),
              const SizedBox(height: 12),
              for (final c in data.byCategory)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(radius: 7, backgroundColor: Color(c.colorValue)),
                  title: Text(c.name),
                  trailing: Text(Fmt.money(c.total)),
                ),
            ],
            const Divider(height: 32),
            Text('Últimos 6 meses', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(height: 220, child: _MonthlyBars(data: data)),
          ],
        );
      },
    );
  }
}

class _MonthlyBars extends StatelessWidget {
  const _MonthlyBars({required this.data});
  final _StatsData data;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final maxY = data.monthTotals.fold<double>(0, (m, v) => v > m ? v : m);

    return BarChart(BarChartData(
      maxY: maxY == 0 ? 100 : maxY * 1.2,
      gridData: const FlGridData(drawVerticalLine: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        leftTitles: const AxisTitles(),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (i < 0 || i >= data.months.length) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(Fmt.monthShort(data.months[i]),
                    style: const TextStyle(fontSize: 11)),
              );
            },
          ),
        ),
      ),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, _, rod, __) => BarTooltipItem(
            Fmt.money(rod.toY),
            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      barGroups: [
        for (var i = 0; i < data.monthTotals.length; i++)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: data.monthTotals[i],
              color: color,
              width: 22,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ]),
      ],
    ));
  }
}
