import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/app_restrictions/data/repositories/backend_app_permission_repository.dart';
import 'package:farzandim/features/app_restrictions/presentation/providers/app_usage_providers.dart';
import 'package:farzandim/features/app_restrictions/presentation/widgets/app_icon_widget.dart';
import 'package:farzandim/features/app_restrictions/presentation/widgets/app_tile_skeleton.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/shared/widgets/app_switch.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:farzandim/shared/widgets/settings_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Bitta ruxsat uchun ilovalar ro'yxati (masalan "Kamera uchun ruxsatlar").
///
/// Har ilova yonida toggle — ota-ona o'sha ilovaga ruxsatni yoqadi/o'chiradi.
/// Ilovalar `installedAppsProvider`'dan (real), holatlar
/// `appPermissionPoliciesProvider`'dan (backend) — yo'q ilova default yoqilgan.
class PermissionAppsScreen extends ConsumerStatefulWidget {
  /// `PermissionAppsScreen` konstruktor.
  const PermissionAppsScreen({
    required this.childId,
    required this.permission,
    super.key,
  });

  /// Boshlang'ich bola id'si.
  final String childId;

  /// Ruxsat kaliti: camera | microphone | location | ...
  final String permission;

  @override
  ConsumerState<PermissionAppsScreen> createState() =>
      _PermissionAppsScreenState();
}

class _PermissionAppsScreenState extends ConsumerState<PermissionAppsScreen> {
  late String _childId;

  @override
  void initState() {
    super.initState();
    _childId = widget.childId;
  }

  Future<void> _toggle(String packageName, bool allowed) async {
    try {
      await ref
          .read(backendAppPermissionRepositoryProvider)
          .setPolicy(
            childId: _childId,
            packageName: packageName,
            permission: widget.permission,
            allowed: allowed,
          );
    } catch (_) {
      // Saqlash yiqildi (offline/server) — foydalanuvchiga aniq xabar,
      // jim yutilmaydi (EH-07). Quyidagi invalidate haqiqiy holatni qaytaradi
      // (optimistik toggle orqaga "sakraydi").
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text("Saqlab bo'lmadi. Internet aloqasini tekshiring."),
          ),
        );
      }
    }
    ref.invalidate(
      appPermissionPoliciesProvider((_childId, widget.permission)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(childrenListProvider);
    final appsAsync = ref.watch(installedAppsProvider(_childId));
    final policiesAsync = ref.watch(
      appPermissionPoliciesProvider((_childId, widget.permission)),
    );
    final permName = 'appPermissions.items.${widget.permission}'.tr();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                title: 'appPermissions.appsTitle'.tr(
                  namedArgs: {'name': permName},
                ),
              ),

              // Bola tanlash (bir nechta bola bo'lsa).
              if (children.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.lg,
                    AppDimensions.sm,
                    AppDimensions.lg,
                    0,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _ChildDropdown(
                      childId: _childId,
                      onChanged: (id) => setState(() => _childId = id),
                    ),
                  ),
                ),

              Expanded(
                child: appsAsync.when(
                  loading: () => ListView.builder(
                    itemCount: 6,
                    itemBuilder: (_, __) => const AppTileSkeleton(),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.lg),
                      child: Text(
                        '$e',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyS.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  data: (apps) {
                    if (apps.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppDimensions.lg),
                          child: Text(
                            'deviceSettings.awaitingSubtitle'.tr(),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyS.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }
                    final policies =
                        policiesAsync.valueOrNull ?? const <String, bool>{};
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.lg,
                        vertical: AppDimensions.md,
                      ),
                      itemCount: apps.length,
                      separatorBuilder: (_, __) => const SizedBox(
                        height: AppDimensions.sm + AppDimensions.xs,
                      ),
                      itemBuilder: (context, i) {
                        final app = apps[i];
                        // Ro'yxatda yo'q = default ruxsat berilgan.
                        final allowed = policies[app.packageName] ?? true;
                        return _AppPermissionRow(
                          packageName: app.packageName,
                          appName: app.appName.isEmpty
                              ? app.packageName
                              : app.appName,
                          iconUrl: app.iconUrl,
                          iconBase64: app.iconBase64,
                          allowed: allowed,
                          onChanged: (v) => _toggle(app.packageName, v),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bitta ilova qatori — ikona + nom + toggle.
class _AppPermissionRow extends StatelessWidget {
  const _AppPermissionRow({
    required this.packageName,
    required this.appName,
    required this.allowed,
    required this.onChanged,
    this.iconUrl,
    this.iconBase64,
  });

  final String packageName;
  final String appName;
  final String? iconUrl;
  final String? iconBase64;
  final bool allowed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      accent: AppColors.secondary,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm + 2,
      ),
      child: Row(
        children: [
          AppIconWidget(
            packageName: packageName,
            iconUrl: iconUrl,
            iconBase64: iconBase64,
            size: 36,
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Text(
              appName,
              style: AppTextStyles.bodyM.copyWith(fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AppSwitch(value: allowed, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Bola tanlash dropdown (Saidali ▾).
class _ChildDropdown extends ConsumerWidget {
  const _ChildDropdown({required this.childId, required this.onChanged});

  final String childId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childrenListProvider);
    final current = children.firstWhere(
      (c) => c.id == childId,
      orElse: () => children.first,
    );
    return PopupMenuButton<String>(
      onSelected: onChanged,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      itemBuilder: (_) => [
        for (final c in children)
          PopupMenuItem<String>(value: c.id, child: Text(c.name)),
      ],
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: AppDimensions.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              current.name,
              style: AppTextStyles.bodyM.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tepa qator: ← + markazda sarlavha.
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
                style: AppTextStyles.headlineL.copyWith(fontSize: 19),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
