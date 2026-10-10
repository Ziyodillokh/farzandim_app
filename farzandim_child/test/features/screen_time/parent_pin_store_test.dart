import 'package:farzandim_child/features/screen_time/data/parent_pin_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  late ParentPinStore store;

  ParentPinStore newStore() => ParentPinStore(clock: () => now);

  setUp(() {
    // O'rnatish belgisi bor — "yangi o'rnatish" tozalashi ishlamaydi.
    SharedPreferences.setMockInitialValues({'screenTime.installMarker.v1': true});
    FlutterSecureStorage.setMockInitialValues({});
    now = DateTime(2026, 10, 10, 12);
    store = newStore();
  });

  test('PIN formati — faqat 4 ta raqam', () {
    expect(ParentPinStore.isValidFormat('1234'), isTrue);
    expect(ParentPinStore.isValidFormat('123'), isFalse);
    expect(ParentPinStore.isValidFormat('12345'), isFalse);
    expect(ParentPinStore.isValidFormat('12a4'), isFalse);
  });

  test('noto\'g\'ri formatdagi PIN saqlanmaydi', () async {
    await expectLater(store.setPin('12'), throwsArgumentError);
    expect(await store.hasPin(), isFalse);
  });

  test('o\'rnatilgan PIN tekshiriladi', () async {
    await store.setPin('2580');

    expect(await store.hasPin(), isTrue);
    expect(await store.verify('2580'), PinCheckResult.ok);
    expect(await store.verify('0000'), PinCheckResult.wrong);
  });

  test('5 ta xatodan keyin 5 daqiqa bloklanadi, keyin yana ishlaydi', () async {
    await store.setPin('2580');
    for (var i = 1; i < ParentPinStore.maxAttempts; i++) {
      expect(await store.verify('1111'), PinCheckResult.wrong);
    }
    expect(await store.verify('1111'), PinCheckResult.locked);
    // Bloklangan paytda to'g'ri PIN ham qabul qilinmaydi.
    expect(await store.verify('2580'), PinCheckResult.locked);
    expect(await store.lockRemaining(), ParentPinStore.lockDuration);

    now = now.add(ParentPinStore.lockDuration);

    expect(await store.lockRemaining(), isNull);
    expect(await store.verify('2580'), PinCheckResult.ok);
  });

  test('to\'g\'ri PIN xatolar hisobini nolga tushiradi', () async {
    await store.setPin('2580');
    for (var i = 1; i < ParentPinStore.maxAttempts; i++) {
      await store.verify('1111');
    }
    expect(await store.verify('2580'), PinCheckResult.ok);

    expect(await store.verify('1111'), PinCheckResult.wrong);
  });

  test('yangi o\'rnatishda Keychain\'da qolgan eski PIN o\'chiriladi', () async {
    FlutterSecureStorage.setMockInitialValues({
      'screenTime.parentPin.v1': '2580',
    });
    SharedPreferences.setMockInitialValues({});

    expect(await newStore().hasPin(), isFalse);
  });

  test('clear() PIN\'ni o\'chiradi (uzish)', () async {
    await store.setPin('2580');

    await store.clear();

    expect(await store.hasPin(), isFalse);
  });
}
