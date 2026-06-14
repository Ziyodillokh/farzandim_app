import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:farzandim/features/notifications/data/repositories/backend_fcm_repository.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AndroidManifest'dagi default channel ID bilan mos kelishi shart.
const String _defaultChannelId = 'farzandim_default';
const String _defaultChannelName = 'Farzandim asosiy xabarlari';
const String _defaultChannelDesc =
    'Ovozli xabar, SOS, geo-zona kabi muhim xabarlar';

/// Firebase Cloud Messaging (FCM) bilan ishlaydigan servis.
///
/// **Sprint 4.4.22 cleanup:** Firestore + FirebaseAuth qatlami olib tashlandi.
/// Token faqat Backend (`/api/fcm/tokens`)'ga registratsiya qilinadi.
class FcmService {
  /// Konstruktor.
  FcmService({
    FirebaseMessaging? messaging,
    BackendFcmRepository? backendRepo,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _backendRepo = backendRepo;

  final FirebaseMessaging _messaging;
  final BackendFcmRepository? _backendRepo;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;
  StreamSubscription<String>? _onTokenRefreshSub;

  bool _initialized = false;

  /// FCM xabari kelganda (foreground) chaqiriladi — UI tomonidan
  /// `notificationsProvider`'ga qo'shish uchun.
  void Function(AppNotification)? onForegroundMessage;

  /// Foydalanuvchi notification'ni bossa chaqiriladi (background tap
  /// yoki cold start). Implementatsiya `GoRouter`'dan foydalanib
  /// kerakli ekranga o'tadi.
  void Function(AppNotification)? onMessageTap;

  /// Servisni ishga tushirish — `main.dart` Firebase init'dan keyin
  /// bir marta chaqiring. Idempotent.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // ST-08: bu yerda requestPermission CHAQIRMAYMIZ — init startup'da
    // ishlaydi va ruxsat dialogi TIL TANLASH ekrani ustida chiqardi
    // (foydalanuvchi ilova nimaligini bilmay turib rad etardi). Ruxsat
    // endi login muvaffaqiyatli bo'lgach so'raladi (reRegisterToken).
    await _setupLocalNotifications();

    // ST-06: bu yerda darhol POST QILMAYMIZ. Avval har cold start'da
    // 2 marta POST ketardi (bu yerda #1 + app.dart auth-transition
    // reRegisterToken #2), login qilinmagan holatda esa kafolatlangan
    // 401 so'rov. Registratsiya endi FAQAT: (a) auth-transition'da
    // (app.dart — bootstrap'da har doim ishlaydi) va (b) token refresh
    // bo'lganda (quyidagi listener).
    _onTokenRefreshSub =
        _messaging.onTokenRefresh.listen(saveTokenForCurrentUser);

    _onMessageSub = FirebaseMessaging.onMessage.listen((message) {
      final notification = AppNotification.fromRemoteMessage(message);
      onForegroundMessage?.call(notification);
      // Foreground'da kelganda FCM o'zi UI ko'rsatmaydi — manual.
      unawaited(_showLocalNotification(message));
    });

    _onMessageOpenedAppSub = FirebaseMessaging.onMessageOpenedApp
        .listen(_navigateForMessage);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateForMessage(initialMessage);
      });
    }
  }

  /// FCM token'ni Backend'ga registratsiya qilish.
  Future<void> saveTokenForCurrentUser(String token) async {
    if (_backendRepo == null) return;
    try {
      final deviceId = await _getOrCreateDeviceId();
      final deviceType = Platform.isAndroid ? 'android' : 'ios';
      await _backendRepo.registerToken(
        token: token,
        deviceType: deviceType,
        deviceId: deviceId,
      );
    } catch (e) {
      debugPrint('FCM Backend register xato: $e');
    }
  }

  /// Backend'ga FCM token'ni QAYTA registratsiya qilish.
  ///
  /// `init()` token'ni app startup'da yuboradi — ammo o'sha paytda
  /// foydalanuvchi hali login qilmagan bo'lishi mumkin (JWT yo'q →
  /// `POST /fcm/tokens` 401 qaytaradi). Login muvaffaqiyatli tugagach
  /// shu metod chaqiriladi va token qayta yoziladi.
  Future<void> reRegisterToken() async {
    try {
      // ST-08: ruxsat endi SHU yerda so'raladi — login muvaffaqiyatli
      // bo'lgach (dashboard ochilish payti), til-tanlash ustida emas.
      // Allaqachon berilgan/rad etilgan bo'lsa OS dialog ko'rsatmaydi.
      await _messaging.requestPermission();
      final token = await _messaging.getToken();
      if (token != null) {
        await saveTokenForCurrentUser(token);
      }
    } catch (e) {
      debugPrint('FCM reRegisterToken xato: $e');
    }
  }

  /// Diagnostika: o'ziga test push yuborish (Settings tugmasi).
  /// Backend `{ tokens, sent, failed, invalid }` qaytaradi yoki `null`.
  Future<Map<String, dynamic>?> sendTestPush() async {
    return _backendRepo?.sendTestPush();
  }

  /// High-importance Android notification channel yaratish + iOS init.
  Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Local notification bosildi — payload'dan AppNotification yarata
        // olmaymiz, ammo FCM tap callback baribir ishlaydi.
      },
    );

    // Android: HIGH-importance channel — ovoz va vibratsiya majburiy.
    const androidChannel = AndroidNotificationChannel(
      _defaultChannelId,
      _defaultChannelName,
      description: _defaultChannelDesc,
      importance: Importance.high,
    );
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(androidChannel);
  }

  /// Foreground'da kelgan FCM xabarini lokal notification orqali ko'rsatish.
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] as String?;
    final body = notification?.body ?? message.data['body'] as String?;
    if (title == null && body == null) return;

    const androidDetails = AndroidNotificationDetails(
      _defaultChannelId,
      _defaultChannelName,
      channelDescription: _defaultChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final id = (message.messageId ?? DateTime.now().toIso8601String())
        .hashCode &
        0x7FFFFFFF;
    await _localNotifications.show(id, title, body, details);
  }

  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('fcm_device_id');
    if (id == null || id.isEmpty) {
      final random = math.Random.secure();
      final bytes = List<int>.generate(16, (_) => random.nextInt(256));
      id = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      await prefs.setString('fcm_device_id', id);
    }
    return id;
  }

  /// FCM token'ni olib tashlash (logout paytida) — Backend tomondan.
  Future<void> removeTokenForCurrentUser() async {
    if (_backendRepo == null) return;
    try {
      await _backendRepo.deleteAllTokens();
    } catch (e) {
      debugPrint('FCM Backend logout xato: $e');
    }
  }

  void _navigateForMessage(RemoteMessage message) {
    final notification = AppNotification.fromRemoteMessage(message);
    onMessageTap?.call(notification);
  }

  Future<void> dispose() async {
    await _onMessageSub?.cancel();
    await _onMessageOpenedAppSub?.cancel();
    await _onTokenRefreshSub?.cancel();
    _initialized = false;
  }
}

