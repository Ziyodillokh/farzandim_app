// "Telefonni tahrirlash" / "Emailni tahrirlash" — Akkount sheet'idagi
// qalam ikonidan ochiladigan Parvoz bottom sheet'lari. Ikkalasi ham bir xil
// oqim: yangi qiymat kirit → OTP yuboriladi → 6 xonali kod → tasdiqlab saqlash.
//
// TELEFON: yangi raqamga SMS OTP (POST /users/me/phone + /verify).
// EMAIL: yangi manzilga email OTP (POST /users/me/email + /verify).
// Ikkalasi ham tasdiqlangach profilni qayta yuklaydi.

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
const _otpLen = 6; // backend 6 xonali kod talab qiladi

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

/// Telefonni tahrirlash varag'ini ochadi.
Future<void> showPhoneEditSheet(BuildContext context) => _show(context, true);

/// Emailni tahrirlash varag'ini ochadi.
Future<void> showEmailEditSheet(BuildContext context) => _show(context, false);

Future<void> _show(BuildContext context, bool isPhone) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _ContactEditSheet(isPhone: isPhone),
  );
}

class _ContactEditSheet extends ConsumerStatefulWidget {
  const _ContactEditSheet({required this.isPhone});

  final bool isPhone;

  @override
  ConsumerState<_ContactEditSheet> createState() => _ContactEditSheetState();
}

class _ContactEditSheetState extends ConsumerState<_ContactEditSheet> {
  final _valueCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _otpFocus = FocusNode();
  bool _codeSent = false;
  bool _busy = false;
  int _resend = 0;
  Timer? _resendTimer;
  String? _error;
  String _sentTo = '';

  @override
  void initState() {
    super.initState();
    _valueCtrl.addListener(_onChanged);
    _otpCtrl.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _resendTimer?.cancel();
    _valueCtrl.dispose();
    _otpCtrl.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  bool get _valueValid => widget.isPhone
      ? _normalizePhone(_valueCtrl.text) != null
      : _emailRe.hasMatch(_valueCtrl.text.trim());

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

  /// Kiritilgan qiymatni normallashtiradi (telefon → +998…, email → lower);
  /// yaroqsiz bo'lsa `null`.
  String? _normalizedTarget() {
    if (widget.isPhone) return _normalizePhone(_valueCtrl.text);
    final email = _valueCtrl.text.trim();
    return _emailRe.hasMatch(email) ? email.toLowerCase() : null;
  }

  Future<void> _sendCode() async {
    final target = _normalizedTarget();
    if (target == null) {
      setState(
        () => _error = widget.isPhone
            ? 'contactEdit.invalidPhone'.tr()
            : 'contactEdit.invalidEmail'.tr(),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final notifier = ref.read(profileProvider.notifier);
      if (widget.isPhone) {
        await notifier.requestPhoneOtp(target);
      } else {
        await notifier.requestEmailOtp(target);
      }
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _sentTo = target;
        _busy = false;
      });
      _startCooldown();
      AppToast.success(context, 'contactEdit.codeSent'.tr());
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
    // `_sentTo` — kod aynan yuborilgan qiymat (maydonni keyin tahrirlasa ham
    // to'g'ri tasdiqlanadi).
    if (!_codeSent || !_otpValid) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final notifier = ref.read(profileProvider.notifier);
      if (widget.isPhone) {
        await notifier.verifyPhoneAndSave(phone: _sentTo, code: _otpCtrl.text);
      } else {
        await notifier.verifyEmailAndSave(email: _sentTo, code: _otpCtrl.text);
      }
      if (!mounted) return;
      // Toast ROOT overlay'ga yoziladi — pop'dan OLDIN ko'rsatamiz, aks holda
      // sheet yopilib context o'lik bo'lib toast chiqmay qoladi.
      AppToast.success(
        context,
        widget.isPhone
            ? 'contactEdit.savedPhone'.tr()
            : 'contactEdit.savedEmail'.tr(),
      );
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
    final title = widget.isPhone
        ? 'contactEdit.phoneTitle'.tr()
        : 'contactEdit.emailTitle'.tr();
    // Qadamga qarab "Kod yuborish" → "Saqlash".
    final primaryLabel = _codeSent
        ? 'contactEdit.save'.tr()
        : 'contactEdit.sendCode'.tr();
    final primaryEnabled = _codeSent ? _otpValid : _valueValid;
    final onPrimary = _codeSent ? _save : _sendCode;

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
                            title,
                            style: _unb(17, w: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ParvozTextField(
                    label: widget.isPhone
                        ? 'contactEdit.newPhone'.tr()
                        : 'contactEdit.newEmail'.tr(),
                    controller: _valueCtrl,
                    keyboardType: widget.isPhone
                        ? TextInputType.phone
                        : TextInputType.emailAddress,
                    hint: widget.isPhone
                        ? 'contactEdit.phoneHint'.tr()
                        : 'contactEdit.emailHint'.tr(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _codeSent
                              ? 'contactEdit.otpSentLabel'.tr(
                                  namedArgs: {'target': _sentTo},
                                )
                              : 'contactEdit.otpLabel'.tr(),
                          style: _pop(13, c: _dim),
                        ),
                      ),
                      if (_codeSent)
                        _resend > 0
                            ? Text(
                                'contactEdit.resendIn'.tr(
                                  namedArgs: {'s': '$_resend'},
                                ),
                                style: _pop(12, c: _dim),
                              )
                            : GestureDetector(
                                onTap: _sendCode,
                                behavior: HitTestBehavior.opaque,
                                child: Text(
                                  'contactEdit.resend'.tr(),
                                  style: _pop(12, w: FontWeight.w500, c: _blue),
                                ),
                              ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ParvozOtpInput(
                    controller: _otpCtrl,
                    focusNode: _otpFocus,
                    enabled: _codeSent,
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
                    label: primaryLabel,
                    onPressed: onPrimary,
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

final RegExp _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Kiritilgan raqamni `+998XXXXXXXXX`ga keltiradi; yaroqsiz bo'lsa `null`.
String? _normalizePhone(String raw) {
  final digits = raw.replaceAll(RegExp('[^0-9]'), '');
  String candidate;
  if (digits.length == 9) {
    candidate = '+998$digits';
  } else if (digits.length == 12 && digits.startsWith('998')) {
    candidate = '+$digits';
  } else {
    return null;
  }
  return RegExp(r'^\+998\d{9}$').hasMatch(candidate) ? candidate : null;
}
