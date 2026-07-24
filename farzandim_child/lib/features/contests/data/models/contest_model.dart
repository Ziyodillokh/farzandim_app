// ─────────────────────────────────────────────────────────────────────
// ContestModel — bola uchun konkurs ma'lumotlari
// ─────────────────────────────────────────────────────────────────────
//
// `imageUrl` bo'sh bo'lsa `placeholderColor` + `placeholderIcon`
// ko'rsatiladi. Kelajakda Admin panel orqali real rasm yuklanadi va
// `imageUrl` to'ldiriladi — UI avtomatik almashadi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:flutter/material.dart';

/// Soha → rang (sevimli test keshidan tiklashda ham ishlatiladi).
Color contestSubjectColor(String subject) {
  switch (subject) {
    case 'Matematika':
      return AppColors.catIndigo;
    case 'Ona tili':
      return AppColors.catPink;
    case 'Ingliz':
      return AppColors.catTeal;
    case 'Fizika':
      return AppColors.catPurple;
    case 'Kimyo':
      return AppColors.warning;
    case 'IT':
      return AppColors.catEmerald;
    default:
      return AppColors.catLavenderDark;
  }
}

/// Soha → ikon.
IconData contestSubjectIcon(String subject) {
  switch (subject) {
    case 'Matematika':
      return Icons.calculate_outlined;
    case 'Ona tili':
      return AppIcons.menu;
    case 'Ingliz':
      return Icons.language_outlined;
    case 'Fizika':
      return Icons.science_outlined;
    case 'Kimyo':
      return Icons.biotech_outlined;
    case 'IT':
      return Icons.code_outlined;
    default:
      return AppIcons.trophy;
  }
}

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
    if (r.isNegative) return 'contests.ended'.tr();
    if (r.inDays > 0) return '${r.inDays} kun';
    if (r.inHours > 0) return '${r.inHours} soat';
    return '${r.inMinutes} daqiqa';
  }

  /// Sevimli test keshi uchun — rang/ikon soha'dan tiklanadi.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'soha': soha,
    'ishtirokchilarSoni': ishtirokchilarSoni,
    'deadline': deadline.toIso8601String(),
    'isActive': isActive,
    'bonus': bonus,
    'savollarSoni': savollarSoni,
    'vaqtChegarasiDaq': vaqtChegarasiDaq,
    'minAge': minAge,
    'maxAge': maxAge,
    'finishedDate': finishedDate?.toIso8601String(),
  };

  factory ContestModel.fromJson(Map<String, dynamic> j) {
    final soha = (j['soha'] as String?) ?? 'Aralash';
    return ContestModel(
      id: (j['id'] as String?) ?? '',
      title: (j['title'] as String?) ?? '—',
      description: (j['description'] as String?) ?? '',
      soha: soha,
      ishtirokchilarSoni: (j['ishtirokchilarSoni'] as num?)?.toInt() ?? 0,
      deadline:
          DateTime.tryParse((j['deadline'] as String?) ?? '') ?? DateTime.now(),
      isActive: j['isActive'] == true,
      placeholderColor: contestSubjectColor(soha),
      placeholderIcon: contestSubjectIcon(soha),
      bonus: (j['bonus'] as num?)?.toInt() ?? 50,
      savollarSoni: (j['savollarSoni'] as num?)?.toInt() ?? 0,
      vaqtChegarasiDaq: (j['vaqtChegarasiDaq'] as num?)?.toInt() ?? 30,
      minAge: (j['minAge'] as num?)?.toInt(),
      maxAge: (j['maxAge'] as num?)?.toInt(),
      finishedDate: DateTime.tryParse((j['finishedDate'] as String?) ?? ''),
    );
  }
}
