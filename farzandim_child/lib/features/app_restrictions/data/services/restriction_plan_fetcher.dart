// ─────────────────────────────────────────────────────────────────────
// RestrictionPlanFetcher — backend manbalaridan bitta RestrictionPlan
// ─────────────────────────────────────────────────────────────────────
//
// Beshta GET parallel (bitta umumiy ulanish): jadval oynalari, ilova
// limitlari, jadvallar (School Mode ham), qurilma siyosati, faol qo'shimcha
// vaqt. Uch asosiy ro'yxatdan biri kelmasa — `null` ("bilmayman", "cheklov
// yo'q" EMAS). Qurilma siyosati / grant'lar alohida yiqilsa — oxirgi
// rejadagi qiymat saqlanadi (tarmoq uzilishida bloklash o'chib qolmasin).

import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_app_limit_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_device_policy_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_unlock_request_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/restriction_plan.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_routine_repository.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_schedule_repository.dart';

class RestrictionPlanFetcher {
  RestrictionPlanFetcher({
    required BackendScheduleRepository scheduleRepo,
    required BackendAppLimitRepository appLimitRepo,
    required BackendRoutineRepository routineRepo,
    required BackendDevicePolicyRepository devicePolicyRepo,
    BackendUnlockRequestRepository? unlockRepo,
  }) : _scheduleRepo = scheduleRepo,
       _appLimitRepo = appLimitRepo,
       _routineRepo = routineRepo,
       _devicePolicyRepo = devicePolicyRepo,
       _unlockRepo = unlockRepo;

  final BackendScheduleRepository _scheduleRepo;
  final BackendAppLimitRepository _appLimitRepo;
  final BackendRoutineRepository _routineRepo;
  final BackendDevicePolicyRepository _devicePolicyRepo;

  /// `null` — grant'lar so'ralmaydi (oxirgi rejadagisi saqlanadi).
  final BackendUnlockRequestRepository? _unlockRepo;

  /// [cached] — oxirgi reja (siyosat/grant zaxirasi), [legacyBlockAll] — eski
  /// versiya keshi, [planDay] — bugungi Toshkent kuni (ishonchli soat).
  Future<RestrictionPlan?> fetch(
    String childId, {
    required RestrictionPlan? cached,
    required bool legacyBlockAll,
    required String Function() planDay,
  }) async {
    final unlockRepo = _unlockRepo;
    final (policies, limits, routines, policy, grants) = await (
      _scheduleRepo.getSchedules(childId),
      _appLimitRepo.getLimits(childId),
      _routineRepo.getRoutines(childId),
      _devicePolicyRepo.getDevicePolicy(childId),
      unlockRepo == null
          ? Future<List<ActiveUnlockGrant>?>.value()
          : unlockRepo.getActiveGrants(),
    ).wait;
    if (policies == null || limits == null || routines == null) return null;

    // AppLimit: to'liq blok (dailyLimitMs == 0) va vaqt cheklovi.
    final fullBlocks = <String>[];
    final limitEntries = <String>[];
    for (final l in limits) {
      if (!l.isActive || l.packageName.isEmpty) continue;
      if (l.isFullBlock) {
        fullBlocks.add(l.packageName);
      } else if (l.dailyLimitMinutes > 0) {
        limitEntries.add('${l.packageName}:${l.dailyLimitMinutes}');
      }
    }
    return RestrictionPlan(
      fullBlocks: fullBlocks,
      limitEntries: limitEntries,
      policies: policies,
      routines: routines,
      blockAll: policy.blockAllApps ?? cached?.blockAll ?? legacyBlockAll,
      // Tarmoq javobidan KEYIN — ishonchli soat `Date` sarlavhasidan yangilangan.
      planDay: planDay(),
      grants: grants == null
          ? (cached?.grants ?? const [])
          : toPlanGrants(grants),
      blockUnknown: policy.blockUnknownSources ?? cached?.blockUnknown,
      blockUninstall: policy.blockUninstall ?? cached?.blockUninstall,
    );
  }

  /// Faqat ilovaga berilgan ('APP') grant'lar; ekran-vaqti grant'i paketsiz.
  static List<PlanGrant> toPlanGrants(List<ActiveUnlockGrant> grants) => [
    for (final g in grants)
      if ((g.kind == null || g.kind == 'APP') && g.packageName != null)
        PlanGrant(
          packageName: g.packageName!,
          expiresAtMs: g.expiresAt.millisecondsSinceEpoch,
        ),
  ];
}
