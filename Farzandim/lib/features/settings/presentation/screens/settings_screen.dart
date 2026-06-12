// Sozlamalar ekrani — profil header, guruhlangan menyu kartalari va
// suzuvchi pastki navigatsiya.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/notifications/presentation/providers/fcm_provider.dart';
import 'package:farzandim/features/profile/data/models/parent_profile.dart';
import 'package:farzandim/features/profile/presentation/providers/profile_provider.dart';
import 'package:farzandim/features/settings/presentation/providers/language_provider.dart';
import 'package:farzandim/features/settings/presentation/providers/sessions_provider.dart';
import 'package:farzandim/shared/widgets/app_bottom_nav.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:farzandim/shared/widgets/settings_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

/// Sozlamalar bosh ekrani.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    // Boshqa qurilmalar soni (joriydan tashqari) — "Faol sessiyalar" badge'i.
    final otherSessions = ref
        .watch(sessionsProvider)
        .maybeWhen(
          data: (list) => list.where((s) => !s.isCurrent).length,
          orElse: () => 0,
        );
    final isDark = AppColors.isDark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _ProfileHeader(profile: profile),
              // Menyu scroll'i butun bo'shliqni egallaydi; AppBottomNav uning
              // ustida suzadi — orqa gradient uzluksiz ko'rinadi.
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          AppDimensions.lg,
                          AppDimensions.sm,
                          AppDimensions.lg,
                          AppDimensions.lg +
                              AppBottomNav.kBarHeight +
                              AppDimensions.md +
                              8,
                        ),
                        child: Column(
                          children: [
                            // ── Karta 1: bola ──
                            _MenuCard(
                              accent: AppColors.secondary,
                              items: [
                                _MenuItem(
                                  icon: Icons.person_add_alt_1_rounded,
                                  title: 'settings.menu.addChild'.tr(),
                                  onTap: () => context.push(AppRoutes.addChild),
                                ),
                                _MenuItem(
                                  icon: Icons.edit_rounded,
                                  title: 'settings.menu.editChild'.tr(),
                                  onTap: () =>
                                      context.push(AppRoutes.settingsChildren),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppDimensions.md),
                            // ── Karta 2: SOS / sessiyalar / til / yordam ──
                            _MenuCard(
                              accent: AppColors.accent,
                              items: [
                                _MenuItem(
                                  icon: Icons.sos_rounded,
                                  title: 'settings.menu.sosAlerts'.tr(),
                                  onTap: () =>
                                      context.push(AppRoutes.sosAlerts),
                                ),
                                _MenuItem(
                                  icon: Icons.devices_rounded,
                                  title: 'settings.menu.sessions'.tr(),
                                  badge: otherSessions > 0
                                      ? '$otherSessions'
                                      : null,
                                  onTap: () =>
                                      context.push(AppRoutes.settingsSessions),
                                ),
                                _MenuItem(
                                  icon: Icons.language_rounded,
                                  title: 'settings.menu.language'.tr(),
                                  onTap: () =>
                                      _showLanguageDialog(context, ref),
                                ),
                                _MenuItem(
                                  icon: Icons.help_outline_rounded,
                                  title: 'settings.menu.support'.tr(),
                                  onTap: () => context.push(AppRoutes.support),
                                ),
                                _MenuItem(
                                  icon: Icons.info_outline_rounded,
                                  title: 'settings.menu.about'.tr(),
                                  onTap: () =>
                                      context.push(AppRoutes.settingsAbout),
                                ),
                                _MenuItem(
                                  icon: Icons.share_rounded,
                                  title: 'settings.menu.share'.tr(),
                                  onTap: _shareApp,
                                ),
                                _MenuItem(
                                  icon: Icons.notifications_active_rounded,
                                  title: 'settings.pushTest.menuTitle'.tr(),
                                  onTap: () => _sendTestPush(context, ref),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Fade scrim — nav ortidagi kontent yumshoq so'nadi:
                    // pastga qarab shaffofdan fon rangiga o'tadi.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 110,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.background.withValues(alpha: 0),
                                AppColors.background.withValues(
                                  alpha: isDark ? 0.35 : 0.25,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Suzuvchi nav — fonsiz (shaffof), gradient ustida
                    // qalqaydi va glass kartalar bilan bir uslubda.
                    Positioned(
                      left: AppDimensions.lg,
                      right: AppDimensions.lg,
                      bottom: AppDimensions.md,
                      child: AppBottomNav(
                        activeIndex: 1,
                        activityLabel: 'dashboard.usageTime'.tr(),
                        settingsLabel: 'settings.title'.tr(),
                        onActivity: () => context.pop(),
                        onSettings: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Ulashish ───

  Future<void> _shareApp() async {
    await Share.share('settings.shareText'.tr());
  }

  // ─── Push diagnostikasi ───
  //
  // Backend o'ziga test push yuborib natijani qaytaradi. tokens=0 bo'lsa
  // qurilma ro'yxatdan o'tmagan; sent>0 lekin push kelmasa bildirishnoma
  // ruxsati muammosi; failed>0 bo'lsa server tomonda Firebase xatosi.
  Future<void> _sendTestPush(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('settings.pushTest.sending'.tr())),
    );

    final res = await ref.read(fcmServiceProvider).sendTestPush();
    if (!context.mounted) return;

    final String title;
    final String body;
    if (res == null) {
      title = 'settings.pushTest.requestFailedTitle'.tr();
      body = 'settings.pushTest.requestFailedBody'.tr();
    } else {
      final tokens = (res['tokens'] as num?)?.toInt() ?? 0;
      final sent = (res['sent'] as num?)?.toInt() ?? 0;
      final failed = (res['failed'] as num?)?.toInt() ?? 0;
      if (tokens == 0) {
        title = 'settings.pushTest.noTokenTitle'.tr();
        body = 'settings.pushTest.noTokenBody'.tr();
      } else if (sent > 0) {
        title = 'settings.pushTest.sentTitle'.tr();
        body = 'settings.pushTest.sentBody'.tr(
          namedArgs: {'tokens': '$tokens', 'sent': '$sent'},
        );
      } else {
        title = 'settings.pushTest.serverFailedTitle'.tr();
        body = 'settings.pushTest.serverFailedBody'.tr(
          namedArgs: {
            'tokens': '$tokens',
            'sent': '$sent',
            'failed': '$failed',
          },
        );
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          title,
          style: AppTextStyles.headlineL.copyWith(fontSize: 18),
        ),
        content: Text(body, style: AppTextStyles.bodyM),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('common.ok'.tr()),
          ),
        ],
      ),
    );
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final lang in AppLanguage.values)
              _LanguageOption(
                language: lang,
                isSelected:
                    lang == AppLanguage.fromCode(context.locale.languageCode),
                onTap: () async {
                  await context.setLocale(lang.locale);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════ PROFILE HEADER ════════════════════════

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final ParentProfile profile;

  @override
  Widget build(BuildContext context) {
    // Telefon bilan ro'yxatdan o'tgan bo'lsa telefon, aks holda email.
    final identifier = _identifier(profile);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.lg,
        AppDimensions.md,
        AppDimensions.md,
        AppDimensions.sm,
      ),
      child: Row(
        children: [
          _Avatar(photoUrl: profile.photoUrl, name: profile.name),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  profile.name.isNotEmpty
                      ? profile.name
                      : 'settings.profile.placeholder'.tr(),
                  style: AppTextStyles.headlineL.copyWith(fontSize: 18),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (identifier != null) ...[
                  const SizedBox(height: 6),
                  _IdentifierPill(text: identifier),
                ],
              ],
            ),
          ),
          const _OverflowMenu(),
        ],
      ),
    );
  }

  String? _identifier(ParentProfile p) {
    if (p.phoneNumber != null && p.phoneNumber!.trim().isNotEmpty) {
      return p.phoneNumber!.trim();
    }
    if (p.email != null && p.email!.trim().isNotEmpty) {
      return p.email!.trim();
    }
    return null;
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.photoUrl, required this.name});

  final String? photoUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceVariant,
        border: Border.all(color: AppColors.border),
        image: hasPhoto
            ? DecorationImage(image: NetworkImage(photoUrl!), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: hasPhoto
          ? null
          : Text(
              _initials(name),
              style: AppTextStyles.headlineL.copyWith(
                fontSize: 18,
                color: AppColors.accent,
              ),
            ),
    );
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '👤';
    final parts = trimmed.split(RegExp(r'\s+'));
    final first = parts.first.characters.first;
    final second = parts.length > 1 ? parts[1].characters.first : '';
    return (first + second).toUpperCase();
  }
}

