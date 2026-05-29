// ─────────────────────────────────────────────────────────────────────
// VoiceMessageService — no-op stub (Sprint 4.4.22 cleanup davomi)
// ─────────────────────────────────────────────────────────────────────
//
// Eski Firestore implementatsiya olib tashlandi. Hozir voice xabar
// yuborish `BackendVoiceMessageRepository` orqali (per-message tap'da
// `markAsRead`). Bu service legacy reference'lar buzilmasligi uchun
// no-op qoldirildi va keyingi cleanup'da butunlay o'chiriladi.

class VoiceMessageService {
  /// Bola chat ekranni ochganda chaqirilgan — endi har xabar individual
  /// `chat_bubble` tap'da `BackendVoiceMessageRepository.markAsRead`
  /// orqali markaylanadi. Bulk batch kerak emas (silent no-op).
  Future<void> markAllAsSeenByChild({
    required String parentUid,
    required String childId,
  }) async {
    // No-op: per-message read receipts hozir bubble onTap orqali.
  }
}
