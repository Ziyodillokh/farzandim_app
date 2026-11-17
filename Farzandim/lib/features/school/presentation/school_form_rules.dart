// ─────────────────────────────────────────────────────────────────────
// school_form_rules — erta ketish va to'lov so'rovi formalari qoidalari
// ─────────────────────────────────────────────────────────────────────
//
// Backend matnni `trim()` qilib, uzunligini JS satr uzunligi (UTF-16) bo'yicha
// tekshiradi. Flutter'ning `maxLength`i esa grafemalarni sanaydi — emoji
// bilan farq qilib, 160/160 ko'rinsa ham server rad etardi. Shu sabab
// cheklov va hisoblagich UTF-16 bo'yicha. Sof funksiyalar — testlanadi.

import 'package:farzandim/features/school/data/models/school_attendance.dart';
import 'package:farzandim/features/school/data/models/school_payment.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

/// Erta ketish vaqtini taklif qilish qadami (daqiqa).
const int _suggestStepMinutes = 15;

const int _minutesPerDay = 24 * 60;

/// [text]ni [max] UTF-16 birligigacha qisqartiradi; belgi (emoji, harf)
/// o'rtasidan bo'linmaydi.
String truncateUtf16(String text, int max) {
  if (text.length <= max) return text;
  final buffer = StringBuffer();
  var length = 0;
  for (final char in text.characters) {
    if (length + char.length > max) break;
    buffer.write(char);
    length += char.length;
  }
  return buffer.toString();
}

/// Matn uzunligini backend kabi (UTF-16) cheklaydi. Chegarada yozish
/// e'tiborsiz qoldiriladi (oxiri o'chmaydi), uzun matn qo'yilsa qisqaradi.
class SchoolLengthLimiter extends TextInputFormatter {
  const SchoolLengthLimiter(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length <= max) return newValue;
    if (oldValue.text.length >= max && oldValue.selection.isCollapsed) {
      return oldValue;
    }
    final text = truncateUtf16(newValue.text, max);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: newValue.selection.end.clamp(0, text.length),
      ),
    );
  }
}

/// Erta ketish uchun taklif qilinadigan vaqt: [now]dan keyingi chorak soat
/// (13:07 → 13:15); yarim tundan oshsa — 23:59.
({int hour, int minute}) suggestedEarlyExitTime(DateTime now) {
  final minutes = now.hour * 60 + now.minute;
  final next = (minutes ~/ _suggestStepMinutes + 1) * _suggestStepMinutes;
  if (next >= _minutesPerDay) return (hour: 23, minute: 59);
  return (hour: next ~/ 60, minute: next % 60);
}

/// Erta ketish formasi to'liqmi (yuborish tugmasi yonadi).
bool canSubmitEarlyExit({
  required String? studentId,
  required String? time,
  required String reason,
  required String pickupBy,
}) {
  final why = reason.trim();
  final who = pickupBy.trim();
  return (studentId?.isNotEmpty ?? false) &&
      (time?.isNotEmpty ?? false) &&
      why.isNotEmpty &&
      why.length <= kEarlyExitReasonMax &&
      who.isNotEmpty &&
      who.length <= kEarlyExitPickupMax;
}

/// "To'laganman, tekshiring" xabari yuborishga yaroqlimi.
bool canSubmitVerification(String message) {
  final text = message.trim();
  return text.isNotEmpty && text.length <= kVerificationMessageMax;
}
