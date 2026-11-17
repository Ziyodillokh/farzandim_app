// KelajakScreen (393pt kenglik, haqiqiy fixture'lar bilan): boy profil
// barcha bo'limlarni ko'rsatadi, qo'llab-quvvatlash kartasi FAQAT signal
// bo'lsa, foiz va "100%" yo'q; bo'sh holat; yosh kiritilmagan — mavjud
// bola tahrirlash sahifasi ochiladi va qaytilganda xulosa yangilanadi;
// bo'lim yo'q — "mavjud emas"; pull-to-refresh qayta so'raydi.

import 'package:dio/dio.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/kelajak/data/kelajak_repository.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_summary.dart';
import 'package:farzandim/features/kelajak/presentation/screens/kelajak_screen.dart';
import 'package:farzandim/features/kelajak/presentation/widgets/kelajak_career_lab_section.dart';
import 'package:farzandim/features/kelajak/presentation/widgets/kelajak_progress_section.dart';
import 'package:farzandim/features/kelajak/presentation/widgets/kelajak_sections.dart';
import 'package:farzandim/features/kelajak/presentation/widgets/kelajak_support_card.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'kelajak_fixtures.dart';

class _FakeKelajakRepository extends KelajakRepository {
  _FakeKelajakRepository(this.fixture) : super(dio: Dio());

  String fixture;
  bool unavailable = false;
  int fetches = 0;

  @override
  Future<KelajakSummary> fetchSummary(String childId) async {
    fetches++;
    if (unavailable) {
      throw const SchoolFailure(SchoolFailureKind.unavailable);
    }
    return kelajakFixture(fixture);
  }
}

