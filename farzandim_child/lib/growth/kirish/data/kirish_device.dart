// Shu qurilma: o'rnatish identifikatori (sessiyalar ro'yxati uchun) va
// qurilma kaliti — barmoq izi / yuz bilan tez kirish (A09, A02, A10).
// Kalit faqat shu qurilmadagi saqlangan sessiyani ochadi; parol o'rnini
// bosmaydi va serverga hech narsa yubormaydi.

import 'package:farzandim_child/core/platform/platform_capabilities.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_repository.dart';
import 'package:farzandim_child/growth/maktab/data/school_v5_repository.dart';
import 'package:farzandim_child/growth/men/data/men_device.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

const _installIdKey = 'g5_install_id_v1';

/// Shu o'rnatishning doimiy identifikatori (ilova o'chirilsa yangilanadi).
final deviceDescriptorProvider = FutureProvider<DeviceDescriptor>((ref) async {
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  String? id;
  try {
    id = await storage.read(key: _installIdKey);
    if (id == null || id.isEmpty) {
      id = newRequestId();
      await storage.write(key: _installIdKey, value: id);
    }
  } on Object catch (e) {
    debugPrint('[kirish] install id o\'qilmadi: ${e.runtimeType}');
    id ??= newRequestId();
  }
  final model = await ref.watch(thisDeviceNameProvider.future);
  return DeviceDescriptor(
    id: id,
    platform: PlatformCapabilities.isIOS ? 'ios' : 'android',
    model: model,
  );
});

abstract interface class DeviceKey {
  /// Qurilmada barmoq izi / yuz bor va yoqilgan.
  Future<bool> isAvailable();

  /// Tasdiqlash oynasi; `true` — bola tasdiqladi.
  Future<bool> confirm(String reason);

  /// Telefonda ekran qulfi bor (kod, chizma yoki biometrik).
  Future<bool> isDeviceSecure();

  /// Telefonning o'z qulfi bilan tasdiqlash (biometrik yoki ekran kodi).
  Future<bool> confirmDevice(String reason);
}

class LocalAuthDeviceKey implements DeviceKey {
  LocalAuthDeviceKey() : _auth = LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported() &&
          await _auth.canCheckBiometrics &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on Object catch (e) {
      // local_auth 3.x bekor qilish / bloklanish / sozlanmaganlikni
      // `LocalAuthException` bilan bildiradi (PlatformException emas).
      debugPrint('[kirish] biometrik holat: ${e.runtimeType}');
      return false;
    }
  }

  @override
  Future<bool> confirm(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } on Object catch (e) {
      debugPrint('[kirish] biometrik tasdiq: ${e.runtimeType}');
      return false;
    }
  }

  @override
  Future<bool> isDeviceSecure() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported();
    } on Object catch (e) {
      debugPrint('[kirish] telefon qulfi holati: ${e.runtimeType}');
      return false;
    }
  }

  @override
  Future<bool> confirmDevice(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason);
    } on Object catch (e) {
      debugPrint('[kirish] telefon qulfi tasdig\'i: ${e.runtimeType}');
      return false;
    }
  }
}

final deviceKeyProvider = Provider<DeviceKey>((_) => LocalAuthDeviceKey());

final deviceKeyAvailableProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(deviceKeyProvider).isAvailable(),
);
