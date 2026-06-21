// ─────────────────────────────────────────────────────────────────────
// themeModeProvider — Light/Dark mode tanlovi (Sprint UI.4)
// ─────────────────────────────────────────────────────────────────────
//
// Foydalanuvchi Settings'da Light/Dark/System tanlaydi. Tanlov
// SharedPreferences'da saqlanadi va app qayta ochilganda tiklanadi.
//
// `main.dart` `ChildApp` build'da `ref.watch(themeModeProvider)` —
// MaterialApp.themeMode shu provider'dan keladi.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _prefsKey = 'settings.theme_mode';

/// App theme mode — light (default), dark, system.
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    // PARVOZ redizayn fazasi: default — DARK (night). "Faqat night" davri;
    // light mode keyin qo'shilganda qaytariladi. Saqlangan tanlov async yuklanadi.
    _restore();
    return ThemeMode.dark;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null) {
        state = _fromString(saved);
      }
    } catch (_) {
      // Default light qoladi.
    }
  }

  /// Theme mode'ni o'zgartirish + SharedPreferences'ga saqlash.
  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.name);
    } catch (_) {
      // Saqlash xatosi — state baribir o'zgardi (sessiya davomida).
    }
  }

  /// Light ↔ Dark tezkor toggle (Settings switch uchun).
  Future<void> toggle() async {
    final next =
        state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setMode(next);
  }

  static ThemeMode _fromString(String s) {
    switch (s) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }
}
