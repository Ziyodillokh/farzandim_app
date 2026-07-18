// Bola DON tarixi — backend `/children/:childId/xp-events` (don > 0).

import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/don_history/data/models/don_history_entry.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bolaning O'Z DON tarixi (eng yangi birinchi). Ekran ochilganda so'raladi.
final donHistoryProvider =
    FutureProvider.autoDispose<List<DonHistoryEntry>>((ref) async {
  final childId = ref.watch(pairingStateProvider).childId;
  if (childId == null || childId.isEmpty) return const <DonHistoryEntry>[];

  final dio = ref.read(dioClientProvider);
  final res = await dio.get<Map<String, dynamic>>(
    '/children/$childId/xp-events',
    queryParameters: <String, dynamic>{'limit': 200},
  );
  final raw = (res.data?['events'] as List?) ?? const [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map(DonHistoryEntry.fromJson)
      .where((e) => e.don > 0) // faqat DON kelgan yozuvlar
      .toList();
});
