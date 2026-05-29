// ─────────────────────────────────────────────────────────────────────
// DeviceInfoProvider — DeviceInfoService Riverpod singletoni
// ─────────────────────────────────────────────────────────────────────
//
// PairingNotifier (`pairing_provider.dart`) shu provider orqali
// service'ni `start()`/`markOffline()` qiladi.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/features/device_info/data/services/device_info_service.dart';

final deviceInfoServiceProvider =
    Provider<DeviceInfoService>((ref) => DeviceInfoService());
