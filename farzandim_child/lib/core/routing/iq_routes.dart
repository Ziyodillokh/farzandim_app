// "IQ test" sahifalari marshrutlari: hub (qoidalar, natija, tarix) va test
// yechish (natija shu sahifada).

import 'package:farzandim_child/core/routing/route_pages.dart';
import 'package:farzandim_child/features/iq/presentation/iq_display.dart';
import 'package:farzandim_child/features/iq/presentation/screens/iq_hub_screen.dart';
import 'package:farzandim_child/features/iq/presentation/screens/iq_test_screen.dart';
import 'package:go_router/go_router.dart';

final iqRoutes = <RouteBase>[
  GoRoute(
    path: IqRoutes.hub,
    pageBuilder: (context, state) => slidePage(state, const IqHubScreen()),
  ),
  GoRoute(
    path: IqRoutes.test,
    pageBuilder: (context, state) => sessionPage(state, const IqTestScreen()),
  ),
];
