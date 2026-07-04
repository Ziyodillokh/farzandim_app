// "Parolni tahrirlash" — Akkount sheet'idagi parol qalamidan ochiladi.
// Ikki rejim (dizaynga mos):
//   • change — Yangi parol + Eski parol (POST /users/me/password).
//   • reset  — "Parolingizni unutdingizmi?" bosilsa: joriy telefonga OTP
//              yuboriladi (POST /users/me/password/request-otp), kod + yangi
//              parol bilan tasdiqlanadi (POST /users/me/password/reset).
//
// Reset havolasi faqat telefon raqami bor bo'lsa ko'rinadi (OTP telefonga
// yuboriladi — social-only user'da telefon bo'lmasligi mumkin).

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/profile/presentation/providers/profile_provider.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_otp_input.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Tokenlar (lokal) ════════════
const _bg = Color(0xFF0F141A);
const _blue = Color(0xFF216BFF);
const _dim = Color(0x99FFFFFF); // oq 60%
const _danger = Color(0xFFFF5A5A);
const _otpLen = 6; // backend 6 xonali kod
const _minPw = 6; // backend min 6 belgi
const _maxPw = 72; // backend @MaxLength(72) (bcrypt 72-bayt chegara)

TextStyle _unb(
  double size, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
  double ls = -0.4,
}) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: w,
  color: c,
  letterSpacing: ls,
  height: 1.3,
);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.5);

enum _PwMode { change, reset }

/// Parolni tahrirlash varag'ini ochadi.
Future<void> showPasswordEditSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => const _PasswordEditSheet(),
  );
}

class _PasswordEditSheet extends ConsumerStatefulWidget {
  const _PasswordEditSheet();

  @override
  ConsumerState<_PasswordEditSheet> createState() => _PasswordEditSheetState();
}

class _PasswordEditSheetState extends ConsumerState<_PasswordEditSheet> {
  final _newCtrl = TextEditingController();
  final _oldCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _otpFocus = FocusNode();
  _PwMode _mode = _PwMode.change;
  bool _codeSent = false;
  bool _busy = false;
  int _resend = 0;
  Timer? _resendTimer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _newCtrl.addListener(_onChanged);
    _oldCtrl.addListener(_onChanged);
    _otpCtrl.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _resendTimer?.cancel();
    _newCtrl.dispose();
    _oldCtrl.dispose();
    _otpCtrl.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  bool get _newValid => _newCtrl.text.length >= _minPw;
  bool get _otpValid => _otpCtrl.text.length == _otpLen;

