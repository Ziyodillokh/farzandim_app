// ─────────────────────────────────────────────────────────────────────
// SupportMessage — Qo'llab-quvvatlash chati xabari (Sprint 7)
// ─────────────────────────────────────────────────────────────────────
//
// Hozircha lokal (statik avto-javoblar). Matn xabarlar SharedPreferences'ga
// saqlanadi; biriktirmalar (rasm/video/hujjat) sessiya davomida bytes/path
// orqali ko'rsatiladi (qayta ishga tushganda kartochka holida qoladi).
// Keyinroq sun'iy intellekt / backend ulanganda repository almashtiriladi.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

enum SupportSender { user, operator }

enum SupportAttachmentType { image, video, document }

/// Xabar yuborilish holati (messenger tick'lari uchun).
/// Matn — darhol `sent`. Biriktirma — `sending` → `sent`/`failed`.
enum SupportSendStatus { sending, sent, failed }

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.sender,
    required this.createdAt,
    this.text,
    this.textKey,
    this.attachmentType,
    this.fileName,
    this.fileSize,
    this.filePath,
    this.bytes,
    this.attachmentKey,
    this.mimeType,
    this.status = SupportSendStatus.sent,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> j) {
    SupportAttachmentType? type;
    final rawType = j['attachmentType'] as String?;
    if (rawType != null) {
      type = SupportAttachmentType.values.firstWhere(
        (t) => t.name == rawType,
        orElse: () => SupportAttachmentType.document,
      );
    }
    final key = j['attachmentKey'] as String?;
    return SupportMessage(
      id: j['id'] as String? ?? '',
      sender: SupportSender.values.firstWhere(
        (s) => s.name == j['sender'],
        orElse: () => SupportSender.operator,
      ),
      createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? _epoch,
      text: j['text'] as String?,
      textKey: j['textKey'] as String?,
      attachmentType: type,
      fileName: j['fileName'] as String?,
      fileSize: (j['fileSize'] as num?)?.toInt(),
      attachmentKey: key,
      mimeType: j['mimeType'] as String?,
      // Qayta ishga tushganda: key bor = yuborilgan; biriktirma key'siz =
      // yuborilmagan (bytes/filePath transient — retry ham imkonsiz, failed).
      status: (type != null && (key == null || key.isEmpty))
          ? SupportSendStatus.failed
          : SupportSendStatus.sent,
    );
  }

  final String id;
  final SupportSender sender;
  final DateTime createdAt;

  /// Matn xabar (biriktirma bo'lmasa).
  final String? text;

  /// Operator template xabarining i18n KALITI (masalan `support.welcome`).
  /// Saqlanadi va RENDER paytida tarjima qilinadi — til almashtirilganda
  /// tarix ham yangi tilda ko'rinadi (resolve qilingan matn emas).
  final String? textKey;

  /// UI'da ko'rsatiladigan matn: kalit bo'lsa joriy tilda tarjima, aks holda
  /// foydalanuvchi kiritgan matn.
  String get displayText => textKey != null ? textKey!.tr() : (text ?? '');

  /// Biriktirma turi — `null` bo'lsa oddiy matn.
  final SupportAttachmentType? attachmentType;
  final String? fileName;

  /// Fayl hajmi (bayt).
  final int? fileSize;

  /// Lokal fayl yo'li — transient (mobil, `open_filex` uchun). Saqlanmaydi.
  final String? filePath;

  /// Rasm preview baytlari — transient (sessiya). Saqlanmaydi.
  final Uint8List? bytes;

  /// Backend MinIO key (yuklangach) — SAQLANADI. Bu bo'lsa biriktirma qayta
  /// ishga tushgandan keyin ham proxy orqali ko'rsatiladi/yuklab olinadi.
  final String? attachmentKey;

  /// MIME turi (masalan `image/png`, `video/mp4`) — backend'dan keladi.
  final String? mimeType;

  /// Yuborilish holati — UI tick'lari (soat/✓/xato) va retry uchun.
  final SupportSendStatus status;

  /// Biriktirma backend'ga yuklanganmi (qayta ishga tushganda ham mavjud).
  bool get hasRemote => attachmentKey != null && attachmentKey!.isNotEmpty;

  bool get isUser => sender == SupportSender.user;
  bool get isOperator => sender == SupportSender.operator;
  bool get hasAttachment => attachmentType != null;
  bool get isImage => attachmentType == SupportAttachmentType.image;
  bool get isVideo => attachmentType == SupportAttachmentType.video;
  bool get isDocument => attachmentType == SupportAttachmentType.document;

  /// "HH:mm" — local vaqt.
  String get timeLabel {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(createdAt.hour)}:${two(createdAt.minute)}';
  }

  /// "2,4 Mb" yoki "320 KB" — Figma formati (vergul bilan).
  String? get fileSizeLabel {
    final s = fileSize;
    if (s == null || s <= 0) return null;
    if (s >= 1024 * 1024) {
      final mb = s / (1024 * 1024);
      return '${mb.toStringAsFixed(1).replaceAll('.', ',')} Mb';
    }
    final kb = (s / 1024).ceil();
    return '$kb KB';
  }

  SupportMessage copyWith({
    Uint8List? bytes,
    String? filePath,
    String? attachmentKey,
    String? mimeType,
    SupportSendStatus? status,
  }) {
    return SupportMessage(
      id: id,
      sender: sender,
      createdAt: createdAt,
      text: text,
      textKey: textKey,
      attachmentType: attachmentType,
      fileName: fileName,
      fileSize: fileSize,
      filePath: filePath ?? this.filePath,
      bytes: bytes ?? this.bytes,
      attachmentKey: attachmentKey ?? this.attachmentKey,
      mimeType: mimeType ?? this.mimeType,
      status: status ?? this.status,
    );
  }

  /// SharedPreferences uchun — transient (`bytes`/`filePath`) saqlanmaydi,
  /// lekin `attachmentKey` SAQLANADI (qayta yuklashda proxy orqali ko'rsatish).
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'sender': sender.name,
    'createdAt': createdAt.toIso8601String(),
    if (text != null) 'text': text,
    if (textKey != null) 'textKey': textKey,
    if (attachmentType != null) 'attachmentType': attachmentType!.name,
    if (fileName != null) 'fileName': fileName,
    if (fileSize != null) 'fileSize': fileSize,
    if (attachmentKey != null) 'attachmentKey': attachmentKey,
    if (mimeType != null) 'mimeType': mimeType,
  };

  // Date.now() o'rniga barqaror fallback (parse xato bo'lsa eski sana).
  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  // `bytes`'ni debugProps'dan chiqarib tashlamaymiz — faqat ichki ishlatish.
  @visibleForTesting
  bool get debugHasBytes => bytes != null;
}
