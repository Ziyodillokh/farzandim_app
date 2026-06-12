import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:farzandim/shared/widgets/custom_text_field.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:farzandim/shared/widgets/otp_input.dart';
import 'package:farzandim/shared/widgets/password_text_field.dart';
import 'package:farzandim/shared/widgets/primary_button.dart';
import 'package:farzandim/shared/widgets/social_button.dart';
import 'package:farzandim/shared/widgets/tab_switcher.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Ro'yxatdan o'tish — 3 bosqichli "wizard":
///   1) Aloqa: telefon YOKI email tanlanadi + maxfiylik roziligi → kod
///      yuboriladi
///   2) Kod: 5 xonali tasdiqlash kodi kiritiladi (2 daqiqa qayta-yuborish
///      taymeri)
///   3) Profil: ism, familiya, parol, parolni takrorlash → ro'yxatdan o'tadi
///
/// ⚠️ HOZIRCHA UI PROTOTIP: kod yuborish va tasdiqlash MOCK qilingan
/// (haqiqiy SMS/email backend hali ulanmagan — keyin POST /auth/send-code +
/// /auth/verify-code qo'shiladi). Yakuniy qadam esa HAQIQIY backend
/// `registerWithPassword` ni chaqiradi.
class SignUpScreen extends ConsumerStatefulWidget {
  /// `SignUpScreen` konstruktor.
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  /// 0 = aloqa, 1 = kod, 2 = profil.
  int _step = 0;

  /// 0 = telefon, 1 = email.
  int _method = 0;

  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  /// Ommaviy offerta (Maxfiylik + Shartlar) qabul qilindimi.
  bool _consent = false;

  /// Kiritilgan tasdiqlash kodi (OtpInput'dan).
  String _code = '';

  bool _loading = false;
  String? _error;

  /// Qayta-yuborish taymeri — 2 daqiqa (120s).
  static const _resendStart = 120;
  int _resendLeft = 0;
  Timer? _timer;

  late final TapGestureRecognizer _privacyTap;
  late final TapGestureRecognizer _termsTap;

  bool get _isPhone => _method == 0;

  /// Foydalanuvchi tanlagan aloqa qiymati (ko'rsatish uchun).
  String get _contact =>
      _isPhone ? '+998 ${_phone.text.trim()}' : _email.text.trim();

