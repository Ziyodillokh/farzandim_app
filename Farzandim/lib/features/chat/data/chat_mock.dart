// ─────────────────────────────────────────────────────────────────────
// chat_mock.dart — FAQAT UI PREVIEW uchun soxta (mock) chat ma'lumotlari
// ─────────────────────────────────────────────────────────────────────
//
// ⚠️ Bu HAQIQIY chat EMAS. "Chatlar" (ro'yxat) + chat detali ekranlarini
// to'ldirilgan holda ko'rsatish uchun soxta kontaktlar/xabarlar. Haqiqiy
// chat backend orqali `voice_message` feature'ida (Telegram-style).

import 'package:flutter/material.dart';

/// Preview chat kontakti — "Chatlar" ro'yxatidagi bitta qator.
class ChatContact {
  /// `ChatContact` konstruktor.
  const ChatContact({
    required this.id,
    required this.name,
    required this.color,
    required this.online,
    required this.lastMessage,
    required this.time,
    this.unread = 0,
  });

  /// Kontakt identifikatori (route parametri).
  final String id;

  /// Ko'rsatiladigan ism.
  final String name;

  /// Avatar fon rangi (bosh harf ustida).
  final Color color;

  /// Onlaynmi (yashil nuqta).
  final bool online;

  /// Oxirgi xabar preview'i.
  final String lastMessage;

  /// Oxirgi xabar vaqti ("11:41" yoki "12 sen").
  final String time;

  /// O'qilmagan xabarlar soni (0 = badge yo'q).
  final int unread;

  /// Avatar uchun bosh harf.
  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';
}

/// Chat xabari turi.
enum ChatMsgKind {
  /// Matnli xabar.
  text,

  /// Dumaloq video xabar (Telegram-style).
  roundVideo,

  /// Ovozli xabar (to'lqin + davomiylik).
  voice,
}

/// Preview chat xabari.
class ChatMsg {
  /// `ChatMsg` konstruktor.
  const ChatMsg({
    required this.kind,
    required this.mine,
    required this.time,
    this.text,
    this.read = true,
    this.dayLabel,
    this.durationSec = 0,
    this.mediaUrl,
  });

  /// Xabar turi (matn / dumaloq video).
  final ChatMsgKind kind;

  /// Meniki (o'ng, ko'k) yoki qabul qilingan (chap, kulrang).
  final bool mine;

  /// Xabar vaqti.
  final String time;

  /// Matn (kind == text bo'lsa).
  final String? text;

  /// O'qilgan (ikki ko'k belgi) — faqat `mine` xabarlar uchun.
  final bool read;

  /// Shu xabar oldidan ko'rsatiladigan kun ajratgichi (masalan "Bugun").
  final String? dayLabel;

  /// Ovoz / video davomiyligi (soniya) — matn uchun 0.
  final int durationSec;

  /// Yozib olingan media manzili (ovoz uchun blob/fayl URL) — eshitish uchun.
  final String? mediaUrl;
}

/// Preview kontaktlar ro'yxati.
const List<ChatContact> mockContacts = [
  ChatContact(
    id: 'nodira',
    name: 'Nodira',
    color: Color(0xFFEF7DA0),
    online: true,
    lastMessage: 'Uyga kirib obed qilib ket',
    time: '11:41',
    unread: 2,
  ),
  ChatContact(
    id: 'akmal',
    name: 'Akmal',
    color: Color(0xFF7B61FF),
    online: false,
    lastMessage: 'Matemmatikaga kech qolma',
    time: '12 sen',
  ),
];

/// `id` bo'yicha kontakt (topilmasa birinchisi).
ChatContact mockContactById(String id) => mockContacts.firstWhere(
  (c) => c.id == id,
  orElse: () => mockContacts.first,
);

/// Kontakt uchun mock xabarlar (rasmga 1:1).
List<ChatMsg> mockMessages(String contactId) => const [
  ChatMsg(
    kind: ChatMsgKind.roundVideo,
    mine: true,
    time: '12 sen',
    durationSec: 12,
  ),
  ChatMsg(
    kind: ChatMsgKind.text,
    mine: false,
    time: '12 sen',
    text: "Ehtiyot bo'linglar",
  ),
  ChatMsg(
    kind: ChatMsgKind.text,
    mine: true,
    time: '12 sen',
    text: 'Xop boladi',
  ),
  ChatMsg(
    kind: ChatMsgKind.text,
    mine: true,
    time: '11:38',
    text: 'Assalomu alaykum',
    dayLabel: 'Bugun',
  ),
  ChatMsg(
    kind: ChatMsgKind.text,
    mine: false,
    time: '11:41',
    text: 'Uyga kirib obed qilib ket',
  ),
];
