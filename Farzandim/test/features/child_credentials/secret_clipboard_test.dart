// SecretClipboard: nusxalangan maxfiy matn (parol) ~90 s dan keyin buferdan
// tozalanadi — faqat bufer hamon shu matnni ushlab turgan bo'lsa; oddiy
// nusxalash (login) tegilmaydi; o'qib bo'lmasa yoki xato bo'lsa jimgina
// o'tkazib yuboriladi; taymer ilova tugaganda (dispose) to'xtaydi.

import 'package:farzandim/features/child_credentials/data/secret_clipboard.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Platforma buferining soxta ko'rinishi.
class _FakePlatformClipboard {
  _FakePlatformClipboard(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            final args = call.arguments as Map<Object?, Object?>;
            text = args['text']! as String;
            writes.add(text!);
          case 'Clipboard.getData':
            reads++;
            if (readError != null) throw readError!;
            // Fonda (Android 10+) o'qib bo'lmaydi: javob `null`.
            return readable && text != null
                ? <String, Object?>{'text': text}
                : null;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
  }

  String? text;
  final List<String> writes = [];
  int reads = 0;
  bool readable = true;
  PlatformException? readError;
}

Future<void> _elapse(WidgetTester tester, Duration duration) async {
  await tester.pump(duration);
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('maxfiy matn TTL dan keyin tozalanadi (89 s — hali yo`q)', (
    tester,
  ) async {
    final platform = _FakePlatformClipboard(tester);
    final clipboard = SecretClipboard();
    addTearDown(clipboard.dispose);

    await clipboard.copySecret('k7m2xq9p');
    await _elapse(tester, const Duration(seconds: 89));
    expect(platform.text, 'k7m2xq9p');
    expect(platform.reads, 0);

    await _elapse(tester, const Duration(seconds: 2));
    expect(platform.text, isEmpty);
    expect(platform.reads, 1);
  });

  testWidgets('TTL sozlanadi', (tester) async {
    final platform = _FakePlatformClipboard(tester);
    final clipboard = SecretClipboard(ttl: const Duration(seconds: 5));
    addTearDown(clipboard.dispose);

    await clipboard.copySecret('k7m2xq9p');
    await _elapse(tester, const Duration(seconds: 6));

    expect(platform.text, isEmpty);
  });

  testWidgets('oddiy nusxalash (login) hech qachon tozalanmaydi', (
    tester,
  ) async {
    final platform = _FakePlatformClipboard(tester);
    final clipboard = SecretClipboard();
    addTearDown(clipboard.dispose);

    await clipboard.copy('aziza.k24');
    await _elapse(tester, const Duration(minutes: 10));

    expect(platform.text, 'aziza.k24');
    expect(platform.reads, 0);
  });

  testWidgets('boshqa matn nusxalangan bo`lsa tegilmaydi', (tester) async {
    final platform = _FakePlatformClipboard(tester);
    final clipboard = SecretClipboard();
    addTearDown(clipboard.dispose);

    await clipboard.copySecret('k7m2xq9p');
    platform.text = 'boshqa matn';
    await _elapse(tester, const Duration(seconds: 100));

    expect(platform.text, 'boshqa matn');
    expect(platform.writes, ['k7m2xq9p']);
  });

  testWidgets('bufer o`qilmasa (fon) — jimgina o`tkazib yuboriladi', (
    tester,
  ) async {
    final platform = _FakePlatformClipboard(tester)..readable = false;
    final clipboard = SecretClipboard();
    addTearDown(clipboard.dispose);

    await clipboard.copySecret('k7m2xq9p');
    await _elapse(tester, const Duration(seconds: 100));

    // O'qib bo'lmadi: begona matnni bosib ketmaymiz.
    expect(platform.reads, 1);
    expect(platform.writes, ['k7m2xq9p']);
  });

  testWidgets('o`qishda platforma xatosi ilovani qulatmaydi', (tester) async {
    final platform = _FakePlatformClipboard(tester)
      ..readError = PlatformException(code: 'denied');
    final clipboard = SecretClipboard();
    addTearDown(clipboard.dispose);

    await clipboard.copySecret('k7m2xq9p');
    await _elapse(tester, const Duration(seconds: 100));

    expect(platform.reads, 1);
    expect(platform.text, 'k7m2xq9p');
  });

  testWidgets('yangi nusxa vaqtni qayta boshlaydi', (tester) async {
    final platform = _FakePlatformClipboard(tester);
    final clipboard = SecretClipboard();
    addTearDown(clipboard.dispose);

    await clipboard.copySecret('k7m2xq9p');
    await _elapse(tester, const Duration(seconds: 60));
    await clipboard.copySecret('k7m2xq9p');
    await _elapse(tester, const Duration(seconds: 60));
    expect(platform.text, 'k7m2xq9p');

    await _elapse(tester, const Duration(seconds: 31));
    expect(platform.text, isEmpty);
  });

  testWidgets('dispose taymerni to`xtatadi (tozalash bo`lmaydi)', (
    tester,
  ) async {
    final platform = _FakePlatformClipboard(tester);
    final clipboard = SecretClipboard();

    await clipboard.copySecret('k7m2xq9p');
    clipboard.dispose();
    await _elapse(tester, const Duration(minutes: 5));

    expect(platform.text, 'k7m2xq9p');
    expect(platform.reads, 0);
  });
}
