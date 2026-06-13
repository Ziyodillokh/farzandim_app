// ─────────────────────────────────────────────────────────────────────
// VideoModel — bola feed'idagi video ma'lumotlari
// ─────────────────────────────────────────────────────────────────────
//
// Backend `/api/content/videos` dan keladigan model. Admin panel yuklaydi,
// backend bola yoshi (child.age) bo'yicha filtrlaydi.
//
// `isReels` — video 90 sekund yoki kamroq bo'lsa true. Reels player
// (vertikal PageView) bilan ochiladi; aks holda klassik landscape
// player ishlatiladi.

import 'package:flutter/material.dart';

class VideoModel {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String duration;
  final int durationSeconds;
  final String videoUrl;
  final String category;
  final String soha;
  final String yonalish;
  final String yoshGuruhi;
  final List<String> hashtags;
  final int views;
  final Color thumbnailColor;

  const VideoModel({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.duration,
    required this.durationSeconds,
    required this.videoUrl,
    required this.category,
    required this.soha,
    required this.yonalish,
    required this.yoshGuruhi,
    required this.hashtags,
    required this.views,
    required this.thumbnailColor,
  });

  bool get isReels => durationSeconds <= 90;
}
