// Kelajak xatolari: server `code`i (`{ statusCode, message, code }`) ilova
// kodiga aylantiriladi. Server `message`i inglizcha va UI uchun emas —
// UI faqat [KelajakErrorCode] bo'yicha matn tanlaydi.

enum KelajakErrorCode {
  /// Yosh ham, tug'ilgan sana ham yo'q — profilda yosh kiritiladi.
  ageRequired,

  /// Yosh 7–18 oralig'ida emas — Kelajak ko'rsatilmaydi.
  ageOutOfRange,

  /// Bu test uchun bolaning yosh guruhida savol yo'q.
  noQuestions,

  /// Server bu test turini bilmaydi.
  unknownType,

  /// Sessiya yopiq (yakunlangan yoki o'tgan kunda boshlangan).
  sessionClosed,

  /// Majburiy savollarga javob berilmagan ([KelajakException.remaining]).
  unanswered,

  /// Javob qiymati noto'g'ri (variantda yo'q, matn juda uzun).
  invalidAnswer,

  /// Savol bu sessiyada yo'q.
  questionNotInSession,

  /// Sessiya topilmadi (`SESSION_NOT_FOUND`).
  sessionNotFound,

  /// Serverda ochiq javoblarni shifrlash kaliti sozlanmagan.
  notConfigured,

  /// Server Kelajakni hali bilmaydi (404, kodsiz) — kirish nuqtalari
  /// yashiriladi.
  unavailable,

  /// Internet yo'q / javob kelmadi.
  network,
  unknown,
}

class KelajakException implements Exception {
  const KelajakException(this.code, {this.message, this.remaining = const []});

  final KelajakErrorCode code;

  /// Server xabari (faqat diagnostika uchun).
  final String? message;

  /// `unanswered`: javobsiz majburiy savollar id'lari.
  final List<String> remaining;

  @override
  String toString() =>
      'KelajakException($code${message == null ? '' : ': $message'})';
}
