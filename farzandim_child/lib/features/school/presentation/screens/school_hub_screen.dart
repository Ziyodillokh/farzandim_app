// ─────────────────────────────────────────────────────────────────────
// SchoolHubScreen — "Maktabim" (`/school`)
// ─────────────────────────────────────────────────────────────────────
//
// Maktabga bog'langan bolaning maktab bo'limlari: bugungi davomat va
// "QR orqali kirish", maktab topshiriqlari (bo'lsa), psixologik testlar
// (bo'lsa), "Bola ovozi" so'rovnomasi (bo'lsa) va psixolog bilan gaplashish
// (sinfga biriktirilgan bo'lsa). Maktab ota-ona ilovasi
// orqali ulanadi — ulanmagan bo'lsa (yoki server funksiyani hali bilmasa)
// tushuntirish ko'rinadi. Yangi ma'lumot push'siz keladi: pastga tortib
// yangilanadi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/design_scale.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/features/school/domain/attendance_models.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/features/school/presentation/widgets/attendance_section.dart';
import 'package:farzandim_child/features/school/presentation/widgets/care_hub_cards.dart';
import 'package:farzandim_child/features/school/presentation/widgets/psych_assignments_section.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_assignments_section.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_message_view.dart';
import 'package:farzandim_child/features/tests/presentation/widgets/inner_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

class SchoolHubScreen extends ConsumerWidget {
  const SchoolHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayState = ref.watch(schoolTodayProvider);
    // Yangilanayotganda / oflaynda oxirgi ma'lum holat ko'rinadi.
    final today = todayState.valueOrNull;
    final schoolName = today?.schoolName.trim() ?? '';

    return Scaffold(
      backgroundColor: HomeColors.bg,
      body: DesignScale(
        child: Builder(
          builder: (context) {
            final insets = MediaQuery.paddingOf(context);
            return RefreshIndicator(
              color: HomeColors.primary,
              backgroundColor: HomeColors.card,
              edgeOffset: insets.top,
              onRefresh: () => refreshSchool(ref),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16,
                  growthTopInset(context),
                  16,
                  insets.bottom + 24,
                ),
                children: [
                  InnerPageHeader(
                    title: 'school.hub.title'.tr(),
                    subtitle: schoolName.isEmpty ? null : schoolName,
                    fallbackRoute: '/dashboard',
                  ),
                  const SizedBox(height: 16),
                  if (today != null) ...[
                    AttendanceSection(today: today),
                    const SchoolAssignmentsSection(),
                    const PsychAssignmentsSection(),
                    // Sinfga biriktirilmagan o'quvchini server so'rovnoma va
                    // psixologga qabul qilmaydi — bola xabarni yozib bo'lgach
                    // rad etilmasin (davomat qismida "sinf belgilanmagan").
                    if (today.className != null) ...[
                      const CareSurveyCard(),
                      const CareHelpCard(),
                    ],
                  ] else
                    _HubStatus(state: todayState),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Bugungi holat hali yo'q: yuklanmoqda, xato yoki maktab ulanmagan.
class _HubStatus extends ConsumerWidget {
  const _HubStatus({required this.state});

  final AsyncValue<SchoolToday?> state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 96),
        child: Center(
          child: CircularProgressIndicator(color: HomeColors.primary),
        ),
      );
    }
    final error = state.error;
    if (error != null) {
      final code = error is SchoolException
          ? error.code
          : SchoolErrorCode.unknown;
      return SchoolMessageView(
        icon: code == SchoolErrorCode.network
            ? Icons.wifi_off_rounded
            : SolarIconsOutline.dangerCircle,
        message: code.messageKey.tr(),
        actionLabel: 'common.retry'.tr(),
        onAction: () => ref.invalidate(schoolTodayProvider),
      );
    }
    return SchoolMessageView(
      icon: SolarIconsOutline.squareAcademicCap,
      iconColor: HomeColors.blue,
      title: 'school.hub.notLinkedTitle'.tr(),
      message: 'school.hub.notLinkedBody'.tr(),
    );
  }
}
