// Ruxsatlar ekrani: «Avtomatik ishga tushish» (OEM autostart) qatori faqat
// shunday ekrani bor telefonda, batareya qatoridan keyin chiqadi; sozlamadan
// qaytgach «Yoqdim» tasdig'i saqlanadi; onboarding'ni to'xtatmaydi
// (kill-native-no-oem-autostart).

import 'package:farzandim_child/features/permissions/data/oem_background_service.dart';
import 'package:farzandim_child/features/permissions/presentation/screens/permission_setup_screen.dart';
import 'package:farzandim_child/features/permissions/presentation/widgets/permission_setup_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../growth/g5_test_app.dart';

const _oemChannel = MethodChannel('farzandim/oem_background');
const _permissionChannel = MethodChannel(
  'flutter.baseflow.com/permissions/methods',
);
const _usageChannel = MethodChannel('farzandim/usage_stats');

const _autostart = 'Avtomatik ishga tushish';
const _battery = 'Quvvatni optimallashtirmaslik';
const _uninstall = "O'chirishni taqiqlash";
const _askTitle = 'Avtomatik ishga tushish yoqildimi?';

/// OEM kanali: `info` va `openAutostart` chaqiruvlarini yozib boradi.
class _FakeOem {
  _FakeOem({this.hasScreen = true, this.opens = true});

  final bool hasScreen;
  final bool opens;
  final calls = <String>[];

  Future<Object?> handle(MethodCall call) async {
    calls.add(call.method);
    return switch (call.method) {
      'info' => <String, Object?>{
        'manufacturer': 'Xiaomi',
        'brand': 'Redmi',
        'hasAutostartScreen': hasScreen,
        'ignoringBatteryOptimizations': true,
      },
      'openAutostart' => opens,
      _ => null,
    };
  }
}

Future<void> _pumpScreen(WidgetTester tester) async {
  await pumpG5App(
    tester,
    size: const Size(390, 1000),
    routes: [
      GoRoute(path: '/p', builder: (_, _) => const PermissionSetupScreen()),
    ],
    initialLocation: '/p',
  );
}

void _mock(WidgetTester tester, MethodChannel channel, _Handler? handler) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    channel,
    handler,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    ),
  );
}

typedef _Handler = Future<Object?>? Function(MethodCall call);

Finder _toggleOf(String title) => find.descendant(
  of: find.widgetWithText(PermRow, title),
  matching: find.byType(PermToggle),
);

/// Ilova sozlamaga o'tib, qaytdi.
Future<void> _leaveAndReturn(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await settleG5(tester);
}

void main() {
  setUpAll(setUpG5WidgetTests);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('OEM ekrani yo\'q telefonda qator ko\'rinmaydi', (tester) async {
    final oem = _FakeOem(hasScreen: false);
    _mock(tester, _oemChannel, oem.handle);
    await _pumpScreen(tester);

    expect(find.text(_battery), findsOneWidget);
    expect(find.text(_autostart), findsNothing);
    expect(oem.calls, ['info']);
  });

  testWidgets('native yordamchi yo\'q (eski build) — qator ko\'rinmaydi', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.text(_battery), findsOneWidget);
    expect(find.text(_autostart), findsNothing);
  });

  testWidgets(
    'qator batareyadan keyin; sozlamadan qaytgach «Yoqdim» saqlanadi',
    (tester) async {
      final oem = _FakeOem();
      _mock(tester, _oemChannel, oem.handle);
      await _pumpScreen(tester);

      final batteryY = tester.getCenter(find.text(_battery)).dy;
      final autostartY = tester.getCenter(find.text(_autostart)).dy;
      final uninstallY = tester.getCenter(find.text(_uninstall)).dy;
      expect(autostartY, greaterThan(batteryY));
      expect(autostartY, lessThan(uninstallY));
      expect(tester.widget<PermToggle>(_toggleOf(_autostart)).value, isFalse);

      await tester.tap(_toggleOf(_autostart));
      await settleG5(tester);
      expect(oem.calls, contains('openAutostart'));
      // Sozlama ochiq — savol hali yo'q (bola qaytgach so'raladi).
      expect(find.text(_askTitle), findsNothing);

      await _leaveAndReturn(tester);
      expect(find.text(_askTitle), findsOneWidget);
      await tester.tap(find.text('Yoqdim'));
      await settleG5(tester);

      expect(find.text(_askTitle), findsNothing);
      expect(tester.widget<PermToggle>(_toggleOf(_autostart)).value, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kOemAutostartConfirmedKey), isTrue);

      // Keyingi qaytishda qayta so'ralmaydi.
      await _leaveAndReturn(tester);
      expect(find.text(_askTitle), findsNothing);
    },
  );

  testWidgets('«Hali yo\'q» — tasdiq saqlanmaydi', (tester) async {
    final oem = _FakeOem();
    _mock(tester, _oemChannel, oem.handle);
    await _pumpScreen(tester);

    await tester.tap(_toggleOf(_autostart));
    await settleG5(tester);
    await _leaveAndReturn(tester);
    await tester.tap(find.text("Hali yo'q"));
    await settleG5(tester);

    expect(tester.widget<PermToggle>(_toggleOf(_autostart)).value, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(kOemAutostartConfirmedKey), isNull);
  });

  testWidgets('sozlama ochilmasa — darhol so\'raladi', (tester) async {
    final oem = _FakeOem(opens: false);
    _mock(tester, _oemChannel, oem.handle);
    await _pumpScreen(tester);

    await tester.tap(_toggleOf(_autostart));
    await settleG5(tester);

    expect(find.text(_askTitle), findsOneWidget);
  });

  testWidgets('avval tasdiqlangan — qator bajarilgan holda', (tester) async {
    SharedPreferences.setMockInitialValues({kOemAutostartConfirmedKey: true});
    final oem = _FakeOem();
    _mock(tester, _oemChannel, oem.handle);
    await _pumpScreen(tester);

    expect(tester.widget<PermToggle>(_toggleOf(_autostart)).value, isTrue);
  });

  testWidgets('tasdiqlanmagan autostart «Keyingisi»ni to\'xtatmaydi', (
    tester,
  ) async {
    final oem = _FakeOem();
    _mock(tester, _oemChannel, oem.handle);
    // Majburiy ruxsatlarning hammasi berilgan.
    _mock(tester, _permissionChannel, (call) async => 1);
    _mock(tester, _usageChannel, (call) async => true);
    await _pumpScreen(tester);

    expect(find.text(_autostart), findsOneWidget);
    expect(tester.widget<PermToggle>(_toggleOf(_autostart)).value, isFalse);
    expect(
      tester.widget<PermNextButton>(find.byType(PermNextButton)).enabled,
      isTrue,
    );
  });
}
