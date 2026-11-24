import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/secure_store.dart';
import '../data/database_helper.dart';

typedef DbRow = Map<String, Object?>;

class SyncResult {
  const SyncResult({required this.pushed, required this.pulled});
  final int pushed;
  final int pulled;
}

class _SyncTable {
  const _SyncTable(this.name, this.toRemote, this.toLocal);
  final String name;
  final Map<String, dynamic> Function(DbRow row, String userId) toRemote;
  final DbRow Function(Map<String, dynamic> remote) toLocal;
}

/// Sincronización bidireccional con Supabase (API REST de PostgREST).
///
/// - Push: sube las filas con `synced = 0` (incluye borrados lógicos).
/// - Pull: descarga filas con `updated_at` posterior a la última sincronización.
/// - Conflictos: gana la escritura más reciente (last-write-wins por `updated_at`).
/// - Privacidad: notas y fotos de tickets NO se envían.
/// - Orden categories -> budgets -> expenses respeta las llaves foráneas.
class SyncService {
  SyncService({SupabaseClient? client, SecureStore? store})
      : _client = client ?? Supabase.instance.client,
        _store = store ?? SecureStore.instance;

  final SupabaseClient _client;
  final SecureStore _store;
  final DatabaseHelper _db = DatabaseHelper.instance;

  static const int _pageSize = 500;
  static const Duration _overlap = Duration(minutes: 2);

  static final List<_SyncTable> _tables = [
    _SyncTable(
      'categories',
      (r, uid) => {
        'id': r['id'],
        'user_id': uid,
        'name': r['name'],
        'color': r['color'],
        'deleted': r['deleted'] == 1,
        'updated_at': r['updated_at'],
      },
      (m) => {
        'id': m['id'],
        'name': m['name'],
        'color': m['color'],
        'deleted': (m['deleted'] as bool? ?? false) ? 1 : 0,
        'updated_at': _iso(m['updated_at']),
        'synced': 1,
      },
    ),
    _SyncTable(
      'budgets',
      (r, uid) => {
        'id': r['id'],
        'user_id': uid,
        'category_id': r['category_id'],
        'limit_amount': r['limit_amount'],
        'period': r['period'],
        'deleted': r['deleted'] == 1,
        'updated_at': r['updated_at'],
      },
      (m) => {
        'id': m['id'],
        'category_id': m['category_id'],
        'limit_amount': (m['limit_amount'] as num).toDouble(),
        'period': m['period'],
        'deleted': (m['deleted'] as bool? ?? false) ? 1 : 0,
        'updated_at': _iso(m['updated_at']),
        'synced': 1,
      },
    ),
    _SyncTable(
      'expenses',
      (r, uid) => {
        'id': r['id'],
        'user_id': uid,
        'category_id': r['category_id'],
        'amount': r['amount'],
        'description': r['description'],
        'spent_at': r['spent_at'],
        'deleted': r['deleted'] == 1,
        'updated_at': r['updated_at'],
      },
      (m) => {
        'id': m['id'],
        'category_id': m['category_id'],
        'amount': (m['amount'] as num).toDouble(),
        'description': m['description'],
        'spent_at': _iso(m['spent_at']),
        'deleted': (m['deleted'] as bool? ?? false) ? 1 : 0,
        'updated_at': _iso(m['updated_at']),
        'synced': 1,
      },
    ),
  ];

  /// Normaliza timestamptz de Postgres al mismo formato ISO-UTC que usa SQLite.
  static String _iso(Object? v) => DateTime.parse(v as String).toUtc().toIso8601String();

  Future<SyncResult> sync() async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Sin sesión activa');
    final uid = user.id;

    final startedAt = DateTime.now().toUtc();
    final lastKey = 'last_sync_$uid';
    final lastRaw = await _store.read(lastKey);
    final since = lastRaw == null
        ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
        : DateTime.parse(lastRaw).subtract(_overlap);

    var pushed = 0;
    for (final t in _tables) {
      pushed += await _push(t, uid);
    }
    var pulled = 0;
    for (final t in _tables) {
      pulled += await _pull(t, since);
    }

    await _store.write(lastKey, startedAt.toIso8601String());
    return SyncResult(pushed: pushed, pulled: pulled);
  }

  Future<DateTime?> lastSyncAt() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final raw = await _store.read('last_sync_$uid');
    return raw == null ? null : DateTime.parse(raw).toLocal();
  }

  Future<int> _push(_SyncTable t, String uid) async {
    final rows = await _db.unsyncedRows(t.name);
    if (rows.isEmpty) return 0;
    final payload = rows.map((r) => t.toRemote(r, uid)).toList();
    await _client.from(t.name).upsert(payload, onConflict: 'user_id,id');
    await _db.markSynced(t.name, rows);
    return rows.length;
  }

  Future<int> _pull(_SyncTable t, DateTime since) async {
    var count = 0;
    var offset = 0;
    while (true) {
      final List<Map<String, dynamic>> page = await _client
          .from(t.name)
          .select()
          .gt('updated_at', since.toIso8601String())
          .order('updated_at')
          .order('id')
          .range(offset, offset + _pageSize - 1);

      for (final remote in page) {
        if (await _applyRemote(t, remote)) count++;
      }
      if (page.length < _pageSize) break;
      offset += _pageSize;
    }
    return count;
  }

  /// Devuelve true si la fila remota se aplicó localmente.
  Future<bool> _applyRemote(_SyncTable t, Map<String, dynamic> remote) async {
    final incoming = t.toLocal(remote);
    final id = incoming['id'] as String;
    final existing = await _db.findRow(t.name, id);

    if (existing != null) {
      final localTime = DateTime.parse(existing['updated_at'] as String);
      final remoteTime = DateTime.parse(incoming['updated_at'] as String);
      // Last-write-wins: solo se aplica lo remoto si es estrictamente más nuevo.
      // Así una edición local pendiente nunca se pisa con datos viejos.
      if (!remoteTime.isAfter(localTime)) return false;
    }

    // Mezcla para conservar columnas que no viajan a la nube (nota, ticket).
    final merged = <String, Object?>{...?existing, ...incoming};

    if (t.name == 'expenses' && incoming['deleted'] == 1) {
      merged['note_enc'] = null;
      final path = existing?['receipt_path'] as String?;
      if (path != null) {
        try {
          final f = File(path);
          if (await f.exists()) await f.delete();
        } catch (_) {}
        merged['receipt_path'] = null;
      }
    }
    await _db.upsertRow(t.name, merged);
    return true;
  }
}
