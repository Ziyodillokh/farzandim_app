// Maktab (v5) manbai: e'lonlar, davomat tarixi, dars jadvali va yozma vazifa
// javobini yuborish (`/api/child/school/*`, CHILD token). Xatolar mavjud
// `SchoolException`ga aylanadi (404 → `unavailable`: endpoint yo'q yoki bola
// maktabga bog'lanmagan).

import 'dart:math';

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/features/school/domain/school_assignment.dart';
import 'package:farzandim_child/features/school/domain/school_json.dart';
import 'package:farzandim_child/growth/maktab/data/school_v5_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bitta javobdagi rasmlar soni va hajmi (server bilan bir xil).
const kHomeworkMaxPhotos = 5;
const kHomeworkMaxPhotoBytes = 8 * 1024 * 1024;

abstract interface class SchoolV5Repository {
  Future<SchoolNoticePage> loadNotices();

  Future<void> markNoticeRead(String id);

  Future<AttendanceMonth> loadAttendance(DateTime month);

  Future<TimetableDay> loadTimetable(DateTime date);

  Future<HomeworkSubmission> submitHomework({
    required String assignmentId,
    required List<String> photoPaths,
    required String comment,
    required String requestId,
  });

  /// Maktab materiali: "O'qidim" (takroriy so'rov — o'zgarishsiz).
  Future<void> markLessonRead(String assignmentId);
}

class ApiSchoolV5Repository implements SchoolV5Repository {
  ApiSchoolV5Repository(this._dio);

  final Dio _dio;

  @override
  Future<SchoolNoticePage> loadNotices() => _guard(() async {
    final res = await _dio.get<Object?>(
      '/child/school/announcements',
      queryParameters: {'limit': 50},
    );
    final data = res.data;
    if (data is! Map) throw const FormatException('announcements: obyekt');
    return SchoolNoticePage(
      items: jsonList(data['items'], SchoolNotice.tryFromJson),
      unreadCount: jsonInt(data['unreadCount']) ?? 0,
    );
  });

  @override
  Future<void> markNoticeRead(String id) => _guard(() async {
    await _dio.post<Object?>(
      '/child/school/announcements/${Uri.encodeComponent(id)}/read',
    );
  });

  @override
  Future<AttendanceMonth> loadAttendance(DateTime month) => _guard(() async {
    final key =
        '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
    final res = await _dio.get<Object?>(
      '/child/school/attendance',
      queryParameters: {'month': key},
    );
    final data = res.data;
    if (data is! Map) throw const FormatException('attendance: obyekt');
    return AttendanceMonth(
      month: DateTime(month.year, month.month),
      days: jsonList(data['days'], AttendanceDay.tryFromJson),
    );
  });

  @override
  Future<TimetableDay> loadTimetable(DateTime date) => _guard(() async {
    final key =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final res = await _dio.get<Object?>(
      '/child/school/timetable',
      queryParameters: {'date': key},
    );
    return TimetableDay.tryFromJson(res.data) ??
        (throw const FormatException('timetable'));
  });

  @override
  Future<HomeworkSubmission> submitHomework({
    required String assignmentId,
    required List<String> photoPaths,
    required String comment,
    required String requestId,
  }) => _guard(() async {
    final form = FormData.fromMap({
      'requestId': requestId,
      if (comment.trim().isNotEmpty) 'comment': comment.trim(),
      'files': [
        for (final path in photoPaths) await MultipartFile.fromFile(path),
      ],
    });
    final res = await _dio.post<Object?>(
      '/child/school/assignments/${Uri.encodeComponent(assignmentId)}/submission',
      data: form,
      options: Options(
        sendTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );
    return HomeworkSubmission.tryFromJson(res.data) ??
        (throw const FormatException('submission'));
  });

  @override
  Future<void> markLessonRead(String assignmentId) => _guard(() async {
    await _dio.post<Object?>(
      '/child/school/assignments/${Uri.encodeComponent(assignmentId)}/read',
    );
  });

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      debugPrint(
        '[school-v5] ${e.requestOptions.path}: ${e.response?.statusCode} ${e.message}',
      );
      final status = e.response?.statusCode;
      throw SchoolException(switch (status) {
        null => SchoolErrorCode.network,
        404 => SchoolErrorCode.unavailable,
        409 => SchoolErrorCode.alreadySubmitted,
        400 || 413 || 415 || 422 => SchoolErrorCode.validation,
        429 => SchoolErrorCode.tooManyRequests,
        _ => SchoolErrorCode.unknown,
      }, e.message);
    } on FormatException catch (e) {
      throw SchoolException(SchoolErrorCode.unknown, e.message);
    }
  }
}

/// Takroriy yuborishda bir xil javob uchun mijoz identifikatori (UUID v4).
String newRequestId([Random? random]) {
  final r = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

final schoolV5RepositoryProvider = Provider<SchoolV5Repository>(
  (ref) => ApiSchoolV5Repository(ref.watch(dioClientProvider)),
);

final schoolNoticesProvider = FutureProvider.autoDispose<SchoolNoticePage>(
  (ref) => ref.watch(schoolV5RepositoryProvider).loadNotices(),
);

final schoolAttendanceMonthProvider = FutureProvider.autoDispose
    .family<AttendanceMonth, DateTime>(
      (ref, month) =>
          ref.watch(schoolV5RepositoryProvider).loadAttendance(month),
    );

final schoolTimetableProvider = FutureProvider.autoDispose
    .family<TimetableDay, DateTime>(
      (ref, date) => ref
          .watch(schoolV5RepositoryProvider)
          .loadTimetable(DateTime(date.year, date.month, date.day)),
    );
