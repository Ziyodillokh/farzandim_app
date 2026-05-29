// ─────────────────────────────────────────────────────────────────────
// SocialPost — ichki sotsial feed posti (PDF p18, 24)
// ─────────────────────────────────────────────────────────────────────
//
// Konsept: ichki sotsial tarmoq — tashqi link YO'Q, faqat ruxsatli
// kontent yaratuvchilar (admin, ustozlar) post yaratadi. Bola
// kuzatish (follow) + yoqtirish (like) qila oladi.
//
// Hozir mock data — kelajakda Firestore `social_posts` collection.

import 'package:flutter/material.dart';

enum SocialMediaType { text, image, video }

extension SocialMediaTypeX on SocialMediaType {
  String get firestoreCode {
    switch (this) {
      case SocialMediaType.text:
        return 'text';
      case SocialMediaType.image:
        return 'image';
      case SocialMediaType.video:
        return 'video';
    }
  }

  IconData get icon {
    switch (this) {
      case SocialMediaType.text:
        return Icons.text_fields;
      case SocialMediaType.image:
        return Icons.image;
      case SocialMediaType.video:
        return Icons.play_circle_outline;
    }
  }
}

class SocialAuthor {
  const SocialAuthor({
    required this.id,
    required this.name,
    this.avatarColor,
    this.verified = false,
  });

  final String id;
  final String name;

  /// Avatar uchun rang (placeholder, real avatar URL keladi keyin).
  final Color? avatarColor;

  /// Tasdiqlangan akkaunt (admin, ustoz).
  final bool verified;
}

class SocialPost {
  const SocialPost({
    required this.id,
    required this.author,
    required this.text,
    required this.mediaType,
    required this.tags,
    required this.likes,
    required this.createdAt,
    this.mediaUrl,
    this.thumbnailColor,
  });

  final String id;
  final SocialAuthor author;
  final String text;
  final SocialMediaType mediaType;
  final List<String> tags;
  final int likes;
  final DateTime createdAt;

  /// Image yoki video URL (mediaType bo'yicha).
  final String? mediaUrl;

  /// Media placeholder rang (image yuklanmaguncha).
  final Color? thumbnailColor;
}
