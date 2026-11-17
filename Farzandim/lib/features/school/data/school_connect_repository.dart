// ─────────────────────────────────────────────────────────────────────
// SchoolConnectRepository — maktab bilan aloqa va farzand statistikasi
// ─────────────────────────────────────────────────────────────────────
//
// Endpoint'lar (`/api/parent/school`, PARENT tokeni):
//   GET  /contacts?studentId=          — o'quvchi bo'yicha kontaktlar
//   GET  /threads · POST /threads      — yozishmalar / yangi xabar
//   GET  /threads/:id · POST /threads/:id/messages · POST /threads/:id/read
//   GET  /students/:id/overview        — "Farzandim maktabda"
// Har xato `SchoolFailure` (429 `RATE_LIMITED` — kunlik chegara; 409
// `contact unavailable` — xodim endi kontakt emas).

import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/core/utils/safe_parse.dart';
import 'package:farzandim/features/school/data/models/school_connect.dart';
import 'package:farzandim/features/school/data/models/student_overview.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final schoolConnectRepositoryProvider = Provider<SchoolConnectRepository>((
  ref,
) {
  return SchoolConnectRepository(dio: ref.watch(dioClientProvider));
});

class SchoolConnectRepository {
  SchoolConnectRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const String _base = '/parent/school';
  static final math.Random _random = math.Random.secure();

  Future<SchoolContacts> fetchContacts(String studentId) =>
      guardSchoolCall('contacts', () async {
        _requireId(studentId);
        final res = await _dio.get<Object?>(
          '$_base/contacts',
          queryParameters: {'studentId': studentId},
        );
        return SchoolContacts.fromJson(asJsonMap(res.data) ?? const {});
      });

  Future<SchoolThreads> fetchThreads() => guardSchoolCall('threads', () async {
    final res = await _dio.get<Object?>('$_base/threads');
    return SchoolThreads.fromJson(asJsonMap(res.data) ?? const {});
  });

  Future<SchoolThread> fetchThread(String threadId) =>
      guardSchoolCall('thread', () async {
        final res = await _dio.get<Object?>(
          '$_base/threads/${_segment(threadId)}',
        );
        return SchoolThread.fromJson(asJsonMap(res.data) ?? const {});
      });

  /// Xodimga xabar: yozishma bo'lmasa ochiladi (bitta juftlikda bitta).
  Future<SchoolThread> startThread({
    required String staffId,
    required String studentId,
    required ContactTopic topic,
    required String body,
  }) => guardSchoolCall('startThread', () async {
    _requireId(staffId);
    _requireId(studentId);
    final text = _validBody(body);
    final res = await _dio.post<Object?>(
      '$_base/threads',
      data: {
        'staffId': staffId,
        'studentId': studentId,
        'topic': topic.api,
        'body': text,
        'clientMessageId': _clientId(),
      },
    );
    return SchoolThread.fromJson(asJsonMap(res.data) ?? const {});
  });

  Future<SchoolThread> sendMessage({
    required String threadId,
    required String body,
    ContactTopic? topic,
  }) => guardSchoolCall('sendMessage', () async {
    final text = _validBody(body);
    final res = await _dio.post<Object?>(
      '$_base/threads/${_segment(threadId)}/messages',
      data: {
        'body': text,
        'topic': ?topic?.api,
        'clientMessageId': _clientId(),
      },
    );
    return SchoolThread.fromJson(asJsonMap(res.data) ?? const {});
  });

  Future<void> markThreadRead(String threadId) =>
      guardSchoolCall('threadRead', () async {
        await _dio.post<Object?>('$_base/threads/${_segment(threadId)}/read');
      });

  Future<StudentOverview> fetchOverview(String studentId) =>
      guardSchoolCall('overview', () async {
        final res = await _dio.get<Object?>(
          '$_base/students/${_segment(studentId)}/overview',
        );
        return StudentOverview.fromJson(asJsonMap(res.data) ?? const {});
      });

  // ── yordamchilar ────────────────────────────────────────────────────

  /// Bo'sh yoki juda uzun matn so'rovsiz rad etiladi (backend qoidasi).
  static String _validBody(String body) {
    final text = body.replaceAll('\r\n', '\n').trim();
    if (text.isEmpty || text.length > kParentMessageMax) {
      throw const SchoolFailure(SchoolFailureKind.validation);
    }
    return text;
  }

  static void _requireId(String id) {
    if (id.trim().isEmpty) {
      throw const SchoolFailure(SchoolFailureKind.validation);
    }
  }

  static String _segment(String id) {
    _requireId(id);
    return Uri.encodeComponent(id.trim());
  }

  /// Idempotentlik kaliti: tarmoq qayta urinishi dublikat yaratmaydi.
  static String _clientId() {
    final bytes = List<int>.generate(12, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
