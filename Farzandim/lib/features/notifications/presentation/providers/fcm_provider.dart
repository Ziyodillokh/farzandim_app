import 'package:farzandim/core/routing/app_router.dart';
import 'package:farzandim/features/notifications/data/repositories/backend_fcm_repository.dart';
import 'package:farzandim/features/notifications/data/services/fcm_service.dart';
import 'package:farzandim/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `FcmService` singleton — `ProviderScope` davomida bir instance.
///
/// Sprint 4.4.8: `BackendFcmRepository` uzatiladi — Backend voice/video
/// push uchun token register qiladi (`POST /api/fcm/tokens`).
final fcmServiceProvider = Provider<FcmService>((ref) {
  final service = FcmService(
    backendRepo: ref.watch(backendFcmRepositoryProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// FCM tizimini ishga tushirish — callback'larni ulash + service.init().
///
/// `app.dart` `ConsumerWidget` build'da `ref.watch(fcmInitializerProvider)`
/// bir marta chaqiriladi (FutureProvider lazy + cached).
///
/// **Foreground**: kelgan xabar `notificationsProvider`'ga qo'shiladi
/// → bell badge yangilanadi.
/// **Tap (background/cold)**: `handleFcmTap` orqali tegishli ekranga
/// navigatsiya.
final fcmInitializerProvider = FutureProvider<void>((ref) async {
  final service = ref.read(fcmServiceProvider)
    ..onForegroundMessage = (notif) {
      ref.read(notificationsProvider.notifier).addFromFcm(notif);
    }
    ..onMessageTap = (notif) {
      final router = ref.read(routerProvider);
      handleFcmTap(notif, router);
    };

  await service.init();
});
