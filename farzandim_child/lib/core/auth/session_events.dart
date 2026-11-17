// ─────────────────────────────────────────────────────────────────────
// SessionEvents — server bola sessiyasini bekor qilganini UI'ga yetkazadi
// ─────────────────────────────────────────────────────────────────────
//
// Backend sessiyani bekor qiladi (bola boshqa qurilmaga ulandi, ota-ona
// kodni yangiladi yoki profilni o'chirdi). WS `child:unpaired` signali
// uxlab yotgan iOS ilovasiga yetib bormaydi — ilova "ulangan" holatda
// qolib, har so'rov 401 qaytarardi. Refresh ham ANIQ rad etilganda
// (`dio_client.dart`) shu yerga signal yuboriladi; PairingNotifier uni
// eshitib lokal ulanishni tozalaydi va bolani /pairing'ga qaytaradi.
//
// Hodisa qaysi akkauntniki ekanini bildiradi (`scope` — token kalitlari
// prefiksi): bitta qurilmada qurilma egasi va mehmon akkauntlar bo'lishi
// mumkin, har biri faqat o'z hodisasiga javob beradi.
//
// Riverpod'siz — `createBackendDio` provider'siz ham ishlatiladi.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bekor qilingan sessiya.
@immutable
class SessionRevoked {
  const SessionRevoked({this.scope = '', this.reason});

  /// `TokenStorage.keyPrefix`: `''` — qurilma egasi (oila kodi yoki asosiy
  /// login), `acct_<childId>_` — shu qurilmadagi mehmon akkaunt.
  final String scope;

  /// Server sababi (`SESSION_REVOKED.reason` yoki WS `session:closed.reason`:
  /// RECOVERED | PERMISSIONS_CHANGED | SIGNED_IN_ELSEWHERE | SIGNED_OUT),
  /// bo'lmasa `null`.
  final String? reason;

  bool get isOwner => scope.isEmpty;
}

abstract final class SessionEvents {
  static final StreamController<SessionRevoked> _revoked =
      StreamController<SessionRevoked>.broadcast();

  /// Sessiya bekor qilinganda hodisa.
  static Stream<SessionRevoked> get revoked => _revoked.stream;

  /// Qurilma egasi sessiyasining server bergan yopilish sababi (v5). Fon
  /// isolate'i refresh paytida bilib qolsa ham, ilova keyingi ochilishda
  /// «Bu qurilmada chiqildi» (A12) ekranida shu sababni ko'rsatadi.
  static const ownerReasonKey = 'g5_owner_closed_reason_v1';

  static void notifyRevoked({String? reason, String scope = ''}) {
    _revoked.add(SessionRevoked(scope: scope, reason: reason));
    if (scope.isEmpty && reason != null) {
      unawaited(_rememberOwnerReason(reason));
    }
  }

  static Future<void> _rememberOwnerReason(String reason) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ownerReasonKey, reason);
    } on Object catch (e) {
      debugPrint('[session] sabab saqlanmadi: ${e.runtimeType}');
    }
  }
}
