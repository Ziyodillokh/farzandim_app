// GameReportService: `openedAt` native "at" dan, 10 daqiqadan eski voqea
// tashlanadi, queue darhol bo'shatiladi, xato bo'lsa xotirada qayta urinadi.

import 'dart:convert';

import 'package:farzandim_child/features/app_restrictions/data/services/game_report_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../background/fake_dio.dart';

void main() {
  final now = DateTime.utc(2026, 11, 13, 5);
  final nowMs = now.millisecondsSinceEpoch;

  String queue(List<Map<String, Object>> items) => jsonEncode(items);

  test(
    'yangi voqea openedAt bilan yuboriladi, eskisi tashlanadi, queue bo\'shaydi',
    () async {
      SharedPreferences.setMockInitialValues({
        GameReportService.queueKey: queue([
          {
            'pkg': 'com.fresh',
            'name': 'Fresh',
            'ts': nowMs,
            'at': nowMs - 60000,
          },
          {'pkg': 'com.stale', 'name': 'Stale', 'at': nowMs - 11 * 60000},
          {'pkg': 'com.legacy', 'name': 'Legacy', 'ts': nowMs - 120000},
        ]),
      });
      final (dio, adapter) = recordingDio();
      final service = GameReportService(
        childId: 'c1',
        dio: dio,
        clock: () => now,
        clockOffsetMs: () => 1000,
      );

      await service.check();

      final sent = {
        for (final r in adapter.requests) r.json['packageName']: r.json,
      };
      expect(
        adapter.requests.every((r) => r.path == '/children/c1/game-open'),
        isTrue,
      );
      expect(sent.keys, {'com.fresh', 'com.legacy'});
      expect(
        sent['com.fresh']!['openedAt'],
        DateTime.fromMillisecondsSinceEpoch(
          nowMs - 60000 + 1000,
          isUtc: true,
        ).toIso8601String(),
      );
      expect(sent['com.fresh']!['appName'], 'Fresh');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(GameReportService.queueKey), isFalse);
    },
  );

  test(
    'xato bo\'lsa xotirada qoladi va keyingi tekshiruvda qayta yuboriladi',
    () async {
      SharedPreferences.setMockInitialValues({
        GameReportService.queueKey: queue([
          {'pkg': 'com.game', 'name': 'Game', 'at': nowMs},
        ]),
      });
      var status = 503;
      final (dio, adapter) = recordingDio((_) => (status, null));
      var clock = now;
      final service = GameReportService(
        childId: 'c1',
        dio: dio,
        clock: () => clock,
        clockOffsetMs: () => 0,
      );

      await service.check();
      expect(adapter.requests, hasLength(1));

      status = 200;
      clock = now.add(const Duration(minutes: 2));
      await service.check();
      expect(adapter.requests, hasLength(2));

      // Muvaffaqiyatdan keyin takrorlanmaydi.
      await service.check();
      expect(adapter.requests, hasLength(2));
    },
  );

  test('10 daqiqadan oshgan qayta urinish tashlanadi', () async {
    SharedPreferences.setMockInitialValues({
      GameReportService.queueKey: queue([
        {'pkg': 'com.game', 'name': 'Game', 'at': nowMs},
      ]),
    });
    var status = 503;
    final (dio, adapter) = recordingDio((_) => (status, null));
    var clock = now;
    final service = GameReportService(
      childId: 'c1',
      dio: dio,
      clock: () => clock,
      clockOffsetMs: () => 0,
    );

    await service.check();
    status = 200;
    clock = now.add(const Duration(minutes: 11));
    await service.check();

    expect(adapter.requests, hasLength(1));
  });

  test('bir o\'yin 5 daqiqa ichida bir marta', () async {
    SharedPreferences.setMockInitialValues({
      GameReportService.queueKey: queue([
        {'pkg': 'com.game', 'name': 'Game', 'at': nowMs - 60000},
      ]),
    });
    final (dio, adapter) = recordingDio();
    final service = GameReportService(
      childId: 'c1',
      dio: dio,
      clock: () => now,
      clockOffsetMs: () => 0,
    );
    await service.check();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      GameReportService.queueKey,
      queue([
        {'pkg': 'com.game', 'name': 'Game', 'at': nowMs},
      ]),
    );
    await service.check();

    expect(adapter.requests, hasLength(1));
  });
}
