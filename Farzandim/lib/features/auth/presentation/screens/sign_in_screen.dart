import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/auth/presentation/screens/scan_account_screen.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

/// Akkauntga kirish — Parvoz dizayni (email/telefon + parol).
///
/// Backend: POST /api/auth/login. Muvaffaqiyatda auth state Authenticated'ga
/// o'tadi va router avtomatik dashboard'ga yo'naltiradi.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _identifier.text.trim().isNotEmpty && _password.text.isNotEmpty;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    final err = await ref
        .read(backendAuthProvider.notifier)
        .loginWithPassword(
          identifier: _identifier.text.trim(),
          password: _password.text,
        );

    if (!mounted) return;
    if (err != null) {
      setState(() {
        _loading = false;
        _error = err;
      });
    }
    // Muvaffaqiyat: router redirect (Authenticated) dashboard'ga olib o'tadi.
  }

  /// Google/Apple bilan kirish. Backend "yangi bo'lsa yarat, bor bo'lsa kirgiz"
  /// qiladi. MUHIM: Google orqali ro'yxatdan o'tganlarning paroli yo'q — ular
  /// FAQAT shu tugmalar orqali qaytib kira oladi.
  Future<void> _social(Future<String?> Function() action) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await action();
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _loading = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ParvozColors.bg,
      body: Stack(
        children: [
          const Positioned(
            top: -150,
            left: 0,
            right: 0,
            child: Center(child: ParvozTopGlow()),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'auth.signIn.title'.tr(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.unbounded(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'auth.signIn.subtitle'.tr(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      height: 1.45,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ─── Email / telefon ───
                  ParvozTextField(
                    label: 'auth.signIn.emailLabel'.tr(),
                    controller: _identifier,
                    hint: 'auth.signIn.emailHint'.tr(),
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),

                  // ─── Parol ───
                  ParvozTextField(
                    label: 'auth.signIn.passwordLabel'.tr(),
                    controller: _password,
                    hint: 'auth.signIn.passwordHint'.tr(),
                    obscure: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),

                  // ─── Parolni unutdingizmi? (chap, ko'k) ───
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => context.push(AppRoutes.forgotPassword),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'auth.signIn.forgotPassword'.tr(),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: ParvozColors.blue,
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          SolarIconsBold.dangerCircle,
                          size: 16,
                          color: Color(0xFFFF6B6B),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _error!,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: const Color(0xFFFF6B6B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ─── Asosiy: Kirish (ko'k) ───
                  ParvozPrimaryButton(
                    label: 'auth.signIn.submitButton'.tr(),
                    loading: _loading,
                    enabled: _canSubmit,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 12),

                  // ─── Apple / Google (shisha) ───
                  Row(
                    children: [
                      Expanded(
                        child: ParvozSecondaryButton(
                          label: 'auth.social.apple'.tr(),
                          enabled: !_loading,
                          leading: SvgPicture.asset(
                            'assets/icons/ic_apple_mark.svg',
                            width: 20,
                            height: 20,
                          ),
                          onPressed: () => _social(
                            ref
                                .read(backendAuthProvider.notifier)
                                .signInWithApple,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ParvozSecondaryButton(
                          label: 'auth.social.google'.tr(),
                          enabled: !_loading,
                          leading: SvgPicture.asset(
                            'assets/icons/ic_google_mark.svg',
                            width: 20,
                            height: 20,
                          ),
                          onPressed: () => _social(
                            ref
                                .read(backendAuthProvider.notifier)
                                .signInWithGoogle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ─── Ikkilamchi: Akkauntga qo'shilish (QR kamera skaner) ───
                  ParvozSecondaryButton(
                    label: 'auth.signIn.signUpButton'.tr(),
                    enabled: !_loading,
                    leading: const Icon(
                      SolarIconsBold.qrCode,
                      size: 22,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ScanAccountScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, top: 4),
                child: ParvozBackButton(
                  onTap: () => context.canPop()
                      ? context.pop()
                      : context.go(AppRoutes.welcome),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