/// Telefon kengligi (393pt), barcha bo'limlar sig'adigan balandlik.
Future<void> _pump(WidgetTester tester, _FakeKelajakRepository repo) async {
  tester.view
    ..physicalSize = const Size(393 * 3, 4200 * 3)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/kelajak/kid-1',
    routes: [
      GoRoute(
        path: '/kelajak/:childId',
        builder: (_, state) =>
            KelajakScreen(childId: state.pathParameters['childId']!),
      ),
      GoRoute(
        path: '/edit-child/:id',
        builder: (_, state) =>
            Scaffold(body: Text('edit:${state.pathParameters['id']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        kelajakRepositoryProvider.overrideWithValue(repo),
        childByIdProvider.overrideWith((ref, id) => null),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('boy profil: barcha bo`limlar, signal kartasi, foiz yo`q', (
    tester,
  ) async {
    await _pump(tester, _FakeKelajakRepository(kRichSupportFixture));

    // Sarlavha: testlar soni va yosh guruhi.
    expect(find.text('7'), findsOneWidget);
    expect(find.text('kelajak.header.sessions'), findsOneWidget);
    // Qiziqishlar: backend matni + sinab ko'rish mumkin bo'lgan sohalar.
    expect(find.byType(KelajakInterestsSection), findsOneWidget);
    expect(find.text('Ijodiy yo‘nalish'), findsOneWidget);
    expect(find.textContaining('qiziqish yuqori'), findsNWidgets(3));
    expect(find.text('dizayn'), findsOneWidget);
    expect(find.text('kelajak.interests.try'), findsNWidgets(3));
    // Kuchli tomonlar va rivojlantirish (maslahat bilan).
    expect(find.text('Muloqot va o‘zini anglash'), findsOneWidget);
    expect(find.text('Xavfsizlik qoidalari'), findsOneWidget);
    expect(
      find.textContaining('Har kuni ozgina vaqt qiziq mavzuni'),
      findsOneWidget,
    );
    // Career Lab: yoqdi / o'rtacha / yoqmadi + keyingi sinov.
    expect(find.byType(KelajakCareerLabSection), findsOneWidget);
    expect(find.text('kelajak.careerLab.liked'), findsOneWidget);
    expect(find.text('kelajak.careerLab.disliked'), findsOneWidget);
    expect(find.text('Mahsulot yoki maket yaratish'), findsOneWidget);
    expect(find.text('Amaliy'), findsOneWidget);
    expect(find.text('Yangi faoliyatni sinab ko‘rish'), findsOneWidget);
    // Signal: ehtiyotkor matn, sohalar, suhbat maslahatlari.
    expect(find.byType(KelajakSupportCard), findsOneWidget);
    expect(find.text('kelajak.support.titleSupport'), findsOneWidget);
    expect(find.textContaining('Bu tashxis emas'), findsOneWidget);
    expect(find.text('kelajak.support.talk1'), findsOneWidget);
    expect(find.text('Xavfsizlik va bullying'), findsOneWidget);
    // Progress: o'zgarish va qiziqishi ortayotgan yo'nalish.
    expect(find.byType(KelajakProgressSection), findsOneWidget);
    expect(find.text('+25'), findsOneWidget);
    expect(find.text('kelajak.progress.first'), findsNWidgets(3));
    expect(
      find.descendant(
        of: find.byType(KelajakProgressSection),
        matching: find.text('Ijtimoiy'),
      ),
      findsOneWidget,
    );
    expect(find.text('kelajak.progress.same'), findsNWidgets(2));
    // Raqamli hukm yo'q, bo'sh holat yo'q.
    expect(find.textContaining('%'), findsNothing);
    expect(find.text('kelajak.empty.title'), findsNothing);
    // Eng pastda — ogohlantirish.
    await tester.scrollUntilVisible(
      find.textContaining('qat’iy kasb hukmi emas'),
      400,
    );
    expect(find.textContaining('qat’iy kasb hukmi emas'), findsOneWidget);
  });

  testWidgets('bo`sh profil: bo`sh holat, signal kartasi yo`q', (tester) async {
    await _pump(tester, _FakeKelajakRepository(kEmptyFixture));

    expect(find.text('kelajak.empty.title'), findsOneWidget);
    expect(find.text('kelajak.header.noActivity'), findsOneWidget);
    expect(find.byType(KelajakSupportCard), findsNothing);
    expect(find.byType(KelajakInterestsSection), findsNothing);
    expect(find.text('kelajak.age.requiredAction'), findsNothing);
  });

  testWidgets('watch: faqat signal va tavsiya, yo`nalish hali yo`q', (
    tester,
  ) async {
    await _pump(tester, _FakeKelajakRepository(kWatchFixture));

    expect(find.byType(KelajakSupportCard), findsOneWidget);
    expect(find.text('kelajak.support.titleWatch'), findsOneWidget);
    expect(find.text('Ruhiy farovonlik va stress'), findsOneWidget);
    expect(find.text('kelajak.interests.forming'), findsOneWidget);
    expect(find.byType(KelajakCareerLabSection), findsNothing);
    expect(find.byType(KelajakProgressSection), findsNothing);
    expect(find.text('Kasbiy qiziqishlar testi'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('yosh kiritilmagan: tahrirlash sahifasi, qaytgach yangilanadi', (
    tester,
  ) async {
    final repo = _FakeKelajakRepository(kAgeRequiredFixture);
    await _pump(tester, repo);

    expect(find.text('kelajak.age.requiredTitle'), findsOneWidget);
    expect(find.text('kelajak.empty.title'), findsNothing);
    expect(find.byType(KelajakSupportCard), findsNothing);
    expect(repo.fetches, 1);

    await tester.tap(find.text('kelajak.age.requiredAction'));
    await tester.pumpAndSettle();
    expect(find.text('edit:kid-1'), findsOneWidget);

    repo.fixture = kEmptyFixture;
    GoRouter.of(tester.element(find.text('edit:kid-1'))).pop();
    await tester.pumpAndSettle();
    expect(repo.fetches, 2);
    expect(find.text('kelajak.age.requiredTitle'), findsNothing);
    expect(find.text('kelajak.empty.title'), findsOneWidget);
  });

  testWidgets('bo`lim yo`q → "mavjud emas"', (tester) async {
    final repo = _FakeKelajakRepository(kEmptyFixture)..unavailable = true;
    await _pump(tester, repo);

    expect(find.text('kelajak.unavailable'), findsOneWidget);
    expect(find.text('kelajak.header.sessions'), findsNothing);
  });

  testWidgets('pastga tortib yangilash xulosani qayta so`raydi', (
    tester,
  ) async {
    final repo = _FakeKelajakRepository(kEmptyFixture);
    await _pump(tester, repo);
    expect(repo.fetches, 1);

    repo.fixture = kRichSupportFixture;
    // Indikator ko'rinish balandligining ~choragidan ortiq tortishni kutadi.
    await tester.fling(find.byType(ListView), const Offset(0, 1600), 1000);
    await tester.pumpAndSettle();

    expect(repo.fetches, 2);
    expect(find.byType(KelajakSupportCard), findsOneWidget);
  });
}
