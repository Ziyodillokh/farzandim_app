// Daily Learning ma'lumot manbai interfeysi. Hozircha lokal amalga oshirish
// (`LocalLearningRepository`); backend tayyor bo'lgach API'ga ulangan
// amalga oshirish shu interfeys orqali almashtiriladi — UI va providerlar
// o'zgarmaydi.

import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/domain/quiz_models.dart';

abstract interface class LearningRepository {
  /// Saqlangan o'quv profili (`null` — hali tanlanmagan).
  Future<LearningProfile?> loadProfile();

  Future<void> saveProfile(LearningProfile profile);

  /// Yechilgan testlar — yangisi birinchi.
  Future<List<TestResult>> loadResults();

  Future<void> saveResult(TestResult result);

  /// Fan savollari banki.
  Future<List<QuizQuestion>> loadQuestions(Subject subject);
}
