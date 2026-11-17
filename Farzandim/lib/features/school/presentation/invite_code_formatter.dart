// Taklif kodi maydoni uchun formatter: katta harf, faqat A–Z va 0–9,
// ko'pi bilan 8 belgi. Raqamli kod (≤ 6 raqam, "042913") bo'linmaydi;
// qolgani 4-belgidan keyin "-" bilan ("ABCD-2345"). Kursor o'zidan oldingi
// kod belgilari soni bo'yicha joyiga qaytariladi — o'rtadan tahrirlash ham
// buzilmaydi. Yopishtirilgan uzun matndan ("Kod: 042 913. Muddati 24 soat")
// kod ajratib olinadi.

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
    final pasted = _codeFromPaste(oldValue, raw);
    if (pasted != null) {
      final text = InviteCode.format(pasted);
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }

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
    // "-" faqat bo'linadigan (harfli/uzun) kodda bor: raqamli kodda yo'q.
    final hasDash = text.contains('-');
    final offset = hasDash && beforeCursor > _half
        ? beforeCursor + 1
        : beforeCursor;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset.clamp(0, text.length)),
    );
  }

  /// Bir martada 2+ belgi qo'shilsa (yopishtirish, avto-to'ldirish — tanlangan
  /// matn ustiga ham) va matn kodga o'xshamasa (ortiqcha so'z/belgi) — undan
  /// topilgan kod; aks holda `null` (oddiy yo'l: yozish va tahrirlash kursorni
  /// saqlaydi).
  String? _codeFromPaste(TextEditingValue oldValue, String raw) {
    if (_insertedLength(oldValue, raw) <= 1) return null;
    if (!InviteCode.looksLikeMessage(raw)) return null;
    return InviteCode.extract(raw);
  }

  /// Maydonga haqiqatda qo'shilgan belgilar soni. Tanlangan (almashtirilgan)
  /// qism hisobga olinadi: butun matn tanlanib uzunligi bir xil xabar
  /// yopishtirilsa, `uzunlik farqi` 0 bo'lsa ham bu yopishtirish.
  static int _insertedLength(TextEditingValue oldValue, String raw) {
    final selection = oldValue.selection;
    final length = oldValue.text.length;
    final replaced = selection.isValid
        ? selection.end.clamp(0, length) - selection.start.clamp(0, length)
        : 0;
    return raw.length - (length - replaced);
  }
}
