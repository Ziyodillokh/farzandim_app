// U01b · Barcha fanlar: sinfda o'tiladigan hamma fanlar kartalari; har biri
// o'z bilim xaritasini (U02) ochadi. O'quvchi tanlagan fanlar belgilanadi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/growth/common/subject_look.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:farzandim_child/growth/oqish/learn/subject_lists.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AllSubjectsScreen extends ConsumerWidget {
  const AllSubjectsScreen({super.key});

  static const _columns = 2;
  static const _gap = 12.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(learningProfileProvider);
    final subjects = profile == null
        ? kSubjectOrder
        : subjectsForGrade(profile.grade);
    final chosen = profile?.subjects ?? const <Subject>[];
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.learn.allSubjects'.tr(),
          subtitle: profile == null
              ? null
              : 'g5.learn.allSubjectsSubtitle'.tr(
                  namedArgs: {
                    'grade': '${profile.grade}',
                    'count': '${subjects.length}',
                  },
                ),
        ),
        children: [
          for (var i = 0; i < subjects.length; i += _columns)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = i; j < i + _columns; j++) ...[
                    if (j > i) const SizedBox(width: _gap),
                    Expanded(
                      child: j < subjects.length
                          ? _SubjectCard(
                              subject: subjects[j],
                              isChosen: chosen.contains(subjects[j]),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.subject, required this.isChosen});

  final Subject subject;
  final bool isChosen;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: GPressable(
        onTap: () => GrowthLinks.subjectMap(context, subject),
        semanticLabel: 'g5.learn.knowledgeMapA11y'.tr(
          namedArgs: {'subject': subject.label},
        ),
        pressedScale: .98,
        child: GGlass(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  subjectTile(subject, size: 44),
                  const Spacer(),
                  if (isChosen)
                    Semantics(
                      label: 'g5.learn.mySubject'.tr(),
                      child: const GIcon(
                        GIcons.sealCheck,
                        size: 22,
                        color: GColors.success,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                subject.label,
                style: GText.onest(15.5, weight: FontWeight.w700, height: 1.3),
              ),
              const SizedBox(height: 3),
              Text(
                'g5.learn.knowledgeMap'.tr(),
                style: GText.onest(
                  12.5,
                  color: GColors.textMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
