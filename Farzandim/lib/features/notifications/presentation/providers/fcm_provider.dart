import 'dart:async';

import 'package:farzandim/core/routing/app_router.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:farzandim/features/notifications/data/repositories/backend_fcm_repository.dart';
import 'package:farzandim/features/notifications/data/services/fcm_service.dart';
import 'package:farzandim/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      // Chat xabari (ovozli `voice` / video `video` / matn) bosilsa —
      // to'g'ridan-to'g'ri o'sha bola bilan chatga kiradi.
      final chatType = notif.data?['type'];
      if (chatType == 'voice' || chatType == 'video') {
        unawaited(_openChatForSender(ref, router, notif));
        return;
      }
      handleFcmTap(notif, router);
    };

  await service.init();
});

/// Chat push tap → o'sha bola bilan chatga kiradi. senderId = bola userId
/// (ota-ona faqat bolalardan xabar oladi) → `linkedDeviceUid` bo'yicha bolani
/// topamiz.
///
/// MUHIM (BUG-5): COLD START (ilova yopiq turib tray'dan bosilganda) bolalar
/// ro'yxati (`childrenListProvider`) hali BO'SH bo'ladi — avval sync o'qib
/// hech nima topmasdan `/notifications`ga tushib qolardi. Endi ro'yxat
/// yuklanishini KUTAMIZ (childrenProvider.future), keyin chatga o'tamiz.
Future<void> _openChatForSender(
  Ref ref,
  GoRouter router,
  AppNotification notif,
) async {
  final senderId = notif.data?['senderId'] as String?;
  if (senderId == null) {
    handleFcmTap(notif, router);
    return;
  }
  var children = ref.read(childrenListProvider);
  if (children.isEmpty) {
    try {
      children = await ref
          .read(childrenProvider.future)
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // Timeout/xato — pastdagi fallback (Bildirishnomalar).
    }
  }
  for (final c in children) {
    if (c.linkedDeviceUid == senderId) {
      router.go(AppRoutes.dashboard);
      unawaited(router.push(AppRoutes.qaVoicePath(c.id)));
      return;
    }
  }
  handleFcmTap(notif, router);
}