class _IdentifierPill extends StatelessWidget {
  const _IdentifierPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Text(
        text,
        style: AppTextStyles.bodyS.copyWith(
          color: AppColors.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OverflowMenu extends ConsumerWidget {
  const _OverflowMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: AppColors.textPrimary),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      onSelected: (value) {
        switch (value) {
          case 'logout':
            _showLogoutDialog(context, ref);
          case 'delete':
            context.push(AppRoutes.settingsDeleteAccount);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(
                Icons.logout_rounded,
                color: AppColors.textPrimary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text('settings.logout.button'.tr(), style: AppTextStyles.bodyM),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'settings.deleteAccount'.tr(),
                style: AppTextStyles.bodyM.copyWith(color: AppColors.error),
              ),
            ],
          ),
        ),
      ],
    );
  }

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
          style: AppTextStyles.bodyS.copyWith(color: AppColors.textSecondary),
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
              try {
                await ref.read(fcmServiceProvider).removeTokenForCurrentUser();
              } catch (_) {
                // token o'chirish xatosi logout'ni to'xtatmasin.
              }
              await ref.read(backendAuthProvider.notifier).logout();
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

// ════════════════════════ MENU CARD / ITEM ════════════════════════

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.items, required this.accent});
  final List<_MenuItem> items;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      accent: accent,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            items[i],
            if (i != items.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                indent: 56,
                color: AppColors.divider,
              ),
          ],
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: 16,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.textPrimary),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.bodyM,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (badge != null) ...[
              Container(
                constraints: const BoxConstraints(minWidth: 22),
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  color: AppColors.info,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                ),
                alignment: Alignment.center,
                child: Text(
                  badge!,
                  style: AppTextStyles.label.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
            ],
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 22,
            ),
          ],
        ),
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
            Expanded(child: Text(language.label, style: AppTextStyles.bodyM)),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.accent, size: 20),
          ],
        ),
      ),
    );
  }
}
