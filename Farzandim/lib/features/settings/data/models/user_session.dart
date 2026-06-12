// ─────────────────────────────────────────────────────────────────────
// UserSession — "Faol sessiyalar" modeli (Backend GET /api/auth/sessions)
// ─────────────────────────────────────────────────────────────────────

import 'package:easy_localization/easy_localization.dart';

/// Login qilingan bitta qurilma sessiyasi.
class UserSession {
  const UserSession({
    required this.id,
    required this.isCurrent,
    this.deviceModel,
    this.platform,
    this.ipAddress,
    this.city,
    this.country,
    this.createdAt,
    this.lastSeenAt,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? v) =>
        v is String ? DateTime.tryParse(v)?.toLocal() : null;
    return UserSession(
      id: json['id'] as String? ?? '',
      isCurrent: json['isCurrent'] as bool? ?? false,
      deviceModel: (json['deviceModel'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['deviceModel'] as String).trim(),
      platform: (json['platform'] as String?)?.trim(),
      ipAddress: (json['ipAddress'] as String?)?.trim(),
      city: (json['city'] as String?)?.trim(),
      country: (json['country'] as String?)?.trim(),
      createdAt: parseDate(json['createdAt']),
      lastSeenAt: parseDate(json['lastSeenAt']),
    );
  }

  final String id;
  final bool isCurrent;
  final String? deviceModel;
  final String? platform; // android | ios | web
  final String? ipAddress;
  final String? city;
  final String? country;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;

  bool get isAndroid => platform == 'android';
  bool get isIos => platform == 'ios';
  bool get isWeb => platform == 'web';

  /// Ko'rsatiladigan qurilma nomi — model bo'lmasa platforma bo'yicha label.
  String get displayName {
    if (deviceModel != null && deviceModel!.isNotEmpty) return deviceModel!;
    switch (platform) {
      case 'android':
        return 'settings.sessions.androidDevice'.tr();
      case 'ios':
        return 'iPhone / iPad';
      case 'web':
        return 'settings.sessions.browser'.tr();
      default:
        return 'settings.sessions.unknownDevice'.tr();
    }
  }

  /// "Andijon, Uzbekistan" yoki bo'sh bo'lsa null.
  String? get locationLabel {
    final parts = <String>[
      if (city != null && city!.isNotEmpty) city!,
      if (country != null && country!.isNotEmpty) country!,
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }
}
