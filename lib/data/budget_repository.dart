import 'package:sqflite/sqflite.dart';

import '../models/budget.dart';
import 'database_helper.dart';

class BudgetRepository {
  Database get _db => DatabaseHelper.instance.db;

  Future<List<Budget>> getAll() async {
    final rows = await _db.rawQuery('''
      SELECT b.*, c.name AS category_name
      FROM budgets b
      LEFT JOIN categories c ON c.id = b.category_id
      WHERE b.deleted = 0
      ORDER BY b.period, category_name
    ''');
    return rows.map(Budget.fromRow).toList();
  }

  Future<void> create(Budget b) =>
      _db.insert('budgets', b.toRow(), conflictAlgorithm: ConflictAlgorithm.abort);

  Future<void> update(Budget b) async {
    final row = b.toRow()..remove('id');
    await _db.update('budgets', row, where: 'id = ?', whereArgs: [b.id]);
  }

  Future<void> delete(String id) async {
    await _db.update(
      'budgets',
      {
        'deleted': 1,
        'synced': 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
