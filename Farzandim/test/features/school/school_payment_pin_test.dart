import 'package:farzandim/core/utils/tashkent_time.dart';
import 'package:farzandim/features/school/data/models/school_payment.dart';
import 'package:farzandim/features/school/presentation/providers/school_payment_providers.dart';
import 'package:farzandim/features/school/presentation/widgets/school_payment_pin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SchoolPaymentReminder _reminder(
  String id,
  String nextDate, {
  bool paused = false,
}) => SchoolPaymentReminder.fromJson({
  'id': id,
  'schoolId': 's1',
  'schoolName': 'Parvoz sinov maktabi',
  'nextDate': nextDate,
  'prepaidMonths': 0,
  'paused': paused,
  'children': const [
    {'id': 'c1', 'name': 'Kamola', 'className': '7-A'},
  ],
  'openVerification': false,
});

void main() {
  group('unpaidPayments', () {
    test("sanasi bugun yoki o'tgan eslatmalar qoladi, kelajakdagisi yo'q", () {
      final due = unpaidPayments([
        _reminder('future', '2026-11-05'),
        _reminder('today', '2026-10-21'),
        _reminder('late', '2026-10-01'),
      ], '2026-10-21');
      expect(due.map((r) => r.id), ['late', 'today']);
    });

    test("to'xtatilgan eslatma va bo'sh sana qadalmaydi", () {
      final due = unpaidPayments([
        _reminder('paused', '2026-10-01', paused: true),
        _reminder('empty', ''),
      ], '2026-10-21');
      expect(due, isEmpty);
    });

    test("natija o'zgarmas ro'yxat", () {
      final due = unpaidPayments([
        _reminder('late', '2026-10-01'),
      ], '2026-10-21');
      expect(
        () => due.add(_reminder('x', '2026-10-01')),
        throwsUnsupportedError,
      );
    });
  });

  group('unpaidSchoolPaymentsProvider', () {
    test("to'lovlar yuklansa — bugungi va o'tganlari", () async {
      final container = ProviderContainer(
        overrides: [
          schoolPaymentsProvider.overrideWith(
            (ref) async => [
              _reminder('late', '2000-01-01'),
              _reminder('future', '2999-01-01'),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(unpaidSchoolPaymentsProvider, (_, _) {});
      await container.read(schoolPaymentsProvider.future);
      expect(sub.read().map((r) => r.id), ['late']);
      expect(tashkentTodayStr().compareTo('2000-01-01'), greaterThan(0));
    });

    test("xato (maktab yo'q) — karta chiqmaydi", () async {
      final container = ProviderContainer(
        overrides: [
          schoolPaymentsProvider.overrideWith(
            (ref) async => throw StateError('no school'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(unpaidSchoolPaymentsProvider, (_, _) {});
      await expectLater(
        container.read(schoolPaymentsProvider.future),
        throwsStateError,
      );
      expect(sub.read(), isEmpty);
    });
  });
}
