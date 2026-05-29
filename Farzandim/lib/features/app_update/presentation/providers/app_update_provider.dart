// ─────────────────────────────────────────────────────────────────────
// app_update_provider — Parent App version check (Sprint 4.4.28)
// ─────────────────────────────────────────────────────────────────────

// ignore_for_file: public_member_api_docs

import 'dart:io' show Platform;

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
    return _check();
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

    final platform = Platform.isAndroid ? info.android : info.ios;

    final ltMin = compareSemver(current, platform.minSupported) < 0;
    if (info.isForceUpdate || ltMin) {
      return AppUpdateStatus(
        state: UpdateState.forceUpdateRequired,
        currentVersion: current,
        info: info,
        targetUrl: platform.storeUrl ?? platform.directApkUrl,
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
        targetUrl: platform.storeUrl ?? platform.directApkUrl,
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
