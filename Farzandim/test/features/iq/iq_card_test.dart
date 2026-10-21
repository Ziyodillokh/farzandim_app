// IQ xulosasi (docs/IQ-REJA.md §5): model, repository yo'li va dashboard
// kartasi — taxminiy natijada IQ raqami yo'q, NORMED'da standart ball + oraliq,
// LOW/VERY_LOW — "Rivojlanish zonasi", natija yo'q — karta yashirin.

import 'package:dio/dio.dart';
import 'package:farzandim/features/iq/data/iq_repository.dart';
import 'package:farzandim/features/iq/data/iq_summary.dart';
import 'package:farzandim/features/iq/presentation/iq_dashboard_card.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http_adapter.dart';

Map<String, dynamic> _result({
  String status = 'PROVISIONAL',
  int percentile = 62,
  String band = 'AVERAGE',
  int? score,
  List<int>? ci,
  String completedAt = '2026-10-21T08:30:00.000Z',
}) => {
  'correct': 13,
  'total': 20,
  'status': status,
  'percentile': percentile,
  'band': band,
  'standardScore': score,
  'ci95': ci,
  'normGroup': '11',
  'completedAt': completedAt,
};

Map<String, dynamic> _summary(
  Map<String, dynamic>? last, {
  List<Map<String, dynamic>> older = const [],
}) => {
  'age': {'status': 'OK', 'age': 11, 'level': 2},
  'last': last,
  'nextAvailableAt': '2999-04-19T08:30:00.000Z',
  'history': [
    if (last != null)
      {
        'sessionId': 's2',
        'completedAt': last['completedAt'],
        'level': 2,
        'result': last,
      },
    for (final r in older)
      {
        'sessionId': 's1',
        'completedAt': r['completedAt'],
        'level': 2,
        'result': r,
      },
  ],
};

class _FakeRepo extends IqRepository {
  _FakeRepo(this.json) : super(dio: Dio());
  final Map<String, dynamic>? json;

  @override
  Future<IqSummary> fetchSummary(String childId) async {
    final json = this.json;
    if (json == null) throw const SchoolFailure(SchoolFailureKind.unavailable);
    return IqSummary.fromJson(json);
  }
}

Future<void> _pump(WidgetTester tester, Map<String, dynamic>? json) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [iqRepositoryProvider.overrideWithValue(_FakeRepo(json))],
      child: const MaterialApp(
        home: Scaffold(body: IqDashboardCard(childId: 'kid-1')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('IqSummary', () {
    test("taxminiy natija: ball va oraliq yo'q, oldingi natija tarixdan", () {
      final s = IqSummary.fromJson(
        _summary(
          _result(),
          older: [
            _result(percentile: 40, completedAt: '2026-04-01T08:00:00.000Z'),
          ],
        ),
      );
      expect(s.last!.status, IqResultStatus.provisional);
      expect(s.last!.standardScore, isNull);
      expect(s.last!.ci95, isNull);
      expect(s.previous!.percentile, 40);
    });

    test('NORMED: standart ball va 95% oraliq', () {
      final s = IqSummary.fromJson(
        _summary(_result(status: 'NORMED', score: 104, ci: [96, 112])),
      );
      expect(s.last!.isNormed, isTrue);
      expect(s.last!.ci95, (96, 112));
      expect(s.previous, isNull);
    });

    test("repository — to'g'ri yo'l", () async {
      final adapter = FakeHttpAdapter((_) => FakeReply(200, _summary(null)));
      final s = await IqRepository(dio: fakeDio(adapter)).fetchSummary('kid 1');
      expect(adapter.requests.single.path, '/children/kid%201/iq/summary');
      expect(s.last, isNull);
    });
  });

  group('IqDashboardCard', () {
    testWidgets("natija yo'q yoki bo'lim yo'q — yashirin", (tester) async {
      await _pump(tester, _summary(null));
      expect(find.text('iq.card.title'), findsNothing);
      await _pump(tester, null);
      expect(find.text('iq.card.title'), findsNothing);
    });

    testWidgets("taxminiy: belgi bor, IQ raqami yo'q, izoh doim", (
      tester,
    ) async {
      await _pump(tester, _summary(_result()));
      expect(find.text('iq.card.title'), findsOneWidget);
      expect(find.text('iq.card.provisional'), findsOneWidget);
      expect(find.text('iq.band.average'), findsOneWidget);
      expect(find.text('iq.card.percentile'), findsOneWidget);
      expect(find.text('iq.card.scoreCi'), findsNothing);
      expect(find.text('iq.card.disclaimer'), findsOneWidget);
    });

    testWidgets(
      'NORMED: ball + oraliq, belgisiz; past daraja — rivojlanish zonasi',
      (tester) async {
        await _pump(
          tester,
          _summary(
            _result(
              status: 'NORMED',
              band: 'VERY_LOW',
              score: 68,
              ci: [61, 75],
            ),
          ),
        );
        expect(find.text('iq.card.provisional'), findsNothing);
        expect(find.text('iq.card.scoreCi'), findsOneWidget);
        expect(find.text('iq.band.growthZone'), findsOneWidget);
      },
    );
  });
}
