// ─────────────────────────────────────────────────────────────────────
// app_update_provider — Parent App version check (Sprint 4.4.28)
// ─────────────────────────────────────────────────────────────────────

import 'package:farzandim/features/app_update/data/models/app_version_info.dart';
import 'package:farzandim/features/app_update/data/repositories/backend_app_version_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsDismissPrefix = 'update.dismissed.';
const _dismissTtl = Duration(hours: 24);

final appUpdateProvider =
    AsyncNotifierProvider<AppUpdateNotifier, AppUpdateStatus>(
      AppUpdateNotifier.new,
    );

class AppUpdateNotifier extends AsyncNotifier<AppUpdateStatus> {
  @override
  Future<AppUpdateStatus> build() async {
    try {
      return await _check();
    } catch (e, st) {
      debugPrint('AppUpdate.build xato: $e\n$st');
      final pkg = await PackageInfo.fromPlatform();
      return AppUpdateStatus.unknown(pkg.version);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_check);
  }

  Future<AppUpdateStatus> _check() async {
    final pkg = await PackageInfo.fromPlatform();
    final current = pkg.version;

    final info = await ref.read(backendAppVersionRepositoryProvider).fetch();
    if (info == null) {
      return AppUpdateStatus.unknown(current);
    }

    // Web'da dart:io Platform UnsupportedError tashlaydi — kIsWeb bilan himoya.
    // Web build Android APK'ni directApkUrl orqali tarqatadi → web'ni
    // android deb olamiz.
    final isAndroid = kIsWeb || defaultTargetPlatform == TargetPlatform.android;
    final platform = isAndroid ? info.android : info.ios;

    // ⚠️ `targetUrl` — Google Play DDA 4.5-bandi buzilishi sababli (bola
    // ilovasi uchun 2026-08-04 rad etish xati, xuddi shu naqsh) NATIV
    // Android/iOS ilova endi FAQAT `storeUrl`ga o'tadi, `directApkUrl`ga
    // hech qachon EMAS — Play-tarqatiladigan APK/AAB o'z ichida Play
    // tashqarisiga APK havolasi tutmasin.
    //
    // ⚠️ MUHIM FARQ — WEB build (`kIsWeb`) bundan MUSTASNO: bu — Play'ga
    // yuborilgan ilova emas, balki bizning O'Z SAYTIMIZ (farzandimedu.uz)
    // dagi yuklab olish sahifasi — uning butun vazifasi aynan APK'ni
    // to'g'ridan-to'g'ri tarqatish (Play'siz o'rnatmoqchi bo'lganlar uchun).
    // Bu yerda DDA 4.5 qo'llanilmaydi (u faqat Play'ga topshirilgan
    // paket ICHIDAGI kodga tegishli), shuning uchun web'da `directApkUrl`
    // zaxira sifatida SAQLANADI.
    final targetUrl = kIsWeb
        ? (platform.storeUrl ?? platform.directApkUrl)
        : platform.storeUrl;

    final ltMin = compareSemver(current, platform.minSupported) < 0;
    if (info.isForceUpdate || ltMin) {
      return AppUpdateStatus(
        state: UpdateState.forceUpdateRequired,
        currentVersion: current,
        info: info,
        targetUrl: targetUrl,
      );
    }

    final ltLatest = compareSemver(current, platform.latest) < 0;
    if (ltLatest) {
      final dismissed = await _isDismissed(platform.latest);
      if (dismissed) {
        return AppUpdateStatus(
          state: UpdateState.upToDate,
          currentVersion: current,
          info: info,
        );
      }
      return AppUpdateStatus(
        state: UpdateState.softUpdateAvailable,
        currentVersion: current,
        info: info,
        targetUrl: targetUrl,
      );
    }

    return AppUpdateStatus(
      state: UpdateState.upToDate,
      currentVersion: current,
      info: info,
    );
  }

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
