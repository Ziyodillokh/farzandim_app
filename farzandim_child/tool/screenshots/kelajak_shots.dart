// Skrinshot harness'i uchun "Kelajagim" sahifalari va holatlari (haqiqiy
// server javoblari — `test/features/kelajak/fixtures`):
//   SHOT_PAGE=kelajak_hub | kelajak_scale (shkala savoli, javob tanlangan) |
//     kelajak_text (ochiq savol, matn yozilgan) | kelajak_result
//     ("Bugungi natijangiz") | kelajak_progress ("Kelajak profilim")
//   SHOT_KELAJAK=profile (standart — to'liq profil, kunlik bajarilgan) |
//     fresh | mixed | age_required | out_of_range — overview holati (hub,
//     bosh sahifa kartasi, Testlar qatori, Rivojlanish bo'limi)

import 'package:farzandim_child/features/kelajak/domain/kelajak_overview.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_progress.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_navigation.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_providers.dart';
import 'package:farzandim_child/features/kelajak/presentation/screens/kelajak_hub_screen.dart';
import 'package:farzandim_child/features/kelajak/presentation/screens/kelajak_progress_screen.dart';
import 'package:farzandim_child/features/kelajak/presentation/screens/kelajak_session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../test/features/kelajak/fake_kelajak_repository.dart';
import '../../test/features/kelajak/kelajak_fixtures.dart';

const shotKelajak = String.fromEnvironment(
  'SHOT_KELAJAK',
  defaultValue: 'profile',
);

const _sessionShot = '/kelajak-shot-session';

String? kelajakLocation(String page) => switch (page) {
  'kelajak_hub' => KelajakRoutes.hub,
  'kelajak_scale' || 'kelajak_text' || 'kelajak_result' => _sessionShot,
  'kelajak_progress' => KelajakRoutes.progress,
  _ => null,
};

String get _overviewFixture => switch (shotKelajak) {
  'fresh' => 'overview_ok_fresh',
  'mixed' => 'overview_ok_today_mixed',
  'age_required' => 'overview_age_required',
  'out_of_range' => 'overview_age_out_of_range',
  _ => 'overview_ok_with_profile',
};

String _sessionFixture(String page) => switch (page) {
  'kelajak_text' => 'session_voice_in_progress',
  'kelajak_result' => 'session_complete_daily',
  _ => 'session_daily_in_progress',
};

String _sessionType(String page) => page == 'kelajak_text' ? 'voice' : 'daily';

FakeKelajakRepository _repository(String page) {
  final repo = FakeKelajakRepository();
  repo.onOverview = () async =>
      KelajakOverview.fromJson(fixture(_overviewFixture));
  repo.onStart = (_) async => session(_sessionFixture(page));
  repo.onProgress = () async =>
      KelajakProgress.fromJson(fixture('progress_multi_day'));
  repo.onResults = (before, _) async => KelajakResultsPage.fromJson(
    fixture(before == null ? 'results_page1_limit2' : 'results_page2_limit2'),
  );
  return repo;
}

List<Override> kelajakOverrides(String page) => [
  kelajakRepositoryProvider.overrideWithValue(_repository(page)),
  kelajakAccountProvider.overrideWithValue('child-1'),
];

List<RouteBase> kelajakShotRoutes(String page) => [
  GoRoute(path: KelajakRoutes.hub, builder: (_, _) => const KelajakHubScreen()),
  GoRoute(
    path: _sessionShot,
    builder: (_, _) => KelajakSessionScreen(type: _sessionType(page)),
  ),
  GoRoute(
    path: KelajakRoutes.progress,
    builder: (_, _) => const KelajakProgressScreen(),
  ),
];

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

/// Sahifa chizilgandan keyingi harakatlar: shkala javobini tanlash, ochiq
/// javob yozish.
Future<void> performKelajakActions(WidgetTester tester, String page) async {
  switch (page) {
    case 'kelajak_scale':
      await tester.tap(find.text('Ko‘proq to‘g‘ri').first);
      await _settle(tester);
    case 'kelajak_text':
      await tester.enterText(
        find.byType(TextField),
        'Maktabda ko‘proq amaliy mashg‘ulot va loyihalar bo‘lsa, '
        'darslar yanada qiziqarli bo‘lardi.',
      );
      await _settle(tester);
      FocusManager.instance.primaryFocus?.unfocus();
      await _settle(tester);
  }
}
