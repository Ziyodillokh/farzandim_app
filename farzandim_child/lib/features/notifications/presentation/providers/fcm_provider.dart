// ─────────────────────────────────────────────────────────────────────
// fcm_provider — Child App FCM service Riverpod (Sprint 4.4.8)
// ─────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/routing/app_router.dart';
import 'package:farzandim_child/features/background/data/services/parvoz_messages.dart';
import 'package:farzandim_child/features/location/presentation/widgets/location_enable_modal.dart';
import 'package:farzandim_child/features/notifications/data/repositories/backend_fcm_repository.dart';
import 'package:farzandim_child/features/notifications/data/services/fcm_service.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/background_owner_provider.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/kirish/link_screens.dart';
import 'package:farzandim_child/growth/ovoz/data/voice_repository.dart';
import 'package:farzandim_child/shared/widgets/app_snackbar.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:farzandim_child/growth/common/media_visibility.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// FcmService singleton — Backend FCM repository bilan.
final fcmServiceProvider = Provider<FcmService>((ref) {
  final service = FcmService(
    backendRepo: ref.watch(backendFcmRepositoryProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// `restrictions_sync` (darhol blok / kategoriya / limit o'zgardi) — limitni
/// darhol qayta yuklaydi (#15). Jim (UI ko'rsatmaydi).
void _handleRestrictionsSync(Ref ref, RemoteMessage message) {
  if (message.data['type'] != 'restrictions_sync') return;
  _requestRestrictionsSync(ref);
}

/// Cheklovlarni qayta yuklash — fon ishlarining yagona egasiga: Android'da
/// FGS ishlasa unga (`parvoz:restrictions_sync`, native push yo'li bilan
/// birga 2 s debounce), aks holda UI isolate; iOS — Family Controls sinxroni.
void _requestRestrictionsSync(Ref ref) {
  unawaited(
    ref.read(backgroundOwnerProvider).forward(ParvozMessages.restrictionsSync),
  );
}

/// Eslatma (study/health/content) push BOSILGANDA — tegishli ekranga olib
/// boradi (#66/#67/#77). `relatedRoute` backend'dan keladi.
void _handleNudgeTap(Ref ref, RemoteMessage message) {
  const nudgeTypes = {'study_nudge', 'health_nudge', 'content_reminder'};
  if (!nudgeTypes.contains(message.data['type'])) return;
  final route = message.data['relatedRoute'] as String?;
  // '/' — router'da route yo'q (dead-end). Bo'sh yoki '/' bo'lsa — jim.
  if (route == null || route.isEmpty || route == '/') return;
  if (isHiddenMediaRoute(route)) return;
  ref.read(routerProvider).go(route);
}

/// Admin broadcast'idagi `deepLink` push BOSILGANDA — tegishli bo'limga olib
/// boradi. deepLink to'g'ridan route yo'li (`/videos`) YOKI `farzandim://<host>`
/// sxemasi bo'lishi mumkin. Noma'lum bo'lsa jim (hech nima qilmaydi).
void _handleDeepLink(Ref ref, RemoteMessage message) {
  final link = (message.data['deepLink'] as String?)?.trim();
  if (link == null || link.isEmpty) return;
  final route = _deepLinkToRoute(link);
  if (route == null || isHiddenMediaRoute(route)) return;
  ref.read(routerProvider).go(route);
}

/// deepLink'ni child router yo'liga aylantiradi. `/...` — to'g'ridan;
/// `farzandim://videos` kabi sxema ma'lum bo'limga xaritalanadi (aniq band —
/// masalan `farzandim://video/123` — bo'lim feed'iga tushadi). Noma'lum → null.
String? _deepLinkToRoute(String link) {
  // Bare '/' — router'da route yo'q (dead-end); e'tiborsiz qoldiramiz.
  if (link == '/') return null;
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

/// Chat xabari (ovozli/video/matn — backend `type:'voice'`) push BOSILGANDA —
/// ota-ona bilan chat ekraniga kiradi (bola bitta ota-ona bilan chatlashadi).
/// `CARE_MESSAGE` — psixologdan javob (matnsiz push). Bosilsa o'sha murojaat
/// yozishmasi ochiladi; ilova ochiq bo'lsa ro'yxat/yozishma yangilanadi.
void _handleCareMessage(Ref ref, RemoteMessage message, {required bool tap}) {
  if (message.data['type'] != 'CARE_MESSAGE') return;
  ref
    ..invalidate(voiceRequestsProvider)
    ..invalidate(voiceRequestProvider);
  if (!tap) return;
  final id = (message.data['requestId'] as String?)?.trim();
  final router = ref.read(routerProvider);
  router.go(GrowthV5Routes.school);
  if (id != null && id.isNotEmpty) {
    unawaited(router.push(GrowthV5Routes.voiceRequest(id)));
  }
}

/// Maktab push'lari (matnsiz): ertangi topshiriq, maktab e'loni, mutaxassis
/// yuborgan test va maktab so'rovnomasi — v5 da tegishli ekran ochiladi.
void _handleSchoolTap(Ref ref, RemoteMessage message) {
  final location = switch (message.data['type']) {
    'HOMEWORK_DUE' => GrowthV5Routes.schoolTasks,
    'SCHOOL_ANNOUNCEMENT' => GrowthV5Routes.notices,
    'PSYCH_ASSIGNMENT' => GrowthV5Routes.voice,
    'CARE_SURVEY' => GrowthV5Routes.voiceSurvey,
    _ => null,
  };
  if (location == null) return;
  final router = ref.read(routerProvider)..go(GrowthV5Routes.school);
  unawaited(router.push(location));
}

/// `PSYCH_ASSIGNMENT` / `CARE_SURVEY` keldi — ilova ochiq bo'lsa testlar va
/// so'rovnoma ro'yxati yangilanadi (bola kutib turmasin).
void _handlePsychRefresh(Ref ref, RemoteMessage message) {
  switch (message.data['type']) {
    case 'PSYCH_ASSIGNMENT':
      ref.invalidate(psychAssignmentsProvider);
    case 'CARE_SURVEY':
      ref.invalidate(voiceSurveyProvider);
  }
}

/// `SCHOOL_LINK` — maktab ulanish so'rovini hal qildi (tasdiq / rad / tuzatish
/// natijasi, matn neytral). Maktab bo'limi holati yangilanadi; bosilsa ochiladi.
void _handleSchoolLink(Ref ref, RemoteMessage message, {required bool tap}) {
  if (message.data['type'] != 'SCHOOL_LINK') return;
  ref
    ..invalidate(schoolTodayProvider)
    ..invalidate(linkStatusProvider);
  if (tap) ref.read(routerProvider).go(GrowthV5Routes.school);
}

void _handleChatTap(Ref ref, RemoteMessage message) {
  final type = message.data['type'];
  if (type != 'voice' && type != 'video') return;
  ref.read(routerProvider).go('/voice-chat');
}

/// `unlock_decision` push kelganda — limit qayta sync + bolaga snackbar.
/// APPROVED → success ("X daqiqa ruxsat"); DENIED → info ("rad etildi").
void _handleUnlockDecision(Ref ref, RemoteMessage message) {
  if (message.data['type'] != 'unlock_decision') return;
  // Limit darhol yangilansin (server effektiv limitga grantni qo'shgan).
  _requestRestrictionsSync(ref);

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
      'unlockRequest.approvedSnack'.tr(namedArgs: {'minutes': '$mins'}),
    );
  } else {
    AppSnackBar.info(ctx, 'unlockRequest.deniedSnack'.tr());
  }
}

/// `location_request` push — ota-ona bola joylashuvni O'CHIRGANда "yoqing"
/// so'rovi yubordi. Bolada modal ko'rsatamiz: [Yoqish] → tizim joylashuv
/// sozlamasi ochiladi. Foreground'da ham, push bosilganda ham chiqadi.
void _handleLocationRequest(Ref ref, RemoteMessage message) {
  if (message.data['type'] != 'location_request') return;
  final ctx = ref
      .read(routerProvider)
      .routerDelegate
      .navigatorKey
      .currentContext;
  if (ctx == null || !ctx.mounted) return;
  unawaited(LocationEnableModal.show(ctx));
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
    _handleLocationRequest(ref, msg);
    _handleCareMessage(ref, msg, tap: false);
    _handleSchoolLink(ref, msg, tap: false);
    _handlePsychRefresh(ref, msg);
  };
  service.onMessageTap = (msg) {
    _handleUnlockDecision(ref, msg);
    _handleRestrictionsSync(ref, msg);
    _handleNudgeTap(ref, msg);
    _handleChatTap(ref, msg);
    _handleDeepLink(ref, msg);
    _handleLocationRequest(ref, msg);
    _handleCareMessage(ref, msg, tap: true);
    _handleSchoolTap(ref, msg);
    _handleSchoolLink(ref, msg, tap: true);
  };
  await service.init();
});
