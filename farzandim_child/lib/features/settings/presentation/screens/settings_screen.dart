// ─────────────────────────────────────────────────────────────────────
// SettingsScreen — Bola Sozlamalari (Parvoz UI Redesign — NIGHT, Premium)
// ─────────────────────────────────────────────────────────────────────
//
// Google Stitch "Sozlamalar (Night) - Premium Edition" dizayniga moslab.
// Bo'limlar (har biri: kulrang label + parvoz karta):
//   - TIL — uz/ru/en (context.setLocale, tanlanganda yashil check)
//   - KO'RINISH — Tungi rejim toggle (themeModeProvider)
//   - HISOB — Profilni tahrirlash (/account-edit), Qiziqishlar (sheet)
//   - ILOVA HAQIDA — versiya (package_info), Maxfiylik (ZRU-547)
//
// Faqat NIGHT (parvoz tokenlar). Light mode keyin alohida. Funksiyalar
// o'zgarmadi — faqat ko'rinish Premium'ga ko'chirildi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/core/theme/theme_mode_provider.dart';
import 'package:farzandim_child/features/onboarding/presentation/widgets/interests_edit_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Icon-badge ko'k aksenti (Stitch secondary-fixed-dim).
const Color _kBadgeBlue = Color(0xFFADC6FF);

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
      backgroundColor: AppColors.parvozBg,
      body: Column(
        children: [
          _Header(
            title: 'settings.title'.tr(),
            onBack: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
              }
            },
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                // ─── TIL ───
                _SectionLabel('settings.languageSection'.tr()),
                _SettingsCard(
                  children: [
                    _LangRow(
                      code: 'UZ',
                      label: "O'zbekcha",
                      selected: currentLocale == 'uz',
                      onTap: () => _setLocale(const Locale('uz')),
                    ),
                    const _RowDivider(),
                    _LangRow(
                      code: 'RU',
                      label: 'Русский',
                      selected: currentLocale == 'ru',
                      onTap: () => _setLocale(const Locale('ru')),
                    ),
                    const _RowDivider(),
                    _LangRow(
                      code: 'EN',
                      label: 'English',
                      selected: currentLocale == 'en',
                      onTap: () => _setLocale(const Locale('en')),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── KO'RINISH ───
                _SectionLabel('settings.themeSection'.tr()),
                _SettingsCard(
                  children: [
                    _ToggleRow(
                      icon: Icons.dark_mode_rounded,
                      iconColor: _kBadgeBlue,
                      title: 'settings.darkMode'.tr(),
                      subtitle: 'settings.darkModeHint'.tr(),
                      value: isDark,
                      onChanged: (_) =>
                          ref.read(themeModeProvider.notifier).toggle(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── HISOB ───
                _SectionLabel('settings.accountSection'.tr()),
                _SettingsCard(
                  children: [
                    _NavRow(
                      icon: Icons.person_rounded,
                      iconColor: _kBadgeBlue,
                      title: 'settings.editProfile'.tr(),
                      onTap: () => context.push('/account-edit'),
                    ),
                    const _RowDivider(),
                    _NavRow(
                      icon: Icons.interests_rounded,
                      iconColor: AppColors.parvozGreen,
                      title: 'onboarding.interests.editTitle'.tr(),
                      onTap: () => InterestsEditSheet.show(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── ILOVA HAQIDA ───
                _SectionLabel('settings.aboutSection'.tr()),
                _SettingsCard(
                  children: [
                    _InfoRow(
                      icon: Icons.info_rounded,
                      iconColor: _kBadgeBlue,
                      title: 'settings.appVersion'.tr(),
                      value: _version,
                    ),
                    const _RowDivider(),
                    _InfoRow(
                      icon: Icons.shield_rounded,
                      iconColor: AppColors.parvozGreen,
                      title: 'settings.privacy'.tr(),
                      value: 'settings.privacyValue'.tr(),
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

  Future<void> _setLocale(Locale locale) async {
    await context.setLocale(locale);
    if (mounted) setState(() {});
  }
}

// ════════════════════════ WIDGET'LAR ════════════════════════

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.parvozBorder),
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: onBack,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.parvozText,
                  size: 24,
                ),
              ),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.parvozText,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.parvozTextDim,
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
        color: AppColors.parvozSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.parvozBorderStrong),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: AppColors.parvozBorderStrong,
      indent: 72,
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

/// Bosiladigan qatorni Material + InkWell bilan o'raydi (ripple).
Widget _tappable({required Widget child, VoidCallback? onTap}) {
  if (onTap == null) return child;
  return Material(
    color: Colors.transparent,
    child: InkWell(onTap: onTap, child: child),
  );
}

const _kTitleStyle = TextStyle(
  color: AppColors.parvozText,
  fontSize: 16,
  fontWeight: FontWeight.w700,
);

const _kValueStyle = TextStyle(
  color: AppColors.parvozTextDim,
  fontSize: 13,
);

class _LangRow extends StatelessWidget {
  const _LangRow({
    required this.code,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _tappable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.parvozSurfaceHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.parvozBorderStrong),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  color: AppColors.parvozTextDim,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.parvozText,
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded,
                  color: AppColors.parvozGreen, size: 22),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _IconBadge(icon: icon, color: iconColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _kTitleStyle),
                const SizedBox(height: 2),
                Text(subtitle, style: _kValueStyle),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.parvozGreen,
            inactiveThumbColor: AppColors.parvozTextDim,
            inactiveTrackColor: AppColors.parvozSurfaceHigh,
            trackOutlineColor:
                WidgetStateProperty.all(AppColors.parvozBorderStrong),
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
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
    return _tappable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _IconBadge(icon: icon, color: iconColor),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: _kTitleStyle)),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.parvozTextDim, size: 22),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _IconBadge(icon: icon, color: iconColor),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: _kTitleStyle)),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: _kValueStyle,
            ),
          ),
        ],
      ),
    );
  }
}
