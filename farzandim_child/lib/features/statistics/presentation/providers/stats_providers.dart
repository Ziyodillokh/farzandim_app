// ─────────────────────────────────────────────────────────────────────
// stats_providers — Statistika sahifasi uchun backend ma'lumotlari
// ─────────────────────────────────────────────────────────────────────
//
// `developmentSummaryProvider` — haftalik o'qilgan kitoblar / ishlangan
//   testlar soni (GET /children/:id/development-summary, gamification).
// `hourlyUsageProvider` — bugungi soatlik ekran vaqti [24 ta ms]
//   (GET /children/:id/app-usage/hourly). Backend sync deltalaridan
//   o'zi hisoblaydi — qurilma hech narsa o'zgartirmaydi.
// `postBookReadEvent` — kitob/audiokitob tugatilganda BOOK_READ XP
//   eventi (+50 XP, dev-summary'dagi kitoblar soniga kiradi).

import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Haftalik rivojlanish yig'indisi (kitoblar/testlar real soni).
typedef DevSummary = ({int booksRead, int testsCompleted});

final developmentSummaryProvider = FutureProvider.autoDispose<DevSummary?>((
  ref,
) async {
  final childId = ref.watch(pairingStateProvider).childId;
  if (childId == null) return null;
  try {
    final res = await ref
        .read(dioClientProvider)
        .get<Map<String, dynamic>>(
          '/children/$childId/development-summary',
          queryParameters: {'range': 'weekly'},
        );
    final d = res.data ?? const {};
    return (
      booksRead: (d['booksRead'] as num?)?.toInt() ?? 0,
      testsCompleted: (d['testsCompleted'] as num?)?.toInt() ?? 0,
    );
  } catch (e) {
    debugPrint('developmentSummary xato: $e');
    return null;
  }
});

/// Bugungi soatlik ekran vaqti — [24] ms. Ma'lumot yo'q bo'lsa null.
final hourlyUsageProvider = FutureProvider.autoDispose<List<int>?>((ref) async {
  final childId = ref.watch(pairingStateProvider).childId;
  if (childId == null) return null;
  try {
    final res = await ref
        .read(dioClientProvider)
        .get<Map<String, dynamic>>('/children/$childId/app-usage/hourly');
    final raw = res.data?['hours'] as List<dynamic>? ?? const [];
    final hours = raw.map((e) => (e as num).toInt()).toList();
    if (hours.length != 24) return null;
    return hours;
  } catch (e) {
    debugPrint('hourlyUsage xato: $e');
    return null;
  }
});

/// Kitob/audiokitob tugatilganda chaqiriladigan BOOK_READ yuboruvchi.
/// Ishlatish: `ref.read(bookReadEventProvider)();`
final bookReadEventProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final childId = ref.read(pairingStateProvider).childId;
    if (childId == null) return;
    try {
      await ref
          .read(dioClientProvider)
          .post<Map<String, dynamic>>(
            '/children/$childId/xp-events',
            data: {'type': 'BOOK_READ', 'xpDelta': 50},
          );
      ref.invalidate(developmentSummaryProvider);
    } catch (e) {
      debugPrint('BOOK_READ event xato: $e');
    }
  };
});
