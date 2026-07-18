// Bola DON tarixi (ota-ona ko'radi) — `/children/:childId/xp-events` (don > 0).

import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/features/don_history/data/models/don_history_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Berilgan bolaning DON tarixi (eng yangi birinchi). Ota-ona o'z farzandi
/// uchun so'raydi (backend `validateChildAccess` — parentId mos kelishi shart).
final donHistoryProvider = FutureProvider.autoDispose
    .family<List<DonHistoryEntry>, String>((ref, childId) async {
      if (childId.isEmpty) return const <DonHistoryEntry>[];
      final dio = ref.read(dioClientProvider);
      final res = await dio.get<Map<String, dynamic>>(
        '/children/$childId/xp-events',
        queryParameters: <String, dynamic>{'limit': 200},
      );
      final raw = (res.data?['events'] as List?) ?? const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(DonHistoryEntry.fromJson)
          .where((e) => e.don > 0)
          .toList();
    });
