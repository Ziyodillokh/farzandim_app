// pollFetchStream/pollTickStream — polling skaffoldining xulq-atvori.
// 5 ta provider shu skaffoldga tayanadi: SWR kesh-birinchi, birinchi-fetch
// xato siyosati, dedup (identity saqlash), dispose'da to'xtash.
//
// Real timer ishlatiladi (qisqa intervallar) — appLifecycleProvider
// override qilinadi, WidgetsBinding kerak emas.

import 'package:farzandim/core/utils/app_lifecycle.dart';
import 'package:farzandim/core/utils/polling.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test konteyner — lifecycle RESUMED holatda (polling ishlaydi).
ProviderContainer makeContainer() {
  final container = ProviderContainer(
    overrides: [
      appLifecycleProvider
          .overrideWith((ref) => AppLifecycleState.resumed),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

const tick = Duration(milliseconds: 60);

Future<void> wait(int ms) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  group('pollFetchStream', () {
    test('SWR: kesh DARHOL, keyin fresh fetch', () async {
      final container = makeContainer();
      final provider = StreamProvider<List<int>>(
        (ref) => pollFetchStream<List<int>>(
          ref,
          interval: const Duration(minutes: 1), // poll bu testda kerak emas
          fetch: () async => [2],
          readCache: () async => [1],
        ),
      );
      final emissions = <List<int>>[];
      container.listen(provider, (_, next) {
        if (next.hasValue) emissions.add(next.requireValue);
      });
      await wait(50);
      expect(emissions, [
        [1],
        [2],
      ]);
    });

    test('kesh YO`Q + birinchi fetch xato → provider error (retry UI)',
        () async {
      final container = makeContainer();
      final provider = StreamProvider<List<int>>(
        (ref) => pollFetchStream<List<int>>(
          ref,
          interval: const Duration(minutes: 1),
          fetch: () async => throw Exception('tarmoq'),
        ),
      );
      container.listen(provider, (_, __) {});
      await wait(50);
      expect(container.read(provider).hasError, isTrue);
    });

    test('kesh BOR + birinchi fetch xato → kesh saqlanadi, error YO`Q',
        () async {
      final container = makeContainer();
      final provider = StreamProvider<List<int>>(
        (ref) => pollFetchStream<List<int>>(
          ref,
          interval: const Duration(minutes: 1),
          fetch: () async => throw Exception('tarmoq'),
          readCache: () async => [7],
        ),
      );
      container.listen(provider, (_, __) {});
      await wait(50);
      final state = container.read(provider);
      expect(state.hasError, isFalse);
      expect(state.requireValue, [7]);
    });

    test('swallowFirstError: xato yutiladi, keyingi poll qiymat beradi',
        () async {
      final container = makeContainer();
      var calls = 0;
      final provider = StreamProvider<List<int>>(
        (ref) => pollFetchStream<List<int>>(
          ref,
          interval: tick,
          fetch: () async {
            calls++;
            if (calls == 1) throw Exception('birinchi xato');
            return [calls];
          },
          swallowFirstError: true,
        ),
      );
      container.listen(provider, (_, __) {});
      await wait(250);
      final state = container.read(provider);
      expect(state.hasError, isFalse);
      expect(state.hasValue, isTrue);
    });

    test('isSame dedup: o`zgarmagan natija yield QILINMAYDI', () async {
      final container = makeContainer();
      var emissionCount = 0;
      final provider = StreamProvider<List<int>>(
        (ref) => pollFetchStream<List<int>>(
          ref,
          interval: tick,
          fetch: () async => [1, 2, 3], // har safar teng ro'yxat
          isSame: (a, b) =>
              a.length == b.length &&
              List.generate(a.length, (i) => a[i] == b[i])
                  .every((x) => x),
        ),
      );
      container.listen(provider, (_, next) {
        if (next.hasValue) emissionCount++;
      });
      // Kamida 3 poll tick o'tadi — lekin qiymat teng, emission 1 ta.
      await wait(300);
      expect(emissionCount, 1);
    });

    test('dispose → polling TO`XTAYDI (zombi yo`q)', () async {
      final container = makeContainer();
      var calls = 0;
      final provider = StreamProvider<List<int>>(
        (ref) => pollFetchStream<List<int>>(
          ref,
          interval: tick,
          fetch: () async {
            calls++;
            return [calls];
          },
        ),
      );
      final sub = container.listen(provider, (_, __) {});
      await wait(200); // bir nechta poll o'tsin
      sub.close();
      container.dispose();
      final after = calls;
      await wait(250); // yana bir nechta tick muddati
      expect(calls, after, reason: "dispose'dan keyin fetch chaqirilmasin");
    });
  });

  group('pollTickStream', () {
    test('darhol 0, keyin har intervalda o`sadi; dispose to`xtatadi',
        () async {
      final container = makeContainer();
      final provider = StreamProvider<int>(
        (ref) => pollTickStream(ref, tick),
      );
      final seen = <int>[];
      final sub = container.listen(provider, (_, next) {
        if (next.hasValue) seen.add(next.requireValue);
      });
      await wait(200);
      expect(seen.first, 0);
      expect(seen.length, greaterThanOrEqualTo(2));
      sub.close();
      container.dispose();
      final len = seen.length;
      await wait(150);
      expect(seen.length, len);
    });
  });
}
