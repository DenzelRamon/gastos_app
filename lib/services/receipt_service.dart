import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/crypto_service.dart';

/// Captura la foto de un ticket con la cámara y la guarda CIFRADA (AES-GCM)
/// en el directorio privado de la app. La imagen en claro nunca se conserva.
class ReceiptService {
  ReceiptService(this._crypto, {ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final CryptoService _crypto;
  final ImagePicker _picker;

  /// Abre la cámara. Devuelve la ruta del archivo cifrado o null si el usuario
  /// cancela o niega el permiso.
  Future<String?> captureReceipt() async {
    final XFile? shot = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (shot == null) return null;
    return _storeEncrypted(shot);
  }

  Future<String?> pickFromGallery() async {
    final XFile? shot = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (shot == null) return null;
    return _storeEncrypted(shot);
  }

  Future<String> _storeEncrypted(XFile shot) async {
    final plain = await shot.readAsBytes();
    final cipher = await _crypto.encryptBytes(plain);

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'receipts'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File(p.join(dir.path, '${const Uuid().v4()}.enc'));
    await file.writeAsBytes(cipher, flush: true);

    // Elimina la copia temporal en claro que dejó la cámara.
    try {
      await File(shot.path).delete();
    } catch (_) {}
    return file.path;
  }

  /// Descifra a memoria para mostrarla. Devuelve null si falta o fue alterada.
  Future<Uint8List?> load(String path) async {
    final f = File(path);
    if (!await f.exists()) return null;
    return _crypto.decryptBytes(await f.readAsBytes());
  }

  Future<void> remove(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}
