// "Maktabim" — maktab topshiriqlari: maktab sinfga bergan Parvoz
// materiallari (fan testi, audiokitob, video) muddati bilan. Bajarilmaganlar
// birinchi; test shu fandan kunlik test yechilganda "Bajarildi" bo'ladi.
// Topshiriq bo'lmasa bo'lim ko'rinmaydi; yuklanmasa — qisqa xato va
// "Qayta urinish".

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/utils/tashkent_time.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/subject_icon.dart';
import 'package:farzandim_child/features/school/domain/school_assignment.dart';
import 'package:farzandim_child/features/school/presentation/assignment_display.dart';
import 'package:farzandim_child/features/school/presentation/assignment_navigation.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/features/school/presentation/school_style.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

class SchoolAssignmentsSection extends ConsumerWidget {
  const SchoolAssignmentsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(schoolAssignmentsProvider);
    // Yangilanayotganda / oflaynda oxirgi ma'lum ro'yxat ko'rinadi.
    final items = state.valueOrNull ?? const <SchoolAssignment>[];
    if (items.isEmpty) {
      if (!state.hasError || state.isLoading) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: kSchoolSectionGap),
        child: SchoolSectionError(
          onRetry: () => ref.invalidate(schoolAssignmentsProvider),
        ),
      );
    }
    final pending = pendingAssignmentCount(items);
    final today = tashkentNow();
    return Padding(
      padding: const EdgeInsets.only(top: kSchoolSectionGap),
      child: SchoolSectionCard(
        icon: SolarIconsBold.notebookBookmark,
        color: HomeColors.amber,
        title: 'school.assignments.title'.tr(),
        trailing: pending > 0 ? SchoolCountBadge(count: pending) : null,
        children: [
          const SizedBox(height: 8),
          Text(
            'school.assignments.hubHint'.tr(),
            style: homeText(13, color: HomeColors.textDim, height: 1.4),
          ),
          for (final item in assignmentsForDisplay(items)) ...[
            const SizedBox(height: 10),
            _AssignmentTile(
              key: ValueKey(item.id),
              assignment: item,
              today: today,
            ),
          ],
        ],
      ),
    );
  }
}

class _AssignmentTile extends ConsumerStatefulWidget {
  const _AssignmentTile({
    super.key,
    required this.assignment,
    required this.today,
  });

  final SchoolAssignment assignment;

  /// Toshkent kalendar kuni (muddat qatori uchun).
  final DateTime today;

  @override
  ConsumerState<_AssignmentTile> createState() => _AssignmentTileState();
}

class _AssignmentTileState extends ConsumerState<_AssignmentTile> {
  /// Audiokitob ro'yxati yuklanmoqda — takroriy bosish e'tiborsiz.
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await openSchoolAssignment(context, ref, widget.assignment);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assignment = widget.assignment;
    final canOpen = assignmentTargetOf(assignment) is! AssignmentOpensNothing;
    final state = assignmentDueState(assignment, widget.today);
    final dueText = assignmentDueText(assignment, widget.today);
    final note = assignment.note.trim();
    return Semantics(
      button: canOpen,
      child: Material(
        color: HomeColors.tile,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: state == AssignmentDueState.done
                ? SchoolColors.accent.withValues(alpha: 0.35)
                : HomeColors.tileBorder,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: canOpen ? _open : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
            child: Row(
              children: [
                _AssignmentIcon(assignment: assignment),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        assignmentKindLabelKey(assignment.kind).tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: homeText(
                          12,
                          weight: FontWeight.w700,
                          color: HomeColors.amber,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        schoolAssignmentTitle(assignment),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: homeText(
                          15,
                          weight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      if (dueText.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          dueText,
                          style: homeText(
                            12.5,
                            weight: _isHighlighted(state)
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: _dueColor(state),
                            height: 1.3,
                          ),
                        ),
                      ],
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          note,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: homeText(
                            12.5,
                            color: HomeColors.textDim,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                _Trailing(state: state, isOpening: _opening, canOpen: canOpen),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

bool _isHighlighted(AssignmentDueState state) =>
    state != AssignmentDueState.upcoming;

Color _dueColor(AssignmentDueState state) => switch (state) {
  AssignmentDueState.done => SchoolColors.accent,
  AssignmentDueState.overdue => SchoolColors.absent,
  AssignmentDueState.today || AssignmentDueState.tomorrow => HomeColors.amber,
  AssignmentDueState.upcoming ||
  AssignmentDueState.noDate => HomeColors.textDim,
};

/// Test — fan belgisi; boshqa material — tur belgisi.
class _AssignmentIcon extends StatelessWidget {
  const _AssignmentIcon({required this.assignment});

  final SchoolAssignment assignment;

  static const _size = 42.0;

  @override
  Widget build(BuildContext context) {
    final subject = assignment.subject;
    if (assignment.kind == SchoolAssignmentKind.test && subject != null) {
      return SubjectIcon(subject: subject, size: _size);
    }
    return SchoolIconSquare(
      icon: assignmentKindIcon(assignment.kind),
      color: HomeColors.amber,
      size: _size,
    );
  }
}

class _Trailing extends StatelessWidget {
  const _Trailing({
    required this.state,
    required this.isOpening,
    required this.canOpen,
  });

  final AssignmentDueState state;
  final bool isOpening;
  final bool canOpen;

  @override
  Widget build(BuildContext context) {
    if (isOpening) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: Padding(
          padding: EdgeInsets.all(3),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: HomeColors.blue,
          ),
        ),
      );
    }
    if (state == AssignmentDueState.done) {
      return const Icon(
        SolarIconsBold.checkCircle,
        size: 22,
        color: SchoolColors.accent,
      );
    }
    if (!canOpen) return const SizedBox(width: 24);
    return const Icon(
      Icons.chevron_right_rounded,
      size: 24,
      color: HomeColors.chevron,
    );
  }
}
