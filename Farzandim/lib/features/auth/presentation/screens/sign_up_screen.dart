import 'dart:async';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/auth/data/services/social_sign_in_service.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/auth/presentation/widgets/google_web_sign_in_dialog.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

/// Ro'yxatdan o'tish — Parvoz dizayni, 3 bosqichli "wizard":
///   1) Aloqa: telefon YOKI email + maxfiylik roziligi → kod yuboriladi
///   2) Kod: 5 xonali tasdiqlash kodi (2 daqiqa qayta-yuborish taymeri)
///   3) Profil: ism, familiya, parol, parolni takrorlash → ro'yxatdan o'tadi
///
/// Telefon OTP — Eskiz SMS; email OTP — nodemailer (SMTP yo'q bo'lsa 503 →
/// OTP'siz to'g'ridan profilga). Yakuniy qadam HAQIQIY `registerWithPassword`.
class SignUpScreen extends ConsumerStatefulWidget {
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

  bool _consent = false;
  String _code = '';
  bool _loading = false;
  String? _error;

  static const _resendStart = 120;
  int _resendLeft = 0;
  Timer? _timer;

  late final TapGestureRecognizer _privacyTap;
  late final TapGestureRecognizer _termsTap;

  bool get _isPhone => _method == 0;

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

  Future<void> _sendCode() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    final dio = ref.read(dioClientProvider);
    try {
      if (_isPhone) {
        await dio.post<Map<String, dynamic>>(
          '/auth/send-register-otp',
          data: {'phone': '+998${_phone.text.trim()}'},
        );
      } else {
        await dio.post<Map<String, dynamic>>(
          '/auth/send-register-email-otp',
          data: {'email': _email.text.trim()},
        );
      }
      if (!mounted) return;
      _startResendTimer();
      setState(() {
        _loading = false;
        _step = 1;
        _code = '';
      });
    } on DioException catch (e) {
      if (!mounted) return;
      // Email xizmati sozlanmagan (503) → eski xulq: OTP'siz profilga o'tamiz.
      if (!_isPhone && e.response?.statusCode == 503) {
        _timer?.cancel();
        setState(() {
          _loading = false;
          _step = 2;
          _error = null;
        });
        return;
      }
      setState(() {
        _loading = false;
        _error = _readDioError(
          e,
          fallback: _isPhone
              ? 'auth.signUp.sendCodeError'.tr()
              : 'auth.signUp.sendEmailError'.tr(),
        );
      });
    }
  }

  Future<void> _resendCode() async {
    if (_resendLeft > 0) return;
    setState(() => _error = null);
    final dio = ref.read(dioClientProvider);
    try {
      if (_isPhone) {
        await dio.post<Map<String, dynamic>>(
          '/auth/send-register-otp',
          data: {'phone': '+998${_phone.text.trim()}'},
        );
      } else {
        await dio.post<Map<String, dynamic>>(
          '/auth/send-register-email-otp',
          data: {'email': _email.text.trim()},
        );
      }
      if (!mounted) return;
      _startResendTimer();
      AppToast.info(context, 'auth.signUp.resentSnack'.tr());
    } on DioException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = _readDioError(
          e,
          fallback: _isPhone
              ? "SMS yuborib bo'lmadi"
              : "Email yuborib bo'lmadi",
        ),
      );
    }
  }

  String _readDioError(DioException e, {required String fallback}) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return fallback;
  }

  // ──────────────────────── 2-BOSQICH: KOD ────────────────────────

  bool get _codeValid => _code.length == 5;

  Future<void> _verifyCode() async {
    if (!_codeValid) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    final dio = ref.read(dioClientProvider);
    try {
      if (_isPhone) {
        await dio.post<Map<String, dynamic>>(
          '/auth/verify-register-otp',
          data: {'phone': '+998${_phone.text.trim()}', 'code': _code},
        );
      } else {
        await dio.post<Map<String, dynamic>>(
          '/auth/verify-register-email-otp',
          data: {'email': _email.text.trim(), 'code': _code},
        );
      }
      if (!mounted) return;
      _timer?.cancel();
      setState(() {
        _loading = false;
        _step = 2;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _readDioError(e, fallback: 'auth.signUp.verifyCodeError'.tr());
      });
    }
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

  /// Google bosilganda: web'da rasmiy render-tugma oynasi (signIn() web'da
  /// idToken bermaydi), mobilda odatiy oqim.
  Future<void> _googlePressed() async {
    if (kIsWeb) {
      await _social(() async {
        final google = ref.read(socialSignInServiceProvider).google;
        final idToken = await showGoogleWebSignInDialog(context, google);
        if (idToken == null) return null; // bekor qilindi — jim
        return ref
            .read(backendAuthProvider.notifier)
            .signInWithGoogleIdToken(idToken);
      });
    } else {
      await _social(ref.read(backendAuthProvider.notifier).signInWithGoogle);
    }
  }

  // ──────────────────────────── NAV ────────────────────────────

  void _onBack() {
    if (_step > 0) {
      final newStep = _step - 1;
      setState(() {
        _step = newStep;
        _error = null;
        if (newStep == 1) _code = '';
      });
      if (newStep == 0) {
        _timer?.cancel();
      } else if (newStep == 1) {
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
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ParvozBackButton(onTap: _onBack),
                    ),
                  ),
                  const SizedBox(height: 8),
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
          ],
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

  EdgeInsets get _pad => const EdgeInsets.fromLTRB(24, 12, 24, 32);

  Widget _title(String text) => Text(
    text,
    textAlign: TextAlign.center,
    style: GoogleFonts.unbounded(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: Colors.white,
      letterSpacing: -0.5,
      height: 1.25,
    ),
  );

  Widget _subtitle(String text) => Text(
    text,
    textAlign: TextAlign.center,
    style: GoogleFonts.poppins(
      fontSize: 14,
      height: 1.45,
      color: Colors.white.withValues(alpha: 0.6),
    ),
  );

  Widget _errorRow(String msg) => Row(
    children: [
      const Icon(
        SolarIconsBold.dangerCircle,
        size: 16,
        color: Color(0xFFFF6B6B),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          msg,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: const Color(0xFFFF6B6B),
          ),
        ),
      ),
    ],
  );

  Widget _appleButton() => ParvozSecondaryButton(
    label: 'auth.social.apple'.tr(),
    enabled: !_loading && _consent,
    leading: SvgPicture.asset(
      'assets/icons/ic_apple_mark.svg',
      width: 20,
      height: 20,
    ),
    onPressed: () =>
        _social(ref.read(backendAuthProvider.notifier).signInWithApple),
  );

  Widget _googleButton() => ParvozSecondaryButton(
    label: 'auth.social.google'.tr(),
    enabled: !_loading && _consent,
    leading: SvgPicture.asset(
      'assets/icons/ic_google_mark.svg',
      width: 20,
      height: 20,
    ),
    onPressed: _googlePressed,
  );

  // ─── 1-bosqich UI ───
  Widget _buildContactStep() {
    return SingleChildScrollView(
      padding: _pad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title('auth.signUp.title'.tr()),
          const SizedBox(height: 8),
          _subtitle('auth.signUp.contactSubtitle'.tr()),
          const SizedBox(height: 28),
          _segmented(),
          const SizedBox(height: 20),
          if (_isPhone)
            ParvozTextField(
              label: 'auth.signUp.phoneLabel'.tr(),
              controller: _phone,
              hint: 'auth.signUp.phoneHint'.tr(),
              keyboardType: TextInputType.phone,
              maxLength: 9,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              prefix: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '+998',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 1,
                    height: 22,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ],
              ),
              onChanged: (_) => setState(() {}),
            )
          else
            ParvozTextField(
              label: 'auth.signUp.emailLabel'.tr(),
              controller: _email,
              hint: 'auth.signUp.emailHint'.tr(),
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
            ),
          const SizedBox(height: 20),
          _consentRow(),
          if (_error != null) ...[
            const SizedBox(height: 16),
            _errorRow(_error!),
          ],
          const SizedBox(height: 24),
          ParvozPrimaryButton(
            label: 'auth.signUp.sendCodeButton'.tr(),
            enabled: _contactValid,
            loading: _loading,
            onPressed: _sendCode,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _appleButton()),
              const SizedBox(width: 12),
              Expanded(child: _googleButton()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _segmented() {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          _segTab('auth.signUp.phoneTab'.tr(), 0),
          _segTab('auth.signUp.emailTab'.tr(), 1),
        ],
      ),
    );
  }

  Widget _segTab(String label, int index) {
    final active = _method == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() {
          _method = index;
          _error = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: active
                ? const LinearGradient(
                    colors: [ParvozColors.blueLight, ParvozColors.blue],
                  )
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _consentRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _consent = !_consent),
          child: Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: _consent ? ParvozColors.blue : Colors.transparent,
              border: Border.all(
                color: _consent
                    ? ParvozColors.blue
                    : Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: _consent
                ? const Icon(
                    SolarIconsBold.checkCircle,
                    size: 15,
                    color: Colors.white,
                  )
                : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: GoogleFonts.poppins(
                fontSize: 13,
                height: 1.45,
                color: Colors.white.withValues(alpha: 0.6),
              ),
              children: [
                TextSpan(text: 'auth.signUp.consent.prefix'.tr()),
                TextSpan(
                  text: 'auth.signUp.consent.privacy'.tr(),
                  style: const TextStyle(
                    color: ParvozColors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                  recognizer: _privacyTap,
                ),
                TextSpan(text: 'auth.signUp.consent.and'.tr()),
                TextSpan(
                  text: 'auth.signUp.consent.terms'.tr(),
                  style: const TextStyle(
                    color: ParvozColors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                  recognizer: _termsTap,
                ),
                TextSpan(text: 'auth.signUp.consent.suffix'.tr()),
              ],
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
          _title('auth.signUp.otpTitle'.tr()),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: GoogleFonts.poppins(
                fontSize: 14,
                height: 1.45,
                color: Colors.white.withValues(alpha: 0.6),
              ),
              children: [
                TextSpan(text: 'auth.signUp.otpSentTo'.tr()),
                const TextSpan(text: '  '),
                TextSpan(
                  text: _contact,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          _ParvozOtp(onChanged: (v) => setState(() => _code = v)),
          const SizedBox(height: 20),
          Center(
            child: _resendLeft > 0
                ? Text(
                    'auth.signUp.resendTimer'.tr(
                      namedArgs: {'time': _resendLabel},
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  )
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _resendCode,
                    child: Text(
                      'auth.verifyOtp.resend'.tr(),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: ParvozColors.blue,
                      ),
                    ),
                  ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            _errorRow(_error!),
          ],
          const SizedBox(height: 24),
          ParvozPrimaryButton(
            label: 'auth.verifyOtp.submitButton'.tr(),
            enabled: _codeValid,
            loading: _loading,
            onPressed: _verifyCode,
          ),
        ],
      ),
    );
  }

  // ─── 3-bosqich UI ───
  Widget _buildProfileStep() {
    final mismatch =
        _confirm.text.isNotEmpty && _confirm.text != _password.text;
    return SingleChildScrollView(
      padding: _pad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title('auth.signUp.profileTitle'.tr()),
          const SizedBox(height: 28),
          ParvozTextField(
            label: 'auth.signUp.firstNameLabel'.tr(),
            controller: _firstName,
            hint: 'auth.signUp.firstNameHint'.tr(),
            keyboardType: TextInputType.name,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 18),
          ParvozTextField(
            label: 'auth.signUp.lastNameLabel'.tr(),
            controller: _lastName,
            hint: 'auth.signUp.lastNameHint'.tr(),
            keyboardType: TextInputType.name,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 18),
          ParvozTextField(
            label: 'auth.signUp.passwordLabel'.tr(),
            controller: _password,
            hint: 'auth.signUp.passwordHint'.tr(),
            obscure: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 18),
          ParvozTextField(
            label: 'auth.signUp.confirmPasswordLabel'.tr(),
            controller: _confirm,
            hint: 'auth.signUp.confirmPasswordHint'.tr(),
            obscure: true,
            onChanged: (_) => setState(() {}),
          ),
          if (mismatch) ...[
            const SizedBox(height: 8),
            _errorRow('auth.signUp.passwordMismatch'.tr()),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            _errorRow(_error!),
          ],
          const SizedBox(height: 28),
          ParvozPrimaryButton(
            label: 'auth.signUp.submitButton'.tr(),
            enabled: _profileValid,
            loading: _loading,
            onPressed: _register,
          ),
        ],
      ),
    );
  }
}

