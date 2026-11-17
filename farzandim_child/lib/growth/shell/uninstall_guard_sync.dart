// «O'chirishni taqiqlash» (Device Admin): ota-onaning `blockUninstall`
// siyosati qurilmada qo'llanadi. v4 bosh ekranidagi `_syncUninstallProtection`
// eski UI olib tashlanganda (e865e2c6) tushib qolgan edi — ota-onaning
// toggle'i Android'da hech narsa qilmasdi (fn-uninstall-guard-regression).
//
// Ilova ochilganda va har qaytganda siyosat o'qilib qo'llanadi. Faollashtirish
// tizim dialogi (Activity kerak — faqat UI) sessiyada ko'pi bilan BIR MARTA:
// bola rad etsa ham qayta-qayta chiqmaydi. O'chirish (ota-ona himoyani bekor
// qilsa) har doim dialogsiz. Bola admin'ni o'chirgani haqidagi bayroqni
// o'qish va ota-onaga xabar — fon isolate'ining ishi (BackgroundJobs).

import 'dart:async';
import 'dart:io' show Platform;

import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_device_policy_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/uninstall_protection_service.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/shell_ready_gate.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/growth/kirish/data/account_scope.dart';
import 'package:farzandim_child/growth/shell/uninstall_guard_syncer.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Faqat haqiqiy Android qurilmada (Device Admin bor). Widget testlarida xost
/// OS — o'chiq: qobiq testlari tarmoqqa chiqmaydi.
final uninstallGuardEnabledProvider = Provider<bool>(
  (_) => !kIsWeb && Platform.isAndroid,
);

/// Sessiya bo'yi bitta sinxronchi (qurilma egasining konteynerida).
final uninstallGuardSyncerProvider = Provider<UninstallGuardSyncer>((ref) {
  Future<bool?> readPolicy(String childId) async {
    final policy = await ref
        .read(backendDevicePolicyRepositoryProvider)
        .getDevicePolicy(childId);
    return policy.blockUninstall;
  }

  return UninstallGuardSyncer(
    readPolicy: readPolicy,
    isActive: uninstallProtectionService.isActive,
    apply: uninstallProtectionService.apply,
  );
});

/// Qobiq ochilganda va ilovaga har qaytilganda siyosatni qo'llaydi.
class UninstallGuardSync extends ConsumerStatefulWidget {
  const UninstallGuardSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UninstallGuardSync> createState() => _UninstallGuardSyncState();
}

class _UninstallGuardSyncState extends ConsumerState<UninstallGuardSync>
    with WidgetsBindingObserver {
  late final bool _enabled = ref.read(uninstallGuardEnabledProvider);

  @override
  void initState() {
    super.initState();
    if (!_enabled) return;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_sync()));
  }

  @override
  void dispose() {
    if (_enabled) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_sync());
  }

  Future<void> _sync() async {
    if (!mounted) return;
    // Mehmon akkaunt ochiq — siyosat qurilma egasiniki, egasining
    // konteynerida qo'llanadi.
    if (ref.read(activeGuestProvider) != null) return;
    final pairing = ref.read(pairingStateProvider);
    final childId = pairing.childId;
    if (!pairing.isPaired || childId == null || childId.isEmpty) return;
    final syncer = ref.read(uninstallGuardSyncerProvider);
    final gate = ref.read(shellReadyGateProvider);
    // Tizim dialogi PIN qulfi ostida chiqmasin — qulf ochilishini kutamiz.
    if (!await gate.waitUntilReady() || !mounted) return;
    try {
      await syncer.sync(childId);
    } on Object catch (e) {
      debugPrint('[uninstall-guard] siyosat qo\'llanmadi: ${e.runtimeType}');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
