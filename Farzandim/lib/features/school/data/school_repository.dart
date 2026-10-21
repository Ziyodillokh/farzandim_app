// ─────────────────────────────────────────────────────────────────────
// SchoolRepository — Parvoz School, ota-ona ilovasi API (12 ta chaqiruv)
// ─────────────────────────────────────────────────────────────────────
//
// Endpoint'lar (`/api/parent/school`, PARENT tokeni, tarif guard'i YO'Q):
//   A. Bog'lanish  POST /link · GET /links · PUT /students/:id/child ·
//                  DELETE /links/:guardianId
//   B. Xabarlar    GET /announcements · POST /announcements/:id/read ·
//                  GET /payments · GET|POST /verifications
//   C. Davomat     POST|GET /early-exits · GET /attendance
//
// Har xato `SchoolFailure`ga aylanadi (404 `code`siz → `unavailable`).
// Kiritilgan ma'lumot so'rovdan OLDIN backend qoidalari bilan tekshiriladi
// (keraksiz 400 va kod urinishlari limiti sarflanmaydi). WS event yo'q —
// yangilash push, resume va pull-to-refresh orqali.

import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/core/utils/safe_parse.dart';
import 'package:farzandim/features/school/data/invite_code.dart';
import 'package:farzandim/features/school/data/models/school_announcement.dart';
import 'package:farzandim/features/school/data/models/school_attendance.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/data/models/school_payment.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final schoolRepositoryProvider = Provider<SchoolRepository>((ref) {
  return SchoolRepository(dio: ref.watch(dioClientProvider));
});

/// "HH:MM", 24 soat (backend `hhmmSchema`).
final RegExp _hhmm = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

/// "YYYY-MM", oy 01–12 (backend `monthSchema`).
final RegExp _month = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$');

class SchoolRepository {
  SchoolRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const String _base = '/parent/school';

  // ── A. Bog'lanish ──────────────────────────────────────────────────

  /// Bog'lanishlar va moslash uchun farzandlar ro'yxati.
  Future<SchoolLinks> fetchLinks() => guardSchoolCall('links', () async {
    final res = await _dio.get<Object?>('$_base/links');
    return SchoolLinks.fromJson(asJsonMap(res.data) ?? const {});
  });

  /// Taklif kodini kiritish ("abcd-2345" ham bo'ladi) → yangi ro'yxat.
  Future<SchoolLinks> redeemInvite(String rawCode) => guardSchoolCall(
    'redeem',
    () async {
      final code = InviteCode.normalize(rawCode);
      if (!InviteCode.isValid(code)) {
        throw const SchoolFailure(SchoolFailureKind.inviteFormat);
      }
      final res = await _dio.post<Object?>('$_base/link', data: {'code': code});
      return SchoolLinks.fromJson(asJsonMap(res.data) ?? const {});
    },
  );

  /// O'quvchini o'z farzandi bilan moslash (`childId: null` — olib
  /// tashlash). Farzand boshqa o'quvchidan avtomatik ajratiladi.
  Future<SchoolLinks> setStudentChild({
    required String studentId,
    required String? childId,
  }) => guardSchoolCall('setChild', () async {
    final res = await _dio.put<Object?>(
      '$_base/students/${_segment(studentId)}/child',
      data: {'childId': childId},
    );
    return SchoolLinks.fromJson(asJsonMap(res.data) ?? const {});
  });

  /// Maktab bilan aloqani uzish (204).
  Future<void> unlink(String guardianId) => guardSchoolCall('unlink', () async {
    await _dio.delete<void>('$_base/links/${_segment(guardianId)}');
  });

  // ── B. Xabarlar ────────────────────────────────────────────────────

  /// E'lonlar sahifasi (yangisi oldin) + o'qilmaganlar soni.
  Future<AnnouncementPage> fetchAnnouncements({
    int page = 1,
    int limit = kAnnouncementsPageSize,
  }) => guardSchoolCall('announcements', () async {
    final res = await _dio.get<Object?>(
      '$_base/announcements',
      queryParameters: {
        'page': math.max(1, page),
        'limit': limit.clamp(1, kMaxAnnouncementsPageSize),
      },
    );
    return AnnouncementPage.fromJson(asJsonMap(res.data) ?? const {});
  });

  /// E'lon o'qildi (idempotent) → server `readAt` vaqti.
  Future<DateTime> markAnnouncementRead(String announcementId) =>
      guardSchoolCall('announcementRead', () async {
        final res = await _dio.post<Object?>(
          '$_base/announcements/${_segment(announcementId)}/read',
        );
        return asJsonMap(res.data)?.readDateTime('readAt') ?? DateTime.now();
      });

