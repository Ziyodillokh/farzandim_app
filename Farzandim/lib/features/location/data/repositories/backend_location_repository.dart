// ─────────────────────────────────────────────────────────────────────
// BackendLocationRepository — Backend Location API (Sprint 4.4.2)
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt:
//   GET  /api/children/:childId/location          — eng so'nggi
//   GET  /api/children/:childId/location/history  — tarix (from/to/limit)
//   WS   location:updated { childId, location }   — real-time push
//
// Real-time pipeline:
//   1. `watchLocation(childId)` chaqirilganda — Backend'dan initial
//      latest fetch + WS listener qo'shiladi
//   2. WS event keladi (`location:updated`) — childId filter qo'yiladi
//      va shu bola uchun yangi `ChildLocation` emit qilinadi
//   3. Stream listener cancel bo'lganda — WS listener olib tashlanadi
//
// Eslatma: Backend `emitToUser(parentId, ...)` ham qiladi, demak
// `join:child` chaqirilmasa ham parent eshitadi (auto-join user room).

// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/core/realtime/socket_client.dart';
import 'package:farzandim/features/location/data/models/child_location.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendLocationRepositoryProvider =
    Provider<BackendLocationRepository>((ref) {
  return BackendLocationRepository(
    dio: ref.watch(dioClientProvider),
    socketClient: ref.watch(socketClientProvider),
  );
});

class BackendLocationRepository {
  BackendLocationRepository({
    required Dio dio,
    required SocketClient socketClient,
  })  : _dio = dio,
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
  /// `from`/`to` ISO 8601 vaqt (UTC). `null` bo'lsa Backend default
  /// ishlatadi (cheklov yo'q). `limit` 1..500, default 100.
  ///
  /// Response chronologic order DESC (Backend `orderBy createdAt desc`).
  /// Polyline chizish uchun caller `.reversed.toList()` qilishi mumkin.
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

  /// Bola joriy joylashuvi stream'i — initial Backend fetch + WS
  /// `location:updated` real-time updates.
  ///
  /// SocketClient'ning broadcast `eventStream`'idan foydalanadi —
  /// bir nechta child uchun bir paytda subscribe bo'lib boshqasiga
  /// tegmaslik (childId filter).
  Stream<ChildLocation?> watchLocation(String childId) {
    late StreamController<ChildLocation?> controller;
    StreamSubscription<dynamic>? subscription;

    controller = StreamController<ChildLocation?>(
      onListen: () async {
        debugPrint('LocRepo[$childId]: watchLocation onListen — subscribed');
        // 1. Initial Backend fetch.
        final initial = await getLatest(childId);
        if (controller.isClosed) return;
        debugPrint(
          'LocRepo[$childId]: initial fetch — '
          '${initial == null ? "null" : "${initial.latitude},${initial.longitude}"}',
        );
        controller.add(initial);

        // 2. WS broadcast stream'iga obuna — har 'location:updated'
        // event filter qilinib bola moslashsagina emit qilinadi.
        subscription =
            _socketClient.eventStream('location:updated').listen((data) {
          if (controller.isClosed) return;
          debugPrint('LocRepo[$childId]: WS location:updated raw — $data');
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
          if (locJson is! Map<String, dynamic>) {
            debugPrint('LocRepo[$childId]: WS location field not Map — skip');
            return;
          }
          try {
            final loc = ChildLocation.fromBackendJson(locJson);
            debugPrint(
              'LocRepo[$childId]: WS yangi joylashuv ${loc.latitude},${loc.longitude}',
            );
            controller.add(loc);
          } catch (e) {
            debugPrint(
              'LocRepo[$childId]: WS parse xato — $e',
            );
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
