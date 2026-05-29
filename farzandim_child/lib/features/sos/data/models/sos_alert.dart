// ─────────────────────────────────────────────────────────────────────
// SosAlert — bola "yordam kerak" signali
// ─────────────────────────────────────────────────────────────────────
//
// Firestore'da `sos_alerts/{alertId}` ostida saqlanadi. Parent App
// shu kolleksiyaga real-vaqt obuna bo'lib, alert dialog ko'rsatadi.

import 'package:cloud_firestore/cloud_firestore.dart';

enum SosStatus { active, resolved }

class SosAlert {
  final String? id;
  final String parentUid;
  final String childId;
  final String childName;
  final double? latitude;
  final double? longitude;
  final int? batteryLevel;
  final String? wifiName;
  final SosStatus status;
  final DateTime? createdAt;

  const SosAlert({
    this.id,
    required this.parentUid,
    required this.childId,
    required this.childName,
    this.latitude,
    this.longitude,
    this.batteryLevel,
    this.wifiName,
    this.status = SosStatus.active,
    this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'parentUid': parentUid,
      'childId': childId,
      'childName': childName,
      if (latitude != null && longitude != null)
        'location': {
          'latitude': latitude,
          'longitude': longitude,
        },
      'deviceInfo': {
        'batteryLevel': batteryLevel,
        'wifiName': wifiName,
      },
      'status': status.name,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
