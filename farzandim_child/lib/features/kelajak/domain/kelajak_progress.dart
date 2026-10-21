// Kelajak rivojlanishi (§4 `ProgressView`) va natijalar tarixi
// (`SessionSummaryView`, kursorli sahifalar).

import 'package:farzandim_child/features/kelajak/domain/kelajak_json.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_types.dart';
import 'package:farzandim_child/features/learning/domain/localized_text.dart';
import 'package:farzandim_child/features/school/domain/school_json.dart';

/// Yakunlangan sessiya qisqachasi.
class KelajakSessionSummary {
  const KelajakSessionSummary({
    required this.id,
    required this.type,
    required this.status,
    this.title,
    this.day,
    this.completedAt,
    this.answered = 0,
    this.total = 0,
  });

  static KelajakSessionSummary? tryFromJson(Object? json) {
    final map = jsonMap(json);
    final id = jsonNonEmpty(map?['id']);
    final type = jsonNonEmpty(map?['type']);
    if (map == null || id == null || type == null) return null;
    return KelajakSessionSummary(
      id: id,
      type: type,
      status: KelajakSessionStatus.fromWire(map['status']),
      title: jsonLocalized(map['title']),
      day: jsonDay(map['day']),
      completedAt: jsonInstant(map['completedAt']),
      answered: jsonCount(map['answered']),
      total: jsonCount(map['total']),
    );
  }

  final String id;
  final String type;
  final KelajakSessionStatus status;
  final LocalizedText? title;
  final DateTime? day;
  final DateTime? completedAt;
  final int answered;
  final int total;

  KelajakTestType get testType => KelajakTestType.fromWire(type);
}

/// Grafik nuqtasi (kun bo'yicha ball).
class KelajakPoint {
  const KelajakPoint({required this.day, required this.score});

  static KelajakPoint? tryFromJson(Object? json) {
    final map = jsonMap(json);
    final day = jsonDay(map?['day']);
    final score = jsonScore(map?['score']);
    if (day == null || score == null) return null;
    return KelajakPoint(day: day, score: score);
  }

  final DateTime day;
  final int score;
}

/// Kategoriya o'zgarishi: oxirgi va oldingi ball.
class KelajakProgressCategory {
  const KelajakProgressCategory({
    required this.category,
    required this.name,
    required this.latest,
    required this.points,
    this.previous,
    this.delta,
  });

  static KelajakProgressCategory? tryFromJson(Object? json) {
    final map = jsonMap(json);
    final category = jsonNonEmpty(map?['category']);
    final latest = jsonScore(map?['latest']);
    if (map == null || category == null || latest == null) return null;
    return KelajakProgressCategory(
      category: category,
      name: jsonLocalized(map['name']) ?? LocalizedText.same(category),
      latest: latest,
      previous: jsonScore(map['previous']),
      delta: jsonScore(map['delta']),
      points: jsonList(map['points'], KelajakPoint.tryFromJson),
    );
  }

  final String category;
  final LocalizedText name;
  final int latest;

  /// `null` — hali bitta o'lchov.
  final int? previous;
  final int? delta;
  final List<KelajakPoint> points;
}

/// RIASEC qiziqishi o'zgarishi.
class KelajakProgressInterest {
  const KelajakProgressInterest({
    required this.code,
    required this.name,
    required this.latest,
    this.previous,
    this.delta,
  });

  static KelajakProgressInterest? tryFromJson(Object? json) {
    final map = jsonMap(json);
    final code = jsonNonEmpty(map?['code']);
    final latest = jsonScore(map?['latest']);
    if (map == null || code == null || latest == null) return null;
    return KelajakProgressInterest(
      code: code,
      name: jsonLocalized(map['name']) ?? LocalizedText.same(code),
      latest: latest,
      previous: jsonScore(map['previous']),
      delta: jsonScore(map['delta']),
    );
  }

  final String code;
  final LocalizedText name;
  final int latest;
  final int? previous;
  final int? delta;
}

class KelajakProgress {
  const KelajakProgress({
    required this.sessionsCompleted,
    this.firstCompletedAt,
    this.lastCompletedAt,
    this.categories = const [],
    this.interests = const [],
    this.improved = const [],
    this.interestsRising = const [],
    this.history = const [],
  });

  factory KelajakProgress.fromJson(Object? json) {
    final map = jsonMap(json);
    if (map == null) {
      throw const FormatException('KelajakProgress: obyekt kerak');
    }
    return KelajakProgress(
      sessionsCompleted: jsonCount(map['sessionsCompleted']),
      firstCompletedAt: jsonInstant(map['firstCompletedAt']),
      lastCompletedAt: jsonInstant(map['lastCompletedAt']),
      categories: jsonList(
        map['categories'],
        KelajakProgressCategory.tryFromJson,
      ),
      interests: jsonList(
        map['interests'],
        KelajakProgressInterest.tryFromJson,
      ),
      improved: jsonStrings(map['improved']),
      interestsRising: jsonStrings(map['interestsRising']),
      history: jsonList(map['history'], KelajakSessionSummary.tryFromJson),
    );
  }

  final int sessionsCompleted;
  final DateTime? firstCompletedAt;
  final DateTime? lastCompletedAt;

  /// wellbeing / safety yo'q.
  final List<KelajakProgressCategory> categories;
  final List<KelajakProgressInterest> interests;

  /// O'sgan kategoriyalar (delta ≥ 10).
  final List<String> improved;

  /// O'sgan qiziqishlar (RIASEC kodlari).
  final List<String> interestsRising;

  /// Oxirgi sessiyalar — yangisi birinchi.
  final List<KelajakSessionSummary> history;

  bool get isEmpty => sessionsCompleted == 0;

  /// O'sgan kategoriyalar (tartib — serverdagidek).
  List<KelajakProgressCategory> get improvedCategories =>
      List.unmodifiable(categories.where((c) => improved.contains(c.category)));

  /// O'sgan qiziqishlar.
  List<KelajakProgressInterest> get risingInterests => List.unmodifiable(
    interests.where((i) => interestsRising.contains(i.code)),
  );
}

/// Natijalar sahifasi (`nextBefore` — keyingi sahifa kursori).
class KelajakResultsPage {
  const KelajakResultsPage({required this.items, this.nextBefore});

  factory KelajakResultsPage.fromJson(Object? json) {
    final map = jsonMap(json);
    if (map == null) {
      throw const FormatException('KelajakResultsPage: obyekt kerak');
    }
    return KelajakResultsPage(
      items: jsonList(map['items'], KelajakSessionSummary.tryFromJson),
      nextBefore: jsonNonEmpty(map['nextBefore']),
    );
  }

  final List<KelajakSessionSummary> items;
  final String? nextBefore;

  bool get hasMore => nextBefore != null;
}
