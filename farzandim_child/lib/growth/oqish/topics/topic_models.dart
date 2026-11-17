// Mavzular katalogi (server: `GET /learning/subjects/:subject/topics`,
// `GET /learning/topics/:id`) — kontrakt: docs/LEARNING-TOPICS.md.

import 'package:farzandim_child/features/learning/domain/localized_text.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:flutter/foundation.dart';

enum TopicMastery {
  /// «O'zlashtirilgan».
  mastered('MASTERED'),

  /// «Mashq kerak».
  practice('PRACTICE'),

  /// «Hali baholanmagan» — dalil yetarli emas (hech qachon 0% emas).
  notAssessed('NOT_ASSESSED');

  const TopicMastery(this.wire);

  final String wire;

  static TopicMastery fromWire(Object? value) {
    for (final m in values) {
      if (m.wire == value) return m;
    }
    return notAssessed;
  }
}

@immutable
class TopicResult {
  const TopicResult({
    required this.correct,
    required this.total,
    required this.completedAt,
  });

  final int correct;
  final int total;
  final DateTime completedAt;

  static TopicResult? tryFromJson(Object? json) {
    if (json case {
      'correct': final int correct,
      'total': final int total,
      'completedAt': final String at,
    }) {
      final date = DateTime.tryParse(at)?.toLocal();
      if (date == null || total <= 0) return null;
      return TopicResult(correct: correct, total: total, completedAt: date);
    }
    return null;
  }
}

@immutable
class LearningTopic {
  const LearningTopic({
    required this.id,
    required this.title,
    required this.position,
    required this.questionCount,
    required this.available,
    required this.mastery,
    required this.completedAttempts,
    this.goal,
    this.lastAssessedAt,
    this.lastResult,
    this.inProgress,
  });

  final String id;
  final LocalizedText title;
  final LocalizedText? goal;
  final int position;
  final int questionCount;

  /// Mashq qilsa bo'ladi (sinfi uchun yetarli savol bor).
  final bool available;
  final TopicMastery mastery;
  final int completedAttempts;
  final DateTime? lastAssessedAt;
  final TopicResult? lastResult;

  /// Tugallanmagan urinish: javob berilgan / jami (faqat bitta mavzu so'rovida).
  final ({String id, int answered, int total})? inProgress;

  static LearningTopic? tryFromJson(Object? json) {
    if (json case {'id': final String id, 'title': final Object title}) {
      LocalizedText name;
      try {
        name = LocalizedText.fromJson(title);
      } on FormatException {
        return null;
      }
      LocalizedText? goal;
      try {
        goal = json['goal'] == null
            ? null
            : LocalizedText.fromJson(json['goal']);
      } on FormatException {
        goal = null;
      }
      final progress = json['inProgressAttempt'];
      return LearningTopic(
        id: id,
        title: name,
        goal: goal,
        position: _int(json['position']),
        questionCount: _int(json['questionCount']),
        available: json['available'] == true,
        mastery: TopicMastery.fromWire(json['mastery']),
        completedAttempts: _int(json['completedAttempts']),
        lastAssessedAt: json['lastAssessedAt'] is String
            ? DateTime.tryParse(json['lastAssessedAt']! as String)?.toLocal()
            : null,
        lastResult: TopicResult.tryFromJson(json['lastResult']),
        inProgress: switch (progress) {
          {
            'id': final String pid,
            'answered': final int answered,
            'total': final int total,
          }
              when answered > 0 && answered < total =>
            (id: pid, answered: answered, total: total),
          _ => null,
        },
      );
    }
    return null;
  }

  static int _int(Object? value) => value is int ? value : 0;
}

@immutable
class SubjectTopicMap {
  const SubjectTopicMap({
    required this.subject,
    required this.grade,
    required this.topics,
    this.currentTopicId,
  });

  final Subject subject;
  final int grade;
  final List<LearningTopic> topics;
  final String? currentTopicId;

  bool get isEmpty => topics.isEmpty;
  bool get hasPractice => topics.any((t) => t.available);

  static SubjectTopicMap? tryFromJson(Subject subject, Object? json) {
    if (json case {'topics': final List<dynamic> items}) {
      final topics = [
        for (final item in items) ?LearningTopic.tryFromJson(item),
      ]..sort((a, b) => a.position.compareTo(b.position));
      return SubjectTopicMap(
        subject: subject,
        grade: json['grade'] is int ? json['grade']! as int : 0,
        topics: List.unmodifiable(topics),
        currentTopicId: json['currentTopicId'] is String
            ? json['currentTopicId']! as String
            : null,
      );
    }
    return null;
  }

  /// Katalog hali yo'q (server eski yoki fan bo'yicha mavzu kiritilmagan).
  static SubjectTopicMap empty(Subject subject) =>
      SubjectTopicMap(subject: subject, grade: 0, topics: const []);
}
