// ─────────────────────────────────────────────────────────────────────
// LearningResult — yakunlangan test natijasi (ota-ona tarixi)
// ─────────────────────────────────────────────────────────────────────
//
// Backend: GET /api/children/:childId/learning/results?limit=&before=
// → `{items, nextBefore}`. Keyingi sahifa `before=nextBefore` bilan.

import 'package:farzandim/core/utils/safe_parse.dart';
import 'package:farzandim/features/growth/data/models/learning_subject.dart';
import 'package:flutter/foundation.dart';

/// Natijalar sahifasi hajmi (backend standarti 30, ko'pi bilan 100).
const int kLearningResultsPageSize = 30;
const int kMaxLearningResultsPageSize = 100;

/// Zaxira til (savollar banki o'zbekchada to'liq).
const String _fallbackLanguage = 'uz';

/// Uch tilli matn (`{uz, ru, en}`); kerakli til yo'q → o'zbekcha.
@immutable
class LocalizedText {
  const LocalizedText(this.values);

  /// Obyekt (`{"uz": "..."}`) yoki oddiy satr; matn yo'q → `null`.
  static LocalizedText? tryParse(Object? raw) {
    if (raw is String) {
      return raw.isEmpty ? null : LocalizedText({_fallbackLanguage: raw});
    }
    final json = asJsonMap(raw);
    if (json == null) return null;
    final values = <String, String>{
      for (final entry in json.entries)
        if (entry.value is String && (entry.value as String).isNotEmpty)
          entry.key: entry.value as String,
    };
    return values.isEmpty ? null : LocalizedText(Map.unmodifiable(values));
  }

  final Map<String, String> values;

  /// [languageCode] matni; yo'q bo'lsa o'zbekcha, u ham yo'q — birinchisi.
  String of(String languageCode) =>
      values[languageCode] ??
      values[_fallbackLanguage] ??
      (values.isEmpty ? '' : values.values.first);
}

@immutable
class LearningResult {
  const LearningResult({
    required this.id,
    required this.subject,
    required this.correct,
    required this.total,
    required this.percent,
    required this.isDaily,
    required this.xpEarned,
    required this.donEarned,
    required this.durationSeconds,
    this.topic,
    this.date,
  });

  factory LearningResult.fromJson(Map<String, dynamic> json) => LearningResult(
    id: json.readString('id'),
    subject: LearningSubject.fromApi(json['subject']),
    topic: LocalizedText.tryParse(json['topic']),
    correct: json.readInt('correct'),
    total: json.readInt('total'),
    percent: json.readInt('percent').clamp(0, 100),
    isDaily: json.readBool('isDaily'),
    xpEarned: json.readInt('xpEarned'),
    donEarned: json.readInt('donEarned'),
    date: json.readDateTime('date'),
    durationSeconds: json.readInt('durationSeconds'),
  );

  final String id;
  final LearningSubject subject;

  /// Mavzu (bo'lsa).
  final LocalizedText? topic;
  final int correct;
  final int total;
  final int percent;

  /// Kunlik rejadagi test.
  final bool isDaily;
  final int xpEarned;
  final int donEarned;

  /// Yakunlangan vaqt (lokal).
  final DateTime? date;
  final int durationSeconds;
}

/// Natijalar sahifasi.
@immutable
class LearningResultsPage {
  const LearningResultsPage({required this.items, this.nextBefore});

  factory LearningResultsPage.fromJson(Map<String, dynamic> json) =>
      LearningResultsPage(
        items: List.unmodifiable(
          parseListSafely(
            json.readList('items'),
            LearningResult.fromJson,
            tag: 'LearningResult',
          ).where((r) => r.id.isNotEmpty),
        ),
        nextBefore: json.readStringOrNull('nextBefore'),
      );

  static const empty = LearningResultsPage(items: []);

  final List<LearningResult> items;

  /// Keyingi sahifa kursori (ISO vaqt, xom holda qaytariladi); oxiri → `null`.
  final String? nextBefore;

  bool get hasMore => nextBefore != null;
}
