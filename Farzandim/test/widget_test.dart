// Asosiy smoke test — ilova xatosiz quriladimi va Welcome ekran
// to'g'ri ko'rsatiladimi tekshiradi.
//
// Buni ishga tushirish:  flutter test

import 'package:farzandim/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    "FarzandimApp smoke test — Welcome ekran ko'rinadi",
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: FarzandimApp(),
        ),
      );

      // Welcome ekrandagi sarlavha topilishi kerak.
      expect(find.text('Hush kelibsiz'), findsOneWidget);

      // Ikkala tugma ham mavjud bo'lishi kerak.
      expect(find.text("Ro'yxatdan o'tish"), findsOneWidget);
      expect(find.text('Akkauntga kirish'), findsOneWidget);
    },
  );
}
