import 'package:farzandim_child/features/app_restrictions/data/services/health_steps_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// permission_handler platform kanali va `Permission.sensors` kodi (= 12),
/// `PermissionStatus` kodlari: 0 denied, 1 granted.
const _permissionChannel = MethodChannel(
  'flutter.baseflow.com/permissions/methods',
);
const _motionChannel = MethodChannel('uz.parvoz.growth/motion');
const _sensorsPermissionCode = 12;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> motionCalls;
  late int sensorsStatus;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    HealthStepsService.instance.debugReset();
    motionCalls = [];
    sensorsStatus = 1;

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_permissionChannel, (call) async {
      if (call.method == 'checkPermissionStatus' &&
          call.arguments == _sensorsPermissionCode) {
        return sensorsStatus;
      }
      return 0;
    });
    messenger.setMockMethodCallHandler(_motionChannel, (call) async {
      motionCalls.add(call);
      return switch (call.method) {
        'isAvailable' => true,
        'stepsBetween' => 1234,
        _ => null,
      };
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_permissionChannel, null);
    messenger.setMockMethodCallHandler(_motionChannel, null);
  });

  test('iOS: bugungi qadam CoreMotion\'dan, Toshkent yarim tunidan', () async {
    final steps = await HealthStepsService.instance.stepsForToday();

    expect(steps, 1234);
    final query = motionCalls.singleWhere((c) => c.method == 'stepsBetween');
    final args = Map<String, Object?>.from(query.arguments as Map);
    final startMs = args['startMs']! as int;
    final endMs = args['endMs']! as int;
    expect(startMs, lessThan(endMs));
    // Boshlanish UTC+5 yarim tuniga to'g'ri keladi.
    const dayMs = Duration.millisecondsPerDay;
    const tashkentOffsetMs = 5 * Duration.millisecondsPerHour;
    expect((startMs + tashkentOffsetMs) % dayMs, 0);
    expect(endMs - startMs, lessThanOrEqualTo(dayMs));
  });

  test('iOS: Motion ruxsati yo\'q bo\'lsa null va so\'rov yuborilmaydi',
      () async {
    sensorsStatus = 0;

    final steps = await HealthStepsService.instance.stepsForToday();

    expect(steps, isNull);
    expect(motionCalls.where((c) => c.method == 'stepsBetween'), isEmpty);
  });

  test('iOS: native xato bo\'lsa null (pedometer fallback ishlaydi)',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_motionChannel, (call) async {
      if (call.method == 'isAvailable') return true;
      throw PlatformException(code: 'query_failed');
    });

    final steps = await HealthStepsService.instance.stepsForToday();

    expect(steps, isNull);
  });
}
