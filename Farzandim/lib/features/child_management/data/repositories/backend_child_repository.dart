// ─────────────────────────────────────────────────────────────────────
// BackendChildRepository — Backend REST CRUD (Sprint 4.4 Bosqich 3)
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt (Backend Claude tasdiqlagan):
//   GET    /api/children                  → { "children": [...] }
//   POST   /api/children                  → Child obyekti
//   GET    /api/children/:id              → Child obyekti
//   PUT    /api/children/:id              → Yangilangan Child
//   DELETE /api/children/:id              → { "ok": true }
//   POST   /api/children/:id/pair-code    → { "familyCode": "73921" }
//
// Avatar:
//   POST   /api/children/:id/avatar        (multipart upload)
//   GET    /api/children/:id/avatar/image  (proxy stream — pastda)

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:farzandim/core/cache/swr_cache.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/core/utils/safe_parse.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/data/models/gender.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendChildRepositoryProvider = Provider<BackendChildRepository>((ref) {
  return BackendChildRepository(dio: ref.watch(dioClientProvider));
});

class BackendChildRepository {
  BackendChildRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// Parent uchun barcha bolalar ro'yxati (createdAt DESC).
  /// Backend response: { "children": [Child, ...] }
  Future<List<Child>> getChildren() async {
    final response = await _dio.get<Map<String, dynamic>>('/children');
    final data = response.data;
    if (data == null) return const [];
    final list = data['children'];
    if (list is! List) return const [];
    // NET-07: xom javob disk-keshga — keyingi cold start'da dashboard
    // serverni kutmasdan DARHOL oxirgi ro'yxatni ko'rsatadi.
    unawaited(SwrCache.write('children', list));
    // ARCH-12: bitta buzuq element butun ro'yxatni yiqitmasin.
    return parseListSafely(list, Child.fromJson, tag: 'children');
  }

  /// NET-07: disk-keshdagi oxirgi bolalar ro'yxati (stale) — cold start'da
  /// server javobini kutmasdan ko'rsatish uchun. Kesh yo'q/buzuq → `null`.
  Future<List<Child>?> getCachedChildren() async {
    final cached = await SwrCache.read('children');
    if (cached == null) return null;
    final (data, _) = cached;
    if (data is! List) return null;
    final parsed = parseListSafely(data, Child.fromJson, tag: 'childrenCache');
    return parsed.isEmpty ? null : parsed;
  }

  /// Bitta bola — id bo'yicha.
  Future<Child?> getChild(String childId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId',
      );
      final data = response.data;
      if (data == null) return null;
      return Child.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Yangi bola yaratish. Backend `familyCode`'ni avtomatik generatsiya
  /// qiladi (5-digit unique, 10 marta retry).
  Future<Child> addChild({
    required String name,
    required int age,
    required Gender gender,
    String? region,
    String? phoneNumber,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/children',
      data: {
        'name': name,
        if (age > 0) 'age': age,
        'gender': gender == Gender.male ? 'male' : 'female',
        if (region != null && region.isNotEmpty) 'region': region,
        if (phoneNumber != null && phoneNumber.isNotEmpty)
          'phoneNumber': phoneNumber,
      },
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException("POST /children: bo'sh javob");
    }
    return Child.fromJson(data);
  }

