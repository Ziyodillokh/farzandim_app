// Ota-ona ilovasi yangilash-aniqlash mantiqi (Sprint 4.4.28).
//
// "Ota-onaga yangilash kelmayapti" muammosi ikki qismdan iborat edi:
//   1. Provider soft-update'ni to'g'ri aniqlaydimi (bu test), va
//   2. Banner dashboardga ulanganmi (UI — dashboard_screen.dart).
// Bu test 1-qismni pinlaydi: latest > current bo'lsa softUpdateAvailable,
// teng bo'lsa upToDate, minSupported'dan past bo'lsa forceUpdateRequired.

import 'package:dio/dio.dart';
import 'package:farzandim/features/app_update/data/models/app_version_info.dart';
import 'package:farzandim/features/app_update/data/repositories/backend_app_version_repository.dart';
import 'package:farzandim/features/app_update/presentation/providers/app_update_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Backend'ni taqlid qiladi — `fetch()` belgilangan versiyani qaytaradi.
class _FakeVersionRepo extends BackendAppVersionRepository {
  _FakeVersionRepo(this._info) : super(dio: Dio());

  final AppVersionInfo? _info;

  @override
  Future<AppVersionInfo?> fetch() async => _info;
}

AppVersionInfo _info({
  required String latest,
  required String minSupported,
  bool isForceUpdate = false,
  String? directApkUrl = 'https://farzandimedu.uz/app/farzandim-parent.apk',
}) {
  final platform = PlatformVersionInfo(
    latest: latest,
    minSupported: minSupported,
    directApkUrl: directApkUrl,
  );
  return AppVersionInfo(
    android: platform,
    ios: platform,
    releaseNotes: 'Yangi imkoniyatlar',
    isForceUpdate: isForceUpdate,
  );
}

Future<AppUpdateStatus> _resolve(AppVersionInfo? info) async {
  final container = ProviderContainer(
    overrides: [
      backendAppVersionRepositoryProvider.overrideWithValue(
        _FakeVersionRepo(info),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container.read(appUpdateProvider.future);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Joriy o'rnatilgan versiya = 1.0.0.
    PackageInfo.setMockInitialValues(
      appName: 'Parvoz Parents',
      packageName: 'com.farzandim',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    SharedPreferences.setMockInitialValues({});
    // `_check` android tarmog'ini ishlatsin (host qanday bo'lishidan qat'i).
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('latest > current → softUpdateAvailable + APK targetUrl', () async {
    final status = await _resolve(
      _info(latest: '1.2.0', minSupported: '1.0.0'),
    );
    expect(status.state, UpdateState.softUpdateAvailable);
    expect(status.currentVersion, '1.0.0');
    expect(
      status.targetUrl,
      'https://farzandimedu.uz/app/farzandim-parent.apk',
      reason: "do'kon URL yo'q → directApkUrl ishlatilishi shart",
    );
  });

  test('latest == current → upToDate (banner ko`rinmaydi)', () async {
    final status = await _resolve(
      _info(latest: '1.0.0', minSupported: '1.0.0'),
    );
    expect(status.state, UpdateState.upToDate);
  });

  test('current < minSupported → forceUpdateRequired', () async {
    final status = await _resolve(
      _info(latest: '2.0.0', minSupported: '1.5.0'),
    );
    expect(status.state, UpdateState.forceUpdateRequired);
    expect(status.targetUrl, isNotNull);
  });

  test('isForceUpdate flag → forceUpdateRequired (latest teng bo`lsa ham)',
      () async {
    final status = await _resolve(
      _info(latest: '1.0.0', minSupported: '1.0.0', isForceUpdate: true),
    );
    expect(status.state, UpdateState.forceUpdateRequired);
  });

  test('backend null qaytarsa → unknown (crash yo`q)', () async {
    final status = await _resolve(null);
    expect(status.state, UpdateState.unknown);
    expect(status.currentVersion, '1.0.0');
  });
}
