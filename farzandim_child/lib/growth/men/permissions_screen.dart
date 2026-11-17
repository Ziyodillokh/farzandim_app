// I05 · Mening ruxsatlarim (faqat ko'rish): joylashuv, qadamlar, qurilma
// holati va ekran vaqti — holat shu telefonning o'zidan o'qiladi. Har bir
// qator bosilsa — nima yig'iladi va kim ko'radi. «Mavjud emas» — nol emas.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/platform/platform_capabilities.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:farzandim_child/growth/men/data/men_device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MePermissionsScreen extends ConsumerStatefulWidget {
  const MePermissionsScreen({super.key});

  @override
  ConsumerState<MePermissionsScreen> createState() =>
      _MePermissionsScreenState();
}

class _MePermissionsScreenState extends ConsumerState<MePermissionsScreen> {
  String? _open;

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(myPermissionsProvider).valueOrNull;
    final rows = [
      ('location', GIcons.mapPin, GHue.rose, perms?.location, null as String?),
      ('steps', GIcons.footprints, GHue.green, perms?.steps, null),
      ('device', GIcons.batteryHigh, GHue.sky, perms?.device, null),
      (
        'screenTime',
        GIcons.hourglassMedium,
        GHue.gold,
        perms?.screenTime,
        PlatformCapabilities.isIOS
            ? 'g5.men.permissions.detail.screenTime.ios'.tr()
            : null,
      ),
    ];
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.teal,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.men.permissions.title'.tr(),
        ),
        onRefresh: () async => ref.invalidate(myPermissionsProvider),
        dock: GButton(
          label: 'g5.men.permissions.family'.tr(),
          kind: GButtonKind.ghost,
          icon: GIcons.users,
          onPressed: () => GrowthLinks.family(context),
        ),
        children: [
          for (final (key, icon, hue, state, extra) in rows)
            _PermissionCard(
              title: 'g5.men.permissions.$key'.tr(),
              icon: icon,
              hue: hue,
              state: state,
              open: _open == key,
              what: 'g5.men.permissions.detail.$key.what'.tr(),
              who: 'g5.men.permissions.detail.$key.who'.tr(),
              extra: extra,
              onTap: () => setState(() => _open = _open == key ? null : key),
            ),
          GNote(
            text:
                '${'g5.men.permissions.parentManages'.tr()} ${'g5.men.permissions.offNote'.tr()}',
            kind: GNoteKind.plain,
            icon: GIcons.shieldCheck,
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.title,
    required this.icon,
    required this.hue,
    required this.state,
    required this.open,
    required this.what,
    required this.who,
    required this.onTap,
    this.extra,
  });

  final String title;
  final GIconData icon;
  final GHue hue;
  final PermissionState? state;
  final bool open;
  final String what;
  final String who;
  final String? extra;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chip = switch (state) {
      PermissionState.on => (
        label: 'g5.men.permissions.on'.tr(),
        kind: GChipKind.ok,
      ),
      PermissionState.off => (
        label: 'g5.men.permissions.off'.tr(),
        kind: GChipKind.neutral,
      ),
      PermissionState.unavailable => (
        label: 'g5.men.permissions.unavailable'.tr(),
        kind: GChipKind.warn,
      ),
      null => (label: 'g5.common.loading'.tr(), kind: GChipKind.neutral),
    };
    return GPressable(
      onTap: onTap,
      pressedScale: .98,
      child: Semantics(
        expanded: open,
        child: GGlass(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  GTile(icon: icon, hue: hue, size: 40),
                  const SizedBox(width: 12),
                  Expanded(child: Text(title, style: GText.itemTitle)),
                  GChip(label: chip.label, kind: chip.kind),
                  const SizedBox(width: 6),
                  GIcon(
                    open ? GIcons.caretUp : GIcons.caretDown,
                    size: 18,
                    color: GColors.link,
                  ),
                ],
              ),
              if (open) ...[
                const SizedBox(height: 12),
                _Detail(label: 'g5.men.permissions.what'.tr(), text: what),
                const SizedBox(height: 8),
                _Detail(label: 'g5.men.permissions.who'.tr(), text: who),
                if (extra != null) ...[
                  const SizedBox(height: 8),
                  Text(extra!, style: GText.caption),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: GText.label),
      const SizedBox(height: 2),
      Text(text, style: GText.body),
    ],
  );
}
