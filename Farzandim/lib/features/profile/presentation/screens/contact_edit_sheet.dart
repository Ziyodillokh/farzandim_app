// "Telefonni tahrirlash" / "Emailni tahrirlash" — Akkount sheet'idagi
// qalam ikonidan ochiladigan Parvoz bottom sheet'lari.
//
// TELEFON: to'liq ishlaydi — yangi raqamga OTP yuboriladi
// (profileProvider.requestPhoneOtp → POST /users/me/phone), 6 xonali kod
// kiritilib tasdiqlanadi (verifyPhoneAndSave → POST /users/me/phone/verify),
// so'ng profil yangilanadi.
//
// EMAIL: backend'da o'zgartirish endpointi hali YO'Q — UI dizayn bilan bir
// xil, lekin "Saqlash" hozircha "tez kunda" toast ko'rsatadi.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/profile/presentation/providers/profile_provider.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Tokenlar (lokal) ════════════
const _bg = Color(0xFF0F141A);
const _card = Color(0xFF1A1F23);
const _cardBorder = Color(0x1FFFFFFF); // oq 12%
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

  Future<void> _sendCode() async {
    if (!widget.isPhone) {
      AppToast.info(context, 'contactEdit.comingSoon'.tr());
      return;
    }
    final phone = _normalizePhone(_valueCtrl.text);
    if (phone == null) {
      setState(() => _error = 'contactEdit.invalidPhone'.tr());
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileProvider.notifier).requestPhoneOtp(phone);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _sentTo = phone;
        _busy = false;
      });
      _startCooldown();
      AppToast.success(context, 'contactEdit.codeSent'.tr());
      _otpFocus.requestFocus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _dioMessage(e);
      });
    }
  }

  Future<void> _save() async {
    if (!widget.isPhone) {
      AppToast.info(context, 'contactEdit.comingSoon'.tr());
      return;
    }
    final phone = _normalizePhone(_valueCtrl.text);
    if (phone == null || !_otpValid) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(profileProvider.notifier)
          .verifyPhoneAndSave(phone: phone, code: _otpCtrl.text);
      if (!mounted) return;
      // Toast ROOT overlay'ga yoziladi — pop'dan OLDIN ko'rsatamiz, aks holda
      // sheet yopilib context o'lik bo'lib toast chiqmay qoladi.
      AppToast.success(context, 'contactEdit.saved'.tr());
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
    // Telefon: qadamga qarab "Kod yuborish" → "Saqlash". Email: doim "Saqlash".
    final showSaveLabel = !widget.isPhone || _codeSent;
    final primaryLabel = showSaveLabel
        ? 'contactEdit.save'.tr()
        : 'contactEdit.sendCode'.tr();
    final primaryEnabled = widget.isPhone
        ? (_codeSent ? _otpValid : _valueValid)
        : _valueValid;
    final onPrimary = widget.isPhone
        ? (_codeSent ? _save : _sendCode)
        : () => AppToast.info(context, 'contactEdit.comingSoon'.tr());

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
                          SolarIconsOutline.altArrowLeft,
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
                      if (widget.isPhone && _codeSent)
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
                  _OtpInput(
                    controller: _otpCtrl,
                    focusNode: _otpFocus,
                    // Email uchun doim faol; telefon uchun kod yuborilgach.
                    enabled: !widget.isPhone || _codeSent,
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

/// 6 xonali OTP kiritish — 6 dumaloq katakcha + ustida shaffof TextField.
class _OtpInput extends StatelessWidget {
  const _OtpInput({
    required this.controller,
    required this.focusNode,
    required this.enabled,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final value = controller.text;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < _otpLen; i++)
                _box(
                  i < value.length ? value[i] : '',
                  active: enabled && i == value.length,
                ),
            ],
          ),
          // Ustidagi shaffof maydon — bosilsa fokus + klaviatura, kiritilgan
          // raqamlar kataklarda ko'rinadi.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                keyboardType: TextInputType.number,
                maxLength: _otpLen,
                showCursor: false,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: Colors.transparent),
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _box(String digit, {required bool active}) {
    return Container(
      width: 50,
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _card,
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? _blue : _cardBorder,
          width: active ? 1.5 : 1,
        ),
      ),
      child: Text(digit, style: _unb(20, ls: 0)),
    );
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
