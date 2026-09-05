// Audiokitoblar — BARCHA sahifalarni olib kelish (2026-09-05 xatosi).
//
// XATO: bitta kitob admin panelda har qismi ALOHIDA yozuv bo'lib
// yuklanadi ("Nur borki soya bor - 1..41"), bola ilovasi esa ularni
// `groupIntoSeries` bilan bitta kartaga yig'adi. Ya'ni YOZUVLAR soni ≠
// KITOBLAR soni.
//
// Repozitoriy faqat 1-sahifani (limit 50, server `@Max(50)`) so'rardi va
// keyingi sahifani hech qachon olmasdi. Bazada 188 yozuv bo'lgani holda
// birinchi 50 tasi kelardi — bu esa 41 qismli BITTA kitob + ikkinchisining
// 9 qismi, ekranda atigi 2 ta kitob. Qolgan 138 yozuv umuman yuklanmasdi.
// Videolarda bilinmadi: har video bitta yozuv.
//
// Bu test sikl ishlashini pinlaydi. Dio mock paketi qo'shmaslik uchun
// `HttpClientAdapter` ning o'zi soxtalashtiriladi.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:farzandim_child/features/audiobooks/data/repositories/audiobooks_backend_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sahifalangan javobni taqlid qiladi va SO'RALGAN sahifalarni yozib boradi.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.totalItems, required this.limit});

  final int totalItems;
  final int limit;
  final List<int> requestedPages = [];

  int get totalPages => (totalItems / limit).ceil();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final page = int.parse('${options.queryParameters['page']}');
    requestedPages.add(page);

    final start = (page - 1) * limit;
    final end = (start + limit) > totalItems ? totalItems : (start + limit);
    final items = [
      for (var i = start; i < end; i++)
        {
          'id': 'ab-$i',
          // Har 41 tasi bitta kitobning qismi — haqiqiy holatga o'xshash.
          'title': 'Kitob ${i ~/ 41} - ${(i % 41) + 1}',
          'author': "O'tkir Hoshimov",
          'audioUrl': 'https://example.uz/a$i.mp3',
          'durationSec': 600,
          'partsCount': 41,
          'ageFrom': 0,
          'ageTo': 18,
          'listens': 0,
        },
    ];

    final body = jsonEncode({
      'items': items,
      'pagination': {
        'page': page,
        'totalPages': totalPages,
        'total': totalItems,
        'limit': limit,
      },
    });

    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

AudiobooksBackendRepository _repoWith(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test.local/api'))
    ..httpClientAdapter = adapter;
  return AudiobooksBackendRepository(dio: dio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('fetchAudiobooks — sahifalash', () {
    test('188 yozuv: HAMMASI olinadi (2 ta emas)', () async {
      // Arrange — haqiqiy holat: 188 yozuv, sahifada 50 ta.
      final adapter = _FakeAdapter(totalItems: 188, limit: 50);

      // Act
      final books = await _repoWith(adapter).fetchAudiobooks();

      // Assert — 4 ta sahifa so'ralgan va 188 yozuvning hammasi kelgan.
      expect(adapter.requestedPages, [1, 2, 3, 4]);
      expect(books, hasLength(188));
    });

    test('bitta sahifaga sig\'sa qo\'shimcha so\'rov yuborilmaydi', () async {
      final adapter = _FakeAdapter(totalItems: 30, limit: 50);

      final books = await _repoWith(adapter).fetchAudiobooks();

      expect(adapter.requestedPages, [1]);
      expect(books, hasLength(30));
    });

    test('aynan chegarada (50 ta) ikkinchi sahifa so\'ralmaydi', () async {
      final adapter = _FakeAdapter(totalItems: 50, limit: 50);

      final books = await _repoWith(adapter).fetchAudiobooks();

      expect(adapter.requestedPages, [1]);
      expect(books, hasLength(50));
    });

    test('kontent yo\'q bo\'lsa bo\'sh ro\'yxat, xato emas', () async {
      final adapter = _FakeAdapter(totalItems: 0, limit: 50);

      final books = await _repoWith(adapter).fetchAudiobooks();

      expect(books, isEmpty);
    });

    test("to'liq ro'yxat cache'ga yoziladi (faqat 1-sahifa emas)", () async {
      final adapter = _FakeAdapter(totalItems: 188, limit: 50);
      await _repoWith(adapter).fetchAudiobooks();

      // Yangi repozitoriy — tarmoqqa chiqmasdan cache'dan o'qiydi.
      final offline = _repoWith(_FakeAdapter(totalItems: 0, limit: 50));
      final cached = await offline.cachedAudiobooks();

      expect(cached, hasLength(188));
    });
  });
}
