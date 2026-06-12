import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/auth/presentation/screens/scan_account_screen.dart';
import 'package:farzandim/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:farzandim/shared/widgets/custom_text_field.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:farzandim/shared/widgets/password_text_field.dart';
import 'package:farzandim/shared/widgets/primary_button.dart';
import 'package:farzandim/shared/widgets/secondary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Akkauntga kirish — email yoki telefon + parol.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AuthBackButton(),
      ),
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.lg,
              AppDimensions.sm,
              AppDimensions.lg,
              AppDimensions.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppDimensions.sm),
                Text(
                  'auth.signIn.title'.tr(),
                  style: AppTextStyles.headlineXL.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.xl + AppDimensions.sm),

                // ─── Email / telefon ───
                AuthFieldLabel('auth.signIn.emailLabel'.tr()),
                const SizedBox(height: AppDimensions.sm),
                CustomTextField(
                  controller: _identifier,
                  hint: 'auth.signIn.emailHint'.tr(),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppDimensions.lg),

                // ─── Parol ───
                AuthFieldLabel('auth.signIn.passwordLabel'.tr()),
                const SizedBox(height: AppDimensions.sm),
                PasswordTextField(
                  controller: _password,
                  hint: '••••••',
                  onChanged: (_) => setState(() {}),
                ),

                // ─── Parolni unutdingizmi? ───
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push(AppRoutes.forgotPassword),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimensions.sm,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'auth.signIn.forgotPassword'.tr(),
                      style: AppTextStyles.bodyS.copyWith(
                        color: kAuthLinkColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: AppDimensions.sm),
                  AuthErrorText(_error!),
                ],

                const SizedBox(height: AppDimensions.md),

                // ─── Asosiy: Akkauntga kirish ───
                PrimaryButton(
                  label: 'auth.signIn.submitButton'.tr(),
                  isLoading: _loading,
                  onPressed: _canSubmit && !_loading ? _submit : null,
                ),
                const SizedBox(height: AppDimensions.sm + AppDimensions.xs),

                // ─── Ikkilamchi: Akkauntga qo'shilish (QR kamera skaner) ───
                // Asosiy qurilmaning QR kodini skanerlab, 2-qurilma sifatida
                // kiradi. MaterialPageRoute (go_router stack'iga tegmasdan).
                SecondaryButton(
                  label: 'auth.signIn.signUpButton'.tr(),
                  icon: Icons.qr_code_scanner_rounded,
                  onPressed: _loading
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ScanAccountScreen(),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
