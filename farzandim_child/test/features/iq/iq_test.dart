// IQ test: server javoblarini o'qish (docs/IQ-REJA.md §4 shakllari),
// tarjimalar to'liqligi va test sahifasi oqimi (tanlash → keyingi →
// yakunlash → natija) — tarmoqsiz.

import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/iq/data/iq_repository.dart';
import 'package:farzandim_child/features/iq/domain/iq_models.dart';
import 'package:farzandim_child/features/iq/presentation/providers/iq_providers.dart';
import 'package:farzandim_child/features/iq/presentation/screens/iq_test_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10" fill="#FFFFFF"/></svg>';

Map<String, Object?> _result({
  String status = 'PROVISIONAL',
  String band = 'ABOVE_AVERAGE',
}) => {
  'correct': 15,
  'total': 20,
  'status': status,
  'percentile': 79,
  'band': band,
  'standardScore': status == 'NORMED' ? 112 : null,
  'ci95': status == 'NORMED' ? [104, 120] : null,
  'normGroup': '10',
  'completedAt': '2026-10-21T13:00:00.000Z',
};

Map<String, Object?> _item(int i, [String? choice]) => {
  'id': 'item-$i',
  'position': i,
  'gridSvg': _svg,
  'options': [
    for (final k in ['A', 'B', 'C', 'D', 'E', 'F']) {'key': k, 'svg': _svg},
  ],
  'choice': choice,
};

Map<String, Object?> _t(String uz) => {
  'uz': uz,
  'ru': '$uz (ru)',
  'en': '$uz (en)',
};

Map<String, Object?> _verbal(int i, [String? choice]) => {
  'id': 'item-$i',
  'position': i,
  'kind': 'VERBAL',
  'gridSvg': null,
  'stem': _t('Munosabatni toping:\nBaliq — suv, qush — ?'),
  'options': [
    for (final (k, v) in [
      ('A', 'tosh'),
      ('B', 'osmon'),
      ('C', 'qum'),
      ('D', 'qor'),
    ])
      {'key': k, 'text': _t(v)},
  ],
  'choice': choice,
};

const _domains = [
  {'kind': 'FIGURAL', 'right': 1, 'total': 1},
  {'kind': 'VERBAL', 'right': 1, 'total': 1},
];

Map<String, Object?> _session({
  String status = 'STARTED',
  int items = 2,
  Map<String, Object?>? result,
  bool mixed = false,
}) => {
  'id': 'session-1',
  'status': status,
  'level': 1,
  'form': 'L1A',
  'total': items,
  'startedAt': '2026-10-21T12:00:00.000Z',
  'completedAt': result == null ? null : '2026-10-21T13:00:00.000Z',
  'items': [
    for (var i = 0; i < items; i++)
      mixed && i.isOdd
          ? _verbal(i, status == 'COMPLETED' ? 'B' : null)
          : _item(i, status == 'COMPLETED' ? 'A' : null),
  ],
  'result': result,
};

class _FakeRepo implements IqRepository {
  _FakeRepo({this.mixed = false});

  final bool mixed;
  final saved = <String>[];
  var completed = false;

  @override
  Future<IqOverview> loadOverview() async => IqOverview.fromJson({
    'age': {'status': 'OK', 'age': 10, 'level': 1},
    'canStart': true,
    'nextAvailableAt': null,
    'active': null,
    'last': null,
    'history': <Object?>[],
  });

  @override
  Future<IqSession> startSession() async =>
      IqSession.fromJson(_session(mixed: mixed));

  @override
  Future<void> saveAnswer({
    required String sessionId,
    required String itemId,
    required String choice,
    int? durationMs,
  }) async => saved.add('$itemId=$choice');

  @override
  Future<IqSession> completeSession(String sessionId) async {
    completed = true;
    return IqSession.fromJson(
      _session(
        status: 'COMPLETED',
        mixed: mixed,
        result: {..._result(), if (mixed) 'domains': _domains},
      ),
    );
  }
}

Map<String, Object?> _iqLeaves(String language) {
  final json =
      jsonDecode(File('assets/translations/$language.json').readAsStringSync())
          as Map<String, Object?>;
  final leaves = <String, Object?>{};
  void walk(Object? node, String path) {
    if (node is Map<String, Object?>) {
      node.forEach((k, v) => walk(v, path.isEmpty ? k : '$path.$k'));
    } else if (path.startsWith('iq.')) {
      leaves[path] = node;
    }
  }

  walk(json, '');
  return leaves;
}

