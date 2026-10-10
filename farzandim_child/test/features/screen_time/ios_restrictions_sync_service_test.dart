import 'package:dio/dio.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_device_policy_repository.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_schedule_repository.dart';
import 'package:farzandim_child/features/screen_time/data/ios_restrictions_sync_service.dart';
import 'package:farzandim_child/features/screen_time/data/screen_time_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channel = MethodChannel('uz.parvoz.growth/screen_time');
const _childId = 'child-1';

/// Backend javoblarini soxtalashtiradi: `null` qiymat = tarmoq xatosi.
class _FakeBackend extends Interceptor {
  Object? schedules = {
    'schedules': [
      {
        'id': 's1',
        'startTime': '21:00',
        'endTime': '07:00',
        'daysOfWeek': [1, 2, 3],
        'action': 'BLOCK',
        'isActive': true,
      },
    ],
  };
  Object? devicePolicy = {'blockAllApps': false};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final data = options.path.endsWith('/schedules') ? schedules : devicePolicy;
    if (data == null) {
      handler.reject(DioException(requestOptions: options));
      return;
    }
    handler.resolve(
      Response(requestOptions: options, data: data, statusCode: 200),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeBackend backend;
  late List<Map<Object?, Object?>> applied;
  late IosRestrictionsSyncService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    backend = _FakeBackend();
    applied = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      if (call.method == 'applyPolicy') {
        applied.add(Map<Object?, Object?>.from(call.arguments as Map));
      }
      return {'blocking': false, 'scheduleErrors': <String>[]};
    });
    final dio = Dio()..interceptors.add(backend);
    service = IosRestrictionsSyncService(
      scheduleRepo: BackendScheduleRepository(dio: dio),
      devicePolicyRepo: BackendDevicePolicyRepository(dio: dio),
      channel: const ScreenTimeChannel(_channel),
    );
  });

  tearDown(() {
    service.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  Future<void> startAndSync() async {
    service.start(childId: _childId);
    await service.sync();
  }

  test('jadval va "hammasini bloklash" native siyosatga uzatiladi', () async {
    backend.devicePolicy = {'blockAllApps': true};

    await startAndSync();

    expect(applied.last, {
      'blockAll': true,
      'windows': [
        {'start': 1260, 'end': 420, 'weekdays': [1, 2, 3]},
      ],
    });
  });

  test('jadval kelmasa (tarmoq yo\'q) siyosat o\'zgartirilmaydi', () async {
    backend.schedules = null;

    await startAndSync();

    expect(applied, isEmpty);
  });

  test('qurilma-siyosati yiqilsa oxirgi "hammasini bloklash" saqlanadi',
      () async {
    backend.devicePolicy = {'blockAllApps': true};
    await startAndSync();

    backend.devicePolicy = null;
    await service.sync();

    expect(applied.last['blockAll'], isTrue);
  });

  test('start() dan oldin sync() hech narsa qilmaydi', () async {
    await service.sync();

    expect(applied, isEmpty);
  });
}
