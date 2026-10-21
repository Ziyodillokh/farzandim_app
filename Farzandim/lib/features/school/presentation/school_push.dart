// ─────────────────────────────────────────────────────────────────────
// school_push — maktab va Growth push'lari qaysi ekranni ochadi
// ─────────────────────────────────────────────────────────────────────
//
// Sof mantiq (widget'siz, test qilinadi): push turi va data'sidan
// marshrut va bildirishnoma sahifasidagi tugma yorlig'i. `handleFcmTap`
// va `NotificationDetailScreen` shu yerdan oladi.
//
// | push                         | ekran                                  |
// |------------------------------|----------------------------------------|
// | school_attendance            | o'quvchi davomati, `date` oyi          |
// | school_early_exit            | erta ketish so'rovlari                 |
// | SCHOOL_ANNOUNCEMENT          | e'lonlar, shu e'lon ochilgan holda     |
// | SCHOOL_REMINDER              | — (faqat bildirishnoma matni)          |
// | SCHOOL_PAYMENT_REMINDER      | to'lovlar                              |
// | SCHOOL_VERIFICATION_ANSWERED | to'lovlar, javob berilgan so'rov       |
// | SCHOOL_MODE_REMIND           | maktab sahifasi, kerakli qadam varag'i |
// | learning_weekly              | bolaning Growth sahifasi               |

import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:flutter/foundation.dart';

/// Push'dagi e'lon matni — e'lon yuklangan sahifalarda topilmasa
/// ko'rsatiladi. Faqat ilova ichidan (`GoRouter` `extra`) beriladi: URL'da
/// emas, shuning uchun tashqi havola (deep link) uni soxtalashtira olmaydi.
@immutable
class SchoolAnnouncementPreview {
  const SchoolAnnouncementPreview({required this.title, required this.body});

  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      other is SchoolAnnouncementPreview &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(title, body);
}

/// Push'dan ochiladigan ekran va unga olib boruvchi tugma yorlig'i
/// (tarjima kaliti). [extra] — ekranga `GoRouter` `extra`si bilan beriladi.
@immutable
class SchoolPushTarget {
  const SchoolPushTarget({
    required this.route,
    required this.labelKey,
    this.extra,
  });

  final String route;
  final String labelKey;
  final SchoolAnnouncementPreview? extra;

  @override
  bool operator ==(Object other) =>
      other is SchoolPushTarget &&
      other.route == route &&
      other.labelKey == labelKey &&
      other.extra == extra;

  @override
  int get hashCode => Object.hash(route, labelKey, extra);

  @override
  String toString() => 'SchoolPushTarget($route, $labelKey)';
}

final RegExp _monthPrefix = RegExp(r'^(\d{4}-\d{2})-\d{2}$');

/// "2026-10-20" → "2026-10"; boshqa shakl → `null` (joriy oy ochiladi).
String? _monthOf(String? day) =>
    day == null ? null : _monthPrefix.firstMatch(day)?.group(1);

/// Maktab/Growth push'i uchun ekran; boshqa turlar, `SCHOOL_REMINDER`
/// (API yo'q) va bolasiz Growth push'i → `null` — bildirishnomaning
/// o'zi ko'rsatiladi.
SchoolPushTarget? schoolPushTarget(AppNotification n) {
  switch (n.type) {
    case NotificationType.schoolAttendance:
      final studentId = n.studentId;
      if (studentId == null) return _schoolHome;
      return SchoolPushTarget(
        route: AppRoutes.schoolAttendancePath(
          studentId,
          month: _monthOf(n.attendanceDate),
        ),
        labelKey: 'notifications.actions.openAttendance',
      );
    case NotificationType.schoolEarlyExit:
      return const SchoolPushTarget(
        route: AppRoutes.schoolEarlyExits,
        labelKey: 'notifications.actions.openEarlyExits',
      );
    case NotificationType.schoolAnnouncement:
      final announcementId = n.announcementId;
      return SchoolPushTarget(
        route: AppRoutes.schoolAnnouncementsPath(focus: announcementId),
        labelKey: 'notifications.actions.openAnnouncements',
        extra: announcementId == null
            ? null
            : SchoolAnnouncementPreview(title: n.title, body: n.message),
      );
    case NotificationType.schoolPayment:
      return const SchoolPushTarget(
        route: AppRoutes.schoolPayments,
        labelKey: 'notifications.actions.openPayments',
      );
    case NotificationType.schoolVerification:
      return SchoolPushTarget(
        route: AppRoutes.schoolPaymentsPath(verification: n.verificationId),
        labelKey: 'notifications.actions.openPayments',
      );
    case NotificationType.schoolMode:
      final studentId = n.studentId;
      if (studentId == null) return _schoolHome;
      return SchoolPushTarget(
        route: AppRoutes.schoolRemindPath(studentId),
        labelKey: 'notifications.actions.openSchool',
      );
    case NotificationType.learningReport:
      final childId = n.childId.trim();
      if (childId.isEmpty) return null;
      return SchoolPushTarget(
        route: AppRoutes.growthPath(childId),
        labelKey: 'notifications.actions.openGrowth',
      );
    case NotificationType.schoolReminder:
    case NotificationType.sos:
    case NotificationType.enterZone:
    case NotificationType.exitZone:
    case NotificationType.lowBattery:
    case NotificationType.appLimit:
    case NotificationType.scheduleStart:
    case NotificationType.scheduleReminder:
    case NotificationType.offline:
    case NotificationType.online:
    case NotificationType.pairRequest:
    case NotificationType.game:
    case NotificationType.unlockRequest:
    case NotificationType.permissionChanged:
    case NotificationType.sessionAccessRequest:
      return null;
  }
}

/// Push bosilganda ochiladigan yo'l (`null` — bildirishnoma sahifasi).
String? schoolRouteFor(AppNotification n) => schoolPushTarget(n)?.route;

/// O'quvchi aniq bo'lmasa — maktab bosh sahifasi.
const _schoolHome = SchoolPushTarget(
  route: AppRoutes.school,
  labelKey: 'notifications.actions.openSchool',
);
