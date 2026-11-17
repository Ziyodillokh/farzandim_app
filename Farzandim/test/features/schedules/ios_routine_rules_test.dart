// iPhone rejim qoidalari — oyna davomiyligi (yarim tundan o'tish bilan),
// 15 daqiqa chegarasi va `blockedApps` yordamchilari.

import 'package:farzandim/core/utils/app_brand.dart';
import 'package:farzandim/features/schedules/data/models/ios_routine_rules.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';

void main() {
  int minutes(int sh, int sm, int eh, int em) => routineWindowMinutes(
    startHour: sh,
    startMinute: sm,
    endHour: eh,
    endMinute: em,
  );

  bool valid(int sh, int sm, int eh, int em) => isRoutineWindowValidForIos(
    startHour: sh,
    startMinute: sm,
    endHour: eh,
    endMinute: em,
  );

  group('routineWindowMinutes', () {
    test('oddiy oyna 08:00 → 14:00 = 360 daqiqa', () {
      expect(minutes(8, 0, 14, 0), 360);
    });

    test('yarim tundan o`tuvchi oyna 22:00 → 07:00 = 540 daqiqa', () {
      expect(minutes(22, 0, 7, 0), 540);
    });

    test('yarim tundan oldin 23:50 → 00:10 = 20 daqiqa', () {
      expect(minutes(23, 50, 0, 10), 20);
    });

    test('daqiqalar hisobga olinadi 10:15 → 10:45 = 30', () {
      expect(minutes(10, 15, 10, 45), 30);
    });

    test('boshlanish == tugash → 0 (bola ilovasi ham bloklamaydi)', () {
      expect(minutes(9, 30, 9, 30), 0);
    });
  });

  group('isRoutineWindowValidForIos (>= 15 daqiqa)', () {
    test('aynan 15 daqiqa → yaroqli', () {
      expect(valid(10, 0, 10, 15), isTrue);
    });

    test('14 daqiqa → yaroqsiz', () {
      expect(valid(10, 0, 10, 14), isFalse);
    });

    test('yarim tundan o`tuvchi 5 daqiqa (23:58 → 00:03) → yaroqsiz', () {
      expect(valid(23, 58, 0, 3), isFalse);
    });

    test('yarim tundan o`tuvchi uzun oyna (22:00 → 07:00) → yaroqli', () {
      expect(valid(22, 0, 7, 0), isTrue);
    });

    test('boshlanish == tugash → yaroqsiz', () {
      expect(valid(8, 0, 8, 0), isFalse);
    });

    test('chegara konstantasi 15', () {
      expect(kIosMinRoutineWindowMinutes, 15);
    });
  });

  group('iosRoutineBlockedApps / routineBlocksIosApps', () {
    test('bloklash yoqilgan → faqat virtual iPhone yozuvi', () {
      expect(iosRoutineBlockedApps(block: true), [kIosSelectionPackage]);
    });

    test('bloklash o`chirilgan → bo`sh ro`yxat', () {
      expect(iosRoutineBlockedApps(block: false), isEmpty);
    });

    test('routineBlocksIosApps: yozuv bor → true', () {
      expect(
        routineBlocksIosApps(['com.whatsapp', kIosSelectionPackage]),
        isTrue,
      );
    });

    test('routineBlocksIosApps: yozuv yo`q / bo`sh → false', () {
      expect(routineBlocksIosApps(const ['com.whatsapp']), isFalse);
      expect(routineBlocksIosApps(const []), isFalse);
    });

    test('kIosSelectionPackage qiymati bola ilovasi bilan mos', () {
      expect(kIosSelectionPackage, 'uz.parvoz.growth.ios-selected-apps');
    });
  });

  group('app_brand: iPhone yozuvi', () {
    test('xom nom bo`lmasa brend nomi "iPhone"', () {
      expect(friendlyAppName(kIosSelectionPackage), 'iPhone');
    });

    test('bola yuborgan nom (tilida) birinchi o`rinda', () {
      expect(
        friendlyAppName(
          kIosSelectionPackage,
          'iPhone: tanlangan ilovalar · 2 ta ilova',
        ),
        'iPhone: tanlangan ilovalar · 2 ta ilova',
      );
    });

    test('avatar rangi — belgilangan brend rangi', () {
      expect(appAvatarColor(kIosSelectionPackage), const Color(0xFF1C1C1E));
    });
  });
}
