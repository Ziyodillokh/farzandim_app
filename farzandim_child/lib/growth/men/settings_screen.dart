// I04 · Sozlamalar va akkaunt: til, matn o'lchami (butun v5 interfeysiga),
// qurilmalar, bildirishnomalar, ruxsatlar, maxfiylik va yordam. Akkauntni
// almashtirish va chiqish — 5-bosqichda (o'z login-paroli bilan) ochiladi.
// «Ovozli o'qish» — ilovada TTS yo'q, shuning uchun ko'rsatilmaydi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/kirish/data/account_scope.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_repository.dart';
import 'package:farzandim_child/growth/men/data/men_device.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _languages = ['uz', 'ru', 'en'];

class MeSettingsScreen extends ConsumerWidget {
  const MeSettingsScreen({super.key});

  Future<void> _pickLanguage(BuildContext context) async {
    final current = context.locale.languageCode;
    final picked = await showGSheet<String>(
      context,
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('g5.men.settings.language'.tr(), style: GText.h2),
          ),
          const SizedBox(height: 14),
          for (final code in _languages) ...[
            GOption(
              label: 'g5.men.settings.langNames.$code'.tr(),
              selected: code == current,
              onTap: () => Navigator.of(sheetContext).pop(code),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
    if (picked == null || picked == current || !context.mounted) return;
    HapticFeedback.selectionClick();
    await context.setLocale(Locale(picked));
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final guest = ref.read(accountRegistryProvider).activeGuest;
    if (guest == null) return;
    final leave = await showGSheet<bool>(
      context,
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('g5.kirish.account.logoutTitle'.tr(), style: GText.h2),
          ),
          const SizedBox(height: 6),
          Text('g5.kirish.account.logoutBody'.tr(), style: GText.body),
          const SizedBox(height: 16),
          GButton(
            label: 'g5.kirish.account.stay'.tr(),
            onPressed: () => Navigator.of(sheetContext).pop(false),
          ),
          const SizedBox(height: 10),
          GButton(
            label: 'g5.kirish.account.logout'.tr(),
            kind: GButtonKind.ghost,
            size: GButtonSize.second,
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
        ],
      ),
    );
    if (leave != true) return;
    try {
      await ref.read(kirishRepositoryProvider).logout();
    } on Object {
      // Server javob bermasa ham shu qurilmadan chiqiladi (tokenlar o'chadi).
    }
    await ref.read(accountRegistryProvider).signOutGuest(guest.childId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guest = ref.watch(accountRegistryProvider).activeGuest;
    final size = ref.watch(g5TextSizeProvider).valueOrNull ?? G5TextSize.normal;
    final device = ref.watch(thisDeviceNameProvider).valueOrNull;
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.blue,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.men.settings.title'.tr(),
        ),
        children: [
          GList(
            children: [
              GListItem(
                leading: const GTile(
                  icon: GIcons.translate,
                  hue: GHue.blue,
                  size: 40,
                ),
                title: 'g5.men.settings.language'.tr(),
                subtitle:
                    'g5.men.settings.langNames.${context.locale.languageCode}'
                        .tr(),
                onTap: () => _pickLanguage(context),
              ),
            ],
          ),
          GSection(
            title: 'g5.men.settings.textSize'.tr(),
            child: GSegmented<G5TextSize>(
              options: G5TextSize.values,
              selected: size,
              labelOf: (s) => 'g5.men.settings.sizes.${s.name}'.tr(),
              onChanged: (s) => ref.read(g5TextSizeProvider.notifier).set(s),
            ),
          ),
          GSection(
            title: 'g5.men.settings.devices'.tr(),
            child: GList(
              children: [
                GListItem(
                  leading: const GTile(
                    icon: GIcons.deviceMobile,
                    hue: GHue.sky,
                    size: 40,
                  ),
                  title: 'g5.men.settings.thisPhone'.tr(),
                  subtitle: [
                    ?device,
                    'g5.men.settings.devicesNote'.tr(),
                  ].join(' · '),
                ),
              ],
            ),
          ),
          GList(
            children: [
              _Link(
                icon: GIcons.bell,
                hue: GHue.gold,
                label: 'g5.men.settings.notifications',
                onTap: () => GrowthLinks.meNotifications(context),
              ),
              _Link(
                icon: GIcons.shieldCheck,
                hue: GHue.sky,
                label: 'g5.men.settings.permissions',
                onTap: () => GrowthLinks.mePermissions(context),
              ),
              _Link(
                icon: GIcons.lockKey,
                hue: GHue.teal,
                label: 'g5.men.settings.privacy',
                onTap: () => GrowthLinks.mePrivacy(context),
              ),
              _Link(
                icon: GIcons.lifebuoy,
                hue: GHue.green,
                label: 'g5.men.settings.help',
                onTap: () => GrowthLinks.meHelp(context),
              ),
            ],
          ),
          GSection(
            title: 'g5.men.settings.account'.tr(),
            child: GList(
              children: [
                GListItem(
                  leading: const GTile(
                    icon: GIcons.password,
                    hue: GHue.teal,
                    size: 40,
                  ),
                  title: 'g5.men.settings.password'.tr(),
                  onTap: () => GrowthLinks.mePassword(context),
                ),
                GListItem(
                  leading: const GTile(
                    icon: GIcons.userSwitch,
                    hue: GHue.slate,
                    size: 40,
                  ),
                  title: 'g5.men.settings.switchAccount'.tr(),
                  onTap: () => context.push(GrowthV5Routes.kirishAccounts),
                ),
                GListItem(
                  leading: const GTile(
                    icon: GIcons.signOut,
                    hue: GHue.slate,
                    size: 40,
                  ),
                  title: 'g5.men.settings.logout'.tr(),
                  // Qurilma egasi chiqa olmaydi — ota-ona nazorati shu
                  // qurilmada (chiqish uchun ota-ona qurilmani uzadi).
                  subtitle: guest == null
                      ? 'g5.kirish.account.ownerLogout'.tr()
                      : null,
                  onTap: guest == null ? null : () => _logout(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({
    required this.icon,
    required this.hue,
    required this.label,
    required this.onTap,
  });

  final GIconData icon;
  final GHue hue;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GListItem(
    leading: GTile(icon: icon, hue: hue, size: 40),
    title: label.tr(),
    onTap: onTap,
  );
}
