import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/sync_service.dart';
import 'auth_provider.dart' show ViewState;

/// Estado de la sincronización: cargando, éxito o error con mensaje seguro.
class SyncProvider extends ChangeNotifier {
  SyncProvider(this._service) {
    _service.lastSyncAt().then((d) {
      lastSync = d;
      notifyListeners();
    });
  }

  final SyncService _service;

  ViewState state = ViewState.idle;
  String? errorMessage;
  DateTime? lastSync;
  SyncResult? lastResult;

  /// Se llama tras una sincronización exitosa para refrescar la UI local.
  Future<void> Function()? onSynced;

  bool get isSyncing => state == ViewState.loading;

  Future<void> sync() async {
    if (isSyncing) return;
    state = ViewState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      lastResult = await _service.sync().timeout(const Duration(seconds: 30));
      lastSync = DateTime.now();
      state = ViewState.success;
      await onSynced?.call();
    } on TimeoutException {
      _fail('La sincronización tardó demasiado. Intenta de nuevo.');
    } on SocketException {
      _fail('Sin conexión a internet.');
    } on AuthException {
      _fail('Tu sesión expiró. Inicia sesión de nuevo.');
    } on PostgrestException {
      _fail('El servidor rechazó la sincronización.');
    } catch (e) {
      if (kDebugMode) debugPrint('Sync error: $e');
      _fail('No se pudo sincronizar.');
    }
    notifyListeners();
  }

  void _fail(String message) {
    state = ViewState.error;
    errorMessage = message;
  }
}
