// ─────────────────────────────────────────────────────────────────────
// SecretClipboard — vaqtinchalik parolni nusxalash va buferdan tozalash
// ─────────────────────────────────────────────────────────────────────
//
// Parol nusxalansa bufer (clipboard) boshqa ilovalarga ham ko'rinadi va
// uzoq turadi. Shu sabab nusxalangan maxfiy matn [ttl] (standart 90 s)
// o'tgach — buferda HALI SHU MATN turgan bo'lsa — bo'shatiladi. Boshqa
// narsa nusxalangan bo'lsa tegilmaydi.
//
// Taymer varaq (widget) umriga bog'liq EMAS: ota-ona nusxalab, varaqni
// yopib, xabarlashuvchiga o'tib yopishtirishi mumkin — bufer varaq
// yopilganda tozalanmaydi, faqat vaqt tugaganda. Ilova o'ldirilsa yoki
// ilova fonda bufer o'qishga ruxsat bermasa (Android 10+) — tozalash
// o'tkazib yuboriladi: bu "yaxshi urinish" (best-effort).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Maxfiy matn buferda shuncha turadi.
const Duration kSecretClipboardTtl = Duration(seconds: 90);

class SecretClipboard {
  SecretClipboard({this.ttl = kSecretClipboardTtl});

  final Duration ttl;
  Timer? _clearTimer;

  /// Oddiy nusxalash (masalan login): bufer keyin tozalanmaydi.
  Future<void> copy(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  /// Maxfiy matnni (parol, parol bor matn) nusxalaydi va [ttl] dan keyin
  /// buferni tozalashni rejalaydi. Yangi nusxa oldingi rejani almashtiradi.
  Future<void> copySecret(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _clearTimer?.cancel();
    _clearTimer = Timer(ttl, () => unawaited(_clearIfUnchanged(text)));
  }

  Future<void> _clearIfUnchanged(String copied) async {
    try {
      final current = await Clipboard.getData(Clipboard.kTextPlain);
      // O'qib bo'lmadi (fon) yoki boshqa matn nusxalangan — tegilmaydi.
      if (current?.text != copied) return;
      await Clipboard.setData(const ClipboardData(text: ''));
    } on Object catch (error) {
      // Matn (parol) log'ga tushmasin: faqat xato turi.
      debugPrint('[credentials] clipboard clear: ${error.runtimeType}');
    }
  }

  /// Ilova tugaganda taymerni to'xtatadi (varaq yopilganda EMAS).
  void dispose() {
    _clearTimer?.cancel();
    _clearTimer = null;
  }
}

final secretClipboardProvider = Provider<SecretClipboard>((ref) {
  final clipboard = SecretClipboard();
  ref.onDispose(clipboard.dispose);
  return clipboard;
});
