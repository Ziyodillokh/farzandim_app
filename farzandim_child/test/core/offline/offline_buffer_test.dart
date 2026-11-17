import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/offline/offline_buffer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/scripted_adapter.dart';

const _queueKey = 'offline_buffer_v1';
const _nextAttemptKey = 'offline_buffer.next_attempt_ms';
const _failuresKey = 'offline_buffer.failures';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  late bool online;
  late ScriptedAdapter adapter;
  late FutureOr<FakeReply> Function(RequestOptions) reply;

  OfflineBuffer buffer() {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'))
      ..httpClientAdapter = adapter;
    return OfflineBuffer(
      dio: dio,
      clock: () => now,
      hasNetwork: () async => online,
    );
  }

  Future<List<int>> queuedSeqs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(_queueKey);
    if (raw == null) return [];
    return [
      for (final item in jsonDecode(raw) as List)
        ((item as Map)['body'] as Map)['seq'] as int,
    ];
  }

  Future<int?> prefInt(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getInt(key);
  }

  Future<void> enqueueSeqs(OfflineBuffer b, Iterable<int> seqs) async {
    for (final seq in seqs) {
      await b.enqueue(endpoint: '/location', body: {'seq': seq});
    }
  }

  int seqOf(RequestOptions o) => (o.data as Map)['seq'] as int;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OfflineBuffer.resetForTest();
    now = DateTime(2026, 11, 14, 12);
    online = true;
    reply = (_) => const FakeReply(200);
    adapter = ScriptedAdapter((o) => reply(o));
  });

  test('stops at the first server error and backs off 1 minute', () async {
    final b = buffer();
    await enqueueSeqs(b, [1, 2, 3]);
    reply = (o) => seqOf(o) == 2 ? const FakeReply(503) : const FakeReply(200);

    await b.flush();

    expect(adapter.requests.map(seqOf), [1, 2]); // 3 ga urinilmadi
    expect(await queuedSeqs(), [2, 3]);
    expect(await prefInt(_failuresKey), 1);
    expect(
      await prefInt(_nextAttemptKey),
      now.add(const Duration(minutes: 1)).millisecondsSinceEpoch,
    );

    // Kutish tugamaguncha hech narsa yuborilmaydi.
    await b.flush();
    expect(adapter.requests, hasLength(2));

    now = now.add(const Duration(minutes: 1, seconds: 1));
    reply = (_) => const FakeReply(200);
    await b.flush();
    expect(adapter.requests.skip(2).map(seqOf), [2, 3]);
    expect(await queuedSeqs(), isEmpty);
    expect(await prefInt(_failuresKey), isNull);
    expect(await prefInt(_nextAttemptKey), isNull);
  });

  test('a network error (no response) also stops the flush', () async {
    final b = buffer();
    await enqueueSeqs(b, [1, 2, 3]);
    reply = (_) => const FakeReply.networkError();

    await b.flush();

    expect(adapter.requests, hasLength(1));
    expect(await queuedSeqs(), [1, 2, 3]);
    expect(await prefInt(_failuresKey), 1);
  });

  test('401, 408 and 429 keep the items and back off', () async {
    for (final status in [401, 408, 429]) {
      SharedPreferences.setMockInitialValues({});
      final b = buffer();
      await enqueueSeqs(b, [1, 2]);
      reply = (_) => FakeReply(status);

      await b.flush();

      expect(await queuedSeqs(), [1, 2], reason: '$status');
      expect(await prefInt(_failuresKey), 1, reason: '$status');
    }
  });

  test('backoff doubles up to 30 minutes', () {
    expect(
      [for (var n = 1; n <= 8; n++) OfflineBuffer.backoffFor(n).inMinutes],
      [1, 2, 4, 8, 16, 30, 30, 30],
    );
  });

  test('consecutive failures grow the persisted wait', () async {
    final b = buffer();
    await enqueueSeqs(b, [1]);
    reply = (_) => const FakeReply(500);

    await b.flush();
    now = now.add(const Duration(minutes: 1));
    await b.flush();

    expect(await prefInt(_failuresKey), 2);
    expect(
      await prefInt(_nextAttemptKey),
      now.add(const Duration(minutes: 2)).millisecondsSinceEpoch,
    );
  });

  test('a wait longer than 30 min (clock moved back) is ignored', () async {
    final b = buffer();
    await enqueueSeqs(b, [1]);
    reply = (_) => const FakeReply(500);
    await b.flush();
    reply = (_) => const FakeReply(200);
    now = now.subtract(const Duration(days: 1)); // soat bir kun orqaga

    await b.flush();

    expect(await queuedSeqs(), isEmpty);
  });

  test('connectivity regained skips the wait', () async {
    final b = buffer();
    await enqueueSeqs(b, [1]);
    reply = (_) => const FakeReply(500);
    await b.flush();
    reply = (_) => const FakeReply(200);

    await b.flush(ignoreBackoff: true);

    expect(await queuedSeqs(), isEmpty);
  });

  test('sends at most 50 items per flush', () async {
    final b = buffer();
    await enqueueSeqs(b, List.generate(120, (i) => i));

    await b.flush();

    expect(adapter.requests, hasLength(50));
    expect(await queuedSeqs(), List.generate(70, (i) => i + 50));
  });

  test('4xx drops the item and continues', () async {
    final b = buffer();
    await enqueueSeqs(b, [1, 2, 3]);
    reply = (o) => seqOf(o) == 2 ? const FakeReply(400) : const FakeReply(200);

    await b.flush();

    expect(adapter.requests.map(seqOf), [1, 2, 3]);
    expect(await queuedSeqs(), isEmpty);
    expect(await prefInt(_failuresKey), isNull);
  });

  test('no network: nothing sent, no backoff', () async {
    final b = buffer();
    await enqueueSeqs(b, [1]);
    online = false;

    await b.flush();

    expect(adapter.requests, isEmpty);
    expect(await queuedSeqs(), [1]);
    expect(await prefInt(_nextAttemptKey), isNull);
  });

  test('items enqueued during a flush are not lost', () async {
    final b = buffer();
    // LocationService o'z nusxasi bilan qo'shadi (ro'yxat umumiy).
    final location = buffer();
    await enqueueSeqs(b, [1, 2]);
    final gate = Completer<void>();
    reply = (o) async {
      if (seqOf(o) == 1) await gate.future;
      return const FakeReply(200);
    };

    final flushing = b.flush();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await enqueueSeqs(location, [3]); // flush tarmoqda kutib turibdi
    gate.complete();
    await flushing;

    expect(adapter.requests.map(seqOf), [1, 2]);
    expect(await queuedSeqs(), [3]);
  });

  test('parallel flush calls share one run', () async {
    final b = buffer();
    await enqueueSeqs(b, [1, 2]);

    await Future.wait([b.flush(), buffer().flush(), b.flush()]);

    expect(adapter.requests, hasLength(2));
  });

  test('entries older than 24 h are pruned, cap stays 1000', () async {
    final b = buffer();
    await enqueueSeqs(b, [1]);
    now = now.add(const Duration(hours: 25));
    await enqueueSeqs(b, [2]);

    expect(await queuedSeqs(), [2]);
    expect(await b.pendingCount(), 1);
  });
}
