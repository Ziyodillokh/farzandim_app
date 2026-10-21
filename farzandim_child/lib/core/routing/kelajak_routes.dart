// "Kelajagim" sahifalari marshrutlari: hub, test yechish (natija shu
// sahifada) va "Kelajak profilim" (rivojlanish va tarix).

import 'package:farzandim_child/core/routing/route_pages.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_navigation.dart';
import 'package:farzandim_child/features/kelajak/presentation/screens/kelajak_hub_screen.dart';
import 'package:farzandim_child/features/kelajak/presentation/screens/kelajak_progress_screen.dart';
import 'package:farzandim_child/features/kelajak/presentation/screens/kelajak_session_screen.dart';
import 'package:go_router/go_router.dart';

final kelajakRoutes = <RouteBase>[
  GoRoute(
    path: KelajakRoutes.hub,
    pageBuilder: (context, state) => slidePage(state, const KelajakHubScreen()),
  ),
  GoRoute(
    path: KelajakRoutes.session,
    // Test turi `extra`da keladi; yo'q bo'lsa (deep-link / tiklash) — hub.
    redirect: (context, state) {
      final type = state.extra;
      return type is String && type.isNotEmpty ? null : KelajakRoutes.hub;
    },
    pageBuilder: (context, state) =>
        sessionPage(state, KelajakSessionScreen(type: state.extra! as String)),
  ),
  GoRoute(
    path: KelajakRoutes.progress,
    pageBuilder: (context, state) =>
        slidePage(state, const KelajakProgressScreen()),
  ),
];
