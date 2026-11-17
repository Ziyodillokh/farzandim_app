// ─────────────────────────────────────────────────────────────────────
// appLifecycleProvider — ilova ekranda yoki fonda (UI isolate)
// ─────────────────────────────────────────────────────────────────────
//
// Socket, bildirishnomalar so'rovi va UI isolate'dagi fon ishlari ilova
// fonga o'tganda to'xtaydi va qaytganda darhol tiklanadi — fonda radio
// uxlay olsin (batareya). `inactive` (bildirishnoma pardasi, tizim
// ruxsat dialogi, ilovalar ro'yxati) hali ham "ekranda" hisoblanadi:
// aks holda har dialogda socket uzilib-ulanardi.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ilova ekranda (`resumed` yoki `inactive`) — `true`; fonda (`hidden`,
/// `paused`, `detached`) — `false`.
bool isForegroundState(AppLifecycleState state) =>
    state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;

/// Joriy [AppLifecycleState] (Flutter `AppLifecycleListener` orqali).
final appLifecycleProvider =
    NotifierProvider<AppLifecycleNotifier, AppLifecycleState>(
      AppLifecycleNotifier.new,
    );

class AppLifecycleNotifier extends Notifier<AppLifecycleState> {
  @override
  AppLifecycleState build() {
    final listener = AppLifecycleListener(
      onStateChange: (next) => state = next,
    );
    ref.onDispose(listener.dispose);
    // Birinchi hodisagacha holat noma'lum bo'lishi mumkin — UI isolate faqat
    // Activity bilan ishga tushadi, demak ekranda.
    return WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
  }
}

/// Ilova ekranda (socket ulanadi, ro'yxatlar yangilanadi).
final isAppInForegroundProvider = Provider<bool>(
  (ref) => isForegroundState(ref.watch(appLifecycleProvider)),
);
