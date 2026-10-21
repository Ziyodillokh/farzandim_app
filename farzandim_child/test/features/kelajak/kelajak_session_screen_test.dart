// Kelajak testi sahifasi: savollar bittadan, majburiy savolda javobsiz
// "Keyingi" yopiq, "Orqaga" javobni saqlaydi, ixtiyoriy savolni o'tkazib
// yuborish, ochiq javob hisoblagichi, yakunda "Bugungi natijangiz", yosh
// holatlari, chiqish tasdig'i va xatolar.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/kelajak/data/kelajak_repository.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_session.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_navigation.dart';
import 'package:farzandim_child/features/kelajak/presentation/screens/kelajak_session_screen.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/setup/setup_widgets.dart';
import 'package:farzandim_child/features/school/presentation/widgets/psych/psych_choice_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_kelajak_repository.dart';
import 'kelajak_fixtures.dart';
import 'kelajak_test_app.dart';

const _openLabel = 'open-test';
const _q1 = 'Kichikroq bolalarga biror ishni o‘rgatish qiziq tuyuladimi?';
const _q2 = 'Hikoya, she’r yoki kichik matn yozishdan zavqlanasanmi?';
const _likeMost = 'Juda yoqadi';

String _t(String key, [Map<String, String>? args]) => key.tr(namedArgs: args);

String _position(int current, int total) =>
    _t('learn.questionOf', {'current': '$current', 'total': '$total'});

FakeKelajakRepository _repoWith(KelajakSession Function() start) =>
    kelajakRepo()..onStart = (_) async => start();

/// Barcha savollarga birinchi variant bilan javob berilgan kunlik sessiya.
KelajakSession _answeredDaily() {
  final json = fixture('session_start_daily');
  final questions = (json['questions'] as List).cast<Map<String, dynamic>>();
  json['status'] = 'IN_PROGRESS';
  json['answers'] = [
    for (final q in questions)
      {
        'questionId': q['id'],
        'value': ((q['options'] as List).first as Map)['value'],
        'text': null,
      },
  ];
  return KelajakSession.fromJson(json);
}

/// Boshlang'ich sahifadan testni ochadi (yopilganda shu sahifaga qaytadi).
Future<void> _openSession(
  WidgetTester tester,
  FakeKelajakRepository repo, {
  String type = 'daily',
  Size size = const Size(393, 852),
  double textScale = 1,
}) async {
  await pumpKelajakApp(
    tester,
    repository: repo,
    initialLocation: '/start',
    size: size,
    textScale: textScale,
    routes: [
      GoRoute(
        path: '/start',
        builder: (_, _) => Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () =>
                    context.push(KelajakRoutes.session, extra: type),
                child: const Text(_openLabel),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: KelajakRoutes.session,
        builder: (_, state) =>
            KelajakSessionScreen(type: state.extra! as String),
      ),
      kelajakMarker(KelajakRoutes.hub),
      kelajakMarker(KelajakRoutes.ageEdit),
      kelajakMarker(KelajakRoutes.home),
    ],
  );
  await tester.tap(find.text(_openLabel));
  await tester.pumpAndSettle();
}

SetupButton _primary(WidgetTester tester, String key) =>
    tester.widget<SetupButton>(find.widgetWithText(SetupButton, _t(key)));

bool _isSelected(WidgetTester tester, String label) => tester
    .widget<PsychChoiceTile>(find.widgetWithText(PsychChoiceTile, label))
    .selected;

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text).first;
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settleKelajak(tester);
}

