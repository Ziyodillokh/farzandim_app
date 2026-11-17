// «Farzandim maktabda» sarlavhasi: ism tor ekran va katta shriftda ham
// so'z o'rtasidan uzilmaydi (harflar ustunga tushmaydi), oddiy shriftda
// bitta, kattasida ko'pi bilan ikki qatorda turadi; davr belgisi ismga joy
// talashmaydi. Ilova shriftni 1.15× gacha kattalashtiradi (app.dart), 1.3×
// — zaxira.

import 'package:farzandim/features/school/data/models/school_connect.dart';
import 'package:farzandim/features/school/presentation/widgets/overview_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/readable_text.dart';

const _period = "O'quv yili · 01.09.2026 dan";

const _ali = ConnectStudent(
  id: 'st-1',
  name: 'Aliyev Ali',
  className: '1-A',
  schoolName: 'Parvoz QA maktabi',
);

const _long = ConnectStudent(
  id: 'st-2',
  name: 'Xudoyberdiyeva Muxlisaxon Baxtiyor qizi',
  className: '11-B',
  schoolName: "Yunusobod tumani 24-sonli umumta'lim maktabi",
);

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required double scale,
  ConnectStudent student = _ali,
}) async {
  tester.view
    ..physicalSize = Size(width * 3, 900 * 3)
    ..devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: OverviewHeaderCard(student: student, periodLabel: _period),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(loadSchoolFonts);

  for (final (width, scale) in [
    (390.0, 1.0),
    (360.0, 1.15),
    (320.0, 1.15),
    (320.0, 1.3),
  ]) {
    testWidgets('ism uzilmaydi, 2 qatordan oshmaydi — ${width.toInt()} px, '
        '${scale}x', (tester) async {
      await _pump(tester, width: width, scale: scale);

      expect(tester.takeException(), isNull);
      expectNoMidWordBreaks(tester);
      expect(lineCountOf(tester, 'Aliyev Ali'), lessThanOrEqualTo(2));
      expect(find.text(_period), findsOneWidget);
    });
  }

  testWidgets('oddiy shriftda ism bitta qatorda', (tester) async {
    await _pump(tester, width: 360, scale: 1);

    expect(lineCountOf(tester, 'Aliyev Ali'), 1);
  });

  testWidgets("uzun familiya sig'maganda shrift kichrayadi, so'z bo'linmaydi", (
    tester,
  ) async {
    await _pump(tester, width: 320, scale: 1.3, student: _long);

    expect(tester.takeException(), isNull);
    expectNoMidWordBreaks(tester);
    expect(lineCountOf(tester, _long.name), lessThanOrEqualTo(2));
  });
}
