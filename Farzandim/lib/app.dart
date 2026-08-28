import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/network/dio_client.dart' show onFeatureLocked;
import 'package:farzandim/core/realtime/socket_providers.dart';
import 'package:farzandim/core/routing/app_router.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_theme.dart';
import 'package:farzandim/core/theme/theme_mode_provider.dart';
import 'package:farzandim/features/app_update/data/models/app_version_info.dart';
import 'package:farzandim/features/app_update/presentation/dialogs/force_update_dialog.dart';
import 'package:farzandim/features/app_update/presentation/providers/app_update_provider.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/geo_zones/presentation/providers/geo_zones_provider.dart';
import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:farzandim/features/notifications/presentation/providers/fcm_provider.dart';
import 'package:farzandim/features/notifications/presentation/providers/unlock_request_sync_provider.dart';
import 'package:farzandim/features/notifications/presentation/screens/sos_sheet.dart';
import 'package:farzandim/features/notifications/presentation/widgets/notification_permission_primer.dart';
import 'package:farzandim/features/pair_requests/presentation/providers/pair_request_providers.dart';
import 'package:farzandim/features/settings/data/apple_receipt_sync_service.dart';
import 'package:farzandim/features/settings/presentation/plan_gate.dart';
import 'package:farzandim/features/sos/presentation/providers/sos_provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

/// iOS uslubidagi bouncing scroll fizika (web va native).
/// Sichqoncha/trackpad bilan ham drag ishlaydi — web'da test qulay.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}

/// Hozir ekranda turgan SOS banner'ining alert id'si (yo'q bo'lsa `null`).
///
/// Ikki vazifasi bor: bir xil alert uchun banner takrorlanmasin va
/// `sos:resolved` kelganda AYNAN o'sha banner yopilsin.
///
/// `late` mos emas — "banner yo'q" holati aynan `null` bilan ifodalanadi va
/// banner yopilgach qiymat qayta `null` ga qaytadi.
// ignore: use_late_for_private_fields_and_variables
String? _shownSosAlertId;

/// SOS WS payload'idan alert id'sini oladi.
///
/// `sos:received` → `{ alert: {id, ...}, childId, childName }`
/// `sos:resolved` → `{ id, childId, status, ... }` (yangilangan qator)
String? _sosAlertIdOf(Map<String, dynamic> payload) {
  final nested = (payload['alert'] as Map?)?['id'];
  if (nested is String && nested.isNotEmpty) return nested;
  final flat = payload['id'] ?? payload['sosAlertId'];
  return flat is String && flat.isNotEmpty ? flat : null;
}

/// Global SOS banner — qizil gradient karta, pulsatsiyalanuvchi ikona,
/// bola ismi va oq "Ko'rish" tugmasi.
class _SosBanner extends StatefulWidget {
  const _SosBanner({
    required this.onView,
    required this.onDismiss,
    this.childName,
  });

  final String? childName;
  final VoidCallback onView;
  final VoidCallback onDismiss;

  @override
  State<_SosBanner> createState() => _SosBannerState();
}

class _SosBannerState extends State<_SosBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.childName;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDC2626), Color(0xFFF05252)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Row(
        children: [
          // Pulsatsiya — SOS shoshilinchligini bildiradi.
          ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.08).animate(
              CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
            ),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                SolarIconsBold.dangerTriangle,
                color: Colors.white,
                size: 23,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 2 qator — tor ekranda (360dp) matnga ~135dp qoladi va
                // "SOS! Bola yordam so'ramoqda" bir qatorga sig'maydi.
                Text(
                  'sos.wsBanner'.tr(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    height: 1.2,
                  ),
                ),
                if (name != null && name.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: widget.onView,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                child: Text(
                  'sos.viewAction'.tr(),
                  style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          // Yopish — ota-ona SOS'ni ko'rgan bo'lsa banner'ni qo'lda olib
          // tashlashi mumkin (avval faqat 10 soniya kutish kerak edi).
          IconButton(
            onPressed: widget.onDismiss,
            icon: Icon(
              SolarIconsBold.closeCircle,
              color: Colors.white.withValues(alpha: 0.8),
              size: 20,
            ),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          ),
        ],
      ),
    );
  }
}

/// Ildiz widget — router, FCM init va socket lifecycle provider'lariga
/// obuna bo'lib, WS event'lar uchun global banner'larni ko'rsatadi.
class FarzandimApp extends ConsumerWidget {
  const FarzandimApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref
      // FCM init triggeri — birinchi build'da ishga tushadi va keshlanadi.
      // Natijaga (AsyncValue<void>) e'tibor bermaymiz — xato bo'lsa
      // `fcm_service.dart` ichida `debugPrint` qiladi.
      ..watch(fcmInitializerProvider)
      // Socket.io lifecycle — auth state'ga listen qilib avtomatik
      // connect/disconnect qiladi. Side-effect, value qaytarmaydi.
      ..watch(socketLifecycleProvider)
      // iOS obuna renewal/expiry "poll" — ilova darajasida (faqat
      // "Tariflar" ekrani ochiq bo'lganda EMAS). Android/web'da no-op.
      ..watch(appleReceiptSyncServiceProvider);

