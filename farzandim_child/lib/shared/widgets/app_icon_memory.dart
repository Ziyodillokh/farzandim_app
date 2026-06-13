// ─────────────────────────────────────────────────────────────────────
// AppIconMemory — base64 ilova ikonkasini SAMARALI ko'rsatish
// ─────────────────────────────────────────────────────────────────────
//
// MUAMMO: ilova ro'yxatlarida `Image.memory(base64Decode(s))` to'g'ridan-
// to'g'ri build ichida chaqirilardi. Har rebuild'da:
//   1) base64Decode — CPU'da string → bytes (har kadr)
//   2) Image.memory — bytes → bitmap (cacheWidth yo'q → to'liq o'lcham)
// Natija: ko'p ikonali ro'yxatni scroll qilganda UI thread bloklanadi
// va ilova "qotib qoladi".
//
// YECHIM:
//   - `base64Decode` natijasi statik LRU-ga cache (string → Uint8List).
//     Bir xil base64 ikkinchi marta dekod qilinmaydi.
//   - `Image.memory` `cacheWidth` bilan — Flutter kichik bitmap dekodlaydi
//     (ikonka 40-48px ko'rsatiladi, manba 192px bo'lsa ham).
//   - `gaplessPlayback: true` — rebuild'da miltillamaydi.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Dekod qilingan baytlar cache'i — base64 string bo'yicha.
/// Oddiy Map (LRU emas, lekin ilova ikonkalar soni cheklangan ~50-100,
/// xotira muammosi bo'lmaydi). Hot restart'da tozalanadi.
final Map<String, Uint8List?> _decodeCache = {};

Uint8List? _decodeCached(String b64) {
  // Allaqachon dekod qilingan bo'lsa (muvaffaqiyatli yoki null) — qaytaramiz.
  if (_decodeCache.containsKey(b64)) return _decodeCache[b64];
  Uint8List? bytes;
  try {
    bytes = base64Decode(b64);
  } catch (_) {
    bytes = null;
  }
  // Cache hajmini cheklash — 200 dan oshsa eng eskisini tashlaymiz
  // (cheksiz o'sib ketmasin).
  if (_decodeCache.length > 200) {
    _decodeCache.remove(_decodeCache.keys.first);
  }
  _decodeCache[b64] = bytes;
  return bytes;
}

/// Base64 ilova ikonkasi — cache'langan dekod + `cacheWidth` bilan.
/// `base64` null/bo'sh yoki noto'g'ri bo'lsa `fallback` ko'rsatiladi.
class AppIconMemory extends StatelessWidget {
  const AppIconMemory({
    required this.base64,
    required this.size,
    required this.fallback,
    this.borderRadius,
    super.key,
  });

  final String? base64;
  final double size;
  final Widget fallback;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final b64 = base64;
    if (b64 == null || b64.isEmpty) return fallback;

    final bytes = _decodeCached(b64);
    if (bytes == null || bytes.isEmpty) return fallback;

    // devicePixelRatio bilan ko'paytirib aniq cacheWidth — retina'da ham
    // o'tkir, lekin manba 192px'dan kichik bitmap dekodlanadi.
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;
    final cacheW = (size * dpr).round().clamp(24, 192);

    final img = Image.memory(
      bytes,
      width: size,
      height: size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      cacheWidth: cacheW,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, __, ___) => fallback,
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: img);
    }
    return img;
  }
}
