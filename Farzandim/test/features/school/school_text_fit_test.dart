// SkTagRow: yorliq sig'sa matn yonida, sig'masa matn ostida — matn hech
// qachon harflab ustunga tushmaydi. wordSafeStyle: eng uzun so'z sig'guncha
// shrift kichrayadi, lekin asl o'lchamning 72% idan pastga tushmaydi.

import 'package:farzandim/features/school/presentation/widgets/school_kit.dart';
import 'package:farzandim/features/school/presentation/widgets/school_text_fit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/readable_text.dart';

const _school = "Yunusobod tumani 24-sonli umumta'lim maktabi";

Future<void> _pumpRow(
  WidgetTester tester, {
  required double width,
  required double scale,
  required String tag,
}) async {
  tester.view
    ..physicalSize = Size(width * 3, 600 * 3)
    ..devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SkTagRow(
            leading: Text(
              _school,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: skText(14.5, w: FontWeight.w600),
            ),
            tag: SkTag(label: tag, color: SK.amber),
          ),
        ),
      ),
    ),
  );
}

bool _tagBesideText(WidgetTester tester, String tag) {
  final text = tester.getRect(find.text(_school));
  final label = tester.getRect(find.text(tag));
  return label.left >= text.right;
}

void main() {
  setUpAll(loadSchoolFonts);

  testWidgets("qisqa yorliq — matn yonida, o'ngda", (tester) async {
    await _pumpRow(tester, width: 390, scale: 1, tag: 'Bugun');

    expect(tester.takeException(), isNull);
    expect(_tagBesideText(tester, 'Bugun'), isTrue);
    expectNoMidWordBreaks(tester);
  });

  testWidgets('uzun yorliq tor ekranda — matn ostiga tushadi', (tester) async {
    const tag = "Muddati o'tgan · 12 kun";
    await _pumpRow(tester, width: 320, scale: 1.3, tag: tag);

    expect(tester.takeException(), isNull);
    expect(_tagBesideText(tester, tag), isFalse);
    expect(
      tester.getRect(find.text(tag)).top,
      greaterThan(tester.getRect(find.text(_school)).bottom),
    );
    expectNoMidWordBreaks(tester);
  });

  for (final (width, scale) in [(360.0, 1.15), (320.0, 1.15), (320.0, 1.3)]) {
    testWidgets("matn so'z o'rtasidan uzilmaydi — ${width.toInt()} px, "
        '${scale}x', (tester) async {
      await _pumpRow(tester, width: width, scale: scale, tag: 'Tekshirilmoqda');

      expect(tester.takeException(), isNull);
      expectNoMidWordBreaks(tester);
      expect(lineCountOf(tester, _school), lessThanOrEqualTo(2));
    });
  }

  testWidgets("wordSafeStyle: sig'adigan matn o'zgarmaydi", (tester) async {
    final style = skDisplay(17);

    final fitted = wordSafeStyle(
      'Aliyev Ali',
      style,
      maxWidth: 300,
      scaler: TextScaler.noScaling,
      direction: TextDirection.ltr,
    );

    expect(fitted.fontSize, 17);
  });

  testWidgets("wordSafeStyle: uzun so'z uchun kichrayadi, 72% dan pastga "
      'tushmaydi', (tester) async {
    final style = skDisplay(17);

    final fitted = wordSafeStyle(
      'Xudoyberdiyeva',
      style,
      maxWidth: 120,
      scaler: TextScaler.noScaling,
      direction: TextDirection.ltr,
    );
    final tiny = wordSafeStyle(
      'Xudoyberdiyeva',
      style,
      maxWidth: 10,
      scaler: TextScaler.noScaling,
      direction: TextDirection.ltr,
    );

    expect(fitted.fontSize, lessThan(17));
    expect(tiny.fontSize, closeTo(17 * 0.72, 0.01));
  });
}
