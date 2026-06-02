/// Redacts secrets from strings and maps before logging.
abstract final class LogSanitizer {
  static String stringForLog(String input) {
    var s = input;
    s = s.replaceAllMapped(RegExp(r'Bearer\s+[\w-]+\.[\w-]+\.[\w-]+'), (_) => 'Bearer ***');
    s = s.replaceAllMapped(RegExp(r'(access_token|refresh_token|password|authorization)\s*[:=]\s*[^\s&,"]+', caseSensitive: false),
        (m) => '${m.group(1)}=***');
    return s;
  }

  static Object? valueForLog(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      return stringForLog(value);
    }
    if (value is Map) {
      final out = <String, dynamic>{};
      for (final e in value.entries) {
        final k = e.key.toString();
        final lower = k.toLowerCase();
        if (lower.contains('password') ||
            lower.contains('token') ||
            lower == 'authorization') {
          out[k] = '***';
        } else if (e.value is Map) {
          out[k] = valueForLog(e.value);
        } else if (e.value is String) {
          out[k] = stringForLog(e.value as String);
        } else {
          out[k] = e.value;
        }
      }
      return out;
    }
    return value;
  }
}
