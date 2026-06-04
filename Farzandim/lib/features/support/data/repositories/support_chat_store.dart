// ─────────────────────────────────────────────────────────────────────
// SupportChatStore — chat tarixini SharedPreferences'ga saqlash
// ─────────────────────────────────────────────────────────────────────
//
// Faqat matn + biriktirma metama'lumotlari saqlanadi (rasm bytes / fayl
// yo'li transient — saqlanmaydi). Web-xavfsiz (dart:io ishlatilmaydi).

import 'dart:convert';

import 'package:farzandim/features/support/data/models/support_message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final supportChatStoreProvider = Provider<SupportChatStore>((ref) {
  return const SupportChatStore();
});

class SupportChatStore {
  const SupportChatStore();

  static const _key = 'support.chat.messages.v1';

  Future<List<SupportMessage>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <SupportMessage>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <SupportMessage>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(SupportMessage.fromJson)
          .toList(growable: false);
    } catch (_) {
      return <SupportMessage>[];
    }
  }

  Future<void> save(List<SupportMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded =
        jsonEncode(messages.map((m) => m.toJson()).toList(growable: false));
    await prefs.setString(_key, encoded);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