  @override
  void initState() {
    super.initState();
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => context.push(AppRoutes.legalPrivacyPolicy);
    _termsTap = TapGestureRecognizer()
      ..onTap = () => context.push(AppRoutes.legalTermsOfService);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _privacyTap.dispose();
    _termsTap.dispose();
    _phone.dispose();
    _email.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  // ──────────────────────────── TAYMER ────────────────────────────

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendLeft = _resendStart);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendLeft <= 1) {
        t.cancel();
        setState(() => _resendLeft = 0);
      } else {
        setState(() => _resendLeft -= 1);
      }
    });
  }

  String get _resendLabel {
    final m = _resendLeft ~/ 60;
    final s = _resendLeft % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // ─────────────────────── 1-BOSQICH: ALOQA ───────────────────────

  bool get _contactValid {
    if (!_consent) return false;
    if (_isPhone) return _phone.text.trim().length == 9;
    final e = _email.text.trim();
    return e.contains('@') && e.contains('.') && e.length >= 5;
  }

  /// MOCK: backend SMS/email yo'q — to'g'ridan-to'g'ri kod bosqichiga o'tamiz
  /// va demo eslatma ko'rsatamiz.
  void _sendCode() {
    FocusScope.of(context).unfocus();
    _startResendTimer();
    setState(() {
      _step = 1;
      _error = null;
      _code = '';
    });
    _showDemoHint();
  }

  void _resendCode() {
    if (_resendLeft > 0) return;
    _startResendTimer();
    _showDemoHint(resent: true);
  }

  void _showDemoHint({bool resent = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            resent
                ? 'auth.signUp.resentSnack'.tr()
                : 'auth.signUp.demoHint'.tr(),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surface,
        ),
      );
  }

  // ──────────────────────── 2-BOSQICH: KOD ────────────────────────

  bool get _codeValid => _code.length == 5;

  /// MOCK: backend tasdiqlash yo'q — istalgan 5 xonali kod qabul qilinadi.
  void _verifyCode() {
    if (!_codeValid) return;
    FocusScope.of(context).unfocus();
    _timer?.cancel();
    setState(() {
      _step = 2;
      _error = null;
    });
  }

  // ─────────────────────── 3-BOSQICH: PROFIL ──────────────────────

  bool get _profileValid {
    if (_firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty) {
      return false;
    }
    if (_password.text.length < 6) return false;
    if (_password.text != _confirm.text) return false;
    return true;
  }

  /// HAQIQIY backend: registerWithPassword (ism+familiya → bitta `name`).
  Future<void> _register() async {
    if (_password.text != _confirm.text) {
      setState(() => _error = 'auth.signUp.passwordMismatch'.tr());
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    final notifier = ref.read(backendAuthProvider.notifier);
    final name = '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim();
    final err = _isPhone
        ? await notifier.registerWithPassword(
            phone: '+998${_phone.text.trim()}',
            password: _password.text,
            name: name,
          )
        : await notifier.registerWithPassword(
            email: _email.text.trim(),
            password: _password.text,
            name: name,
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

  // ──────────────────────────── NAV ────────────────────────────

  void _onBack() {
    if (_step > 0) {
      final newStep = _step - 1;
      setState(() {
        _step = newStep;
        _error = null;
        // OTP bosqichiga qaytganda box'lar bo'sh qayta quriladi —
        // `_code`ni ham tozalaymiz (aks holda bo'sh box + yoniq tugma desync).
        if (newStep == 1) _code = '';
      });
      if (newStep == 0) {
        _timer?.cancel();
      } else if (newStep == 1) {
        // Taymer muzlab qolmasligi uchun OTP'ga qaytganda qayta yoqamiz.
        _startResendTimer();
      }
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.welcome);
    }
  }

  // ──────────────────────────── BUILD ────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: _onBack,
          ),
        ),
        body: GradientBackground(
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: AppDimensions.sm),
                _StepDots(step: _step),
                const SizedBox(height: AppDimensions.sm),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final slide = Tween<Offset>(
                        begin: const Offset(0.12, 0),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey(_step),
                      child: _buildStep(),
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

  Widget _buildStep() {
    switch (_step) {
      case 1:
        return _buildOtpStep();
      case 2:
        return _buildProfileStep();
      default:
        return _buildContactStep();
    }
  }

  EdgeInsets get _pad => const EdgeInsets.fromLTRB(
    AppDimensions.lg,
    AppDimensions.sm,
    AppDimensions.lg,
    AppDimensions.xl,
  );

  // ─── 1-bosqich UI ───
  Widget _buildContactStep() {
    return SingleChildScrollView(
      padding: _pad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'auth.signUp.title'.tr(),
            style: AppTextStyles.headlineXL.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            'auth.signUp.contactSubtitle'.tr(),
            style: AppTextStyles.bodyS.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.xl),

          // Tab: Telefon / Email
          TabSwitcher(
            tabs: ['auth.signUp.phoneTab'.tr(), 'auth.signUp.emailTab'.tr()],
            activeIndex: _method,
            onChanged: (i) => setState(() {
              _method = i;
              _error = null;
            }),
          ),
          const SizedBox(height: AppDimensions.lg),

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

          _consentRow(),

          if (_error != null) ...[
            const SizedBox(height: AppDimensions.md),
            AuthErrorText(_error!),
          ],
          const SizedBox(height: AppDimensions.lg),

          PrimaryButton(
            label: 'auth.signUp.sendCodeButton'.tr(),
            onPressed: _contactValid && !_loading ? _sendCode : null,
          ),
          const SizedBox(height: AppDimensions.lg),

          // Social — alternativa
          Row(
            children: [
              Expanded(
                child: SocialButton(
                  iconAsset: 'assets/icons/ic_apple.svg',
                  semanticsLabel: 'auth.social.apple'.tr(),
                  onPressed: (_loading || !_consent)
                      ? null
                      : () => _social(
                          ref
                              .read(backendAuthProvider.notifier)
                              .signInWithApple,
                        ),
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: SocialButton(
                  iconAsset: 'assets/icons/ic_google.svg',
                  semanticsLabel: 'auth.social.google'.tr(),
                  onPressed: (_loading || !_consent)
                      ? null
                      : () => _social(
                          ref
                              .read(backendAuthProvider.notifier)
                              .signInWithGoogle,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _consentRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _consent,
            onChanged: (v) => setState(() => _consent = v ?? false),
            activeColor: AppColors.primary,
            checkColor: AppColors.onPrimary,
            side: BorderSide(color: AppColors.border, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: AppDimensions.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text.rich(
              TextSpan(
                style: AppTextStyles.bodyS.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                children: [
                  TextSpan(text: 'auth.signUp.consent.prefix'.tr()),
                  TextSpan(
                    text: 'auth.signUp.consent.privacy'.tr(),
                    style: const TextStyle(
                      color: kAuthLinkColor,
                      fontWeight: FontWeight.w600,
                    ),
                    recognizer: _privacyTap,
                  ),
                  TextSpan(text: 'auth.signUp.consent.and'.tr()),
                  TextSpan(
                    text: 'auth.signUp.consent.terms'.tr(),
                    style: const TextStyle(
                      color: kAuthLinkColor,
                      fontWeight: FontWeight.w600,
                    ),
                    recognizer: _termsTap,
                  ),
                  TextSpan(text: 'auth.signUp.consent.suffix'.tr()),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── 2-bosqich UI ───
  Widget _buildOtpStep() {
    return SingleChildScrollView(
      padding: _pad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'auth.signUp.otpTitle'.tr(),
            style: AppTextStyles.headlineXL.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.sm),
          Text.rich(
            TextSpan(
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              children: [
                TextSpan(text: 'auth.signUp.otpSentTo'.tr()),
                const TextSpan(text: '  '),
                TextSpan(
                  text: _contact,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.xl),

          OtpInput(
            length: 5,
            onChanged: (v) => setState(() => _code = v),
            onCompleted: (v) => setState(() => _code = v),
          ),
          const SizedBox(height: AppDimensions.lg),

          // Qayta yuborish — taymer tugaguncha o'chiq.
          Center(
            child: _resendLeft > 0
                ? Text(
                    'auth.signUp.resendTimer'.tr(
                      namedArgs: {'time': _resendLabel},
                    ),
                    style: AppTextStyles.bodyS.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  )
                : TextButton(
                    onPressed: _resendCode,
                    child: Text(
                      'auth.verifyOtp.resend'.tr(),
                      style: AppTextStyles.bodyM.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),

          if (_error != null) ...[
            const SizedBox(height: AppDimensions.md),
            AuthErrorText(_error!),
          ],
          const SizedBox(height: AppDimensions.lg),

          PrimaryButton(
            label: 'auth.verifyOtp.submitButton'.tr(),
            onPressed: _codeValid && !_loading ? _verifyCode : null,
          ),
        ],
      ),
    );
  }

  // ─── 3-bosqich UI ───
  Widget _buildProfileStep() {
    return SingleChildScrollView(
      padding: _pad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'auth.signUp.profileTitle'.tr(),
            style: AppTextStyles.headlineXL.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.xl),

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

          AuthFieldLabel('auth.signUp.passwordLabel'.tr()),
          const SizedBox(height: AppDimensions.sm),
          PasswordTextField(
            controller: _password,
            hint: 'auth.signUp.passwordHint'.tr(),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppDimensions.lg),

          AuthFieldLabel('auth.signUp.confirmPasswordLabel'.tr()),
          const SizedBox(height: AppDimensions.sm),
          PasswordTextField(
            controller: _confirm,
            hint: 'auth.signUp.confirmPasswordHint'.tr(),
            onChanged: (_) => setState(() {}),
          ),

          // Parollar mosligini real-time ko'rsatamiz (tugma o'chiq bo'lsa ham
          // user nega davom eta olmayotganini biladi).
          if (_confirm.text.isNotEmpty && _confirm.text != _password.text) ...[
            const SizedBox(height: AppDimensions.sm),
            AuthErrorText('auth.signUp.passwordMismatch'.tr()),
          ],

          if (_error != null) ...[
            const SizedBox(height: AppDimensions.md),
            AuthErrorText(_error!),
          ],
          const SizedBox(height: AppDimensions.xl),

          PrimaryButton(
            label: 'auth.signUp.submitButton'.tr(),
            isLoading: _loading,
            onPressed: _profileValid && !_loading ? _register : null,
          ),
        ],
      ),
    );
  }
}

/// Yuqoridagi 3 bosqich indikatori (nuqtalar).
class _StepDots extends StatelessWidget {
  const _StepDots({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: i == step ? 26 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i <= step ? AppColors.accent : AppColors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          if (i < 2) const SizedBox(width: 6),
        ],
      ],
    );
  }
}
