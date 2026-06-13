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

  // Reels = qisqa vertikal video. Duration noma'lum (0, masalan link orqali
  // qo'shilgan) bo'lsa reels EMAS — klassik landscape player ochiladi.
  bool get isReels => durationSeconds > 0 && durationSeconds <= 90;

  /// YouTube havolasidan 11 belgili video ID. YouTube emas bo'lsa `null`.
  ///
  /// Host-scoped: faqat youtube domeni oldidan kelgan ID olinadi —
  /// `.mp4?v=...` kabi to'g'ridan-to'g'ri havolalar (cache-buster `?v=`)
  /// xato YouTube deb topilmasligi uchun (admin formasi bilan bir xil mantiq).
  String? get youtubeId {
    final m = _youtubeRe.firstMatch(videoUrl.trim());
    return m?.group(1);
  }

  /// Havola YouTube videosimi (player tanlovi uchun).
  bool get isYouTube => youtubeId != null;
}

// youtu.be, youtube.com/watch?...v=, /embed/, /shorts/, /live/ — har xil
// subdomen (www/m/music) bilan. ID youtube domeni oldidan kelishi shart
// (mp4?v=... kabi to'g'ridan-to'g'ri havola bilan adashmaslik uchun).
final RegExp _youtubeRe = RegExp(
  r'(?:youtu\.be/|youtube\.com/(?:watch\?(?:[^ ]*&)?v=|embed/|shorts/|live/))([\w-]{11})',
);
