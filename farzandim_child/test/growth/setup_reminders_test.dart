// B01 · Sozlama eslatmalari: yumshoq yangilanish ko'rinadi va «Keyinroq»
// bilan yopiladi; yangilanish bo'lmasa hech narsa chiqmaydi.

import 'package:farzandim_child/features/app_update/data/models/app_version_info.dart';
import 'package:farzandim_child/features/app_update/presentation/providers/app_update_provider.dart';
import 'package:farzandim_child/growth/bugun/widgets/setup_reminders.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'g5_test_app.dart';

const _info = AppVersionInfo(
  android: PlatformVersionInfo(
    latest: '2.1.0',
    minSupported: '1.0.0',
    playStoreUrl: 'https://play.google.com/store/apps/details?id=x',
  ),
  ios: PlatformVersionInfo(latest: '2.1.0', minSupported: '1.0.0'),
  releaseNotes: '',
);

class _FakeUpdate extends AppUpdateNotifier {
  _FakeUpdate(this.initial);

  final UpdateState initial;

  @override
  Future<AppUpdateStatus> build() async => AppUpdateStatus(
    state: initial,
    currentVersion: '2.0.0',
    info: _info,
    targetUrl: 'https://play.google.com/store/apps/details?id=x',
  );
}

Future<void> _pump(WidgetTester tester, UpdateState state) => pumpG5App(
  tester,
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: SetupReminders()),
      ),
    ),
  ],
  initialLocation: '/',
  overrides: [appUpdateProvider.overrideWith(() => _FakeUpdate(state))],
);

void main() {
  setUpAll(setUpG5WidgetTests);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('yangi versiya eslatmasi «Keyinroq» bilan yopiladi', (
    tester,
  ) async {
    await _pump(tester, UpdateState.softUpdateAvailable);
    await settleG5(tester);
    expect(find.text('Ilovaning yangi versiyasi bor (2.1.0).'), findsOneWidget);

    await tester.tap(find.text('Keyinroq'));
    await settleG5(tester);
    expect(find.textContaining('yangi versiyasi'), findsNothing);
  });

  testWidgets('yangilanish yo\'q — eslatma chiqmaydi', (tester) async {
    await _pump(tester, UpdateState.upToDate);
    await settleG5(tester);
    expect(find.textContaining('yangi versiyasi'), findsNothing);
  });
}
