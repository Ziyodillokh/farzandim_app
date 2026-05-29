import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/core/utils/extensions.dart';
import 'package:farzandim/features/child_management/data/models/child_device_info.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/shared/widgets/child_avatar.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Bola qurilmasi haqida ma'lumot ekrani — Quick Actions #1.
///
/// **Bosqich 8.B**: ma'lumot endi mock emas — Child App Firestore'ga
/// yozayotgan real `child.deviceInfo` map'idan o'qiladi. Bola hali
/// pair qilmagan yoki Child App offline bo'lsa empty state ko'rsatiladi.
class DeviceSettingsScreen extends ConsumerWidget {
  /// `DeviceSettingsScreen` konstruktor.
  const DeviceSettingsScreen({required this.childId, super.key});

  /// Qaysi bola uchun ma'lumot ko'rsatiladi.
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref
        .watch(childrenListProvider)
        .firstWhereOrNull((c) => c.id == childId);

    if (child == null) {
      return const _ChildNotFound();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              const _Header(),
              Expanded(child: _Content(child: child)),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════ HEADER ════════════════════════

class _Header extends StatelessWidget {
  const _Header();

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
              icon: const Icon(
                Icons.arrow_back,
                color: AppColors.textPrimary,
              ),
              onPressed: () => context.pop(),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'deviceSettings.headerTitle'.tr(),
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

// ════════════════════════ CONTENT ════════════════════════

class _Content extends ConsumerWidget {
  const _Content({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = child.deviceInfo;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.lg,
        vertical: AppDimensions.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChildHeaderCard(child: child, info: info),
          const SizedBox(height: AppDimensions.lg),
          if (info == null)
            const _AwaitingDeviceState()
          else ...[
            _SectionLabel('deviceSettings.sectionDevice'.tr()),
            const SizedBox(height: AppDimensions.sm),
            _DeviceSection(info: info),
            const SizedBox(height: AppDimensions.lg),
            _SectionLabel('deviceSettings.sectionStatus'.tr()),
            const SizedBox(height: AppDimensions.sm),
            _StatusSection(info: info),
            const SizedBox(height: AppDimensions.xl),
            _DangerButton(
              label: 'deviceSettings.disconnectButton'.tr(),
              icon: Icons.link_off,
              onPressed: () => _confirmDisconnect(context, ref),
            ),
            const SizedBox(height: AppDimensions.lg),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDisconnect(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'deviceSettings.disconnectDialog.title'.tr(),
          style: AppTextStyles.headlineL.copyWith(fontSize: 18),
        ),
        content: Text(
          'deviceSettings.disconnectDialog.content'.tr(),
          style: AppTextStyles.bodyS.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'deviceSettings.disconnectDialog.cancel'.tr(),
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'deviceSettings.disconnectDialog.confirm'.tr(),
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (!(confirmed ?? false)) return;

    final result = await ref
        .read(childActionsProvider.notifier)
        .regenerateFamilyCode(child.id);

    if (!context.mounted) return;
    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'deviceSettings.disconnectSuccessSnack'.tr(
              namedArgs: {'code': result.data!},
            ),
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } else {
      final error = result.error;
      final message = error != null
          ? 'deviceSettings.disconnectErrorPrefix'.tr(
              namedArgs: {'error': '$error'},
            )
          : 'deviceSettings.disconnectGenericError'.tr();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

// ════════════════════════ SECTIONS ════════════════════════

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppDimensions.sm),
      child: Text(
        text,
        style: AppTextStyles.label.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _DeviceSection extends StatelessWidget {
  const _DeviceSection({required this.info});
  final ChildDeviceInfo info;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.smartphone,
            label: 'deviceSettings.row.model'.tr(),
            value: info.displayModel,
          ),
          const Divider(height: 1, color: AppColors.divider),
          _InfoRow(
            icon: Icons.android,
            label: 'deviceSettings.row.system'.tr(),
            value: info.displayOS,
          ),
          const Divider(height: 1, color: AppColors.divider),
          _InfoRow(
            icon: Icons.app_settings_alt,
            label: 'deviceSettings.row.appVersion'.tr(),
            value: info.displayAppVersion,
          ),
        ],
      ),
    );
  }
}

class _StatusSection extends StatelessWidget {
  const _StatusSection({required this.info});
  final ChildDeviceInfo info;

  @override
  Widget build(BuildContext context) {
    final batteryLevel = info.batteryLevel;
    final batteryColor = _batteryColor(batteryLevel);
    final isCharging = info.isCharging ?? false;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _InfoRow(
            icon: isCharging
                ? Icons.battery_charging_full
                : Icons.battery_full,
            iconColor: batteryColor,
            label: 'deviceSettings.row.battery'.tr(),
            value: info.displayBattery,
          ),
          const Divider(height: 1, color: AppColors.divider),
          _InfoRow(
            icon: Icons.wifi,
            label: 'deviceSettings.row.wifi'.tr(),
            value: info.displayWifi,
          ),
          const Divider(height: 1, color: AppColors.divider),
          _InfoRow(
            icon: Icons.access_time,
            label: 'deviceSettings.row.lastSeen'.tr(),
            value: info.displayLastSeen,
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

// ════════════════════════ HELPERS ════════════════════════

class _ChildHeaderCard extends StatelessWidget {
  const _ChildHeaderCard({required this.child, required this.info});

  final Child child;
  final ChildDeviceInfo? info;

  @override
  Widget build(BuildContext context) {
    final isConnected = child.isConnected;
    final isOnline = info?.isOnline ?? false;
    final showOnlineBadge = isConnected && isOnline;
    final statusText = !isConnected
        ? 'deviceSettings.status.disconnected'.tr()
        : (isOnline
            ? 'deviceSettings.status.online'.tr()
            : 'deviceSettings.status.offline'.tr());
    final dotColor = showOnlineBadge
        ? AppColors.success
        : AppColors.textTertiary;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Row(
        children: [
          ChildAvatar(child: child, size: 56),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'deviceSettings.headerCardTitle'.tr(
                    namedArgs: {'name': child.name},
                  ),
                  style: AppTextStyles.bodyM.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                        boxShadow: showOnlineBadge
                            ? [
                                BoxShadow(
                                  color: AppColors.success
                                      .withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: AppTextStyles.bodyS.copyWith(
                        color: showOnlineBadge
                            ? AppColors.success
                            : AppColors.textSecondary,
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
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: 12,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodyS.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.bodyS.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `child.deviceInfo` hali Firestore'da yo'q — Child App
/// pair qilmagan yoki birinchi heartbeat hali kelmagan.
class _AwaitingDeviceState extends StatelessWidget {
  const _AwaitingDeviceState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.xl),
      child: Column(
        children: [
          const Icon(
            Icons.phone_android,
            size: 64,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppDimensions.md),
          Text(
            'deviceSettings.awaitingTitle'.tr(),
            style: AppTextStyles.bodyM.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.lg,
            ),
            child: Text(
              'deviceSettings.awaitingSubtitle'.tr(),
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// Qizil border'li tugma — xavfli amallar uchun (uzish, o'chirish).
class _DangerButton extends StatelessWidget {
  const _DangerButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(AppDimensions.radiusPill);
    return SizedBox(
      width: double.infinity,
      height: AppDimensions.buttonHeight,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: AppColors.error.withValues(alpha: 0.6),
          ),
          borderRadius: borderRadius,
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: borderRadius,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: AppColors.error),
                const SizedBox(width: AppDimensions.sm),
                Text(
                  label,
                  style: AppTextStyles.bodyM.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
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
