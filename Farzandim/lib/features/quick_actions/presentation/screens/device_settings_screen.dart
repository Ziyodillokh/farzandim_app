import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/core/utils/extensions.dart';
import 'package:farzandim/features/child_management/data/models/child_device_info.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/data/repositories/backend_child_repository.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/shared/widgets/app_switch.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:farzandim/shared/widgets/settings_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Qurilma sozlamalari ekrani — Figma 1:1.
///
/// Qurilma kartasi (model + batareya + holat — `deviceInfo`dan dinamik),
/// "Baland ovoz" / "Faollik" tugmalari, "Ilova uchun ruxsatlar" yo'li va
/// "Notanish manbalardan ilovalar" toggle'i.
class DeviceSettingsScreen extends ConsumerStatefulWidget {
  /// `DeviceSettingsScreen` konstruktor.
  const DeviceSettingsScreen({required this.childId, super.key});

  /// Qaysi bola uchun ko'rsatiladi.
  final String childId;

  @override
  ConsumerState<DeviceSettingsScreen> createState() =>
      _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends ConsumerState<DeviceSettingsScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Ekran ochilganda eng so'nggi qurilma ma'lumotini ko'rsatish uchun
    // bolalar ro'yxatini yangilaymiz. MUHIM (PERF-07): `invalidate` EMAS —
    // u provider'ni DISPOSE qilib ILOVA BO'YLAB barcha watcher'larni
    // (dashboard, xarita, limits) loading→data siklidan o'tkazardi.
    // Tick-bump recompute qiladi (copyWithPrevious, flash yo'q).
    Future.microtask(
      () => ref.read(childrenRefreshTickProvider.notifier).state++,
    );
    // Ekran ochiq turganda har 30s yangilab turamiz (childrenProvider'ning
    // o'z ichki 60s poll'iga qo'shimcha tezlik shu ekran uchun; avval 10s
    // edi — bola heartbeat'i 20-60s bo'lgani uchun 10s ortiqcha yuk edi).
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        ref.read(childrenRefreshTickProvider.notifier).state++;
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = ref
        .watch(childrenListProvider)
        .firstWhereOrNull((c) => c.id == widget.childId);

    if (child == null) return const _ChildNotFound();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(title: 'deviceSettings.headerTitle'.tr()),
              Expanded(child: _Content(child: child)),
            ],
          ),
        ),
      ),
    );
  }
}

void _snack(BuildContext context, String text, {bool error = false}) {
  if (error) {
    AppToast.error(context, text);
  } else {
    AppToast.info(context, text);
  }
}

/// Bola qurilmasini baland ovozda jiringlatish (qurilmani topish).
Future<void> _ringDevice(
  BuildContext context,
  WidgetRef ref,
  String childId,
) async {
  _snack(context, 'deviceSettings.ringSending'.tr());
  try {
    await ref.read(backendChildRepositoryProvider).ringDevice(childId);
    if (context.mounted) _snack(context, 'deviceSettings.ringSent'.tr());
  } catch (_) {
    if (context.mounted) {
      _snack(context, 'deviceSettings.ringError'.tr(), error: true);
    }
  }
}

// ════════════════════════ CONTENT ════════════════════════

class _Content extends ConsumerWidget {
  const _Content({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.lg,
        AppDimensions.md,
        AppDimensions.lg,
        AppDimensions.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Qurilma kartasi (dinamik) ───
          _DeviceCard(child: child, info: child.deviceInfo),
          const SizedBox(height: AppDimensions.lg),

          // ─── 2 tugma: Baland ovoz / Faollik ───
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon: Icons.volume_up_rounded,
                  label: 'deviceSettings.loudSound'.tr(),
                  onTap: () => _ringDevice(context, ref, child.id),
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: _ActionTile(
                  icon: Icons.bar_chart_rounded,
                  label: 'deviceSettings.activity'.tr(),
                  onTap: () =>
                      context.push(AppRoutes.appRestrictionsPath(child.id)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.lg),

          // "Ilova uchun ruxsatlar" qatori OLIB TASHLANDI — funksiya hozircha
          // to'g'ri ishlamaydi; keyinroq qaytarilishi mumkin (route saqlangan).

          // ─── Notanish manbalardan ilovalar (toggle) ───
          _UnknownSourcesCard(child: child),
          const SizedBox(height: AppDimensions.lg),

          // ─── Ruxsatlar holati (Block 4 / M12) ───
          _PermissionsCard(info: child.deviceInfo),
        ],
      ),
    );
  }
}

