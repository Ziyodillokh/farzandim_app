// Lokal Daily Learning manbai: profil va natijalar — SharedPreferences,
// savollar — ilova ichidagi bank (`assets/learning/questions/<fan>.json`).

import 'dart:convert';

import 'package:farzandim_child/features/learning/data/learning_repository.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/domain/quiz_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kLearningProfileKey = 'learning_profile_v1';
const kLearningResultsKey = 'learning_results_v1';

/// Saqlanadigan natijalar chegarasi (eng eskilari o'chiriladi).
const kMaxStoredResults = 300;

class LocalLearningRepository implements LearningRepository {
  LocalLearningRepository({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final Map<Subject, List<QuizQuestion>> _questions = {};

  @override
  Future<LearningProfile?> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kLearningProfileKey);
    if (raw == null) return null;
    try {
      return LearningProfile.tryFromJson(jsonDecode(raw));
    } on FormatException catch (e) {
      debugPrint('[learning] profil o\'qilmadi: $e');
      return null;
    }
  }

  @override
  Future<void> saveProfile(LearningProfile profile) async {
    if (!profile.isValid) {
      throw ArgumentError.value(profile, 'profile', 'noto\'g\'ri profil');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kLearningProfileKey, jsonEncode(profile.toJson()));
  }

  @override
  Future<List<TestResult>> loadResults() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kLearningResultsKey);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final results = [
        for (final item in decoded) ?TestResult.tryFromJson(item),
      ]..sort((a, b) => b.date.compareTo(a.date));
      return List.unmodifiable(results);
    } on FormatException catch (e) {
      debugPrint('[learning] natijalar o\'qilmadi: $e');
      return const [];
    }
  }

  @override
  Future<void> saveResult(TestResult result) async {
    final current = await loadResults();
    final updated = [
      result,
      ...current.where((r) => r.id != result.id),
    ].take(kMaxStoredResults);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kLearningResultsKey,
      jsonEncode([for (final r in updated) r.toJson()]),
    );
  }

  @override
  Future<List<QuizQuestion>> loadQuestions(Subject subject) async {
    final cached = _questions[subject];
    if (cached != null) return cached;
    try {
      final raw = await _bundle.loadString(
        'assets/learning/questions/${subject.name}.json',
      );
      final questions = List<QuizQuestion>.unmodifiable(
        parseQuestionBank(subject, jsonDecode(raw)),
      );
      _questions[subject] = questions;
      return questions;
    } on FlutterError catch (e) {
      // Bu fan uchun bank hali yo'q — bo'sh (UI "tez orada" ko'rsatadi).
      debugPrint('[learning] ${subject.name} banki topilmadi: $e');
      return const [];
    }
  }
}
