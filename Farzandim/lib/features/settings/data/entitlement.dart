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
    this.isTrial = false,
    this.trialEndsAt,
  });

  factory Entitlement.fromJson(Map<String, dynamic> j) => Entitlement(
    tier: (j['tier'] as String?) ?? 'free',
    features: [
      for (final f in (j['features'] as List? ?? const [])) f as String,
    ],
    maxChildren: (j['maxChildren'] as num?)?.toInt() ?? 1,
    maxParents: (j['maxParents'] as num?)?.toInt() ?? 1,
    isTrial: (j['isTrial'] as bool?) ?? false,
    trialEndsAt: j['trialEndsAt'] is String
        ? DateTime.tryParse(j['trialEndsAt'] as String)
        : null,
  );

  /// 'free' | 'standard' | 'premium' | 'vip'.
  final String tier;

  /// Yoqilgan funksiya kalitlari (plan.features).
  final List<String> features;
  final int maxChildren;
  final int maxParents;

  /// Joriy tarif 1-haftalik Standart demo (trial) orqali kelganmi.
  final bool isTrial;

  /// Trial tugash vaqti (banner "X kun qoldi" uchun). Trial bo'lmasa null.
  final DateTime? trialEndsAt;

  bool has(String feature) => features.contains(feature);
  bool get isFree => tier == 'free';

  /// Trial tugashiga qolgan kun (yuqoriga yaxlitlangan). Trial emas/tugagan → 0.
  int get trialDaysLeft {
    final end = trialEndsAt;
    if (end == null) return 0;
    final diff = end.difference(DateTime.now());
    if (diff.isNegative) return 0;
    return (diff.inMinutes / (60 * 24)).ceil().clamp(1, 999);
  }

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
  // XATO YUTILMAYDI (avval catch→free edi): tarmoq blip'ida u pullik
  // foydalanuvchini butun sessiya davomida `free`ga "qamab" qo'yardi va
  // lokatsiya/boshqa gate'lar qulflanib qolardi. Endi AsyncError qaytadi —
  // fail-OPEN qiladi; backend guard haqiqiy himoya; resume'da qayta uriniladi.
  final res = await dio.get<Map<String, dynamic>>('/me/entitlement');
  return Entitlement.fromJson(res.data ?? const <String, dynamic>{});
});
