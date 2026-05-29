// ─────────────────────────────────────────────────────────────────────
// ChildDeviceInfo — bola qurilmasining ma'lumotlari
// ─────────────────────────────────────────────────────────────────────
//
// Firestore'da `users/{parentUid}/children/{childId}/deviceInfo` ostida
// saqlanadi. Parent App ushbu maydonni real-vaqt o'qib bola haqida
// (telefon modeli, batareya, Wi-Fi, online/offline) ma'lumot ko'rsatadi.

import 'package:cloud_firestore/cloud_firestore.dart';

class ChildDeviceInfo {
  final String? deviceModel;
  final String? androidVersion;
  final String? appVersion;
  final int? batteryLevel;
  final bool? isCharging;
  final String? wifiName;
  final bool isOnline;
  final DateTime? lastSeen;

  const ChildDeviceInfo({
    this.deviceModel,
    this.androidVersion,
    this.appVersion,
    this.batteryLevel,
    this.isCharging,
    this.wifiName,
    this.isOnline = false,
    this.lastSeen,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'deviceModel': deviceModel,
      'androidVersion': androidVersion,
      'appVersion': appVersion,
      'batteryLevel': batteryLevel,
      'isCharging': isCharging,
      'wifiName': wifiName,
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    };
  }

  factory ChildDeviceInfo.fromFirestore(Map<String, dynamic> data) {
    return ChildDeviceInfo(
      deviceModel: data['deviceModel'] as String?,
      androidVersion: data['androidVersion'] as String?,
      appVersion: data['appVersion'] as String?,
      batteryLevel: data['batteryLevel'] as int?,
      isCharging: data['isCharging'] as bool?,
      wifiName: data['wifiName'] as String?,
      isOnline: data['isOnline'] as bool? ?? false,
      lastSeen: data['lastSeen'] != null
          ? (data['lastSeen'] as Timestamp).toDate()
          : null,
    );
  }
}
