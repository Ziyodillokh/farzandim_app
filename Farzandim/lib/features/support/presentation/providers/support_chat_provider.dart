// ─────────────────────────────────────────────────────────────────────
// supportChatProvider — Qo'llab-quvvatlash chati (Telegram ko'prigi)
// ─────────────────────────────────────────────────────────────────────
//
// HAQIQIY backend oqimi:
//   user yozadi → POST /support/messages → backend operatorlar Telegram
//   GURUHIGA yetkazadi; operator Telegram'dan javob yozadi → backend
//   saqlaydi → ilova 10s polling (`syncFromServer`) bilan o'qiydi.
//
// Avto-javob ("Tez orada javob beramiz, iltimos kuting") — SERVER yaratadi
// (`isAutoAck`), klient o'z tilida ko'rsatadi. Eski soxta avto-javoblar
// olib tashlandi.
//
// Offlayn zaxira: tarix SharedPreferences'da keshlanaadi — server o'chsa
// oxirgi suhbat baribir ko'rinadi; yuborilmagan xabar failed + retry.

import 'dart:async';

import 'package:farzandim/core/realtime/socket_client.dart';
import 'package:farzandim/features/support/data/models/support_message.dart';
import 'package:farzandim/features/support/data/repositories/support_attachment_repository.dart';
import 'package:farzandim/features/support/data/repositories/support_chat_store.dart';
import 'package:farzandim/features/support/data/repositories/support_messages_repository.dart';
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
        ref.watch(supportMessagesRepositoryProvider),
        ref.watch(socketClientProvider),
      );
    });

class SupportChatNotifier extends StateNotifier<SupportChatState> {
  SupportChatNotifier(
    this._store,
    this._attachments,
    this._messagesRepo,
    this._socket,
  ) : super(const SupportChatState()) {
    _load();
    // Operator javobi (Telegram'dan) DARHOL keladi — backend `support:message`
    // WS event'ini `user:{id}` room'iga emit qiladi (matn yoki rasm/fayl).
    _wsSub = _socket.eventStream('support:message').listen(_onWsMessage);
    // Socket qayta ulanganda (uzilishdan keyin) WS'da o'tkazib yuborilgan
    // javoblar bo'lishi mumkin — darhol server bilan sinxronlaymiz.
    _connSub = _socket.stateStream.listen((s) {
      if (s == SocketConnectionState.connected) unawaited(syncFromServer());
    });
  }

  final SupportChatStore _store;
  final SupportAttachmentRepository _attachments;
  final SupportMessagesRepository _messagesRepo;
  final SocketClient _socket;
  StreamSubscription<dynamic>? _wsSub;
  StreamSubscription<SocketConnectionState>? _connSub;
  int _seq = 0;

  @override
  void dispose() {
    _wsSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }

  /// WS orqali kelgan operator xabarini darhol qo'shadi (id bo'yicha dublikatni
  /// chetlab; rasm/fayl maydonlari ham `fromServer` orqali o'qiladi). Keyingi
  /// sync server nusxasini tasdiqlaydi.
  void _onWsMessage(dynamic data) {
    if (!mounted || data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    final id = map['id'] as String?;
    if (id == null || _find(id) != null) return;
    _append(SupportMessage.fromServer(map));
    unawaited(_store.save(state.messages));
  }

  String _newLocalId() {
    _seq++;
    return 'local_${DateTime.now().microsecondsSinceEpoch}_$_seq';
  }

  SupportMessage get _welcome => SupportMessage(
    id: 'welcome',
    sender: SupportSender.operator,
    createdAt: DateTime.now(),
    textKey: 'support.welcome',
  );

  /* ───────────────────────── Yuklash / sync ───────────────────────── */

  Future<void> _load() async {
    // Avval kesh — server javobini kutmasdan suhbat ko'rinadi.
    final cached = await _store.load();
    if (!mounted) return;
    if (state.messages.isEmpty && cached.isNotEmpty) {
      state = state.copyWith(messages: cached);
    }
    await syncFromServer();
    if (!mounted) return;
    if (state.messages.isEmpty) {
      state = state.copyWith(messages: [_welcome]);
    }
  }

  /// Server tarixini o'qib lokal holat bilan birlashtiradi (id bo'yicha
  /// UNION-merge + createdAt bo'yicha tartib). Server haqiqat manbasi, lekin
  /// hali serverga yetmagan lokal xabarlar (WS, sending, failed) SAQLANADI —
  /// aks holda WS bilan kelgan javob poyga'da tushib qolardi ("ba'zida matn
  /// kelmaydi" muammosi).
  Future<void> syncFromServer() async {
    final List<SupportMessage> server;
    try {
      server = await _messagesRepo.list();
    } catch (e) {
      debugPrint('Support sync xato: $e');
      return; // offlayn — joriy holat qoladi
    }
    if (!mounted) return;

    final byId = <String, SupportMessage>{};
    // Avval lokal — WS/pending xabarlar va transient preview saqlanadi.
    for (final m in state.messages) {
      byId[m.id] = m;
    }
    // Server ustun (haqiqat manbasi) — transient preview (bytes/filePath)
    // ko'chiriladi (server ularni saqlamaydi).
    for (final s in server) {
      final local = byId[s.id];
      byId[s.id] =
          (local != null && (local.bytes != null || local.filePath != null))
          ? s.copyWith(bytes: local.bytes, filePath: local.filePath)
          : s;
    }

    final hasReal = byId.length > 1 || !byId.containsKey('welcome');
    final merged =
        byId.values.where((m) => !(m.id == 'welcome' && hasReal)).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (merged.isEmpty) return; // welcome'ni o'chirib yubormaymiz
    state = state.copyWith(messages: merged);
    await _store.save(state.messages);
  }

  /* ───────────────────────── Yuborish ───────────────────────── */

  /// Matn xabar — optimistik ko'rsatib, backend'ga yuboradi (Telegram
  /// guruhiga yetadi). Xato bo'lsa failed + retry.
  Future<void> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final localId = _newLocalId();
    _append(
      SupportMessage(
        id: localId,
        sender: SupportSender.user,
        createdAt: DateTime.now(),
        text: trimmed,
        status: SupportSendStatus.sending,
      ),
    );
    await _postToServer(localId, text: trimmed);
  }

