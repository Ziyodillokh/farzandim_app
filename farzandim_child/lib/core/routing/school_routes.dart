// Eski maktab marshrutlaridan v5 hali ishlatadiganlari: davomat QR'i va
// psixologik test. "Maktabim", so'rovnoma va murojaatlar v5 "Bola ovozi"
// ekranlariga yo'naltiriladi.

import 'package:farzandim_child/core/routing/route_pages.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/features/school/presentation/school_navigation.dart';
import 'package:farzandim_child/features/school/presentation/screens/psych_test_screen.dart';
import 'package:farzandim_child/features/school/presentation/screens/school_check_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final schoolRoutes = <RouteBase>[
  GoRoute(path: SchoolRoutes.hub, redirect: (_, __) => GrowthV5Routes.school),
  GoRoute(
    path: SchoolRoutes.checkIn,
    // To'liq ekran (kamera) — yopish tugmasi bilan.
    pageBuilder: (context, state) => MaterialPage<void>(
      key: state.pageKey,
      fullscreenDialog: true,
      child: const SchoolCheckInScreen(),
    ),
  ),
  GoRoute(
    path: SchoolRoutes.test,
    // Topshiriq id'si `extra`da; yo'q bo'lsa (deep-link / tiklash) —
    // "Maktabim".
    redirect: (context, state) {
      final id = state.extra;
      return id is String && id.isNotEmpty ? null : SchoolRoutes.hub;
    },
    pageBuilder: (context, state) => sessionPage(
      state,
      PsychTestScreen(assignmentId: state.extra! as String),
    ),
  ),
  GoRoute(
    path: SchoolRoutes.survey,
    redirect: (_, __) => GrowthV5Routes.voiceSurvey,
  ),
  GoRoute(
    path: SchoolRoutes.newRequest,
    redirect: (_, __) => GrowthV5Routes.voiceCompose,
  ),
  GoRoute(
    path: SchoolRoutes.requests,
    redirect: (_, __) => GrowthV5Routes.voiceRequests,
  ),
];
