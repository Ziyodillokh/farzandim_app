// KelajakRepository: `GET /children/:childId/kelajak/summary` haqiqiy
// javoblar bilan (fixtures); 404 `code`siz — "Kelajak mavjud emas"
// (bo'lim yashirinadi), begona bola — 403, bo'sh id tarmoqqa chiqmaydi.

import 'package:farzandim/features/kelajak/data/kelajak_repository.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_summary.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_support.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http_adapter.dart';
import 'kelajak_fixtures.dart';

Matcher _failure(SchoolFailureKind kind) =>
    throwsA(isA<SchoolFailure>().having((f) => f.kind, 'kind', kind));

void main() {
  late FakeHttpAdapter adapter;
  late KelajakRepository repo;
  var reply = const FakeReply(200);

  setUp(() {
    reply = const FakeReply(200);
    adapter = FakeHttpAdapter((_) => reply);
    repo = KelajakRepository(dio: fakeDio(adapter));
  });

  test('summary: yo`l va boy profil', () async {
    reply = FakeReply(200, kelajakFixtureJson(kRichSupportFixture));
    final summary = await repo.fetchSummary('kid-1');

    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/children/kid-1/kelajak/summary');
    expect(request.queryParameters, isEmpty);
    expect(summary.sessionsCompleted, 7);
    expect(summary.interests?.top, ['A', 'I', 'S']);
    expect(summary.support?.level, KelajakSupportLevel.support);
  });

  test('summary: yosh kiritilmagan — xato emas, holat', () async {
    reply = FakeReply(200, kelajakFixtureJson(kAgeRequiredFixture));
    final summary = await repo.fetchSummary('kid-1');
    expect(summary.age.status, KelajakAgeStatus.ageRequired);
  });

  test('id kodlanadi; bo`sh id tarmoqqa chiqmaydi', () async {
    reply = FakeReply(200, kelajakFixtureJson(kEmptyFixture));
    await repo.fetchSummary(' a/b ');
    expect(adapter.requests.single.path, '/children/a%2Fb/kelajak/summary');

    await expectLater(
      repo.fetchSummary('  '),
      _failure(SchoolFailureKind.validation),
    );
    expect(adapter.requests, hasLength(1));
  });

  test('404 code`siz (bola yo`q / Kelajak yo`q) → unavailable', () async {
    reply = FakeReply(404, kelajakFixtureJson(kChildNotFoundFixture));
    await expectLater(
      repo.fetchSummary('kid-1'),
      _failure(SchoolFailureKind.unavailable),
    );
    reply = const FakeReply(404, {
      'statusCode': 404,
      'message': 'Cannot GET /api/children/kid-1/kelajak/summary',
      'error': 'Not Found',
    });
    await expectLater(
      repo.fetchSummary('kid-1'),
      _failure(SchoolFailureKind.unavailable),
    );
  });

  test('begona bola → forbidden; server va tarmoq xatolari', () async {
    reply = FakeReply(403, kelajakFixtureJson(kForbiddenFixture));
    await expectLater(
      repo.fetchSummary('kid-1'),
      _failure(SchoolFailureKind.forbidden),
    );
    reply = const FakeReply(500, {'statusCode': 500, 'message': 'boom'});
    await expectLater(
      repo.fetchSummary('kid-1'),
      _failure(SchoolFailureKind.server),
    );
    reply = const FakeReply.offline();
    await expectLater(
      repo.fetchSummary('kid-1'),
      _failure(SchoolFailureKind.network),
    );
  });

  test('JSON bo`lmagan javob — bo`sh xulosa, yiqilmaydi', () async {
    reply = const FakeReply(200, '<html>ok</html>');
    final summary = await repo.fetchSummary('kid-1');
    expect(summary.sessionsCompleted, 0);
    expect(summary.age.status, KelajakAgeStatus.unknown);
  });
}
