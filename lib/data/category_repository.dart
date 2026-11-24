import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/category.dart';
import 'database_helper.dart';

class CategoryInUseException implements Exception {
  @override
  String toString() => 'La categoría tiene gastos o presupuestos asociados';
}

class CategoryRepository {
  Database get _db => DatabaseHelper.instance.db;

  Future<List<Category>> getAll() async {
    final rows = await _db.query('categories',
        where: 'deleted = 0', orderBy: 'name COLLATE NOCASE');
    return rows.map(Category.fromMap).toList();
  }

  Future<Category> create(String name, int colorValue) async {
    final c = Category(id: const Uuid().v4(), name: name, colorValue: colorValue);
    await _db.insert('categories', c.toMap());
    return c;
  }

  Future<void> update(Category c) async {
    await _db.update(
      'categories',
      {
        'name': c.name,
        'color': c.colorValue,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'synced': 0,
      },
      where: 'id = ?',
      whereArgs: [c.id],
    );
  }

  /// Borrado lógico; se bloquea si aún hay datos que la usan.
  Future<void> delete(String id) async {
    final used = Sqflite.firstIntValue(await _db.rawQuery(
          '''SELECT
               (SELECT COUNT(*) FROM expenses WHERE category_id = ? AND deleted = 0) +
               (SELECT COUNT(*) FROM budgets  WHERE category_id = ? AND deleted = 0)''',
          [id, id],
        )) ??
        0;
    if (used > 0) throw CategoryInUseException();
    await _db.update(
      'categories',
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