// ════════════════════════ PERMISSIONS STATUS ════════════════════════

/// Bola qurilmasidagi OS-ruxsatlar holati (lokatsiya / bildirishnoma / fon /
/// accessibility). Data Child App device-info heartbeat'idan keladi; `null`
/// (hali yubormagan) → "Noma'lum". On-design: SettingsCard + status ikonalar.
class _PermissionsCard extends StatelessWidget {
  const _PermissionsCard({required this.info});

  final ChildDeviceInfo? info;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      accent: AppColors.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SettingsIconChip(
                icon: Icons.verified_user_outlined,
                accent: AppColors.secondary,
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Text(
                  'deviceSettings.permissions.title'.tr(),
                  style: AppTextStyles.bodyM.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          _PermRow(
            icon: Icons.location_on_rounded,
            label: 'deviceSettings.permissions.location'.tr(),
            status: info?.locationPermission,
          ),
          _PermRow(
            icon: Icons.notifications_rounded,
            label: 'deviceSettings.permissions.notification'.tr(),
            status: info?.notificationPermission,
          ),
          _PermRow(
            icon: Icons.battery_saver_rounded,
            label: 'deviceSettings.permissions.background'.tr(),
            status: info?.backgroundAllowed,
          ),
          _PermRow(
            icon: Icons.accessibility_new_rounded,
            label: 'deviceSettings.permissions.accessibility'.tr(),
            status: info?.accessibilityEnabled,
          ),
        ],
      ),
    );
  }
}

/// Bitta ruxsat qatori — ikona + nom + holat (berilgan/rad/noma'lum).
class _PermRow extends StatelessWidget {
  const _PermRow({
    required this.icon,
    required this.label,
    required this.status,
  });

  final IconData icon;
  final String label;

