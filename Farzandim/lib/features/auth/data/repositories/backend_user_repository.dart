// ─────────────────────────────────────────────────────────────────────
// BackendUserRepository — Backend Users API (Sprint 4.4.1)
// ─────────────────────────────────────────────────────────────────────
//
// User profil CRUD (auth flow'dan alohida — login/refresh
// BackendAuthRepository'da qoladi).
//
// Backend kontrakt:
//   GET  /api/users/me              → AuthUser obyekti
//   PUT  /api/users/me  body {...}  → yangilangan AuthUser
//     body: { name?, avatarUrl?, language? }
//
// Telefon raqami alohida endpoint orqali (POST /api/users/me/phone,
// keyingi sub-sprint'da ulanadi).

// ignore_for_file: public_member_api_docs

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/features/auth/data/models/auth_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendUserRepositoryProvider = Provider<BackendUserRepository>((ref) {
  return BackendUserRepository(dio: ref.watch(dioClientProvider));
});

class BackendUserRepository {
  BackendUserRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// Joriy user profilini Backend'dan oladi.
  ///
  /// 401 holatida DioClient refresh interceptor avtomatik chaqiriladi.
  /// Refresh ham fail bo'lsa `null` qaytaradi (caller logout qilishi shart).
  Future<AuthUser?> me() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/users/me');
      final data = response.data;
      if (data == null) return null;
      return AuthUser.fromJson(data);
    } on DioException {
      return null;
    }
  }

  /// Profil tahrirlash. Backend faqat berilgan fieldlarni yangilaydi
  /// (partial update), qolganlari saqlanadi.
  ///
  /// `name`     — ko'rsatiladigan ism (1-100 char)
  /// `avatarUrl` — avatar URL (Telegram URL yoki keyinroq Backend signed URL)
  /// `language` — 'uz' | 'ru' | 'en' (Backend default 'uz')
  ///
  /// Muvaffaqiyat: yangilangan `AuthUser`. Xato: `Exception` otadi
  /// (caller UI'da SnackBar ko'rsatadi).
  Future<AuthUser> updateMe({
    String? name,
    String? avatarUrl,
    String? language,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (avatarUrl != null) body['avatarUrl'] = avatarUrl;
    if (language != null) body['language'] = language;

    if (body.isEmpty) {
      throw ArgumentError("updateMe: hech qanday o'zgartirish yo'q");
    }

    final response = await _dio.put<Map<String, dynamic>>(
      '/users/me',
      data: body,
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException("PUT /users/me: bo'sh response");
    }
    return AuthUser.fromJson(data);
  }

  /// Akkauntni Backend'da butunlay o'chiradi (DELETE /api/users/me).
  /// Backend cascade: bola(lar), lokatsiya, xabarlar, obuna — hammasi o'chadi.
  /// Xato bo'lsa `DioException` otadi (caller UI'da ko'rsatadi).
  Future<void> deleteAccount() async {
    await _dio.delete<void>('/users/me');
  }

  /// Profil rasmini Backend'ga yuklaydi. Yangi signed URL qaytaradi.
  Future<String?> uploadAvatar(Uint8List bytes) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: 'avatar.jpg',
        contentType: DioMediaType('image', 'jpeg'),
      ),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/users/me/avatar',
      data: formData,
    );
    return response.data?['avatarUrl'] as String?;
  }
}
