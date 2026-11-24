import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Acceso a SQLite. Cada usuario tiene su propio archivo `gastos_<uid>.db`,
/// de modo que dos cuentas en el mismo teléfono nunca comparten datos.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const int _version = 1;

  /// Categorías sembradas en cada base nueva. Los ids son fijos para que
  /// la sincronización entre dispositivos no genere duplicados.
  static const List<(String, String, int)> defaultCategories = [
    ('default-food', 'Comida', 0xFFE57373),
    ('default-transport', 'Transporte', 0xFF64B5F6),
    ('default-home', 'Hogar', 0xFF81C784),
    ('default-leisure', 'Ocio', 0xFFBA68C8),
    ('default-health', 'Salud', 0xFF4DB6AC),
    ('default-other', 'Otros', 0xFFFFB74D),
  ];

  Database? _db;
  String? _userId;

  Database get db {
    final d = _db;
    if (d == null) throw StateError('La base de datos no está abierta');
    return d;
  }

  Future<void> open(String userId) async {
    if (_db != null && _userId == userId) return;
    await close();
    final dir = await getDatabasesPath();
    final safeId = userId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    _db = await openDatabase(
      p.join(dir, 'gastos_$safeId.db'),
      version: _version,
      onConfigure: (d) async => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
    );
    _userId = userId;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
    _userId = null;
  }

  Future<void> _onCreate(Database d, int version) async {
    final batch = d.batch();
    batch.execute('''
      CREATE TABLE categories (
        id         TEXT PRIMARY KEY,
        name       TEXT    NOT NULL,
        color      INTEGER NOT NULL,
        updated_at TEXT    NOT NULL,
        synced     INTEGER NOT NULL DEFAULT 0,
        deleted    INTEGER NOT NULL DEFAULT 0
      )''');
    batch.execute('''
      CREATE TABLE budgets (
        id           TEXT PRIMARY KEY,
        category_id  TEXT REFERENCES categories(id) ON DELETE RESTRICT,
        limit_amount REAL NOT NULL CHECK (limit_amount > 0),
        period       TEXT NOT NULL CHECK (period IN ('weekly','monthly')),
        updated_at   TEXT NOT NULL,
        synced       INTEGER NOT NULL DEFAULT 0,
        deleted      INTEGER NOT NULL DEFAULT 0
      )''');
    batch.execute('''
      CREATE TABLE expenses (
        id           TEXT PRIMARY KEY,
        category_id  TEXT NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
        amount       REAL NOT NULL CHECK (amount > 0),
        description  TEXT NOT NULL,
        note_enc     TEXT,
        receipt_path TEXT,
        spent_at     TEXT NOT NULL,
        updated_at   TEXT NOT NULL,
        synced       INTEGER NOT NULL DEFAULT 0,
        deleted      INTEGER NOT NULL DEFAULT 0
      )''');
    batch.execute('CREATE INDEX idx_expenses_spent_at ON expenses(spent_at)');
    batch.execute('CREATE INDEX idx_expenses_category ON expenses(category_id)');
    batch.execute('CREATE INDEX idx_budgets_category ON budgets(category_id)');

    final now = DateTime.now().toUtc().toIso8601String();
    for (final (id, name, color) in defaultCategories) {
      batch.insert('categories', {
        'id': id,
        'name': name,
        'color': color,
        'updated_at': now,
        'synced': 0,
        'deleted': 0,
      });
    }
    await batch.commit(noResult: true);
  }

  // ---- Utilidades genéricas usadas por la sincronización ----

  Future<List<Map<String, Object?>>> unsyncedRows(String table) =>
      db.query(table, where: 'synced = 0');

  Future<void> markSynced(String table, List<String> ids) async {
    if (ids.isEmpty) return;
    final batch = db.batch();
    for (final id in ids) {
      batch.update(table, {'synced': 1}, where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  Future<Map<String, Object?>?> findRow(String table, String id) async {
    final rows = await db.query(table, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> upsertRow(String table, Map<String, Object?> row) =>
      db.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
}