/// FCM tap-event'ni `GoRouter` orqali tegishli ekranga navigatsiya
/// qilish.
///
/// MUHIM (BUG-02): `go()` flat route'ga stack'ni BO'SHATIB qo'yardi —
/// foydalanuvchi "orqaga" bossa GoError ("There is nothing to pop") yoki
/// ilovadan chiqib ketardi. Endi dashboard asos qilinib ustiga `push` —
/// "orqaga" har doim dashboard'ga qaytadi.
void handleFcmTap(AppNotification notif, GoRouter router) {
  void open(String path) {
    router
      ..go(AppRoutes.dashboard)
      ..push(path);
  }

  switch (notif.type) {
    case NotificationType.sos:
    case NotificationType.enterZone:
    case NotificationType.exitZone:
      if (notif.childId.isEmpty) {
        open(AppRoutes.notifications);
      } else {
        open(AppRoutes.locationPath(notif.childId));
      }
    case NotificationType.lowBattery:
      // Past batareya — bola qayerdaligi muhim → jonli xarita.
      if (notif.childId.isNotEmpty) {
        open(AppRoutes.locationPath(notif.childId));
      } else {
        open(AppRoutes.notifications);
      }
    case NotificationType.appLimit:
    case NotificationType.game:
      if (notif.childId.isNotEmpty) {
        open(AppRoutes.appRestrictionsPath(notif.childId));
      } else {
        open(AppRoutes.notifications);
      }
    case NotificationType.scheduleStart:
    case NotificationType.scheduleReminder:
      if (notif.childId.isNotEmpty) {
        open(AppRoutes.schedulesPath(notif.childId));
      } else {
        open(AppRoutes.notifications);
      }
    case NotificationType.pairRequest:
      if (notif.childId.isNotEmpty) {
        open(AppRoutes.pairRequestsPath(notif.childId));
      } else {
        open(AppRoutes.notifications);
      }
    case NotificationType.unlockRequest:
      // Qaror varag'i bildirishnomalar ekranidagi kartochkadan ochiladi.
      open(AppRoutes.notifications);
    case NotificationType.offline:
    case NotificationType.online:
      open(AppRoutes.notifications);
  }
}
