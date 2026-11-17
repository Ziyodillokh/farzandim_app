// Maktab provayderlari (soxta repository bilan): bo'lim mavjud emasligi UI'ni
// yashiradi, farzandga moslangan o'quvchi tanlanadi, amallar `Result`
// qaytaradi va ro'yxatni faqat kerak bo'lganda qayta yuklaydi.

import 'package:dio/dio.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:farzandim/features/school/data/school_repository.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Backend'ni taqlid qiladi: `links` qaytaradi yoki `error` otadi.
class _FakeSchoolRepository extends SchoolRepository {
  _FakeSchoolRepository() : super(dio: Dio());

  SchoolLinks links = SchoolLinks.empty;
  Exception? linksError;
  Exception? actionError;
  int linkFetches = 0;
  final List<String> calls = [];

  @override
  Future<SchoolLinks> fetchLinks() async {
    linkFetches++;
    final error = linksError;
    if (error != null) throw error;
    return links;
  }

  @override
  Future<SchoolLinks> redeemInvite(String rawCode) async {
    calls.add('redeem:$rawCode');
    final error = actionError;
    if (error != null) throw error;
    return links;
  }

  @override
  Future<SchoolLinks> setStudentChild({
    required String studentId,
    required String? childId,
  }) async {
    calls.add('setChild:$studentId:$childId');
    final error = actionError;
    if (error != null) throw error;
    return links;
  }

  @override
  Future<void> unlink(String guardianId) async {
    calls.add('unlink:$guardianId');
    final error = actionError;
    if (error != null) throw error;
  }
}

SchoolLinks _sampleLinks() => SchoolLinks.fromJson(const {
  'links': [
    {
      'guardianId': 'g-1',
      'fullName': 'Karimova Malika',
      'relation': 'MOTHER',
      'school': {'id': 's-1', 'name': 'Test maktab'},
      'students': [
        {
          'id': 'st-1',
          'fullName': 'Karimov Aziz',
          'className': '7-A',
          'childId': 'kid-1',
          'linkedBy': 'ME',
        },
        {
          'id': 'st-2',
          'fullName': 'Karimova Laylo',
          'className': '3-B',
          'childId': null,
          'linkedBy': 'NONE',
        },
        {
          'id': 'st-3',
          'fullName': 'Karimov Bek',
          'className': '9-V',
          'childId': null,
          'linkedBy': 'OTHER',
        },
      ],
    },
  ],
  'children': [
    {'id': 'kid-1', 'name': 'Aziz'},
    {'id': 'kid-2', 'name': 'Laylo'},
  ],
});

