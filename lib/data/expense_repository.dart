import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../core/crypto_service.dart';
import '../models/expense.dart';
import 'database_helper.dart';

class CategoryTotal {
  const CategoryTotal(this.name, this.colorValue, this.total);
  final String name;
  final int colorValue;
  final double total;
}

/// CRUD de gastos. La nota se cifra al escribir y se descifra al leer.
class ExpenseRepository {
  ExpenseRepository(this._crypto);

  final CryptoService _crypto;
  Database get _db => DatabaseHelper.instance.db;

  // ---- Create ----
  Future<Expense> create(Expense e) async {
    await _db.insert('expenses', await _toRow(e),
        conflictAlgorithm: ConflictAlgorithm.abort);
    return e;
  }

  // ---- Read ----
  Future<List<Expense>> getAll({
    DateTime? from,
    DateTime? to,
    String? categoryId,
  }) async {
    final where = <String>['e.deleted = 0'];
    final args = <Object?>[];
    if (from != null) {
      where.add('e.spent_at >= ?');
      args.add(from.toUtc().toIso8601String());
    }
    if (to != null) {
      where.add('e.spent_at < ?');
      args.add(to.toUtc().toIso8601String());
    }
    if (categoryId != null) {
      where.add('e.category_id = ?');
      args.add(categoryId);
    }
    final rows = await _db.rawQuery('''
      SELECT e.*, c.name AS category_name, c.color AS category_color
      FROM expenses e
      JOIN categories c ON c.id = e.category_id
      WHERE ${where.join(' AND ')}
      ORDER BY e.spent_at DESC, e.updated_at DESC
    ''', args);
    return Future.wait(rows.map(_fromRow));
  }

  Future<Expense?> getById(String id) async {
    final rows = await _db.rawQuery('''
      SELECT e.*, c.name AS category_name, c.color AS category_color
      FROM expenses e JOIN categories c ON c.id = e.category_id
      WHERE e.id = ? AND e.deleted = 0
    ''', [id]);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  // ---- Update ----
  Future<void> update(Expense e) async {
    final row = await _toRow(e);
    row.remove('id');
    await _db.update('expenses', row, where: 'id = ?', whereArgs: [e.id]);
  }

  // ---- Delete (lógico, para poder sincronizar el borrado) ----
  Future<void> delete(String id) async {
    final current = await getById(id);
    await _db.update(
      'expenses',
      {
        'deleted': 1,
        'synced': 0,
        'note_enc': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    // El ticket cifrado no tiene sentido sin su gasto.
    final path = current?.receiptPath;
    if (path != null) {
      final f = File(path);
      if (await f.exists()) await f.delete();
    }
  }

  // ---- Agregados ----
  Future<double> totalSpent(DateTime from, DateTime to, {String? categoryId}) async {
    final args = <Object?>[from.toUtc().toIso8601String(), to.toUtc().toIso8601String()];
    var sql = 'SELECT COALESCE(SUM(amount), 0) AS t FROM expenses '
        'WHERE deleted = 0 AND spent_at >= ? AND spent_at < ?';
    if (categoryId != null) {
      sql += ' AND category_id = ?';
      args.add(categoryId);
    }
    final rows = await _db.rawQuery(sql, args);
    return (rows.first['t'] as num).toDouble();
  }

  Future<List<CategoryTotal>> totalsByCategory(DateTime from, DateTime to) async {
    final rows = await _db.rawQuery('''
      SELECT c.name AS name, c.color AS color, SUM(e.amount) AS total
      FROM expenses e JOIN categories c ON c.id = e.category_id
      WHERE e.deleted = 0 AND e.spent_at >= ? AND e.spent_at < ?
      GROUP BY c.id
      ORDER BY total DESC
    ''', [from.toUtc().toIso8601String(), to.toUtc().toIso8601String()]);
    return rows
        .map((r) => CategoryTotal(
            r['name'] as String, r['color'] as int, (r['total'] as num).toDouble()))
        .toList();
  }

  // ---- Cifrado de campos ----
  Future<Map<String, Object?>> _toRow(Expense e) async {
    final note = e.note;
    final noteEnc = (note == null || note.isEmpty)
        ? null
        : await _crypto.encryptString(note);
    return e.toRow(noteEnc: noteEnc);
  }

  Future<Expense> _fromRow(Map<String, Object?> row) async {
    final enc = row['note_enc'] as String?;
    final note = enc == null ? null : await _crypto.decryptString(enc);
    return Expense.fromRow(row, note: note);
  }
}
