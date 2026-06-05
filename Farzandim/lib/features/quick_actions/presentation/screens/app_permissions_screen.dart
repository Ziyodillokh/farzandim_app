import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Ilova uchun ruxsatlar ekrani — bola qurilmasidagi ruxsatlar ro'yxati.
///
/// Hozircha 8 ta standart ruxsat kategoriyasi ko'rsatiladi (Joylashuv,
/// Kamera, ...). Har biri bosilsa izoh chiqadi. Ruxsatning aniq holati
/// (berilgan/rad etilgan) bola qurilmasi (Child App) ma'lumot yuborgach
/// dinamik ko'rinadi.
class AppPermissionsScreen extends StatelessWidget {
  /// `AppPermissionsScreen` konstruktor.
  const AppPermissionsScreen({required this.childId, super.key});

  /// Qaysi bolaning qurilmasi ruxsatlari.
  final String childId;

  /// Ruxsat kalitlari + ikonkalari (Figma tartibida).
  static const List<(String, IconData)> _permissions = [
    ('location', Icons.location_on_outlined),
    ('camera', Icons.camera_alt_outlined),
    ('contacts', Icons.contacts_outlined),
    ('microphone', Icons.mic_none_rounded),
    ('sms', Icons.sms_outlined),
    ('calendar', Icons.calendar_today_outlined),
    ('phone', Icons.call_outlined),
    ('storage', Icons.folder_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(title: 'appPermissions.headerTitle'.tr()),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.lg,
                    vertical: AppDimensions.md,
                  ),
                  itemCount: _permissions.length,
                  separatorBuilder: (_, __) => const SizedBox(
                    height: AppDimensions.sm + AppDimensions.xs,
                  ),
                  itemBuilder: (context, i) {
                    final (key, icon) = _permissions[i];
                    final name = 'appPermissions.items.$key'.tr();
                    return _PermissionRow(
                      icon: icon,
                      name: name,
                      onTap: () => context.push(
                        AppRoutes.permissionAppsPath(childId, key),
                      ),
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

/// Bitta ruxsat qatori — ikona + nom + chevron (bosilsa izoh).
class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.name,
    required this.onTap,
  });

  final IconData icon;
  final String name;
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
                  name,
                  style: AppTextStyles.bodyM.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
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
