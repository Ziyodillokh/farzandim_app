// ─────────────────────────────────────────────────────────────────────
// AppPairingState — pairing oqimi holatining modeli
// ─────────────────────────────────────────────────────────────────────
//
// Pairing 4 ta holatdan iborat: notPaired → pairing → paired (yoki error).
// Bu klass `PairingNotifier` (Riverpod StateNotifier) tomonidan
// boshqariladi. Immutable — har o'zgarishda `copyWith()` orqali yangi
// nusxa hosil qilinadi.

enum PairingStatus {
  /// Hali ulanmagan — Welcome/Pairing ekranlarida ko'rinadi.
  notPaired,

  /// Ulanmoqda — kod tekshirish + Firestore yozish jarayoni.
  /// UI loading spinner ko'rsatadi.
  pairing,

  /// Muvaffaqiyatli ulangan — Dashboard ko'rsatiladi.
  paired,

  /// Backend 0.6.0: pair request yaratildi, parent tasdiqi kutilmoqda.
  /// `pairRequestId` + `expiresAt` saqlanadi, polling ekrani ko'rsatiladi.
  awaitingParent,

  /// Xato — `errorMessage`'da sabab.
  error,
}

class AppPairingState {
  const AppPairingState({
    this.status = PairingStatus.notPaired,
    this.parentUid,
    this.childId,
    this.childName,
    this.currentUserId,
    this.errorMessage,
    this.pairRequestId,
    this.pairRequestExpiresAt,
  });

  final PairingStatus status;
  final String? parentUid;
  final String? childId;
  final String? childName;
  final String? currentUserId;
  final String? errorMessage;

  /// Backend 0.6.0 — `awaitingParent` holatida saqlanadi.
  final String? pairRequestId;
  final DateTime? pairRequestExpiresAt;

  bool get isPaired =>
      status == PairingStatus.paired && parentUid != null && childId != null;

  AppPairingState copyWith({
    PairingStatus? status,
    String? parentUid,
    String? childId,
    String? childName,
    String? currentUserId,
    String? errorMessage,
    String? pairRequestId,
    DateTime? pairRequestExpiresAt,
  }) {
    return AppPairingState(
      status: status ?? this.status,
      parentUid: parentUid ?? this.parentUid,
      childId: childId ?? this.childId,
      childName: childName ?? this.childName,
      currentUserId: currentUserId ?? this.currentUserId,
      errorMessage: errorMessage ?? this.errorMessage,
      pairRequestId: pairRequestId ?? this.pairRequestId,
      pairRequestExpiresAt:
          pairRequestExpiresAt ?? this.pairRequestExpiresAt,
    );
  }
}
