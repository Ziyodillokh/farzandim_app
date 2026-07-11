// ─────────────────────────────────────────────────────────────────────
// VoiceMessage — bola yoki ota-ona yuborgan ovozli xabar
// ─────────────────────────────────────────────────────────────────────
//
// Firestore: `voice_messages/{messageId}` — top-level kolleksiya.
// `sender`: 'child' (Child App yozgan) yoki 'parent' (Parent App yozgan)
// — chat ekran bubble'ni o'ng/chap joyga qo'yish uchun.

import 'package:cloud_firestore/cloud_firestore.dart';

enum VoiceMessageStatus { sent, seen }

class VoiceMessage {
  final String? id;
  final String parentUid;
  final String childId;
  final String childName;
  final String sender; // 'child' | 'parent'
  final String audioUrl;
  final int durationSeconds;
  final List<double> waveform;
  final VoiceMessageStatus status;
  final DateTime? createdAt;
  final DateTime? seenAt;
  // Text xabar (Telegram-style chat). Audio xabarda null.
  final String? text;

  bool get isText => text != null && text!.isNotEmpty;

  const VoiceMessage({
    this.id,
    required this.parentUid,
    required this.childId,
    required this.childName,
    required this.sender,
    required this.audioUrl,
    required this.durationSeconds,
    this.waveform = const [],
    this.status = VoiceMessageStatus.sent,
    this.createdAt,
    this.seenAt,
    this.text,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'parentUid': parentUid,
      'childId': childId,
      'childName': childName,
      'sender': sender,
      'audioUrl': audioUrl,
      'durationSeconds': durationSeconds,
      'waveform': waveform,
      'status': status.name,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Backend REST `VoiceMessage` JSON'idan (Sprint 4.4.5).
  ///
  /// Backend kontrakt (Prisma `VoiceMessage` model):
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
  /// Eslatma: Backend'da `audioUrl` yo'q — alohida `GET /api/voice-messages/:id/file`
  /// signed URL endpoint orqali olinadi. Hozir `audioUrl` bo'sh saqlanadi,
  /// playback chaqirilganda repository fetch qiladi.
  ///
  /// `sender` parametri caller tomonidan beriladi (current userId bilan
  /// taqqoslash orqali — `senderId == currentUserId ? 'child' : 'parent'`).
  factory VoiceMessage.fromBackendJson(
    Map<String, dynamic> json, {
    required String currentUserId,
  }) {
    final senderId = json['senderId'] as String? ?? '';
    return VoiceMessage(
      id: json['id'] as String?,
      parentUid: '', // Backend kontract'da yo'q — ishlatilmaydi
      childId: '',
      childName: '',
      sender: senderId == currentUserId ? 'child' : 'parent',
      audioUrl: '', // Signed URL lazy fetch
      durationSeconds: (json['durationSeconds'] as int?) ?? 0,
      status: (json['isRead'] as bool? ?? false)
          ? VoiceMessageStatus.seen
          : VoiceMessageStatus.sent,
      // Backend ISO 8601 UTC → local (Tashkent UTC+5).
      // Agar `Z`/`+` marker yo'q bo'lsa, Dart parse local time deb tushunadi
      // (toLocal() effekti yo'q) — Z'ni majburlab qo'shamiz.
      createdAt: _parseBackendIso(json['createdAt'] as String?),
      text: json['text'] as String?,
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

  factory VoiceMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return VoiceMessage(
      id: doc.id,
      parentUid: data['parentUid'] as String? ?? '',
      childId: data['childId'] as String? ?? '',
      childName: data['childName'] as String? ?? '',
      sender: data['sender'] as String? ?? 'child',
      audioUrl: data['audioUrl'] as String? ?? '',
      durationSeconds: data['durationSeconds'] as int? ?? 0,
      waveform:
          (data['waveform'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [],
      status: VoiceMessageStatus.values.firstWhere(
        (s) => s.name == (data['status'] as String?),
        orElse: () => VoiceMessageStatus.sent,
      ),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      seenAt: data['seenAt'] != null
          ? (data['seenAt'] as Timestamp).toDate()
          : null,
    );
  }
}