  /// Biriktirma: optimistik → MinIO upload → POST /support/messages.
  Future<void> sendAttachment({
    required SupportAttachmentType type,
    required String fileName,
    required int fileSize,
    String? filePath,
    Uint8List? bytes,
  }) async {
    final localId = _newLocalId();
    _append(
      SupportMessage(
        id: localId,
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
    await _uploadAndPost(localId);
  }

  /// `failed` xabarni qayta yuborish (matn yoki biriktirma).
  Future<void> retryAttachment(String id) async {
    final msg = _find(id);
    if (msg == null || msg.status != SupportSendStatus.failed) return;
    if (msg.hasAttachment) {
      if (msg.bytes == null && msg.filePath == null && !msg.hasRemote) {
        return; // transientlar yo'qolgan (restart) — qayta yuborib bo'lmaydi
      }
      _updateMessage(id, (m) => m.copyWith(status: SupportSendStatus.sending));
      await _uploadAndPost(id);
    } else {
      _updateMessage(id, (m) => m.copyWith(status: SupportSendStatus.sending));
      await _postToServer(id, text: msg.text ?? '');
    }
  }

  /// Biriktirmani (kerak bo'lsa) MinIO'ga yuklab, so'ng xabarni POST qiladi.
  Future<void> _uploadAndPost(String localId) async {
    var msg = _find(localId);
    if (msg == null) return;
    try {
      if (!msg.hasRemote) {
        final res = await _attachments.upload(
          fileName: msg.fileName ?? 'fayl',
          filePath: msg.filePath,
          bytes: msg.bytes,
        );
        if (!mounted) return;
        if (res.key.isEmpty) {
          throw Exception("upload bo'sh key qaytardi");
        }
        _updateMessage(
          localId,
          (m) => m.copyWith(attachmentKey: res.key, mimeType: res.mimeType),
        );
        msg = _find(localId);
      }
      await _postToServer(
        localId,
        attachmentKey: msg?.attachmentKey,
        attachmentType: msg?.attachmentType?.name,
        fileName: msg?.fileName,
        fileSize: msg?.fileSize,
        mimeType: msg?.mimeType,
      );
    } catch (e) {
      debugPrint('Support biriktirma xato: $e');
      if (!mounted) return;
      _updateMessage(
        localId,
        (m) => m.copyWith(status: SupportSendStatus.failed),
      );
      await _store.save(state.messages);
    }
  }

  /// Backend'ga POST: muvaffaqiyatda lokal xabar server nusxasi bilan
  /// almashtiriladi (id ham server'niki — keyingi sync'da dublikat bo'lmaydi)
  /// va server ack'i (bo'lsa) typing'dan keyin qo'shiladi.
  Future<void> _postToServer(
    String localId, {
    String? text,
    String? attachmentKey,
    String? attachmentType,
    String? fileName,
    int? fileSize,
    String? mimeType,
  }) async {
    final local = _find(localId);
    try {
      final res = await _messagesRepo.send(
        text: text,
        attachmentKey: attachmentKey,
        attachmentType: attachmentType,
        fileName: fileName,
        fileSize: fileSize,
        mimeType: mimeType,
      );
      if (!mounted) return;
      // Lokal xabarni server nusxasi bilan almashtiramiz (transient preview
      // saqlanadi).
      final serverMsg = res.message.copyWith(
        bytes: local?.bytes,
        filePath: local?.filePath,
      );
      state = state.copyWith(
        messages: [
          for (final m in state.messages)
            if (m.id == localId) serverMsg else m,
        ],
      );
      await _store.save(state.messages);

      // Avto-ack — "yozmoqda…" dan keyin tabiiy paydo bo'ladi.
      final ack = res.ack;
      if (ack != null) {
        state = state.copyWith(operatorTyping: true);
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (!mounted) return;
        state = state.copyWith(
          operatorTyping: false,
          messages: [...state.messages, ack],
        );
        await _store.save(state.messages);
      }
    } catch (e) {
      debugPrint('Support yuborish xato: $e');
      if (!mounted) return;
      _updateMessage(
        localId,
        (m) => m.copyWith(status: SupportSendStatus.failed),
      );
      await _store.save(state.messages);
    }
  }

  /* ───────────────────────── Helpers ───────────────────────── */

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
}
