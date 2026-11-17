// A01 · Xush kelibsan: ilova birinchi ochilganda — Parvoz sharchasi, bir
// qatorli salomlashuv, til tanlovi (eslab qolinadi) va «Boshlash» → A02.
// Orqaga tugmasi yo'q. Qoraqalpoq interfeysi tarjima tayyor bo'lgach qo'shiladi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/onboarding/presentation/screens/language_select_screen.dart'
    show kLanguagePickedKey;
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _languages = ['uz', 'ru', 'en'];

class KirishWelcomeScreen extends StatelessWidget {
  const KirishWelcomeScreen({super.key});

  Future<void> _start(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kLanguagePickedKey, true);
    if (context.mounted) context.go(GrowthV5Routes.kirishLogin);
  }

  @override
  Widget build(BuildContext context) {
    final current = context.locale.languageCode;
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.blue,
        dock: GButton(
          label: 'g5.kirish.welcome.start'.tr(),
          size: GButtonSize.xl,
          trailingIcon: GIcons.arrowRight,
          onPressed: () => _start(context),
        ),
        children: [
          const SizedBox(height: 28),
          const Center(child: _Orb()),
          const SizedBox(height: 8),
          Semantics(
            header: true,
            child: Text(
              'g5.kirish.welcome.title'.tr(),
              textAlign: TextAlign.center,
              style: GText.display(30),
            ),
          ),
          Text(
            'g5.kirish.welcome.subtitle'.tr(),
            textAlign: TextAlign.center,
            style: GText.body,
          ),
          const SizedBox(height: 8),
          GSection(
            title: 'g5.kirish.welcome.language'.tr(),
            child: Column(
              children: [
                for (final code in _languages) ...[
                  GOption(
                    label: 'g5.men.settings.langNames.$code'.tr(),
                    selected: code == current,
                    onTap: () => context.setLocale(Locale(code)),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Parvoz qanot belgisi nurli shar ichida.
class _Orb extends StatelessWidget {
  const _Orb();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 148,
      height: 148,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0x664F86FF), Color(0x142F5BEA), Color(0x00000000)],
          stops: [0, .62, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: GColors.primary.withValues(alpha: .35),
            blurRadius: 60,
            spreadRadius: 4,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Image.asset('assets/icons/growth_logo.png', width: 96, height: 96),
    ),
  );
}
