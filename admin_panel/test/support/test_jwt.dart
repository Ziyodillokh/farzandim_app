import 'dart:convert';

/// Unsigned JWT with a far-future `exp` (client decode only; tests only).
String testAccessJwt({int expSecondsSinceEpoch = 4102444800}) {
  final header =
      base64Url.encode(utf8.encode(jsonEncode({'alg': 'none', 'typ': 'JWT'})))
          .replaceAll('=', '');
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'exp': expSecondsSinceEpoch})))
      .replaceAll('=', '');
  const sig = 'e30';
  return '$header.$payload.$sig';
}
