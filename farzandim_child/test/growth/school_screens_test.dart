// M01–M08 · Maktab bo'limi: bosh ekran, vazifalar, tafsilot, davomat, tarix,
// e'lonlar, jadval va yozma javob yuborish (soxta manbalar, tarmoqsiz).
// «Bugun» — 2026-11-05 09:30 (Ona tili darsi davom etmoqda).

import 'dart:io';

import 'package:farzandim_child/features/school/domain/school_assignment.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_models.dart';
import 'package:farzandim_child/growth/kirish/link_screens.dart';
import 'package:farzandim_child/growth/kirish/school_code_screens.dart';
import 'package:farzandim_child/growth/maktab/data/school_v5_repository.dart';
import 'package:farzandim_child/growth/maktab/homework_submit_screen.dart';
import 'package:farzandim_child/growth/oqish/practice/practice_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../features/learning/fake_learning_repository.dart';
import '../features/school/fake_school_repository.dart';
import 'fake_school_v5.dart';
import 'g5_overrides.dart';
import 'g5_test_app.dart';

class _FakePicker extends ImagePicker {
  _FakePicker(this.path);

  final String path;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => XFile(path);
}

Future<FakeSchoolV5Repository> _pump(
  WidgetTester tester,
  String location, {
  bool linked = true,
  List<RouteBase> extraRoutes = const [],
  LinkStatus linkStatus = LinkStatus.none,
  List<SchoolAssignment>? tasks,
}) async {
  final v5 = FakeSchoolV5Repository(
    notices: kSchoolNotices(),
    month: kSchoolMonth(),
    day: kSchoolDay(),
  );
  await pumpG5App(
    tester,
    routes: [...buildGrowthV5Routes(), ...extraRoutes],
    initialLocation: location,
    overrides: [
      ...g5Overrides(
        learning: FakeLearningRepository(clock: () => kG5Now),
        school: FakeSchoolRepository(
          today: linked ? kSchoolToday : null,
          assignments: tasks ?? kSchoolTasks,
          clock: () => kG5Now,
        ),
        schoolAccount: linked ? 'child-1' : null,
      ),
      schoolV5RepositoryProvider.overrideWithValue(v5),
      linkStatusProvider.overrideWith((ref) async => linkStatus),
    ],
  );
  return v5;
}

