// Kelajak natija modellari (§4 `CategoryScoreView`, `InterestsView`,
// `InsightsView`, `ResultView`, `ProfileView`). Bolaga — sodda tavsiyalar:
// kasb bo'yicha qat'iy hukm yo'q, qo'llab-quvvatlash — raqamsiz xabar.
// Buzilgan ro'yxat elementlari tashlab yuboriladi, ixtiyoriy maydon
// bo'lmasa — bo'sh qiymat.

import 'package:farzandim_child/features/kelajak/domain/kelajak_json.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_types.dart';
import 'package:farzandim_child/features/learning/domain/localized_text.dart';
import 'package:farzandim_child/features/school/domain/school_json.dart';

/// Kategoriya bali (0–100) — wellbeing / safety bu yerda kelmaydi.
class KelajakCategoryScore {
  const KelajakCategoryScore({
    required this.category,
    required this.name,
    required this.score,
    required this.answered,
  });

  static KelajakCategoryScore? tryFromJson(Object? json) {
    final map = jsonMap(json);
    final category = jsonNonEmpty(map?['category']);
    final score = jsonScore(map?['score']);
    if (map == null || category == null || score == null) return null;
    return KelajakCategoryScore(
      category: category,
      name: jsonLocalized(map['name']) ?? LocalizedText.same(category),
      score: score,
      answered: jsonCount(map['answered']),
    );
  }

  final String category;
  final LocalizedText name;
  final int score;
  final int answered;
}

/// RIASEC o'lchami (R, I, A, S, E, C).
class KelajakDimension {
  const KelajakDimension({
    required this.code,
    required this.name,
    required this.score,
    required this.answered,
  });

  static KelajakDimension? tryFromJson(Object? json) {
    final map = jsonMap(json);
    final code = jsonNonEmpty(map?['code']);
    final score = jsonScore(map?['score']);
    if (map == null || code == null || score == null) return null;
    return KelajakDimension(
      code: code,
      name: jsonLocalized(map['name']) ?? LocalizedText.same(code),
      score: score,
      answered: jsonCount(map['answered']),
    );
  }

  final String code;
  final LocalizedText name;
  final int score;
  final int answered;
}

/// Qiziqishlar: o'lchamlar, top kodlar va ishonchlilik.
class KelajakInterests {
  const KelajakInterests({
    required this.dimensions,
    required this.top,
    required this.isReliable,
  });

  static KelajakInterests? tryFromJson(Object? json) {
    final map = jsonMap(json);
    if (map == null) return null;
    return KelajakInterests(
      dimensions: jsonList(map['dimensions'], KelajakDimension.tryFromJson),
      top: jsonStrings(map['top']),
      isReliable: map['reliable'] == true,
    );
  }

  final List<KelajakDimension> dimensions;

  /// Eng yuqori o'lchamlar (≥50 ball), kamayish tartibida.
  final List<String> top;

  /// Har top o'lchamda ≥2 javob — yo'nalish tavsiyasi faqat shunda.
  final bool isReliable;
}

/// Kuchli tomon (kategoriya kaliti va nomi).
class KelajakStrength {
  const KelajakStrength({required this.key, required this.title});

  static KelajakStrength? tryFromJson(Object? json) {
    final map = jsonMap(json);
    final key = jsonNonEmpty(map?['key']);
    final title = jsonLocalized(map?['title']);
    if (key == null || title == null) return null;
    return KelajakStrength(key: key, title: title);
  }

  final String key;
  final LocalizedText title;
}

/// Qiziqish yo'nalishi: qisqa tavsif va sinab ko'rish mumkin bo'lgan sohalar.
class KelajakInterestInsight {
  const KelajakInterestInsight({
    required this.code,
    required this.title,
    required this.body,
    required this.suggestions,
  });

