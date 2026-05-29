import 'package:farzandim/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 6 ta box'li OTP kod kiritish widget'i.
///
/// **Xususiyatlar:**
/// - Auto-advance: bitta raqam terilsa keyingi box'ga o'tadi
/// - Backspace: oldingi box'ga qaytadi
/// - Paste support: 6 raqamli matn yopishtirilsa avtomatik to'ldiriladi
/// - `onCompleted`: 6 ta raqam to'liq terilganda chaqiriladi
/// - `onChanged`: har terish'da joriy qiymat (string)
class OtpInput extends StatefulWidget {
  /// `OtpInput` konstruktor.
  const OtpInput({
    required this.onCompleted,
    super.key,
    this.onChanged,
    this.length = 6,
    this.autoFocus = true,
  });

  /// Kod uzunligi (default 6).
  final int length;

  /// Birinchi box ekran ochilganda fokuslanadi.
  final bool autoFocus;

  /// Har terishda chaqiriladi.
  final ValueChanged<String>? onChanged;

  /// To'liq kod terilganda chaqiriladi.
  final ValueChanged<String> onCompleted;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.length,
      (_) => TextEditingController(),
    );
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNodes.first.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _currentCode => _controllers.map((c) => c.text).join();

  void _onChanged(int index, String value) {
    // Foydalanuvchi 6 raqamni yopishtirsa — har bir box'ga taqsimlash.
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp('[^0-9]'), '');
      for (var i = 0;
          i < widget.length && index + i < widget.length;
          i++) {
        if (i < digits.length) {
          _controllers[index + i].text = digits[i];
        }
      }
      // Oxirgi to'lgan box'ga focus ko'chirish.
      final lastFilled =
          (index + digits.length).clamp(0, widget.length - 1);
      _focusNodes[lastFilled].requestFocus();
    } else if (value.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    final code = _currentCode;
    widget.onChanged?.call(code);
    if (code.length == widget.length) {
      widget.onCompleted(code);
    }
  }

  void _onKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      // Bo'sh box'da Backspace → oldingi box'ni tozalash + focus.
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < widget.length; i++)
          _OtpBox(
            controller: _controllers[i],
            focusNode: _focusNodes[i],
            onChanged: (value) => _onChanged(i, value),
            onKeyEvent: (event) => _onKey(i, event),
          ),
      ],
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onKeyEvent,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<KeyEvent> onKeyEvent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 56,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: onKeyEvent,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 2,
              ),
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
