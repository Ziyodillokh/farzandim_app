// ─────────────────────────────────────────────────────────────────────
// Theme mode — light / dark toggle (Riverpod + SharedPreferences)
// ─────────────────────────────────────────────────────────────────────
//
// Dashboard'dagi ☀️/🌙 ikon `toggle()` chaqiradi. `app.dart`
// `themeModeProvider`'ni watch qiladi va `AppColors.brightness` ni
// o'rnatib, mos ThemeData quradi. Tanlov SharedPreferences'da saqlanadi.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  dark,
  light;

  Brightness get brightness =>
      this == AppThemeMode.dark ? Brightness.dark : Brightness.light;
}

class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  ThemeModeNotifier() : super(AppThemeMode.dark) {
    _load();
  }

  static const _key = 'app.theme_mode.v1';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getString(_key) == 'light'
          ? AppThemeMode.light
          : AppThemeMode.dark;
    } catch (_) {
      // best-effort — default dark qoladi
    }
  }

  /// Light ↔ dark almashtirish + saqlash.
  Future<void> toggle() async {
    final next = state == AppThemeMode.dark
        ? AppThemeMode.light
        : AppThemeMode.dark;
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        next == AppThemeMode.light ? 'light' : 'dark',
      );
    } catch (_) {
      // best-effort
    }
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, AppThemeMode>((ref) {
      return ThemeModeNotifier();
    });
