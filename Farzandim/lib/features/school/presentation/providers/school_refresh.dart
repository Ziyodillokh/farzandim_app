// Maktab ma'lumotlarini qayta yuklash — bitta joyda: pull-to-refresh,
// ilovaga qaytish (resume) va maktab push'lari.

import 'package:farzandim/features/growth/presentation/providers/growth_providers.dart';
import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:farzandim/features/school/presentation/providers/school_announcement_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_attendance_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_early_exit_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_payment_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// [invalidate] — `ref.invalidate` (WidgetRef, Ref yoki ProviderContainer).
/// Ro'yxatlar yangilanayotganda oldingi qiymat saqlanadi (karta
/// miltillamaydi); davomat (barcha o'quvchi va oylar), o'qilmaganlar soni,
/// erta ketish, to'lovlar va so'rovlar qayta so'raladi. Ochiq e'lonlar
/// ekrani yuklangan sahifalarini yo'qotmasdan yangilanadi.
void invalidateSchoolData(void Function(ProviderOrFamily provider) invalidate) {
  invalidate(schoolLinksProvider);
  invalidate(monthAttendanceProvider);
  invalidate(schoolUnreadCountProvider);
  invalidate(schoolAnnouncementsRefreshSignal);
  invalidate(schoolEarlyExitsProvider);
  invalidate(schoolPaymentsProvider);
  invalidate(schoolVerificationsProvider);
}

/// Push turi bo'yicha eskirgan provayderlar (ilova ochiq turganda kelgan
/// push ekrandagi ro'yxatni yangilaydi). Yopiq ekranlarniki qayta
/// yaratilmaydi — `invalidate` faqat tirik provayderga ta'sir qiladi.
List<ProviderOrFamily> schoolProvidersForPush(NotificationType type) =>
    switch (type) {
      NotificationType.schoolAttendance => [monthAttendanceProvider],
      // Tasdiqlangan erta ketish keyin davomatda "erta ketdi" bo'ladi.
      NotificationType.schoolEarlyExit => [
        schoolEarlyExitsProvider,
        monthAttendanceProvider,
      ],
      NotificationType.schoolAnnouncement => [
        schoolUnreadCountProvider,
        schoolAnnouncementsRefreshSignal,
      ],
      NotificationType.schoolPayment => [schoolPaymentsProvider],
      NotificationType.schoolVerification => [
        schoolPaymentsProvider,
        schoolVerificationsProvider,
      ],
      // Moslash yoki ulash holati o'zgargan bo'lishi mumkin.
      NotificationType.schoolMode => [schoolLinksProvider],
      NotificationType.learningReport => [
        growthSummaryProvider,
        growthResultsProvider,
      ],
      _ => const [],
    };

/// [notification] maktab/Growth push'i bo'lsa, tegishli ma'lumotni
/// qayta so'raydi; boshqa push'larda hech narsa qilmaydi.
void refreshForSchoolPush(
  AppNotification notification,
  void Function(ProviderOrFamily provider) invalidate,
) {
  schoolProvidersForPush(notification.type).forEach(invalidate);
}
