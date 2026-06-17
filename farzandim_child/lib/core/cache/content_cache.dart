// ─────────────────────────────────────────────────────────────────────
// ContentCache — kontent ro'yxatlari uchun lokal (persistent) cache
// ─────────────────────────────────────────────────────────────────────
//
// MUAMMO: video/audiokitob/kitob ro'yxatlari har ochilganda to'liq
// backend'dan qayta yuklanardi. Sekin internetda bu sezilarli kechikish
// berardi (bola "malumotlar sekin kelyapti" deydi) va offline'da umuman
// bo'sh ko'rinardi.
//
// YECHIM: backend muvaffaqiyatli javob berganda RAW JSON `items` ro'yxati
// SharedPreferences'ga yoziladi. Keyingi ochilishda UI cache'dan DARHOL
// to'ladi (stale-while-revalidate) — fon'da yangi ma'lumot kelguncha bola
// allaqachon ro'yxatni ko'radi. Offline bo'lsa ham oxirgi ko'rgani qoladi.
//
// Nega Hive/sqflite emas: loyihada bunday dep yo'q; ro'yxatlar kichik
// (50 element × kichik JSON), SharedPreferences ular uchun yetarli va
// qo'shimcha native dep talab qilmaydi.
//
// Saqlanadigan format: { "ts": <epochMs>, "items": [ ...rawMaps ] }
// `ts` — yoshini bilish uchun (juda eski cache'ni e'tiborsiz qoldirish).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

class ContentCache {
  ContentCache._();

  static const String _prefix = 'content_cache_v1_';

  /// Bundan eski cache "haddan tashqari eski" — baribir ko'rsatamiz (offline
  /// holatda nimadir yo'qdan yaxshi), lekin log qilamiz. Hard-expire YO'Q:
  /// stale-while-revalidate fon refresh baribir yangilaydi.
  static const Duration staleAfter = Duration(days: 7);

  /// Backend qaytargan RAW `items` ro'yxatini cache'ga yozadi (fire-and-forget
  /// chaqirilishi mumkin — xato bo'lsa jim o'tadi, asosiy oqimni buzmaydi).
  static Future<void> save(String key, List<dynamic> rawItems) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Eslatma: Date.now() o'rniga DateTime — bu Flutter app kodi (Workflow
      // skripti emas), shuning uchun xavfsiz.
      final payload = <String, dynamic>{
        'ts': DateTime.now().millisecondsSinceEpoch,
        'items': rawItems,
      };
      await prefs.setString('$_prefix$key', jsonEncode(payload));
    } catch (e) {
      // Cache yozolmaslik — kechiriladigan xato (masalan kvota). Jim o'tamiz.
      debugPrint('ContentCache.save($key) skipped: $e');
    }
  }

  /// Cache'dagi RAW `items` ro'yxatini qaytaradi (yo'q/buzuq bo'lsa null).
  /// Parsing chaqiruvchi (repository) tomonida — o'sha model mapperlari bilan.
  static Future<List<dynamic>?> read(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final items = decoded['items'];
      if (items is! List) return null;
      final ts = (decoded['ts'] as num?)?.toInt() ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > staleAfter.inMilliseconds) {
        debugPrint('ContentCache.read($key): stale (${Duration(milliseconds: age).inDays}d)');
      }
      return items;
    } catch (e) {
      debugPrint('ContentCache.read($key) failed: $e');
      return null;
    }
  }

  /// Bitta cache yozuvini o'chiradi (masalan logout/unpair).
  static Future<void> clear(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefix$key');
    } catch (_) {/* jim */}
  }
}
