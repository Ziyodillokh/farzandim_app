// Kelajak provayderi va sof mantiq: bo'lim yo'q (404 `code`siz) → `null`
// (kartalar yashirinadi), boshqa xato — xato holati; karta holati
// (yosh / bo'sh / shakllanmoqda / top yo'nalishlar), o'zgarish belgisi
// foizsiz, qiziqishi ortayotgan yo'nalishlar va Career Lab guruhlari.

import 'package:dio/dio.dart';
import 'package:farzandim/features/kelajak/data/kelajak_repository.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_summary.dart';
import 'package:farzandim/features/kelajak/presentation/kelajak_view_models.dart';
import 'package:farzandim/features/kelajak/presentation/providers/kelajak_providers.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kelajak_fixtures.dart';

class _FakeKelajakRepository extends KelajakRepository {
  _FakeKelajakRepository() : super(dio: Dio());

  SchoolFailure? error;
  String fixture = kRichSupportFixture;
  int fetches = 0;

  @override
  Future<KelajakSummary> fetchSummary(String childId) async {
    fetches++;
    final error = this.error;
    if (error != null) throw error;
    return kelajakFixture(fixture);
  }
}

KelajakSummary _summary(Map<String, dynamic> patch) =>
    KelajakSummary.fromJson({...kelajakFixtureJson(kEmptyFixture), ...patch});

void main() {
  late _FakeKelajakRepository repo;

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [kelajakRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => repo = _FakeKelajakRepository());

  group('kelajakSummaryProvider', () {
    test('xulosa yuklanadi va kesh qayta so`ramaydi', () async {
      final container = makeContainer();
      final summary = await container.read(
        kelajakSummaryProvider('kid-1').future,
      );
      expect(summary?.sessionsCompleted, 7);
      await container.read(kelajakSummaryProvider('kid-1').future);
      expect(repo.fetches, 1);
    });

    test('bo`lim yo`q (unavailable) → null — karta yashirinadi', () async {
      repo.error = const SchoolFailure(SchoolFailureKind.unavailable);
      final container = makeContainer();
      final summary = await container.read(
        kelajakSummaryProvider('kid-1').future,
      );
      expect(summary, isNull);
      expect(KelajakCardMode.of(summary), isA<KelajakCardHidden>());
    });

    test('ruxsat yo`q → xato holati (null emas)', () async {
      repo.error = const SchoolFailure(SchoolFailureKind.forbidden);
      final container = makeContainer();
      await expectLater(
        container.read(kelajakSummaryProvider('kid-1').future),
        throwsA(isA<SchoolFailure>()),
      );
    });
  });

  group('KelajakCardMode', () {
    test('boy profil → top yo`nalishlar (RIASEC nomi bilan)', () {
      final mode = KelajakCardMode.of(kelajakFixture(kRichSupportFixture));
      expect(mode, isA<KelajakCardInterests>());
      final names = (mode as KelajakCardInterests).names;
      expect(names.map((n) => n.of('uz')), [
        'Ijodiy',
        'Tadqiqotchi',
        'Ijtimoiy',
      ]);
    });

    test('javob yo`q → bo`sh; yosh yo`q → yosh so`raladi', () {
      expect(
        KelajakCardMode.of(kelajakFixture(kEmptyFixture)),
        isA<KelajakCardEmpty>(),
      );
      expect(
        KelajakCardMode.of(kelajakFixture(kAgeRequiredFixture)),
        isA<KelajakCardAgeRequired>(),
      );
    });

    test('testlar bor, yo`nalish hali yo`q → shakllanmoqda', () {
      final mode = KelajakCardMode.of(kelajakFixture(kWatchFixture));
      expect(mode, isA<KelajakCardForming>());
      expect((mode as KelajakCardForming).sessions, 1);
    });

    test('7–18 dan tashqari va javobsiz → yashirin', () {
      final outOfRange = _summary({
        'age': {'status': 'AGE_OUT_OF_RANGE', 'age': 5, 'ageGroup': null},
      });
      expect(KelajakCardMode.of(outOfRange), isA<KelajakCardHidden>());
    });
  });

  test('o`zgarish belgisi foizsiz; yosh guruhi', () {
    expect(kelajakDeltaLabel(25), '+25');
    expect(kelajakDeltaLabel(-10), '−10');
    expect(kelajakDeltaLabel(0), '0');
    expect(kelajakAgeGroupLabel('10-12'), '10–12');
  });

  test('qiziqishi ortayotgan yo`nalishlar (delta ≥ 10)', () {
    final progress = kelajakFixture(kRichSupportFixture).progress;
    expect(kelajakRisingInterests(progress).map((i) => i.code), ['S']);
    expect(kelajakHasProgress(progress), isTrue);
    expect(kelajakHasProgress(kelajakFixture(kEmptyFixture).progress), isFalse);
  });

  test('Career Lab guruhlari va umumiy tavsiyalar', () {
    final rich = kelajakFixture(kRichSupportFixture).insights;
    final lab = KelajakCareerLabView.of(rich);
    expect(lab.liked.map((d) => d.code), ['R', 'C']);
    expect(lab.neutral.single.activity.of('uz'), 'Jamoaviy loyiha');
    expect(
      lab.disliked.single.activity.of('uz'),
      'Mavzuni boshqalarga tushuntirish',
    );
    expect(lab.next, hasLength(1));
    expect(kelajakGeneralNextSteps(rich), isEmpty);

    final empty = kelajakFixture(kEmptyFixture);
    expect(KelajakCareerLabView.of(empty.insights).isEmpty, isTrue);
    expect(kelajakGeneralNextSteps(empty.insights), hasLength(2));
    expect(kelajakShowsEmptyState(empty), isTrue);
    expect(kelajakShowsEmptyState(kelajakFixture(kWatchFixture)), isFalse);
  });
}
