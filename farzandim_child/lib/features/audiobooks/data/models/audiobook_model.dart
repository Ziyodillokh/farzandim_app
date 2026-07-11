// ─────────────────────────────────────────────────────────────────────
// AudiobookModel — bola audiokitobi
// ─────────────────────────────────────────────────────────────────────
//
// Backend `/api/content/audiobooks` dan keladigan model. Admin panel
// yuklaydi, backend bola yoshi bo'yicha filtrlaydi.

import 'package:flutter/material.dart';

class AudiobookModel {
  final String id;
  final String title;
  final String author;
  final String description;
  final String coverUrl;
  final String audioUrl;
  final int durationSeconds;
  final String duration;
  final String category;
  final List<String> hashtags;
  final int listenCount;
  final Color coverColor;

  /// Qismlar soni (backend: `partsCount`). 0/1 bo'lsa yagona qism sifatida
  /// ko'rsatiladi. UI qismlar ro'yxati va navigatsiya uchun ishlatadi.
  final int partsCount;

  const AudiobookModel({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.coverUrl,
    required this.audioUrl,
    required this.durationSeconds,
    required this.duration,
    required this.category,
    required this.hashtags,
    required this.listenCount,
    required this.coverColor,
    this.partsCount = 1,
  });
}
