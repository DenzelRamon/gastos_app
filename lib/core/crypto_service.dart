import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;

import 'secure_store.dart';

/// Cifrado AES-256-GCM (autenticado) para datos sensibles locales.
///
/// - La llave de 256 bits se genera con un generador seguro la primera vez y
///   se guarda en Keychain/Keystore (nunca junto a los datos cifrados).
/// - Cada cifrado usa un IV aleatorio de 96 bits, así el mismo texto produce
///   salidas distintas.
/// - GCM añade una etiqueta de autenticación: si alguien altera el archivo,
///   el descifrado falla en lugar de devolver basura.
class CryptoService {
  CryptoService(this._store, this._userId);

  final SecureStore _store;
  final String _userId;
  enc.Key? _key;

  static const int _ivLength = 12;

  Future<enc.Key> _loadKey() async {
    final cached = _key;
    if (cached != null) return cached;
    final name = 'aes_key_$_userId';
    var b64 = await _store.read(name);
    if (b64 == null) {
      final fresh = enc.Key.fromSecureRandom(32);
      b64 = fresh.base64;
      await _store.write(name, b64);
    }
    return _key = enc.Key.fromBase64(b64);
  }

  enc.Encrypter _encrypter(enc.Key key) =>
      enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

  /// Devuelve `ivBase64:cipherBase64`.
  Future<String> encryptString(String plain) async {
    final key = await _loadKey();
    final iv = enc.IV.fromSecureRandom(_ivLength);
    final out = _encrypter(key).encrypt(plain, iv: iv);
    return '${iv.base64}:${out.base64}';
  }

  /// Devuelve null si el dato fue alterado o la llave no corresponde.
  Future<String?> decryptString(String packed) async {
    try {
      final parts = packed.split(':');
      if (parts.length != 2) return null;
      final key = await _loadKey();
      final iv = enc.IV.fromBase64(parts[0]);
      return _encrypter(key).decrypt(enc.Encrypted.fromBase64(parts[1]), iv: iv);
    } catch (_) {
      return null;
    }
  }

  /// Devuelve `IV (12 bytes) || cifrado`.
  Future<Uint8List> encryptBytes(Uint8List plain) async {
    final key = await _loadKey();
    final iv = enc.IV.fromSecureRandom(_ivLength);
    final out = _encrypter(key).encryptBytes(plain, iv: iv);
    return Uint8List.fromList([...iv.bytes, ...out.bytes]);
  }

  Future<Uint8List?> decryptBytes(Uint8List packed) async {
    try {
      if (packed.length <= _ivLength) return null;
      final key = await _loadKey();
      final iv = enc.IV(Uint8List.sublistView(packed, 0, _ivLength));
      final body = Uint8List.sublistView(packed, _ivLength);
      final plain = _encrypter(key).decryptBytes(enc.Encrypted(body), iv: iv);
      return Uint8List.fromList(plain);
    } catch (_) {
      return null;
    }
  }

  /// Borra la llave: los datos cifrados quedan irrecuperables (cierre de cuenta).
  Future<void> destroyKey() async {
    await _store.delete('aes_key_$_userId');
    _key = null;
  }
}
