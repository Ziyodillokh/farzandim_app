import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/shared/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Welcome ekran — ilova birinchi ochilganda ko'rinadi.
///
/// Layout: 3 qatlamli `Stack`:
///   1. Fon rasmi (`welcome_bg.jpg`, BoxFit.cover)
///   2. Yuqoridan transparent → pastdan qora (60% opacity) gradient overlay
///      — matn rasmda yaxshi o'qilishi uchun
///   3. Mazmun (logo, sarlavhalar, 2 ta tugma) `SafeArea` ichida
class WelcomeScreen extends StatelessWidget {
  /// `WelcomeScreen` konstruktor.
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Stack farzand'lari to'liq ekranni egallashi uchun `expand`.
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ─── Qatlam 1: Fon rasmi ───
          Image.asset(
            'assets/images/welcome_bg.jpg',
            fit: BoxFit.cover,
          ),

          // ─── Qatlam 2: Qorong'i overlay (matn o'qilishi uchun) ───
          //
          // Yuqorida shaffof, pastda 60% qora (#99000000) — pastdagi
          // matn va tugmalar rasmni ortib turishi uchun.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0x99000000),
                ],
              ),
            ),
          ),

          // ─── Qatlam 3: Mazmun ───
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Yuqoridan 80dp bo'shliq (status bar tagidan).
                  const SizedBox(height: 80),

                  // Brand: square brand (LOGO, yuqorida) + icon (accent, pastda)
                  Center(
                    child: Image.asset(
                      'assets/app_icon/parent_app_icon_white.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.md),
                  Center(
                    child: Image.asset(
                      'assets/icons/parent_logo_icon.png',
                      width: 80,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.lg),

                  // Asosiy sarlavha — 28sp Bold oq, markazda.
                  Text(
                    'auth.welcome.title'.tr(),
                    style: AppTextStyles.headlineXL,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.sm),

                  // Subtitle — 16sp oq, markazda.
                  Text(
                    'auth.welcome.subtitle'.tr(),
                    style: AppTextStyles.bodyM,
                    textAlign: TextAlign.center,
                  ),

                  // Bo'sh joy — tugmalarni pastga "itarib" yuboradi.
                  const Spacer(),

                  // Yagona auth yo'li — Telegram Login.
                  // Sprint 4.4 backend migratsiyasidan keyin alohida
                  // Sign Up / Sign In ekranlari olib tashlangan: Telegram
                  // orqali kirish ham ro'yxatdan o'tish, ham kirishni qamraydi.
                  PrimaryButton(
                    label: 'auth.welcome.continueButton'.tr(),
                    onPressed: () => context.push(AppRoutes.telegramLogin),
                  ),

                  // Pastki bo'shliq — bottom safe area'dan tashqari 32dp.
                  const SizedBox(height: AppDimensions.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
