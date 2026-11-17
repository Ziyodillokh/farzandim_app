// ─────────────────────────────────────────────────────────────────────
// Kutilayotgan taklif kodi (deep link `farzandimedu.uz/link?code=…`)
// ─────────────────────────────────────────────────────────────────────
//
// Havola ilovani ochganda ota-ona hali kirmagan bo'lishi mumkin: kod shu
// yerda eslab qolinadi (faqat xotirada), kirgach router uni maktabga ulanish
// sahifasiga olib boradi va o'chiradi. Yuborishni baribir ota-ona bosadi.

import 'package:flutter_riverpod/flutter_riverpod.dart';

final pendingInviteCodeProvider = StateProvider<String?>((ref) => null);
