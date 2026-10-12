// ─────────────────────────────────────────────────────────────────────
// FcmService — Child App FCM (Sprint 4.4.8)
// ─────────────────────────────────────────────────────────────────────
//
// Vazifalar:
// - FirebaseMessaging permission so'rash + token olish
// - Backend'ga register qilish (`POST /api/fcm/tokens`)
// - Token refresh listener (eskirsa avtomatik almashtirish)
// - Foreground xabarlari (parent yuborgan voice → snackbar yoki UI)
// - Background tap navigation (push bossa app ochiladi)

// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/platform/platform_capabilities.dart';
import 'package:farzandim_child/features/location/data/services/location_service.dart';
import 'package:farzandim_child/features/screen_time/data/ios_restrictions_sync_service.dart';
import 'package:farzandim_child/features/notifications/data/repositories/backend_fcm_repository.dart';
import 'package:farzandim_child/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AndroidManifest'dagi default channel ID bilan mos kelishi shart.
const String _defaultChannelId = 'farzandim_child_default';
String _defaultChannelName = 'notifications.channel.name'.tr();
String _defaultChannelDesc = 'notifications.channel.desc'.tr();

/// Data-only FCM background handler — app fon/yopiq holatda keladi.
/// 'location_wake': ota-ona xaritani ochdi, bitta yangi fix yuboriladi.
/// 'restrictions_sync' (iOS): ota-ona blok/limit/rejimni o'zgartirdi —
/// Family Controls siyosati darhol yangilanadi (Android'da buni doimiy
/// fon servisi qiladi).
/// Alohida isolate'da ishlaydi — Firebase init majburiy. Best-effort:
/// xato bo'lsa jim chiqadi, crash yo'q.
@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  if (message.data['type'] == 'restrictions_sync' &&
      PlatformCapabilities.isIOS) {
    try {
      await IosRestrictionsSyncService.syncInBackground();
    } catch (e) {
      debugPrint('FCM background restrictions_sync xato: $e');
    }
    return;
  }
  if (message.data['type'] != 'location_wake') return;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // allaqachon init bo'lgan yoki config yo'q — davom etamiz
  }
  await LocationService.sendWakeFix();
}

class FcmService {
  FcmService({
    required BackendFcmRepository backendRepo,
    FirebaseMessaging? messaging,
  }) : _backendRepo = backendRepo,
       _messaging = messaging ?? FirebaseMessaging.instance;

  final BackendFcmRepository _backendRepo;
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;
  StreamSubscription<String>? _onTokenRefreshSub;

  bool _initialized = false;

  /// Foreground xabar callback.
  void Function(RemoteMessage)? onForegroundMessage;

  /// Background tap callback (push bossa).
  void Function(RemoteMessage)? onMessageTap;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Permission so'rash (Android 13+). iOS'da bu yerda SO'RALMAYDI —
    // ruxsatlar ekranida izoh bilan so'raladi (kontekstsiz tizim oynasi
    // ilova ochilishi bilan chiqmasin). FCM token iOS'da ruxsatsiz ham
    // olinadi (APNs ro'yxatdan o'tish ruxsatga bog'liq emas).
    if (!PlatformCapabilities.isIOS) {
      await _messaging.requestPermission();
    }
    await _setupLocalNotifications();

    // 2. Listener'lar TOKENDAN OLDIN ulanadi: iOS'da `getToken()` APNs token
    // hali kelmagan bo'lsa xato beradi — avval shu xato init'ni to'xtatib,
    // butun sessiya davomida xabarlar (restrictions_sync, unlock_decision,
    // location_wake) e'tiborsiz qolardi.
    _onTokenRefreshSub = _messaging.onTokenRefresh.listen(_registerToBackend);

    // 3. Foreground listener — UI ko'rsatish uchun manual local notification.
    _onMessageSub = FirebaseMessaging.onMessage.listen((message) {
      debugPrint('FCM foreground: ${message.notification?.title}');
      // location_wake — ota-ona xaritani ochdi, yangi fix yuboriladi.
      // Data-only xabar — notification ko'rsatilmaydi.
      if (message.data['type'] == 'location_wake') {
        unawaited(LocationService.sendWakeFix());
        return;
      }
      onForegroundMessage?.call(message);
      unawaited(_showLocalNotification(message));
    });

