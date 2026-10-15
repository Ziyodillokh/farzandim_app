// Sahifa o'tish animatsiyalari (go_router).

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Pastki nav tablari uchun — siljimaydi, oniy almashadi: nav bir joyda
/// turadi va "qimirlab" ketmaydi.
CustomTransitionPage<T> tabPage<T>(GoRouterState state, Widget child) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    // Tab bar odatiy xatti-harakati: oniy almashinuv (animatsiya paytida
    // ikki sahifaning navi ustma-ust tushib, ikonlar "qimirlamaydi").
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        child,
  );
}

/// Slide right-to-left — ichki sahifaga "drill-down" his. 250ms,
/// easeOutCubic.
CustomTransitionPage<T> slidePage<T>(GoRouterState state, Widget child) {
  return CustomTransitionPage<T>(
    // go_router'ning noyob pageKey'i — bir xil ekran stack'da takror
    // bo'lsa ham kalitlar to'qnashmaydi (duplicate page key crash fix).
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.08, 0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

/// Pastdan ko'tariladigan to'liq ekran (test sessiyasi).
CustomTransitionPage<T> sessionPage<T>(GoRouterState state, Widget child) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}
