import 'package:flutter_test/flutter_test.dart';

import 'package:farzandim_child/features/permissions/data/oem_background_service.dart';

void main() {
  group('shouldNudgeAutostart', () {
    test('avtozapusk ekrani bor, tasdiqlanmagan, eslatilmagan → bir marta ochiladi', () {
      expect(
        shouldNudgeAutostart(hasAutostartScreen: true, confirmed: false, alreadyNudged: false),
        isTrue,
      );
    });

    test('tasdiqlangan yoki allaqachon eslatilgan bo\'lsa qayta ochilmaydi', () {
      expect(
        shouldNudgeAutostart(hasAutostartScreen: true, confirmed: true, alreadyNudged: false),
        isFalse,
      );
      expect(
        shouldNudgeAutostart(hasAutostartScreen: true, confirmed: false, alreadyNudged: true),
        isFalse,
      );
    });

    test('ekrani yo\'q telefon (Pixel, plugin yo\'q, iOS) — hech qachon', () {
      expect(
        shouldNudgeAutostart(hasAutostartScreen: false, confirmed: false, alreadyNudged: false),
        isFalse,
      );
    });
  });
}
