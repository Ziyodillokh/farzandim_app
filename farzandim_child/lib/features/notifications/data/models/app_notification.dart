// ─────────────────────────────────────────────────────────────────────
// AppNotification — bola ko'radigan bildirishnoma model
// ─────────────────────────────────────────────────────────────────────
//
// Firestore: users/{parentUid}/children/{childId}/notifications/{id}
//
// Manbalar:
//   - Achievement unlock (gamification)
//   - Konkurs natija
//   - Parent so'rovi (photo/video request)
//   - Schedule reminder
//   - System (yangi feature, update)

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum NotificationType {
  achievement,    // Yutuq unlock
  contest,        // Konkurs natija / boshlash
  schedule,       // Jadval eslatma
  parentRequest,  // Photo/video so'rov
  voice,          // Yangi voice xabar
  geoZone,        // Geo-zone kirish/chiqish
  system,         // Yangi feature, app update
}

extension NotificationTypeX on NotificationType {
  String get firestoreCode {
    switch (this) {
      case NotificationType.achievement:
        return 'achievement';
      case NotificationType.contest:
        return 'contest';
      case NotificationType.schedule:
        return 'schedule';
      case NotificationType.parentRequest:
        return 'parent_request';
      case NotificationType.voice:
        return 'voice';
      case NotificationType.geoZone:
        return 'geo_zone';
      case NotificationType.system:
        return 'system';
    }
  }

  static NotificationType fromCode(String code) {
    for (final t in NotificationType.values) {
      if (t.firestoreCode == code) return t;
    }
    return NotificationType.system;
  }

  IconData get icon {
    switch (this) {
      case NotificationType.achievement:
        return AppIcons.trophy;
      case NotificationType.contest:
        return Icons.workspace_premium;
      case NotificationType.schedule:
        return Icons.schedule;
      case NotificationType.parentRequest:
        return AppIcons.profile;
      case NotificationType.voice:
        return AppIcons.mic;
      case NotificationType.geoZone:
        return AppIcons.mapPin;
      case NotificationType.system:
        return Icons.info_outline;
    }
  }

  Color get color {
    switch (this) {
      case NotificationType.achievement:
        return AppColors.catAmber; // gold
      case NotificationType.contest:
        return AppColors.catViolet; // violet
      case NotificationType.schedule:
        return AppColors.catBlue; // sky
      case NotificationType.parentRequest:
        return AppColors.catPinkVibrant; // pink
      case NotificationType.voice:
        return AppColors.catEmeraldLight; // emerald
      case NotificationType.geoZone:
        return AppColors.catBlue; // sky
      case NotificationType.system:
        return const Color(0xFFA0AEC0); // grey
    }
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.thumbnailUrl,
    this.relatedRoute,
    this.relatedId,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  /// Optional thumbnail (parent request photo, achievement icon).
  final String? thumbnailUrl;

  /// Tap qilingach qaerga olib boradi (`/contests`, `/profile`, ...).
  final String? relatedRoute;

  /// Bog'liq entity ID (contest, achievement, request).
  final String? relatedId;

  /// Backend REST `Notification` JSON'idan parse (Sprint 4.4.9.5).
  ///
  /// Backend kontract:
  /// ```json
  /// {
  ///   "id": "uuid",
  ///   "childId": "uuid",
  ///   "type": "ACHIEVEMENT|CONTEST|SCHEDULE|PARENT_REQUEST|VOICE|GEO_ZONE|SYSTEM",
  ///   "title": "...",
  ///   "body": "...",
  ///   "data": {},
  ///   "isRead": false,
  ///   "createdAt": "ISO 8601"
  /// }
  /// ```
  factory AppNotification.fromBackendJson(Map<String, dynamic> json) {
    final data = (json['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AppNotification(
      id: json['id'] as String? ?? '',
      type: NotificationTypeX.fromCode(
        (json['type'] as String? ?? 'SYSTEM').toLowerCase(),
      ),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: _parseIso(json['createdAt'] as String?) ?? DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      relatedRoute: data['relatedRoute'] as String?,
      relatedId: data['relatedId'] as String?,
    );
  }

  static DateTime? _parseIso(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      return DateTime.parse(iso).toLocal();
    } catch (_) {
      return null;
    }
  }

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppNotification(
      id: doc.id,
      type: NotificationTypeX.fromCode(data['type'] as String? ?? 'system'),
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] as bool? ?? false,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      relatedRoute: data['relatedRoute'] as String?,
      relatedId: data['relatedId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'type': type.firestoreCode,
        'title': title,
        'body': body,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': isRead,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (relatedRoute != null) 'relatedRoute': relatedRoute,
        if (relatedId != null) 'relatedId': relatedId,
      };
}
