// ─────────────────────────────────────────────────────────────────────
// kelajak_insights — ota-ona xulosasidagi talqinlar (ParentInsightsView)
// ─────────────────────────────────────────────────────────────────────
//
// Kuchli tomonlar, qiziqish yo'nalishlari (faqat `interests.reliable`
// bo'lsa), Career Lab (faoliyat nomi va xulosa — savol id'si va xom
// reytingsiz), rivojlantirish mumkin bo'lgan jihatlar va keyingi tavsiya.
// Matnlar backend'da (`texts.ts`) — qat'iy kasb hukmisiz yozilgan.

import 'package:farzandim/core/utils/safe_parse.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_text.dart';
import 'package:flutter/foundation.dart';

/// Kuchli tomon (masalan `social_self` — "Muloqot va o'zini anglash").
@immutable
class KelajakStrength {
  const KelajakStrength({required this.key, required this.title});

  factory KelajakStrength.fromJson(Map<String, dynamic> json) =>
      KelajakStrength(
        key: requireKelajakString(json, 'key'),
        title: requireKelajakText(json, 'title'),
      );

  final String key;
  final LocalizedText title;
}

/// Qiziqish yuqori bo'lgan yo'nalish (RIASEC kodi) va sinab ko'rish
/// mumkin bo'lgan sohalar.
@immutable
class KelajakInterestInsight {
  const KelajakInterestInsight({
    required this.code,
    required this.title,
    required this.body,
    required this.suggestions,
  });

  factory KelajakInterestInsight.fromJson(Map<String, dynamic> json) =>
      KelajakInterestInsight(
        code: requireKelajakString(json, 'code'),
        title: requireKelajakText(json, 'title'),
        body: readKelajakText(json, 'body'),
        suggestions: List.unmodifiable([
          for (final raw in json.readList('suggestions'))
            ?LocalizedText.tryParse(raw),
        ]),
      );

  final String code;
  final LocalizedText title;
  final LocalizedText? body;
  final List<LocalizedText> suggestions;
}

/// Career Lab faoliyati (yoqqan yoki sinalgan).
@immutable
class KelajakDirection {
  const KelajakDirection({required this.activity, this.code});

  factory KelajakDirection.fromJson(Map<String, dynamic> json) =>
      KelajakDirection(
        activity: requireKelajakText(json, 'activity'),
        code: json.readStringOrNull('code'),
      );

  final LocalizedText activity;

  /// RIASEC kodi (umumiy faoliyatda `null`).
  final String? code;
}

/// Career Lab taassuroti.
enum KelajakVerdict {
  liked,
  neutral,
  disliked,
  unknown;

  static KelajakVerdict fromApi(Object? raw) => switch (raw) {
    'liked' => liked,
    'neutral' => neutral,
    'disliked' => disliked,
    _ => unknown,
  };
}

/// Sinalgan faoliyat va taassurot.
@immutable
class KelajakTriedDirection {
  const KelajakTriedDirection({required this.direction, required this.verdict});

  factory KelajakTriedDirection.fromJson(Map<String, dynamic> json) =>
      KelajakTriedDirection(
        direction: KelajakDirection.fromJson(json),
        verdict: KelajakVerdict.fromApi(json['verdict']),
      );

  final KelajakDirection direction;
  final KelajakVerdict verdict;
}

/// Rivojlantirish mumkin bo'lgan jihat va maslahat.
@immutable
class KelajakGrowthArea {
  const KelajakGrowthArea({required this.key, required this.title, this.tip});

  factory KelajakGrowthArea.fromJson(Map<String, dynamic> json) =>
      KelajakGrowthArea(
        key: requireKelajakString(json, 'key'),
        title: requireKelajakText(json, 'title'),
        tip: readKelajakText(json, 'tip'),
      );

  /// Kategoriya yoki `safety_rules`.
  final String key;
  final LocalizedText title;
  final LocalizedText? tip;
}

/// Keyingi tavsiya turi.
enum KelajakNextKind {
  takeTest,
  careerLab,
  comeBack,
  unknown;

  static KelajakNextKind fromApi(Object? raw) => switch (raw) {
    'take_test' => takeTest,
    'career_lab' => careerLab,
    'come_back' => comeBack,
    _ => unknown,
  };
}

/// Keyingi tavsiya (ota-onaga `externalId` har doim `null` — o'qilmaydi).
@immutable
class KelajakNextStep {
  const KelajakNextStep({
    required this.kind,
    required this.title,
    this.testType,
    this.body,
  });

  factory KelajakNextStep.fromJson(Map<String, dynamic> json) =>
      KelajakNextStep(
        kind: KelajakNextKind.fromApi(json['kind']),
        testType: json.readStringOrNull('testType'),
        title: requireKelajakText(json, 'title'),
        body: readKelajakText(json, 'body'),
      );

  final KelajakNextKind kind;
  final String? testType;
  final LocalizedText title;
  final LocalizedText? body;
}

@immutable
class KelajakInsights {
  const KelajakInsights({
    this.strengths = const [],
    this.interests = const [],
    this.likedDirections = const [],
    this.triedDirections = const [],
    this.growthAreas = const [],
    this.next = const [],
  });

  factory KelajakInsights.fromJson(Map<String, dynamic> json) =>
      KelajakInsights(
        strengths: readKelajakList(json, 'strengths', KelajakStrength.fromJson),
        interests: readKelajakList(
          json,
          'interests',
          KelajakInterestInsight.fromJson,
        ),
        likedDirections: readKelajakList(
          json,
          'likedDirections',
          KelajakDirection.fromJson,
        ),
        triedDirections: readKelajakList(
          json,
          'triedDirections',
          KelajakTriedDirection.fromJson,
        ),
        growthAreas: readKelajakList(
          json,
          'growthAreas',
          KelajakGrowthArea.fromJson,
        ),
        next: readKelajakList(json, 'next', KelajakNextStep.fromJson),
      );

  final List<KelajakStrength> strengths;

  /// Top yo'nalishlar; profil hali ishonchli bo'lmasa bo'sh.
  final List<KelajakInterestInsight> interests;
  final List<KelajakDirection> likedDirections;
  final List<KelajakTriedDirection> triedDirections;
  final List<KelajakGrowthArea> growthAreas;
  final List<KelajakNextStep> next;
}
