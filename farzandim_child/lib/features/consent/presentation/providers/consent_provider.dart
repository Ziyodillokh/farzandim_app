// ─────────────────────────────────────────────────────────────────────
// ConsentProvider — Parent Consent state (Riverpod)
// ─────────────────────────────────────────────────────────────────────
//
// `ConsentState.unknown` — SharedPreferences hali o'qilmagan (boot).
// `ConsentState.notGiven` — rozilik berilmagan → /consent ekrani.
// `ConsentState.given` — rozilik bor → boshqa ekranlarga ruxsat.
//
// Router `refreshListenable` orqali bu provider'ga reaktiv bog'lanadi
// (pairingStateProvider kabi). Rozilik tasdiqlangach state o'zgaradi,
// router darhol /consent'dan keyingi sahifaga o'tkazadi.

import 'package:farzandim_child/features/consent/data/services/consent_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConsentState { unknown, notGiven, given }

final consentStateProvider =
    StateNotifierProvider<ConsentNotifier, ConsentState>((ref) {
  return ConsentNotifier();
});

class ConsentNotifier extends StateNotifier<ConsentState> {
  ConsentNotifier() : super(ConsentState.unknown) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final given = await ConsentStorage.isParentConsentGiven();
    state = given ? ConsentState.given : ConsentState.notGiven;
  }

  /// Ota-ona "Ota-onam tasdiqlaydi" tugmasini 3 sekund ushlab turgach
  /// chaqiriladi. SharedPreferences yoziladi va state yangilanadi —
  /// router darhol keyingi ekranga yo'naltiradi.
  Future<void> confirm() async {
    await ConsentStorage.markConsentGiven();
    state = ConsentState.given;
  }

  /// Faqat test/debug uchun — rozilikni qayta so'rash.
  Future<void> reset() async {
    await ConsentStorage.resetConsent();
    state = ConsentState.notGiven;
  }
}
