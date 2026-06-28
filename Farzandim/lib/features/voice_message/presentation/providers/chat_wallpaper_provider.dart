// Chat orqa foni tanlovi (Telegram uslubidagi wallpaper).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tayyor gradient fonlar.
const List<List<Color>> chatWallpaperPresets = [
  [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)], // Tungi ko'k
  [Color(0xFF232526), Color(0xFF414345)], // Grafit
  [Color(0xFF134E5E), Color(0xFF71B280)], // O'rmon
  [Color(0xFF42275A), Color(0xFF734B6D)], // Siyohrang
  [Color(0xFF1A2980), Color(0xFF26D0CE)], // Okean
  [Color(0xFF3E5151), Color(0xFFDECBA4)], // Qum
  [Color(0xFF0B486B), Color(0xFFF56217)], // Quyobotish
  [Color(0xFF16222A), Color(0xFF3A6073)], // Po'lat
];

/// Default fon kaliti.
const String kChatWallpaperDefault = 'default';

/// Tanlov SharedPreferences'da saqlanadi (barcha chatlar uchun bitta).
/// Qiymat: 'default', 'preset:N' yoki 'file:<yo'l>'.
class ChatWallpaperNotifier extends StateNotifier<String> {
  ChatWallpaperNotifier() : super(kChatWallpaperDefault) {
    _load();
  }

  static const _key = 'chat.wallpaper.v1';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getString(_key) ?? kChatWallpaperDefault;
    } catch (_) {
      // best-effort — default qoladi
    }
  }

  Future<void> _save(String value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, value);
    } catch (_) {
      // best-effort
    }
  }

  Future<void> setDefault() => _save(kChatWallpaperDefault);

  Future<void> setPreset(int index) => _save('preset:$index');

  /// `path` — app docs'ga ko'chirilgan doimiy rasm yo'li.
  Future<void> setImage(String path) => _save('file:$path');
}

final chatWallpaperProvider =
    StateNotifierProvider<ChatWallpaperNotifier, String>((ref) {
      return ChatWallpaperNotifier();
    });

/// Wallpaper kalitidan preset indeksini ajratadi (yo'q bo'lsa `null`).
int? chatWallpaperPresetIndex(String key) {
  if (!key.startsWith('preset:')) return null;
  return int.tryParse(key.substring('preset:'.length));
}

/// Wallpaper kalitidan fayl yo'lini ajratadi (yo'q bo'lsa `null`).
String? chatWallpaperFilePath(String key) {
  if (!key.startsWith('file:')) return null;
  return key.substring('file:'.length);
}
