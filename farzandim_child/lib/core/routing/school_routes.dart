// Maktab sahifalari marshrutlari: "Maktabim", davomat QR'i, psixologik
// test, "Bola ovozi" so'rovnomasi va psixologga murojaatlar.

import 'package:farzandim_child/core/routing/route_pages.dart';
import 'package:farzandim_child/features/school/presentation/school_navigation.dart';
import 'package:farzandim_child/features/school/presentation/screens/care_request_screen.dart';
import 'package:farzandim_child/features/school/presentation/screens/care_requests_screen.dart';
import 'package:farzandim_child/features/school/presentation/screens/care_survey_screen.dart';
import 'package:farzandim_child/features/school/presentation/screens/psych_test_screen.dart';
import 'package:farzandim_child/features/school/presentation/screens/school_check_in_screen.dart';
import 'package:farzandim_child/features/school/presentation/screens/school_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final schoolRoutes = <RouteBase>[
  GoRoute(
    path: SchoolRoutes.hub,
    pageBuilder: (context, state) => slidePage(state, const SchoolHubScreen()),
  ),
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
    pageBuilder: (context, state) => slidePage(state, const CareSurveyScreen()),
  ),
  GoRoute(
    path: SchoolRoutes.newRequest,
    pageBuilder: (context, state) =>
        slidePage(state, const CareRequestScreen()),
  ),
  GoRoute(
    path: SchoolRoutes.requests,
    pageBuilder: (context, state) =>
        slidePage(state, const CareRequestsScreen()),
  ),
];
