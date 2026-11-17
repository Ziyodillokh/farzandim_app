// ─────────────────────────────────────────────────────────────────────
// ShellReadyGate — ilova «tayyor»: splash o'tgan va PIN qulfi ochiq
// ─────────────────────────────────────────────────────────────────────
//
// Bloklash overlay'idagi «Ruxsat so'rash» Parvoz'ni sovuq ishga tushirganda
// modal hali /splash'da ochilardi. Splash keyin `context.go()` qilib sahifani
// almashtirar, modal u bilan birga yopilar va so'rov jimgina yo'qolardi
// (fn-unlock-request-lost-cold-start). Endi kutilayotgan so'rov (va Device
// Admin tizim dialogi) faqat shu darvoza ochilgach ko'rsatiladi: manzil
// splash emas, xato sahifasi emas va PIN qulfi ochiq.

import 'dart:async';

import 'package:farzandim_child/core/routing/app_router.dart';
import 'package:farzandim_child/growth/men/lock/app_lock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Splash manzili — undan keyin ilovaning o'z ekranlari boshlanadi.
const kSplashLocation = '/splash';

/// Tayyor bo'lsa-yu navigator konteksti hali yo'q bo'lsa — shuncha kadr
/// kutiladi, keyin keyingi manzil / qulf o'zgarishi kutiladi (kadrlar
/// cheksiz so'ralmasin).
const _kMaxFrameRetries = 5;

class ShellReadyGate {
  ShellReadyGate({required GoRouter router, required AppLock lock})
    : _router = router,
      _lock = lock;

  final GoRouter _router;
  final AppLock _lock;
  final List<Completer<bool>> _waiters = [];
  bool _listening = false;
  bool _disposed = false;

  /// Splash o'tgan, manzil xatosiz va PIN qulfi ochiq.
  bool get isReady {
    final config = _router.routerDelegate.currentConfiguration;
    return config.isNotEmpty &&
        !config.isError &&
        config.uri.path != kSplashLocation &&
        !_lock.isLocked;
  }

  /// Darvoza ochilguncha kutadi. `false` — darvoza yopildi (konteyner
  /// almashdi), kutish bekor.
  Future<bool> waitUntilReady() async {
    while (!_disposed) {
      if (isReady) return true;
      if (!await _nextChange()) return false;
    }
    return false;
  }

  /// Tayyor ilovaning navigator konteksti — modal shu yerda ochiladi.
  ///
  /// Manzil o'zgargach sahifalar keyingi kadrda quriladi: undan oldin ochilgan
  /// modal eski (splash) sahifaga ulanib, u bilan birga yopilardi. Shu sababli
  /// kadr tugashini kutib, holatni qayta tekshiramiz. `null` — kutish bekor.
  Future<BuildContext?> waitForContext() async {
    var frames = 0;
    while (await waitUntilReady()) {
      await WidgetsBinding.instance.endOfFrame;
      if (_disposed) return null;
      final ctx = _router.routerDelegate.navigatorKey.currentContext;
      if (isReady && ctx != null && ctx.mounted) return ctx;
      // Kadr davomida qulflandi / manzil o'zgardi — yana ochilishini kutamiz.
      if (!isReady) continue;
      if (++frames < _kMaxFrameRetries) continue;
      // Navigator hali qurilmagan — keyingi o'zgarishni kutamiz.
      frames = 0;
      if (!await _nextChange()) return null;
    }
    return null;
  }

  /// Keyingi manzil yoki qulf o'zgarishi. `false` — darvoza yopildi.
  Future<bool> _nextChange() {
    if (_disposed) return Future.value(false);
    final waiter = Completer<bool>();
    _waiters.add(waiter);
    if (!_listening) {
      _listening = true;
      _router.routerDelegate.addListener(_onChanged);
      _lock.addListener(_onChanged);
    }
    return waiter.future;
  }

  void _onChanged() {
    final waiters = List.of(_waiters);
    _waiters.clear();
    _stopListening();
    for (final waiter in waiters) {
      waiter.complete(true);
    }
  }

  void _stopListening() {
    if (!_listening) return;
    _listening = false;
    _router.routerDelegate.removeListener(_onChanged);
    _lock.removeListener(_onChanged);
  }

  void dispose() {
    _disposed = true;
    _stopListening();
    final waiters = List.of(_waiters);
    _waiters.clear();
    for (final waiter in waiters) {
      waiter.complete(false);
    }
  }
}

/// Shu konteyner router'i va ilova qulfi bo'yicha darvoza.
final shellReadyGateProvider = Provider<ShellReadyGate>((ref) {
  final gate = ShellReadyGate(
    router: ref.watch(routerProvider),
    lock: ref.watch(appLockProvider),
  );
  ref.onDispose(gate.dispose);
  return gate;
});
