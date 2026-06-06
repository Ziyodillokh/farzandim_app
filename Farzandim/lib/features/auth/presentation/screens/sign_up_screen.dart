import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:farzandim/shared/widgets/custom_text_field.dart';
import 'package:farzandim/shared/widgets/password_text_field.dart';
import 'package:farzandim/shared/widgets/primary_button.dart';
import 'package:farzandim/shared/widgets/social_button.dart';
import 'package:farzandim/shared/widgets/tab_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ro'yxatdan o'tish — telefon yoki email + parol.
///
/// Tab orqali telefon (+998) yoki email tanlanadi. Backend: POST
/// /api/auth/register. Apple/Google tugmalari hozircha UI'da (tez orada).
class SignUpScreen extends ConsumerStatefulWidget {
  /// `SignUpScreen` konstruktor.
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  /// 0 = telefon, 1 = email.
  int _activeTab = 0;

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  bool get _isPhone => _activeTab == 0;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty) {
      return false;
    }
    if (_password.text.length < 6) return false;
    if (_isPhone) {
      return _phone.text.trim().length == 9;
    }
    final email = _email.text.trim();
    return email.contains('@') && email.contains('.');
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    final notifier = ref.read(backendAuthProvider.notifier);
    final fullName =
        '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim();
    final err = _isPhone
        ? await notifier.registerWithPassword(
            phone: '+998${_phone.text.trim()}',
            password: _password.text,
            name: fullName,
          )
        : await notifier.registerWithPassword(
            email: _email.text.trim(),
            password: _password.text,
            name: fullName,
          );

    if (!mounted) return;
    if (err != null) {
      setState(() {
        _loading = false;
        _error = err;
      });
    }
    // Muvaffaqiyat: router redirect dashboard'ga olib o'tadi.
  }

  void _socialComingSoon() {
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
                'auth.signUp.title'.tr(),
                style: AppTextStyles.headlineXL.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.xl),

              // ─── Ism + Familiya ───
              AuthFieldLabel('auth.signUp.firstNameLabel'.tr()),
              const SizedBox(height: AppDimensions.sm),
              CustomTextField(
                controller: _firstName,
                hint: 'auth.signUp.firstNameHint'.tr(),
                keyboardType: TextInputType.name,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppDimensions.lg),
              AuthFieldLabel('auth.signUp.lastNameLabel'.tr()),
              const SizedBox(height: AppDimensions.sm),
              CustomTextField(
                controller: _lastName,
                hint: 'auth.signUp.lastNameHint'.tr(),
                keyboardType: TextInputType.name,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppDimensions.lg),

              // ─── Tab: Telefon / Email ───
              TabSwitcher(
                tabs: [
                  'auth.signUp.phoneTab'.tr(),
                  'auth.signUp.emailTab'.tr(),
                ],
                activeIndex: _activeTab,
                onChanged: (i) => setState(() {
                  _activeTab = i;
                  _error = null;
                }),
              ),
              const SizedBox(height: AppDimensions.lg),

              // ─── Identifikator maydoni (telefon yoki email) ───
              if (_isPhone) ...[
                AuthFieldLabel('auth.signUp.phoneLabel'.tr()),
                const SizedBox(height: AppDimensions.sm),
                CustomTextField(
                  controller: _phone,
                  hint: 'auth.signUp.phoneHint'.tr(),
                  prefix: '+998 ',
                  keyboardType: TextInputType.phone,
                  maxLength: 9,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
              ] else ...[
                AuthFieldLabel('auth.signUp.emailLabel'.tr()),
                const SizedBox(height: AppDimensions.sm),
                CustomTextField(
                  controller: _email,
                  hint: 'auth.signUp.emailHint'.tr(),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: AppDimensions.lg),

              // ─── Parol (telefon va email ikkalasida ham) ───
              AuthFieldLabel('auth.signUp.passwordLabel'.tr()),
              const SizedBox(height: AppDimensions.sm),
              PasswordTextField(
                controller: _password,
                hint: 'auth.signUp.passwordHint'.tr(),
                onChanged: (_) => setState(() {}),
              ),

              if (_error != null) ...[
                const SizedBox(height: AppDimensions.md),
                AuthErrorText(_error!),
              ],

              const SizedBox(height: AppDimensions.lg),

              // ─── Asosiy: Ro'yxatdan o'tish ───
              PrimaryButton(
                label: 'auth.signUp.submitButton'.tr(),
                isLoading: _loading,
                onPressed: _canSubmit && !_loading ? _submit : null,
              ),
              const SizedBox(height: AppDimensions.lg),

              // ─── Ijtimoiy: Apple / Google (hozircha UI) ───
              Row(
                children: [
                  Expanded(
                    child: SocialButton(
                      iconAsset: 'assets/icons/ic_apple.svg',
                      semanticsLabel: 'auth.social.apple'.tr(),
                      onPressed: _socialComingSoon,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: SocialButton(
                      iconAsset: 'assets/icons/ic_google.svg',
                      semanticsLabel: 'auth.social.google'.tr(),
                      onPressed: _socialComingSoon,
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
