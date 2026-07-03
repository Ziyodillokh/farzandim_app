// Parvoz OTP kiritish widget'i — [length] ta dumaloq katak + ustida shaffof
// TextField (bosilsa fokus + klaviatura, kiritilgan raqamlar kataklarda
// ko'rinadi). Telefon/email o'zgartirish va parol tiklash oqimlarida
// qayta ishlatiladi.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

const _card = Color(0xFF1A1F23);
const _cardBorder = Color(0x1FFFFFFF); // oq 12%
const _blue = Color(0xFF216BFF);

/// Dumaloq kataklardan iborat OTP kiritish maydoni.
class ParvozOtpInput extends StatelessWidget {
  const ParvozOtpInput({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    this.length = 6,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final int length;

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
              for (var i = 0; i < length; i++)
                _box(
                  i < value.length ? value[i] : '',
                  active: enabled && i == value.length,
                ),
            ],
          ),
          // Ustidagi shaffof maydon — bosilsa fokus + klaviatura.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                keyboardType: TextInputType.number,
                maxLength: length,
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
      child: Text(
        digit,
        style: GoogleFonts.unbounded(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
