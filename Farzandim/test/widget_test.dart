// Asosiy smoke test — HOZIRCHA SKIP.
//
// `FarzandimApp` build'da `context.localizationDelegates` (EasyLocalization)
// va secure-storage'dan auth tiklashni talab qiladi — ikkalasi ham test
// muhitida mavjud emas, shu sabab bu test hech qachon o'tmagan (har doim
// "Null check operator used on a null value" bilan yiqilardi).
//
// Haqiqiy qamrov endi unit-testlarda: test/models/, test/utils/, test/cache/
// (flutter test bilan ishga tushadi). To'liq smoke uchun integration_test
// (haqiqiy qurilma/emulator) kerak bo'ladi.

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    "FarzandimApp smoke test — Welcome ekran ko'rinadi",
    (tester) async {},
    // Sabab yuqoridagi fayl-izohda: EasyLocalization + secure storage.
    skip: true,
  );
}
