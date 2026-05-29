// ─────────────────────────────────────────────────────────────────────
// SettingsScreen — Bola Sozlamalari (Sprint UI.4)
// ─────────────────────────────────────────────────────────────────────
//
// Bo'limlar:
//   - Til tanlash (uz/ru/en) — easy_localization context.setLocale
//   - Tema (Light/Dark) — themeModeProvider
//   - Hisob — profil tahrirlash (/account-edit)
//   - Ilova haqida — versiya (package_info_plus)
//   - Maxfiylik — ZRU-547 ma'lumot
//   - Ulanishni uzish — unpair (confirm dialog)

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/core/theme/theme_mode_provider.dart';
import 'package:farzandim_child/shared/widgets/gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = '${info.version} (${info.buildNumber})');
      }
    } catch (_) {
      // Version ko'rsatilmaydi.
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final currentLocale = context.locale.languageCode;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('settings.title').tr(),
      ),
      body: GradientBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // ─── Til ───
              _SectionTitle('settings.languageSection'.tr()),
              _SettingsCard(
                children: [
                  _LanguageTile(
                    code: 'uz',
                    label: "O'zbekcha",
                    flag: '🇺🇿',
                    selected: currentLocale == 'uz',
                    onTap: () => _setLocale(const Locale('uz')),
                  ),
                  const _Divider(),
                  _LanguageTile(
                    code: 'ru',
                    label: 'Русский',
                    flag: '🇷🇺',
                    selected: currentLocale == 'ru',
                    onTap: () => _setLocale(const Locale('ru')),
                  ),
                  const _Divider(),
                  _LanguageTile(
                    code: 'en',
                    label: 'English',
                    flag: '🇬🇧',
                    selected: currentLocale == 'en',
                    onTap: () => _setLocale(const Locale('en')),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ─── Tema ───
              _SectionTitle('settings.themeSection'.tr()),
              _SettingsCard(
                children: [
                  _SwitchTile(
                    icon: isDark
                        ? AppIcons.hourglass
                        : AppIcons.star,
                    iconColor: isDark
                        ? AppColors.secondary
                        : AppColors.accent,
                    title: 'settings.darkMode'.tr(),
                    subtitle: 'settings.darkModeHint'.tr(),
                    value: isDark,
                    onChanged: (_) =>
                        ref.read(themeModeProvider.notifier).toggle(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ─── Hisob ───
              _SectionTitle('settings.accountSection'.tr()),
              _SettingsCard(
                children: [
                  _NavTile(
                    icon: AppIcons.profile,
                    iconColor: AppColors.secondary,
                    title: 'settings.editProfile'.tr(),
                    onTap: () => context.push('/account-edit'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ─── Ilova haqida ───
              _SectionTitle('settings.aboutSection'.tr()),
              _SettingsCard(
                children: [
                  _InfoTile(
                    icon: AppIcons.info,
                    iconColor: AppColors.secondary,
                    title: 'settings.appVersion'.tr(),
                    value: _version,
                  ),
                  const _Divider(),
                  _InfoTile(
                    icon: AppIcons.privacy,
                    iconColor: AppColors.success,
                    title: 'settings.privacy'.tr(),
                    value: 'settings.privacyValue'.tr(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setLocale(Locale locale) async {
    await context.setLocale(locale);
    if (mounted) setState(() {});
  }
}

// ════════════════════════ KICHIK WIDGET'LAR ════════════════════════

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      color: AppColors.divider,
      indent: 56,
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.code,
    required this.label,
    required this.flag,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final String label;
  final String flag;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      trailing: selected
          ? const Icon(AppIcons.check, color: AppColors.primary, size: 22)
          : null,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.primary,
      secondary: _IconBox(icon: icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: _IconBox(icon: icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      trailing: Icon(
        AppIcons.chevronRight,
        size: 18,
        color: AppColors.textTertiary,
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _IconBox(icon: icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 140),
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
