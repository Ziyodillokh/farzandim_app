// ─────────────────────────────────────────────────────────────────────
// TokenMemory — isolate ichidagi UMUMIY token xotirasi
// ─────────────────────────────────────────────────────────────────────
//
// Shu isolate'dagi barcha `TokenStorage()` nusxalari bitta xotirani
// ishlatadi (kalit — `TokenStorage.keyPrefix`: qurilma egasi `''`, mehmon
// `acct_<childId>_`). Avval har HTTP so'rov secure storage'ni o'qirdi:
// fon isolate'ida soatiga ~2 500 marta MasterKey + EncryptedSharedPreferences
// qurilardi (rob-dart-securestorage-per-request). Endi storage faqat
// birinchi ishlatishda, 401 kelganda va saqlash/tozalashda ishlatiladi.
//
// `generation` — shu isolate'da yozuv (saqlash/tozalash) bo'lganini bildiradi:
// undan oldin boshlangan storage o'qishi yangi qiymat ustiga yozilmaydi.

import 'package:farzandim_child/core/auth/token_pair.dart';
import 'package:flutter/foundation.dart';

/// Secure storage o'qish natijasi. `failed` — o'qib bo'lmadi (NOMA'LUM,
/// hech qachon "chiqib ketgan" degani emas).
@immutable
class TokenRead {
  const TokenRead.found(TokenPair this.pair) : failed = false, error = null;
  const TokenRead.absent() : pair = null, failed = false, error = null;
  const TokenRead.failed(this.error) : pair = null, failed = true;

  final TokenPair? pair;
  final bool failed;
  final Object? error;

  /// Xatosiz o'qildi va hech narsa yo'q.
  bool get isCleanAbsent => !failed && pair == null;
}

class TokenMemory {
  TokenMemory();

  /// Shu isolate'ning yagona xotirasi (statik — isolate umri bo'yi).
  static final TokenMemory isolate = TokenMemory();

  final Map<String, TokenPair> _pairs = {};
  final Map<String, int> _generations = {};
  final Map<String, Future<TokenRead>> _reads = {};
  final Set<String> _markedPresent = {};

  TokenPair? pairOf(String scope) => _pairs[scope];

  int generationOf(String scope) => _generations[scope] ?? 0;

  /// Shu isolate saqladi (login yoki refresh javobi).
  void put(String scope, TokenPair pair) {
    _pairs[scope] = pair;
    _changed(scope);
  }

  /// Shu isolate tozaladi.
  void forget(String scope) {
    _pairs.remove(scope);
    _markedPresent.remove(scope);
    _changed(scope);
  }

  /// Storage'dan o'qilgan juftni qabul qiladi — o'qish boshlangandan beri
  /// shu isolate yozmagan bo'lsa va u xotiradagidan eskiroq bo'lmasa.
  void adopt(String scope, TokenPair stored, {required int seenGeneration}) {
    if (generationOf(scope) != seenGeneration) return;
    final current = _pairs[scope];
    if (current != null &&
        isOlderToken(stored.accessToken, current.accessToken)) {
      return;
    }
    _pairs[scope] = stored;
  }

  Future<TokenRead>? pendingRead(String scope) => _reads[scope];

  void beginRead(String scope, Future<TokenRead> read) => _reads[scope] = read;

  void endRead(String scope, Future<TokenRead> read) {
    if (identical(_reads[scope], read)) _reads.remove(scope);
  }

  /// "Tokenlar saqlangan" belgisi shu isolate'da allaqachon yozilganmi.
  bool isMarkedPresent(String scope) => _markedPresent.contains(scope);

  void markPresent(String scope) => _markedPresent.add(scope);

  void _changed(String scope) {
    _generations[scope] = generationOf(scope) + 1;
    // Yozuvdan oldin boshlangan o'qishga yangi chaqiruvchilar qo'shilmasin.
    _reads.remove(scope);
  }

  @visibleForTesting
  void reset() {
    _pairs.clear();
    _generations.clear();
    _reads.clear();
    _markedPresent.clear();
  }
}