void main() {
  setUpAll(setUpG5WidgetTests);

  testWidgets('M01: maktab, davomat, vazifa, jadval va e\'lon', (tester) async {
    await _pump(tester, GrowthV5Routes.school);

    expect(find.text('24-maktab · 6-B'), findsOneWidget);
    expect(find.text('Kirish qayd etildi · 08:12'), findsOneWidget);
    expect(find.text('Kun hali tasdiqlanmagan'), findsOneWidget);
    expect(find.text('Kunlik test: Matematika'), findsOneWidget);
    expect(find.text('Ona tili'), findsOneWidget);
    expect(find.text('Ingliz tili'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Bola ovozi'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1 ta yangi'), findsOneWidget);
    expect(find.text('Psixologga yozish'), findsOneWidget);
  });

  testWidgets('M01: maktabga ulanmagan bola — kodni shu yerda kiritadi', (
    tester,
  ) async {
    await _pump(tester, GrowthV5Routes.school, linked: false);

    expect(find.text('Maktabga ulanmagansan'), findsOneWidget);
    expect(find.text('Maktab kodini kiritish'), findsOneWidget);

    await tester.tap(find.text('Maktab kodini kiritish'));
    await settleG5(tester);
    expect(find.byType(KirishSchoolCodeScreen), findsOneWidget);
  });

  testWidgets('M01: kod kiritilgan — «Tasdiq kutilmoqda», maktab nomisiz', (
    tester,
  ) async {
    await _pump(
      tester,
      GrowthV5Routes.school,
      linked: false,
      linkStatus: const LinkStatus(
        student: StudentLinkState.underReview,
        parent: ParentLinkState.none,
      ),
    );

    expect(find.text('Tasdiq kutilmoqda'), findsOneWidget);
    expect(find.text('Ulanish holati'), findsOneWidget);
    expect(find.text('Boshqa kod kiritish'), findsOneWidget);
    expect(find.text('Maktab kodini kiritish'), findsNothing);
  });

  testWidgets('M03: maktab materiali — matn, havola va «O\'qidim»', (
    tester,
  ) async {
    final v5 = await _pump(
      tester,
      GrowthV5Routes.schoolTask('l1'),
      tasks: [
        ...kSchoolTasks,
        SchoolAssignment(
          id: 'l1',
          kind: SchoolAssignmentKind.lesson,
          materialId: 'school:m1',
          title: 'Kasrlarni qo\'shish',
          note: '',
          isOverdue: false,
          dueDate: DateTime(2026, 11, 6),
          isDone: false,
          teacherName: 'Nigora Rahimova',
          lesson: const SchoolLesson(
            body: 'Avval umumiy maxrajni toping.',
            linkUrl: 'https://www.youtube.com/watch?v=x1',
          ),
        ),
      ],
    );

    expect(find.text('Avval umumiy maxrajni toping.'), findsOneWidget);
    expect(find.text('Havolani ochish'), findsOneWidget);
    expect(find.text('www.youtube.com'), findsOneWidget);

    await tester.tap(find.text('Oʻqidim'));
    await settleG5(tester);
    expect(v5.lessonReads, ['l1']);
  });

  testWidgets('M02 → M03: guruhlar va test vazifasini boshlash', (
    tester,
  ) async {
    await _pump(tester, GrowthV5Routes.schoolTasks);

    expect(find.text('BUGUN'), findsOneWidget);
    expect(find.text('KEYINGI KUNLAR'), findsOneWidget);
    // Bajarilgan yagona vazifa — audiokitob: audio / video yashirin.
    expect(find.text('BAJARILGAN'), findsNothing);
    expect(find.text('Oʻrmon sirlari'), findsNothing);

    await tester.tap(find.text('Kunlik test: Matematika'));
    await settleG5(tester);
    expect(
      find.text('«Har bir misolga bitta urinish. Kalkulyator ishlatma.»'),
      findsOneWidget,
    );

    await tester.tap(find.text('Boshlash'));
    await settleG5(tester);
    expect(find.byType(PracticeScreen), findsOneWidget);
  });

  testWidgets('M03: yozma vazifa «Javob yuborish» ga olib boradi', (
    tester,
  ) async {
    await _pump(tester, GrowthV5Routes.schoolTask('w1'));

    await tester.tap(find.text('Javob yuborish'));
    await settleG5(tester);
    expect(find.byType(HomeworkSubmitScreen), findsOneWidget);
  });

  testWidgets('M05: kun tanlansa kiosk va maktab tasdig\'i alohida', (
    tester,
  ) async {
    await _pump(tester, GrowthV5Routes.attendanceHistory);

    await tester.tap(find.bySemanticsLabel(RegExp(r'^3-noyabr')));
    await settleG5(tester);
    expect(find.text('Kiosk: kirish 08:05 · chiqish 13:40'), findsOneWidget);
    expect(find.text('Maktab tasdiqlagan · Qatnashgan'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp(r'^4-noyabr')));
    await settleG5(tester);
    expect(find.text('Avtomatik holat · Aniqlanmagan'), findsOneWidget);
  });

  testWidgets('M06: e\'lon ochiladi va o\'qilgan deb belgilanadi', (
    tester,
  ) async {
    final v5 = await _pump(tester, GrowthV5Routes.notices);

    expect(find.text('6-B sinf uchun · 5-noyabr'), findsOneWidget);
    await tester.tap(find.text('Batafsil').first);
    await settleG5(tester);

    expect(
      find.textContaining('Kitob kartangizni olib keling'),
      findsOneWidget,
    );
    expect(v5.readIds, ['n1']);
  });

  testWidgets('M07: hozirgi va keyingi dars, vazifa belgisi', (tester) async {
    await _pump(tester, GrowthV5Routes.timetable);

    expect(find.text('6-B sinf · 1-smena'), findsOneWidget);
    expect(find.text('Hozir'), findsOneWidget);
    expect(find.text('Keyingi dars'), findsOneWidget);
    expect(find.text('Oʻtdi'), findsOneWidget);
    expect(find.text('Vazifa bor'), findsOneWidget);
    expect(find.text('Jismoniy tarbiya'), findsOneWidget);
  });

  testWidgets('M08: rasmsiz yuborib bo\'lmaydi; rasm bilan — «Yuborildi»', (
    tester,
  ) async {
    final file = await tester.runAsync(() async {
      final f = File('${Directory.systemTemp.path}/g5_homework_test.jpg');
      await f.writeAsBytes(const [0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0xFF, 0xD9]);
      return f;
    });
    final v5 = await _pump(
      tester,
      '/javob-test',
      extraRoutes: [
        GoRoute(
          path: '/javob-test',
          builder: (_, _) => HomeworkSubmitScreen(
            taskId: 'w1',
            picker: _FakePicker(file!.path),
          ),
        ),
      ],
    );

    await tester.tap(find.text('Yuborish'));
    await settleG5(tester);
    expect(find.text('Kamida bitta rasm qoʻsh.'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.bySemanticsLabel(RegExp('Galereya')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settleG5(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Yuborish'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settleG5(tester);

    expect(v5.submitted.single.photos, 1);
    expect(find.text('Yuborildi · 15:20'), findsOneWidget);
    expect(find.text('Vazifalarga qaytish'), findsOneWidget);
  });
}
