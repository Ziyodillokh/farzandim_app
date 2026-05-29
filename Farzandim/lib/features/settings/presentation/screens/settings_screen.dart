import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/notifications/presentation/providers/fcm_provider.dart';
import 'package:farzandim/features/profile/data/models/parent_profile.dart';
import 'package:farzandim/features/profile/presentation/providers/profile_provider.dart';
import 'package:farzandim/features/settings/presentation/providers/language_provider.dart';
import 'package:farzandim/features/settings/presentation/providers/notification_settings_provider.dart';
import 'package:farzandim/features/settings/presentation/widgets/settings_section.dart';
import 'package:farzandim/features/settings/presentation/widgets/settings_tile.dart';
import 'package:farzandim/features/settings/presentation/widgets/settings_toggle.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:farzandim/shared/widgets/secondary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Sozlamalar bosh ekrani — bo'limlarga tartiblangan menyu.
///
/// **Bosqich 7.1 tuzatishlari:**
/// - Profil tile subtitle dinamik (ism + telefon profile'dan)
/// - Bildirishnoma toggle'lar Riverpod state'ga ulangan (saqlanadi)
/// - Til tile dialog ochadi (3 ta til, bayroq, tanlangan check)
/// - Texnik yordam dialog (Email/Telefon/Telegram, clipboard'ga nusxa)
class SettingsScreen extends ConsumerWidget {
  /// `SettingsScreen` konstruktor.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childCount = ref.watch(childrenListProvider).length;
    final profile = ref.watch(profileProvider);
    final notifSettings = ref.watch(notificationSettingsProvider);
    final notifNotifier =
        ref.read(notificationSettingsProvider.notifier);
    // Joriy til — easy_localization context'idan o'qiymiz.
    // `setLocale` chaqirilsa, kontekst o'zgarib widget rebuild bo'ladi.
    final language = AppLanguage.fromCode(context.locale.languageCode);

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
                    vertical: AppDimensions.md,
                  ),
                  child: Column(
                    children: [
                      // Profil: ko'k accent (shaxsiy ma'lumot)
                      SettingsSection(
                        title: 'settings.sections.profile'.tr(),
                        children: [
                          SettingsTile(
                            icon: Icons.person_rounded,
                            accentColor: AppColors.info,
                            title: 'settings.profile.title'.tr(),
                            subtitle: _profileSubtitle(profile),
                            onTap: () =>
                                context.push(AppRoutes.settingsProfile),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.md),
                      // Bolalar: lime accent (asosiy fokus)
                      SettingsSection(
                        title: 'settings.sections.children'.tr(),
                        children: [
                          SettingsTile(
                            icon: Icons.family_restroom_rounded,
                            title: 'settings.children.title'.tr(),
                            subtitle: 'settings.children.subtitle'.tr(
                              namedArgs: {'count': '$childCount'},
                            ),
                            onTap: () =>
                                context.push(AppRoutes.settingsChildren),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.md),
                      // Bildirishnoma: sariq accent (diqqat)
                      SettingsSection(
                        title: 'settings.sections.notifications'.tr(),
                        children: [
                          SettingsToggle(
                            icon: Icons.notifications_rounded,
                            accentColor: AppColors.warning,
                            title: 'settings.notificationToggles.push'.tr(),
                            value: notifSettings.pushEnabled,
                            onChanged: notifNotifier.togglePush,
                          ),
                          SettingsToggle(
                            icon: Icons.location_on_rounded,
                            accentColor: AppColors.success,
                            title:
                                'settings.notificationToggles.location'.tr(),
                            value: notifSettings.locationAlerts,
                            onChanged: notifNotifier.toggleLocation,
                          ),
                          SettingsToggle(
                            icon: Icons.shield_rounded,
                            accentColor: AppColors.success,
                            title:
                                'settings.notificationToggles.geoZone'.tr(),
                            value: notifSettings.geoZoneAlerts,
                            onChanged: notifNotifier.toggleGeoZone,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.md),
                      // Til: ko'k accent
                      SettingsSection(
                        title: 'settings.sections.language'.tr(),
                        children: [
                          SettingsTile(
                            icon: Icons.translate_rounded,
                            accentColor: AppColors.info,
                            title: 'settings.language.title'.tr(),
                            subtitle: language.label,
                            onTap: () => _showLanguageDialog(context, ref),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.md),
                      // Yordam: monoxromatik lime (asosiy)
                      SettingsSection(
                        title: 'settings.sections.help'.tr(),
                        children: [
                          SettingsTile(
                            icon: Icons.info_rounded,
                            title: 'settings.help.about'.tr(),
                            onTap: () =>
                                context.push(AppRoutes.settingsAbout),
                          ),
                          SettingsTile(
                            icon: Icons.support_agent_rounded,
                            title: 'settings.help.support'.tr(),
                            onTap: () => _showSupportDialog(context),
                          ),
                          SettingsTile(
                            icon: Icons.privacy_tip_rounded,
                            title: 'settings.help.privacy'.tr(),
                            onTap: () => context.push(
                              AppRoutes.legalPrivacyPolicy,
                            ),
                          ),
                          SettingsTile(
                            icon: Icons.description_rounded,
                            title: 'settings.help.terms'.tr(),
                            onTap: () => context.push(
                              AppRoutes.legalTermsOfService,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.xl),
                      SecondaryButton(
                        label: 'settings.logout.button'.tr(),
                        icon: Icons.logout_rounded,
                        onPressed: () =>
                            _showLogoutDialog(context, ref),
                      ),
                      const SizedBox(height: AppDimensions.md),
                      TextButton(
                        onPressed: () => context.push(
                          AppRoutes.settingsDeleteAccount,
                        ),
                        child: Text(
                          'settings.deleteAccount'.tr(),
                          style: AppTextStyles.bodyM.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.lg),
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

  // ─── Profil subtitle ───

  /// "Aliyev • +998 90 ..." yoki bo'sh paytda placeholder.
  String _profileSubtitle(ParentProfile profile) {
    final parts = <String>[
      if (profile.name.trim().isNotEmpty) profile.name.trim(),
      if (profile.phoneNumber != null &&
          profile.phoneNumber!.trim().isNotEmpty)
        profile.phoneNumber!.trim(),
    ];
    if (parts.isEmpty) return 'settings.profile.placeholder'.tr();
    return parts.join(' • ');
  }

  // ─── Til dialog ───

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'settings.language.dialogTitle'.tr(),
          style: AppTextStyles.headlineL.copyWith(fontSize: 18),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: Builder(
          builder: (innerContext) {
            // Joriy tilni dialog'ning o'z konteksti orqali o'qiymiz —
            // setLocale chaqirilsa, butun ilova rebuild bo'lib dialog
            // ham yangi locale bilan qayta ochilmaydi. Lekin dialog
            // yopilgani uchun bu muhim emas.
            final selected =
                AppLanguage.fromCode(context.locale.languageCode);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final lang in AppLanguage.values)
                  _LanguageOption(
                    language: lang,
                    isSelected: lang == selected,
                    onTap: () async {
                      // easy_localization API — locale o'zgaradi,
                      // SharedPreferences'da avtomatik saqlanadi,
                      // butun MaterialApp.router rebuild bo'ladi.
                      await context.setLocale(lang.locale);
                      if (innerContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ─── Texnik yordam dialog ───

  void _showSupportDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'settings.supportDialog.title'.tr(),
          style: AppTextStyles.headlineL.copyWith(fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'settings.supportDialog.subtitle'.tr(),
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            _SupportContactRow(
              icon: Icons.mail_rounded,
              label: 'settings.supportDialog.emailLabel'.tr(),
              value: 'support@farzandim.uz',
            ),
            const SizedBox(height: 12),
            _SupportContactRow(
              icon: Icons.phone_rounded,
              label: 'settings.supportDialog.phoneLabel'.tr(),
              value: '+998 90 123 45 67',
            ),
            const SizedBox(height: 12),
            _SupportContactRow(
              icon: Icons.send_rounded,
              label: 'settings.supportDialog.telegramLabel'.tr(),
              value: '@farzandim_support',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'settings.supportDialog.close'.tr(),
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Logout ───

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'settings.logout.dialogTitle'.tr(),
          style: AppTextStyles.headlineL.copyWith(fontSize: 18),
        ),
        content: Text(
          'settings.logout.dialogContent'.tr(),
          style: AppTextStyles.bodyS.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'settings.logout.cancel'.tr(),
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              // FCM token tozalash + Backend logout.
              try {
                await ref
                    .read(fcmServiceProvider)
                    .removeTokenForCurrentUser();
              } catch (_) {
                // FCM Firestore mode'da bo'lmasa xato bo'lishi mumkin.
              }
              await ref.read(backendAuthProvider.notifier).logout();
              // Auth-protected routing avtomatik /welcome'ga yo'naltiradi.
            },
            child: Text(
              'settings.logout.confirm'.tr(),
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: AppColors.textPrimary,
              ),
              onPressed: () => context.pop(),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'settings.title'.tr(),
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

// ════════════════════════ LANGUAGE OPTION ════════════════════════

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.language,
    required this.isSelected,
    required this.onTap,
  });

  final AppLanguage language;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: 12,
        ),
        child: Row(
          children: [
            Text(language.flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Text(
                language.label,
                style: AppTextStyles.bodyM,
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════ SUPPORT CONTACT ROW ════════════════════════

class _SupportContactRow extends StatelessWidget {
  const _SupportContactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(12);
    return Material(
      color: AppColors.surfaceVariant,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _copyToClipboard(context),
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.22),
                      AppColors.primary.withValues(alpha: 0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.20),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: AppTextStyles.bodyS.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.copy_rounded,
                color: AppColors.textSecondary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyToClipboard(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'settings.supportDialog.copiedSnack'.tr(
            namedArgs: {'label': label},
          ),
        ),
      ),
    );
  }
}
