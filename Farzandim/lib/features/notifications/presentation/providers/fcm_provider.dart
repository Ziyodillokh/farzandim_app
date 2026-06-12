import 'package:farzandim/core/routing/app_router.dart';
import 'package:farzandim/features/notifications/data/repositories/backend_fcm_repository.dart';
import 'package:farzandim/features/notifications/data/services/fcm_service.dart';
import 'package:farzandim/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `FcmService` singleton — `ProviderScope` davomida bir instance.
/// Token backend'ga `BackendFcmRepository` orqali registratsiya qilinadi.
final fcmServiceProvider = Provider<FcmService>((ref) {
  final service = FcmService(
    backendRepo: ref.watch(backendFcmRepositoryProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// FCM tizimini ishga tushirish — callback'larni ulab `service.init()`
/// chaqiradi. `app.dart` build'ida bir marta watch qilinadi
/// (FutureProvider lazy + cached). Foreground xabar ro'yxatga qo'shiladi,
/// tap esa `handleFcmTap` orqali tegishli ekranga olib boradi.
final fcmInitializerProvider = FutureProvider<void>((ref) async {
  final service = ref.read(fcmServiceProvider)
    ..onForegroundMessage = (notif) {
      ref.read(notificationsProvider.notifier).addFromFcm(notif);
    }
    ..onMessageTap = (notif) {
      // Tray'dan bosilgan push ham ro'yxatga tushsin — aks holda fonda
      // kelgan xabar Bildirishnomalar sahifasida ko'rinmaydi. messageId
      // bo'yicha dedup bor, bg handler pending'i bilan takrorlanmaydi.
      ref.read(notificationsProvider.notifier).addFromFcm(notif);
      final router = ref.read(routerProvider);
      handleFcmTap(notif, router);
    };

  await service.init();
});
