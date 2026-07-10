// ─────────────────────────────────────────────────────────────────────
// video_api_mapper — backend video DTO → VideoModel (yagona manba)
// ─────────────────────────────────────────────────────────────────────
//
// Backend `/content/videos`, `/content/history/videos`,
// `/content/favorites/videos` — hammasi BIR XIL video shaklini qaytaradi
// (consumer-content.service.mapVideo). Shuning uchun parslash bitta joyda.

// ignore_for_file: public_member_api_docs

import 'package:farzandim_child/core/config/env_config.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/videos/data/models/video_model.dart';
import 'package:flutter/material.dart';

VideoModel videoFromApiJson(Map<String, dynamic> raw) {
  final id = raw['id']?.toString() ?? '';
  final durationSec = (raw['durationSec'] as num?)?.toInt() ?? 0;
  final ageFrom = (raw['ageFrom'] as num?)?.toInt() ?? 0;
  final ageTo = (raw['ageTo'] as num?)?.toInt() ?? 18;
  final category = (raw['category'] as String?)?.trim();
  return VideoModel(
    id: id,
    title: (raw['title'] as String?) ?? '—',
    description: (raw['description'] as String?) ?? '',
    thumbnailUrl: EnvConfig.resolveMediaUrl(
      (raw['thumbnail'] as String?) ?? '',
    ),
    duration: _formatDuration(durationSec),
    durationSeconds: durationSec,
    videoUrl: EnvConfig.resolveMediaUrl((raw['url'] as String?) ?? ''),
    category: category?.isNotEmpty == true
        ? _humanCategory(category!)
        : 'Boshqa',
    soha: _sohaFor(category),
    yonalish: "Ta'lim",
    yoshGuruhi: '$ageFrom-$ageTo',
    hashtags: const [],
    views: (raw['views'] as num?)?.toInt() ?? 0,
    thumbnailColor: _thumbnailColorFor(id),
  );
}

String _humanCategory(String slug) {
  switch (slug) {
    case 'multfilmlar':
      return 'Multfilmlar';
    case 'qoshiqlar':
      return "Qo'shiqlar";
    case 'ta-limiy':
      return "Ta'limiy";
    case 'sport':
      return 'Sport';
    default:
      return slug;
  }
}

String _sohaFor(String? slug) {
  if (slug == null) return 'Aralash';
  if (slug.contains('multfilm') || slug.contains('qoshiq')) return 'Ijodiy';
  if (slug.contains('sport')) return 'Jismoniy';
  return 'Aniq fanlar';
}

String _formatDuration(int sec) {
  if (sec <= 0) return '0:00';
  final m = sec ~/ 60;
  final s = (sec % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Deterministik thumbnail rangi — bir xil video bir xil rang bilan.
Color _thumbnailColorFor(String id) {
  if (id.isEmpty) return AppColors.catLavenderDark;
  var hash = 0;
  for (final code in id.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  const palette = <Color>[
    AppColors.catLavenderDark,
    AppColors.warning,
    AppColors.catPink,
    AppColors.catEmerald,
    AppColors.catIndigo,
    AppColors.catTeal,
    AppColors.catOrangeDark,
    AppColors.catPurple,
  ];
  return palette[hash % palette.length];
}
