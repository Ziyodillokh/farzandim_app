// F01 · Oila va aloqa: yuqorida oson topiladigan SOS, tasdiqlangan oila
// kontakti (shu akkauntning ota-onasi) va xabar yozish. Ekran vaqti uchun
// qo'shimcha vaqt so'rash — faqat qurilma egasida (cheklovlar uniki).
// Ovozli va video qo'ng'iroq (F05) — alohida bosqich, bu yerda yo'q.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/account/presentation/providers/child_repository_provider.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/kirish/data/account_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paired = ref.watch(pairingStateProvider).childId != null;
    final parentName = ref.watch(parentNameProvider).valueOrNull;
    final owner = ref.watch(activeGuestProvider) == null;
    final name = (parentName == null || parentName.trim().isEmpty)
        ? 'g5.oila.parent'.tr()
        : parentName.trim();
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.rose,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.oila.title'.tr(),
        ),
        children: [
          GPressable(
            onTap: () => context.push(GrowthV5Routes.familySos),
            semanticLabel: 'g5.oila.sos.title'.tr(),
            child: GGlass(
              glowHue: GHue.rose,
              child: Row(
                children: [
                  const GTile(icon: GIcons.siren, hue: GHue.rose, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('g5.oila.sos.title'.tr(), style: GText.h3),
                        const SizedBox(height: 2),
                        Text('g5.oila.sosHint'.tr(), style: GText.caption),
                      ],
                    ),
                  ),
                  const GIcon(GIcons.caretRight, size: 18),
                ],
              ),
            ),
          ),
          if (!paired)
            GNote(
              text: 'g5.oila.noFamily'.tr(),
              kind: GNoteKind.warn,
              icon: GIcons.users,
            )
          else
            GGlass(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      GAvatar(
                        initials: name.characters.first.toUpperCase(),
                        hue: GHue.rose,
                        size: 48,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: GText.itemTitle),
                            const SizedBox(height: 2),
                            Text('g5.oila.approved'.tr(), style: GText.caption),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GButton(
                    label: 'g5.oila.write'.tr(),
                    icon: GIcons.chatCircleText,
                    size: GButtonSize.md,
                    onPressed: () => context.push('/voice-chat'),
                  ),
                ],
              ),
            ),
          if (paired && owner)
            GList(
              children: [
                GListItem(
                  leading: const GTile(
                    icon: GIcons.hourglassMedium,
                    hue: GHue.gold,
                    size: 44,
                  ),
                  title: 'g5.oila.screenTime'.tr(),
                  subtitle: 'g5.oila.extra.ask'.tr(),
                  onTap: () => context.push(GrowthV5Routes.familyExtraTime),
                ),
              ],
            ),
          GNote(
            text: 'g5.oila.onlyApproved'.tr(),
            kind: GNoteKind.plain,
            icon: GIcons.shieldCheck,
          ),
        ],
      ),
    );
  }
}
