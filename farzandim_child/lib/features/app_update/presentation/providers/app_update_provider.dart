// ─────────────────────────────────────────────────────────────────────
// app_update_provider — Backend version check + dashboard banner state
// (Sprint 4.4.28)
// ─────────────────────────────────────────────────────────────────────
//
// AsyncNotifier pattern: app startup paytida `check()` chaqiriladi,
// natija Riverpod orqali UI'ga taqsimlanadi. Dashboard'dagi
// `UpdateBanner` `appUpdateProvider`'ni watch qilib `softUpdateAvailable`
// bo'lsa ko'rsatadi. App'ning ildiz widget'i `forceUpdateRequired`
// bo'lsa modal dialog'ni ochadi.
//
// Dismiss throttle: foydalanuvchi banner'ni × bossa, shu versiya uchun
// 24 soat ko'rinmaydi (SharedPreferences `update.dismissed.{version}`).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farzandim_child/core/platform/platform_capabilities.dart';
import 'package:farzandim_child/features/app_update/data/models/app_version_info.dart';
import 'package:farzandim_child/features/app_update/data/repositories/backend_app_version_repository.dart';
import 'package:farzandim_child/features/app_update/domain/update_decision.dart';

const _prefsDismissPrefix = 'update.dismissed.';
const _dismissTtl = Duration(hours: 24);

final appUpdateProvider =
    AsyncNotifierProvider<AppUpdateNotifier, AppUpdateStatus>(
      AppUpdateNotifier.new,
    );

class AppUpdateNotifier extends AsyncNotifier<AppUpdateStatus> {
  @override
  Future<AppUpdateStatus> build() async {
    return _check();
  }

  /// App startup yoki dashboard ochilganda qayta tekshirish.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_check);
  }

  Future<AppUpdateStatus> _check() async {
    final pkg = await PackageInfo.fromPlatform();
    final current = pkg.version;

    final info = await ref.read(backendAppVersionRepositoryProvider).fetch();
    if (info == null) {
      // Tarmoq xatosi yoki Backend yo'q — silent skip.
      return AppUpdateStatus.unknown(current);
    }

    // Web preview — do'kon yo'q, yangilanish ko'rsatilmaydi.
    if (kIsWeb) return AppUpdateStatus.unknown(current);

    // ⚠️ `targetUrl` FAQAT `storeUrl` (Play Market/App Store) — Google Play
    // DDA 4.5-bandi buzilishi sababli (2026-08-04 rad etish xati)
    // `directApkUrl` zaxira sifatida ham ISHLATILMAYDI. Backend
    // `playStoreUrl`ni to'ldirishi SHART (docs/PLAY_STORE_CHECKLIST.md).
    // iOS: faqat iOS ma'lumoti va haqiqiy App Store havolasi bo'lsa
    // (App Review 2.1 — ishlamaydigan "Yangilash" tugmasi rad etiladi);
    // umumiy (Android) `isForceUpdate` iOS'ni bloklamaydi.
    final decision = decideUpdate(
      currentVersion: current,
      info: info,
      isIOS: PlatformCapabilities.isIOS,
    );

    if (decision.state == UpdateState.softUpdateAvailable) {
      final latest = PlatformCapabilities.isIOS
          ? info.ios.latest
          : info.android.latest;
      if (await _isDismissed(latest)) {
        return AppUpdateStatus(
          state: UpdateState.upToDate,
          currentVersion: current,
          info: info,
        );
      }
    }

    return AppUpdateStatus(
      state: decision.state,
      currentVersion: current,
      info: info,
      targetUrl: decision.targetUrl,
      releaseNotes: decision.releaseNotes,
    );
  }

  /// Soft banner'ni 24 soatga yopish.
  Future<void> dismissSoftUpdate(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      '$_prefsDismissPrefix$version',
      DateTime.now().millisecondsSinceEpoch,
    );
    final current = state.valueOrNull;
    if (current != null && current.state == UpdateState.softUpdateAvailable) {
      state = AsyncValue.data(
        AppUpdateStatus(
          state: UpdateState.upToDate,
          currentVersion: current.currentVersion,
          info: current.info,
        ),
      );
    }
  }

  Future<bool> _isDismissed(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getInt('$_prefsDismissPrefix$version');
      if (stored == null) return false;
      final dismissedAt = DateTime.fromMillisecondsSinceEpoch(stored);
      final age = DateTime.now().difference(dismissedAt);
      return age < _dismissTtl;
    } catch (e) {
      debugPrint('AppUpdate._isDismissed xato: $e');
      return false;
    }
  }
}
