import 'package:dio/dio.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_device_policy_repository.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/restrictions_sync_provider.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/usage_providers.dart';
import 'package:farzandim_child/features/background/data/services/background_service.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_schedule_repository.dart';
import 'package:farzandim_child/features/screen_time/data/ios_restrictions_sync_service.dart';
import 'package:farzandim_child/features/screen_time/data/screen_time_channel.dart';
import 'package:farzandim_child/features/screen_time/presentation/providers/screen_time_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _foregroundTaskChannel = MethodChannel('flutter_foreground_task/methods');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('iOS: ilovalar usage sync servisi yaratilmaydi (Apple sharti)', () {
    // pairingStateProvider'ga umuman tegilmasligi kerak — aks holda bu
    // konteynerda Firebase/secure storage talab qilinib test yiqilardi.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(usageSyncServiceProvider), isNull);
  });

  test('iOS: cheklov sinxronizatsiyasi Family Controls servisi bo\'ladi', () {
    final dio = Dio();
    final container = ProviderContainer(
      overrides: [
        backendScheduleRepositoryProvider.overrideWithValue(
          BackendScheduleRepository(dio: dio),
        ),
        backendDevicePolicyRepositoryProvider.overrideWithValue(
          BackendDevicePolicyRepository(dio: dio),
        ),
        screenTimeChannelProvider.overrideWithValue(const ScreenTimeChannel()),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(restrictionsSyncServiceProvider),
      isA<IosRestrictionsSyncService>(),
    );
  });

  test('iOS: BackgroundService foreground-task kanaliga murojaat qilmaydi',
      () async {
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_foregroundTaskChannel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(_foregroundTaskChannel, null),
    );

    BackgroundService.init();
    await BackgroundService().start();
    await BackgroundService().stop();

    expect(calls, isEmpty);
  });
}
