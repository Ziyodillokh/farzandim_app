// Bola joylashuvi uchun Backend REST + WS klienti: eng so'nggi nuqta,
// tarix, to'xtashlar va `location:updated` real-time stream.
// Backend `emitToUser` ham qiladi, shuning uchun `join:child`siz ham
// parent user room orqali event'larni eshitadi.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/core/realtime/socket_client.dart';
import 'package:farzandim/features/location/data/models/child_location.dart';
import 'package:farzandim/features/location/data/models/location_stop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendLocationRepositoryProvider = Provider<BackendLocationRepository>((
  ref,
) {
  return BackendLocationRepository(
    dio: ref.watch(dioClientProvider),
    socketClient: ref.watch(socketClientProvider),
  );
});

class BackendLocationRepository {
  BackendLocationRepository({
    required Dio dio,
    required SocketClient socketClient,
  }) : _dio = dio,
       _socketClient = socketClient;

  final Dio _dio;
  final SocketClient _socketClient;

  /// Bola eng so'nggi joylashuvini Backend'dan oladi.
  ///
  /// `null` qaytadi:
  /// - 404: bola hech qachon location yubormagan (yangi pair'lashgan)
  /// - boshqa xato: log + null
  Future<ChildLocation?> getLatest(String childId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/location',
      );
      final data = response.data;
      if (data == null) return null;
      final locJson = data['location'] as Map<String, dynamic>?;
      if (locJson == null) return null;
      return ChildLocation.fromBackendJson(locJson);
    } on DioException catch (e) {
      // 404 — yangi bola, location yo'q. Bu xato emas — null qaytaramiz.
      if (e.response?.statusCode == 404) return null;
      debugPrint('BackendLocationRepository.getLatest: $e');
      return null;
    }
  }

  /// Bola harakat tarixini Backend'dan oladi.
  ///
  /// `from`/`to` ISO 8601 (UTC), `null` bo'lsa backend default ishlatadi.
  /// `limit` 1..500. Javob DESC tartibda — polyline uchun caller
  /// `.reversed.toList()` qilishi mumkin.
  Future<List<ChildLocation>> getHistory({
    required String childId,
    DateTime? from,
    DateTime? to,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/location/history',
        queryParameters: {
          if (from != null) 'from': from.toUtc().toIso8601String(),
          if (to != null) 'to': to.toUtc().toIso8601String(),
          'limit': limit,
        },
      );
      final data = response.data;
      if (data == null) return const [];
      final list = data['locations'] as List<dynamic>? ?? const [];
      return list
          .map((e) => ChildLocation.fromBackendJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      debugPrint('BackendLocationRepository.getHistory: $e');
      return const [];
    }
  }

  /// Bola to'xtagan joylari (backend stop-detection). Xaritada marker.
  /// `from`/`to` ISO 8601 (UTC). Xato bo'lsa bo'sh ro'yxat.
  Future<List<LocationStop>> getStops({
    required String childId,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/location/stops',
        queryParameters: {
          if (from != null) 'from': from.toUtc().toIso8601String(),
          if (to != null) 'to': to.toUtc().toIso8601String(),
        },
      );
      final list = response.data?['stops'] as List<dynamic>? ?? const [];
      return list
          .map((e) => LocationStop.fromBackendJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      debugPrint('BackendLocationRepository.getStops: $e');
      return const [];
    }
  }

  /// Bola joriy joylashuvi stream'i — boshlang'ich Backend fetch + WS
  /// `location:updated` real-time yangilanishlar. Broadcast
  /// `eventStream`'dan childId bo'yicha filtrlanadi, shunda bir nechta
  /// bolaga parallel obuna bo'lsa ham bir-biriga tegmaydi.
  Stream<ChildLocation?> watchLocation(String childId) {
    late StreamController<ChildLocation?> controller;
    StreamSubscription<dynamic>? subscription;

    controller = StreamController<ChildLocation?>(
      onListen: () async {
        debugPrint('LocRepo[$childId]: watchLocation onListen — subscribed');
        // Avval backend'dan joriy nuqtani olamiz.
        final initial = await getLatest(childId);
        if (controller.isClosed) return;
        final initialStr = initial == null
            ? 'null'
            : '${initial.latitude},${initial.longitude}';
        debugPrint('LocRepo[$childId]: initial fetch — $initialStr');
        controller.add(initial);

        // Keyin WS stream'iga obuna — faqat shu bolaning
        // 'location:updated' event'lari emit qilinadi.
        subscription = _socketClient.eventStream('location:updated').listen((
          data,
        ) {
          if (controller.isClosed) return;
          // To'liq payload'ni print qilmaymiz — har WS event'da katta
          // string yasash bekorga xotira va log IO sarflaydi.
          if (data is! Map) {
            debugPrint('LocRepo[$childId]: WS payload not Map — skip');
            return;
          }
          final eventChildId = data['childId'] as String?;
          if (eventChildId != childId) {
            debugPrint(
              'LocRepo[$childId]: WS childId mismatch ($eventChildId) — skip',
            );
            return;
          }

          final locJson = data['location'];
          // socket_io payload'ni ko'pincha Map<dynamic,dynamic> qilib
          // beradi — qattiq Map<String,dynamic> cast real-time update'ni
          // jimgina o'ldirardi. Yumshoq tekshirib .from() bilan
          // normalizatsiya qilamiz.
          if (locJson is! Map) {
            debugPrint('LocRepo[$childId]: WS location field not Map — skip');
            return;
          }
          try {
            final loc = ChildLocation.fromBackendJson(
              Map<String, dynamic>.from(locJson),
            );
            debugPrint(
              'LocRepo[$childId]: WS yangi joylashuv '
              '${loc.latitude},${loc.longitude}',
            );
            controller.add(loc);
          } catch (e) {
            debugPrint('LocRepo[$childId]: WS parse xato — $e');
          }
        });
      },
      onCancel: () async {
        debugPrint('LocRepo[$childId]: watchLocation onCancel');
        await subscription?.cancel();
      },
    );

    return controller.stream;
  }
}
