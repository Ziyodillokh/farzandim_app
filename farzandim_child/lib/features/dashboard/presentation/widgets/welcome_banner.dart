// ─────────────────────────────────────────────────────────────────────
// WelcomeBanner — vaqt-aware greeting + sana
// ─────────────────────────────────────────────────────────────────────
//
// Soatga qarab "Xayrli tong/kun/kech" tabriklash + bugungi sana
// ("Bugun chorshanba, 14 may"). Lokalizatsiya: uz/ru/en.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class WelcomeBanner extends StatelessWidget {
  const WelcomeBanner({required this.childName, super.key});

  final String childName;

  String _greetingKey() {
    final h = DateTime.now().hour;
    if (h < 6) return 'dashboard.greetingNight';
    if (h < 12) return 'dashboard.greetingMorning';
    if (h < 17) return 'dashboard.greetingDay';
    if (h < 22) return 'dashboard.greetingEvening';
    return 'dashboard.greetingNight';
  }

  String _formattedDate(BuildContext context) {
    final now = DateTime.now();
    final locale = context.locale.languageCode;
    // easy_localization 'uz' → intl uchun 'uz_UZ' kerak.
    final intlLocale = switch (locale) {
      'ru' => 'ru_RU',
      'en' => 'en_US',
      _ => 'uz_UZ',
    };
    try {
      final fmt = DateFormat('EEEE, d MMMM', intlLocale);
      return 'dashboard.todayDate'.tr(namedArgs: {'date': fmt.format(now)});
    } catch (_) {
      // Locale data yuklanmagan bo'lsa fallback default formatga.
      return 'dashboard.todayDate'.tr(
        namedArgs: {'date': DateFormat.yMMMMd().format(now)},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _greetingKey().tr(namedArgs: {'name': childName}),
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _formattedDate(context),
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      ],
    );
  }
}
