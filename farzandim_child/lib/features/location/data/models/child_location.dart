// ─────────────────────────────────────────────────────────────────────
// ChildLocation — bola joylashuvi
// ─────────────────────────────────────────────────────────────────────
//
// Firestore'da `users/{parentUid}/children/{childId}/location` ostida
// saqlanadi (oxirgi joylashuv). Parent App map ekranda real-vaqt pin
// ko'rsatish uchun shu maydonga obuna bo'ladi.

import 'package:cloud_firestore/cloud_firestore.dart';

class ChildLocation {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double? heading;
  final double? speed;
  final DateTime? updatedAt;

  const ChildLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.heading,
    this.speed,
    this.updatedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'heading': heading,
      'speed': speed,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory ChildLocation.fromFirestore(Map<String, dynamic> data) {
    return ChildLocation(
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      accuracy: (data['accuracy'] as num?)?.toDouble() ?? 0,
      heading: (data['heading'] as num?)?.toDouble(),
      speed: (data['speed'] as num?)?.toDouble(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }
}