void main() {
  group('server javoblari', () {
    test('overview: oxirgi natija PROVISIONAL — IQ raqamisiz', () {
      final o = IqOverview.fromJson({
        'age': {'status': 'OK', 'age': 10, 'level': 1},
        'canStart': false,
        'nextAvailableAt': '2027-04-19T13:00:00.000Z',
        'active': null,
        'last': _result(),
        'history': [
          {
            'sessionId': 's1',
            'completedAt': '2026-10-21T13:00:00.000Z',
            'level': 1,
            'result': _result(),
          },
        ],
      });
      expect(o.canStart, isFalse);
      expect(o.nextAvailableAt, DateTime.utc(2027, 4, 19, 13));
      expect(o.last!.isNormed, isFalse);
      expect(o.last!.standardScore, isNull);
      expect(o.last!.band, IqBand.aboveAverage);
      expect(o.history.single.sessionId, 's1');
    });

    test('NORMED: IQ raqami va 95% oraliq', () {
      final r = IqResult.fromJson(_result(status: 'NORMED'));
      expect(r.isNormed, isTrue);
      expect([r.standardScore, r.ciLow, r.ciHigh], [112, 104, 120]);
    });

    test(
      'PROVISIONAL bo\'lsa server raqam yuborsa ham ko\'rsatilmaydi; noma\'lum daraja — o\'rtacha',
      () {
        final r = IqResult.fromJson({
          ..._result(band: 'WHATEVER'),
          'standardScore': 140,
          'ci95': [130, 150],
        });
        expect(r.standardScore, isNull);
        expect(r.ciLow, isNull);
        expect(r.band, IqBand.average);
      },
    );

    test('sessiya: savollar tartibda, davom ettirish birinchi javobsizdan', () {
      final s = IqSession.fromJson({
        ..._session(items: 3),
        'status': 'IN_PROGRESS',
        'items': [_item(2), _item(0, 'B'), _item(1, 'C')],
      });
      expect(s.items.map((i) => i.position), [0, 1, 2]);
      expect(s.resumeIndex, 2);
      expect(s.isOpen, isTrue);
      expect(s.answeredCount, 2);
    });

    test(
      'matnli savol: tur, uch tilli shart va variantlar; eski server — rasmli',
      () {
        final item = IqItem.fromJson(_verbal(3));
        expect(item.kind, IqItemKind.verbal);
        expect(item.isFigural, isFalse);
        expect(item.gridSvg, isNull);
        expect(item.stem!.of('ru'), contains('(ru)'));
        expect(
          item.options.map((o) => o.text!.of('en')),
          contains('osmon (en)'),
        );
        final noRu = IqText.fromJson({'uz': 'son', 'en': 'number'}, 'stem');
        expect(
          [noRu.of('ru'), noRu.of('en'), noRu.of('kk')],
          ['son', 'number', 'son'],
        );
        final legacy = IqItem.fromJson(_item(0));
        expect(legacy.kind, IqItemKind.figural);
        expect(legacy.options.first.svg, isNotNull);
        final s = IqSession.fromJson(_session(items: 3, mixed: true));
        expect(s.isMixed, isTrue);
        expect(IqSession.fromJson(_session(items: 3)).isMixed, isFalse);
      },
    );

    test('matnli savol buzuq — FormatException; noma\'lum tur ham', () {
      expect(
        () => IqItem.fromJson({..._verbal(0), 'stem': null}),
        throwsFormatException,
      );
      expect(
        () => IqItem.fromJson({
          ..._verbal(0),
          'options': [
            {'key': 'A', 'svg': _svg},
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => IqItem.fromJson({..._verbal(0), 'kind': 'MEMORY'}),
        throwsFormatException,
      );
    });

    test('yo\'nalishlar natijasi: buzuq va noma\'lum yozuvlar tashlanadi', () {
      final r = IqResult.fromJson({
        ..._result(),
        'domains': [
          ..._domains,
          {'kind': 'MEMORY', 'right': 1, 'total': 2},
          {'kind': 'LOGIC', 'right': 5, 'total': 3},
          'x',
        ],
      });
      expect(r.domains.map((d) => (d.kind, d.right, d.total)), [
        (IqItemKind.figural, 1, 1),
        (IqItemKind.verbal, 1, 1),
      ]);
      expect(IqResult.fromJson(_result()).domains, isEmpty);
    });

    test('buzuq javob — FormatException', () {
      expect(
        () => IqSession.fromJson({'id': 'x', 'items': 'yo\'q'}),
        throwsFormatException,
      );
      expect(() => IqResult.fromJson({'total': 20}), throwsFormatException);
    });
  });

  group('tarjimalar', () {
    final leaves = {
      for (final l in ['uz', 'ru', 'en']) l: _iqLeaves(l),
    };

    test(
      'uch tilda bir xil kalitlar, bo\'sh matn yo\'q, o\'rinbosarlar bir xil',
      () {
        final keys = leaves['uz']!.keys.toSet();
        expect(keys, isNotEmpty);
        final placeholder = RegExp(r'\{(\w+)\}');
        for (final l in ['ru', 'en']) {
          expect(leaves[l]!.keys.toSet(), keys, reason: l);
          for (final k in keys) {
            final value = leaves[l]![k];
            expect(value, isA<String>(), reason: '$l $k');
            expect((value! as String).trim(), isNotEmpty, reason: '$l $k');
            Set<String> args(Object? v) =>
                placeholder.allMatches(v! as String).map((m) => m[1]!).toSet();
            expect(args(value), args(leaves['uz']![k]), reason: '$l $k');
          }
        }
      },
    );

    test('har xato kodi va daraja uchun matn bor', () {
      for (final code in IqErrorCode.values) {
        expect(
          leaves['uz']!['iq.error.${code.name}'],
          isNotNull,
          reason: code.name,
        );
      }
      for (final band in IqBand.values) {
        expect(
          leaves['uz']!['iq.band.${band.name}'],
          isNotNull,
          reason: band.name,
        );
      }
    });
  });

  group('test sahifasi', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      GoogleFonts.config.allowRuntimeFetching = false;
      await EasyLocalization.ensureInitialized();
    });

    Future<void> pumpTest(WidgetTester tester, _FakeRepo repo) async {
      tester.view
        ..physicalSize = const Size(393, 852) * 2
        ..devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final app = EasyLocalization(
        supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
        path: 'assets/translations',
        fallbackLocale: const Locale('uz'),
        startLocale: const Locale('uz'),
        child: ProviderScope(
          overrides: [
            iqRepositoryProvider.overrideWithValue(repo),
            iqAccountProvider.overrideWithValue('child-1'),
          ],
          child: Builder(
            builder: (context) => MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: const IqTestScreen(),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await tester.pumpWidget(app);
        for (var i = 0; i < 8; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }
        await GoogleFonts.pendingFonts();
      });
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('tanlash → keyingi → yakunlash → taxminiy natija', (
      tester,
    ) async {
      final repo = _FakeRepo();
      await pumpTest(tester, repo);

      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('Naqsh'), findsNothing);
      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keyingi'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text('Yakunlash'), findsNothing);

      await tester.tap(find.text('E'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yakunlash'));
      await tester.pumpAndSettle();

      expect(repo.saved, ['item-0=B', 'item-1=E']);
      expect(repo.completed, isTrue);
      expect(find.text('Taxminiy'), findsOneWidget);
      expect(find.text('O\'rtachadan yuqori'), findsOneWidget);
      expect(find.textContaining('79%'), findsOneWidget);
      expect(find.textContaining('IQ 1'), findsNothing);
      expect(find.text('Yo\'nalishlar bo\'yicha'), findsNothing);
    });

    testWidgets('aralash test: rasm → so\'z savoli → yo\'nalishlar natijasi', (
      tester,
    ) async {
      final repo = _FakeRepo(mixed: true);
      await pumpTest(tester, repo);

      expect(find.text('Naqsh'), findsOneWidget);
      await tester.tap(find.text('C'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keyingi'));
      await tester.pumpAndSettle();

      expect(find.text('So\'zlar'), findsOneWidget);
      expect(find.text('Munosabatni toping:'), findsOneWidget);
      expect(find.text('Baliq — suv, qush — ?'), findsOneWidget);
      await tester.tap(find.text('osmon'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yakunlash'));
      await tester.pumpAndSettle();

      expect(repo.saved, ['item-0=C', 'item-1=B']);
      expect(find.text('Yo\'nalishlar bo\'yicha'), findsOneWidget);
      expect(find.text('Naqsh'), findsOneWidget);
      expect(find.text('So\'zlar'), findsOneWidget);
      expect(find.text('1/1'), findsNWidgets(2));
    });
  });
}