  /// To'lov eslatmalari (summasiz: keyingi sana, farzandlar, ochiq so'rov).
  Future<List<SchoolPaymentReminder>> fetchPayments() =>
      guardSchoolCall('payments', () async {
        final res = await _dio.get<Object?>('$_base/payments');
        return List.unmodifiable(
          parseListSafely(
            _asList(res.data),
            SchoolPaymentReminder.fromJson,
            tag: 'SchoolPaymentReminder',
          ).where((p) => p.id.isNotEmpty),
        );
      });

  /// "To'laganman, tekshiring" so'rovlarim (yangisi oldin, ≤ 100).
  Future<List<PaymentVerification>> fetchVerifications() =>
      guardSchoolCall('verifications', () async {
        final res = await _dio.get<Object?>('$_base/verifications');
        return List.unmodifiable(
          parseListSafely(
            _asList(res.data),
            PaymentVerification.fromJson,
            tag: 'PaymentVerification',
          ).where((v) => v.id.isNotEmpty),
        );
      });

  /// Yangi tekshiruv so'rovi (bitta eslatmada bitta ochiq — aks holda 409).
  Future<PaymentVerification> createVerification({
    required String paymentReminderId,
    required String message,
  }) => guardSchoolCall('createVerification', () async {
    final text = message.trim();
    if (paymentReminderId.trim().isEmpty ||
        text.isEmpty ||
        text.length > kVerificationMessageMax) {
      throw const SchoolFailure(SchoolFailureKind.validation);
    }
    final res = await _dio.post<Object?>(
      '$_base/verifications',
      data: {'paymentReminderId': paymentReminderId, 'message': text},
    );
    return PaymentVerification.fromJson(asJsonMap(res.data) ?? const {});
  });

  // ── C. Davomat ─────────────────────────────────────────────────────

  /// Erta ketish so'rovi — har doim BUGUN uchun (sanani server qo'yadi).
  /// [time] — "HH:MM" (24 soat).
  Future<EarlyExitRequest> requestEarlyExit({
    required String studentId,
    required String time,
    required String reason,
    required String pickupBy,
  }) => guardSchoolCall('requestEarlyExit', () async {
    final why = reason.trim();
    final who = pickupBy.trim();
    if (studentId.trim().isEmpty ||
        !_hhmm.hasMatch(time) ||
        why.isEmpty ||
        why.length > kEarlyExitReasonMax ||
        who.isEmpty ||
        who.length > kEarlyExitPickupMax) {
      throw const SchoolFailure(SchoolFailureKind.validation);
    }
    final res = await _dio.post<Object?>(
      '$_base/early-exits',
      data: {
        'studentId': studentId,
        'time': time,
        'reason': why,
        'pickupBy': who,
      },
    );
    return EarlyExitRequest.fromJson(asJsonMap(res.data) ?? const {});
  });

  /// Bog'langan farzandlar bo'yicha so'rovlar (≤ 50, yangisi oldin;
  /// xodim kiritganlari ham).
  Future<List<EarlyExitRequest>> fetchEarlyExits() =>
      guardSchoolCall('earlyExits', () async {
        final res = await _dio.get<Object?>('$_base/early-exits');
        return List.unmodifiable(
          parseListSafely(
            _asList(res.data),
            EarlyExitRequest.fromJson,
            tag: 'EarlyExitRequest',
          ).where((e) => e.id.isNotEmpty),
        );
      });

  /// Oylik davomat; [month] "YYYY-MM" (berilmasa — joriy Toshkent oyi).
  Future<MonthAttendance> fetchAttendance({
    required String studentId,
    String? month,
  }) => guardSchoolCall('attendance', () async {
    if (studentId.trim().isEmpty ||
        (month != null && !_month.hasMatch(month))) {
      throw const SchoolFailure(SchoolFailureKind.validation);
    }
    final res = await _dio.get<Object?>(
      '$_base/attendance',
      queryParameters: {
        'studentId': studentId,
        if (month != null) 'month': month,
      },
    );
    return MonthAttendance.fromJson(asJsonMap(res.data) ?? const {});
  });

  /// Yo'l bo'lagi uchun id. Bo'sh id 404 (`code`siz) berib, bo'lim
  /// "mavjud emas" deb noto'g'ri yashirilmasin — oldindan rad etamiz.
  static String _segment(String id) {
    final value = id.trim();
    if (value.isEmpty) {
      throw const SchoolFailure(SchoolFailureKind.validation);
    }
    return Uri.encodeComponent(value);
  }

  static List<dynamic> _asList(Object? data) =>
      data is List ? data : const <dynamic>[];
}
