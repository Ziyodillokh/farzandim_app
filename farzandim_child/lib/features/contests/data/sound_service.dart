// ─────────────────────────────────────────────────────────────────────
// SoundService — quiz sound effects (placeholder)
// ─────────────────────────────────────────────────────────────────────
//
// Audio fayllar `assets/sounds/` papkasiga keyinroq qo'shiladi.
// Hozircha faqat debugPrint — UX flow ishlashi uchun majburiy emas.

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundService {
  SoundService._();

  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playCorrect() => _play('correct');
  static Future<void> playWrong() => _play('wrong');
  static Future<void> playTimeout() => _play('timeout');
  static Future<void> playVictory() => _play('victory');

  static Future<void> _play(String name) async {
    try {
      // assets/sounds/$name.mp3 — fayl bo'lsa o'ynaydi, bo'lmasa silent
      await _player.play(AssetSource('sounds/$name.mp3'));
    } catch (_) {
      if (kDebugMode) {
        debugPrint('🔊 SOUND: $name (placeholder, asset yo\'q)');
      }
    }
  }
}
