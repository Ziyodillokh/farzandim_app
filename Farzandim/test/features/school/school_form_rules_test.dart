// Erta ketish va to'lov so'rovi formalari: UTF-16 uzunlik cheklovi (backend
// bilan bir xil), taklif qilinadigan vaqt, yuborish shartlari va sana/vaqt
// ko'rinishi.

import 'package:farzandim/features/school/data/models/school_attendance.dart';
import 'package:farzandim/features/school/data/models/school_payment.dart';
import 'package:farzandim/features/school/presentation/school_form_rules.dart';
import 'package:farzandim/features/school/presentation/school_format.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue _value(String text) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: text.length),
);

void main() {
  group('truncateUtf16', () {
    test('qisqa matn o`zgarmaydi, uzuni kesiladi', () {
      expect(truncateUtf16('salom', 10), 'salom');
      expect(truncateUtf16('abcdef', 4), 'abcd');
    });

    test('emoji (2 birlik) o`rtasidan bo`linmaydi', () {
      // "ab👍" = 2 + 2 birlik; 3 ga sig'maydi → emoji tashlanadi.
      expect(truncateUtf16('ab👍', 3), 'ab');
      expect(truncateUtf16('ab👍', 4), 'ab👍');
    });
  });

  group('SchoolLengthLimiter', () {
    const limiter = SchoolLengthLimiter(5);

    test('chegaragacha o`tkazadi', () {
      final next = limiter.formatEditUpdate(_value('abc'), _value('abcd'));
      expect(next.text, 'abcd');
    });

    test('chegarada yozish e`tiborsiz (oxiri o`chmaydi)', () {
      final old = _value('abcde');
      final next = limiter.formatEditUpdate(old, _value('abcdef'));
      expect(next, old);
    });

    test('uzun matn qo`yilsa qisqaradi', () {
      final next = limiter.formatEditUpdate(_value(''), _value('abcdefgh'));
      expect(next.text, 'abcde');
      expect(next.selection, const TextSelection.collapsed(offset: 5));
    });

    test('backend kabi UTF-16 sanaydi (emoji = 2)', () {
      final next = limiter.formatEditUpdate(_value('abcd'), _value('abcd👍'));
      expect(next.text, 'abcd');
    });
  });

  group('suggestedEarlyExitTime — keyingi chorak soat', () {
    final cases = {
      '13:07': (hour: 13, minute: 15),
      '13:00': (hour: 13, minute: 15),
      '13:14': (hour: 13, minute: 15),
      '13:15': (hour: 13, minute: 30),
      '09:59': (hour: 10, minute: 0),
      '23:44': (hour: 23, minute: 45),
      '23:45': (hour: 23, minute: 59),
      '23:58': (hour: 23, minute: 59),
    };
    for (final MapEntry(key: now, value: expected) in cases.entries) {
      test(now, () {
        final parts = now.split(':').map(int.parse).toList();
        final time = DateTime.utc(2026, 10, 20, parts[0], parts[1]);
        expect(suggestedEarlyExitTime(time), expected);
      });
    }
  });

  group('canSubmitEarlyExit', () {
    bool can({
      String? studentId = 'st-1',
      String? time = '13:30',
      String reason = 'Shifokor',
      String pickupBy = 'Onasi',
    }) => canSubmitEarlyExit(
      studentId: studentId,
      time: time,
      reason: reason,
      pickupBy: pickupBy,
    );

    test('to`liq forma', () => expect(can(), isTrue));

    test('o`quvchi yoki vaqt tanlanmagan', () {
      expect(can(studentId: null), isFalse);
      expect(can(studentId: ''), isFalse);
      expect(can(time: null), isFalse);
    });

    test('bo`sh (faqat bo`shliq) yoki juda uzun matn', () {
      expect(can(reason: '   '), isFalse);
      expect(can(pickupBy: ' '), isFalse);
      expect(can(reason: 'a' * (kEarlyExitReasonMax + 1)), isFalse);
      expect(can(pickupBy: 'a' * (kEarlyExitPickupMax + 1)), isFalse);
      expect(can(reason: ' ${'a' * kEarlyExitReasonMax} '), isTrue);
    });
  });

  test('canSubmitVerification', () {
    expect(canSubmitVerification(''), isFalse);
    expect(canSubmitVerification('  \n '), isFalse);
    expect(
      canSubmitVerification('3-noyabr kuni Click orqali to`ladim'),
      isTrue,
    );
    expect(canSubmitVerification('a' * kVerificationMessageMax), isTrue);
    expect(canSubmitVerification('a' * (kVerificationMessageMax + 1)), isFalse);
  });

  group('school_format', () {
    test('kun-kalitlari', () {
      expect(formatSchoolDay('2026-10-05'), '05.10.2026');
      expect(formatSchoolDayShort('2026-10-05'), '05.10');
      expect(formatSchoolDay('ertaga'), 'ertaga');
      expect(formatSchoolDayShort(''), '');
    });

    test('sana, vaqt va HH:MM', () {
      final at = DateTime(2026, 3, 7, 9, 5);
      expect(formatSchoolDate(at), '07.03.2026');
      expect(formatSchoolTime(at), '09:05');
      expect(formatHhMm(7, 0), '07:00');
      expect(formatHhMm(23, 59), '23:59');
    });

    test('vaqt belgisi: bugun — kalit, boshqa kun — sana bilan', () {
      final now = DateTime(2026, 10, 20, 18);
      expect(
        schoolStampLabel(DateTime(2026, 10, 19, 14, 5), now: now),
        '19.10.2026, 14:05',
      );
      // easy_localization testda yuklanmagan — `.tr()` kalitni qaytaradi.
      expect(
        schoolStampLabel(DateTime(2026, 10, 20, 8), now: now),
        'school.todayAt',
      );
      expect(
        schoolDayTimeLabel('2026-10-19', '13:30', today: '2026-10-20'),
        '19.10.2026, 13:30',
      );
      expect(
        schoolDayTimeLabel('2026-10-20', '13:30', today: '2026-10-20'),
        'school.todayAt',
      );
    });

    test('oy sarlavhasi: buzuq kalit o`zgarishsiz, yil oxirida', () {
      expect(schoolMonthTitle('oktyabr'), 'oktyabr');
      expect(schoolMonthTitle('2026-10'), endsWith(' 2026'));
    });
  });
}
