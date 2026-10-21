// Kiosk QR'ini tanish: havola, xom token, ota-ona ulash QR'i va boshqalar.

import 'package:farzandim_child/features/school/domain/kiosk_qr.dart';
import 'package:flutter_test/flutter_test.dart';

/// Haqiqiy shakldagi token: base64url(JSON) + "." + base64url(HMAC).
const _token =
    'eyJzIjoiMWQ5ZjJmYzAtNzE5Yi00YjQyLWE4ZjktNjQwYWVjN2JkODBjIiwidCI6NTg3NjY0NjN9'
    '.Qm9oN0Z5d2hOTXhQcF9sQ0FfbW5ScEdQMXhkV2Y3ZGg';

String? _tokenOf(String? raw) => switch (parseKioskQr(raw)) {
  KioskQrCheckIn(:final token) => token,
  _ => null,
};

void main() {
  test('kiosk havolasidan token olinadi', () {
    expect(_tokenOf('parvoz-school://checkin?code=$_token'), _token);
    // Atrofdagi bo'shliq va katta harfli sxema / host.
    expect(_tokenOf('  PARVOZ-SCHOOL://CheckIn?code=$_token\n'), _token);
    // Havolada kod serverda tekshiriladi (format bu yerda talab qilinmaydi).
    expect(_tokenOf('parvoz-school://checkin?code=MOCK-1234'), 'MOCK-1234');
  });

  test('xom token (havolasiz) qabul qilinadi', () {
    expect(_tokenOf(_token), _token);
    expect(_tokenOf('abc_DEF-1.xyz'), 'abc_DEF-1.xyz');
  });

  test('ota-ona ilovasining ulash QR\'i alohida aniqlanadi', () {
    expect(
      parseKioskQr('farzandim:repair:0123456789abcdef0123456789abcdef'),
      isA<KioskQrPairing>(),
    );
    expect(parseKioskQr(' Farzandim:Repair:abc '), isA<KioskQrPairing>());
  });

  test('boshqa QR\'lar tanilmaydi', () {
    for (final raw in [
      null,
      '',
      '   ',
      'parvoz-school://checkin',
      'parvoz-school://checkin?code=',
      'parvoz-school://other?code=$_token',
      'https://farzandimedu.uz/checkin?code=$_token',
      // Pairing ekranidagi oddiy repair token (nuqtasiz) — kiosk emas.
      '0123456789abcdef0123456789abcdef',
      'a.b.c',
      'salom dunyo',
      'abc.def ghi',
    ]) {
      expect(parseKioskQr(raw), isA<KioskQrUnknown>(), reason: '$raw');
    }
  });

  test('buzuq foiz-kodlangan havola xatosiz tanilmaydi', () {
    for (final code in ['%FF', '%C3%28', '%E0%A4%A']) {
      final raw = 'parvoz-school://checkin?code=$code';
      expect(() => parseKioskQr(raw), returnsNormally, reason: raw);
      expect(parseKioskQr(raw), isA<KioskQrUnknown>(), reason: raw);
    }
  });

  test('server chegarasidan uzun token rad etiladi', () {
    final long = '${'a' * kKioskTokenMaxLength}.b';
    expect(parseKioskQr(long), isA<KioskQrUnknown>());
    expect(
      parseKioskQr('parvoz-school://checkin?code=$long'),
      isA<KioskQrUnknown>(),
    );
  });
}
