// ─────────────────────────────────────────────────────────────────────
// AppVersionInfo — Backend /api/app/version domain model (Sprint 4.4.28)
// ─────────────────────────────────────────────────────────────────────

// ignore_for_file: public_member_api_docs

import 'package:flutter/foundation.dart';

@immutable
class PlatformVersionInfo {
  const PlatformVersionInfo({
    required this.latest,
    required this.minSupported,
    this.playStoreUrl,
    this.appStoreUrl,
    this.directApkUrl,
  });

  factory PlatformVersionInfo.fromJson(Map<String, dynamic> json) {
    return PlatformVersionInfo(
      latest: json['latest'] as String? ?? '0.0.0',
      minSupported: json['minSupported'] as String? ?? '0.0.0',
      playStoreUrl: json['playStoreUrl'] as String?,
      appStoreUrl: json['appStoreUrl'] as String?,
      directApkUrl: json['directApkUrl'] as String?,
    );
  }

  final String latest;
  final String minSupported;
  final String? playStoreUrl;
  final String? appStoreUrl;
  final String? directApkUrl;

  String? get storeUrl => playStoreUrl ?? appStoreUrl;
}

@immutable
class AppVersionInfo {
  const AppVersionInfo({
    required this.android,
    required this.ios,
    required this.releaseNotes,
    this.isForceUpdate = false,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      android: PlatformVersionInfo.fromJson(
        json['android'] as Map<String, dynamic>? ?? const {},
      ),
      ios: PlatformVersionInfo.fromJson(
        json['ios'] as Map<String, dynamic>? ?? const {},
      ),
      releaseNotes: json['releaseNotes'] as String? ?? '',
      isForceUpdate: json['isForceUpdate'] as bool? ?? false,
    );
  }

  final PlatformVersionInfo android;
  final PlatformVersionInfo ios;
  final String releaseNotes;
  final bool isForceUpdate;
}

enum UpdateState {
  unknown,
  upToDate,
  softUpdateAvailable,
  forceUpdateRequired,
}

@immutable
class AppUpdateStatus {
  const AppUpdateStatus({
    required this.state,
    required this.currentVersion,
    this.info,
    this.targetUrl,
  });

  const AppUpdateStatus.unknown(this.currentVersion)
      : state = UpdateState.unknown,
        info = null,
        targetUrl = null;

  final UpdateState state;
  final String currentVersion;
  final AppVersionInfo? info;
  final String? targetUrl;

  bool get needsAttention =>
      state == UpdateState.softUpdateAvailable ||
      state == UpdateState.forceUpdateRequired;
}

int compareSemver(String a, String b) {
  final pa = _parseParts(a);
  final pb = _parseParts(b);
  for (var i = 0; i < 3; i++) {
    if (pa[i] < pb[i]) return -1;
    if (pa[i] > pb[i]) return 1;
  }
  return 0;
}

List<int> _parseParts(String v) {
  final clean = v.split('+').first;
  final parts = clean.split('.').map(int.tryParse).toList();
  while (parts.length < 3) {
    parts.add(0);
  }
  return parts.take(3).map((e) => e ?? 0).toList();
}
