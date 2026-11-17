// IQ test providerlari. Manba — server (`ApiIqRepository`, `/api/iq`).
// Hammasi ulangan bolaga bog'langan: boshqa bolaga qayta ulanganda oldingi
// bolaning natijasi ko'rinmaydi. Kirish nuqtalari `iqAvailableProvider`
// bilan yashiriladi (server IQ'ni bilmaydi yoki yosh 9–20 dan tashqarida).

import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/iq/data/api_iq_repository.dart';
import 'package:farzandim_child/features/iq/data/iq_repository.dart';
import 'package:farzandim_child/features/iq/domain/iq_models.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final iqRepositoryProvider = Provider<IqRepository>(
  (ref) => ApiIqRepository(ref.watch(dioClientProvider)),
);

/// Ulangan bolaning `childId`si (`null` — ulanmagan: so'rov ham, UI ham yo'q).
final iqAccountProvider = Provider<String?>(
  (ref) => ref.watch(
    pairingStateProvider.select((s) => s.isPaired ? s.childId : null),
  ),
);

/// Hisob bo'yicha overview; `null` — server IQ testni hali bilmaydi.
final iqOverviewByAccountProvider = FutureProvider.autoDispose
    .family<IqOverview?, String>((ref, account) async {
      try {
        return await ref.watch(iqRepositoryProvider).loadOverview();
      } on IqException catch (e) {
        if (e.code == IqErrorCode.unavailable) return null;
        rethrow;
      }
    });

final iqOverviewProvider = Provider.autoDispose<AsyncValue<IqOverview?>>((ref) {
  final account = ref.watch(iqAccountProvider);
  if (account == null) return const AsyncData(null);
  return ref.watch(iqOverviewByAccountProvider(account));
});

/// Kirish nuqtalari ko'rinadi: yosh `OK` yoki `AGE_REQUIRED` (profilga
/// yo'naltiriladi). Yangilanishda oxirgi ma'lum holat qoladi.
final iqAvailableProvider = Provider.autoDispose<bool>((ref) {
  final overview = ref.watch(iqOverviewProvider).valueOrNull;
  if (overview == null) return false;
  return overview.age.status == IqAgeStatus.ok ||
      overview.age.status == IqAgeStatus.ageRequired;
});

/// Pull-to-refresh / sahifaga qaytish: overview qayta so'raladi (xato
/// bo'lsa jim — UI oxirgi holatni ko'rsatadi).
Future<void> refreshIq(WidgetRef ref) async {
  final account = ref.read(iqAccountProvider);
  if (account == null) return;
  ref.invalidate(iqOverviewByAccountProvider(account));
  try {
    await ref.read(iqOverviewByAccountProvider(account).future);
  } on Object {
    // Xato UI'da (`AsyncError`) ko'rinadi.
  }
}
