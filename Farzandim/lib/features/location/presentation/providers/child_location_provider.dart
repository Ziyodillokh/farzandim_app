// Sprint 4.4.2: Firestore stream → Backend REST + WS real-time
//
// Eski Firebase auth + Firestore listener olib tashlandi.
// Yangi: BackendLocationRepository.watchLocation (initial GET + WS).
//
// `childLocationProvider` family signature o'zgarmaydi — UI tomonida
// hech narsa o'zgartirish kerak emas.

import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/location/data/models/child_location.dart';
import 'package:farzandim/features/location/data/repositories/backend_location_repository.dart';
import 'package:farzandim/features/location/data/services/geocoding_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bola joriy joylashuvi — Backend `/api/children/:childId/location` +
/// WS `location:updated` real-time push.
///
/// `backendAuthProvider`'ga bog'langan: foydalanuvchi `AuthAuthenticated`
/// bo'lmasa stream bo'sh qaytariladi.
final childLocationProvider =
    StreamProvider.family<ChildLocation?, String>((ref, childId) {
  final auth = ref.watch(backendAuthProvider);
  if (auth is! AuthAuthenticated) {
    return Stream.value(null);
  }
  final repo = ref.watch(backendLocationRepositoryProvider);
  return repo.watchLocation(childId);
});

/// Bola joriy joylashuvi manzili (reverse geocoding) — joylashuv
/// o'zgarganda avtomatik qayta hisoblanadi. Kalit yo'q / xato bo'lsa
/// `null` (UI koordinata yoki "Noma'lum joylashuv" ko'rsatadi).
final childAddressProvider =
    FutureProvider.family<String?, String>((ref, childId) async {
  final loc = ref.watch(childLocationProvider(childId)).valueOrNull;
  if (loc == null) return null;
  return ref
      .watch(geocodingServiceProvider)
      .reverse(loc.latitude, loc.longitude);
});
