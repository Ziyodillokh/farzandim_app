// ─────────────────────────────────────────────────────────────────────
// InterestsSyncService — onboarding tag'larini backend'ga jo'natish
// ─────────────────────────────────────────────────────────────────────
//
// Onboarding'da bola tanlagan qiziqishlar SharedPreferences
// `child_interests_pending_v1` ga yoziladi (chunki bola hali pair
// bo'lmagan, JWT yo'q).
//
// Pairing tugagach (yoki QR re-pair tugagach) `PairingNotifier`
// shu service'ni chaqiradi → PUT /api/children/me/interests yuboriladi.
// Muvaffaqiyatli bo'lsa pending tozalanadi va `child_interests_synced_v1`
// ga ko'chiriladi (profile/dashboard local'dan o'qiy oladi).

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim_child/features/onboarding/data/interest_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

final interestsSyncServiceProvider = Provider<InterestsSyncService>((ref) {
  return InterestsSyncService(dio: ref.read(dioClientProvider));
});

class InterestsSyncService {
  InterestsSyncService({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// Pending interests bo'lsa backend'ga yuboradi. Idempotent —
  /// pending bo'sh bo'lsa hech nima qilmaydi. Pairing tugagach
  /// (CHILD JWT mavjud bo'lganda) chaqirilishi kerak.
  Future<void> syncPendingInterests() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(kPendingInterestsKey);
    if (pending == null || pending.isEmpty) return;

    try {
      await _dio.put<Map<String, dynamic>>(
        '/children/me/interests',
        data: {'interests': pending},
      );
      // Muvaffaqiyatli — pending'ni synced ga ko'chiramiz.
      await prefs.setStringList(kSyncedInterestsKey, pending);
      await prefs.remove(kPendingInterestsKey);
      debugPrint(
        'InterestsSync: ${pending.length} ta tag muvaffaqiyatli yuborildi',
      );
    } on DioException catch (e) {
      // Tarmoq xatosi — pending qoldiradi, keyingi pairing yoki
      // app restart'da qayta urinadi.
      debugPrint('InterestsSync: yuborilmadi (${e.message}) — keyin qayta');
    } catch (e) {
      debugPrint('InterestsSync: kutilmagan xato: $e');
    }
  }

  /// Local cache'dan o'qish (profile/dashboard'da chip ko'rsatish uchun).
  /// Pending bor bo'lsa pending'ni qaytaradi (eng so'nggi tanlov).
  static Future<List<String>> readLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(kPendingInterestsKey);
    if (pending != null && pending.isNotEmpty) return pending;
    return prefs.getStringList(kSyncedInterestsKey) ?? const [];
  }
}
