// ─────────────────────────────────────────────────────────────────────
// child_data_provider — Dashboard data providerlari (Sprint 4.4.9)
// ─────────────────────────────────────────────────────────────────────
//
// Eski: Firestore `users/{parentUid}/children/{childId}` doc'idan
//   real-time stream o'qigan.
// Yangi: Backend `GET /api/children/:id` (Child JWT bilan) — Future,
//   real-time o'rniga refreshable. Pairing tugagach bola ma'lumotlari
//   Backend'dan to'la keladi (name, age, region, family_code, photoPath).

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/core/config/env_config.dart';
import 'package:farzandim_child/core/network/dio_client.dart';

typedef ChildKey = ({String parentUid, String childId});

/// Bola ma'lumotlarini Backend'dan oladi (`GET /api/children/:childId`).
///
/// `parentUid` parametri eski signature uchun saqlanadi (UI joylarida
/// pairing.parentUid + pairing.childId bilan chaqiriladi). Backend
/// chaqirishda foydalanilmaydi — auth JWT'da child o'zi mavjud.
///
/// 404 yoki tarmoq xato → null (UI default fallback ko'rsatadi).
final childDataStreamProvider =
    FutureProvider.family<Map<String, dynamic>?, ChildKey>((ref, params) async {
      final dio = ref.watch(dioClientProvider);
      try {
        final response = await dio.get<Map<String, dynamic>>(
          '/children/${params.childId}',
        );
        return response.data;
      } on DioException {
        return null;
      }
    });

/// Ota-ona ma'lumotlari. Sprint 4.4.9'da Backend'da hali alohida
/// `/api/users/:id` (parent) endpoint yo'q — fairy null qaytariladi.
/// Kelajakda Backend `GET /api/users/:id` qo'shilsa shu yerga ulanadi.
final parentInfoProvider = FutureProvider.family<Map<String, dynamic>?, String>(
  (ref, parentUid) async {
    // Backend'da hozircha bola o'z parent ma'lumotini olishi uchun
    // endpoint yo'q (faqat /users/me o'zining ma'lumoti). Null qaytaramiz —
    // UI "Ota-ona" default label ko'rsatadi.
    return null;
  },
);

/// Bola rasmi URL — Parent App yoki bola o'zi yuklagan
/// (`POST /children/:id/avatar` yoki `/children/me/avatar`).
///
/// Avval `GET /:id/avatar` orqali rasm BORLIGINI tekshiramiz (404 → yo'q).
/// Rasm bo'lsa, MinIO signed URL o'rniga ICHKI PROXY URL'ni qaytaramiz:
///   GET /children/:id/avatar/image  (ommaviy, backend MinIO'dan stream qiladi)
/// Bu web va telefon'da bir xil ishlaydi — signed URL'ning MinIO host
/// reachability muammosi (127.0.0.1:9000 telefon'dan ko'rinmaydi) bartaraf.
///
/// `?t=` cache-bust — rasm yangilangach `ref.invalidate` qilinsa, Image
/// keshdan emas, yangi rasmni yuklaydi.
///
/// 404 (photo yo'q) → null → fallback Icon.person.
final childAvatarUrlProvider = FutureProvider.family<String?, String>((
  ref,
  childId,
) async {
  final dio = ref.watch(dioClientProvider);
  try {
    // Rasm mavjudligini tekshirish (auth bilan). 404 → DioException → null.
    await dio.get<Map<String, dynamic>>('/children/$childId/avatar');
    final bust = DateTime.now().millisecondsSinceEpoch;
    return '${EnvConfig.apiUrl}/children/$childId/avatar/image?t=$bust';
  } on DioException {
    return null;
  }
});
