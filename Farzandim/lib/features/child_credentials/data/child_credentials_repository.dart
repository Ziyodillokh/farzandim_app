// ─────────────────────────────────────────────────────────────────────
// ChildCredentialsRepository — bolaning login/parol API'si (ota-ona tokeni)
// ─────────────────────────────────────────────────────────────────────
//
// Endpoint'lar (`/api/children/:childId`, faqat bolaning ota-onasi):
//   GET  /credentials                  → holat yoki null
//   POST /credentials                  → 201 {login, temporaryPassword, issuedAt}
//        birinchi berish: {login?, signOutDevices: false}
//        yangilash:       {signOutDevices}
//        (login allaqachon bor bo'lsa har qanday POST YANGILASH hisoblanadi)
//   GET  /recovery-requests            → ochiq "parolni unutdim" so'rovlari
//   POST /recovery-requests/:id/reject → so'rovni rad etish
//
// Har xato `CredentialsFailure`ga aylanadi (404 `code`siz → `unavailable`).
// Login so'rovdan OLDIN backend qoidasi bilan tekshiriladi (keraksiz 400
// yubormaslik uchun). Vaqtinchalik parol faqat qaytariladi — hech qayerda
// saqlanmaydi va log'ga yozilmaydi.

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/features/child_credentials/data/child_login.dart';
import 'package:farzandim/features/child_credentials/data/credentials_failure.dart';
import 'package:farzandim/features/child_credentials/data/models/child_credentials.dart';
import 'package:farzandim/features/child_credentials/data/models/issued_credentials.dart';
import 'package:farzandim/features/child_credentials/data/models/recovery_request.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final childCredentialsRepositoryProvider = Provider<ChildCredentialsRepository>(
  (ref) => ChildCredentialsRepository(dio: ref.watch(dioClientProvider)),
);

class ChildCredentialsRepository {
  ChildCredentialsRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// Bolaning kirish ma'lumotlari; hali berilmagan bo'lsa `null`.
  Future<ChildCredentials?> fetchCredentials(String childId) =>
      guardCredentialsCall('credentials', () async {
        final res = await _dio.get<Object?>(_path(childId, 'credentials'));
        return ChildCredentials.tryParse(res.data);
      });

  /// Birinchi marta login va parol berish. [login] — ixtiyoriy; bo'sh
  /// yoki berilmasa backend o'zi tanlaydi. Yaroqsiz login so'rovsiz rad
  /// etiladi; band login — 409 (`loginTaken`).
  ///
  /// `signOutDevices: false` HAR DOIM aniq yuboriladi: ekran eskirgan bo'lsa
  /// (login allaqachon berilgan, yoki so'rov qayta yuborilgan) backend bu
  /// so'rovni "yangilash" deb qabul qiladi, uning standart qiymati esa `true` —
  /// bolaning ulangan (nazorat) telefoni tizimdan chiqib ketardi.
  Future<IssuedCredentials> issueCredentials(String childId, {String? login}) =>
      guardCredentialsCall('issue', () async {
        final custom = ChildLogin.normalize(login ?? '');
        if (custom.isNotEmpty && !ChildLogin.isValid(custom)) {
          throw const CredentialsFailure(CredentialsFailureKind.validation);
        }
        final res = await _dio.post<Object?>(
          _path(childId, 'credentials'),
          data: <String, dynamic>{
            if (custom.isNotEmpty) 'login': custom,
            'signOutDevices': false,
          },
        );
        return _issued(res.data);
      });

  /// Mavjud login uchun yangi vaqtinchalik parol. [signOutDevices] —
  /// bolaning boshqa qurilmalari (ulangan telefon ham) tizimdan chiqariladi.
  Future<IssuedCredentials> resetCredentials(
    String childId, {
    required bool signOutDevices,
  }) => guardCredentialsCall('reset', () async {
    final res = await _dio.post<Object?>(
      _path(childId, 'credentials'),
      data: <String, dynamic>{'signOutDevices': signOutDevices},
    );
    return _issued(res.data);
  });

  /// Ochiq "parolni unutdim" so'rovlari (yangisi birinchi).
  Future<List<RecoveryRequest>> fetchRecoveryRequests(String childId) =>
      guardCredentialsCall('recovery', () async {
        final res = await _dio.get<Object?>(
          _path(childId, 'recovery-requests'),
        );
        return parseRecoveryRequests(res.data);
      });

  /// So'rovni rad etish (parol o'zgarmaydi).
  Future<void> rejectRecoveryRequest(String childId, String requestId) =>
      guardCredentialsCall('rejectRecovery', () async {
        await _dio.post<Object?>(
          _path(childId, 'recovery-requests/${_segment(requestId)}/reject'),
          // Bo'sh JSON tana: ba'zi serverlar `Content-Type: json` bilan
          // tanasiz POST'ni rad etadi.
          data: const <String, dynamic>{},
        );
      });

  static IssuedCredentials _issued(Object? data) =>
      IssuedCredentials.tryParse(data) ??
      (throw const CredentialsFailure(CredentialsFailureKind.malformed));

  static String _path(String childId, String tail) =>
      '/children/${_segment(childId)}/$tail';

  /// Yo'l bo'lagi uchun id. Bo'sh id boshqa marshrutga tushib ketmasin
  /// (masalan `/children//credentials`) — oldindan rad etamiz.
  static String _segment(String id) {
    final value = id.trim();
    if (value.isEmpty) {
      throw const CredentialsFailure(CredentialsFailureKind.validation);
    }
    return Uri.encodeComponent(value);
  }
}
