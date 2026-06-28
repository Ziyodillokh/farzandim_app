import 'dart:math' as math;

import 'package:farzandim/features/geo_zones/data/models/geo_zone.dart';
import 'package:farzandim/features/geo_zones/presentation/providers/geo_zones_provider.dart';
import 'package:farzandim/features/location/presentation/providers/child_location_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bola hozir qayerdaligi (dashboard location kartasi uchun).
///
/// `zoneName` — bola geo-zona ICHIDA bo'lsa o'sha zona nomi (g'olib, masalan
/// "Uy"/"Maktab"). `street` — ko'cha nomi (reverse geocode) yoki topilmasa
/// koordinata; joylashuv umuman yo'q bo'lsa `null`.
typedef ChildPlace = ({String? zoneName, String? street});

/// Bolaning joriy joyini hisoblaydi: geo-zona nomi → ko'cha → koordinata →
/// "Ko'chada". Reaktiv — joylashuv/zona/manzil o'zgarsa avtomatik yangilanadi.
final childPlaceProvider = Provider.family<ChildPlace, String>((ref, childId) {
  final loc = ref.watch(childLocationProvider(childId)).valueOrNull;
  if (loc == null) {
    // Bola hali GPS yubormagan — UI "Ko'chada" default'ini ko'rsatadi.
    return (zoneName: null, street: null);
  }

  // 1) Geo-zona ichidami? Radius ichidagi eng yaqin markazli zona g'olib.
  final zones =
      ref.watch(geoZonesProvider(childId)).valueOrNull ?? const <GeoZone>[];
  GeoZone? hit;
  var best = double.infinity;
  for (final z in zones) {
    final d = _distanceMeters(
      loc.latitude,
      loc.longitude,
      z.latitude,
      z.longitude,
    );
    if (d <= z.radiusMeters && d < best) {
      best = d;
      hit = z;
    }
  }

  // 2) Ko'cha nomi (reverse geocode) yoki topilmasa koordinata.
  final addr = ref.watch(childAddressProvider(childId)).valueOrNull;
  final lat = loc.latitude.toStringAsFixed(5);
  final lng = loc.longitude.toStringAsFixed(5);
  final street = (addr != null && addr.isNotEmpty) ? addr : '$lat, $lng';

  return (zoneName: hit?.name, street: street);
});

/// Ikki koordinata orasidagi masofa (metr) — Haversine formulasi.
double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const earthM = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return earthM * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}
