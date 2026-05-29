// ─────────────────────────────────────────────────────────────────────
// LocationProvider — LocationService Riverpod singletoni
// ─────────────────────────────────────────────────────────────────────
//
// PairingNotifier shu provider orqali start()/stop() qiladi.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/features/location/data/services/location_service.dart';

final locationServiceProvider =
    Provider<LocationService>((ref) => LocationService());
