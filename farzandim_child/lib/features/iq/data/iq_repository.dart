// IQ test ma'lumot manbai — server (`/api/iq`, CHILD token;
// docs/IQ-REJA.md §4). Savollar va forma faqat serverda tanlanadi.

import 'package:farzandim_child/features/iq/domain/iq_models.dart';

enum IqErrorCode {
  /// Yosh ham, tug'ilgan sana ham yo'q — profilda yosh kiritiladi.
  ageRequired,

  /// Yosh 9–20 oralig'ida emas.
  ageOutOfRange,

  /// Qayta topshirish hali mumkin emas ([IqException.nextAvailableAt]).
  retakeTooSoon,

  /// Darajada savol yo'q.
  noItems,

  /// Sessiya yopiq (yakunlangan yoki 24 soatdan eski).
  sessionClosed,

  /// Hamma savolga javob berilmagan.
  unanswered,

  /// Variant yoki savol bu sessiyaniki emas.
  invalidChoice,
  sessionNotFound,

  /// Server IQ testni hali bilmaydi (404, kodsiz) — kirish nuqtalari yashirin.
  unavailable,
  network,
  unknown,
}

class IqException implements Exception {
  const IqException(this.code, {this.message, this.nextAvailableAt});

  final IqErrorCode code;
  final String? message;
  final DateTime? nextAvailableAt;

  @override
  String toString() =>
      'IqException($code${message == null ? '' : ': $message'})';
}

abstract interface class IqRepository {
  Future<IqOverview> loadOverview();

  /// Yangi yoki davom etayotgan sessiya (idempotent).
  Future<IqSession> startSession();

  /// Javobni saqlash (to'g'riligi qaytarilmaydi).
  Future<void> saveAnswer({
    required String sessionId,
    required String itemId,
    required String choice,
    int? durationMs,
  });

  /// Yakunlash (idempotent) — natija bilan.
  Future<IqSession> completeSession(String sessionId);
}
