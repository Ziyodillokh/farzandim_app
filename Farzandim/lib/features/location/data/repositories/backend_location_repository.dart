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
  /// 404 — bola hech qachon location yubormagan (yangi pair'lashgan) →
  /// `null`. Boshqa xatolar yuqoriga otiladi: avval hammasi null'ga
  /// yutilardi va vaqtinchalik tarmoq xatosi ekranda "Lokatsiya yo'q"
  /// (retry'siz) bo'lib ko'rinardi.
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
      if (e.response?.statusCode == 404) return null;
      debugPrint('BackendLocationRepository.getLatest: $e');
      rethrow;
    }
  }

  /// Bola qurilmasidan darhol yangi GPS fix so'raydi (backend data-only
  /// FCM yuboradi). Best-effort — xato yutiladi, javob WS orqali keladi.
  Future<void> requestLocationUpdate(String childId) async {
    try {
      await _dio.post<void>(
        '/children/$childId/location/request-update',
        data: const <String, dynamic>{},
      );
    } on DioException catch (e) {
      debugPrint('BackendLocationRepository.requestLocationUpdate: $e');
    }
  }

  /// Bola joylashuvni O'CHIRGANда unga "joylashuvni yoqing" so'rovi (backend
  /// KO'RINADIGAN push yuboradi → bolada modal). `request-update` (wake) dan
  /// farqi: bu joylashuv o'chiq bo'lganda bolaga qo'lda yoqishni so'raydi.
  /// `true` — so'rov yuborildi, `false` — xato.
  Future<bool> requestLocationEnable(String childId) async {
    try {
      await _dio.post<void>(
        '/children/$childId/location/request-enable',
        data: const <String, dynamic>{},
      );
      return true;
    } on DioException catch (e) {
      debugPrint('BackendLocationRepository.requestLocationEnable: $e');
      return false;
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
    DateTime? before,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/location/history',
        queryParameters: {
          if (from != null) 'from': from.toUtc().toIso8601String(),
          if (to != null) 'to': to.toUtc().toIso8601String(),
          // Cursor — to'liq kunni 500 talik sahifalar bilan olish uchun.
          if (before != null) 'before': before.toUtc().toIso8601String(),
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

  /// WS `location:updated` event'laridan shu bolaning joylashuvlari.
  /// Broadcast `eventStream`'dan childId bo'yicha filtrlanadi, shunda
  /// bir nechta bolaga parallel obuna bo'lsa ham bir-biriga tegmaydi.
  /// Boshlang'ich fetch/resync/polling provider tomonida.
  Stream<ChildLocation> locationEvents(String childId) async* {
    await for (final data in _socketClient.eventStream('location:updated')) {
      if (data is! Map) continue;
      if ((data['childId'] as String?) != childId) continue;
      final locJson = data['location'];
      // socket_io payload'ni ko'pincha Map<dynamic,dynamic> qilib beradi —
      // qattiq cast update'ni jim o'ldirardi, .from() bilan normalizatsiya.
      if (locJson is! Map) continue;
      try {
        yield ChildLocation.fromBackendJson(Map<String, dynamic>.from(locJson));
      } catch (e) {
        debugPrint('LocRepo[$childId]: WS parse xato — $e');
      }
    }
  }
}
