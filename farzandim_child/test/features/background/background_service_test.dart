// BackgroundService.cacheNotifStrings: tarjima yuklanmagan bo'lsa (qiymat ==
// kalit) HECH NARSA saqlanmaydi; eski xato yozuv (xom kalit) tozalanadi;
// taymer/har daqiqalik shablon kaliti olib tashlanadi.

import 'package:farzandim_child/features/background/data/services/background_service.dart';
import 'package:farzandim_child/features/background/data/services/background_task_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Map<String, Object?>> stored() async {
    final prefs = await SharedPreferences.getInstance();
    return {for (final k in prefs.getKeys()) k: prefs.get(k)};
  }

  test(
    'tarjima yo\'q — hech qanday qiymat kalitga teng bo\'lib saqlanmaydi',
    () async {
      SharedPreferences.setMockInitialValues({});

      await BackgroundService.cacheNotifStrings(translate: (key) => key);

      expect(await stored(), isEmpty);
    },
  );

  test('tarjima bor — saqlanadi; eski xom kalitlar tozalanadi', () async {
    SharedPreferences.setMockInitialValues({
      'restriction.i18n.blocked': 'blockScreen.blocked',
      'bg.notifTitle': 'background.notificationTitle',
      BackgroundTaskConfig.legacyLastUpdateKey: 'background.lastUpdate',
    });
    const translations = {
      'background.notificationTitle': 'Parvoz ishlayapti',
      'background.channelName': 'Parvoz xizmati',
      'blockScreen.ok': 'OK',
      'blockScreen.schoolSub': '{time} dan keyin ochiladi.',
    };

    await BackgroundService.cacheNotifStrings(
      translate: (key) => translations[key] ?? key,
    );

    final values = await stored();
    expect(values, {
      'bg.notifTitle': 'Parvoz ishlayapti',
      'bg.channelName': 'Parvoz xizmati',
      'restriction.i18n.ok': 'OK',
      'restriction.i18n.schoolSub': '{time} dan keyin ochiladi.',
    });
    for (final entry in values.entries) {
      expect(entry.value, isNot(startsWith('blockScreen.')));
      expect(entry.value, isNot(startsWith('background.')));
    }
  });

  test(
    'foreground service sozlamasi: doimiy WakeLock/WifiLock yo\'q, 5 daq',
    () {
      final options = BackgroundTaskConfig.taskOptions;

      expect(options.allowWakeLock, isFalse);
      expect(options.allowWifiLock, isFalse);
      expect(options.eventAction.interval, 5 * 60 * 1000);
      expect(options.autoRunOnBoot, isTrue);
    },
  );
}
