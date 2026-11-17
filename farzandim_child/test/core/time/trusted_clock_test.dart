import 'dart:io' show HttpDate;

import 'package:farzandim_child/core/auth/token_memory.dart';
import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/network/clock_sync_interceptor.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/core/time/trusted_clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/secure_storage_fake.dart';
import '../network/scripted_adapter.dart';

const _hour = Duration(hours: 1);
const _tolerance = 2000; // ms: sarlavha soniyagacha + test kechikishi

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SecureStorageFake.install();
    SharedPreferences.setMockInitialValues({});
    TrustedClock.resetForTest();
  });

  void sample(Duration offset, {Duration roundTrip = Duration.zero}) {
    final now = DateTime.now();
    TrustedClock.recordSample(
      serverDate: now.add(offset).toUtc(),
      roundTrip: roundTrip,
      receivedAt: now,
    );
  }

  test('learns the offset from Date headers on backend responses', () async {
    final dio = buildBackendDio(TokenStorage(memory: TokenMemory()))
      ..httpClientAdapter = ScriptedAdapter(
        (_) => FakeReply(200, null, {
          'date': HttpDate.format(DateTime.now().add(_hour)),
        }),
      );

    await dio.get<dynamic>('/children/me');

    expect(TrustedClock.offsetMs, closeTo(_hour.inMilliseconds, _tolerance));
    final skew = TrustedClock.now().difference(DateTime.now()).inMilliseconds;
    expect(skew, closeTo(_hour.inMilliseconds, _tolerance));
  });

  test('error responses carry Date too', () async {
    final dio = buildBackendDio(TokenStorage(memory: TokenMemory()))
      ..httpClientAdapter = ScriptedAdapter(
        (_) => FakeReply(404, null, {
          'date': HttpDate.format(DateTime.now().subtract(_hour)),
        }),
      );

    await expectLater(dio.get<dynamic>('/x'), throwsA(anything));

    expect(TrustedClock.offsetMs, closeTo(-_hour.inMilliseconds, _tolerance));
  });

  test('responses slower than 5 s are ignored', () {
    sample(_hour, roundTrip: const Duration(seconds: 6));

    expect(TrustedClock.offsetMs, 0);
  });

  test('one outlier does not move the median', () {
    for (var i = 0; i < 4; i++) {
      sample(Duration.zero);
    }
    sample(_hour);

    expect(TrustedClock.offsetMs, closeTo(0, _tolerance));
  });

  test('a real clock change wins after a few responses', () {
    for (var i = 0; i < 5; i++) {
      sample(Duration.zero);
    }
    for (var i = 0; i < 3; i++) {
      sample(-const Duration(days: 1));
    }

    expect(
      TrustedClock.offsetMs,
      closeTo(-const Duration(days: 1).inMilliseconds, _tolerance),
    );
  });

  test('offsetChanges fires only for moves beyond 30 s', () async {
    final changes = <int>[];
    final sub = TrustedClock.offsetChanges.listen(changes.add);

    sample(const Duration(seconds: 10));
    await Future<void>.delayed(Duration.zero);
    expect(changes, isEmpty);

    for (var i = 0; i < 3; i++) {
      sample(_hour);
    }
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(changes, hasLength(1));
    expect(changes.single, closeTo(_hour.inMilliseconds, _tolerance));
  });

  test('ensureLoaded starts from the saved restriction.clock_offset_ms', () async {
    SharedPreferences.setMockInitialValues({TrustedClock.prefsKey: 120000});

    await TrustedClock.ensureLoaded();

    expect(TrustedClock.offsetMs, 120000);
  });

  test('the clock never writes prefs (the snapshot owns the key)', () async {
    sample(_hour);
    sample(_hour);
    await Future<void>.delayed(Duration.zero);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(TrustedClock.prefsKey), isFalse);
  });

  group('parseHttpDate', () {
    test('RFC 1123', () {
      expect(
        parseHttpDate('Sun, 06 Nov 1994 08:49:37 GMT'),
        DateTime.utc(1994, 11, 6, 8, 49, 37),
      );
      final now = DateTime.now().toUtc();
      final parsed = parseHttpDate(HttpDate.format(now))!;
      expect(now.difference(parsed).inSeconds.abs(), lessThanOrEqualTo(1));
    });

    test('anything else is null', () {
      for (final value in [
        null,
        '',
        'ertaga',
        'Sunday, 06-Nov-94 08:49:37 GMT',
        'Sun, 06 Foo 1994 08:49:37 GMT',
        'Sun, 32 Nov 1994 08:49:37 GMT',
        'Sun, 06 Nov 1994 25:49:37 GMT',
      ]) {
        expect(parseHttpDate(value), isNull, reason: '$value');
      }
    });
  });
}
