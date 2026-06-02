import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/admin_api.dart';
import '../../core/network/admin_session.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/ux/app_error_handler.dart';
import '../../core/widgets/common.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();

  bool _loading = false;
  String? _error;

  // 2FA state
  bool _needs2fa = false;
  String? _challengeId;
  String? _maskedPhone;

  // Resend cooldown
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    setState(() { _loading = true; _error = null; });

    try {
      final result = await AdminApi().login(email, password);

      if (result.requires2fa) {
        setState(() {
          _needs2fa = true;
          _challengeId = result.challengeId;
          _maskedPhone = result.maskedPhone;
          _resendSeconds = 60;
          _loading = false;
        });
        _startResendTimer();
        return;
      }

      await _applyLogin(result);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = AppErrorHandler.userMessage(e); });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _error = '6 raqamli kod kiriting');
      return;
    }
    if (_challengeId == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final result = await AdminApi().verify2fa(challengeId: _challengeId!, code: code);
      await _applyLogin(result);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = AppErrorHandler.userMessage(e); });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _applyLogin(LoginResult result) async {
    await AdminSession.setTokens(
      accessToken: result.accessToken ?? '',
      // H7 — web'da refresh token HttpOnly cookie'da, javob body'sida kelmaydi.
      // 'cookie' — sessiya borligini bildiruvchi belgi (haqiqiy token emas).
      refreshToken: result.refreshToken ?? (kIsWeb ? 'cookie' : null),
    );
    if (result.staff != null) {
      AdminSession.applyStaffProfile(result.staff!);
    } else {
      final me = await AdminApi().fetchStaffMe();
      if (me.isNotEmpty) AdminSession.applyStaffProfile(me);
    }
    if (!mounted) return;
    context.go('/dashboard');
  }

  Future<void> _resendOtp() async {
    if (_resendSeconds > 0) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    setState(() { _loading = true; _error = null; });
    try {
      final result = await AdminApi().login(email, password);
      if (result.requires2fa) {
        setState(() {
          _challengeId = result.challengeId;
          _maskedPhone = result.maskedPhone;
          _resendSeconds = 60;
          _otpController.clear();
        });
        _startResendTimer();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AppErrorHandler.userMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_resendSeconds > 0) {
          _resendSeconds--;
        } else {
          t.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AppCard(
              child: _needs2fa ? _buildOtpStep() : _buildPasswordStep(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Admin Login'),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Password'),
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: AppSpacing.sm),
        AppPrimaryButton(
          label: _loading ? 'Signing in...' : 'Login',
          onPressed: _loading ? null : _submit,
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('SMS tasdiqlash'),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Kod yuborildi: ${_maskedPhone ?? '—'}',
          style: const TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: '6 raqamli kod',
            counterText: '',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, letterSpacing: 8),
          onSubmitted: (_) => _verifyOtp(),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
        ],
        const SizedBox(height: AppSpacing.sm),
        AppPrimaryButton(
          label: _loading ? 'Tekshirilmoqda...' : 'Tasdiqlash',
          onPressed: _loading ? null : _verifyOtp,
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: _resendSeconds > 0 ? null : _resendOtp,
          child: Text(
            _resendSeconds > 0 ? 'Qayta yuborish ($_resendSeconds s)' : 'Qayta yuborish',
          ),
        ),
        TextButton(
          onPressed: () => setState(() { _needs2fa = false; _error = null; _otpController.clear(); }),
          child: const Text('Orqaga'),
        ),
      ],
    );
  }
}
