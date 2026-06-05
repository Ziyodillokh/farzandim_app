import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Ilova haqida ekrani — logo, versiya, qisqa tavsif, linklar.
class AboutScreen extends StatelessWidget {
  /// `AboutScreen` konstruktor.
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              const _Header(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.lg,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: AppDimensions.xl),
                      Image.asset(
                        'assets/icons/parent_logo_icon.png',
                        width: 80,
                        height: 80,
                      ),
                      const SizedBox(height: AppDimensions.md),
                      Text(
                        'about.appName'.tr(),
                        style: AppTextStyles.headlineXL.copyWith(
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.xs),
                      Text(
                        'about.version'.tr(),
                        style: AppTextStyles.bodyS.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.xl),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusM,
                          ),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: const EdgeInsets.all(AppDimensions.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'about.description1'.tr(),
                              style: AppTextStyles.bodyS.copyWith(
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'about.description2'.tr(),
                              style: AppTextStyles.bodyS.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.5,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.lg),
                      _LinkTile(
                        title: 'about.termsLink'.tr(),
                        onTap: () => context.push(
                          AppRoutes.legalTermsOfService,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      _LinkTile(
                        title: 'about.privacyLink'.tr(),
                        onTap: () => context.push(
                          AppRoutes.legalPrivacyPolicy,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.xl),
                      Text(
                        'about.madeWithLove'.tr(),
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.md),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
              icon: Icon(
                Icons.arrow_back,
                color: AppColors.textPrimary,
              ),
              onPressed: () => context.pop(),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'about.headerTitle'.tr(),
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

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(AppDimensions.radiusM);
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.md,
            vertical: 14,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyM,
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 22,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