  static KelajakInterestInsight? tryFromJson(Object? json) {
    final map = jsonMap(json);
    final code = jsonNonEmpty(map?['code']);
    final title = jsonLocalized(map?['title']);
    if (map == null || code == null || title == null) return null;
    return KelajakInterestInsight(
      code: code,
      title: title,
      body: jsonLocalized(map['body']),
      suggestions: jsonList(map['suggestions'], jsonLocalized),
    );
  }

  final String code;
  final LocalizedText title;
  final LocalizedText? body;
  final List<LocalizedText> suggestions;
}

/// Career Lab faoliyati (yoqqan yoki sinalgan yo'nalish).
class KelajakDirection {
  const KelajakDirection({
    required this.activity,
    this.externalId,
    this.code,
    this.rating,
    this.verdict,
  });

  static KelajakDirection? tryFromJson(Object? json) {
    final map = jsonMap(json);
    final activity = jsonLocalized(map?['activity']);
    if (map == null || activity == null) return null;
    final verdict = map['verdict'];
    return KelajakDirection(
      activity: activity,
      externalId: jsonNonEmpty(map['externalId']),
      code: jsonNonEmpty(map['code']),
      rating: jsonInt(map['rating']),
      verdict: verdict == null ? null : KelajakVerdict.fromWire(verdict),
    );
  }

  final LocalizedText activity;
  final String? externalId;

  /// RIASEC kodi (`null` — umumiy faoliyat).
  final String? code;

  /// Xom reyting (shkala qiymati).
  final int? rating;

  /// Faqat sinalgan yo'nalishlarda.
  final KelajakVerdict? verdict;
}

/// Rivojlantirish mumkin bo'lgan jihat va maslahat.
class KelajakGrowthArea {
  const KelajakGrowthArea({
    required this.key,
    required this.title,
    required this.tip,
  });

  static KelajakGrowthArea? tryFromJson(Object? json) {
    final map = jsonMap(json);
    final key = jsonNonEmpty(map?['key']);
    final title = jsonLocalized(map?['title']);
    if (map == null || key == null || title == null) return null;
    return KelajakGrowthArea(
      key: key,
      title: title,
      tip: jsonLocalized(map['tip']),
    );
  }

  final String key;
  final LocalizedText title;
  final LocalizedText? tip;
}

/// Qo'llab-quvvatlash xabari — raqam ham, tashxis ham yo'q.
class KelajakSupport {
  const KelajakSupport({required this.level, required this.message});

  static KelajakSupport? tryFromJson(Object? json) {
    final map = jsonMap(json);
    final message = jsonLocalized(map?['message']);
    if (map == null || message == null) return null;
    return KelajakSupport(
      level: KelajakSupportLevel.fromWire(map['level']),
      message: message,
    );
  }

  final KelajakSupportLevel level;
  final LocalizedText message;

  /// Xabarni ko'rsatish kerak (`none` — hammasi yaxshi).
  bool get needsAttention =>
      level == KelajakSupportLevel.watch ||
      level == KelajakSupportLevel.support;
}

/// Keyingi tavsiya (test, Career Lab faoliyati yoki "ertaga yana").
class KelajakNext {
  const KelajakNext({
    required this.kind,
    required this.title,
    this.body,
    this.testType,
    this.externalId,
  });

  static KelajakNext? tryFromJson(Object? json) {
    final map = jsonMap(json);
    final title = jsonLocalized(map?['title']);
    if (map == null || title == null) return null;
    return KelajakNext(
      kind: KelajakNextKind.fromWire(map['kind']),
      title: title,
      body: jsonLocalized(map['body']),
      testType: jsonNonEmpty(map['testType']),
      externalId: jsonNonEmpty(map['externalId']),
    );
  }

  final KelajakNextKind kind;
  final LocalizedText title;
  final LocalizedText? body;

  /// Ochiladigan test turi (`take_test`, `career_lab`).
  final String? testType;

  /// Career Lab faoliyati.
  final String? externalId;
}

