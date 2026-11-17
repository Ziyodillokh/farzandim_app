// LearningRepository: `/children/:childId/learning/*` so'rovlari faqat
// backend qabul qiladigan parametrlar bilan ketadi (noma'lumi — 400), qoidaga
// zid kiritma tarmoqqa chiqmaydi, 404 `code`siz — "Growth mavjud emas".

import 'package:farzandim/features/growth/data/learning_repository.dart';
import 'package:farzandim/features/growth/data/models/learning_profile.dart';
import 'package:farzandim/features/growth/data/models/learning_subject.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http_adapter.dart';

Matcher _failure(SchoolFailureKind kind) =>
    throwsA(isA<SchoolFailure>().having((f) => f.kind, 'kind', kind));

void main() {
  late FakeHttpAdapter adapter;
  late LearningRepository repo;
  var reply = const FakeReply(200);

  setUp(() {
    reply = const FakeReply(200);
    adapter = FakeHttpAdapter((_) => reply);
    repo = LearningRepository(dio: fakeDio(adapter));
  });

  String lastPath() => adapter.requests.last.path;
  Map<String, dynamic> lastQuery() => adapter.requests.last.queryParameters;

  test('summary: faqat days=7|30', () async {
    reply = const FakeReply(200, {'testsCount': 3, 'periodDays': 30});
    final summary = await repo.fetchSummary('kid-1', days: 30);
    expect(lastPath(), '/children/kid-1/learning/summary');
    expect(lastQuery(), {'days': 30});
    expect(summary.testsCount, 3);

    await expectLater(
      repo.fetchSummary('kid-1', days: 14),
      _failure(SchoolFailureKind.validation),
    );
    expect(adapter.requests, hasLength(1));
  });

  test('results: limit chegarasi, kursor va fan filtri', () async {
    reply = const FakeReply(200, {
      'items': [
        {'id': 'r-1', 'subject': 'math'},
      ],
      'nextBefore': null,
    });
    final page = await repo.fetchResults('kid-1');
    expect(lastPath(), '/children/kid-1/learning/results');
    expect(lastQuery(), {'limit': 30});
    expect(page.items.single.id, 'r-1');
    expect(page.hasMore, isFalse);

    await repo.fetchResults(
      'kid-1',
      limit: 500,
      before: '2026-10-19T06:00:00.000Z',
      subject: LearningSubject.english,
    );
    expect(lastQuery(), {
      'limit': 100,
      'before': '2026-10-19T06:00:00.000Z',
      'subject': 'english',
    });

    final count = adapter.requests.length;
    await expectLater(
      repo.fetchResults('kid-1', subject: LearningSubject.unknown),
      _failure(SchoolFailureKind.validation),
    );
    expect(adapter.requests, hasLength(count));
  });

  test('profile: tanlanmagan → null; saqlash', () async {
    reply = const FakeReply(200, {'profile': null});
    expect(await repo.fetchProfile('kid-1'), isNull);
    expect(lastPath(), '/children/kid-1/learning/profile');

    reply = const FakeReply(200, {
      'profile': {
        'grade': 6,
        'subjects': ['math'],
        'updatedAt': '2026-10-20T06:00:00.000Z',
      },
    });
    final saved = await repo.saveProfile(
      'kid-1',
      const LearningProfile(grade: 6, subjects: [LearningSubject.math]),
    );
    final request = adapter.requests.last;
    expect(request.method, 'PUT');
    expect(request.path, '/children/kid-1/learning/profile');
    expect(request.data, {
      'grade': 6,
      'subjects': ['math'],
    });
    expect(saved.updatedAt, isNotNull);
  });

  test('qoidaga zid profil tarmoqqa chiqmaydi', () async {
    await expectLater(
      repo.saveProfile(
        'kid-1',
        const LearningProfile(grade: 5, subjects: [LearningSubject.physics]),
      ),
      _failure(SchoolFailureKind.validation),
    );
    await expectLater(
      repo.fetchSummary(''),
      _failure(SchoolFailureKind.validation),
    );
    expect(adapter.requests, isEmpty);
  });

  test('Growth yo`q (404 code`siz) → unavailable; begona bola → 403', () async {
    reply = const FakeReply(404, {
      'statusCode': 404,
      'message': 'Cannot GET /api/children/kid-1/learning/summary?days=7',
      'error': 'Not Found',
    });
    await expectLater(
      repo.fetchSummary('kid-1'),
      _failure(SchoolFailureKind.unavailable),
    );
    reply = const FakeReply(403, {
      'statusCode': 403,
      'message': 'Forbidden',
      'error': 'Forbidden',
    });
    await expectLater(
      repo.fetchProfile('kid-1'),
      _failure(SchoolFailureKind.forbidden),
    );
  });
}
