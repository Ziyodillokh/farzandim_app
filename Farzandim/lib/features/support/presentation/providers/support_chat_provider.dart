// ─────────────────────────────────────────────────────────────────────
// supportChatProvider — Qo'llab-quvvatlash chati holati (lokal, statik)
// ─────────────────────────────────────────────────────────────────────
//
// Hozircha statik avto-javoblar (keyinroq AI ulanadi). Operator
// salomlashadi, foydalanuvchi yozadi/biriktirma yuboradi → operator
// statik javob beradi. Matn tarixi saqlanadi (SharedPreferences),
// biriktirmalar sessiya davomida to'liq, qayta yuklashda kartochka.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/support/data/models/support_message.dart';
import 'package:farzandim/features/support/data/repositories/support_chat_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Chat xabarlari + yuborish amallari. App umri davomida saqlanadi
/// (autoDispose emas — boshqa ekranga o'tib qaytganda suhbat qoladi).
final supportChatProvider =
    StateNotifierProvider<SupportChatNotifier, List<SupportMessage>>((ref) {
  return SupportChatNotifier(ref.watch(supportChatStoreProvider));
});

/// Statik avto-javoblar soni (`support.autoReply.0..N-1`).
const int _autoReplyCount = 3;

class SupportChatNotifier extends StateNotifier<List<SupportMessage>> {
  SupportChatNotifier(this._store) : super(const <SupportMessage>[]) {
    _load();
  }

  final SupportChatStore _store;
  int _replyIndex = 0;
  int _seq = 0;
  bool _operatorTyping = false;

  bool get operatorTyping => _operatorTyping;

  String _newId() {
    _seq++;
    return '${DateTime.now().microsecondsSinceEpoch}_$_seq';
  }

  Future<void> _load() async {
    final loaded = await _store.load();
    if (loaded.isNotEmpty) {
      state = loaded;
      return;
    }
    // Birinchi ochilish — operator salomlashadi (brand: Farzandim).
    state = <SupportMessage>[
      SupportMessage(
        id: _newId(),
        sender: SupportSender.operator,
        createdAt: DateTime.now(),
        text: 'support.welcome'.tr(),
      ),
    ];
    await _store.save(state);
  }

  /// Matn xabar yuborish.
  Future<void> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _append(
      SupportMessage(
        id: _newId(),
        sender: SupportSender.user,
        createdAt: DateTime.now(),
        text: trimmed,
      ),
    );
    await _store.save(state);
    _scheduleReply(isAttachment: false);
  }

  /// Biriktirma (rasm/video/hujjat) yuborish.
  Future<void> sendAttachment({
    required SupportAttachmentType type,
    required String fileName,
    required int fileSize,
    String? filePath,
    Uint8List? bytes,
  }) async {
    _append(
      SupportMessage(
        id: _newId(),
        sender: SupportSender.user,
        createdAt: DateTime.now(),
        attachmentType: type,
        fileName: fileName,
        fileSize: fileSize,
        filePath: filePath,
        bytes: bytes,
      ),
    );
    await _store.save(state);
    _scheduleReply(isAttachment: true);
  }

  void _append(SupportMessage m) {
    state = <SupportMessage>[...state, m];
  }

  /// Operator "yozyapti" + qisqa kechikishdan keyin statik javob.
  void _scheduleReply({required bool isAttachment}) {
    _operatorTyping = true;
    Future<void>.delayed(const Duration(milliseconds: 900), () async {
      if (!mounted) return;
      _operatorTyping = false;
      final String text;
      if (isAttachment) {
        text = 'support.fileReply'.tr();
      } else {
        text = 'support.autoReply.${_replyIndex % _autoReplyCount}'.tr();
        _replyIndex++;
      }
      _append(
        SupportMessage(
          id: _newId(),
          sender: SupportSender.operator,
          createdAt: DateTime.now(),
          text: text,
        ),
      );
      await _store.save(state);
    });
  }
}
