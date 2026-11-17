// A10 · Akkaunt tanlash va A12 · Sessiya yopildi.
//
// A10: umumiy qurilmada bir nechta bola — har birining ma'lumoti alohida;
// tanlansa faqat parol yoki qurilma kaliti so'raladi. A12: tiklash yoki
// ruxsat o'zgarganda shu qurilmadagi sessiya yopilgani haqida — tizim
// hodisasidan ochiladi, orqaga tugmasi yo'q.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/kirish/data/account_registry.dart';
import 'package:farzandim_child/growth/kirish/data/account_scope.dart';
import 'package:farzandim_child/growth/kirish/switch_account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
}

class KirishAccountsScreen extends ConsumerWidget {
  const KirishAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(accountRegistryProvider);
    final accounts = [...registry.accounts]
      ..sort((a, b) {
        if (a.owner != b.owner) return a.owner ? -1 : 1;
        return (b.lastUsedAt ?? DateTime(2000)).compareTo(
          a.lastUsedAt ?? DateTime(2000),
        );
      });
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.blue,
        top: GTopBar(
          leading: context.canPop()
              ? GTopBar.back(
                  label: 'g5.common.back'.tr(),
                  onPressed: () => context.pop(),
                )
              : null,
          title: 'g5.kirish.accounts.title'.tr(),
        ),
        children: [
          GList(
            children: [
              for (final a in accounts)
                GListItem(
                  leading: GAvatar(
                    initials: _initials(a.name),
                    hue: a.owner ? GHue.blue : GHue.teal,
                    size: 44,
                  ),
                  title: a.name,
                  subtitle: [
                    if (a.className != null) a.className!,
                    if (a.owner) 'g5.kirish.accounts.thisDevice'.tr(),
                  ].join(' · '),
                  trailing: a.deviceKey && !a.owner
                      ? GChip(
                          label: 'g5.kirish.accounts.withKey'.tr(),
                          kind: GChipKind.info,
                          icon: GIcons.fingerprint,
                        )
                      : null,
                  onTap: () => switchToAccount(context, ref, a),
                ),
              GListItem(
                leading: const GTile(
                  icon: GIcons.userPlus,
                  hue: GHue.slate,
                  size: 44,
                ),
                title: 'g5.kirish.accounts.other'.tr(),
                onTap: () => context.push(GrowthV5Routes.kirishLogin),
              ),
            ],
          ),
          GNote(
            text: 'g5.kirish.accounts.note'.tr(),
            kind: GNoteKind.plain,
            icon: GIcons.lockKey,
          ),
        ],
      ),
    );
  }
}

class KirishClosedScreen extends ConsumerWidget {
  const KirishClosedScreen({super.key});

  void _again(BuildContext context, WidgetRef ref) {
    ref.read(accountRegistryProvider).clearClosedNotice();
    ref.read(pairingStateProvider.notifier).clearSessionEndedNotice();
    context.go(GrowthV5Routes.kirishLogin);
  }

  void _accounts(BuildContext context, WidgetRef ref) {
    ref.read(accountRegistryProvider).clearClosedNotice();
    context.go(GrowthV5Routes.kirishAccounts);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(accountRegistryProvider);
    final reason = registry.closedNotice;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: GColors.bg,
        body: GScreen(
          theme: GBgTheme.rose,
          dock: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GButton(
                label: 'g5.kirish.closed.again'.tr(),
                icon: GIcons.signIn,
                onPressed: () => _again(context, ref),
              ),
              // Qurilmada boshqa akkauntlar qolgan — ulardan biriga o'tish.
              if (registry.accounts.isNotEmpty) ...[
                const SizedBox(height: 8),
                GButton(
                  label: 'g5.kirish.closed.accounts'.tr(),
                  kind: GButtonKind.ghost,
                  size: GButtonSize.second,
                  onPressed: () => _accounts(context, ref),
                ),
              ],
            ],
          ),
          children: [
            const SizedBox(height: 32),
            const Center(
              child: GTile(icon: GIcons.doorOpen, hue: GHue.rose, size: 72),
            ),
            Semantics(
              header: true,
              child: Text(
                'g5.kirish.closed.title'.tr(),
                textAlign: TextAlign.center,
                style: GText.h2,
              ),
            ),
            Text(
              'g5.kirish.closed.${(reason ?? SessionClosedReason.other).name}'
                  .tr(),
              textAlign: TextAlign.center,
              style: GText.body,
            ),
            GNote(
              text: 'g5.kirish.closed.wiped'.tr(),
              kind: GNoteKind.plain,
              icon: GIcons.shieldCheck,
            ),
          ],
        ),
      ),
    );
  }
}
