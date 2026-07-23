// Ota-ona tarifi (entitlement) — backend `GET /me/entitlement`.
// Ilova UI'ni shu bilan gate qiladi (qulflangan funksiya → oyna; bola-limit).
import 'package:farzandim/core/network/dio_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Foydalanuvchi tarifi + limitlar.
class Entitlement {
  const Entitlement({
    required this.tier,
    required this.features,
    required this.maxChildren,
    required this.maxParents,
  });

  factory Entitlement.fromJson(Map<String, dynamic> j) => Entitlement(
    tier: (j['tier'] as String?) ?? 'free',
    features: [
      for (final f in (j['features'] as List? ?? const [])) f as String,
    ],
    maxChildren: (j['maxChildren'] as num?)?.toInt() ?? 1,
    maxParents: (j['maxParents'] as num?)?.toInt() ?? 1,
  );

  /// 'free' | 'standard' | 'premium' | 'vip'.
  final String tier;

  /// Yoqilgan funksiya kalitlari (plan.features).
  final List<String> features;
  final int maxChildren;
  final int maxParents;

  bool has(String feature) => features.contains(feature);
  bool get isFree => tier == 'free';

  static const free = Entitlement(
    tier: 'free',
    features: <String>[],
    maxChildren: 1,
    maxParents: 1,
  );
}

/// Joriy foydalanuvchi tarifi (aktiv obunaga qarab). To'lov/resume'da
/// `ref.invalidate(entitlementProvider)` bilan yangilanadi.
final entitlementProvider = FutureProvider<Entitlement>((ref) async {
  final dio = ref.watch(dioClientProvider);
  try {
    final res = await dio.get<Map<String, dynamic>>('/me/entitlement');
    return Entitlement.fromJson(res.data ?? const <String, dynamic>{});
  } catch (_) {
    // Tarmoq/auth xatosida — free (himoya buzilmaydi, backend guard baribir bor).
    return Entitlement.free;
  }
});
