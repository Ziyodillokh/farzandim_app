// ─────────────────────────────────────────────────────────────────────
// KelajakProgress — oxirgi natija oldingisiga nisbatan (ota-ona)
// ─────────────────────────────────────────────────────────────────────
//
// Backend `progress`: kategoriyalar (wellbeing / safety /
// parent_communication yo'q, nuqta kamida 2 javobdan, ≤12 nuqta) va
// qiziqish yo'nalishlari. Ballar 0–100; `previous`/`delta` — birinchi
// natijada `null`.

import 'package:farzandim/core/utils/safe_parse.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_text.dart';
import 'package:flutter/foundation.dart';

/// Kun bo'yicha ball ("YYYY-MM-DD", Toshkent kuni).
@immutable
class KelajakProgressPoint {
  const KelajakProgressPoint({required this.day, required this.score});

  factory KelajakProgressPoint.fromJson(Map<String, dynamic> json) =>
      KelajakProgressPoint(
        day: requireKelajakString(json, 'day'),
        score: readKelajakScore(json, 'score'),
      );

  final String day;
  final int score;
}

/// Kategoriya: oxirgi va oldingi ball.
@immutable
class KelajakProgressCategory {
  const KelajakProgressCategory({
    required this.category,
    required this.name,
    required this.latest,
    required this.points,
    this.previous,
    this.delta,
  });

  factory KelajakProgressCategory.fromJson(Map<String, dynamic> json) =>
      KelajakProgressCategory(
        category: requireKelajakString(json, 'category'),
        name: readKelajakText(json, 'name'),
        latest: readKelajakScore(json, 'latest'),
        previous: json.readIntOrNull('previous'),
        delta: json.readIntOrNull('delta'),
        points: readKelajakList(json, 'points', KelajakProgressPoint.fromJson),
      );

  final String category;
  final LocalizedText? name;
  final int latest;
  final int? previous;
  final int? delta;
  final List<KelajakProgressPoint> points;
}

/// Qiziqish yo'nalishi (RIASEC): oxirgi va oldingi ball.
@immutable
class KelajakProgressInterest {
  const KelajakProgressInterest({
    required this.code,
    required this.name,
    required this.latest,
    this.previous,
    this.delta,
  });

  factory KelajakProgressInterest.fromJson(Map<String, dynamic> json) =>
      KelajakProgressInterest(
        code: requireKelajakString(json, 'code'),
        name: readKelajakText(json, 'name'),
        latest: readKelajakScore(json, 'latest'),
        previous: json.readIntOrNull('previous'),
        delta: json.readIntOrNull('delta'),
      );

  final String code;
  final LocalizedText? name;
  final int latest;
  final int? previous;
  final int? delta;
}

@immutable
class KelajakProgress {
  const KelajakProgress({
    this.categories = const [],
    this.interests = const [],
  });

  factory KelajakProgress.fromJson(Map<String, dynamic> json) =>
      KelajakProgress(
        categories: readKelajakList(
          json,
          'categories',
          KelajakProgressCategory.fromJson,
        ),
        interests: readKelajakList(
          json,
          'interests',
          KelajakProgressInterest.fromJson,
        ),
      );

  final List<KelajakProgressCategory> categories;
  final List<KelajakProgressInterest> interests;

  bool get isEmpty => categories.isEmpty && interests.isEmpty;
}
