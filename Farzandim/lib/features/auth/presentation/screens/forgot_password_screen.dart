import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:farzandim/shared/widgets/custom_text_field.dart';
import 'package:farzandim/shared/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Parolni tiklash — hozircha UI stub.
///
/// Tiklash oqimi (SMS/email orqali kod yuborish) keyinroq backendga ulanadi.
/// Hozir tugma bosilganda "tez orada" xabari ko'rsatiladi.
class ForgotPasswordScreen extends StatefulWidget {
  /// `ForgotPasswordScreen` konstruktor.
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _comingSoon() {
    FocusScope.of(context).unfocus();
    AppToast.info(context, 'auth.social.comingSoon'.tr());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AuthBackButton(),
      ),
      body: SafeArea(
        top: false,
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
                'auth.forgotPassword.title'.tr(),
                style: AppTextStyles.headlineXL.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.md),
              Text(
                'auth.forgotPassword.subtitle'.tr(),
                style: AppTextStyles.bodyS.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.xl),

              AuthFieldLabel('auth.forgotPassword.emailLabel'.tr()),
              const SizedBox(height: AppDimensions.sm),
              CustomTextField(
                controller: _email,
                hint: 'auth.forgotPassword.emailHint'.tr(),
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppDimensions.lg),

              PrimaryButton(
                label: 'auth.forgotPassword.submitButton'.tr(),
                onPressed: _email.text.trim().isEmpty ? null : _comingSoon,
              ),
              const SizedBox(height: AppDimensions.lg),

              // ─── Esladingizmi? → Akkauntga kirish ───
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'auth.forgotPassword.remembered'.tr(),
                    style: AppTextStyles.bodyS.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(AppRoutes.signIn);
                      }
                    },
                    child: Text(
                      'auth.forgotPassword.backToSignIn'.tr(),
                      style: AppTextStyles.bodyS.copyWith(
                        color: kAuthLinkColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
