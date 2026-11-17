// ─────────────────────────────────────────────────────────────────────
// payment_view_models — To'lovlar sahifasi mantiqi (widget'siz, testlanadi)
// ─────────────────────────────────────────────────────────────────────
//
// Platforma summa yoki qarz hisoblamaydi (TZ 4.5): holat faqat maktab
// tasdiqlagan keyingi sana, to'xtatilganlik, oldindan to'langan oylar va
// ochiq "to'laganman" so'rovidan kelib chiqadi.

import 'package:farzandim/features/school/data/models/school_payment.dart';
import 'package:flutter/foundation.dart';

/// Eslatma holati (ustuvorlik tartibida).
enum PaymentStatusKind {
  /// Maktab eslatmalarni to'xtatgan.
  paused,

  /// "To'laganman" so'rovi maktabda ko'rib chiqilmoqda.
  checking,

  /// Sana o'tgan.
  overdue,

  /// Bugun to'lov kuni.
  today,

  /// Hali bor (necha kun qolgani bilan).
  upcoming,

  /// Sana noma'lum (buzuq qiymat).
  unknown,
}

@immutable
class PaymentStatus {
  const PaymentStatus(this.kind, {this.days = 0});

  final PaymentStatusKind kind;

  /// `upcoming` — qolgan kunlar; `overdue` — o'tgan kunlar.
  final int days;

  /// Tez orada (7 kun ichida) — ogohlantirish rangi.
  bool get isSoon => kind == PaymentStatusKind.upcoming && days <= 7;

  @override
  bool operator ==(Object other) =>
      other is PaymentStatus && other.kind == kind && other.days == days;

  @override
  int get hashCode => Object.hash(kind, days);

  @override
  String toString() => 'PaymentStatus(${kind.name}, $days)';
}

/// [today] — mahalliy kun (vaqtsiz).
PaymentStatus paymentStatusOf(SchoolPaymentReminder r, DateTime today) {
  if (r.paused) return const PaymentStatus(PaymentStatusKind.paused);
  if (r.openVerification) {
    return const PaymentStatus(PaymentStatusKind.checking);
  }
  final next = r.nextDay;
  if (next == null) return const PaymentStatus(PaymentStatusKind.unknown);
  final day = DateTime(today.year, today.month, today.day);
  final due = DateTime(next.year, next.month, next.day);
  final diff = due.difference(day).inDays;
  if (diff < 0) return PaymentStatus(PaymentStatusKind.overdue, days: -diff);
  if (diff == 0) return const PaymentStatus(PaymentStatusKind.today);
  return PaymentStatus(PaymentStatusKind.upcoming, days: diff);
}

/// Maktab sahifasidagi «To'lovlar» plitasi uchun jamlanma.
@immutable
class PaymentsSummary {
  const PaymentsSummary({this.due = 0, this.checking = 0, this.nextInDays});

  /// To'lov kuni kelgan yoki o'tgan (to'xtatilmagan, tekshiruvda emas).
  final int due;

  /// "To'laganman" so'rovi maktabda ko'rib chiqilmoqda.
  final int checking;

  /// Eng yaqin kelgusi to'lovgacha kunlar (`null` — kelgusi yo'q).
  final int? nextInDays;
}

PaymentsSummary paymentsSummaryOf(
  List<SchoolPaymentReminder> reminders,
  DateTime today,
) {
  final statuses = [for (final r in reminders) paymentStatusOf(r, today)];
  final upcoming = [
    for (final s in statuses)
      if (s.kind == PaymentStatusKind.upcoming) s.days,
  ];
  return PaymentsSummary(
    due: statuses
        .where(
          (s) =>
              s.kind == PaymentStatusKind.overdue ||
              s.kind == PaymentStatusKind.today,
        )
        .length,
    checking: statuses
        .where((s) => s.kind == PaymentStatusKind.checking)
        .length,
    nextInDays: upcoming.isEmpty
        ? null
        : upcoming.reduce((a, b) => a < b ? a : b),
  );
}

/// Tarix yozuvi turi (maktab amali yoki ota-onaning so'rovi).
enum PaymentEventKind { schoolAction, requestSent, schoolAnswered }

@immutable
class PaymentEvent {
  const PaymentEvent({
    required this.kind,
    required this.at,
    this.action,
    this.text,
    this.verificationId,
    this.hasReceipt = false,
  });

  final PaymentEventKind kind;
  final DateTime at;
  final PaymentAction? action;

  /// So'rov matni yoki maktab javobi.
  final String? text;
  final String? verificationId;

  /// Ota-ona so'roviga chek rasmi biriktirilgan.
  final bool hasReceipt;
}

/// Maktab amallari va so'rovlar bitta tarixda (yangisi oldin).
List<PaymentEvent> paymentTimeline(
  List<SchoolPaymentReminder> reminders,
  List<PaymentVerification> verifications,
) {
  final events = <PaymentEvent>[
    for (final r in reminders)
      for (final e in r.history)
        if (e.at != null)
          PaymentEvent(
            kind: PaymentEventKind.schoolAction,
            at: e.at!,
            action: e.action,
          ),
    for (final v in verifications) ...[
      if (v.createdAt != null)
        PaymentEvent(
          kind: PaymentEventKind.requestSent,
          at: v.createdAt!,
          text: v.message,
          verificationId: v.id,
          hasReceipt: v.hasReceipt,
        ),
      if (v.answeredAt != null && (v.answer ?? '').trim().isNotEmpty)
        PaymentEvent(
          kind: PaymentEventKind.schoolAnswered,
          at: v.answeredAt!,
          text: v.answer,
          verificationId: v.id,
        ),
    ],
  ]..sort((a, b) => b.at.compareTo(a.at));
  return List.unmodifiable(events);
}

/// "To'laganman" xabari tuzilgan maydonlardan (bo'sh qismlar tashlanadi).
/// [labels] — `school.payments.composed.*` tarjimalari (`{value}` bilan).
String composeVerificationMessage({
  required ({String method, String months}) labels,
  String? method,
  List<String> months = const [],
  String note = '',
}) {
  final parts = <String>[
    if (method != null && method.isNotEmpty)
      labels.method.replaceAll('{value}', method),
    if (months.isNotEmpty)
      labels.months.replaceAll('{value}', months.join(', ')),
    if (note.trim().isNotEmpty) note.trim(),
  ];
  return parts.join(' ');
}

/// To'lov usuli. Onlayn usulda chek rasmi (skrinshot) so'raladi; naqdda —
/// faqat izoh.
enum PaymentMethod {
  click,
  payme,
  uzum,
  card,
  transfer,
  cash;

  bool get isOnline => this != cash;

  /// `school.payments.methods.<name>`.
  String get labelKey => 'school.payments.methods.$name';
}

/// O'quv yilining 12 oyi (sentabr → avgust); [base] — to'lov sanasi yoki
/// bugun. Masalan 2026-11 → 2026-09 … 2027-08.
List<DateTime> academicYearMonths(DateTime base) {
  final startYear = base.month >= 9 ? base.year : base.year - 1;
  return List.unmodifiable([
    for (var i = 0; i < 12; i++) DateTime(startYear, 9 + i),
  ]);
}
