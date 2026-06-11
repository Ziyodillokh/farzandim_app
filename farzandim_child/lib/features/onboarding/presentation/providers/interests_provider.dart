// ─────────────────────────────────────────────────────────────────────
// InterestsProvider — bola qiziqishlari (Riverpod state)
// ─────────────────────────────────────────────────────────────────────
//
// 2 ta provider:
//   - `childInterestsProvider` — joriy tag ID'lar (List<String>).
//     SharedPreferences `child_interests_pending_v1` yoki `_synced_v1`
//     dan o'qiydi. Pending bo'lsa pending (eng so'nggi tanlov),
//     aks holda synced. App ochilganda + Settings'da yangilangach
//     qayta yangilanadi.
//   - `interestContentTagsProvider` — qiziqish ID'larga mos kontent
//     kategoriya slug'lari (ContentCategory.slug bilan moslashadi).
//     Recommendation providerlari shu set'ga qarab filter qiladi.
//
// Saqlash uchun `saveInterests` extension method bor — backend'ga
// PUT yuboradi va local cache'ni yangilaydi.

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/onboarding/data/interest_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local SharedPreferences'dan bola qiziqishlari. Onboarding tugagach yoki
/// Settings'da yangilangach o'zgaradi. Pending bo'lsa pending'ni qaytaradi
/// (eng so'nggi tanlov backend sync'dan oldin), aks holda synced.
final childInterestsProvider =
    AsyncNotifierProvider<ChildInterestsNotifier, List<String>>(
  ChildInterestsNotifier.new,
);

class ChildInterestsNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    return _read();
  }

  Future<List<String>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(kPendingInterestsKey);
    if (pending != null && pending.isNotEmpty) return pending;
    return prefs.getStringList(kSyncedInterestsKey) ?? const [];
  }

  /// Settings'da o'zgartirish — backend'ga PUT yuboradi va sync'ga
  /// yozadi. Xato bo'lsa pending'ga tushadi (keyingi pair/restart'da
  /// sync.) `interests` — yangi tag ID'lar ro'yxati.
  Future<bool> save(List<String> interests) async {
    state = const AsyncValue.loading();
    final prefs = await SharedPreferences.getInstance();
    try {
      final dio = ref.read(dioClientProvider);
      await dio.put<Map<String, dynamic>>(
        '/children/me/interests',
        data: {'interests': interests},
      );
      await prefs.setStringList(kSyncedInterestsKey, interests);
      await prefs.remove(kPendingInterestsKey);
      state = AsyncValue.data(interests);
      return true;
    } on DioException catch (e) {
      debugPrint('childInterests.save: backend fail (${e.message})');
      // Pending'ga tushiramiz — keyingi restart yoki sync'da qayta urinadi.
      await prefs.setStringList(kPendingInterestsKey, interests);
      state = AsyncValue.data(interests);
      return false;
    } catch (e) {
      debugPrint('childInterests.save: kutilmagan xato: $e');
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }
}

/// Qiziqish ID'laridan ContentCategory.slug'larga oqim (overlap'ni
/// hisoblash uchun). `Set<String>` — tezkor `.contains` uchun.
final interestContentTagsProvider = Provider<Set<String>>((ref) {
  final interests = ref.watch(childInterestsProvider).valueOrNull ?? const [];
  if (interests.isEmpty) return const {};
  final tags = <String>{};
  for (final id in interests) {
    final option = kInterestById[id];
    if (option != null) tags.addAll(option.contentTags);
  }
  return tags;
});
