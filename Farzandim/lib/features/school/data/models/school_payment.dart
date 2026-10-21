// ─────────────────────────────────────────────────────────────────────
// SchoolPayment — to'lov eslatmalari va "to'laganman" so'rovlari
// ─────────────────────────────────────────────────────────────────────
//
// Backend: GET /api/parent/school/payments, GET|POST /verifications.
// Ataylab summa yoki qarz YO'Q — faqat maktab tasdiqlagan keyingi sana.

import 'package:farzandim/core/utils/safe_parse.dart';
import 'package:flutter/foundation.dart';

/// "To'laganman, tekshiring" xabarining eng katta uzunligi (backend).
const int kVerificationMessageMax = 500;

/// Eslatmaga kiritilgan farzand (maktab o'quvchisi).
@immutable
class PaymentChild {
  const PaymentChild({
    required this.id,
    required this.name,
    required this.className,
  });

  factory PaymentChild.fromJson(Map<String, dynamic> json) => PaymentChild(
    id: json.readString('id'),
    name: json.readString('name'),
    className: json.readString('className'),
  );

  final String id;
  final String name;
  final String className;
}

/// Bitta vasiy yozuvi bo'yicha to'lov eslatmasi.
@immutable
class SchoolPaymentReminder {
  const SchoolPaymentReminder({
    required this.id,
    required this.schoolId,
    required this.schoolName,
    required this.nextDate,
    required this.prepaidMonths,
    required this.paused,
    required this.children,
    required this.openVerification,
  });

  factory SchoolPaymentReminder.fromJson(Map<String, dynamic> json) =>
      SchoolPaymentReminder(
        id: json.readString('id'),
        schoolId: json.readString('schoolId'),
        schoolName: json.readString('schoolName'),
        nextDate: json.readString('nextDate'),
        prepaidMonths: json.readInt('prepaidMonths'),
        paused: json.readBool('paused'),
        children: List.unmodifiable(
          parseListSafely(
            json.readList('children'),
            PaymentChild.fromJson,
            tag: 'PaymentChild',
          ),
        ),
        openVerification: json.readBool('openVerification'),
      );

  final String id;
  final String schoolId;
  final String schoolName;

  /// Keyingi to'lov kuni, "YYYY-MM-DD" (maktab tasdiqlagan).
  final String nextDate;

  /// Oldindan to'langan oylar soni.
  final int prepaidMonths;

  /// Eslatmalar to'xtatilgan.
  final bool paused;
  final List<PaymentChild> children;

  /// Ochiq so'rov bor — yangisini yuborib bo'lmaydi (409).
  final bool openVerification;

  /// [nextDate] sana sifatida (buzuq → `null`).
  DateTime? get nextDay => DateTime.tryParse(nextDate);
}

/// Tekshiruv so'rovi holati.
enum VerificationStatus {
  open,
  answered,
  closed,
  unknown;

  static VerificationStatus fromApi(Object? raw) => switch (raw) {
    'OPEN' => open,
    'ANSWERED' => answered,
    'CLOSED' => closed,
    _ => unknown,
  };
}

/// "To'laganman, tekshiring" so'rovi va maktab javobi.
@immutable
class PaymentVerification {
  const PaymentVerification({
    required this.id,
    required this.paymentReminderId,
    required this.schoolId,
    required this.schoolName,
    required this.nextDate,
    required this.message,
    required this.status,
    this.answer,
    this.answeredAt,
    this.createdAt,
  });

  factory PaymentVerification.fromJson(Map<String, dynamic> json) =>
      PaymentVerification(
        id: json.readString('id'),
        paymentReminderId: json.readString('paymentReminderId'),
        schoolId: json.readString('schoolId'),
        schoolName: json.readString('schoolName'),
        nextDate: json.readString('nextDate'),
        message: json.readString('message'),
        status: VerificationStatus.fromApi(json['status']),
        answer: json.readStringOrNull('answer'),
        answeredAt: json.readDateTime('answeredAt'),
        createdAt: json.readDateTime('createdAt'),
      );

  final String id;
  final String paymentReminderId;
  final String schoolId;
  final String schoolName;

  /// So'rov yuborilgan paytdagi keyingi to'lov kuni ("YYYY-MM-DD").
  final String nextDate;
  final String message;
  final VerificationStatus status;

  /// Maktab javobi (bo'lsa).
  final String? answer;
  final DateTime? answeredAt;
  final DateTime? createdAt;

  bool get isOpen => status == VerificationStatus.open;
}