/// 5 xonali OTP — shisha box'lar, fokus/to'ldirilganda ko'k rim.
class _ParvozOtp extends StatefulWidget {
  const _ParvozOtp({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<_ParvozOtp> createState() => _ParvozOtpState();
}

class _ParvozOtpState extends State<_ParvozOtp> {
  static const _len = 5;
  final List<TextEditingController> _ctrls = List.generate(
    _len,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _nodes = List.generate(_len, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    for (final n in _nodes) {
      n.addListener(_onFocus);
    }
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    for (final n in _nodes) {
      n
        ..removeListener(_onFocus)
        ..dispose();
    }
    super.dispose();
  }

  String get _value => _ctrls.map((c) => c.text).join();

  void _onChanged(int i, String v) {
    if (v.length > 1) {
      final digits = v.replaceAll(RegExp(r'\D'), '');
      for (var j = 0; j < _len; j++) {
        _ctrls[j].text = j < digits.length ? digits[j] : '';
      }
      final filled = digits.length.clamp(0, _len);
      _nodes[filled >= _len ? _len - 1 : filled].requestFocus();
      widget.onChanged(_value);
      setState(() {});
      return;
    }
    if (v.isNotEmpty && i < _len - 1) {
      _nodes[i + 1].requestFocus();
    }
    widget.onChanged(_value);
    setState(() {});
  }

  KeyEventResult _onKey(int i, KeyEvent e) {
    if (e is KeyDownEvent &&
        e.logicalKey == LogicalKeyboardKey.backspace &&
        _ctrls[i].text.isEmpty &&
        i > 0) {
      _nodes[i - 1].requestFocus();
      _ctrls[i - 1].clear();
      widget.onChanged(_value);
      setState(() {});
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return TextSelectionTheme(
      data: const TextSelectionThemeData(
        cursorColor: ParvozColors.blue,
        selectionHandleColor: ParvozColors.blue,
        selectionColor: Color(0x5C216BFF),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [for (var i = 0; i < _len; i++) _box(i)],
      ),
    );
  }

  Widget _box(int i) {
    final filled = _ctrls[i].text.isNotEmpty;
    final focused = _nodes[i].hasFocus;
    return SizedBox(
      width: 52,
      height: 60,
      child: Focus(
        canRequestFocus: false,
        onKeyEvent: (_, e) => _onKey(i, e),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: (focused || filled)
                  ? ParvozColors.blue
                  : Colors.white.withValues(alpha: 0.12),
              width: focused ? 1.6 : 1.2,
            ),
          ),
          child: Center(
            child: TextField(
              controller: _ctrls[i],
              focusNode: _nodes[i],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 1,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) => _onChanged(i, v),
              cursorColor: ParvozColors.blue,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              decoration: const InputDecoration(
                filled: false,
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
