// ─────────────────────────────────────────────────────────────────────
// supportChatProvider — Qo'llab-quvvatlash chati holati (lokal, statik)
// ─────────────────────────────────────────────────────────────────────
//
// Hozircha statik avto-javoblar (keyinroq AI ulanadi). Operator
// salomlashadi, foydalanuvchi yozadi/biriktirma yuboradi → operator
// statik javob beradi. Matn tarixi saqlanadi (SharedPreferences),
// biriktirmalar sessiya davomida to'liq, qayta yuklashda kartochka.
//
// State — `SupportChatState`: xabarlar + operator "yozmoqda" bayrog'i
// (UI typing-indikatorini ko'rsata olishi uchun alohida field emas,
// state'ning o'zida). Biriktirma yuborilish holati (sending/sent/failed)
// har xabarning `status` maydonida — tick'lar + retry shu orqali.

import 'package:farzandim/features/support/data/models/support_message.dart';
import 'package:farzandim/features/support/data/repositories/support_attachment_repository.dart';
import 'package:farzandim/features/support/data/repositories/support_chat_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Chat ekrani holati — xabarlar ro'yxati + operator yozmoqda bayrog'i.
@immutable
class SupportChatState {
  /// `SupportChatState` konstruktor.
  const SupportChatState({
    this.messages = const <SupportMessage>[],
    this.operatorTyping = false,
  });

  /// Xabarlar (eskidan yangiga).
  final List<SupportMessage> messages;

  /// Operator hozir "yozmoqda…" (typing indikator ko'rsatiladi).
  final bool operatorTyping;

  /// Nusxa (immutable yangilash).
  SupportChatState copyWith({
    List<SupportMessage>? messages,
    bool? operatorTyping,
  }) {
    return SupportChatState(
      messages: messages ?? this.messages,
      operatorTyping: operatorTyping ?? this.operatorTyping,
    );
  }
}

/// Chat xabarlari + yuborish amallari. App umri davomida saqlanadi
/// (autoDispose emas — boshqa ekranga o'tib qaytganda suhbat qoladi).
final supportChatProvider =
    StateNotifierProvider<SupportChatNotifier, SupportChatState>((ref) {
      return SupportChatNotifier(
        ref.watch(supportChatStoreProvider),
        ref.watch(supportAttachmentRepositoryProvider),
      );
    });

/// Statik avto-javoblar soni (`support.autoReply.0..N-1`).
const int _autoReplyCount = 3;

class SupportChatNotifier extends StateNotifier<SupportChatState> {
  SupportChatNotifier(this._store, this._attachments)
    : super(const SupportChatState()) {
    _load();
  }

  final SupportChatStore _store;
  final SupportAttachmentRepository _attachments;
  int _replyIndex = 0;
  int _seq = 0;

  /// Kutilayotgan avto-javoblar soni — typing indikatori refcount'i.
  /// Bool yetarli emas: ketma-ket 2 xabarda birinchi callback typing'ni
  /// erta o'chirib yuborardi (review topilmasi).
  int _pendingReplies = 0;

  String _newId() {
    _seq++;
    return '${DateTime.now().microsecondsSinceEpoch}_$_seq';
  }

  Future<void> _load() async {
    final loaded = await _store.load();
    if (!mounted) return;
    // Lost-update himoyasi: load kutilayotganda foydalanuvchi allaqachon
    // xabar yuborgan bo'lsa, kech kelgan tarix uni o'chirib yubormasin.
    if (state.messages.isNotEmpty) return;
    if (loaded.isNotEmpty) {
      state = state.copyWith(messages: loaded);
      return;
    }
    // Birinchi ochilish — operator salomlashadi. textKey saqlanadi (matn
    // emas) — til almashtirilganda render paytida yangi tilda tarjima bo'ladi.
    state = state.copyWith(
      messages: <SupportMessage>[
        SupportMessage(
          id: _newId(),
          sender: SupportSender.operator,
          createdAt: DateTime.now(),
          textKey: 'support.welcome',
        ),
      ],
    );
    await _store.save(state.messages);
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
    await _store.save(state.messages);
    _scheduleReply(isAttachment: false);
  }

