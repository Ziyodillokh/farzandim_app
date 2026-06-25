import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Welcome ekran — Parvoz dizayni.
///
/// To'liq ekran fon rasmi (ota va farzand) + pastga to'qlashuvchi gradient,
/// tepada brend, pastda sarlavha + ko'k "Ro'yxatdan o'tish" va shisha
/// "Kirish" tugmalari.
///
/// Fon rasmi: `assets/images/welcome_bg_parvoz.jpg` (Figma'dan eksport qilib
/// shu yo'lga joylang). Topilmasa to'q ko'k-qora gradient fallback ko'rinadi.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Auth hali aniqlanmagan bo'lsa (cold start) — yengil splash. Login bo'lgan
    // foydalanuvchi welcome "flash"ini ko'rmaydi (router dashboard'ga otadi).
    final auth = ref.watch(backendAuthProvider);
    if (auth is AuthUnknown) {
      return const Scaffold(
        backgroundColor: ParvozColors.bg,
        body: Center(child: ParvozBrandLogo()),
      );
    }

    // Fon rasmni ekran kengligida dekod qilamiz (2 MB JPG to'liq o'lchamda
    // ortiqcha xotira yemasin) — MEM-4 tavsiyasi.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final bgWidth = (MediaQuery.sizeOf(context).width * dpr).round();

    return Scaffold(
      backgroundColor: ParvozColors.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Qatlam 1: fon rasmi (topilmasa to'q gradient).
          Image.asset(
            'assets/images/welcome_bg_parvoz.jpg',
            fit: BoxFit.cover,
            cacheWidth: bgWidth,
            errorBuilder: (_, __, ___) => const _BgFallback(),
          ),
          // Qatlam 2: pastga to'qlashuvchi gradient — matn o'qilishi uchun.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x0002060D),
                  Color(0x1A02060D),
                  Color(0xE602060D),
                  Color(0xFF02060D),
                ],
                stops: [0, 0.4, 0.78, 1],
              ),
            ),
          ),
          // Qatlam 3: mazmun.
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
                const ParvozBrandLogo(),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'auth.welcome.title'.tr(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.unbounded(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'auth.welcome.subtitle'.tr(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          height: 1.45,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 28),
                      ParvozPrimaryButton(
                        label: 'auth.welcome.signUpButton'.tr(),
                        onPressed: () => context.push(AppRoutes.signUp),
                      ),
                      const SizedBox(height: 12),
                      ParvozSecondaryButton(
                        label: 'auth.welcome.signInButton'.tr(),
                        onPressed: () => context.push(AppRoutes.signIn),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fon rasmi topilmaganda — to'q ko'k-qora gradient.
class _BgFallback extends StatelessWidget {
  const _BgFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B1B33), ParvozColors.bg],
        ),
      ),
    );
  }
}
