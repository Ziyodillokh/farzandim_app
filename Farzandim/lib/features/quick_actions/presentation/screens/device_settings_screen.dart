import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/core/utils/extensions.dart';
import 'package:farzandim/features/child_management/data/models/child_device_info.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Qurilma sozlamalari ekrani — Figma 1:1.
///
/// Qurilma kartasi (model + batareya + holat — `deviceInfo`dan dinamik),
/// "Baland ovoz" / "Faollik" tugmalari, "Ilova uchun ruxsatlar" yo'li va
/// "Notanish manbalardan ilovalar" toggle'i.
class DeviceSettingsScreen extends ConsumerWidget {
  /// `DeviceSettingsScreen` konstruktor.
  const DeviceSettingsScreen({required this.childId, super.key});

  /// Qaysi bola uchun ko'rsatiladi.
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref
        .watch(childrenListProvider)
        .firstWhereOrNull((c) => c.id == childId);

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

void _comingSoon(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('auth.social.comingSoon'.tr()),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceVariant,
      ),
    );
}

// ════════════════════════ CONTENT ════════════════════════

class _Content extends StatelessWidget {
  const _Content({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context) {
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
                  onTap: () => _comingSoon(context),
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

          // ─── Ilova uchun ruxsatlar ───
          _NavRow(
            icon: Icons.smartphone_rounded,
            label: 'deviceSettings.appPermissionsRow'.tr(),
            onTap: () =>
                context.push(AppRoutes.appPermissionsPath(child.id)),
          ),
          const SizedBox(height: AppDimensions.lg),

          // ─── Notanish manbalardan ilovalar (toggle) ───
          const _UnknownSourcesCard(),
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
    final isOnline = (child.isConnected) && (info?.isOnline ?? false);
    final battery = info?.batteryLevel;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
      ),
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Row(
        children: [
          // Qurilma rasm/ikona placeholder.
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.smartphone_rounded,
              size: 32,
              color: AppColors.textSecondary,
            ),
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
    final borderRadius = BorderRadius.circular(AppDimensions.radiusM);
    return Material(
      color: AppColors.surface,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppDimensions.lg),
          child: Column(
            children: [
              Icon(icon, size: 26, color: AppColors.textPrimary),
              const SizedBox(height: AppDimensions.sm),
              Text(
                label,
                style: AppTextStyles.bodyS.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════ NAV ROW ════════════════════════

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(AppDimensions.radiusM);
    return Material(
      color: AppColors.surface,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.md,
            vertical: AppDimensions.md,
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: AppColors.textSecondary),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyM.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════ UNKNOWN SOURCES TOGGLE ════════════════════════

class _UnknownSourcesCard extends StatefulWidget {
  const _UnknownSourcesCard();

  @override
  State<_UnknownSourcesCard> createState() => _UnknownSourcesCardState();
}

class _UnknownSourcesCardState extends State<_UnknownSourcesCard> {
  bool _blocked = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'deviceSettings.unknownSources.title'.tr(),
                  style: AppTextStyles.bodyM.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              Switch.adaptive(
                value: _blocked,
                activeThumbColor: AppColors.primary,
                onChanged: (v) {
                  setState(() => _blocked = v);
                  _comingSoon(context);
                },
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            'deviceSettings.unknownSources.desc'.tr(),
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
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
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
