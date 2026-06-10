import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/onboarding/presentation/providers/language_picked_provider.dart';
import 'package:farzandim/features/settings/presentation/providers/language_provider.dart';
import 'package:farzandim/shared/widgets/glass_card.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:farzandim/shared/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Birinchi ochilish — til tanlash ekrani.
///
/// Shisha karta ichida logo + 3 til (O'zbekcha / Русский / English). Tilni
/// bossangiz ilova DARHOL o'sha tilga o'tadi (jonli ko'rinish), "Davom etish"
/// bilan saqlanib welcome'ga o'tiladi. Keyingi ochilishlarda QAYTA chiqmaydi
/// (`languagePickedProvider`). Faqat ota-ona ilovasi.
class LanguageSelectScreen extends ConsumerWidget {
  /// `LanguageSelectScreen` konstruktor.
  const LanguageSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tanlangan til = joriy locale (tap setLocale qiladi → ekran qayta quriladi).
    final current = AppLanguage.fromCode(context.locale.languageCode);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.lg),
              child: GlassCard(
                elevation: GlassElevation.raised,
                padding: const EdgeInsets.all(AppDimensions.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipOval(
                      child: Image.asset(
                        'assets/icons/parent_logo_icon.png',
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.lg),
                    Text(
                      'language.selectTitle'.tr(),
                      style: AppTextStyles.headlineL,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.xs),
                    Text(
                      'language.selectSubtitle'.tr(),
                      style: AppTextStyles.bodyS.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.lg),
                    for (final lang in AppLanguage.values) ...[
                      _LangTile(
                        lang: lang,
                        selected: lang == current,
                        onTap: () => context.setLocale(lang.locale),
                      ),
                      const SizedBox(height: AppDimensions.sm),
                    ],
                    const SizedBox(height: AppDimensions.md),
                    PrimaryButton(
                      label: 'language.continueButton'.tr(),
                      onPressed: () async {
                        await ref
                            .read(languagePickedProvider.notifier)
                            .markPicked();
                        if (context.mounted) {
                          context.go(AppRoutes.welcome);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bitta til varianti — bayroq + nom + tanlangan bo'lsa check. Bosilganda
/// ilova tili jonli o'zgaradi.
class _LangTile extends StatelessWidget {
  const _LangTile({
    required this.lang,
    required this.selected,
    required this.onTap,
  });

  final AppLanguage lang;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDimensions.radiusM);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.md,
            vertical: AppDimensions.md,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.18)
                : AppColors.surfaceVariant.withValues(alpha: 0.45),
            borderRadius: radius,
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(lang.flag, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Text(
                  lang.label,
                  style: AppTextStyles.bodyM.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              AnimatedScale(
                scale: selected ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
