import 'dart:collection';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// `FlutterSecureStorage.setMockInitialValues` uchun boshqariladigan "disk":
/// o'qishlarni sanaydi, Android'dagi "sticky null" (Keystore xatosidan keyin
/// hamma o'qish `null`) va o'qish xatosini taqlid qiladi.
class SecureStorageFake extends MapBase<String, String> {
  SecureStorageFake([Map<String, String>? initial]) {
    if (initial != null) _data.addAll(initial);
  }

  final Map<String, String> _data = {};
  final Map<String, int> reads = {};

  /// `true` — har o'qish `null` (yozuvlar saqlanadi).
  bool stickyNull = false;

  /// `true` — har o'qish PlatformException tashlaydi.
  bool failReads = false;

  /// O'qishdan oldin chaqiriladi (masalan boshqa isolate yozuvini taqlid).
  void Function(String key, int readCount)? onRead;

  /// O'rnatadi va qaytaradi.
  static SecureStorageFake install([Map<String, String>? initial]) {
    final fake = SecureStorageFake(initial);
    FlutterSecureStorage.setMockInitialValues(fake);
    return fake;
  }

  int readsOf(String key) => reads[key] ?? 0;

  /// Xom qiymat (o'qish hisoblanmaydi).
  String? raw(String key) => _data[key];

  /// `auth.tokens.v2` yozuvini o'qilgan JSON sifatida.
  Map<String, dynamic>? combined([String prefix = '']) {
    final value = _data['${prefix}auth.tokens.v2'];
    return value == null ? null : jsonDecode(value) as Map<String, dynamic>;
  }

  @override
  String? operator [](Object? key) {
    final k = key as String;
    final count = (reads[k] ?? 0) + 1;
    reads[k] = count;
    onRead?.call(k, count);
    if (failReads) {
      throw PlatformException(code: 'Keystore', message: 'decrypt failed');
    }
    if (stickyNull) return null;
    return _data[k];
  }

  @override
  void operator []=(String key, String value) => _data[key] = value;

  @override
  void clear() => _data.clear();

  @override
  Iterable<String> get keys => _data.keys;

  @override
  String? remove(Object? key) => _data.remove(key);

  @override
  bool containsKey(Object? key) => !stickyNull && _data.containsKey(key);
}
