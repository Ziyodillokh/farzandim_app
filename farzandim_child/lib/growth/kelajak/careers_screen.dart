// K03 · Kasblarni o'rganish: bitta kengaytirilgan kasb kartasi — kundalik
// ish, kerakli fanlar, uyda sinab ko'radigan kichik mashg'ulot. Soha
// Kelajak profilidan tavsiya qilinadi, lekin bu faqat tavsiya — istalgan
// boshqa sohani tanlash mumkin.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_providers.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/growth/common/subject_look.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/kelajak/kelajak_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class KelajakCareersScreen extends ConsumerStatefulWidget {
  const KelajakCareersScreen({super.key});

  @override
  ConsumerState<KelajakCareersScreen> createState() =>
      _KelajakCareersScreenState();
}

class _KelajakCareersScreenState extends ConsumerState<KelajakCareersScreen> {
  CareerField? _picked;

  @override
  Widget build(BuildContext context) {
    final top =
        ref
            .watch(kelajakOverviewProvider)
            .valueOrNull
            ?.profile
            ?.interests
            ?.top ??
        const <String>[];
    final recommended = CareerField.recommended(top);
    final field = _picked ?? recommended;
    final subject = field.subjectFor(ref.watch(learningProfileProvider)?.grade);
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.gold,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.kelajak.careers.title'.tr(),
        ),
        dock: GButton(
          label: 'g5.kelajak.careers.goal'.tr(),
          icon: GIcons.target,
          onPressed: () =>
              context.push(GrowthV5Routes.kelajakGoal, extra: subject),
        ),
        children: [
          GGlass(
            glowHue: field.hue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    GTile(icon: field.icon, hue: field.hue, size: 52),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              '${field.key}.title'.tr(),
                              style: GText.h3,
                            ),
                          ),
                          if (field == recommended)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: GChip(
                                label: 'g5.kelajak.careers.forYou'.tr(),
                                kind: GChipKind.info,
                                icon: GIcons.sparkle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('${field.key}.does'.tr(), style: GText.body),
                const SizedBox(height: 14),
                Text(
                  'g5.kelajak.careers.subjects'.tr(),
                  style: GText.itemTitle,
                ),
                const SizedBox(height: 4),
                Text('${field.key}.subjects'.tr(), style: GText.body),
                const SizedBox(height: 14),
                GNote(
                  text: '${field.key}.tryIt'.tr(),
                  kind: GNoteKind.plain,
                  icon: GIcons.lightbulb,
                ),
                const SizedBox(height: 12),
                GButton(
                  label: 'g5.kelajak.careers.try'.tr(
                    namedArgs: {'subject': subject.label},
                  ),
                  kind: GButtonKind.ghost,
                  size: GButtonSize.md,
                  icon: subject.gIcon,
                  onPressed: () =>
                      context.push(GrowthV5Routes.practice(subject)),
                ),
              ],
            ),
          ),
          GSection(
            title: 'g5.kelajak.careers.other'.tr(),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in CareerField.values)
                  if (f != field)
                    GPressable(
                      onTap: () => setState(() => _picked = f),
                      semanticLabel: '${f.key}.title'.tr(),
                      child: GChip(label: '${f.key}.title'.tr(), icon: f.icon),
                    ),
              ],
            ),
          ),
          Text('g5.kelajak.careers.note'.tr(), style: GText.caption),
        ],
      ),
    );
  }
}
