import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/shared/widgets/primary_button.dart';
import 'package:farzandim/shared/widgets/secondary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Welcome ekran — ilova birinchi ochilganda ko'rinadi.
///
/// Figma'ga mos layout: to'liq ekran fon rasmi, ustida pastga to'qlashuvchi
/// gradient va mazmun (yurak logo, sarlavhalar, ikkita tugma).
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Auth hali aniqlanmagan bo'lsa (cold start, bootstrap ketmoqda) og'ir
    // welcome_bg.jpg (325KB) dekod qilinmasin deb yengil splash ko'rsatamiz.
    // Login bo'lgan user shu tufayli welcome "flash"ini ko'rmaydi —
    // bootstrap tugashi bilan router dashboard'ga redirect qiladi.
    final auth = ref.watch(backendAuthProvider);
    if (auth is AuthUnknown) {
      return const Scaffold(
        backgroundColor: Color(0xFF14101A),
        body: Center(
          child: Text(
            'Farzandim',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
      );
    }

    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ─── Qatlam 1: Fon rasmi ───
          Image.asset(
            'assets/images/welcome_bg.jpg',
            fit: BoxFit.cover,
            // Rasm yuklanmasa, to'q fon — oq ekran ko'rinmasin.
            errorBuilder: (_, __, ___) =>
                const ColoredBox(color: Color(0xFF14101A)),
          ),

          // ─── Qatlam 2: Gradient overlay ───
          //
          // Yuqorida rasm to'liq ko'rinadi (shaffof), pastga qarab
          // to'qlashadi — matn va tugmalar yaxshi o'qilishi uchun.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Color(0x59000000), // ~35% qora
                  Color(0xCC000000), // ~80% qora (tugmalar ortida)
                ],
                stops: [0.0, 0.42, 0.72, 1.0],
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
                  // Hero blok ekran balandligining ~11% pastida boshlanadi
                  // (status bar tagidan) — Figma'dagi vertikal joylashuv.
                  SizedBox(height: size.height * 0.11),

                  // ─── Brand: yurak logo ───
                  // Kulrang, biroz egilgan (~8°), yarim shaffof — silver.
                  const Center(child: _HeartLogo()),
                  const SizedBox(height: AppDimensions.xl),

                  // ─── Asosiy sarlavha — Bold oq, markazda ───
                  Text(
                    'auth.welcome.title'.tr(),
                    style: AppTextStyles.headlineXL.copyWith(
                      fontWeight: FontWeight.w800,
                      shadows: const [
                        Shadow(
                          color: Color(0x66000000),
                          blurRadius: 16,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.sm),

                  // ─── Subtitle — oq, markazda ───
                  Text(
                    'auth.welcome.subtitle'.tr(),
                    style: AppTextStyles.bodyM.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      shadows: const [
                        Shadow(
                          color: Color(0x4D000000),
                          blurRadius: 12,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Bo'sh joy — tugmalarni pastga "itarib" yuboradi.
                  const Spacer(),

                  // ─── Asosiy tugma — "Ro'yxatdan o'tish" (lime green) ───
                  PrimaryButton(
                    label: 'auth.welcome.signUpButton'.tr(),
                    onPressed: () => context.push(AppRoutes.signUp),
                  ),
                  const SizedBox(height: AppDimensions.sm + AppDimensions.xs),

                  // ─── Ikkilamchi tugma — "Akkauntga kirish" (shaffof) ───
                  SecondaryButton(
                    label: 'auth.welcome.signInButton'.tr(),
                    onPressed: () => context.push(AppRoutes.signIn),
                  ),

                  // Pastki bo'shliq — bottom safe area'dan tashqari.
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

/// Welcome ekrandagi brand mark — Figma'dagi silver yurak: kulrang gradient,
/// ~8° egilish va yumshoq soya.
class _HeartLogo extends StatelessWidget {
  const _HeartLogo();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      // ~8 daraja soat strelkasi yo'nalishida.
      angle: 8 * math.pi / 180,
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEDEDF2), Color(0xFFAFAFBC)],
        ).createShader(bounds),
        blendMode: BlendMode.srcIn,
        child: const Opacity(
          opacity: 0.9,
          child: Icon(
            Icons.favorite_rounded,
            size: 66,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Color(0x59000000),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