  /// Bola ma'lumotlarini yangilash. Partial update — faqat o'zgargan
  /// fieldlarni yuborish kifoya. Backend qaytarilgan Child obyektini
  /// to'liq qaytaradi.
  Future<Child> updateChild(String childId, Child updated) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/children/$childId',
      data: updated.toJson(),
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException("PUT /children/:id: bo'sh javob");
    }
    return Child.fromJson(data);
  }

  /// Bolani o'chirish (Backend cascade qiladi: location, schedule,
  /// routine, geo zone, profile, va h.k.).
  ///
  /// Eslatma: Fastify strict mode `Content-Type: application/json`
  /// bilan kelgan request'da bo'sh body'ni rad qiladi
  /// (FST_ERR_CTP_EMPTY_JSON_BODY). DELETE odatda body'siz —
  /// Content-Type header'ini explicit null qilamiz.
  Future<void> deleteChild(String childId) async {
    await _dio.delete<Map<String, dynamic>>(
      '/children/$childId',
      data: const <String, dynamic>{},
    );
  }

  /// Yangi family code generatsiya (eski childUserId null'ga, isConnected
  /// false'ga). Foydalanuvchi bola qurilmasini yo'qotsa yoki yangisini
  /// ulasa ishlatadi.
  ///
  /// Returns: yangi 5-raqamli familyCode.
  Future<String> regenerateFamilyCode(String childId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/children/$childId/pair-code',
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException("POST /children/:id/pair-code: bo'sh");
    }
    final code = data['familyCode'] as String?;
    if (code == null || code.isEmpty) {
      throw const FormatException("familyCode yo'q");
    }
    return code;
  }

  /// Avatar upload — multipart `POST /api/children/:id/avatar`.
  /// Backend response: yangi `Child` obyekti (photoPath bilan).
  Future<Child> uploadAvatar(String childId, List<int> bytes) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: 'avatar.jpg',
        contentType: DioMediaType('image', 'jpeg'),
      ),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/children/$childId/avatar',
      data: formData,
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException("POST /avatar: bo'sh javob");
    }
    return Child.fromJson(data);
  }

  /// Bola qurilmasini baland ovozda jiringlatish — `POST /children/:id/ring`.
  /// Backend FCM data push yuboradi; bola qurilmasi silent rejimda ham
  /// STREAM_ALARM orqali jiringlaydi (qurilmani topish).
  Future<void> ringDevice(String childId) async {
    await _dio.post<void>('/children/$childId/ring');
  }

  /// "Notanish manbalardan ilovalar" toggle — `PUT /children/:id`.
  /// `true` bo'lsa bola qurilmasi Play'dan boshqa manbadagi ilovalarni
  /// bloklaydi (native enforce). Yangilangan `Child` qaytadi.
  Future<Child> setBlockUnknownSources(
    String childId, {
    required bool value,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/children/$childId',
      data: <String, dynamic>{'blockUnknownSources': value},
    );
    return Child.fromJson(response.data ?? <String, dynamic>{});
  }

  /// "Barcha ilovalarni bloklash" toggle (dashboard) — `PUT /children/:id`.
  /// `true` bo'lsa bola qurilmasidagi barcha ilovalar bloklanadi (Child App
  /// device-policy'ni o'qib enforce qiladi). Yangilangan `Child` qaytadi.
  Future<Child> setBlockAllApps(String childId, {required bool value}) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/children/$childId',
      data: <String, dynamic>{'blockAllApps': value},
    );
    return Child.fromJson(response.data ?? <String, dynamic>{});
  }

  /// "O'chirishni taqiqlash" — bola Farzandim'ni o'chira olmaydi (Device
  /// Admin orqali uninstall bloklanadi).
  Future<Child> setBlockUninstall(String childId, {required bool value}) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/children/$childId',
      data: <String, dynamic>{'blockUninstall': value},
    );
    return Child.fromJson(response.data ?? <String, dynamic>{});
  }

  /// "Xavfsiz internet filtri" — `PUT /children/:id`. `enabled` filtr holati,
  /// `categories` bloklangan kategoriyalar (ADULT | GAMBLING | SOCIAL).
  /// Yangilangan `Child` qaytadi (bola qurilmasi device-policy'ni o'qib
  /// enforce qiladi).
  Future<Child> setWebFilter(
    String childId, {
    required bool enabled,
    required List<String> categories,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/children/$childId',
      data: <String, dynamic>{
        'webFilterEnabled': enabled,
        'blockedWebCategories': categories,
      },
    );
    return Child.fromJson(response.data ?? <String, dynamic>{});
  }

  /// Avatar rasm proxy URL — `GET /api/children/:id/avatar/image`.
  ///
  /// Backend MinIO'dan rasmni stream qiladi (signed URL'ga qaraganda
  /// ishonchli: telefon ichki MinIO endpointiga ulanolmaydi). URL barqaror —
  /// bola foto yuklagan bo'lsa shu manzilda rasm turadi, aks holda 404.
  String avatarProxyUrl(String childId) =>
      '${_dio.options.baseUrl}/children/$childId/avatar/image';
}
