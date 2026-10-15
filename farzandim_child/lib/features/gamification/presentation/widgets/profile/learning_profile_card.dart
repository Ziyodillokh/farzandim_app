// Profil — "Fanlarim" kartasi: sinf, tanlangan fanlar va "O‘zgartirish".
//
// Holatlar (`learning_providers.dart`):
//   • profil bor            → sarlavha + sinf + fanlar chiplari
//   • profil yo'q (yuklangan) → "Fanlaringizni tanlang" + tugma
//   • yuklanmoqda           → bir xil balandlikdagi bo'sh karta

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/subject_icon.dart';
import 'package:farzandim_child/features/progress/presentation/widgets/progress_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

const _setupRoute = '/learn/setup';

/// Yuklanish paytidagi karta balandligi (fanlar kartasiga yaqin).
const _placeholderHeight = 112.0;

/// "O‘zgartirish" havolasi chegarasi — sarlavha va sinf uchun joy qolsin.
const _changeLinkMaxWidth = 160.0;

class LearningProfileCard extends ConsumerWidget {
  const LearningProfileCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(learningProfileProvider);
    if (profile != null) return _SubjectsCard(profile: profile);
    if (ref.watch(needsLearningSetupProvider)) return const _SetupCard();
    return Container(
      height: _placeholderHeight,
      decoration: homeCardDecoration(),
    );
  }
}

/// "7-sinf" — ko'k pill.
class GradeChip extends StatelessWidget {
  const GradeChip({super.key, required this.grade});

  final int grade;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: HomeColors.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: HomeColors.primary.withValues(alpha: 0.45)),
      ),
      child: Text(
        'profile.grade'.tr(namedArgs: {'grade': '$grade'}),
        maxLines: 1,
        style: homeText(12, weight: FontWeight.w700, color: HomeColors.blue),
      ),
    );
  }
}

class _SubjectsCard extends StatelessWidget {
  const _SubjectsCard({required this.profile});

  final LearningProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 6, 16),
      decoration: homeCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: FitText(
                        'profile.mySubjects'.tr(),
                        style: homeText(
                          19,
                          weight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: GradeChip(grade: profile.grade),
                      ),
                    ),
                  ],
                ),
              ),
              const _ChangeLink(),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in profile.subjects) _SubjectChip(subject: s),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "O‘zgartirish" — sinf/fanlarni qayta tanlash (bosish maydoni 44pt).
class _ChangeLink extends StatelessWidget {
  const _ChangeLink();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: () => context.push(_setupRoute),
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 44,
            maxWidth: _changeLinkMaxWidth,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  SolarIconsOutline.pen2,
                  size: 15,
                  color: progressLinkColor,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'profile.change'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: homeText(
                      13,
                      weight: FontWeight.w600,
                      color: progressLinkColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  const _SubjectChip({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
      decoration: BoxDecoration(
        color: HomeColors.tile,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: HomeColors.tileBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SubjectIcon(subject: subject, size: 28),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              subject.labelKey.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: homeText(13.5, weight: FontWeight.w600, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Profil hali tanlanmagan — sinf va fanlarni tanlashga taklif.
class _SetupCard extends StatelessWidget {
  const _SetupCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: HomeColors.testsBorder),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [HomeColors.testsTop, HomeColors.testsBottom],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: HomeColors.subjectSquare,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  SolarIconsBold.notebookBookmark,
                  size: 22,
                  color: HomeColors.subjectGlyph,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'profile.setupTitle'.tr(),
                      style: homeText(
                        17,
                        weight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'profile.setupHint'.tr(),
                      style: homeText(
                        13,
                        color: HomeColors.textDim,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HomeColors.primary,
              minimumSize: const Size.fromHeight(46),
              shape: const StadiumBorder(),
            ),
            onPressed: () => context.push(_setupRoute),
            child: Text(
              'profile.setupButton'.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: homeText(14.5, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
