// Kelajak bosh ma'lumoti (§4 `OverviewView`): yosh holati, bugungi testlar,
// kategoriya nomlari va kumulyativ profil.

import 'package:farzandim_child/features/kelajak/domain/kelajak_insights.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_json.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_types.dart';
import 'package:farzandim_child/features/learning/domain/localized_text.dart';
import 'package:farzandim_child/features/school/domain/school_json.dart';

/// Yosh holati (yosh taxmin qilinmaydi — server hisoblaydi).
class KelajakAge {
  const KelajakAge({required this.status, this.age, this.ageGroup});

  factory KelajakAge.fromJson(Object? json) {
    final map = jsonMap(json);
    return KelajakAge(
      status: KelajakAgeStatus.fromWire(map?['status']),
      age: jsonInt(map?['age']),
      ageGroup: jsonNonEmpty(map?['ageGroup']),
    );
  }

  final KelajakAgeStatus status;
  final int? age;

  /// `7-9`, `10-12`, `13-15`, `16-18`.
  final String? ageGroup;

  bool get isOk => status == KelajakAgeStatus.ok;
}

/// Testning bugungi holati.
class KelajakToday {
  const KelajakToday({required this.status, this.sessionId});

  factory KelajakToday.fromJson(Object? json) {
    final map = jsonMap(json);
    return KelajakToday(
      status: KelajakTodayStatus.fromWire(map?['status']),
      sessionId: jsonNonEmpty(map?['sessionId']),
    );
  }

  final KelajakTodayStatus status;
  final String? sessionId;

  bool get isCompleted => status == KelajakTodayStatus.completed;

  /// Boshlangan, lekin hali yakunlanmagan.
  bool get isUnfinished =>
      status == KelajakTodayStatus.started ||
      status == KelajakTodayStatus.inProgress;
}

/// Overview'dagi test kartasi.
class KelajakTestInfo {
  const KelajakTestInfo({
    required this.type,
    required this.title,
    required this.today,
    this.description,
    this.questionCount = 0,
    this.estimatedMinutes = 0,
  });

  static KelajakTestInfo? tryFromJson(Object? json) {
    final map = jsonMap(json);
    final type = jsonNonEmpty(map?['type']);
    final title = jsonLocalized(map?['title']);
    if (map == null || type == null || title == null) return null;
    return KelajakTestInfo(
      type: type,
      title: title,
      today: KelajakToday.fromJson(map['today']),
      description: jsonLocalized(map['description']),
      questionCount: jsonCount(map['questionCount']),
      estimatedMinutes: jsonCount(map['estimatedMinutes']),
    );
  }

  /// Server test turi (`daily`, `career` …) — sessiya shu bilan boshlanadi.
  final String type;
  final LocalizedText title;
  final KelajakToday today;
  final LocalizedText? description;
  final int questionCount;
  final int estimatedMinutes;

  KelajakTestType get testType => KelajakTestType.fromWire(type);
}

/// Kategoriya nomi va tartibi.
class KelajakCategory {
  const KelajakCategory({
    required this.id,
    required this.name,
    required this.order,
  });

  static KelajakCategory? tryFromJson(Object? json) {
    final map = jsonMap(json);
    final id = jsonNonEmpty(map?['id']);
    final name = jsonLocalized(map?['name']);
    if (map == null || id == null || name == null) return null;
    return KelajakCategory(id: id, name: name, order: jsonCount(map['order']));
  }

  final String id;
  final LocalizedText name;
  final int order;
}

class KelajakOverview {
  const KelajakOverview({
    required this.age,
    required this.tests,
    required this.categories,
    this.profile,
  });

  factory KelajakOverview.fromJson(Object? json) {
    final map = jsonMap(json);
    if (map == null) {
      throw const FormatException('KelajakOverview: obyekt kerak');
    }
    final categories = [
      ...uniqueBy(
        jsonList(map['categories'], KelajakCategory.tryFromJson),
        (c) => c.id,
      ),
    ]..sort((a, b) => a.order.compareTo(b.order));
    return KelajakOverview(
      age: KelajakAge.fromJson(map['age']),
      tests: uniqueBy(
        jsonList(map['tests'], KelajakTestInfo.tryFromJson),
        (t) => t.type,
      ),
      categories: List.unmodifiable(categories),
      profile: KelajakProfile.tryFromJson(map['profile']),
    );
  }

  final KelajakAge age;

  /// Bugungi testlar (yosh `OK` bo'lmasa bo'sh).
  final List<KelajakTestInfo> tests;

  /// Kategoriyalar — `order` bo'yicha.
  final List<KelajakCategory> categories;

  /// Kumulyativ profil (`null` — hali yakunlangan sessiya yo'q).
  final KelajakProfile? profile;

  /// Tur bo'yicha test (`null` — bugun berilmaydi).
  KelajakTestInfo? testOf(String type) {
    for (final test in tests) {
      if (test.type == type) return test;
    }
    return null;
  }

  /// "Bugungi testlar"dagi kunlik savollar.
  KelajakTestInfo? get daily => testOf(KelajakTestType.daily.wire);

  /// Kategoriya nomi (`null` — noma'lum kategoriya).
  LocalizedText? categoryName(String id) {
    for (final category in categories) {
      if (category.id == id) return category.name;
    }
    return null;
  }
}
