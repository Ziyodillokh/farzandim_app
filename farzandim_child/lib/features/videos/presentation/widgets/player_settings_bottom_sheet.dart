// ─────────────────────────────────────────────────────────────────────
// PlayerSettingsBottomSheet — sozlamalar (PDF p22-26)
// ─────────────────────────────────────────────────────────────────────
//
// 5 ta tile: Ekran qulflash, Takrorlash (Switch), Tezlik, Sifat,
// Uyqu taymeri. Tezlik/Sifat/Uyqu tile bos → ikkinchi modal sheet
// ochib variantni tanlash.

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/videos/presentation/providers/player_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlayerSettingsBottomSheet extends ConsumerWidget {
  const PlayerSettingsBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(playerSettingsProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'videos.player.settingsTitle'.tr(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            _tile(
              icon: Icons.lock_outline,
              title: 'videos.player.screenLock'.tr(),
              trailing: const Icon(AppIcons.chevronRight,
                  color: AppColors.textSecondary),
              onTap: () {
                ref.read(playerSettingsProvider.notifier).state =
                    settings.copyWith(screenLocked: true);
                Navigator.pop(context);
              },
            ),
            _tile(
              icon: Icons.repeat,
              title: 'videos.player.repeat'.tr(),
              trailing: Switch(
                value: settings.repeat,
                activeThumbColor: AppColors.primary,
                onChanged: (val) {
                  ref.read(playerSettingsProvider.notifier).state =
                      settings.copyWith(repeat: val);
                },
              ),
            ),
            _tile(
              icon: Icons.speed,
              title: 'videos.player.speed'.tr(),
              subtitle: '${settings.speed}x',
              trailing: const Icon(AppIcons.chevronRight,
                  color: AppColors.textSecondary),
              onTap: () => _openSpeedPicker(context, ref),
            ),
            _tile(
              icon: Icons.high_quality,
              title: 'videos.player.quality'.tr(),
              subtitle: settings.quality,
              trailing: const Icon(AppIcons.chevronRight,
                  color: AppColors.textSecondary),
              onTap: () => _openQualityPicker(context, ref),
            ),
            _tile(
              icon: AppIcons.hourglass,
              title: 'videos.player.sleepTimer'.tr(),
              subtitle: settings.sleepTimerMinutes != null
                  ? 'videos.player.sleepMinShort'.tr(
                      namedArgs: {
                        'min': '${settings.sleepTimerMinutes}',
                      },
                    )
                  : 'videos.player.sleepOff'.tr(),
              trailing: const Icon(AppIcons.chevronRight,
                  color: AppColors.textSecondary),
              onTap: () => _openSleepTimerPicker(context, ref),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title,
          style: const TextStyle(color: AppColors.textPrimary)),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  void _openSpeedPicker(BuildContext context, WidgetRef ref) {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    _openListPicker(
      context: context,
      title: 'videos.player.speed'.tr(),
      options: speeds.map((s) => '${s}x').toList(),
      currentValue: '${ref.read(playerSettingsProvider).speed}x',
      onSelect: (value) {
        final speed =
            double.parse(value.replaceAll('x', ''));
        ref.read(playerSettingsProvider.notifier).state =
            ref.read(playerSettingsProvider).copyWith(speed: speed);
      },
    );
  }

  void _openQualityPicker(BuildContext context, WidgetRef ref) {
    _openListPicker(
      context: context,
      title: 'videos.player.quality'.tr(),
      options: const ['1080p', '720p', '480p', '360p', '240p'],
      currentValue: ref.read(playerSettingsProvider).quality,
      onSelect: (value) {
        ref.read(playerSettingsProvider.notifier).state =
            ref.read(playerSettingsProvider).copyWith(quality: value);
      },
    );
  }

  void _openSleepTimerPicker(BuildContext context, WidgetRef ref) {
    final settings = ref.read(playerSettingsProvider);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'videos.player.sleepTimer'.tr(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Divider(color: AppColors.border, height: 1),
              ListTile(
                title: Text(
                  'videos.player.sleepOffButton'.tr(),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                trailing: settings.sleepTimerMinutes == null
                    ? const Icon(AppIcons.check,
                        color: AppColors.primary)
                    : null,
                onTap: () {
                  ref.read(playerSettingsProvider.notifier).state =
                      settings.copyWith(clearSleepTimer: true);
                  Navigator.pop(ctx);
                },
              ),
              for (final min in const [5, 10, 15, 20, 30, 45])
                ListTile(
                  title: Text(
                    'videos.player.sleepMinutes'.tr(
                      namedArgs: {'min': '$min'},
                    ),
                    style: const TextStyle(
                        color: AppColors.textPrimary),
                  ),
                  trailing: settings.sleepTimerMinutes == min
                      ? const Icon(AppIcons.check,
                          color: AppColors.primary)
                      : null,
                  onTap: () {
                    ref.read(playerSettingsProvider.notifier).state =
                        settings.copyWith(sleepTimerMinutes: min);
                    Navigator.pop(ctx);
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _openListPicker({
    required BuildContext context,
    required String title,
    required List<String> options,
    required String currentValue,
    required void Function(String) onSelect,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Divider(color: AppColors.border, height: 1),
              for (final option in options)
                ListTile(
                  title: Text(
                    option,
                    style: const TextStyle(
                        color: AppColors.textPrimary),
                  ),
                  trailing: option == currentValue
                      ? const Icon(AppIcons.check,
                          color: AppColors.primary)
                      : null,
                  onTap: () {
                    onSelect(option);
                    Navigator.pop(ctx);
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
