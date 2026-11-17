// Akkauntga bog'liq mahalliy ma'lumotlar. Qurilmada bir nechta bola akkaunti
// bo'lishi mumkin (A10), shuning uchun shaxsiy ma'lumot kalitlari bola id'si
// bilan ajratiladi: `<asos>@<childId>` (tugallanmagan mashq, xatcho'plar,
// oxirgi audiokitob, maktab kodi cheklovi). Bir bolaniki boshqasiga
// ko'rinmaydi va chiqishda faqat o'shaniki o'chiriladi. Hech kim kirmagan
// bo'lsa (`childId` yo'q) — hech narsa o'qilmaydi va yozilmaydi.

import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/growth/ovoz/data/voice_outbox.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [base] kalitining [childId] akkauntiga tegishli nusxasi.
String accountKey(String base, String childId) => '$base@$childId';

/// Faol akkaunt bolasining id'si (`null` — hech kim kirmagan). Mehmon akkaunt
/// faol bo'lsa `pairingStateProvider` shu bolaniki (`AccountScope`).
final currentChildIdProvider = Provider<String?>(
  (ref) => ref.watch(pairingStateProvider.select((s) => s.childId)),
);

/// Faol akkaunt uchun [base] kaliti; `null` — hech kim kirmagan (o'qilmaydi
/// ham, yozilmaydi ham). Akkaunt almashsa qaramlar qayta quriladi.
final currentAccountKeyProvider = Provider.family<String?, String>((ref, base) {
  final childId = ref.watch(currentChildIdProvider);
  return childId == null ? null : accountKey(base, childId);
});

/// [childId] akkauntining qurilmadagi shaxsiy ma'lumotlarini o'chiradi:
/// `@<childId>` bilan tugaydigan barcha SharedPreferences kalitlari va
/// yuborilmagan murojaatlar navbati (secure storage). Akkauntdan chiqishda
/// chaqiriladi; xato logga yoziladi va chiqishni to'xtatmaydi.
Future<void> clearAccountLocalData(String childId) async {
  final suffix = accountKey('', childId);
  try {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.endsWith(suffix)).toList();
    await Future.wait(keys.map(prefs.remove));
  } on Object catch (e) {
    debugPrint('[accounts] mahalliy ma\'lumot o\'chirilmadi: ${e.runtimeType}');
  }
  try {
    await const SecureVoiceOutboxStore().write(voiceOutboxKey(childId), null);
  } on Object catch (e) {
    debugPrint(
      '[accounts] murojaatlar navbati o\'chirilmadi: ${e.runtimeType}',
    );
  }
}
