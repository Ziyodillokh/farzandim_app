// Kirgandan keyin qaysi sahifa: maktabga ulangan oila — Maktab; maktabsiz —
// Nazorat; farzand ham, maktab ham yo'q yangi ota-ona — bir marta «Qanday
// boshlaymiz?».

import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/home/domain/home_landing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maktabga ulangan oila Maktab tabida ochiladi', () {
    for (final hasChildren in [true, false]) {
      expect(
        homeLanding(
          hasChildren: hasChildren,
          hasSchool: true,
          startSeen: false,
        ),
        AppRoutes.school,
      );
    }
  });

  test(
    'maktabsiz oila — Nazorat (hozirgi foydalanuvchilar uchun o`zgarmaydi)',
    () {
      expect(
        homeLanding(hasChildren: true, hasSchool: false, startSeen: false),
        AppRoutes.dashboard,
      );
    },
  );

  test(
    'yangi ota-ona — «Qanday boshlaymiz?», o`tkazib yuborgach takrorlanmaydi',
    () {
      expect(
        homeLanding(hasChildren: false, hasSchool: false, startSeen: false),
        AppRoutes.start,
      );
      expect(
        homeLanding(hasChildren: false, hasSchool: false, startSeen: true),
        AppRoutes.dashboard,
      );
    },
  );
}
