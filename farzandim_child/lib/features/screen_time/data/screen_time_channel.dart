// ─────────────────────────────────────────────────────────────────────
// ScreenTimeChannel — iOS Family Controls native moduli bilan aloqa
// ─────────────────────────────────────────────────────────────────────
//
// Native: ios/Runner/ScreenTimePlugin.swift + ios/Shared/ParvozShield.swift.
// Bu kanal orqali ilovalar haqida HECH QANDAY ma'lumot Dart'ga kelmaydi —
// faqat sonlar (nechta ilova/toifa tanlangan) va holat.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:farzandim_child/features/screen_time/domain/ios_shield_policy.dart';

enum ScreenTimeAuthorization { notDetermined, denied, approved }

@immutable
class ScreenTimeStatus {
  const ScreenTimeStatus({
    required this.authorization,
    required this.isBlocking,
    required this.apps,
    required this.categories,
    required this.webDomains,
    this.blockAdultWebsites = false,
    this.denyAppInstallation = false,
    this.unlockedUntil,
    this.dailyLimitMinutes,
    this.isDailyLimitReached = false,
  });

  factory ScreenTimeStatus.fromMap(Map<Object?, Object?> map) {
    final name = map['authorization'] as String?;
    final unlockedUntilMs = map['unlockedUntilMs'] as int?;
    return ScreenTimeStatus(
      authorization: ScreenTimeAuthorization.values.firstWhere(
        (a) => a.name == name,
        orElse: () => ScreenTimeAuthorization.notDetermined,
      ),
      isBlocking: map['blocking'] as bool? ?? false,
      apps: map['apps'] as int? ?? 0,
      categories: map['categories'] as int? ?? 0,
      webDomains: map['webDomains'] as int? ?? 0,
      blockAdultWebsites: map['blockAdultWebsites'] as bool? ?? false,
      denyAppInstallation: map['denyAppInstallation'] as bool? ?? false,
      unlockedUntil: unlockedUntilMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(unlockedUntilMs),
      dailyLimitMinutes: map['dailyLimitMinutes'] as int?,
      isDailyLimitReached: map['dailyLimitReached'] as bool? ?? false,
    );
  }

  final ScreenTimeAuthorization authorization;
  final bool isBlocking;
  final int apps;
  final int categories;
  final int webDomains;

  /// Doimiy himoya (ota-ona PIN bilan yoqadi).
  final bool blockAdultWebsites;
  final bool denyAppInstallation;

  /// Ota-ona bergan qo'shimcha vaqt shu paytgacha (cheklov ochiq).
  final DateTime? unlockedUntil;

  /// Ota-ona Android'dan qo'ygan kunlik limit (daqiqa); `null` — yo'q.
  final int? dailyLimitMinutes;

  /// Bugungi kunlik limit tugagan.
  final bool isDailyLimitReached;

  bool get isAuthorized => authorization == ScreenTimeAuthorization.approved;
  bool get hasSelection => apps + categories + webDomains > 0;
}

/// Native xato kodi (FamilyControlsError nomi yoki `notAuthorized` va h.k.).
class ScreenTimeException implements Exception {
  const ScreenTimeException(this.code, [this.message]);

  final String code;
  final String? message;

  @override
  String toString() => 'ScreenTimeException($code${message == null ? '' : ': $message'})';
}

class ScreenTimeChannel {
  const ScreenTimeChannel([
    this._channel = const MethodChannel('uz.parvoz.growth/screen_time'),
  ]);

  final MethodChannel _channel;

  Future<ScreenTimeStatus> status() async =>
      ScreenTimeStatus.fromMap(await _invokeMap('status'));

  /// [strict] = false — Face ID/parol bilan (`.individual`, Oila guruhi
  /// kerak emas). [strict] = true — Family Sharing, ota-ona Apple ID
  /// (`.child`): bola ruxsatni ham, ilovani ham o'chira olmaydi.
  Future<ScreenTimeStatus> requestAuthorization({bool strict = false}) async =>
      ScreenTimeStatus.fromMap(await _invokeMap('requestAuthorization', {
        'mode': strict ? 'child' : 'individual',
      }));

  /// FamilyActivityPicker. `null` — foydalanuvchi bekor qildi.
  Future<ScreenTimeStatus?> pickApps({
    required String title,
    required String cancel,
    required String done,
  }) async {
    final map = await _invoke<Map<Object?, Object?>>('pickApps', {
      'title': title,
      'cancel': cancel,
      'done': done,
    });
    return map == null ? null : ScreenTimeStatus.fromMap(map);
  }

  /// Siyosatni saqlaydi, DeviceActivity jadvallarini yangilaydi va hozirgi
  /// holatni qo'llaydi. [languageCode] — bloklash ekrani matnlari tili.
  /// Qaytaradi: hozir cheklov faolmi.
  Future<bool> applyPolicy(
    IosShieldPolicy policy, {
    String? languageCode,
  }) async {
    final map = await _invokeMap('applyPolicy', {
      ...policy.toMap(),
      if (languageCode != null) 'language': languageCode,
    });
    final errors = (map['scheduleErrors'] as List?)?.cast<String>() ?? const [];
    if (errors.isNotEmpty) {
      debugPrint('ScreenTime: jadval xatolari: $errors');
    }
    return map['blocking'] as bool? ?? false;
  }

  /// Ota-ona tasdiqlagan qo'shimcha vaqt: [until] gacha cheklov ochiq,
  /// cheklangan ilovalardan [minutes] daqiqa foydalanilsa — qaytadi.
  Future<ScreenTimeStatus> grantUnlock({
    required DateTime until,
    required int minutes,
  }) async {
    final map = await _invokeMap('grantUnlock', {
      'untilMs': until.millisecondsSinceEpoch,
      'minutes': minutes,
    });
    return ScreenTimeStatus.fromMap(map);
  }

  Future<ScreenTimeStatus> clearUnlock() async =>
      ScreenTimeStatus.fromMap(await _invokeMap('clearUnlock'));

  Future<ScreenTimeStatus> setExtras({
    required bool blockAdultWebsites,
    required bool denyAppInstallation,
  }) async {
    final map = await _invokeMap('setExtras', {
      'blockAdultWebsites': blockAdultWebsites,
      'denyAppInstallation': denyAppInstallation,
    });
    return ScreenTimeStatus.fromMap(map);
  }

  /// Bloklash ekranida "Qo'shimcha vaqt so'rash" bosilganmi (bir martalik).
  Future<bool> consumePendingUnlockRequest() async =>
      await _invoke<bool>('consumePendingUnlockRequest') ?? false;

  /// Uzish paytida — tanlov, siyosat, jadvallar va cheklovlar o'chiriladi.
  Future<void> reset() => _invoke<void>('reset');

  Future<Map<Object?, Object?>> _invokeMap(
    String method, [
    Object? arguments,
  ]) async {
    final map = await _invoke<Map<Object?, Object?>>(method, arguments);
    if (map == null) throw ScreenTimeException('emptyResult', method);
    return map;
  }

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw ScreenTimeException(e.code, e.message);
    } on MissingPluginException {
      throw const ScreenTimeException('unavailable');
    }
  }
}
