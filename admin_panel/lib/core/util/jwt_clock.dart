import 'dart:convert';

String _padBase64Url(String segment) {
  final m = segment.length % 4;
  if (m == 0) {
    return segment;
  }
  return segment + ('=' * (4 - m));
}

/// Client-side JWT `exp` (seconds since epoch). Does not verify signature.
int? readJwtExpSeconds(String jwt) {
  final parts = jwt.split('.');
  if (parts.length != 3) {
    return null;
  }
  try {
    final bytes = base64Url.decode(_padBase64Url(parts[1]));
    final map = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final exp = map['exp'];
    if (exp is int) {
      return exp;
    }
    if (exp is num) {
      return exp.toInt();
    }
  } catch (_) {
    return null;
  }
  return null;
}

bool isJwtExpired(String jwt, {DateTime? now, Duration skew = const Duration(seconds: 45)}) {
  final expSec = readJwtExpSeconds(jwt);
  if (expSec == null) {
    return false;
  }
  final exp = DateTime.fromMillisecondsSinceEpoch(expSec * 1000, isUtc: true);
  final n = (now ?? DateTime.now()).toUtc();
  return !exp.isAfter(n.add(skew));
}

bool shouldRefreshBeforeRequest(
  String jwt, {
  Duration lead = const Duration(minutes: 2),
  DateTime? now,
}) {
  final expSec = readJwtExpSeconds(jwt);
  if (expSec == null) {
    return false;
  }
  final exp = DateTime.fromMillisecondsSinceEpoch(expSec * 1000, isUtc: true);
  final n = (now ?? DateTime.now()).toUtc();
  return !exp.isAfter(n.add(lead));
}
