// ─────────────────────────────────────────────────────────────────────
// fcm_provider — Child App FCM service Riverpod (Sprint 4.4.8)
// ─────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:farzandim_child/core/routing/app_router.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/restrictions_sync_provider.dart';
import 'package:farzandim_child/features/notifications/data/repositories/backend_fcm_repository.dart';
import 'package:farzandim_child/features/notifications/data/services/fcm_service.dart';
import 'package:farzandim_child/shared/widgets/app_snackbar.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// FcmService singleton — Backend FCM repository bilan.
final fcmServiceProvider = Provider<FcmService>((ref) {
  final service = FcmService(
    backendRepo: ref.watch(backendFcmRepositoryProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// `restrictions_sync` (darhol blok / kategoriya / limit o'zgardi) — fon'da
/// ham limitни darhol qayta yuklaydi (#15). Jim (UI ko'rsatmaydi).
void _handleRestrictionsSync(Ref ref, RemoteMessage message) {
  if (message.data['type'] != 'restrictions_sync') return;
  unawaited(ref.read(restrictionsSyncServiceProvider).sync());
}

/// Eslatma (study/health/content) push BOSILGANDA — tegishli ekranga olib
/// boradi (#66/#67/#77). `relatedRoute` backend'dan keladi.
void _handleNudgeTap(Ref ref, RemoteMessage message) {
  const nudgeTypes = {'study_nudge', 'health_nudge', 'content_reminder'};
  if (!nudgeTypes.contains(message.data['type'])) return;
  final route = message.data['relatedRoute'] as String?;
  if (route == null || route.isEmpty) return;
  ref.read(routerProvider).go(route);
}

/// Admin broadcast'idagi `deepLink` push BOSILGANDA — tegishli bo'limga olib
/// boradi. deepLink to'g'ridan route yo'li (`/videos`) YOKI `farzandim://<host>`
/// sxemasi bo'lishi mumkin. Noma'lum bo'lsa jim (hech nima qilmaydi).
void _handleDeepLink(Ref ref, RemoteMessage message) {
  final link = (message.data['deepLink'] as String?)?.trim();
  if (link == null || link.isEmpty) return;
  final route = _deepLinkToRoute(link);
  if (route == null) return;
  ref.read(routerProvider).go(route);
}

/// deepLink'ni child router yo'liga aylantiradi. `/...` — to'g'ridan;
/// `farzandim://videos` kabi sxema ma'lum bo'limga xaritalanadi (aniq band —
/// masalan `farzandim://video/123` — bo'lim feed'iga tushadi). Noma'lum → null.
String? _deepLinkToRoute(String link) {
  if (link.startsWith('/')) return link;
  const prefix = 'farzandim://';
  if (!link.startsWith(prefix)) return null;
  final host = link.substring(prefix.length).split('/').first.toLowerCase();
  switch (host) {
    case 'videos':
    case 'video':
      return '/videos';
    case 'audiobooks':
    case 'audiobook':
    case 'audio':
      return '/audiobooks';
    case 'tests':
    case 'test':
    case 'contests':
    case 'olympiads':
      return '/contests';
    case 'profile':
      return '/profile';
    case 'dashboard':
    case 'home':
      return '/dashboard';
    default:
      return null;
  }
}

/// `unlock_decision` push kelganda — limit qayta sync + bolaga snackbar.
/// APPROVED → success ("X daqiqa ruxsat"); DENIED → info ("rad etildi").
void _handleUnlockDecision(Ref ref, RemoteMessage message) {
  if (message.data['type'] != 'unlock_decision') return;
  // Limit darhol yangilansin (server effektiv limitga grantni qo'shgan).
  unawaited(ref.read(restrictionsSyncServiceProvider).sync());

  final ctx = ref
      .read(routerProvider)
      .routerDelegate
      .navigatorKey
      .currentContext;
  if (ctx == null || !ctx.mounted) return;
  final approved = message.data['approved'] == 'true';
  if (approved) {
    final mins = message.data['grantedMinutes'] ?? '';
    AppSnackBar.success(
      ctx,
      'Ota-onangiz $mins daqiqa qo\'shimcha vaqt berdi!',
    );
  } else {
    AppSnackBar.info(ctx, "So'rovingiz rad etildi.");
  }
}

/// FCM tizimini ishga tushirish — `app.dart` (yoki main) bir marta
/// `ref.watch(fcmInitializerProvider)` chaqiradi.
final fcmInitializerProvider = FutureProvider<void>((ref) async {
  final service = ref.read(fcmServiceProvider);
  // Foreground + tap'da: unlock qarori (limit sync + UI) va restrictions_sync
  // (darhol blok/kategoriya — jim limit sync).
  service.onForegroundMessage = (msg) {
    _handleUnlockDecision(ref, msg);
    _handleRestrictionsSync(ref, msg);
  };
  service.onMessageTap = (msg) {
    _handleUnlockDecision(ref, msg);
    _handleRestrictionsSync(ref, msg);
    _handleNudgeTap(ref, msg);
    _handleDeepLink(ref, msg);
  };
  await service.init();
});