  /// Biriktirma (rasm/video/hujjat) yuborish.
  ///
  /// 1. Darhol `sending` holatida ko'rsatamiz (optimistik).
  /// 2. Fonda backend MinIO'ga yuklaymiz → `attachmentKey` + `sent`.
  ///    Xato bo'lsa `failed` — bubble'da retry tugmasi chiqadi.
  Future<void> sendAttachment({
    required SupportAttachmentType type,
    required String fileName,
    required int fileSize,
    String? filePath,
    Uint8List? bytes,
  }) async {
    final id = _newId();
    _append(
      SupportMessage(
        id: id,
        sender: SupportSender.user,
        createdAt: DateTime.now(),
        attachmentType: type,
        fileName: fileName,
        fileSize: fileSize,
        filePath: filePath,
        bytes: bytes,
        status: SupportSendStatus.sending,
      ),
    );
    await _store.save(state.messages);
    // Avto-javob upload MUVAFFAQIYATIDAN keyin (_uploadAttachment ichida) —
    // failed bo'lsa operator "fayl olindi" deb adashtirmaydi.
    await _uploadAttachment(id);
  }

  /// `failed` biriktirmani qayta yuborish (bytes/filePath hali sessiyada
  /// bo'lsa). Transientlar yo'qolgan bo'lsa (restart) hech narsa qilmaydi —
  /// UI bunday xabarda retry tugmasini ko'rsatmaydi.
  Future<void> retryAttachment(String id) async {
    final msg = _find(id);
    if (msg == null ||
        msg.status != SupportSendStatus.failed ||
        (msg.bytes == null && msg.filePath == null)) {
      return;
    }
    _updateMessage(id, (m) => m.copyWith(status: SupportSendStatus.sending));
    await _uploadAttachment(id);
  }

  Future<void> _uploadAttachment(String id) async {
    final msg = _find(id);
    if (msg == null) return;
    try {
      final res = await _attachments.upload(
        fileName: msg.fileName ?? 'fayl',
        filePath: msg.filePath,
        bytes: msg.bytes,
      );
      if (!mounted) return;
      if (res.key.isNotEmpty) {
        _updateMessage(
          id,
          (m) => m.copyWith(
            attachmentKey: res.key,
            mimeType: res.mimeType,
            status: SupportSendStatus.sent,
          ),
        );
        // Fayl haqiqatan yetib bordi — endi operator javobi o'rinli
        // (retry muvaffaqiyati ham shu yo'ldan o'tadi).
        _scheduleReply(isAttachment: true);
      } else {
        _updateMessage(id, (m) => m.copyWith(status: SupportSendStatus.failed));
      }
      await _store.save(state.messages);
    } catch (e) {
      debugPrint('Support biriktirma yuklash xato: $e');
      if (!mounted) return;
      // Optimistik xabar sessiyada ko'rinadi (bytes/filePath bilan);
      // `failed` holat retry tugmasini yoqadi.
      _updateMessage(id, (m) => m.copyWith(status: SupportSendStatus.failed));
      await _store.save(state.messages);
    }
  }

  SupportMessage? _find(String id) {
    for (final m in state.messages) {
      if (m.id == id) return m;
    }
    return null;
  }

  void _append(SupportMessage m) {
    state = state.copyWith(messages: <SupportMessage>[...state.messages, m]);
  }

  /// Berilgan `id`li xabarni `update` bilan almashtiradi (immutable).
  void _updateMessage(
    String id,
    SupportMessage Function(SupportMessage) update,
  ) {
    state = state.copyWith(
      messages: <SupportMessage>[
        for (final m in state.messages)
          if (m.id == id) update(m) else m,
      ],
    );
  }

  /// Operator "yozyapti" indikatori + qisqa kechikishdan keyin statik javob.
  /// Refcount (`_pendingReplies`) — parallel javoblar bir-birining typing'ini
  /// erta o'chirib yubormasligi uchun.
  void _scheduleReply({required bool isAttachment}) {
    if (!mounted) return;
    _pendingReplies++;
    state = state.copyWith(operatorTyping: true);
    Future<void>.delayed(const Duration(milliseconds: 1400), () async {
      if (!mounted) return;
      _pendingReplies--;
      final String key;
      if (isAttachment) {
        key = 'support.fileReply';
      } else {
        key = 'support.autoReply.${_replyIndex % _autoReplyCount}';
        _replyIndex++;
      }
      if (_pendingReplies <= 0) {
        state = state.copyWith(operatorTyping: false);
      }
      _append(
        SupportMessage(
          id: _newId(),
          sender: SupportSender.operator,
          createdAt: DateTime.now(),
          textKey: key,
        ),
      );
      await _store.save(state.messages);
    });
  }
}
