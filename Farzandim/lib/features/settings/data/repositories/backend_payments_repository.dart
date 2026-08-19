// To'lov / obuna API'si — Click orqali oylik/yillik tarif sotib olish.
//
// Backend kontrakt:
//   GET  /api/payments/plans   -> { plans:[...], availableProviders:[...] }
//   POST /api/payments/checkout {provider, planId} -> { checkoutUrl }
//   GET  /api/payments/me      -> { subscription, payments }
//
// Auth: ConsumerJwtAuthGuard — ota-ona ilovasi tokeni bilan ishlaydi
// (children endpointlari bilan bir xil guard).

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bitta tarif (Plan).
class PlanEntry {
  const PlanEntry({
    required this.id,
    required this.slug,
    required this.name,
    required this.priceUzs,
    required this.period,
    required this.entitlementTier,
    this.description,
    this.badge,
    this.features = const [],
  });

  factory PlanEntry.fromJson(Map<String, dynamic> j) => PlanEntry(
    id: j['id'] as String,
    slug: (j['slug'] as String?) ?? '',
    name: (j['name'] as String?) ?? '',
    description: j['description'] as String?,
    priceUzs: (j['priceUzs'] as num?)?.toInt() ?? 0,
    period: (j['period'] as String?) ?? 'monthly',
    entitlementTier: (j['entitlementTier'] as String?) ?? 'free',
    badge: j['badge'] as String?,
    features: [
      for (final f in (j['features'] as List? ?? const [])) f as String,
    ],
  );

  final String id;
  final String slug;
  final String name;
  final String? description;

  /// Narx so'mda (0 = bepul).
  final int priceUzs;

  /// 'free' | 'monthly' | 'yearly'.
  final String period;

  /// 'free' | 'standard' | 'premium'.
  final String entitlementTier;
  final String? badge;

  /// Admin tanlagan funksiya kalitlari (plan.features) — kartada ko'rsatiladi.
  final List<String> features;

  bool get isFree => priceUzs <= 0;
}

/// `/plans` javobi — tariflar + mavjud to'lov provayderlari.
class PlansResult {
  const PlansResult({required this.plans, required this.availableProviders});

  final List<PlanEntry> plans;
  final List<String> availableProviders;

  bool get clickAvailable => availableProviders.contains('click');
  bool get paymeAvailable => availableProviders.contains('payme');

  /// Ilovada ko'rsatiladigan TASHQI to'lov usullari (Android/web checkout),
  /// barqaror tartibda: Click, keyin Payme. Backend'da kalitlari sozlanmagan
  /// provayder ro'yxatga kirmaydi (`availableProviders` shuni bildiradi).
  /// Bo'sh bo'lsa — hech qanday tashqi to'lov yo'q (checkout 503 qaytaradi).
  List<String> get externalProviders => <String>[
    for (final p in const ['click', 'payme'])
      if (availableProviders.contains(p)) p,
  ];
}

final backendPaymentsRepositoryProvider = Provider<BackendPaymentsRepository>(
  (ref) => BackendPaymentsRepository(dio: ref.watch(dioClientProvider)),
);

class BackendPaymentsRepository {
  BackendPaymentsRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<PlansResult> getPlans() async {
    final res = await _dio.get<Map<String, dynamic>>('/payments/plans');
    final data = res.data ?? const <String, dynamic>{};
    final plans = <PlanEntry>[
      for (final p in (data['plans'] as List? ?? const []))
        PlanEntry.fromJson(p as Map<String, dynamic>),
    ];
    final providers = <String>[
      for (final p in (data['availableProviders'] as List? ?? const []))
        p as String,
    ];
    return PlansResult(plans: plans, availableProviders: providers);
  }

  /// Checkout boshlash — to'lov sahifasi URL'ini qaytaradi.
  /// [provider] — `click` yoki `payme` (backend `availableProviders`dan).
  /// Bo'sh string qaytsa — URL kelmadi (xato).
  Future<String> checkout({
    required String planId,
    String provider = 'click',
    String billingPeriod = 'monthly',
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/payments/checkout',
      data: <String, dynamic>{
        'provider': provider,
        'planId': planId,
        'billingPeriod': billingPeriod,
      },
    );
    return (res.data?['checkoutUrl'] as String?) ?? '';
  }

  /// Apple IAP (StoreKit) xaridini backend'da tekshiradi va muvaffaqiyatli
  /// bo'lsa obunani beradi/uzaytiradi.
  ///
  /// [verificationData] — `serverVerificationData` (StoreKit kvitansiyasi).
  /// [productId] — App Store product id. Xarid/restore paytida ANIQ
  /// ma'lum bo'ladi. Renewal-tekshiruv (ilova resume'da jim so'rov,
  /// `AppleReceiptSyncService`) paytida esa `null` qoldiriladi — backend
  /// kvitansiya ichidan eng so'nggi mos yozuvni o'zi aniqlaydi.
  /// `true` qaytsa entitlement berildi/tasdiqlandi.
  Future<bool> verifyApplePurchase({
    required String verificationData,
    String? productId,
    String? transactionId,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/payments/apple/verify',
      data: <String, dynamic>{
        if (productId != null) 'productId': productId,
        'verificationData': verificationData,
        if (transactionId != null) 'transactionId': transactionId,
      },
    );
    return (res.data?['ok'] as bool?) ?? false;
  }
}

/// Tariflar ro'yxati (paywall ekrani uchun).
final plansProvider = FutureProvider.autoDispose<PlansResult>(
  (ref) => ref.watch(backendPaymentsRepositoryProvider).getPlans(),
);
