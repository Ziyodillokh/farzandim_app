// ─────────────────────────────────────────────────────────────────────
// ChildRepository — bola profili Backend (NestJS + MinIO) operatsiyalari
// ─────────────────────────────────────────────────────────────────────
//
// AccountEditScreen ushbu repodan foydalanadi:
//   - updateMyProfile() — name/age/region yangilash (PUT /children/me)
//   - uploadMyAvatar()  — foto MinIO'ga yuklash (POST /children/me/avatar)
//
// Eski versiya Firebase Firestore + Storage ishlatardi — ammo loyiha
// backend'i NestJS + MinIO. Firebase sozlanmagani uchun rasm yuklash
// `storage/retry-limit-exceeded` / `permission-denied` bilan tushardi.
// Endi qolgan ilova bilan bir xil — Backend Child JWT orqali.

import 'dart:typed_data';

import 'package:dio/dio.dart';

class ChildRepository {
  ChildRepository(this._dio);

  final Dio _dio;

  /// Bola o'z ism/yosh/hududini yangilaydi. `null` qiymatlar payloadga
  /// qo'shilmaydi — qisman update. Backend `childUserId` (CHILD JWT) orqali
  /// bolani topadi.
  Future<void> updateMyProfile({String? name, int? age, String? region}) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (age != null) data['age'] = age;
    if (region != null) data['region'] = region;

    if (data.isEmpty) return;

    await _dio.put<Map<String, dynamic>>('/children/me', data: data);
  }

  /// Foto MinIO'ga yuklanadi (multipart). Backend `photoPath`'ni yangilaydi;
  /// rasm `GET /children/:id/avatar/image` proxy orqali ko'rsatiladi.
  ///
  /// `bytes` ishlatiladi (File emas) — web va mobile'da bir xil. fromBytes
  /// kontent-tipni fayl nomidan aniqlay olmaydi, shuning uchun `image/jpeg`
  /// aniq beriladi (aks holda backend `octet-stream`'ni rad etadi).
  Future<void> uploadMyAvatar({
    required Uint8List bytes,
    String filename = 'profile.jpg',
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType('image', 'jpeg'),
      ),
    });

    await _dio.post<Map<String, dynamic>>('/children/me/avatar', data: form);
  }

  /// Bog'langan ota-onaning ismi — GET /children/:id/parent.
  /// "Chatlar" ro'yxati va chat header'ida ko'rsatiladi.
  Future<String?> getParentName(String childId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/children/$childId/parent',
    );
    return res.data?['name'] as String?;
  }
}
