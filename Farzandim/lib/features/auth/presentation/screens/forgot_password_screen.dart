import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/custom_text_field.dart';
import 'package:farzandim/shared/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Parolni tiklash (logout holatida) — 2 bosqich:
///   1) Email/telefon kiritish → tasdiqlash kodi (POST /auth/password/forgot).
///   2) Kod + yangi parol → parol yangilanadi (POST /auth/password/reset).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  /// `ForgotPasswordScreen` konstruktor.
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _contact = TextEditingController();
  final _code = TextEditingController();
  final _newPassword = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;

  @override
  void dispose() {
    _contact.dispose();
    _code.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  /// Kiritilgan matnni telefon (+998...) yoki email deb ajratadi.
  ({String? phone, String? email}) _parseContact() {
    final raw = _contact.text.trim();
    final digits = raw.replaceAll(RegExp('[^0-9]'), '');
    final looksPhone =
        raw.startsWith('+') ||
        (RegExp(r'^\d+$').hasMatch(raw) && digits.length >= 9);
    if (looksPhone) {
      return (phone: raw.startsWith('+') ? raw : '+$digits', email: null);
    }
    return (phone: null, email: raw.toLowerCase());
  }

  Map<String, dynamic> _contactBody() {
    final c = _parseContact();
    return {
      if (c.phone != null) 'phone': c.phone,
      if (c.email != null) 'email': c.email,
    };
  }

  Future<void> _sendCode() async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await ref
          .read(dioClientProvider)
          .post<dynamic>('/auth/password/forgot', data: _contactBody());
      if (!mounted) return;
      setState(() => _codeSent = true);
      AppToast.info(context, 'auth.forgotPassword.codeSent'.tr());
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'auth.forgotPassword.sendError'.tr());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await ref
          .read(dioClientProvider)
          .post<dynamic>(
            '/auth/password/reset',
            data: {
              ..._contactBody(),
              'code': _code.text.trim(),
              'newPassword': _newPassword.text,
            },
          );
      if (!mounted) return;
      AppToast.success(context, 'auth.forgotPassword.resetSuccess'.tr());
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.signIn);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      // Backend "Noto'g'ri kod" kabi aniq xabar qaytarsa — o'shani ko'rsatamiz.
      final msg = data is Map && data['message'] is String
          ? data['message'] as String
          : 'auth.forgotPassword.resetError'.tr();
      AppToast.error(context, msg);
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'auth.forgotPassword.resetError'.tr());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _contact.text.trim().isNotEmpty && !_busy;
    final canReset =
        _code.text.trim().length >= 4 &&
        _newPassword.text.length >= 6 &&
        !_busy;

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

              // ── Email / telefon ──
              AuthFieldLabel('auth.forgotPassword.contactLabel'.tr()),
              const SizedBox(height: AppDimensions.sm),
              CustomTextField(
                controller: _contact,
                hint: 'auth.forgotPassword.contactHint'.tr(),
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
              ),

              if (!_codeSent) ...[
                const SizedBox(height: AppDimensions.lg),
                PrimaryButton(
                  label: 'auth.forgotPassword.sendButton'.tr(),
                  isLoading: _busy,
                  onPressed: canSend ? _sendCode : null,
                ),
              ] else ...[
                const SizedBox(height: AppDimensions.lg),
                // ── Tasdiqlash kodi ──
                AuthFieldLabel('auth.forgotPassword.codeLabel'.tr()),
                const SizedBox(height: AppDimensions.sm),
                CustomTextField(
                  controller: _code,
                  hint: 'auth.forgotPassword.codeHint'.tr(),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppDimensions.lg),
                // ── Yangi parol ──
                AuthFieldLabel('auth.forgotPassword.newPasswordLabel'.tr()),
                const SizedBox(height: AppDimensions.sm),
                CustomTextField(
                  controller: _newPassword,
                  hint: 'auth.forgotPassword.newPasswordHint'.tr(),
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppDimensions.lg),
                PrimaryButton(
                  label: 'auth.forgotPassword.resetButton'.tr(),
                  isLoading: _busy,
                  onPressed: canReset ? _reset : null,
                ),
                const SizedBox(height: AppDimensions.xs),
                // Kodni qayta yuborish
                TextButton(
                  onPressed: _busy ? null : _sendCode,
                  child: Text('auth.forgotPassword.sendButton'.tr()),
                ),
              ],

              const SizedBox(height: AppDimensions.lg),
              // ─── Esladingizmi? → kirish ───
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
