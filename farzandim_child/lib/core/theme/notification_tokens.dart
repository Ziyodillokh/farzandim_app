// ─────────────────────────────────────────────────────────────────────
// notification_tokens — premium "Bildirishnomalar" dizayn tokenlari (#UI)
// ─────────────────────────────────────────────────────────────────────
//
// Reference dizaynidagi aniq qiymatlar. Har bildirishnoma turi o'z vizual
// kimligiga ega bo'lishi uchun kategoriya-stil xaritasi (icon + accent +
// soft fon) shu yerda — data-driven, takror "kulrang blok" emas.

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/features/notifications/data/models/app_notification.dart';
import 'package:flutter/material.dart';

/// Premium notifications ekrani uchun ranglar/o'lchamlar/soyalar.
abstract final class NotifTokens {
  // Matn
  static const Color ink = Color(0xFF0E1726);
  static const Color ink2 = Color(0xFF3A4658);
  static const Color muted = Color(0xFF9AA4B6);

  // Aksentlar (accent + soft fon)
  static const Color primary = Color(0xFF3B5BFD);
  static const Color primarySoft = Color(0xFFEEF1FF);
  static const Color danger = Color(0xFFFB3B4E);
  static const Color dangerSoft = Color(0xFFFFEDEE);
  static const Color success = Color(0xFF13C28B);
  static const Color successSoft = Color(0xFFE6F9F2);
  static const Color warning = Color(0xFFFF9F1C);
  static const Color warningSoft = Color(0xFFFFF4E2);
  static const Color violet = Color(0xFF7C5CFC);
  static const Color violetSoft = Color(0xFFF0EBFF);

  static const Color surface = Color(0xFFFFFFFF);

  // Fon gradienti (#EAEEF7 → #F4F6FC)
  static const Color bgTop = Color(0xFFEAEEF7);
  static const Color bgBottom = Color(0xFFF4F6FC);

  // Geometriya
  static const double cardRadius = 22;
  static const double unreadBar = 3.5;

  // Soyalar
  static const List<BoxShadow> shadowSm = [
    BoxShadow(
      color: Color(0x0A101726), // rgba(16,23,38,.04)
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];
  static const List<BoxShadow> shadowMd = [
    BoxShadow(
      color: Color(0x12101726), // rgba(16,23,38,.07)
      blurRadius: 26,
      offset: Offset(0, 10),
    ),
  ];
}

/// Bitta kategoriyaning vizual kimligi.
@immutable
class NotifCategoryStyle {
  const NotifCategoryStyle({
    required this.icon,
    required this.accent,
    required this.soft,
  });

  /// Badge ichidagi ikona.
  final IconData icon;

  /// Aksent rang (ikona, unread bar/nuqta).
  final Color accent;

  /// Badge va unread fon uchun yumshoq tint.
  final Color soft;
}

/// Har bildirishnoma turi → o'ziga xos stil (data-driven). Reference'dagi
/// kategoriyalar (aloqa uzildi=danger, maktabga yetdi=location, yutuq,
/// quvvat kam=battery, ekran vaqti) shu yerda turlarga moslashtirilgan.
const Map<NotificationType, NotifCategoryStyle> kNotifCategoryStyles = {
  NotificationType.system: NotifCategoryStyle(
    icon: Icons.wifi_off_rounded,
    accent: NotifTokens.danger,
    soft: NotifTokens.dangerSoft,
  ),
  NotificationType.geoZone: NotifCategoryStyle(
    icon: AppIcons.mapPin,
    accent: NotifTokens.primary,
    soft: NotifTokens.primarySoft,
  ),
  NotificationType.achievement: NotifCategoryStyle(
    icon: AppIcons.trophy,
    accent: NotifTokens.warning,
    soft: NotifTokens.warningSoft,
  ),
  NotificationType.contest: NotifCategoryStyle(
    icon: Icons.workspace_premium_rounded,
    accent: NotifTokens.violet,
    soft: NotifTokens.violetSoft,
  ),
  NotificationType.schedule: NotifCategoryStyle(
    icon: Icons.hourglass_bottom_rounded,
    accent: NotifTokens.violet,
    soft: NotifTokens.violetSoft,
  ),
  NotificationType.parentRequest: NotifCategoryStyle(
    icon: AppIcons.profile,
    accent: NotifTokens.primary,
    soft: NotifTokens.primarySoft,
  ),
  NotificationType.voice: NotifCategoryStyle(
    icon: AppIcons.mic,
    accent: NotifTokens.violet,
    soft: NotifTokens.violetSoft,
  ),
  NotificationType.studyNudge: NotifCategoryStyle(
    icon: Icons.menu_book_rounded,
    accent: NotifTokens.primary,
    soft: NotifTokens.primarySoft,
  ),
  NotificationType.healthNudge: NotifCategoryStyle(
    icon: Icons.directions_run_rounded,
    accent: NotifTokens.success,
    soft: NotifTokens.successSoft,
  ),
  NotificationType.contentReminder: NotifCategoryStyle(
    icon: Icons.movie_rounded,
    accent: NotifTokens.violet,
    soft: NotifTokens.violetSoft,
  ),
};

/// Tur uchun stil (xaritada bo'lmasa — neytral primary fallback).
NotifCategoryStyle notifStyleFor(NotificationType type) {
  return kNotifCategoryStyles[type] ??
      const NotifCategoryStyle(
        icon: Icons.notifications_rounded,
        accent: NotifTokens.primary,
        soft: NotifTokens.primarySoft,
      );
}
