// ─────────────────────────────────────────────────────────────────────
// AudiobookModel — bola audiokitobi
// ─────────────────────────────────────────────────────────────────────
//
// Hozircha mock — `MockAudiobooks.all` ro'yxatda saqlanadi. Kelajakda
// admin panel orqali Firestore'ga joylanadigan real audiokitoblar bilan
// almashtiriladi.

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
  });
}