    // Toggle'ga qarab AppColors.brightness o'rnatiladi. Root build
    // descendant'lardan oldin ishlaydi, shuning uchun keyin barcha
    // widget'lar to'g'ri rangni o'qiydi.
    final themeMode = ref.watch(themeModeProvider);
    AppColors.brightness = themeMode.brightness;

    // ── Til reaktivligi: locale → router refresh ──────────────────────
    // `context.setLocale()` faqat easy_localization holatini yangilaydi;
    // go_router sahifalarni cache qiladi (Navigator GlobalKey), shuning uchun
    // til almashganda joriy ekran (masalan Dashboard) ESKI tilda qolib "bir
    // marta refresh" talab qilardi. Joriy locale'ni provider'ga sinxronlaymiz
    // → refreshListenable fire bo'lib router sahifani QAYTA quradi (theme
    // reaktivligi bilan aynan bir xil mexanizm).
    final localeCode = context.locale.languageCode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final localeNotifier = ref.read(localeRefreshProvider.notifier);
      if (localeNotifier.state != localeCode) {
        localeNotifier.state = localeCode;
      }
    });

    // ── Tarif (entitlement) qulflangan funksiya → "yuksalting" oynasi ──
    // Backend `@RequireFeature` guard 403 (FEATURE_NOT_IN_PLAN / CHILD_LIMIT_
    // REACHED) qaytarsa dio interceptor `onFeatureLocked`ni chaqiradi. Shu
    // yerda bir marta ulaymiz — har qanday qulflangan funksiya (va bola-limit)
    // uchun bitta markaziy "Premium funksiya" oynasi.
    onFeatureLocked ??= (feature, message, requiredTier) {
      final ctx =
          ref.read(routerProvider).routerDelegate.navigatorKey.currentContext;
      if (ctx == null) return;
      showUpgradeDialog(ctx, ref, tier: requiredTier, message: message);
    };

    // FCM token re-registratsiya — login muvaffaqiyatli tugagach.
    // `fcmInitializerProvider` token'ni startup'da yuboradi, ammo o'sha
    // paytda JWT yo'q bo'lsa 401 olib registratsiya bo'lmaydi. Auth
    // state `AuthAuthenticated`'ga o'tganda token qayta yoziladi —
    // shu bilan admin panel push'lari Parent App'ga yetib boradi.
    ref
      ..listen<BackendAuthState>(backendAuthProvider, (previous, next) {
        if (next is AuthAuthenticated && previous is! AuthAuthenticated) {
          // Login muvaffaqiyatli — avval bildirishnoma "primer"i (rationale)
          // ko'rsatiladi, so'ng OS ruxsati so'raladi va FCM token saqlanadi.
          // Navigator konteksti tayyor bo'lishi uchun post-frame'da chaqiramiz.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final navContext = ref
                .read(routerProvider)
                .routerDelegate
                .navigatorKey
                .currentContext;
            if (navContext != null && navContext.mounted) {
              NotificationPermissionPrimer.ensure(navContext, ref);
            } else {
              // Kontekst topilmasa (kamdan-kam) — token'ni baribir
              // registratsiya qilamiz (eski fallback xulqi).
              ref.read(fcmServiceProvider).reRegisterToken();
            }
            // Bola "qo'shimcha vaqt" so'rovlarini serverdan tortamiz.
            // Push YAGONA kanal bo'lib qolmasin: yetib bormagan so'rov
            // ilova ochilganda baribir ko'rinadi. Shu o'qish provayderni
            // ham yaratadi → u fondan qaytishni o'zi kuzata boshlaydi.
            unawaited(ref.read(unlockRequestSyncProvider).sync());
          });
        }
      })
      // SOS WS event'i — eng yuqori prioritet, qizil banner.
      ..listen<AsyncValue<Map<String, dynamic>>>(sosReceivedAlertProvider, (
        _,
        next,
      ) {
        final payload = next.valueOrNull;
        if (payload == null || payload.isEmpty) return;
        final messenger = _scaffoldMessengerKey.currentState;
        if (messenger == null) return;

        final alertId = _sosAlertIdOf(payload);
        // Bir xil alert takror kelsa (WS qayta ulanishi, bola tugmani qayta
        // bosishi) banner'ni QAYTA navbatga qo'ymaymiz. Avval har event yangi
        // SnackBar qo'shardi — navbat yig'ilib, bittasi yopilgach darhol
        // keyingisi chiqardi va banner "umuman ketmayapti"dek ko'rinardi.
        if (alertId != null && alertId == _shownSosAlertId) return;
        _shownSosAlertId = alertId;

        final childName =
            payload['childName'] as String? ??
            (payload['child'] as Map?)?['name'] as String?;

        // SOS eng yuqori prioritet — navbatdagi past prioritetli banner'lar
        // (pair-request, geo-zona) SOS'ni kutib turmasin.
        messenger.clearSnackBars();
        final controller = messenger.showSnackBar(
          SnackBar(
            // Fon/padding'ni `_SosBanner` o'zi boshqaradi.
            backgroundColor: Colors.transparent,
            elevation: 0,
            padding: EdgeInsets.zero,
            duration: const Duration(seconds: 12),
            behavior: SnackBarBehavior.floating,
            content: _SosBanner(
              childName: childName,
              // Bosilsa — xaritali "SOS xabar" modali (notification tap bilan
              // bir xil UI). Navigator konteksti bo'lmasa ro'yxatga fallback.
              onView: () {
                messenger.hideCurrentSnackBar();
                final router = ref.read(routerProvider);
                final navContext =
                    router.routerDelegate.navigatorKey.currentContext;
                if (navContext == null) {
                  router.push(AppRoutes.sosAlerts);
                  return;
                }
                final childId =
                    (payload['childId'] as String?) ??
                    (payload['child'] as Map?)?['id'] as String? ??
                    '';
                final sosNotif = AppNotification(
                  id: alertId ?? 'sos-${DateTime.now().millisecondsSinceEpoch}',
                  type: NotificationType.sos,
                  childId: childId,
                  childName: childName ?? '',
                  title: 'SOS',
                  message: '',
                  timestamp: DateTime.now(),
                );
                unawaited(SosSheet.show(navContext, sosNotif));
              },
              onDismiss: messenger.hideCurrentSnackBar,
            ),
          ),
        );
        // Yopilgach id'ni bo'shatamiz — o'sha bola keyinchalik YANGI SOS
        // yuborsa banner yana ko'rinishi kerak.
        unawaited(
          controller.closed.then((_) {
            if (_shownSosAlertId == alertId) _shownSosAlertId = null;
          }),
        );
      })
      // SOS hal qilindi — qizil banner darhol yopilsin. Alert boshqa
      // qurilmada hal qilingan bo'lsa ham shu event keladi.
      ..listen<AsyncValue<Map<String, dynamic>>>(sosResolvedAlertProvider, (
        _,
        next,
      ) {
        final payload = next.valueOrNull;
        if (payload == null || payload.isEmpty) return;
        final resolvedId = _sosAlertIdOf(payload);
        if (resolvedId == null || resolvedId != _shownSosAlertId) return;
        _shownSosAlertId = null;
        _scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
      })
      // Pair request yaratildi WS event'i — sariq banner.
      ..listen<AsyncValue<Map<String, dynamic>>>(pairRequestCreatedProvider, (
        _,
        next,
      ) {
        final payload = next.valueOrNull;
        if (payload == null || payload.isEmpty) return;
        final messenger = _scaffoldMessengerKey.currentState;
        if (messenger == null) return;
        final childName =
            (payload['child'] as Map?)?['name'] as String? ??
            payload['childName'] as String? ??
            'pairRequests.fallbackChildName'.tr();
        final childId = payload['childId'] as String?;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'childManagement.pairBanner.message'.tr(
                namedArgs: {'name': childName},
              ),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            backgroundColor: const Color(0xFFFBBF24),
            duration: const Duration(seconds: 10),
            behavior: SnackBarBehavior.floating,
            action: childId != null
                ? SnackBarAction(
                    label: 'sos.viewAction'.tr(),
                    textColor: Colors.black,
                    onPressed: () => ref
                        .read(routerProvider)
                        .push(AppRoutes.pairRequestsPath(childId)),
                  )
                : null,
          ),
        );
      })
      // Geo zone alert WS event'i — foreground'da har joydan ko'rinadigan
      // SnackBar. Background'da backend FCM push yuboradi.
      ..listen<AsyncValue<Map<String, dynamic>>>(geoZoneAlertProvider, (
        _,
        next,
      ) {
        final payload = next.valueOrNull;
        if (payload == null || payload.isEmpty) return;
        final messengerKey = _scaffoldMessengerKey;
        final messenger = messengerKey.currentState;
        if (messenger == null) return;
        final zoneName =
            payload['zoneName'] as String? ??
            'dashboard.geoZoneAlert.zoneFallback'.tr();
        final isEnter = payload['event'] == 'enter';
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              (isEnter
                      ? 'dashboard.geoZoneAlert.enter'
                      : 'dashboard.geoZoneAlert.exit')
                  .tr(namedArgs: {'zone': zoneName}),
            ),
            backgroundColor: isEnter
                ? const Color(0xFF4ADE80)
                : const Color(0xFFFBBF24),
          ),
        );
      });

    // Startup'da backend'dan versiya tekshiruvi. Force update bo'lsa modal
    // dialog (eski versiya bilan ishlash taqiqlanadi), soft update Dashboard
    // banner'ida ko'rinadi. Birinchi qiymat ref.watch'dan, keyingilari
    // ref.listen orqali.
    final initialUpdateStatus = ref.watch(appUpdateProvider).valueOrNull;
    if (initialUpdateStatus != null &&
        initialUpdateStatus.state == UpdateState.forceUpdateRequired &&
        !_forceUpdateDialogShown) {
      _forceUpdateDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final router = ref.read(routerProvider);
        final navContext = router.routerDelegate.navigatorKey.currentContext;
        if (navContext != null) {
          ForceUpdateDialog.show(navContext, initialUpdateStatus);
        }
      });
    }
    ref.listen<AsyncValue<AppUpdateStatus>>(appUpdateProvider, (
      previous,
      next,
    ) {
      final status = next.valueOrNull;
      if (status == null) return;
      if (status.state != UpdateState.forceUpdateRequired) return;
      if (_forceUpdateDialogShown) return;
      _forceUpdateDialogShown = true;
      final router = ref.read(routerProvider);
      final navContext = router.routerDelegate.navigatorKey.currentContext;
      if (navContext == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ForceUpdateDialog.show(navContext, status);
      });
    });

    return MaterialApp.router(
      title: 'Parvoz Parents',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _AppScrollBehavior(),
      theme: AppTheme.build(),
      // Light/dark almashishda Theme.of() widget'lari 200ms crossfade
      // qiladi, AppColors getter'lari esa darhol flip qiladi — bu
      // nomuvofiqlik jank beradi. Zero qilib hammasini bir kadrda
      // almashtiramiz.
      themeAnimationDuration: Duration.zero,
      // Global baza fon — barcha route'lar ortida theme rangi turadi.
      // Transparent scaffold'larda overscroll paytida oq OS oyna foni
      // ko'rinib qolmasin; bitta joyda hal qilingani uchun har ekranni
      // alohida o'zgartirish shart emas.
      // Matn-masshtabining faqat YUQORI chegarasi cheklanadi (1.15):
      // telefonning system "katta shrift" sozlamasi bilan matn kattalashib,
      // qattiq balandlikdagi kartalarni overflow qilardi.
      //
      // ⚠️ `minScaleFactor: 1` QO'YMANG — u Material date picker'ni buzadi.
      // `_DatePickerHeader` sarlavhani `clamp(maxScaleFactor: currentScale)`
      // bilan cheklaydi; odatiy shriftda currentScale = 1.0. Bizning min=1
      // bilan kesishganda min va max ikkalasi ham 1.0 bo'lib qoladi, Flutter
      // esa `assert(maxScale > minScale)` (qat'iy katta) talab qiladi →
      // "Yangi bola qo'shish" ekranida sana tanlash oynasi qizil xato bilan
      // yiqilardi (2026-08-11 da aniqlandi).
      //
      // Pastki chegara kerak emas: matn kichiklashishi hech qanday tartibni
      // buzmaydi, aksincha kichik shrift tanlagan foydalanuvchi uchun to'g'ri.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: ColoredBox(
          color: AppColors.background,
          // Theme YOKI til o'zgarganda subtree remount bo'ladi (key o'zgaradi):
          // AppColors static getter'lari yangi rangni, `.tr()` yangi tilni
          // o'qiydi. go_router sahifalarni cache qiladi — locale key'da
          // bo'lmasa til almashganda eski tilda qolib, "refresh" kerak
          // bo'lardi. Route stack saqlanadi.
          child: KeyedSubtree(
            key: ValueKey('${themeMode}_${context.locale.languageCode}'),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
      routerConfig: ref.watch(routerProvider),
      scaffoldMessengerKey: _scaffoldMessengerKey,
      // easy_localization delegate va supportedLocales — `EasyLocalization`
      // widget'idan keladi (main.dart'da o'ralgan). `context.locale` ham
      // shu yerdan o'qiladi.
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}

/// Global ScaffoldMessenger key — WS banner'lar har qanday ekranda
/// ko'rinishi uchun (router shape'idan tashqarida ham).
final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Force-update dialogi bir marta ochilsin — busiz build ichidagi
/// `ref.watch(appUpdateProvider)` tufayli har rebuild'da dialog ustma-ust
/// qayta ochilardi.
bool _forceUpdateDialogShown = false;
