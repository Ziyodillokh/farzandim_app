// ─────────────────────────────────────────────────────────────────────
// Parvoz Kelajak providerlari
// ─────────────────────────────────────────────────────────────────────
//
// Manba — server (`ApiKelajakRepository`, `/api/kelajak`). Hammasi ulangan
// bolaga bog'langan (`kelajakAccountProvider`): boshqa bolaga qayta
// ulanganda oldingi bolaning profili va qo'llab-quvvatlash xabari (yangisi
// yuklanayotganda ham) ko'rinmaydi. Kirish nuqtalari
// `kelajakAvailableProvider` bilan yashiriladi: server Kelajakni hali
// bilmaydi (404, kodsiz) yoki yosh 7–18 oralig'ida emas.

import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/kelajak/data/api_kelajak_repository.dart';
import 'package:farzandim_child/features/kelajak/data/kelajak_repository.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_overview.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_progress.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_types.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final kelajakRepositoryProvider = Provider<KelajakRepository>(
  (ref) => ApiKelajakRepository(ref.watch(dioClientProvider)),
);

/// Kelajak ma'lumoti tegishli hisob — ulangan bolaning `childId`si
/// (`null` — ulanmagan: so'rov ham, UI ham yo'q).
final kelajakAccountProvider = Provider<String?>(
  (ref) => ref.watch(
    pairingStateProvider.select((s) => s.isPaired ? s.childId : null),
  ),
);

/// Hisob bo'yicha overview — har bola uchun alohida nusxa, shuning uchun
/// boshqa bolaga o'tilganda oldingisining ma'lumoti "eski qiymat" bo'lib
/// qolmaydi. `null` — server Kelajakni hali bilmaydi (404, kodsiz).
final kelajakOverviewByAccountProvider = FutureProvider.autoDispose
    .family<KelajakOverview?, String>((ref, account) async {
      try {
        return await ref.watch(kelajakRepositoryProvider).loadOverview();
      } on KelajakException catch (e) {
        if (e.code == KelajakErrorCode.unavailable) return null;
        rethrow;
      }
    });

/// Joriy bolaning overview'i: yosh holati, bugungi testlar, kategoriyalar
/// va profil (`null` — ulanmagan yoki Kelajak serverda yo'q).
final kelajakOverviewProvider =
    Provider.autoDispose<AsyncValue<KelajakOverview?>>((ref) {
      final account = ref.watch(kelajakAccountProvider);
      if (account == null) return const AsyncData(null);
      return ref.watch(kelajakOverviewByAccountProvider(account));
    });

/// Kelajak kirish nuqtalari ko'rinadi: overview yuklangan va yosh `OK` yoki
/// `AGE_REQUIRED` (bola profilida yosh kiritishga yo'naltiriladi). Server
/// Kelajakni bilmasa, yosh oraliqdan tashqarida yoki hali hech narsa
/// yuklanmagan bo'lsa — yashirin. Yangilanishda oxirgi ma'lum holat qoladi.
final kelajakAvailableProvider = Provider.autoDispose<bool>((ref) {
  final overview = ref.watch(kelajakOverviewProvider).valueOrNull;
  if (overview == null) return false;
  return switch (overview.age.status) {
    KelajakAgeStatus.ok || KelajakAgeStatus.ageRequired => true,
    KelajakAgeStatus.ageOutOfRange || KelajakAgeStatus.unknown => false,
  };
});

/// Rivojlanish: kategoriya va qiziqishlar o'zgarishi, tarix ("Rivojlanish"
/// sahifasidagi "Kelajak profilim" bo'limi uchun).
final kelajakProgressProvider = FutureProvider.autoDispose<KelajakProgress>((
  ref,
) {
  final account = ref.watch(kelajakAccountProvider);
  if (account == null) {
    throw const KelajakException(KelajakErrorCode.unavailable);
  }
  return ref.watch(kelajakRepositoryProvider).loadProgress();
});
