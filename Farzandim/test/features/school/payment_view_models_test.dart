// To'lovlar sahifasi mantiqi: holat (sana, to'xtatilgan, tekshirilmoqda),
// tarix (maktab amallari + so'rovlar) va "to'laganman" matni.

import 'package:farzandim/features/school/data/models/school_payment.dart';
import 'package:farzandim/features/school/presentation/payment_view_models.dart';
import 'package:flutter_test/flutter_test.dart';

SchoolPaymentReminder _reminder({
  String nextDate = '2026-11-15',
  bool paused = false,
  bool open = false,
  List<PaymentHistoryEntry> history = const [],
}) => SchoolPaymentReminder(
  id: 'p-1',
  schoolId: 's-1',
  schoolName: '24-maktab',
  nextDate: nextDate,
  prepaidMonths: 0,
  paused: paused,
  children: const [],
  openVerification: open,
  history: history,
);

void main() {
  final today = DateTime(2026, 11, 9, 15, 30);

  group('paymentStatusOf', () {
    test('qolgan kunlar, bugun va o`tgan kunlar', () {
      expect(
        paymentStatusOf(_reminder(), today),
        const PaymentStatus(PaymentStatusKind.upcoming, days: 6),
      );
      expect(paymentStatusOf(_reminder(), today).isSoon, isTrue);
      expect(
        paymentStatusOf(_reminder(nextDate: '2026-12-20'), today).isSoon,
        isFalse,
      );
      expect(
        paymentStatusOf(_reminder(nextDate: '2026-11-09'), today).kind,
        PaymentStatusKind.today,
      );
      expect(
        paymentStatusOf(_reminder(nextDate: '2026-11-06'), today),
        const PaymentStatus(PaymentStatusKind.overdue, days: 3),
      );
    });

    test('to`xtatilgan va tekshirilayotgan sanadan ustun; buzuq sana', () {
      expect(
        paymentStatusOf(
          _reminder(nextDate: '2026-11-01', paused: true),
          today,
        ).kind,
        PaymentStatusKind.paused,
      );
      expect(
        paymentStatusOf(
          _reminder(nextDate: '2026-11-01', open: true),
          today,
        ).kind,
        PaymentStatusKind.checking,
      );
      expect(
        paymentStatusOf(_reminder(nextDate: 'x'), today).kind,
        PaymentStatusKind.unknown,
      );
    });
  });

  test(
    'paymentTimeline: amallar va so`rovlar bitta tarixda, yangisi oldin',
    () {
      final events = paymentTimeline(
        [
          _reminder(
            history: [
              PaymentHistoryEntry(
                action: PaymentAction.created,
                at: DateTime(2026, 9, 2),
              ),
              PaymentHistoryEntry(
                action: PaymentAction.verified,
                at: DateTime(2026, 10, 14, 11),
              ),
            ],
          ),
        ],
        [
          PaymentVerification(
            id: 'v-1',
            paymentReminderId: 'p-1',
            schoolId: 's-1',
            schoolName: '24-maktab',
            nextDate: '2026-10-15',
            message: "To'ladim",
            status: VerificationStatus.answered,
            answer: 'Qabul qilindi',
            answeredAt: DateTime(2026, 10, 14, 10),
            createdAt: DateTime(2026, 10, 13, 19),
          ),
        ],
      );
      expect(events.map((e) => e.kind), [
        PaymentEventKind.schoolAction,
        PaymentEventKind.schoolAnswered,
        PaymentEventKind.requestSent,
        PaymentEventKind.schoolAction,
      ]);
      expect(events.first.action, PaymentAction.verified);
      expect(events[1].text, 'Qabul qilindi');
      expect(events[1].verificationId, 'v-1');
    },
  );

  test('composeVerificationMessage: bo`sh qismlar tashlanadi', () {
    const labels = (method: 'Usul: {value}.', months: 'Oy: {value}.');
    expect(
      composeVerificationMessage(
        labels: labels,
        method: 'Click',
        months: const ['Oktyabr 2026', 'Noyabr 2026'],
        note: ' Ikkala farzand uchun ',
      ),
      'Usul: Click. Oy: Oktyabr 2026, Noyabr 2026. Ikkala farzand uchun',
    );
    expect(composeVerificationMessage(labels: labels), '');
    expect(
      composeVerificationMessage(labels: labels, note: 'Naqd berdim'),
      'Naqd berdim',
    );
  });

  test('academicYearMonths: sentabrdan avgustgacha 12 oy', () {
    final fromNov = academicYearMonths(DateTime(2026, 11, 15));
    expect(fromNov, hasLength(12));
    expect(fromNov.first, DateTime(2026, 9));
    expect(fromNov.last, DateTime(2027, 8));
    // Bahorgi sana — o'tgan sentabrdan boshlangan o'quv yili.
    expect(academicYearMonths(DateTime(2027, 3, 5)).first, DateTime(2026, 9));
    expect(academicYearMonths(DateTime(2027, 9)).first, DateTime(2027, 9));
  });

  test(
    'PaymentMethod: naqddan boshqa usullar onlayn (chek rasmi so`raladi)',
    () {
      expect(PaymentMethod.values.where((m) => !m.isOnline), [
        PaymentMethod.cash,
      ]);
      expect(PaymentMethod.click.labelKey, 'school.payments.methods.click');
    },
  );

  test('to`lov tarixi JSON: amallar, BULK_SHIFT — sana o`zgarishi', () {
    final r = SchoolPaymentReminder.fromJson(const {
      'id': 'p-1',
      'nextDate': '2026-11-15',
      'history': [
        {'at': '2026-10-14T06:20:00.000Z', 'action': 'BULK_SHIFT'},
        {'at': '2026-09-01T05:00:00.000Z', 'action': 'CREATED'},
        {'action': 'PAUSED'},
      ],
    });
    expect(r.history.map((e) => e.action), [
      PaymentAction.shifted,
      PaymentAction.created,
    ]);
  });

  group('paymentsSummaryOf (Maktab sahifasidagi «To`lovlar» plitasi)', () {
    test('to`lov kuni kelgan va o`tganlar — to`lanmagan', () {
      final summary = paymentsSummaryOf([
        _reminder(nextDate: '2026-11-09'),
        _reminder(nextDate: '2026-11-01'),
        _reminder(nextDate: '2026-11-20'),
      ], today);
      expect(summary.due, 2);
      expect(summary.checking, 0);
      expect(summary.nextInDays, 11);
    });

    test('to`xtatilgan va tekshirilayotgan to`lanmagan hisoblanmaydi', () {
      final summary = paymentsSummaryOf([
        _reminder(nextDate: '2026-11-01', paused: true),
        _reminder(nextDate: '2026-11-01', open: true),
      ], today);
      expect(summary.due, 0);
      expect(summary.checking, 1);
      expect(summary.nextInDays, isNull);
    });

    test('eslatma yo`q — bo`sh', () {
      final summary = paymentsSummaryOf(const [], today);
      expect((summary.due, summary.checking, summary.nextInDays), (0, 0, null));
    });
  });
}
