// ─────────────────────────────────────────────────────────────────────
// KelajakSummary — bolaning Kelajak xulosasi (ota-ona ko'rinishi)
// ─────────────────────────────────────────────────────────────────────
//
// Backend: GET /api/children/:childId/kelajak/summary
// (`ParentSummaryView`, docs/KELAJAK-REJA.md §5). Maxfiylik: savol
// darajasidagi javoblar, ochiq matn, wellbeing/safety raqamlari va
// `parent_communication` kelmaydi; kategoriya — kamida 2 javobdan.
// Yosh: `AGE_REQUIRED` — xato emas, xulosaning bir holati.

import 'dart:math' as math;

import 'package:farzandim/core/utils/safe_parse.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_insights.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_progress.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_support.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_text.dart';
import 'package:flutter/foundation.dart';

/// Yosh holati: savollar shu yosh guruhidan tanlanadi.
enum KelajakAgeStatus {
  ok,
  ageRequired,
  ageOutOfRange,
  unknown;

  static KelajakAgeStatus fromApi(Object? raw) => switch (raw) {
    'OK' => ok,
    'AGE_REQUIRED' => ageRequired,
    'AGE_OUT_OF_RANGE' => ageOutOfRange,
    _ => unknown,
  };
}

@immutable
class KelajakAge {
  const KelajakAge({required this.status, this.age, this.ageGroup});

  factory KelajakAge.fromJson(Map<String, dynamic> json) => KelajakAge(
    status: KelajakAgeStatus.fromApi(json['status']),
    age: json.readIntOrNull('age'),
    ageGroup: json.readStringOrNull('ageGroup'),
  );

  final KelajakAgeStatus status;
  final int? age;

  /// "7-9" | "10-12" | "13-15" | "16-18".
  final String? ageGroup;
}

/// Kategoriya bali (kumulyativ profil).
@immutable
class KelajakCategoryScore {
  const KelajakCategoryScore({
    required this.category,
    required this.score,
    required this.answered,
    this.name,
  });

  factory KelajakCategoryScore.fromJson(Map<String, dynamic> json) =>
      KelajakCategoryScore(
        category: requireKelajakString(json, 'category'),
        name: readKelajakText(json, 'name'),
        score: readKelajakScore(json, 'score'),
        answered: json.readInt('answered'),
      );

  final String category;
  final LocalizedText? name;
  final int score;
  final int answered;
}

/// RIASEC yo'nalishi bali.
@immutable
class KelajakInterestDimension {
  const KelajakInterestDimension({
    required this.code,
    required this.score,
    required this.answered,
    this.name,
  });

  factory KelajakInterestDimension.fromJson(Map<String, dynamic> json) =>
      KelajakInterestDimension(
        code: requireKelajakString(json, 'code'),
        name: readKelajakText(json, 'name'),
        score: readKelajakScore(json, 'score'),
        answered: json.readInt('answered'),
      );

  final String code;
  final LocalizedText? name;
  final int score;
  final int answered;
}

/// Qiziqishlar profili: yo'nalishlar, top kodlar va ishonchlilik.
@immutable
class KelajakInterests {
  const KelajakInterests({
    required this.dimensions,
    required this.top,
    required this.reliable,
  });

  static KelajakInterests? tryParse(Object? raw) {
    final json = asJsonMap(raw);
    if (json == null) return null;
    return KelajakInterests(
      dimensions: readKelajakList(
        json,
        'dimensions',
        KelajakInterestDimension.fromJson,
      ),
      top: List.unmodifiable(json.readList('top').whereType<String>()),
      reliable: json.readBool('reliable'),
    );
  }

  final List<KelajakInterestDimension> dimensions;
  final List<String> top;

  /// Har top yo'nalishda kamida 2 javob — shundagina yo'nalish tavsiyasi.
  final bool reliable;

  /// [code] yo'nalishining nomi ("A" → "Ijodiy"); topilmasa `null`.
  LocalizedText? nameOf(String? code) {
    if (code == null) return null;
    for (final dimension in dimensions) {
      if (dimension.code == code) return dimension.name;
    }
    return null;
  }
}

@immutable
class KelajakSummary {
  const KelajakSummary({
    required this.age,
    required this.sessionsCompleted,
    required this.categories,
    required this.insights,
    required this.progress,
    this.lastCompletedAt,
    this.interests,
    this.support,
    this.disclaimer,
  });

  factory KelajakSummary.fromJson(Map<String, dynamic> json) => KelajakSummary(
    age: KelajakAge.fromJson(json.readMapOrNull('age') ?? const {}),
    sessionsCompleted: math.max(0, json.readInt('sessionsCompleted')),
    lastCompletedAt: json.readDateTime('lastCompletedAt'),
    categories: readKelajakList(
      json,
      'categories',
      KelajakCategoryScore.fromJson,
    ),
    interests: KelajakInterests.tryParse(json['interests']),
    insights: KelajakInsights.fromJson(
      json.readMapOrNull('insights') ?? const {},
    ),
    support: KelajakSupport.tryParse(json['support']),
    progress: KelajakProgress.fromJson(
      json.readMapOrNull('progress') ?? const {},
    ),
    disclaimer: readKelajakText(json, 'disclaimer'),
  );

  final KelajakAge age;
  final int sessionsCompleted;

  /// Oxirgi yakunlangan sessiya (mahalliy vaqt); hali yo'q → `null`.
  final DateTime? lastCompletedAt;
  final List<KelajakCategoryScore> categories;
  final KelajakInterests? interests;
  final KelajakInsights insights;

  /// Qo'llab-quvvatlash signali; signal yo'q → `null`.
  final KelajakSupport? support;
  final KelajakProgress progress;
  final LocalizedText? disclaimer;

  bool get hasAnswers => sessionsCompleted > 0;
}
