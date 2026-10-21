// ProfileScreen (Growth) — tutun testlari: bo'limlar chiziladi, tor ekran
// va katta shriftda overflow yo'q, menyu qatori sahifani ochadi.
//
// Tarmoq yo'q: barcha ma'lumot provider override'lari orqali.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/usage_providers.dart';
import 'package:farzandim_child/features/dashboard/presentation/providers/child_data_provider.dart';
import 'package:farzandim_child/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:farzandim_child/features/gamification/presentation/screens/profile_screen.dart';
import 'package:farzandim_child/features/gamification/presentation/widgets/profile/achievement_badges.dart';
import 'package:farzandim_child/features/gamification/presentation/widgets/profile/learning_profile_card.dart';
import 'package:farzandim_child/features/gamification/presentation/widgets/profile/profile_identity_card.dart';
import 'package:farzandim_child/features/gamification/presentation/widgets/profile/profile_menu.dart';
import 'package:farzandim_child/features/gamification/presentation/widgets/profile/profile_stats_row.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/features/pairing/data/models/pairing_state.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_icons/solar_icons.dart';

import '../school/fake_school_repository.dart';

const _childName = 'Aziza Karimova';

const _profile = LearningProfile(
  grade: 7,
  subjects: [
    Subject.math,
    Subject.english,
    Subject.native,
    Subject.informatics,
    Subject.chemistry,
  ],
);

/// Ulangan bola — haqiqiy notifier (repository, storage) o'rniga.
class _FakePairing extends StateNotifier<AppPairingState>
    implements PairingNotifier {
  _FakePairing()
    : super(
        const AppPairingState(
          status: PairingStatus.paired,
          parentUid: 'parent-1',
          childId: 'child-1',
          childName: _childName,
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpProfile(
  WidgetTester tester, {
  LearningProfile? profile = _profile,
  bool needsSetup = false,
  Size size = const Size(393, 1900),
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = size * 2
    ..devicePixelRatio = 2;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (_, _) =>
            const ProfileScreen(navigation: SizedBox(height: 66)),
      ),
      GoRoute(
        path: '/don-history',
        builder: (_, _) => const Scaffold(body: Text('don-history-page')),
      ),
    ],
  );

  final app = EasyLocalization(
    supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('uz'),
    startLocale: const Locale('uz'),
    child: ProviderScope(
      overrides: [
        pairingStateProvider.overrideWith((ref) => _FakePairing()),
        childAvatarUrlProvider.overrideWith((ref, id) async => null),
        childDataStreamProvider.overrideWith(
          (ref, key) async => <String, dynamic>{'gender': 'female', 'age': 12},
        ),
        backendGamificationProvider.overrideWith(
          (ref) => Stream.value(
            const BackendGamification(
              xp: 1200,
              don: 12480,
              streak: 17,
              level: 3,
              status: 'active',
              unlockedAchievements: ['first_book', 'streak_10'],
            ),
          ),
        ),
        gamificationProfileProvider.overrideWith((ref) => const Stream.empty()),
        todayStepsProvider.overrideWith((ref) async => 6842),
        learningProfileProvider.overrideWithValue(profile),
        needsLearningSetupProvider.overrideWithValue(needsSetup),
        // Maktabga bog'lanmagan bola ("Maktabim" qatori yo'q, tarmoq yo'q).
        schoolRepositoryProvider.overrideWithValue(FakeSchoolRepository()),
      ],
      child: Builder(
        builder: (context) => MaterialApp.router(
          theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          routerConfig: router,
        ),
      ),
    ),
  );

  // Shriftlar birinchi kadrdan oldin (aks holda test shriftida o'lchanadi),
  // tarjimalar esa asinxron yuklanadi.
  await tester.runAsync(() async {
    await _preloadFonts();
    await tester.pumpWidget(app);
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    }
    await GoogleFonts.pendingFonts();
  });
  await tester.pump(const Duration(milliseconds: 300));
}

/// Growth sahifalaridagi barcha bundle shrift og'irliklari.
Future<void> _preloadFonts() async {
  for (final w in [FontWeight.w700, FontWeight.w800]) {
    GoogleFonts.montserrat(fontWeight: w);
  }
  for (final w in [
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700,
    FontWeight.w800,
  ]) {
    GoogleFonts.plusJakartaSans(fontWeight: w);
  }
  await GoogleFonts.pendingFonts();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('paired child sees identity, stats, subjects, menu, badges', (
    tester,
  ) async {
    // Arrange + Act
    await _pumpProfile(tester);

    // Assert
    expect(tester.takeException(), isNull);
    expect(find.byType(ProfileIdentityCard), findsOneWidget);
    expect(find.text(_childName), findsOneWidget);
    expect(find.byType(ProfileStatsRow), findsOneWidget);
    expect(find.text('6 842'), findsOneWidget);
    expect(find.text('12 480'), findsOneWidget);
    expect(find.byType(LearningProfileCard), findsOneWidget);
    expect(find.byType(ProfileMenu), findsOneWidget);
    expect(find.byType(AchievementBadges), findsOneWidget);
    expect(find.text('2/4'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('shows subject setup call-to-action without a learning profile', (
    tester,
  ) async {
    // Arrange + Act
    await _pumpProfile(tester, profile: null, needsSetup: true);

    // Assert
    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byType(LearningProfileCard),
        matching: find.byType(FilledButton),
      ),
      findsOneWidget,
    );
  });

  testWidgets('fits a 320pt screen at 1.3 text scale without overflow', (
    tester,
  ) async {
    // Arrange + Act
    await _pumpProfile(tester, size: const Size(320, 2000), textScale: 1.3);

    // Assert
    expect(tester.takeException(), isNull);
    expect(find.byType(AchievementBadges), findsOneWidget);
  });

  testWidgets('menu row opens its page', (tester) async {
    // Arrange
    await _pumpProfile(tester);

    // Act
    await tester.tap(find.byIcon(SolarIconsBold.walletMoney));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('don-history-page'), findsOneWidget);
  });
}
