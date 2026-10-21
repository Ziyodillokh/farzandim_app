// "Maktabim" — psixologik testlar: maktab psixologi sinfga yuborgan, hali
// yechilmagan testlar (yopilishi yaqini birinchi). Test bo'lmasa bo'lim
// ko'rinmaydi; yuklanmasa — qisqa xato va "Qayta urinish".

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/iq/presentation/iq_display.dart';
import 'package:farzandim_child/features/school/domain/psych_models.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/features/school/presentation/psych_display.dart';
import 'package:farzandim_child/features/school/presentation/school_navigation.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

class PsychAssignmentsSection extends ConsumerWidget {
  const PsychAssignmentsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(psychAssignmentsProvider);
    // Yangilanayotganda / oflaynda oxirgi ma'lum ro'yxat ko'rinadi.
    final items = state.valueOrNull ?? const <PsychAssignmentSummary>[];
    if (items.isEmpty) {
      if (!state.hasError || state.isLoading) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: kSchoolSectionGap),
        child: SchoolSectionError(
          onRetry: () => ref.invalidate(psychAssignmentsProvider),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: kSchoolSectionGap),
      child: SchoolSectionCard(
        icon: SolarIconsBold.clipboardList,
        color: HomeColors.blue,
        title: 'school.psych.title'.tr(),
        trailing: SchoolCountBadge(count: items.length),
        children: [
          const SizedBox(height: 8),
          Text(
            'school.psych.hubHint'.tr(),
            style: homeText(13, color: HomeColors.textDim, height: 1.4),
          ),
          for (final item in items) ...[
            const SizedBox(height: 10),
            _AssignmentTile(
              assignment: item,
              onTap: () async {
                if (item.kind != PsychKind.iq) {
                  openPsychTest(context, item.assignmentId);
                  return;
                }
                // Parvoz IQ — odatdagi IQ sahifasi; qaytgach ro'yxat yangilanadi
                // (yakunlangan bo'lsa topshiriq yo'qoladi).
                await context.push(IqRoutes.hub);
                ref.invalidate(psychAssignmentsProvider);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({required this.assignment, required this.onTap});

  final PsychAssignmentSummary assignment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kindLabel = psychKindLabelKey(assignment.kind).tr();
    final title = assignment.title.trim();
    final meta = psychMetaLine(assignment);
    return Semantics(
      button: true,
      child: Material(
        color: HomeColors.tile,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: HomeColors.tileBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
            child: Row(
              children: [
                SchoolIconSquare(
                  icon: psychKindIcon(assignment.kind),
                  color: HomeColors.blue,
                  size: 42,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        kindLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: homeText(
                          12,
                          weight: FontWeight.w700,
                          color: HomeColors.blue,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title.isEmpty ? kindLabel : title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: homeText(
                          15,
                          weight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          meta,
                          style: homeText(
                            12.5,
                            color: HomeColors.textDim,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 24,
                  color: HomeColors.chevron,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