void main() {
  setUpAll(setUpKelajakWidgetTests);

  testWidgets('savollar bittadan; majburiy savolda javobsiz "Keyingi" yopiq', (
    tester,
  ) async {
    final repo = _repoWith(() => session('session_start_daily'));

    await _openSession(tester, repo);

    expect(tester.takeException(), isNull);
    expect(repo.starts, ['daily']);
    expect(find.text(_q1), findsOneWidget);
    expect(find.text(_q2), findsNothing);
    expect(find.text(_position(1, 10)), findsOneWidget);
    expect(find.text('Kasbiy qiziqishlar'), findsOneWidget);
    // Har bir yorliq to'liq ko'rinadi (harfsiz).
    for (final label in [
      'Umuman yoqmaydi',
      'Unchalik yoqmaydi',
      'Yoqadi',
      _likeMost,
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(_primary(tester, 'kelajak.session.next').onTap, isNull);
    expect(find.text(_t('kelajak.session.chooseHint')), findsOneWidget);
    expect(find.text(_t('kelajak.session.skip')), findsNothing);

    await _tapText(tester, _likeMost);

    expect(_isSelected(tester, _likeMost), isTrue);
    expect(_primary(tester, 'kelajak.session.next').onTap, isNotNull);
    expect(find.text(_t('kelajak.session.chooseHint')), findsNothing);
    expect(repo.saves.single.value, 4);
  });

  testWidgets('"Orqaga" tanlangan javobni saqlaydi', (tester) async {
    final repo = _repoWith(() => session('session_start_daily'));
    await _openSession(tester, repo);

    await _tapText(tester, _likeMost);
    await _tapText(tester, _t('kelajak.session.next'));

    expect(find.text(_q2), findsOneWidget);
    expect(find.text(_position(2, 10)), findsOneWidget);
    expect(_primary(tester, 'kelajak.session.next').onTap, isNull);

    await _tapText(tester, _t('kelajak.session.back'));

    expect(find.text(_q1), findsOneWidget);
    expect(_isSelected(tester, _likeMost), isTrue);
    expect(_isSelected(tester, 'Yoqadi'), isFalse);
    // Qaytish qayta saqlamaydi.
    expect(repo.saves, hasLength(1));
  });

  testWidgets('ixtiyoriy savolni javobsiz o\'tkazib yuborish mumkin', (
    tester,
  ) async {
    final repo = _repoWith(() => session('session_start_career_lab'));
    await _openSession(tester, repo, type: 'career_lab');

    expect(find.text(_t('kelajak.session.optional')), findsOneWidget);
    expect(_primary(tester, 'kelajak.session.next').onTap, isNull);
    expect(find.text(_t('kelajak.session.chooseHint')), findsNothing);

    await _tapText(tester, _t('kelajak.session.skip'));

    expect(find.text(_position(2, 5)), findsOneWidget);
    expect(repo.saves, isEmpty);
  });

  testWidgets('ochiq javob: hisoblagich, chegara va "Keyingi"da saqlash', (
    tester,
  ) async {
    final repo = _repoWith(() => session('session_start_voice'));
    await _openSession(tester, repo, type: 'voice');

    expect(find.text('0/1000'), findsOneWidget);
    expect(find.text(_t('kelajak.session.skip')), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Salom');
    await settleKelajak(tester);

    expect(find.text('5/1000'), findsOneWidget);
    expect(find.text(_t('kelajak.session.skip')), findsNothing);

    await tester.enterText(find.byType(TextField), 'a' * 1200);
    await settleKelajak(tester);
    expect(find.text('1000/1000'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  Robot yasash  ');
    await settleKelajak(tester);
    await _tapText(tester, _t('kelajak.session.next'));

    expect(find.text(_position(2, 3)), findsOneWidget);
    expect(repo.saves.single.text, 'Robot yasash');
    expect(repo.saves.single.questionId, kVoiceFirstQuestion);
  });

  testWidgets('yakunlash — "Bugungi natijangiz" va besh bo\'lim', (
    tester,
  ) async {
    final repo = _repoWith(_answeredDaily)
      ..onComplete = (_) async => session('session_complete_daily');
    await _openSession(tester, repo);

    // Hammasi javob berilgan — oxirgi savoldan davom etadi.
    expect(find.text(_position(10, 10)), findsOneWidget);
    await _tapText(tester, _t('kelajak.session.finish'));

    expect(repo.completes, [kDailySessionId]);
    expect(find.text(_t('kelajak.result.title')), findsOneWidget);
    expect(find.textContaining('Sen yolg‘iz emassan'), findsOneWidget);
    Future<void> scrollTo(String text) => tester.scrollUntilVisible(
      find.text(text),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // Bo'limlar tartibda, har biri server tavsiyasi bilan.
    for (final (key, sample) in [
      ('kelajak.result.strengths', 'Muloqot va o‘zini anglash'),
      ('kelajak.result.interests', 'Ijodiy yo‘nalish'),
      ('kelajak.result.liked', 'Mahsulot yoki maket yaratish'),
      ('kelajak.result.growth', 'O‘rganish odatlari'),
      ('kelajak.result.next', 'Yangi faoliyatni sinab ko‘rish'),
    ]) {
      await scrollTo(_t(key));
      await scrollTo(sample);
      expect(find.text(_t(key)), findsOneWidget, reason: key);
      expect(find.text(sample), findsOneWidget, reason: sample);
    }
    // Qat'iy hukm va foiz yo'q.
    expect(find.textContaining('100%'), findsNothing);
    expect(find.textContaining('bo‘lishing kerak'), findsNothing);
  });

  testWidgets('natijadan bosh sahifaga', (tester) async {
    final repo = _repoWith(() => session('session_complete_daily'));
    await _openSession(tester, repo);

    expect(find.text(_t('kelajak.result.title')), findsOneWidget);
    await _tapText(tester, _t('kelajak.result.toHome'));
    await tester.pumpAndSettle();

    expect(find.text('page:${KelajakRoutes.home}'), findsOneWidget);
  });

  testWidgets('AGE_REQUIRED — mavjud profil sahifasiga yo\'naltiradi', (
    tester,
  ) async {
    final repo = kelajakRepo()
      ..onStart = (_) async =>
          throw const KelajakException(KelajakErrorCode.ageRequired);
    await _openSession(tester, repo);

    expect(find.text(_t('kelajak.age.requiredTitle')), findsOneWidget);
    await _tapText(tester, _t('kelajak.age.requiredAction'));
    await tester.pumpAndSettle();

    expect(find.text('page:${KelajakRoutes.ageEdit}'), findsOneWidget);

    // Profildan qaytgach yosh holati qayta so'raladi.
    GoRouter.of(tester.element(find.textContaining('page:'))).pop();
    await tester.pumpAndSettle();
    expect(repo.starts, ['daily', 'daily']);
  });

  testWidgets('AGE_OUT_OF_RANGE — mehribon tushuntirish va yopish', (
    tester,
  ) async {
    final repo = kelajakRepo()
      ..onStart = (_) async =>
          throw const KelajakException(KelajakErrorCode.ageOutOfRange);
    await _openSession(tester, repo);

    expect(find.text(_t('kelajak.age.outOfRangeTitle')), findsOneWidget);
    await _tapText(tester, _t('common.close'));
    await tester.pumpAndSettle();

    expect(find.text(_openLabel), findsOneWidget);
  });

  testWidgets('yuklash xatosi — "Qayta urinish" bilan tiklanadi', (
    tester,
  ) async {
    var fail = true;
    final repo = kelajakRepo()
      ..onStart = (_) async {
        if (fail) throw const KelajakException(KelajakErrorCode.network);
        return session('session_start_daily');
      };
    await _openSession(tester, repo);

    expect(find.text(_t('kelajak.errors.network')), findsOneWidget);
    fail = false;
    await _tapText(tester, _t('common.retry'));

    expect(find.text(_q1), findsOneWidget);
  });

  testWidgets('javob saqlanmasa — xabar, javob qaytariladi', (tester) async {
    final repo = _repoWith(() => session('session_start_daily'))
      ..onSave = (_) async =>
          throw const KelajakException(KelajakErrorCode.network);
    await _openSession(tester, repo);

    await _tapText(tester, _likeMost);

    expect(find.text(_t('kelajak.errors.network')), findsOneWidget);
    expect(_isSelected(tester, _likeMost), isFalse);
    expect(_primary(tester, 'kelajak.session.next').onTap, isNull);
  });

  testWidgets('javob bo\'lsa chiqishda tasdiq so\'raladi', (tester) async {
    final repo = _repoWith(() => session('session_start_daily'));
    await _openSession(tester, repo);

    await _tapText(tester, _likeMost);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text(_t('kelajak.leave.title')), findsOneWidget);
    await tester.tap(find.text(_t('kelajak.leave.stay')));
    await tester.pumpAndSettle();
    expect(find.text(_q1), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('kelajak.leave.leave')));
    await tester.pumpAndSettle();

    expect(find.text(_openLabel), findsOneWidget);
  });

  testWidgets('javobsiz chiqishda tasdiq yo\'q', (tester) async {
    final repo = _repoWith(() => session('session_start_daily'));
    await _openSession(tester, repo);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text(_t('kelajak.leave.title')), findsNothing);
    expect(find.text(_openLabel), findsOneWidget);
  });

  testWidgets('320pt ekran va katta shriftda savol va natija sig\'adi', (
    tester,
  ) async {
    final repo = _repoWith(_answeredDaily)
      ..onComplete = (_) async => session('session_complete_daily');
    await _openSession(
      tester,
      repo,
      size: const Size(320, 640),
      textScale: 1.3,
    );

    expect(tester.takeException(), isNull);
    await _tapText(tester, _t('kelajak.session.finish'));

    expect(tester.takeException(), isNull);
    expect(find.text(_t('kelajak.result.title')), findsOneWidget);
  });
}
