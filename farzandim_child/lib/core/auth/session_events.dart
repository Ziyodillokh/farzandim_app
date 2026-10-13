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
// Riverpod'siz — `createBackendDio` provider'siz ham ishlatiladi.

import 'dart:async';

abstract final class SessionEvents {
  static final StreamController<void> _revoked =
      StreamController<void>.broadcast();

  /// Sessiya bekor qilinganda hodisa.
  static Stream<void> get revoked => _revoked.stream;

  static void notifyRevoked() => _revoked.add(null);
}
