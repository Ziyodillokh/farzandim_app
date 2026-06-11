// ─────────────────────────────────────────────────────────────────────
// appLifecycleProvider — ilova lifecycle holati (polling'larni to'xtatish)
// ─────────────────────────────────────────────────────────────────────
//
// Polling provayderlar (children 60s, usage 30s, ...) har tick'da shu
// provider'ni O'QIB (`ref.read`), ilova FONDA bo'lsa so'rov yubormaydi.
// Busiz ilova background'da turganda ham backend'ga doimiy so'rov ketardi
// — 100k user'da minglab RPS keraksiz yuk + telefon batareyasi.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Joriy [AppLifecycleState]. Birinchi o'qilganda observer o'rnatiladi va
/// ilova umri davomida yangilanib turadi.
final appLifecycleProvider = StateProvider<AppLifecycleState>((ref) {
  final listener = AppLifecycleListener(
    onStateChange: (s) => ref.controller.state = s,
  );
  ref.onDispose(listener.dispose);
  return WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
});

/// Polling tick'larida ishlatiladigan qisqartma — ilova ko'rinib turibdimi.
bool isAppResumed(Ref ref) =>
    ref.read(appLifecycleProvider) == AppLifecycleState.resumed;
