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
  });

  factory ScreenTimeStatus.fromMap(Map<Object?, Object?> map) {
    final name = map['authorization'] as String?;
    return ScreenTimeStatus(
      authorization: ScreenTimeAuthorization.values.firstWhere(
        (a) => a.name == name,
        orElse: () => ScreenTimeAuthorization.notDetermined,
      ),
      isBlocking: map['blocking'] as bool? ?? false,
      apps: map['apps'] as int? ?? 0,
      categories: map['categories'] as int? ?? 0,
      webDomains: map['webDomains'] as int? ?? 0,
    );
  }

  final ScreenTimeAuthorization authorization;
  final bool isBlocking;
  final int apps;
  final int categories;
  final int webDomains;

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

  /// Ota-ona Apple ID bilan tasdiqlaydi (Family Sharing, `.child`).
  Future<ScreenTimeStatus> requestAuthorization() async =>
      ScreenTimeStatus.fromMap(await _invokeMap('requestAuthorization'));

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
  /// holatni qo'llaydi. Qaytaradi: hozir cheklov faolmi.
  Future<bool> applyPolicy(IosShieldPolicy policy) async {
    final map = await _invokeMap('applyPolicy', policy.toMap());
    final errors = (map['scheduleErrors'] as List?)?.cast<String>() ?? const [];
    if (errors.isNotEmpty) {
      debugPrint('ScreenTime: jadval xatolari: $errors');
    }
    return map['blocking'] as bool? ?? false;
  }

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
