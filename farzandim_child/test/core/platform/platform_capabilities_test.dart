import 'package:farzandim_child/core/platform/platform_capabilities.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('iOS: Android nazorat to\'plami va usage yuborish o\'chiq', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    expect(PlatformCapabilities.isIOS, isTrue);
    expect(PlatformCapabilities.isAndroid, isFalse);
    expect(PlatformCapabilities.hasAndroidControls, isFalse);
    expect(PlatformCapabilities.canUploadAppUsage, isFalse);
    expect(PlatformCapabilities.hasAppUsageStats, isFalse);
    expect(PlatformCapabilities.hasForegroundService, isFalse);
    expect(PlatformCapabilities.hasHealthConnect, isFalse);
    expect(PlatformCapabilities.permissionsAreBlocking, isFalse);
  });

  test('Android: avvalgi xatti-harakat o\'zgarmagan', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(PlatformCapabilities.isIOS, isFalse);
    expect(PlatformCapabilities.isAndroid, isTrue);
    expect(PlatformCapabilities.hasAndroidControls, isTrue);
    expect(PlatformCapabilities.canUploadAppUsage, isTrue);
    expect(PlatformCapabilities.hasAppUsageStats, isTrue);
    expect(PlatformCapabilities.hasForegroundService, isTrue);
    expect(PlatformCapabilities.hasHealthConnect, isTrue);
    expect(PlatformCapabilities.permissionsAreBlocking, isTrue);
  });
}
