import 'package:farzandim_child/features/app_update/data/models/app_version_info.dart';
import 'package:farzandim_child/features/app_update/domain/update_decision.dart';
import 'package:flutter_test/flutter_test.dart';

const _appStoreUrl = 'https://apps.apple.com/app/id1234567890';
const _playUrl =
    'https://play.google.com/store/apps/details?id=com.farzandim.growth';

AppVersionInfo _info({
  bool isForceUpdate = false,
  String releaseNotes = 'Android 16 qo\'llab-quvvatlanadi',
  PlatformVersionInfo? ios,
  PlatformVersionInfo? android,
}) {
  return AppVersionInfo(
    android:
        android ??
        const PlatformVersionInfo(
          latest: '1.0.7',
          minSupported: '1.0.0',
          playStoreUrl: _playUrl,
        ),
    ios:
        ios ??
        const PlatformVersionInfo(latest: '1.0.0', minSupported: '1.0.0'),
    releaseNotes: releaseNotes,
    isForceUpdate: isForceUpdate,
  );
}

void main() {
  group('validAppStoreUrl', () {
    test('accepts https App Store links only', () {
      expect(validAppStoreUrl(_appStoreUrl), _appStoreUrl);
      expect(validAppStoreUrl('http://apps.apple.com/app/id1'), isNull);
      expect(validAppStoreUrl(_playUrl), isNull);
      expect(validAppStoreUrl(''), isNull);
      expect(validAppStoreUrl(null), isNull);
    });
  });

  group('iOS', () {
    test('never forces or shows a banner without an App Store URL', () {
      final decision = decideUpdate(
        currentVersion: '1.0.0',
        info: _info(
          isForceUpdate: true,
          ios: const PlatformVersionInfo(
            latest: '2.0.0',
            minSupported: '1.5.0',
            isForceUpdate: true,
          ),
        ),
        isIOS: true,
      );

      expect(decision.state, UpdateState.upToDate);
    });

    test('ignores the shared Android force flag', () {
      final decision = decideUpdate(
        currentVersion: '1.0.0',
        info: _info(
          isForceUpdate: true,
          ios: const PlatformVersionInfo(
            latest: '1.0.0',
            minSupported: '1.0.0',
            appStoreUrl: _appStoreUrl,
          ),
        ),
        isIOS: true,
      );

      expect(decision.state, UpdateState.upToDate);
    });

    test('iOS force flag does not lock the newest version', () {
      final decision = decideUpdate(
        currentVersion: '1.2.0',
        info: _info(
          ios: const PlatformVersionInfo(
            latest: '1.2.0',
            minSupported: '1.0.0',
            appStoreUrl: _appStoreUrl,
            isForceUpdate: true,
          ),
        ),
        isIOS: true,
      );

      expect(decision.state, UpdateState.upToDate);
    });

    test('forces below minSupported with the iOS notes and URL', () {
      final decision = decideUpdate(
        currentVersion: '1.0.0',
        info: _info(
          ios: const PlatformVersionInfo(
            latest: '1.3.0',
            minSupported: '1.1.0',
            appStoreUrl: _appStoreUrl,
            releaseNotes: 'iOS fixes',
          ),
        ),
        isIOS: true,
      );

      expect(decision.state, UpdateState.forceUpdateRequired);
      expect(decision.targetUrl, _appStoreUrl);
      expect(decision.releaseNotes, 'iOS fixes');
    });

    test('soft update never shows the shared (Android) notes', () {
      final decision = decideUpdate(
        currentVersion: '1.0.0',
        info: _info(
          ios: const PlatformVersionInfo(
            latest: '1.1.0',
            minSupported: '1.0.0',
            appStoreUrl: _appStoreUrl,
          ),
        ),
        isIOS: true,
      );

      expect(decision.state, UpdateState.softUpdateAvailable);
      expect(decision.releaseNotes, isEmpty);
    });
  });

  group('Android (unchanged)', () {
    test('shared force flag forces the update', () {
      final decision = decideUpdate(
        currentVersion: '1.0.7',
        info: _info(isForceUpdate: true),
        isIOS: false,
      );

      expect(decision.state, UpdateState.forceUpdateRequired);
      expect(decision.targetUrl, _playUrl);
    });

    test('below latest shows the soft banner with shared notes', () {
      final decision = decideUpdate(
        currentVersion: '1.0.5',
        info: _info(),
        isIOS: false,
      );

      expect(decision.state, UpdateState.softUpdateAvailable);
      expect(decision.releaseNotes, 'Android 16 qo\'llab-quvvatlanadi');
    });

    test('latest version is up to date', () {
      final decision = decideUpdate(
        currentVersion: '1.0.7',
        info: _info(),
        isIOS: false,
      );

      expect(decision.state, UpdateState.upToDate);
    });
  });

  test('parses per-platform force flag and notes', () {
    final info = AppVersionInfo.fromJson({
      'android': {'latest': '1.0.7', 'minSupported': '1.0.0'},
      'ios': {
        'latest': '1.1.0',
        'minSupported': '1.0.0',
        'isForceUpdate': true,
        'releaseNotes': 'iOS',
      },
      'releaseNotes': 'shared',
      'isForceUpdate': false,
    });

    expect(info.ios.isForceUpdate, isTrue);
    expect(info.ios.releaseNotes, 'iOS');
    expect(info.android.isForceUpdate, isNull);
  });
}
