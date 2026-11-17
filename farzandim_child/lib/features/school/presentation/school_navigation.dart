// Maktab sahifalariga o'tish — bir joyda (bosh sahifa kartasi, Profil
// menyusi, "Maktabim" va QR sahifasi shu yordamchilarni ishlatadi).

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

abstract final class SchoolRoutes {
  /// "Maktabim" — maktab bo'limlari.
  static const hub = '/school';

  /// Kiosk QR bilan kirish / chiqish (to'liq ekran, kamera).
  static const checkIn = '/school/check-in';

  /// Psixologik test (`extra` — topshiriq id'si).
  static const test = '/school/test';

  /// "Bola ovozi" so'rovnomasi.
  static const survey = '/school/survey';

  /// Psixologga yangi murojaat.
  static const newRequest = '/school/request/new';

  /// Murojaatlarim.
  static const requests = '/school/requests';
}

/// "Maktabim" sahifasi.
void openSchoolHub(BuildContext context) {
  HapticFeedback.selectionClick();
  context.push(SchoolRoutes.hub);
}

/// Davomat QR'ini skanerlash.
void openSchoolCheckIn(BuildContext context) {
  HapticFeedback.selectionClick();
  context.push(SchoolRoutes.checkIn);
}

/// Psixologik testni ochish (topshiriq id'si `extra`da).
void openPsychTest(BuildContext context, String assignmentId) {
  HapticFeedback.selectionClick();
  context.push(SchoolRoutes.test, extra: assignmentId);
}

/// "Bola ovozi" so'rovnomasi.
void openCareSurvey(BuildContext context) {
  HapticFeedback.selectionClick();
  context.push(SchoolRoutes.survey);
}

/// Psixologga yangi murojaat.
void openNewCareRequest(BuildContext context) {
  HapticFeedback.selectionClick();
  context.push(SchoolRoutes.newRequest);
}

/// Murojaatlarim.
void openCareRequests(BuildContext context) {
  HapticFeedback.selectionClick();
  context.push(SchoolRoutes.requests);
}

/// Maktab sahifasini yopish: orqaga, bo'lmasa (deep-link) — "Maktabim".
void closeSchoolPage(BuildContext context) =>
    context.canPop() ? context.pop() : context.go(SchoolRoutes.hub);
