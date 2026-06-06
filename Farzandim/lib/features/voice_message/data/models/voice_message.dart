import 'package:flutter/foundation.dart';

/// Ovozli xabar holati.
enum VoiceMessageStatus {
  /// Yuborilgan, hali tinglanmagan.
  sent,

  /// Qabul qiluvchi tomonidan tinglangan / ko'rilgan.
  seen,
}

/// Bola va ota-ona o'rtasidagi ovozli xabar.
///
/// Firestore: `voice_messages/{auto-id}` top-level collection.
/// `parentUid` + `childId` indekslangan — ota-ona faqat o'z bolalarining
/// xabarlarini ko'radi. `sender` — `'parent'` yoki `'child'`.
@immutable
class VoiceMessage {
  /// `VoiceMessage` konstruktor.
  const VoiceMessage({
    required this.id,
    required this.parentUid,
    required this.childId,
    required this.childName,
    required this.sender,
    required this.audioUrl,
    required this.durationSeconds,
    required this.waveform,
    required this.status,
    required this.createdAt,
    this.seenAt,
    this.text,
    this.mediaKey,
    this.mediaType,
    this.mimeType,
    this.fileName,
    this.fileSize,
  });

  /// Backend REST `VoiceMessage` JSON'idan (Sprint 4.4.5).
  ///
  /// Backend Prisma kontract:
  /// ```json
  /// {
  ///   "id": "uuid",
  ///   "senderId": "uuid",
  ///   "receiverId": "uuid",
  ///   "storagePath": "senderId/messageId.m4a",
  ///   "durationSeconds": 3,
  ///   "isRead": false,
  ///   "createdAt": "ISO 8601"
  /// }
  /// ```
  ///
  /// Mapping:
  /// - `senderId == currentUserId (parent)` → sender = 'parent'
  /// - boshqa holda → sender = 'child'
  /// - `audioUrl` bo'sh — signed URL lazy fetch (`/voice-messages/:id/file`)
  /// - `waveform` Backend'da yo'q — bo'sh list
  ///
  /// `childId` UI tarafi tracking uchun — Backend xabarlari child-grouped emas
  /// (sender/receiver based). Caller `childId`'ni dispatch'da to'ldiradi.
  factory VoiceMessage.fromBackendJson(
    Map<String, dynamic> json, {
    required String currentUserId,
    required String childId,
  }) {
    final senderId = json['senderId'] as String? ?? '';
    return VoiceMessage(
      id: json['id'] as String? ?? '',
      parentUid: currentUserId, // Parent App: o'zining user ID
      childId: childId,
      childName: '',
      sender: senderId == currentUserId ? 'parent' : 'child',
      audioUrl: '', // Signed URL lazy fetch
      durationSeconds: (json['durationSeconds'] as int?) ?? 0,
      waveform: const [],
      status: (json['isRead'] as bool? ?? false)
          ? VoiceMessageStatus.seen
          : VoiceMessageStatus.sent,
      // Backend ISO 8601 UTC → local (Tashkent UTC+5).
      // Agar `Z`/`+` marker yo'q bo'lsa Dart parse local time deb tushunadi —
      // Z'ni majburlab qo'shamiz.
      createdAt: _parseBackendIso(json['createdAt'] as String?) ??
          DateTime.now(),
      text: json['text'] as String?,
      mediaKey: json['mediaKey'] as String?,
      mediaType: json['mediaType'] as String?,
      mimeType: json['mimeType'] as String?,
      fileName: json['fileName'] as String?,
      fileSize: (json['fileSize'] as num?)?.toInt(),
    );
  }

  static DateTime? _parseBackendIso(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      // Backend Z marker bilan UTC qaytaradi — Dart parse UTC deb tushunadi
      // va toLocal() Tashkent +5'ga aylantiradi.
      // Agar marker yo'q (Backend local time) — toLocal hech narsa
      // o'zgartirmaydi va Backend vaqtini ko'rsatamiz.
      return DateTime.parse(iso).toLocal();
    } catch (_) {
      return null;
    }
  }

  /// Firestore document ID.
  final String id;

  /// Ota-ona Firebase UID — query filter uchun.
  final String parentUid;

  /// Qaysi bola bilan suhbat.
  final String childId;

  /// Bola ismi (denormalized — har xabar alohida o'qilmasligi uchun).
  final String childName;

  /// `'parent'` yoki `'child'` — kim yuborgan.
  final String sender;

  /// Storage'dagi audio fayl URL'i.
  final String audioUrl;

  /// Audio davomiyligi sekundda.
  final int durationSeconds;

  /// Waveform amplitudalari (0..1) — bubble ichidagi to'lqin chiziq.
  final List<double> waveform;

  /// Xabar holati: `sent` yoki `seen`.
  final VoiceMessageStatus status;

  /// Yaratilgan vaqt (server timestamp).
  final DateTime createdAt;

  /// Ko'rilgan vaqt — `null` bo'lsa hali tinglanmagan.
  final DateTime? seenAt;

  /// Text xabar matni (Telegram-style chat). Audio/media'da `null` yoki
  /// media uchun caption sifatida ishlatilishi mumkin.
  final String? text;

  /// Media fayl kaliti (MinIO `chat` bucket) — proxy URL build qilish uchun.
  final String? mediaKey;

  /// Media turi: `'image'` yoki `'file'`. Media bo'lmasa `null`.
  final String? mediaType;

  /// Media MIME turi (masalan `image/jpeg`, `application/pdf`).
  final String? mimeType;

  /// Media original fayl nomi (hujjat bubble'da ko'rsatiladi).
  final String? fileName;

  /// Media fayl hajmi baytda (hujjat bubble'da ko'rsatiladi).
  final int? fileSize;

  /// Ko'rilganmi (status == seen).
  bool get isSeen => status == VoiceMessageStatus.seen;

  /// Media (rasm/hujjat) xabar — `mediaKey` MinIO `chat` bucket kaliti.
  bool get hasMedia => mediaKey != null && mediaKey!.isNotEmpty;

  /// Rasm media.
  bool get isImage => hasMedia && mediaType == 'image';

  /// Hujjat (rasm bo'lmagan) media.
  bool get isFile => hasMedia && mediaType != 'image';

  /// Faqat matnli xabar (audio/media yo'q). Backend matn xabarda
  /// `durationSeconds == null` (→ 0) va `storagePath == null` keladi.
  bool get isText =>
      !hasMedia && durationSeconds == 0 && (text != null && text!.isNotEmpty);

  /// Audio (ovozli) xabar — text/media bo'lmagan qolgan barcha holat.
  bool get isAudio => !hasMedia && !isText;
}
