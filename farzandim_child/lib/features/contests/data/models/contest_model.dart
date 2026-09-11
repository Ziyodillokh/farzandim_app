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

/// Fan nomini kalitga keltiradi — rang/ikon tanlashning YAGONA manbai
/// (repository ham, sevimlilar keshi ham shu orqali o'tadi).
///
/// Backend `subject`ni erkin satr sifatida qabul qiladi, admin sehrgari esa
/// "Ingliz tili", "IT / Mantiq" kabi yozuvlarni yuboradi. Avval bu yerda aniq
/// matn bo'yicha (`'Ingliz'`, `'IT'`) solishtirilardi — shuning uchun o'sha
/// fanlar hech qachon o'z ikonkasini olmasdi, default kubokka tushardi.
/// Endi registr, ortiqcha bo'sh joy, apostrof turi ("o'" / "oʻ" / "o’") va
/// "Matematika 8-sinf" kabi qo'shimchalar e'tiborga olinmaydi.
String contestSubjectKey(String subject) {
  final s = subject
      .trim()
      .toLowerCase()
      .replaceAll(RegExp("[’ʻ`´]"), "'");
  if (s.isEmpty) return '';
  if (s.startsWith('matem') ||
      s.startsWith('geometr') ||
      s.startsWith('algebra')) {
    return 'matematika';
  }
  if (s.startsWith('ona til') ||
      s.startsWith("o'zbek til") ||
      s.startsWith('adabiyot')) {
    return 'ona_tili';
  }
  if (s.startsWith('ingliz') || s.startsWith('english')) return 'ingliz';
  if (s.startsWith('fizik')) return 'fizika';
  if (s.startsWith('kimyo') || s.startsWith('ximiya')) return 'kimyo';
  if (s.startsWith('biolog')) return 'biologiya';
  if (s.startsWith('geograf')) return 'geografiya';
  if (s.startsWith('tarix')) return 'tarix';
  // "IT", "IT / Mantiq", "Informatika", "Dasturlash" — lekin "Italyan tili"
  // emas: `\b` so'z chegarasi shart.
  if (RegExp(r'^it\b').hasMatch(s) ||
      s.startsWith('informatika') ||
      s.startsWith('mantiq') ||
      s.startsWith('dasturlash')) {
    return 'it';
  }
  return s;
}

/// Soha → rang (sevimli test keshidan tiklashda ham ishlatiladi).
Color contestSubjectColor(String subject) {
  switch (contestSubjectKey(subject)) {
    case 'matematika':
      return AppColors.catIndigo;
    case 'ona_tili':
      return AppColors.catPink;
    case 'ingliz':
      return AppColors.catTeal;
    case 'fizika':
      return AppColors.catPurple;
    case 'kimyo':
      return AppColors.warning;
    case 'biologiya':
      return AppColors.catGreen;
    case 'geografiya':
      return AppColors.catBlue;
    case 'tarix':
      return AppColors.catAmber;
    case 'it':
      return AppColors.catEmerald;
    default:
      return AppColors.catLavenderDark;
  }
}

/// Soha → ikon.
IconData contestSubjectIcon(String subject) {
  switch (contestSubjectKey(subject)) {
    case 'matematika':
      return Icons.calculate_outlined;
    case 'ona_tili':
      // Avval `AppIcons.menu` (gamburger) turardi — ochiq kitob to'g'riroq.
      return Icons.menu_book_outlined;
    case 'ingliz':
      return Icons.language_outlined;
    case 'fizika':
      return Icons.science_outlined;
    case 'kimyo':
      return Icons.biotech_outlined;
    case 'biologiya':
      return Icons.eco_outlined;
    case 'geografiya':
      return Icons.public_outlined;
    case 'tarix':
      return Icons.history_edu_outlined;
    case 'it':
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
