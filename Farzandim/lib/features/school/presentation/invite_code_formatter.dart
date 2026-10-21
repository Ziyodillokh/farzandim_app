// Taklif kodi maydoni uchun formatter: katta harf, faqat A–Z va 0–9,
// ko'pi bilan 8 belgi, 4-belgidan keyin "-" ("ABCD-2345"). Kursor
// o'zidan oldingi kod belgilari soni bo'yicha joyiga qaytariladi —
// o'rtadan tahrirlash ham buzilmaydi.

import 'package:farzandim/features/school/data/invite_code.dart';
import 'package:flutter/services.dart';

class InviteCodeInputFormatter extends TextInputFormatter {
  const InviteCodeInputFormatter();

  static final RegExp _allowed = RegExp(r'^[A-Z0-9]$');

  /// Ajratuvchi "-" shu sondagi belgidan keyin turadi.
  static const int _half = InviteCode.length ~/ 2;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;
    final selection = newValue.selection;
    final cursor = selection.isValid
        ? selection.extentOffset.clamp(0, raw.length)
        : raw.length;

    final code = StringBuffer();
    var beforeCursor = 0;
    for (var i = 0; i < raw.length; i++) {
      if (code.length == InviteCode.length) break;
      final char = raw[i].toUpperCase();
      if (!_allowed.hasMatch(char)) continue;
      code.write(char);
      if (i < cursor) beforeCursor++;
    }

    final text = InviteCode.format(code.toString());
    final offset = beforeCursor > _half ? beforeCursor + 1 : beforeCursor;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset.clamp(0, text.length)),
    );
  }
}