/// Tavsiyalar to'plami (natija va profil uchun bir xil).
class KelajakInsights {
  const KelajakInsights({
    this.strengths = const [],
    this.interests = const [],
    this.likedDirections = const [],
    this.triedDirections = const [],
    this.growthAreas = const [],
    this.support,
    this.next = const [],
  });

  factory KelajakInsights.fromJson(Object? json) {
    final map = jsonMap(json);
    if (map == null) return empty;
    return KelajakInsights(
      strengths: jsonList(map['strengths'], KelajakStrength.tryFromJson),
      interests: jsonList(map['interests'], KelajakInterestInsight.tryFromJson),
      likedDirections: jsonList(
        map['likedDirections'],
        KelajakDirection.tryFromJson,
      ),
      triedDirections: jsonList(
        map['triedDirections'],
        KelajakDirection.tryFromJson,
      ),
      growthAreas: jsonList(map['growthAreas'], KelajakGrowthArea.tryFromJson),
      support: KelajakSupport.tryFromJson(map['support']),
      next: jsonList(map['next'], KelajakNext.tryFromJson),
    );
  }

  static const empty = KelajakInsights();

  final List<KelajakStrength> strengths;
  final List<KelajakInterestInsight> interests;
  final List<KelajakDirection> likedDirections;
  final List<KelajakDirection> triedDirections;
  final List<KelajakGrowthArea> growthAreas;
  final KelajakSupport? support;
  final List<KelajakNext> next;
}

/// Sessiya natijasi: shu sessiya ballari + yakundagi profil tavsiyalari.
class KelajakResult {
  const KelajakResult({
    required this.answered,
    required this.total,
    required this.categories,
    required this.insights,
    this.interests,
    this.disclaimer,
  });

  static KelajakResult? tryFromJson(Object? json) {
    final map = jsonMap(json);
    if (map == null) return null;
    return KelajakResult(
      answered: jsonCount(map['answered']),
      total: jsonCount(map['total']),
      categories: jsonList(map['categories'], KelajakCategoryScore.tryFromJson),
      interests: KelajakInterests.tryFromJson(map['interests']),
      insights: KelajakInsights.fromJson(map['insights']),
      disclaimer: jsonLocalized(map['disclaimer']),
    );
  }

  final int answered;
  final int total;
  final List<KelajakCategoryScore> categories;
  final KelajakInterests? interests;
  final KelajakInsights insights;

  /// "Bu tavsiya, qat'iy hukm emas" ogohlantirishi.
  final LocalizedText? disclaimer;
}

/// Kumulyativ profil (oxirgi 180 kun).
class KelajakProfile {
  const KelajakProfile({
    required this.answeredQuestions,
    required this.availableQuestions,
    required this.categories,
    required this.insights,
    this.updatedAt,
    this.interests,
    this.disclaimer,
  });

  static KelajakProfile? tryFromJson(Object? json) {
    final map = jsonMap(json);
    if (map == null) return null;
    return KelajakProfile(
      updatedAt: jsonInstant(map['updatedAt']),
      answeredQuestions: jsonCount(map['answeredQuestions']),
      availableQuestions: jsonCount(map['availableQuestions']),
      categories: jsonList(map['categories'], KelajakCategoryScore.tryFromJson),
      interests: KelajakInterests.tryFromJson(map['interests']),
      insights: KelajakInsights.fromJson(map['insights']),
      disclaimer: jsonLocalized(map['disclaimer']),
    );
  }

  final DateTime? updatedAt;
  final int answeredQuestions;
  final int availableQuestions;
  final List<KelajakCategoryScore> categories;
  final KelajakInterests? interests;
  final KelajakInsights insights;
  final LocalizedText? disclaimer;

  /// Profil to'ldirilganligi 0..1 (javob berilgan / mavjud savollar).
  double get completeness => availableQuestions == 0
      ? 0
      : (answeredQuestions / availableQuestions).clamp(0, 1).toDouble();
}
