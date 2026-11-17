// I01 · Men: shaxsiy profil markazi — ism, sinf va maktab, DON darajasi,
// seriya, shaxsiy o'sish, qiziqishlar, oila, ruxsatlar va sozlamalar. Bola
// faqat o'z akkauntini ko'radi; boshqa bolalar bilan solishtirish yo'q.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:farzandim_child/growth/men/data/men_device.dart';
import 'package:farzandim_child/growth/men/data/men_models.dart';
import 'package:farzandim_child/growth/men/lock/app_lock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(pairingStateProvider.select((s) => s.childName));
    final school = ref.watch(schoolTodayProvider).valueOrNull;
    final game = ref.watch(backendGamificationProvider).valueOrNull;
    final permissions = ref.watch(myPermissionsProvider).valueOrNull;
    final don = game?.don ?? 0;
    final level = donLevel(don);
    final lang = 'g5.men.settings.langNames.${context.locale.languageCode}'
        .tr();
    return GScreen(
      theme: GBgTheme.blue,
      top: GTopBar(
        title: 'g5.men.title'.tr(),
        actions: [
          GIconButton(
            icon: GIcons.gearSix,
            label: 'g5.men.hub.settings'.tr(),
            onPressed: () => GrowthLinks.meSettings(context),
          ),
        ],
      ),
      onRefresh: () async => ref
        ..invalidate(backendGamificationProvider)
        ..invalidate(myPermissionsProvider),
      children: [
        GGlass(
          kind: GGlassKind.feat,
          glowHue: GHue.blue,
          child: Row(
            children: [
              GAvatar(initials: _initials(name), hue: GHue.blue, size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name ?? '', style: GText.h3),
                    const SizedBox(height: 2),
                    Text(
                      school == null
                          ? 'g5.men.hub.noSchool'.tr()
                          : 'g5.men.hub.classLine'.tr(
                              namedArgs: {
                                'class': school.className ?? '',
                                'school': school.schoolName,
                              },
                            ),
                      style: GText.caption,
                    ),
                    const SizedBox(height: 10),
                    GPressable(
                      onTap: () => GrowthLinks.level(context),
                      semanticLabel: 'g5.men.hub.level'.tr(
                        namedArgs: {'n': '$level'},
                      ),
                      child: GChip(
                        label: 'g5.men.hub.level'.tr(
                          namedArgs: {'n': '$level'},
                        ),
                        kind: GChipKind.info,
                        icon: GIcons.medal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Stat(
                  icon: GIcons.fire,
                  hue: GHue.orange,
                  label: 'g5.men.hub.streak'.tr(),
                  value: 'g5.men.hub.days'.tr(
                    namedArgs: {'n': '${game?.streak ?? 0}'},
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Stat(
                  icon: GIcons.target,
                  hue: GHue.slate,
                  label: 'g5.men.hub.weeklyGoal'.tr(),
                  value: 'g5.men.hub.soon'.tr(),
                ),
              ),
            ],
          ),
        ),
        GList(
          children: [
            GListItem(
              leading: const GTile(
                icon: GIcons.chartLineUp,
                hue: GHue.green,
                size: 40,
              ),
              title: 'g5.men.hub.growth'.tr(),
              subtitle: 'g5.men.hub.growthSub'.tr(),
              onTap: () => GrowthLinks.meGrowth(context),
            ),
            GListItem(
              leading: const GTile(
                icon: GIcons.lightbulb,
                hue: GHue.gold,
                size: 40,
              ),
              title: 'g5.men.hub.interests'.tr(),
              subtitle: 'g5.men.hub.interestsSub'.tr(),
              onTap: () => GrowthLinks.interests(context),
            ),
            GListItem(
              leading: const GTile(
                icon: GIcons.users,
                hue: GHue.rose,
                size: 40,
              ),
              title: 'g5.men.hub.family'.tr(),
              subtitle: 'g5.men.hub.familySub'.tr(),
              onTap: () => GrowthLinks.family(context),
            ),
            GListItem(
              leading: const GTile(
                icon: GIcons.shieldCheck,
                hue: GHue.sky,
                size: 40,
              ),
              title: 'g5.men.hub.permissions'.tr(),
              subtitle: permissions == null
                  ? null
                  : 'g5.men.hub.permissionsSub'.tr(
                      namedArgs: {'count': '${permissions.enabledCount}'},
                    ),
              onTap: () => GrowthLinks.mePermissions(context),
            ),
            ListenableBuilder(
              listenable: ref.watch(appLockProvider),
              builder: (context, _) => GListItem(
                leading: const GTile(
                  icon: GIcons.lockKey,
                  hue: GHue.blue,
                  size: 40,
                ),
                title: 'g5.lock.hub.title'.tr(),
                subtitle: ref.read(appLockProvider).isEnabled
                    ? 'g5.lock.hub.on'.tr()
                    : 'g5.lock.hub.off'.tr(),
                onTap: () => GrowthLinks.meLock(context),
              ),
            ),
            GListItem(
              leading: const GTile(
                icon: GIcons.gear,
                hue: GHue.slate,
                size: 40,
              ),
              title: 'g5.men.hub.settings'.tr(),
              subtitle: 'g5.men.hub.settingsSub'.tr(namedArgs: {'lang': lang}),
              onTap: () => GrowthLinks.meSettings(context),
            ),
          ],
        ),
        GNote(
          text: 'g5.men.hub.ownOnly'.tr(),
          kind: GNoteKind.plain,
          icon: GIcons.lockKey,
        ),
      ],
    );
  }

  String _initials(String? name) {
    final parts = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.hue,
    required this.label,
    required this.value,
  });

  final GIconData icon;
  final GHue hue;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => GGlass(
    padding: const EdgeInsets.all(14),
    child: MergeSemantics(
      child: Row(
        children: [
          GTile(icon: icon, hue: hue, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GText.caption),
                Text(value, style: GText.itemTitle),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
