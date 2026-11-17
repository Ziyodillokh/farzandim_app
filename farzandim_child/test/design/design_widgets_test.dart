// Dizayn tizimi vidjetlari: review topilmalari uchun regressiya testlari.

import 'package:farzandim_child/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {double width = 300}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(width: width, child: child),
    ),
  ),
);

void main() {
  testWidgets('GCodeField onCompleted faqat bir marta chaqiriladi', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final completed = <String>[];
    final changed = <String>[];
    await tester.pumpWidget(
      _host(
        GCodeField(
          semanticLabel: 'Maktab kodi',
          controller: controller,
          onChanged: changed.add,
          onCompleted: completed.add,
        ),
      ),
    );

    controller.text = '047215';
    await tester.pump();
    // Faqat kursor/tanlov o'zgarishi — matn o'sha.
    controller.selection = const TextSelection.collapsed(offset: 2);
    controller.selection = const TextSelection.collapsed(offset: 6);
    await tester.pump();

    expect(completed, ['047215']);
    expect(changed, ['047215']);
  });

  testWidgets('GCodeField uzoq bosilganda buferdagi raqamlarni joylaydi', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': 'Kod: 04-72-15 99'};
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
    final completed = <String>[];
    await tester.pumpWidget(
      _host(
        GCodeField(semanticLabel: 'Maktab kodi', onCompleted: completed.add),
      ),
    );

    await tester.longPress(find.byType(GCodeField));
    await tester.pump();

    expect(completed, ['047215']);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets(
    'o\'chirilgan GCodeField: faqat o\'qiladi, joylashtirmaydi, xiralashadi',
    (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? <String, dynamic>{'text': '047215'}
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final handle = tester.ensureSemantics();
      final completed = <String>[];
      await tester.pumpWidget(
        _host(
          GCodeField(
            semanticLabel: 'Maktab kodi',
            enabled: false,
            onCompleted: completed.add,
          ),
        ),
      );

      await tester.longPress(find.byType(GCodeField));
      await tester.pump();

      expect(completed, isEmpty);
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      final cells = tester.widget<AnimatedOpacity>(
        find.descendant(
          of: find.byType(GCodeField),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(cells.opacity, lessThan(1));
      expect(
        tester.getSemantics(find.byType(GCodeField)),
        isSemantics(label: 'Maktab kodi', isReadOnly: true, isEnabled: false),
      );
      handle.dispose();
    },
  );

  testWidgets('yoqilgan GCodeField kataklari to\'liq ko\'rinadi', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const GCodeField(semanticLabel: 'Kod')));

    final cells = tester.widget<AnimatedOpacity>(
      find.descendant(
        of: find.byType(GCodeField),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(cells.opacity, 1);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isFalse);
  });

  testWidgets('GProgressBar ota kengligini to\'liq egallaydi', (tester) async {
    await tester.pumpWidget(
      _host(
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [GProgressBar(value: 1 / 3)],
        ),
      ),
    );

    expect(tester.getSize(find.byType(GProgressBar)).width, 300);
  });

  testWidgets('GButton nomi ekran o\'quvchida bir marta', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(GButton(label: 'Davom etish', onPressed: () {})),
    );

    final node = tester.getSemantics(find.byType(GButton));
    expect(node.label, 'Davom etish');
    expect(node, isSemantics(isButton: true));
    handle.dispose();
  });

  testWidgets('bosiladigan GListItem tugmasi sarlavhani nom qiladi', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(GListItem(title: 'Ingliz tili', subtitle: '9/10', onTap: () {})),
    );

    final node = tester.getSemantics(find.byType(GListItem));
    expect(node.label, contains('Ingliz tili'));
    expect(node.label, contains('9/10'));
    expect(node, isSemantics(isButton: true));
    handle.dispose();
  });

  testWidgets(
    'ogohlantiruvchi GNote jonli hudud — ekran o\'quvchi e\'lon qiladi',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const Column(
            children: [
              GNote(text: 'Yuborilmadi', kind: GNoteKind.warn),
              GNote(text: 'Xavf boʻlsa qoʻngʻiroq qil', kind: GNoteKind.sos),
              GNote(text: 'Shunchaki maslahat', kind: GNoteKind.info),
            ],
          ),
        ),
      );

      expect(
        tester.getSemantics(find.widgetWithText(GNote, 'Yuborilmadi')),
        isSemantics(label: 'Yuborilmadi', isLiveRegion: true),
      );
      expect(
        tester.getSemantics(
          find.widgetWithText(GNote, 'Xavf boʻlsa qoʻngʻiroq qil'),
        ),
        isSemantics(isLiveRegion: true),
      );
      // Oddiy maslahat har safar e'lon qilinmaydi.
      expect(
        tester.getSemantics(find.widgetWithText(GNote, 'Shunchaki maslahat')),
        isNot(isSemantics(isLiveRegion: true)),
      );
      handle.dispose();
    },
  );

  testWidgets('GSwitch bosish zonasi 48px', (tester) async {
    await tester.pumpWidget(_host(GSwitch(value: true, onChanged: (_) {})));

    expect(
      tester.getSize(find.byType(GSwitch)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('GBubble ota kengligining 80% idan oshmaydi', (tester) async {
    await tester.pumpWidget(
      _host(
        const GBubble(
          mine: true,
          child: Text(
            'Juda uzun xabar matni juda uzun xabar matni juda uzun xabar',
          ),
        ),
        width: 280,
      ),
    );

    final bubble = find
        .descendant(of: find.byType(GBubble), matching: find.byType(Container))
        .first;
    expect(tester.getSize(bubble).width, lessThanOrEqualTo(224.5));
  });

  testWidgets('GScreen klaviatura ochilganda dock uning ustiga ko\'tariladi', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1
      ..viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: GScreen(
          dock: GButton(label: 'Yuborish', onPressed: () {}),
          children: const [GTextField(label: 'Izoh')],
        ),
      ),
    );
    await tester.pump();

    final button = tester.getRect(find.byType(GButton));
    expect(button.bottom, lessThanOrEqualTo(844 - 300));
  });

  testWidgets(
    'dock balandligi o\'lchanadi: ikki tugmali dock kontentni yopmaydi',
    (tester) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: GScreen(
            dock: Column(
              children: [
                GButton(label: 'Asosiy', onPressed: () {}),
                const SizedBox(height: 10),
                GButton(
                  label: 'Ikkinchi',
                  kind: GButtonKind.ghost,
                  size: GButtonSize.second,
                  onPressed: () {},
                ),
              ],
            ),
            children: [
              for (var i = 0; i < 30; i++)
                SizedBox(height: 40, child: Text('qator $i')),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();

      final last = tester.getRect(find.text('qator 29'));
      final dockTop = tester.getRect(find.text('Asosiy')).top - 20;
      expect(last.bottom, lessThanOrEqualTo(dockTop));
    },
  );

  testWidgets('GTextField fokus halqasi chiqqanda ham matn kiritiladi', (
    tester,
  ) async {
    final login = TextEditingController();
    final password = TextEditingController();
    addTearDown(login.dispose);
    addTearDown(password.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              GTextField(label: 'Login', controller: login),
              GTextField(
                label: 'Parol',
                controller: password,
                obscure: true,
                showLabel: 'Ko\'rsatish',
                hideLabel: 'Yashirish',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'aziza.k24');
    await tester.enterText(find.byType(TextField).last, 'parol1234');

    expect(login.text, 'aziza.k24');
    expect(password.text, 'parol1234');
  });
}
