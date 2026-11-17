// Xotiradagi soxta shifrlangan saqlash (TokenStorage testlari uchun).

import 'package:farzandim/core/auth/token_storage.dart';

/// Keystore xatosini ([failReads]) va flutter_secure_storage 9.x "doim null"
/// holatini ([nullReads]) beradi.
class MemoryBackend implements TokenStorageBackend {
  final Map<String, String> store = {};
  bool failReads = false;
  bool nullReads = false;
  bool failWrites = false;
  bool failDeletes = false;
  int reads = 0;

  /// Berilsa, o'qish shu Future tugaguncha kutadi (sekin Keystore).
  Future<void>? readGate;

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw Exception('KeyStore yozish xatosi');
    store[key] = value;
  }

  @override
  Future<String?> read(String key) async {
    reads++;
    // Qiymat o'qish BOSHIDA olinadi — sekin o'qish eski qiymatni qaytaradi.
    final value = store[key];
    final gate = readGate;
    if (gate != null) await gate;
    if (failReads) throw Exception('KeyStore xatosi');
    if (nullReads) return null;
    return value;
  }

  @override
  Future<void> delete(String key) async {
    if (failDeletes) throw Exception('KeyStore o`chirish xatosi');
    store.remove(key);
  }
}
