// ─────────────────────────────────────────────────────────────────────
// ArticleModel — foydali maqola / bilim (#48)
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakti (GET /api/content/articles):
//   { items: [{ id, title, body(markdown), coverUrl, ageFrom, ageTo,
//               category, views, createdAt }], pagination: {...} }

import 'package:flutter/material.dart';

@immutable
class ArticleModel {
  const ArticleModel({
    required this.id,
    required this.title,
    required this.body,
    required this.coverUrl,
    required this.category,
    required this.ageFrom,
    required this.ageTo,
    required this.views,
    required this.coverColor,
    this.likes = 0,
  });

  final String id;
  final String title;

  /// Markdown matn (o'qish ekranida render qilinadi).
  final String body;

  /// Muqova rasm URL (bo'sh bo'lishi mumkin — fallback rang ishlatiladi).
  final String coverUrl;
  final String category;
  final int ageFrom;
  final int ageTo;
  final int views;

  /// Yoqtirishlar soni (backend global hisoblagichi).
  final int likes;

  /// Muqovasiz maqola uchun barqaror fallback rang.
  final Color coverColor;

  bool get hasCover => coverUrl.isNotEmpty;

  String get yoshGuruhi => '$ageFrom-$ageTo';
}