  void _startCooldown() {
    _resend = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _resend--);
      if (_resend <= 0) t.cancel();
    });
  }

  /// "Parolingizni unutdingizmi?" — reset rejimiga o'tib OTP so'raydi.
  Future<void> _toReset() async {
    setState(() {
      _mode = _PwMode.reset;
      _error = null;
    });
    await _requestOtp();
  }

  /// Reset rejimidan "eski parol" rejimiga qaytish (masalan SMS ketmasa tupik
  /// bo'lib qolmasin).
  void _toChange() {
    _resendTimer?.cancel();
    setState(() {
      _mode = _PwMode.change;
      _codeSent = false;
      _resend = 0;
      _error = null;
      _otpCtrl.clear();
    });
  }

  Future<void> _requestOtp() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileProvider.notifier).requestPasswordOtp();
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _busy = false;
      });
      _startCooldown();
      AppToast.success(context, 'passwordEdit.codeSent'.tr());
      // OTP maydoni rebuild'dan keyin enabled bo'ladi — fokusni post-frame
      // so'raymiz (disabled maydonga requestFocus no-op bo'lardi).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _otpFocus.requestFocus();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _dioMessage(e);
      });
    }
  }

  Future<void> _save() async {
    final isReset = _mode == _PwMode.reset;
    if (isReset) {
      if (!_newValid || !_otpValid || !_codeSent) return;
    } else {
      if (!_newValid || _oldCtrl.text.isEmpty) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final notifier = ref.read(profileProvider.notifier);
      if (isReset) {
        await notifier.resetPasswordWithOtp(
          code: _otpCtrl.text,
          newPassword: _newCtrl.text,
        );
      } else {
        await notifier.changePassword(
          oldPassword: _oldCtrl.text,
          newPassword: _newCtrl.text,
        );
      }
      if (!mounted) return;
      // Toast ROOT overlay'ga — pop'dan OLDIN ko'rsatamiz.
      AppToast.success(context, 'passwordEdit.saved'.tr());
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _dioMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = (ref.watch(profileProvider).phoneNumber ?? '').trim();
    final canReset = phone.isNotEmpty;
    final isReset = _mode == _PwMode.reset;
    final primaryEnabled = isReset
        ? (_newValid && _otpValid && _codeSent)
        : (_newValid && _oldCtrl.text.isNotEmpty);
    // Yangi parol qisqa bo'lsagina eslatma (bo'sh holatda ko'rsatilmaydi).
    final showMinHint = _newCtrl.text.isNotEmpty && !_newValid;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: ColoredBox(
        color: _bg,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        behavior: HitTestBehavior.opaque,
                        child: const Icon(
                          SolarIconsOutline.arrowLeft,
                          size: 24,
                          color: Colors.white,
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'passwordEdit.title'.tr(),
                            style: _unb(17, w: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ParvozTextField(
                    label: 'passwordEdit.newPassword'.tr(),
                    controller: _newCtrl,
                    obscure: true,
                    hint: '••••••',
                    maxLength: _maxPw,
                  ),
                  if (showMinHint) ...[
                    const SizedBox(height: 8),
                    Text(
                      'passwordEdit.minHint'.tr(),
                      style: _pop(12, c: _danger),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (isReset)
                    _ResetOtpSection(
                      target: _mask(phone),
                      otpCtrl: _otpCtrl,
                      otpFocus: _otpFocus,
                      codeSent: _codeSent,
                      resend: _resend,
                      onResend: _requestOtp,
                      onBackToChange: _toChange,
                    )
                  else
                    _ChangeSection(
                      oldCtrl: _oldCtrl,
                      canReset: canReset,
                      onForgot: _toReset,
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: _pop(13, c: _danger),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ParvozPrimaryButton(
                    label: 'passwordEdit.save'.tr(),
                    onPressed: _save,
                    showArrow: false,
                    loading: _busy,
                    enabled: primaryEnabled && !_busy,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _mask(String phone) =>
      phone.length < 2 ? phone : '**${phone.substring(phone.length - 2)}';

  /// NestJS xato xabarini (message: String | List) ajratib oladi.
  String _dioMessage(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final m = data['message'];
        if (m is String && m.isNotEmpty) return m;
        if (m is List && m.isNotEmpty) return '${m.first}';
      }
    }
    return 'errors.generic'.tr();
  }
}

/// change rejimi — eski parol + "Parolingizni unutdingizmi?" havolasi.
class _ChangeSection extends StatelessWidget {
  const _ChangeSection({
    required this.oldCtrl,
    required this.canReset,
    required this.onForgot,
  });

  final TextEditingController oldCtrl;
  final bool canReset;
  final VoidCallback onForgot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ParvozTextField(
          label: 'passwordEdit.oldPassword'.tr(),
          controller: oldCtrl,
          obscure: true,
          hint: '••••••',
        ),
        if (canReset) ...[
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: onForgot,
              behavior: HitTestBehavior.opaque,
              child: Text(
                'passwordEdit.forgot'.tr(),
                style: _pop(13, w: FontWeight.w500, c: _blue),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// reset rejimi — joriy telefonga yuborilgan OTP + qayta yuborish.
class _ResetOtpSection extends StatelessWidget {
  const _ResetOtpSection({
    required this.target,
    required this.otpCtrl,
    required this.otpFocus,
    required this.codeSent,
    required this.resend,
    required this.onResend,
    required this.onBackToChange,
  });

  final String target;
  final TextEditingController otpCtrl;
  final FocusNode otpFocus;
  final bool codeSent;
  final int resend;
  final VoidCallback onResend;
  final VoidCallback onBackToChange;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'passwordEdit.otpLabel'.tr(namedArgs: {'target': target}),
                style: _pop(13, c: _dim),
              ),
            ),
            if (codeSent)
              resend > 0
                  ? Text(
                      'passwordEdit.resendIn'.tr(namedArgs: {'s': '$resend'}),
                      style: _pop(12, c: _dim),
                    )
                  : GestureDetector(
                      onTap: onResend,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        'passwordEdit.resend'.tr(),
                        style: _pop(12, w: FontWeight.w500, c: _blue),
                      ),
                    ),
          ],
        ),
        const SizedBox(height: 12),
        ParvozOtpInput(
          controller: otpCtrl,
          focusNode: otpFocus,
          enabled: codeSent,
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: onBackToChange,
            behavior: HitTestBehavior.opaque,
            child: Text(
              'passwordEdit.backToChange'.tr(),
              style: _pop(13, w: FontWeight.w500, c: _blue),
            ),
          ),
        ),
      ],
    );
  }
}
