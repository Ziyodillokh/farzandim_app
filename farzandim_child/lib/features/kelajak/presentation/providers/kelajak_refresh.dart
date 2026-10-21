// Pastga tortib yangilash / ilovaga qaytish: Kelajak ma'lumotlari serverdan
// qayta yuklanadi (bosh sahifa, Testlar, Rivojlanish va hub shu bilan).

import 'package:farzandim_child/features/kelajak/data/kelajak_repository.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_providers.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_results_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Overview, rivojlanish va natijalar qayta so'raladi. Ekranda overview
/// kuzatilayotgan bo'lsa — u yuklanguncha kutiladi (indikator uchun); tarmoq
/// xatosi indikatorni to'xtatmaydi — oxirgi ma'lum holat qoladi.
Future<void> refreshKelajak(WidgetRef ref) async {
  final account = ref.read(kelajakAccountProvider);
  if (account == null) return;
  final overview = kelajakOverviewByAccountProvider(account);
  final isWatched = ref.exists(overview);
  ref
    ..invalidate(kelajakOverviewByAccountProvider)
    ..invalidate(kelajakProgressProvider)
    ..invalidate(kelajakResultsProvider);
  if (!isWatched) return;
  try {
    await ref.read(overview.future);
  } on KelajakException {
    // Oflayn — kartalar avvalgi holatda qoladi.
  }
}
