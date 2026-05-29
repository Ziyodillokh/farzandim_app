import 'package:flutter/foundation.dart';

/// Bildirishnoma sozlamalari — qaysi turdagi push xabarlar yoqilgan.
///
/// Firestore'da `users/{uid}.notificationSettings` map ostida saqlanadi.
/// Cloud Function FCM yuborishdan oldin shu sozlamalarni tekshiradi.
@immutable
class NotificationSettings {
  /// `NotificationSettings` konstruktor — barcha turlari default
  /// yoqilgan.
  const NotificationSettings({
    this.pushEnabled = true,
    this.locationAlerts = true,
    this.geoZoneAlerts = true,
    this.batteryAlerts = true,
    this.screenTimeAlerts = true,
  });

  /// Firestore map'idan parse — `users/{uid}.notificationSettings`.
  ///
  /// Mavjud bo'lmagan maydonlar default `true` qiymatini oladi (yangi
  /// turdagi xabar qo'shilganda eski foydalanuvchilar uchun safe default).
  factory NotificationSettings.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return const NotificationSettings();
    return NotificationSettings(
      pushEnabled: (data['pushEnabled'] as bool?) ?? true,
      locationAlerts: (data['locationAlerts'] as bool?) ?? true,
      geoZoneAlerts: (data['geoZoneAlerts'] as bool?) ?? true,
      batteryAlerts: (data['batteryAlerts'] as bool?) ?? true,
      screenTimeAlerts: (data['screenTimeAlerts'] as bool?) ?? true,
    );
  }

  /// Asosiy push toggle. `false` bo'lsa qolgan barcha xabarlar
  /// yuborilmaydi (master switch).
  final bool pushEnabled;

  /// Bola joylashuv yangilanganda xabar.
  final bool locationAlerts;

  /// Geo-zonaga kirsa/chiqsa xabar.
  final bool geoZoneAlerts;

  /// Bola qurilmasi batareyasi kam bo'lsa xabar.
  final bool batteryAlerts;

  /// Ekran vaqti chegarasi tugaganda xabar.
  final bool screenTimeAlerts;

  /// Firestore'ga yozish uchun map (`users/{uid}.notificationSettings`).
  Map<String, dynamic> toFirestore() {
    return {
      'pushEnabled': pushEnabled,
      'locationAlerts': locationAlerts,
      'geoZoneAlerts': geoZoneAlerts,
      'batteryAlerts': batteryAlerts,
      'screenTimeAlerts': screenTimeAlerts,
    };
  }

  /// Yangi `NotificationSettings` yaratish — bitta yoki bir nechta
  /// maydonni o'zgartiradi.
  NotificationSettings copyWith({
    bool? pushEnabled,
    bool? locationAlerts,
    bool? geoZoneAlerts,
    bool? batteryAlerts,
    bool? screenTimeAlerts,
  }) {
    return NotificationSettings(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      locationAlerts: locationAlerts ?? this.locationAlerts,
      geoZoneAlerts: geoZoneAlerts ?? this.geoZoneAlerts,
      batteryAlerts: batteryAlerts ?? this.batteryAlerts,
      screenTimeAlerts: screenTimeAlerts ?? this.screenTimeAlerts,
    );
  }
}