void main() {
  late _FakeSchoolRepository repo;

  ProviderContainer makeContainer({bool signedIn = true}) {
    final container = ProviderContainer(
      overrides: [
        schoolRepositoryProvider.overrideWithValue(repo),
        schoolSignedInProvider.overrideWithValue(signedIn),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => repo = _FakeSchoolRepository());

  group('schoolLinksProvider', () {
    test(
      'kirish holati hali o`qilmoqda — "mavjud emas" emas, kutadi',
      () async {
        final auth = StateProvider<bool?>((ref) => null);
        final container = ProviderContainer(
          overrides: [
            schoolRepositoryProvider.overrideWithValue(repo),
            schoolSignedInProvider.overrideWith((ref) => ref.watch(auth)),
          ],
        );
        addTearDown(container.dispose);
        final states = <AsyncValue<SchoolLinks>>[];
        container.listen(
          schoolLinksProvider,
          (_, next) => states.add(next),
          fireImmediately: true,
        );
        await Future<void>.delayed(Duration.zero);

        expect(container.read(schoolLinksProvider).isLoading, isTrue);
        expect(repo.linkFetches, 0);

        repo.links = _sampleLinks();
        container.read(auth.notifier).state = true;
        final links = await container.read(schoolLinksProvider.future);

        expect(links.available, isTrue);
        expect(repo.linkFetches, 1);
        // Push'dagi amal kutgan qiymat: oraliqda "mavjud emas" bo'lmagan.
        expect(
          states.any((s) => !s.isLoading && s.valueOrNull?.available == false),
          isFalse,
        );
      },
    );

    test('kirilmagan — so`rovsiz unavailable', () async {
      final container = makeContainer(signedIn: false);
      final links = await container.read(schoolLinksProvider.future);
      expect(links.available, isFalse);
      expect(repo.linkFetches, 0);
      expect(container.read(schoolAvailableProvider), isFalse);
    });

    test(
      'backend`da bo`lim yo`q (404 code`siz) → bo`lim yashiriladi',
      () async {
        repo.linksError = const SchoolFailure(SchoolFailureKind.unavailable);
        final container = makeContainer();
        final links = await container.read(schoolLinksProvider.future);
        expect(links, SchoolLinks.unavailable);
        expect(container.read(schoolAvailableProvider), isFalse);
        expect(container.read(unmatchedStudentsProvider), isEmpty);
      },
    );

    test(
      'tarmoq xatosi — AsyncError (qayta urinish), bo`lim yashirin',
      () async {
        repo.linksError = const SchoolFailure(SchoolFailureKind.network);
        final container = makeContainer();
        await expectLater(
          container.read(schoolLinksProvider.future),
          throwsA(const SchoolFailure(SchoolFailureKind.network)),
        );
        expect(container.read(schoolLinksProvider).hasError, isTrue);
        expect(container.read(schoolAvailableProvider), isFalse);
      },
    );

    test('bog`lanish yo`q — bo`lim ko`rinadi (taklif kodi CTA)', () async {
      final container = makeContainer();
      final links = await container.read(schoolLinksProvider.future);
      expect(links.hasLinks, isFalse);
      expect(container.read(schoolAvailableProvider), isTrue);
    });

    test('yuklanayotganda bo`lim yashirin', () {
      final container = makeContainer();
      expect(container.read(schoolLinksProvider).isLoading, isTrue);
      expect(container.read(schoolAvailableProvider), isFalse);
    });
  });

  group('moslash', () {
    test('farzandga moslangan o`quvchi va moslanmaganlar', () async {
      repo.links = _sampleLinks();
      final container = makeContainer();
      await container.read(schoolLinksProvider.future);

      expect(container.read(studentForChildProvider('kid-1'))?.id, 'st-1');
      expect(container.read(studentForChildProvider('kid-2')), isNull);
      expect(container.read(studentForChildProvider('begona')), isNull);
      expect(
        container.read(unmatchedStudentsProvider).map((s) => s.id),
        ['st-2'],
        reason: 'OTHER — boshqa oila a`zosiniki, taklif qilinmaydi',
      );
    });

    test('ro`yxat yuklanmaguncha o`quvchi yo`q', () {
      repo.links = _sampleLinks();
      final container = makeContainer();
      expect(container.read(studentForChildProvider('kid-1')), isNull);
    });
  });

  group('SchoolActionsNotifier', () {
    test(
      'redeem: muvaffaqiyat → Result.success va ro`yxat yangilanadi',
      () async {
        final container = makeContainer();
        await container.read(schoolLinksProvider.future);
        expect(repo.linkFetches, 1);

        repo.links = _sampleLinks();
        final result = await container
            .read(schoolActionsProvider.notifier)
            .redeem('abcd-2345');

        expect(result.isSuccess, isTrue);
        expect(result.data?.links.single.guardianId, 'g-1');
        expect(repo.calls, ['redeem:abcd-2345']);
        expect(container.read(schoolActionsProvider).hasError, isFalse);

        final refreshed = await container.read(schoolLinksProvider.future);
        expect(repo.linkFetches, 2);
        expect(refreshed.hasLinks, isTrue);
      },
    );

    test('redeem: noto`g`ri kod → xabar, ro`yxat qayta yuklanmaydi', () async {
      final container = makeContainer();
      await container.read(schoolLinksProvider.future);
      repo.actionError = const SchoolFailure(SchoolFailureKind.inviteInvalid);

      final result = await container
          .read(schoolActionsProvider.notifier)
          .redeem('ABCD2345');

      expect(result.isSuccess, isFalse);
      // easy_localization testda yuklanmagan — `.tr()` kalitni qaytaradi.
      expect(result.error, 'school.errors.inviteInvalid');
      expect(
        container.read(schoolActionsProvider).error,
        const SchoolFailure(SchoolFailureKind.inviteInvalid),
      );
      await container.read(schoolLinksProvider.future);
      expect(repo.linkFetches, 1);
    });

    test('redeem: internet yo`q → ro`yxat xato holatiga o`tmaydi', () async {
      repo.links = _sampleLinks();
      final container = makeContainer();
      await container.read(schoolLinksProvider.future);
      repo.actionError = const SchoolFailure(SchoolFailureKind.network);

      final result = await container
          .read(schoolActionsProvider.notifier)
          .redeem('ABCD2345');

      expect(result.error, 'errors.noInternet');
      expect(container.read(schoolLinksProvider).hasError, isFalse);
      expect(container.read(schoolAvailableProvider), isTrue);
      expect(repo.linkFetches, 1);
    });

    test(
      'setChild: boshqa oila moslagan → xabar + ro`yxat yangilanadi',
      () async {
        repo.links = _sampleLinks();
        final container = makeContainer();
        await container.read(schoolLinksProvider.future);
        repo.actionError = const SchoolFailure(
          SchoolFailureKind.studentLinkedElsewhere,
        );

        final result = await container
            .read(schoolActionsProvider.notifier)
            .setChild(studentId: 'st-3', childId: 'kid-2');

        expect(result.error, 'school.errors.linkedElsewhere');
        expect(repo.calls, ['setChild:st-3:kid-2']);
        await container.read(schoolLinksProvider.future);
        expect(repo.linkFetches, 2);
      },
    );

    test('setChild: moslash olib tashlanadi (null)', () async {
      repo.links = _sampleLinks();
      final container = makeContainer();
      final result = await container
          .read(schoolActionsProvider.notifier)
          .setChild(studentId: 'st-1', childId: null);
      expect(result.isSuccess, isTrue);
      expect(repo.calls, ['setChild:st-1:null']);
    });

    test('unlink: muvaffaqiyat → ro`yxat yangilanadi', () async {
      repo.links = _sampleLinks();
      final container = makeContainer();
      await container.read(schoolLinksProvider.future);
      repo.links = SchoolLinks.empty;

      final result = await container
          .read(schoolActionsProvider.notifier)
          .unlink('g-1');

      expect(result.isSuccess, isTrue);
      expect(repo.calls, ['unlink:g-1']);
      final refreshed = await container.read(schoolLinksProvider.future);
      expect(refreshed.hasLinks, isFalse);
      expect(container.read(studentForChildProvider('kid-1')), isNull);
    });

    test('kutilmagan xato ham Result.failure (ilova yiqilmaydi)', () async {
      final container = makeContainer();
      repo.actionError = const FormatException('bug');
      final result = await container
          .read(schoolActionsProvider.notifier)
          .unlink('g-1');
      expect(result.error, 'errors.generic');
    });
  });
}
