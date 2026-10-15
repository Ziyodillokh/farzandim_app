// ─────────────────────────────────────────────────────────────────────
// savedAudiobookIdsProvider — Kutubxona'dagi "saqlash" (bookmark) holati
// ─────────────────────────────────────────────────────────────────────
//
// Videolarda saqlash backend'da bor (`favoriteVideoIdsProvider`).
// Audiokitoblar uchun backend endpoint hali yo'q — shu sababli hozircha
// LOKAL to'plam (SharedPreferences). Backend qo'shilganda video
// sevimlilari kabi sinxronlash shu notifier ichiga qo'shiladi.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _savedKey = 'saved_audiobook_ids_v1';

/// Saqlangan audiokitob ID'lari (lokal).
final savedAudiobookIdsProvider =
    NotifierProvider<SavedAudiobookIdsNotifier, Set<String>>(
      SavedAudiobookIdsNotifier.new,
    );

/// Saqlanganlar to'plami — lokal restore + optimistic toggle.
class SavedAudiobookIdsNotifier extends Notifier<Set<String>> {
  Future<void>? _ready;

  @override
  Set<String> build() {
    _ready = _restore();
    return const {};
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = (prefs.getStringList(_savedKey) ?? const <String>[]).toSet();
    } catch (_) {
      // O'qib bo'lmadi — bo'sh to'plam bilan davom etamiz.
    }
  }

  /// Toggle — yangi holat (saqlandi=true) qaytaradi.
  Future<bool> toggle(String id) async {
    await _ready;
    final next = {...state};
    final added = next.add(id);
    if (!added) next.remove(id);
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_savedKey, next.toList());
    } catch (_) {
      // Saqlash xatosi — sessiya davomida holat baribir o'zgardi.
    }
    return added;
  }
}
