// ─────────────────────────────────────────────────────────────────────
// ContestModel — bola uchun konkurs ma'lumotlari
// ─────────────────────────────────────────────────────────────────────
//
// `imageUrl` bo'sh bo'lsa `placeholderColor` + `placeholderIcon`
// ko'rsatiladi. Kelajakda Admin panel orqali real rasm yuklanadi va
// `imageUrl` to'ldiriladi — UI avtomatik almashadi.

import 'package:flutter/material.dart';

class ContestModel {
  final String id;
  final String title;
  final String description;
  final String soha;
  final int ishtirokchilarSoni;
  final DateTime deadline;
  final bool isActive;
  final String imageUrl;
  final Color placeholderColor;
  final IconData placeholderIcon;
  final int bonus;
  final int savollarSoni;
  final int vaqtChegarasiDaq;

  // Admin qo'ygan yosh chegarasi (backend ageFrom/ageTo). Bola UI'da
  // "N-M yosh uchun" deb ko'rsatiladi.
  final int? minAge;
  final int? maxAge;

  // Faqat yakunlangan uchun.
  final DateTime? finishedDate;

  const ContestModel({
    required this.id,
    required this.title,
    required this.description,
    required this.soha,
    required this.ishtirokchilarSoni,
    required this.deadline,
    required this.isActive,
    this.imageUrl = '',
    required this.placeholderColor,
    required this.placeholderIcon,
    required this.bonus,
    required this.savollarSoni,
    required this.vaqtChegarasiDaq,
    this.minAge,
    this.maxAge,
    this.finishedDate,
  });

  /// "7-12 yosh" ko'rinishidagi yorliq — ikkala chegara ham bo'lsa.
  String? get ageLabel =>
      (minAge != null && maxAge != null) ? '$minAge-$maxAge yosh' : null;

  Duration get remaining => deadline.difference(DateTime.now());

  String get remainingFormatted {
    final r = remaining;
    if (r.isNegative) return 'Tugadi';
    if (r.inDays > 0) return '${r.inDays} kun';
    if (r.inHours > 0) return '${r.inHours} soat';
    return '${r.inMinutes} daqiqa';
  }
}
