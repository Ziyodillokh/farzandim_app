// Xotiradagi mavzular manbai: xarita, bitta mavzu va mavzu bo'yicha urinish
// (urinishlar o'qish manbaidan — javob tekshiruvi o'sha soxta qoidada).

import 'package:farzandim_child/features/learning/domain/localized_text.dart';
import 'package:farzandim_child/features/learning/domain/quiz_models.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/growth/oqish/topics/topic_models.dart';
import 'package:farzandim_child/growth/oqish/topics/topics_repository.dart';

import '../features/learning/fake_learning_repository.dart';

class FakeTopicsRepository implements TopicsRepository {
  FakeTopicsRepository({
    this.topics = const [],
    this.currentTopicId,
    required this.learning,
  });

  final List<LearningTopic> topics;
  final String? currentTopicId;
  final FakeLearningRepository learning;

  final startedTopics = <String>[];

  @override
  Future<SubjectTopicMap> loadSubjectMap(Subject subject) async =>
      SubjectTopicMap(
        subject: subject,
        grade: 6,
        topics: topics,
        currentTopicId: currentTopicId,
      );

  @override
  Future<LearningTopic?> loadTopic(String topicId) async {
    for (final t in topics) {
      if (t.id == topicId) return t;
    }
    return null;
  }

  @override
  Future<QuizAttempt> startTopicAttempt(Subject subject, String topicId) {
    startedTopics.add(topicId);
    return learning.startAttempt(subject);
  }
}

LearningTopic topic(
  String id,
  String title, {
  int position = 0,
  TopicMastery mastery = TopicMastery.notAssessed,
  bool available = true,
  int completedAttempts = 0,
  DateTime? lastAssessedAt,
  TopicResult? lastResult,
  ({String id, int answered, int total})? inProgress,
  String? goal,
}) => LearningTopic(
  id: id,
  title: LocalizedText.same(title),
  goal: goal == null ? null : LocalizedText.same(goal),
  position: position,
  questionCount: available ? 12 : 3,
  available: available,
  mastery: mastery,
  completedAttempts: completedAttempts,
  lastAssessedAt: lastAssessedAt,
  lastResult: lastResult,
  inProgress: inProgress,
);