    // 4. Background tap listener.
    _onMessageOpenedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      debugPrint('FCM opened from background');
      onMessageTap?.call(message);
    });

    // 5. Token olish + Backend'ga register (faqat pair'lashgan bo'lsa).
    unawaited(_registerCurrentToken());

    // 6. Cold start (terminated app push bossa).
    try {
      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        onMessageTap?.call(initial);
      }
    } catch (e) {
      debugPrint('FCM getInitialMessage xato: $e');
    }
  }

  /// iOS'da APNs token ilova ishga tushgandan bir oz keyin keladi —
  /// shu paytgacha `getToken()` xato beradi. Bir necha marta qayta uriniladi;
  /// kech kelgan token baribir `onTokenRefresh` orqali yuboriladi.
  Future<void> _registerCurrentToken() async {
    for (var attempt = 1; attempt <= _tokenAttempts; attempt++) {
      try {
        final isApnsReady = !PlatformCapabilities.isIOS ||
            await _messaging.getAPNSToken() != null;
        if (isApnsReady) {
          final token = await _messaging.getToken();
          if (token != null) await _registerToBackend(token);
          return;
        }
      } catch (e) {
        debugPrint('FCM token olinmadi ($attempt/$_tokenAttempts): $e');
      }
      await Future<void>.delayed(_tokenRetryDelay);
    }
  }

  static const _tokenAttempts = 6;
  static const _tokenRetryDelay = Duration(seconds: 5);

  /// HIGH-importance Android notification channel + iOS init.
  Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    // iOS ruxsati ruxsatlar ekranida so'raladi (yuqoridagi izohga qarang).
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _localNotifications.initialize(
      initSettings,
      // Foreground'da ko'rsatilgan lokal banner bosilganda — avval BU
      // callback umuman yo'q edi, shu sababli chat push'i (salom xabari)
      // banner'ga tegib hech qayerga navigatsiya qilmasdi. Payload'dagi
      // FCM `data`ni tiklab xuddi background tap bilan bir xil yo'lga
      // (`onMessageTap` → `_handleChatTap` va h.k.) yuboramiz.
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = (jsonDecode(payload) as Map).cast<String, dynamic>();
          onMessageTap?.call(RemoteMessage(data: data));
        } catch (e) {
          debugPrint('Local notification payload decode xato: $e');
        }
      },
    );

    final androidChannel = AndroidNotificationChannel(
      _defaultChannelId,
      _defaultChannelName,
      description: _defaultChannelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(androidChannel);
  }

  /// Foreground'da kelgan FCM xabarini lokal notification orqali ko'rsatish.
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] as String?;
    final body = notification?.body ?? message.data['body'] as String?;
    if (title == null && body == null) return;

    final androidDetails = AndroidNotificationDetails(
      _defaultChannelId,
      _defaultChannelName,
      channelDescription: _defaultChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final id =
        (message.messageId ?? DateTime.now().toIso8601String()).hashCode &
        0x7FFFFFFF;
    // Payload — banner bosilganda `onDidReceiveNotificationResponse`da
    // asl FCM `data`ni tiklash uchun (chat type/senderId/messageId va h.k.).
    final payload = message.data.isEmpty ? null : jsonEncode(message.data);
    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  /// Pair/login MUVAFFAQIYATIDAN KEYIN chaqiriladi — token backend'ga
  /// kafolatli ro'yxatga olinadi. Aks holda `init()` pair'dan OLDIN ishlab
  /// (JWT hali yo'q), register 401 bo'lib jimgina yutilardi → backend'da
  /// token bo'lmasdi → "Baland ovoz" ring `sent:0` jim no-op bo'lardi.
  Future<void> refreshRegistration() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _registerToBackend(token);
      }
    } catch (e) {
      debugPrint('FCM refreshRegistration xato: $e');
    }
  }

  Future<void> _registerToBackend(String token) async {
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

  /// Logout / pair-code regen paytida — Backend'dagi tokenlarni o'chirish.
  Future<void> clearTokens() async {
    try {
      await _backendRepo.deleteAllTokens();
    } catch (_) {
      /* ignore */
    }
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

  Future<void> dispose() async {
    await _onMessageSub?.cancel();
    await _onMessageOpenedAppSub?.cancel();
    await _onTokenRefreshSub?.cancel();
    _initialized = false;
  }
}
