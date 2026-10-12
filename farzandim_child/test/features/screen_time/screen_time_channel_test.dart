import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:farzandim_child/features/screen_time/data/screen_time_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const method = MethodChannel('uz.parvoz.growth/screen_time');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(method, (call) async {
      calls.add(call);
      return {'authorization': 'approved'};
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(method, null);
  });

  test('standart ruxsat .individual rejimini so\'raydi', () async {
    final status = await const ScreenTimeChannel().requestAuthorization();

    expect(calls.single.method, 'requestAuthorization');
    expect(calls.single.arguments, {'mode': 'individual'});
    expect(status.isAuthorized, isTrue);
  });

  test('kuchli himoya .child rejimini so\'raydi', () async {
    await const ScreenTimeChannel().requestAuthorization(strict: true);

    expect(calls.single.arguments, {'mode': 'child'});
  });

  test('native xato kodi ScreenTimeException bo\'lib qaytadi', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(method, (_) async {
      throw PlatformException(code: 'invalidAccountType');
    });

    expect(
      const ScreenTimeChannel().requestAuthorization(strict: true),
      throwsA(isA<ScreenTimeException>()
          .having((e) => e.code, 'code', 'invalidAccountType')),
    );
  });
}
