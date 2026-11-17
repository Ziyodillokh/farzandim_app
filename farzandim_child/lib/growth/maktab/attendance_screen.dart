// M04 · Davomat: bugungi kirish/chiqish vaqtlari, qayerdan qayd etilgani va
// maktab kunni tasdiqlaganmi. Kirish/chiqish — maktab kioskidagi o'zgaruvchan
// QR'ni skanerlash orqali (mavjud xavfsiz tizim; statik QR-karta ishlatilmaydi).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:farzandim_child/growth/maktab/data/school_v5_repository.dart';
import 'package:farzandim_child/growth/maktab/school_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(learningClockProvider)();
    final today = ref.watch(schoolTodayProvider).valueOrNull;
    final month = ref
        .watch(schoolAttendanceMonthProvider(DateTime(now.year, now.month)))
        .valueOrNull;
    final day = month?.dayOf(now);
    final record = today?.record;
    final source = record == null ? '' : attendanceSourceLine(record.source);
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.teal,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.school.attendance.title'.tr(),
          subtitle: today?.className,
        ),
        dock: GButton(
          label: 'g5.school.attendance.scan'.tr(),
          icon: GIcons.qrCode,
          onPressed: () => GrowthLinks.schoolCheckIn(context),
        ),
        onRefresh: () async {
          ref
            ..invalidate(schoolTodayProvider)
            ..invalidate(schoolAttendanceMonthProvider);
        },
        children: [
          GSection(
            title: 'g5.school.attendance.today'.tr(),
            child: GGlass(
              kind: GGlassKind.feat,
              glowHue: GHue.green,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _Time(
                          icon: GIcons.signIn,
                          label: 'g5.school.attendance.in'.tr(),
                          value: record?.inAt,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Time(
                          icon: GIcons.signOut,
                          label: 'g5.school.attendance.out'.tr(),
                          value: record?.outAt,
                        ),
                      ),
                    ],
                  ),
                  if (source.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(source, style: GText.caption),
                  ],
                  const SizedBox(height: 12),
                  if (today != null && !today.isSchoolDay)
                    GChip(label: 'g5.school.noSchoolDay'.tr())
                  else if (record == null)
                    GChip(label: 'g5.school.attendance.unknown'.tr())
                  else if (day?.confirmed == true)
                    GChip(
                      label: 'g5.school.dayConfirmed'.tr(),
                      kind: GChipKind.ok,
                      icon: GIcons.sealCheck,
                    )
                  else
                    GChip(
                      label: 'g5.school.dayNotConfirmed'.tr(),
                      kind: GChipKind.warn,
                      icon: GIcons.hourglassMedium,
                    ),
                ],
              ),
            ),
          ),
          GNote(
            text: 'g5.school.attendance.scanHint'.tr(),
            icon: GIcons.qrCode,
          ),
          GList(
            children: [
              GListItem(
                leading: const GTile(
                  icon: GIcons.calendarDots,
                  hue: GHue.sky,
                  size: 40,
                ),
                title: 'g5.school.attendance.history'.tr(),
                onTap: () => GrowthLinks.attendanceHistory(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Time extends StatelessWidget {
  const _Time({required this.icon, required this.label, required this.value});

  final GIconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        children: [
          GTile(icon: icon, hue: GHue.green, size: 40),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GText.caption),
              Text(value ?? '—', style: GText.display(18)),
            ],
          ),
        ],
      ),
    );
  }
}
