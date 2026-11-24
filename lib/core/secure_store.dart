import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Envoltura sobre Keychain (iOS) / EncryptedSharedPreferences (Android).
/// Aquí viven las llaves de cifrado, la sesión de Supabase y banderas sensibles.
class SecureStore {
  SecureStore._();
  static final SecureStore instance = SecureStore._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  Future<String?> read(String key) => _storage.read(key: key);
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  Future<void> delete(String key) => _storage.delete(key: key);
  Future<bool> contains(String key) => _storage.containsKey(key: key);
}

/// Almacén de sesión para supabase_flutter.
///
/// Por defecto el SDK guarda access/refresh token en SharedPreferences (texto
/// plano). Con esta clase los tokens se guardan cifrados en el almacén seguro
/// del sistema operativo.
class SecureLocalStorage extends LocalStorage {
  SecureLocalStorage()
      : super(
          initialize: () async {},
          hasAccessToken: () =>
              SecureStore.instance.contains(supabasePersistSessionKey),
          accessToken: () =>
              SecureStore.instance.read(supabasePersistSessionKey),
          removePersistedSession: () =>
              SecureStore.instance.delete(supabasePersistSessionKey),
          persistSession: (String value) =>
              SecureStore.instance.write(supabasePersistSessionKey, value),
        );
}
