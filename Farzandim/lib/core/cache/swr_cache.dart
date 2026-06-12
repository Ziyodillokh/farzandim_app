// ─────────────────────────────────────────────────────────────────────
// SwrCache — stale-while-revalidate disk keshi (NET-07)
// ─────────────────────────────────────────────────────────────────────
//
// Maqsad: ekranlar serverni kutmasdan DARHOL oxirgi ma'lumotni ko'rsatsin
// (spinner o'rniga), yangisi esa fonda kelib UI'ni yangilasin. 100k user
// masshtabida takroriy so'rovlar va "bo'sh kutish" UX'i yo'qoladi.
//
// Dizayn qarorlari:
//   • XOM backend-JSON saqlanadi (provider o'zi mavjud fromJson bilan
//     dekodlaydi) — model evolyutsiyasida kesh buzilmaydi, dekod xatosi
//     shunchaki "kesh yo'q" deb qaraladi.
//   • SharedPreferences — kichik/o'rta payloadlar uchun yetarli (bizning
//     eng kattasi installed-apps ~100-300KB). Har yozuvda savedAt bor.
//   • XAVFSIZLIK: `clearAll()` logout/sessiya-tugashida chaqiriladi —
//     keyingi akkaunt oldingisining ma'lumotini KO'RMAYDI.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Barcha SWR kalitlari shu prefiks bilan — clearAll faqat shularni o'chiradi.
const _kPrefix = 'swr_cache_v1:';

/// Disk SWR keshi — statik util (holatsiz).
class SwrCache {
  SwrCache._();

  /// Keshdan o'qish. Yo'q/buzuq bo'lsa `null`.
  /// Qaytadi: (xom JSON qiymat, saqlangan vaqt).
  static Future<(Object?, DateTime)?> read(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_kPrefix$key');
      if (raw == null || raw.isEmpty) return null;
      final envelope = jsonDecode(raw) as Map<String, dynamic>;
      final savedAtMs = envelope['savedAt'] as int?;
      if (savedAtMs == null) return null;
      return (
        envelope['data'],
        DateTime.fromMillisecondsSinceEpoch(savedAtMs),
      );
    } catch (e) {
      debugPrint('SwrCache.read($key): $e');
      return null;
    }
  }

  /// Keshga yozish — `data` jsonEncode qilinadigan bo'lishi shart
  /// (backend javobining xom List/Map'i).
  static Future<void> write(String key, Object? data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_kPrefix$key',
        jsonEncode({
          'savedAt': DateTime.now().millisecondsSinceEpoch,
          'data': data,
        }),
      );
    } catch (e) {
      debugPrint('SwrCache.write($key): $e');
    }
  }

  /// Bitta kalitni o'chirish.
  static Future<void> evict(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_kPrefix$key');
    } catch (_) {}
  }

  /// BARCHA SWR keshini tozalash — logout / sessiya tugashida SHART
  /// (boshqa akkaunt ma'lumoti ko'rinib qolmasin).
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs
          .getKeys()
          .where((k) => k.startsWith(_kPrefix))
          .toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
      debugPrint('SwrCache.clearAll: ${keys.length} kalit tozalandi');
    } catch (e) {
      debugPrint('SwrCache.clearAll: $e');
    }
  }
}