  /// `true` = berilgan, `false` = rad etilgan, `null` = noma'lum.
  final bool? status;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData statusIcon;
    final String statusKey;
    if (status ?? false) {
      color = AppColors.success;
      statusIcon = Icons.check_circle_rounded;
      statusKey = 'deviceSettings.permissions.granted';
    } else if (status == false) {
      color = AppColors.error;
      statusIcon = Icons.cancel_rounded;
      statusKey = 'deviceSettings.permissions.denied';
    } else {
      color = AppColors.textTertiary;
      statusIcon = Icons.help_outline_rounded;
      statusKey = 'deviceSettings.permissions.unknown';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppDimensions.md),
          Expanded(child: Text(label, style: AppTextStyles.bodyM)),
          Icon(statusIcon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            statusKey.tr(),
            style: AppTextStyles.bodyS.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════ DEVICE CARD ════════════════════════

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.child, required this.info});

  final Child child;
  final ChildDeviceInfo? info;

  @override
  Widget build(BuildContext context) {
    // Online holati — YAGONA heartbeat-aware mantiq (Child.isLiveOnline):
    // ulangan VA oxirgi heartbeat 5 daqiqa ichida. Dashboard/bolalar ro'yxati
    // ham aynan shu getter'dan foydalanadi (avval har joyda har xil edi).
    final isOnline = child.isLiveOnline;
    final battery = info?.batteryLevel;

    return SettingsCard(
      accent: AppColors.secondary,
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Row(
        children: [
          // Qurilma ikonasi — premium accent chip.
          SettingsIconChip(
            icon: Icons.smartphone_rounded,
            accent: AppColors.secondary,
            size: 60,
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  info?.displayModel ?? "Noma'lum qurilma",
                  style: AppTextStyles.bodyM.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Batareya
                    Icon(
                      Icons.battery_std_rounded,
                      size: 14,
                      color: _batteryColor(battery),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      battery != null ? '$battery%' : '—',
                      style: AppTextStyles.bodyS.copyWith(
                        color: _batteryColor(battery),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '•',
                      style: AppTextStyles.bodyS.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Holat
                    Icon(
                      Icons.wifi_rounded,
                      size: 14,
                      color: isOnline
                          ? AppColors.success
                          : AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isOnline
                          ? 'deviceSettings.status.online'.tr()
                          : 'deviceSettings.status.offline'.tr(),
                      style: AppTextStyles.bodyS.copyWith(
                        color: isOnline
                            ? AppColors.success
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _batteryColor(int? level) {
    if (level == null) return AppColors.textSecondary;
    if (level >= 50) return AppColors.success;
    if (level >= 20) return AppColors.warning;
    return AppColors.error;
  }
}

// ════════════════════════ ACTION TILE ════════════════════════

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      accent: AppColors.secondary,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.lg),
      child: Column(
        children: [
          SettingsIconChip(icon: icon, accent: AppColors.secondary, size: 46),
          const SizedBox(height: AppDimensions.sm),
          Text(
            label,
            style: AppTextStyles.bodyS.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════ UNKNOWN SOURCES TOGGLE ════════════════════════

class _UnknownSourcesCard extends ConsumerStatefulWidget {
  const _UnknownSourcesCard({required this.child});

  final Child child;

  @override
  ConsumerState<_UnknownSourcesCard> createState() =>
      _UnknownSourcesCardState();
}

class _UnknownSourcesCardState extends ConsumerState<_UnknownSourcesCard> {
  late bool _blocked = widget.child.blockUnknownSources;
  bool _saving = false;

  @override
  void didUpdateWidget(_UnknownSourcesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Backend'dan yangilangan qiymat kelsa (saqlash tugagach) sinxronlash —
    // lekin saqlash jarayonida foydalanuvchi tanlovini ustun qo'yamiz.
    if (!_saving &&
        oldWidget.child.blockUnknownSources !=
            widget.child.blockUnknownSources) {
      _blocked = widget.child.blockUnknownSources;
    }
  }

  Future<void> _onChanged(bool value) async {
    if (_saving) return;
    final previous = _blocked;
    setState(() {
      _blocked = value; // optimistik
      _saving = true;
    });
    try {
      await ref
          .read(backendChildRepositoryProvider)
          .setBlockUnknownSources(widget.child.id, value: value);
      ref.invalidate(childrenProvider);
      if (mounted) {
        _snack(
          context,
          value
              ? 'deviceSettings.unknownSources.enabledSnack'.tr()
              : 'deviceSettings.unknownSources.disabledSnack'.tr(),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _blocked = previous); // revert
        _snack(
          context,
          'deviceSettings.unknownSources.errorSnack'.tr(),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      accent: AppColors.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SettingsIconChip(
                icon: Icons.shield_outlined,
                accent: AppColors.secondary,
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Text(
                  'deviceSettings.unknownSources.title'.tr(),
                  style: AppTextStyles.bodyM.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              AppSwitch(
                value: _blocked,
                onChanged: _saving ? null : _onChanged,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            'deviceSettings.unknownSources.desc'.tr(
              namedArgs: {'name': widget.child.name},
            ),
            style: AppTextStyles.bodyS.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════ HEADER + NOT FOUND ════════════════════════

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () => context.pop(),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: AppTextStyles.headlineL.copyWith(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _ChildNotFound extends StatelessWidget {
  const _ChildNotFound();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Text(
            'deviceSettings.childNotFound'.tr(),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
