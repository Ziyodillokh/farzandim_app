// "Kelajagim" sahifalariga o'tish — bir joyda (bosh sahifa kartasi, Testlar,
// Rivojlanish, hub va natija sahifasi shu yordamchilarni ishlatadi).

import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_providers.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_session_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

abstract final class KelajakRoutes {
  /// Testlar ro'yxati, yosh holati va mavzular.
  static const hub = '/kelajak';

  /// Test yechish (`extra` — test turi, masalan `daily`).
  static const session = '/kelajak/session';

  /// Kategoriyalar o'zgarishi, o'sgan qiziqishlar va tarix.
  static const progress = '/kelajak/progress';

  /// Mavjud profil tahrirlash sahifasi (`PUT /children/me` — yosh shu yerda
  /// kiritiladi).
  static const ageEdit = '/account-edit';

  /// Bosh sahifa.
  static const home = '/dashboard';
}

void openKelajakHub(BuildContext context) {
  HapticFeedback.selectionClick();
  context.push(KelajakRoutes.hub);
}

/// Bugungi testni ochish (yangi, davom etayotgan yoki yakunlangan — natija).
void openKelajakSession(BuildContext context, String type) {
  HapticFeedback.selectionClick();
  context.push(KelajakRoutes.session, extra: type);
}

void openKelajakProgress(BuildContext context) {
  HapticFeedback.selectionClick();
  context.push(KelajakRoutes.progress);
}

/// Yosh kiritilmagan: profil sahifasi; qaytgach yosh holati va sessiyalar
/// serverdan qayta so'raladi (yosh taxmin qilinmaydi).
Future<void> openKelajakAgeEdit(BuildContext context, WidgetRef ref) async {
  HapticFeedback.selectionClick();
  await context.push(KelajakRoutes.ageEdit);
  if (!context.mounted) return;
  ref
    ..invalidate(kelajakOverviewByAccountProvider)
    ..invalidate(kelajakSessionProvider);
}

/// Natijadan hub'ga: hub'dan ochilgan bo'lsa — orqaga, aks holda test
/// sahifasi hub bilan almashtiriladi (bosh sahifa ostida qoladi).
void returnToKelajakHub(BuildContext context) {
  final matches = GoRouter.of(context).routerDelegate.currentConfiguration;
  final list = matches.matches;
  final fromHub =
      list.length >= 2 &&
      list[list.length - 2].matchedLocation == KelajakRoutes.hub;
  if (fromHub && context.canPop()) {
    context.pop();
  } else {
    context.pushReplacement(KelajakRoutes.hub);
  }
}

/// Kelajak sahifasini yopish: orqaga, bo'lmasa (deep-link) — hub.
void closeKelajakPage(BuildContext context) =>
    context.canPop() ? context.pop() : context.go(KelajakRoutes.hub);
