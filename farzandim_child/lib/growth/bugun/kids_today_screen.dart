// B03 · Bugun (1–4-sinf): katta matn, bitta katta vazifa kartasi, katta fan
// belgilari va katta «Boshlash» tugmasi. Pastki menyu va SOS B01 dagidek.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/growth/bugun/widgets/setup_reminders.dart';
import 'package:farzandim_child/growth/bugun/widgets/today_header.dart';
import 'package:farzandim_child/growth/common/learning_rules.dart';
import 'package:farzandim_child/growth/common/subject_look.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:flutter/material.dart';
import 'package:farzandim_child/growth/bugun/widgets/contact_tiles.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class KidsTodayView extends ConsumerWidget {
  const KidsTodayView({
    super.key,
    required this.profile,
    required this.onRefresh,
  });

  final LearningProfile profile;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = firstName(ref.watch(pairingStateProvider).childName);
    final className = ref.watch(schoolTodayProvider).valueOrNull?.className;
    final plan = ref.watch(dailyPlanProvider);
    return GScreen(
      theme: GBgTheme.gold,
      onRefresh: onRefresh,
      top: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _KidAvatar(
                initial: name.isEmpty
                    ? '★'
                    : name.characters.first.toUpperCase(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  className != null
                      ? 'g5.kids.className'.tr(namedArgs: {'name': className})
                      : 'g5.kids.grade'.tr(
                          namedArgs: {'grade': '${profile.grade}'},
                        ),
                  style: GText.onest(
                    15,
                    weight: FontWeight.w600,
                    color: GColors.textLabel,
                  ),
                ),
              ),
              SosPill(onTap: () => GrowthLinks.sos(context)),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text(
              name.isEmpty
                  ? 'g5.kids.resultTitleAnon'.tr()
                  : 'g5.kids.hello'.tr(namedArgs: {'name': name}),
              style: GText.display(28),
            ),
          ),
        ],
      ),
      children: [
        const SetupReminders(),
        _GameCard(plan: plan),
        const ContactTiles(),
      ],
    );
  }
}

class _KidAvatar extends StatelessWidget {
  const _KidAvatar({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 48,
        height: 48,
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            startAngle: 3.66,
            endAngle: 3.66 + 6.2832,
            colors: [
              Color(0xFFFFE08A),
              Color(0xFFF59E0B),
              Color(0xFF9A5B05),
              Color(0xFFFFE08A),
            ],
          ),
        ),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: Alignment(-.4, -.5),
              colors: [Color(0xFF22366B), Color(0xFF0A1228)],
            ),
          ),
          alignment: Alignment.center,
          child: Text(initial, style: GText.display(17)),
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.plan});

  final DailyPlan plan;

  @override
  Widget build(BuildContext context) {
    final next = plan.nextItem;
    final remaining = plan.items.where((i) => !i.isDone).length;
    return GGlass(
      kind: GGlassKind.feat,
      glowHue: GHue.gold,
      radius: 28,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'g5.kids.gameTitle'.tr(),
            style: GText.display(22).copyWith(height: 1.25),
          ),
          const SizedBox(height: 4),
          Text(
            next == null
                ? 'g5.kids.allDone'.tr()
                : 'g5.kids.remaining'.tr(namedArgs: {'count': '$remaining'}),
            style: GText.onest(16, color: GColors.textLabel, height: 1.4),
          ),
          const SizedBox(height: 16),
          for (final item in plan.items) ...[
            _KidRow(item: item, isNext: identical(item, next)),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 10),
          if (next != null)
            Semantics(
              label: 'g5.kids.startA11y'.tr(
                namedArgs: {'subject': next.subject.label},
              ),
              child: ExcludeSemantics(
                child: GButton(
                  label: 'g5.kids.start'.tr(),
                  size: GButtonSize.xl,
                  trailingIcon: GIcons.arrowRight,
                  onPressed: () => GrowthLinks.practice(context, next.subject),
                ),
              ),
            )
          else if (plan.items.isNotEmpty)
            GButton(
              label: 'g5.kids.playAgain'.tr(),
              size: GButtonSize.xl,
              kind: GButtonKind.ghost,
              onPressed: () =>
                  GrowthLinks.practice(context, plan.items.first.subject),
            ),
        ],
      ),
    );
  }
}

class _KidRow extends StatelessWidget {
  const _KidRow({required this.item, required this.isNext});

  final DailyPlanItem item;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final done = item.isDone;
    final Widget status;
    if (done) {
      status = Text(
        'g5.kids.done'.tr(),
        style: GText.onest(
          15,
          weight: FontWeight.w600,
          color: const Color(0xFF8BE8C0),
        ),
      );
    } else if (isNext) {
      status = GChip(label: 'g5.kids.next'.tr(), kind: GChipKind.info);
    } else {
      status = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GIcon(GIcons.timer, size: 16, color: Color(0xFFB4C0DA)),
          const SizedBox(width: 6),
          Text(
            'g5.kids.minutes'.tr(namedArgs: {'count': '$kMinutesPerSubject'}),
            style: GText.onest(
              15,
              weight: FontWeight.w600,
              color: const Color(0xFFB4C0DA),
            ),
          ),
        ],
      );
    }
    return MergeSemantics(
      child: Container(
        constraints: const BoxConstraints(minHeight: 88),
        padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: isNext ? const Color(0x1A4F86FF) : null,
          border: Border.all(
            color: isNext ? const Color(0x528CB4FF) : const Color(0x00FFFFFF),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Opacity(
                    opacity: done ? .75 : 1,
                    child: ClipOval(child: subjectTile(item.subject, size: 72)),
                  ),
                  if (done)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF34D399), Color(0xFF0E9F6E)],
                          ),
                          border: Border.all(
                            color: const Color(0xFF0B1226),
                            width: 3,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const GIcon(
                          GIcons.check,
                          size: 13,
                          color: GColors.white,
                          secondaryOpacity: 0,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.subject.label,
                    style: GText.onest(
                      19,
                      weight: FontWeight.w700,
                      color: done ? GColors.textLabel : GColors.text,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  status,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
