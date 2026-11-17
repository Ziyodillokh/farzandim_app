// Eski Growth marshrutlaridan v5 hali ishlatadigani: sinf va fanlarni
// sozlash (A06, `GrowthLinks.learningSetup`).

import 'package:farzandim_child/core/routing/route_pages.dart';
import 'package:farzandim_child/features/learning/presentation/learning_navigation.dart';
import 'package:farzandim_child/features/learning/presentation/screens/learning_setup_screen.dart';
import 'package:go_router/go_router.dart';

final growthRoutes = <RouteBase>[
  GoRoute(
    path: LearningRoutes.setup,
    pageBuilder: (context, state) =>
        slidePage(state, const LearningSetupScreen()),
  ),
];
