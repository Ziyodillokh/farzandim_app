// ─────────────────────────────────────────────────────────────────────
// notification_settings_provider — SharedPreferences (Sprint 4.4.22)
// ─────────────────────────────────────────────────────────────────────
//
// Eski Firestore stream o'rniga lokal saqlash. Bildirishnoma sozlamalari
// device-specific bo'lib qoladi (parent ko'p qurilmaga kirsa har birida
// alohida). Kelajakda Backend `User.preferences`'ga ko'chiriladi.

import 'dart:async';
import 'dart:convert';

import 'package:farzandim/features/settings/data/models/notification_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'notification_settings_v1';

class NotificationSettingsNotifier
    extends StateNotifier<NotificationSettings> {
  NotificationSettingsNotifier() : super(const NotificationSettings()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      state = NotificationSettings(
        pushEnabled: map['pushEnabled'] as bool? ?? true,
        locationAlerts: map['locationAlerts'] as bool? ?? true,
        geoZoneAlerts: map['geoZoneAlerts'] as bool? ?? true,
        batteryAlerts: map['batteryAlerts'] as bool? ?? true,
        screenTimeAlerts: map['screenTimeAlerts'] as bool? ?? true,
      );
    } catch (e) {
      debugPrint('NotificationSettings _load: $e');
    }
  }

  Future<void> _persist(NotificationSettings updated) async {
    state = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {
        'pushEnabled': updated.pushEnabled,
        'locationAlerts': updated.locationAlerts,
        'geoZoneAlerts': updated.geoZoneAlerts,
        'batteryAlerts': updated.batteryAlerts,
        'screenTimeAlerts': updated.screenTimeAlerts,
      };
      await prefs.setString(_prefsKey, jsonEncode(map));
    } catch (e) {
      debugPrint('NotificationSettings _persist: $e');
    }
  }

  /// Push master toggle.
  // ignore: avoid_positional_boolean_parameters
  void togglePush(bool value) {
    unawaited(_persist(state.copyWith(pushEnabled: value)));
  }

  /// Joylashuv yangilanish xabarlari.
  // ignore: avoid_positional_boolean_parameters
  void toggleLocation(bool value) {
    unawaited(_persist(state.copyWith(locationAlerts: value)));
  }

  /// Geo-zona kirish/chiqish xabarlari.
  // ignore: avoid_positional_boolean_parameters
  void toggleGeoZone(bool value) {
    unawaited(_persist(state.copyWith(geoZoneAlerts: value)));
  }

  /// Batareya kam bo'lsa xabar.
  // ignore: avoid_positional_boolean_parameters
  void toggleBattery(bool value) {
    unawaited(_persist(state.copyWith(batteryAlerts: value)));
  }

  /// Ekran vaqti tugadi xabar.
  // ignore: avoid_positional_boolean_parameters
  void toggleScreenTime(bool value) {
    unawaited(_persist(state.copyWith(screenTimeAlerts: value)));
  }
}

final notificationSettingsProvider = StateNotifierProvider<
    NotificationSettingsNotifier, NotificationSettings>(
  (ref) => NotificationSettingsNotifier(),
);
