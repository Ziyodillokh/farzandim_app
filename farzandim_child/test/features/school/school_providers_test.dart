// Providerlar: maktab UI'si faqat bog'langan bolada; server funksiyani
// bilmasa (404 kodsiz) xatosiz yashiriladi; ro'yxatlar bog'lanmaganda
// so'rovsiz bo'sh; QR natijasi bugungi holatni darhol yangilaydi; boshqa
// bolaga qayta ulanganda oldingi bolaning maktabi ko'rinmaydi; til serverga
// yozilgach til bo'yicha ro'yxatlar qayta yuklanadi.

import 'dart:async';

import 'package:farzandim_child/features/account/presentation/providers/language_sync_provider.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/features/school/domain/attendance_models.dart';
import 'package:farzandim_child/features/school/domain/care_models.dart';
import 'package:farzandim_child/features/school/domain/psych_models.dart';
import 'package:farzandim_child/features/school/domain/school_assignment.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_school_repository.dart';
import 'school_fixtures.dart';

final _today = SchoolToday.tryFromJson(todayJson)!;

/// Ulangan bola (`null` — ulanmagan); testda almashtiriladi.
final _account = StateProvider<String?>((ref) => 'child-1');

ProviderContainer _container(FakeSchoolRepository repo) {
  final c = ProviderContainer(
    overrides: [
      schoolRepositoryProvider.overrideWithValue(repo),
      schoolAccountProvider.overrideWith((ref) => ref.watch(_account)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

/// Ro'yxatlar `autoDispose` — ekrandagidek kuzatilgan holda o'qiladi.
void _watchLists(ProviderContainer c) {
  c
    ..listen(psychAssignmentsProvider, (_, _) {})
    ..listen(careSurveyProvider, (_, _) {})
    ..listen(careRequestsProvider, (_, _) {})
    ..listen(schoolAssignmentsProvider, (_, _) {});
}

/// Bugungi holat yuklanishini kutish (xato bo'lsa ham).
Future<void> _loadToday(ProviderContainer c) async {
  try {
    await c.read(schoolTodayProvider.future);
  } on SchoolException {
    // Holat provider'da tekshiriladi.
  }
}

void main() {
  test(
    'bog\'lanmagan: maktab yashirin, ro\'yxatlar so\'rovsiz bo\'sh',
    () async {
      final repo = FakeSchoolRepository();
      final c = _container(repo);
      await _loadToday(c);
      _watchLists(c);

      expect(c.read(isSchoolLinkedProvider), isFalse);
      expect(await c.read(psychAssignmentsProvider.future), isEmpty);
      expect(await c.read(careRequestsProvider.future), isEmpty);
      expect(await c.read(schoolAssignmentsProvider.future), isEmpty);
      expect((await c.read(careSurveyProvider.future)).isEnrolled, isFalse);
      expect(repo.calls, ['loadToday']);
    },
  );

  test(
    'server funksiyani bilmaydi (404 kodsiz) — xatosiz yashiriladi',
    () async {
      final repo = FakeSchoolRepository(today: _today)
        ..failNext = const SchoolException(SchoolErrorCode.unavailable);
      final c = _container(repo);
      await _loadToday(c);

      final state = c.read(schoolTodayProvider);
      expect(state.hasError, isFalse);
      expect(state.value, isNull);
      expect(c.read(isSchoolLinkedProvider), isFalse);
    },
  );

  test('tarmoq xatosi — holat xato, maktab UI ko\'rinmaydi', () async {
    final repo = FakeSchoolRepository(today: _today)
      ..failNext = const SchoolException(SchoolErrorCode.network);
    final c = _container(repo);
    await _loadToday(c);

    expect(c.read(schoolTodayProvider).hasError, isTrue);
    expect(c.read(isSchoolLinkedProvider), isFalse);
  });

  test('bog\'langan: ro\'yxatlar serverdan yuklanadi', () async {
    final repo = FakeSchoolRepository(
      today: _today,
      careSurvey: CareSurveyStatus.tryFromJson(careSurveyJson)!,
      careRequests: [CareRequest.tryFromJson(careRequestJson)!],
      psychAssignments: [PsychAssignmentSummary.tryFromJson(psychSummaryJson)!],
      assignments: [SchoolAssignment.tryFromJson(schoolAssignmentJson)!],
    );
    final c = _container(repo);
    await _loadToday(c);
    _watchLists(c);

    expect(c.read(isSchoolLinkedProvider), isTrue);
    expect(
      (await c.read(psychAssignmentsProvider.future)).single.assignmentId,
      'assign-1',
    );
    expect((await c.read(careSurveyProvider.future)).survey?.id, 'survey-1');
    expect((await c.read(careRequestsProvider.future)).single.id, 'req-1');
    expect((await c.read(schoolAssignmentsProvider.future)).single.id, 'sa-1');
  });

  test('ro\'yxat "unavailable" bo\'lsa — bo\'sh, xatosiz', () async {
    final repo = FakeSchoolRepository(
      today: _today,
      psychAssignments: [PsychAssignmentSummary.tryFromJson(psychSummaryJson)!],
    );
    final c = _container(repo);
    await _loadToday(c);
    repo.failNext = const SchoolException(SchoolErrorCode.unavailable);
    _watchLists(c);

    expect(await c.read(psychAssignmentsProvider.future), isEmpty);
  });

  test('ulanmagan — maktab so\'ralmaydi', () async {
    final repo = FakeSchoolRepository(today: _today);
    final c = _container(repo);
    c.read(_account.notifier).state = null;
    await _loadToday(c);

    expect(c.read(isSchoolLinkedProvider), isFalse);
    expect(repo.calls, isEmpty);
  });

  group('boshqa bolaga qayta ulanish', () {
    final otherToday = SchoolToday.tryFromJson({
      ...todayJson,
      'schoolName': 'Boshqa maktab',
    })!;

    test('yangi bola holati yuklanayotganda oldingisi ko\'rinmaydi', () async {
      final repo = FakeSchoolRepository(today: _today);
      final c = _container(repo);
      await _loadToday(c);
      expect(c.read(isSchoolLinkedProvider), isTrue);

      // Hech narsa kuzatmayotganda (ulanish ekrani) boshqa bolaga o'tildi.
      repo.today = otherToday;
      final slowLoad = repo.holdNextToday = Completer<void>();
      c.read(_account.notifier).state = 'child-2';

      expect(c.read(schoolTodayProvider).valueOrNull, isNull);
      expect(c.read(isSchoolLinkedProvider), isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(schoolTodayProvider).isLoading, isTrue);
      expect(c.read(schoolTodayProvider).valueOrNull, isNull);

      slowLoad.complete();
      await _loadToday(c);
      expect(c.read(schoolTodayProvider).value?.schoolName, 'Boshqa maktab');
      expect(repo.calls, ['loadToday', 'loadToday']);
    });

    test('uzilganda maktab darhol yashiriladi', () async {
      final repo = FakeSchoolRepository(today: _today);
      final c = _container(repo);
      c.listen(isSchoolLinkedProvider, (_, _) {});
      await _loadToday(c);
      expect(c.read(isSchoolLinkedProvider), isTrue);

      c.read(_account.notifier).state = null;
      expect(c.read(isSchoolLinkedProvider), isFalse);
      expect(c.read(schoolTodayProvider).valueOrNull, isNull);
    });

    test('murojaatlar ro\'yxati yangi bolaga o\'tmaydi', () async {
      final repo = FakeSchoolRepository(
        today: _today,
        careRequests: [CareRequest.tryFromJson(careRequestJson)!],
      );
      final c = _container(repo);
      await _loadToday(c);
      final sub = c.listen(careRequestsProvider, (_, _) {});
      expect((await c.read(careRequestsProvider.future)).single.id, 'req-1');

      // Ekran yopildi (ulanish ekrani) — ro'yxat xotiradan tashlanadi.
      sub.close();
      await Future<void>.delayed(Duration.zero);
      repo
        ..careRequests.clear()
        ..today = otherToday;
      c.read(_account.notifier).state = 'child-2';
      await Future<void>.delayed(Duration.zero);
      await _loadToday(c);

      c.listen(careRequestsProvider, (_, _) {});
      expect(c.read(careRequestsProvider).valueOrNull, isNull);
      expect(await c.read(careRequestsProvider.future), isEmpty);
    });
  });

  test(
    'til serverga yozilgach testlar va so\'rovnoma qayta yuklanadi',
    () async {
      final repo = FakeSchoolRepository(today: _today);
      final c = _container(repo);
      await _loadToday(c);
      _watchLists(c);
      await c.read(psychAssignmentsProvider.future);
      await c.read(careSurveyProvider.future);
      await c.read(careRequestsProvider.future);
      repo.calls.clear();

      c.read(syncedLanguageRevisionProvider.notifier).state++;
      await c.read(psychAssignmentsProvider.future);
      await c.read(careSurveyProvider.future);
      await c.read(careRequestsProvider.future);

      expect(
        repo.calls,
        unorderedEquals(['loadPsychAssignments', 'loadCareSurvey']),
      );
    },
  );

  test('yangilanayotganda va oflaynda bog\'langan holat saqlanadi', () async {
    final repo = FakeSchoolRepository(today: _today);
    final c = _container(repo);
    c.listen(isSchoolLinkedProvider, (_, _) {});
    await _loadToday(c);
    expect(c.read(isSchoolLinkedProvider), isTrue);

    repo.failNext = const SchoolException(SchoolErrorCode.network);
    c.invalidate(schoolTodayProvider);
    expect(c.read(schoolTodayProvider).isLoading, isTrue);
    expect(c.read(isSchoolLinkedProvider), isTrue);

    await _loadToday(c);
    expect(c.read(schoolTodayProvider).hasError, isTrue);
    expect(c.read(isSchoolLinkedProvider), isTrue);
  });

  test('QR natijasi bugungi holatni qayta yuklashsiz yangilaydi', () async {
    final repo = FakeSchoolRepository(today: _today);
    final c = _container(repo);
    await _loadToday(c);

    repo.today = SchoolToday.tryFromJson({
      ...todayJson,
      'record': {'status': 'PRESENT', 'inAt': '07:58', 'source': 'QR'},
    });
    final result = await c
        .read(schoolTodayProvider.notifier)
        .checkIn('abc.def');

    expect(result.action, CheckInAction.arrived);
    expect(c.read(schoolTodayProvider).value?.record?.inAt, '07:58');
    expect(repo.calls, ['loadToday', 'checkIn']);
  });

  test('QR xatosi holatni buzmaydi', () async {
    final repo = FakeSchoolRepository(today: _today);
    final c = _container(repo);
    await _loadToday(c);
    repo.failNext = const SchoolException(SchoolErrorCode.kioskExpired);

    await expectLater(
      c.read(schoolTodayProvider.notifier).checkIn('abc.def'),
      throwsA(isA<SchoolException>()),
    );
    expect(c.read(schoolTodayProvider).value?.record?.inAt, '08:12');
  });

  test('skanerlashdan oldingi sekin yuklash yangi holatni bosmaydi', () async {
    final before = SchoolToday.tryFromJson({...todayJson, 'record': null})!;
    final repo = FakeSchoolRepository(today: before);
    final c = _container(repo);
    c.listen(schoolTodayProvider, (_, _) {});
    await _loadToday(c);

    // Yangilash boshlandi — server hali "kelmagan" holatni qaytaradi.
    final slowLoad = repo.holdNextToday = Completer<void>();
    c.invalidate(schoolTodayProvider);
    expect(c.read(schoolTodayProvider).isLoading, isTrue);

    repo.today = _today;
    await c.read(schoolTodayProvider.notifier).checkIn('abc.def');
    expect(c.read(schoolTodayProvider).value?.record?.inAt, '08:12');

    slowLoad.complete();
    await _loadToday(c);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(schoolTodayProvider).value?.record?.inAt, '08:12');
    expect(repo.calls, ['loadToday', 'loadToday', 'checkIn', 'loadToday']);
  });
}
