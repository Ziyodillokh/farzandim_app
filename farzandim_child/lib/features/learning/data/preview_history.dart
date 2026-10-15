// ⚠️ PREVIEW (`kLearningPreviewData`): backend ulanguncha dashboardlar
// bo'sh ko'rinmasligi uchun o'tgan kunlar natijalari (deterministik).
// Faqat xotirada — saqlanmaydi; bugungi kun har doim bo'sh (bola o'zi
// yechadi). Release'dan oldin bayroq o'chiriladi.

import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/domain/learning_stats.dart';
import 'package:farzandim_child/features/learning/domain/localized_text.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';

/// Necha kun orqaga namunaviy tarix.
const _historyDays = 20;

/// Fanlarning namunaviy "boshlang'ich" darajasi (profil tartibida).
const _baseByIndex = [88, 66, 76, 72, 82];

const _topics = <Subject, List<Map<String, String>>>{
  Subject.math: [
    {'uz': 'Kasrlar', 'ru': 'Дроби', 'en': 'Fractions'},
    {'uz': 'Tenglamalar', 'ru': 'Уравнения', 'en': 'Equations'},
  ],
  Subject.english: [
    {'uz': 'Grammatika', 'ru': 'Грамматика', 'en': 'Grammar'},
    {'uz': 'Lug‘at', 'ru': 'Лексика', 'en': 'Vocabulary'},
  ],
  Subject.native: [
    {'uz': 'So‘z turkumlari', 'ru': 'Части речи', 'en': 'Parts of speech'},
    {'uz': 'Imlo', 'ru': 'Орфография', 'en': 'Spelling'},
  ],
  Subject.history: [
    {'uz': 'Amir Temur davri', 'ru': 'Эпоха Темура', 'en': 'Timurid era'},
    {
      'uz': 'Buyuk ipak yo‘li',
      'ru': 'Великий шёлковый путь',
      'en': 'Silk Road',
    },
  ],
  Subject.biology: [
    {'uz': 'Hujayra', 'ru': 'Клетка', 'en': 'The cell'},
    {'uz': 'O‘simliklar', 'ru': 'Растения', 'en': 'Plants'},
  ],
  Subject.geography: [
    {'uz': 'Materiklar', 'ru': 'Материки', 'en': 'Continents'},
    {'uz': 'Iqlim', 'ru': 'Климат', 'en': 'Climate'},
  ],
  Subject.physics: [
    {'uz': 'Harakat', 'ru': 'Движение', 'en': 'Motion'},
    {'uz': 'Kuch', 'ru': 'Сила', 'en': 'Force'},
  ],
  Subject.chemistry: [
    {'uz': 'Elementlar', 'ru': 'Элементы', 'en': 'Elements'},
    {'uz': 'Reaksiyalar', 'ru': 'Реакции', 'en': 'Reactions'},
  ],
  Subject.informatics: [
    {'uz': 'Algoritmlar', 'ru': 'Алгоритмы', 'en': 'Algorithms'},
    {
      'uz': 'Sanoq tizimlari',
      'ru': 'Системы счисления',
      'en': 'Number systems',
    },
  ],
  Subject.russian: [
    {'uz': 'Kelishiklar', 'ru': 'Падежи', 'en': 'Cases'},
    {'uz': 'Imlo', 'ru': 'Орфография', 'en': 'Spelling'},
  ],
};

/// Namunaviy tarix — yangisi birinchi. Har 7 kunda bir "dam olish" kuni;
/// natijalar vaqt o'tib biroz o'sadi (haftalik o'sish ko'rinsin).
List<TestResult> previewHistory(LearningProfile profile, DateTime now) {
  final results = <TestResult>[];
  for (var daysAgo = 1; daysAgo <= _historyDays; daysAgo++) {
    if (daysAgo % 7 == 4) continue;
    for (var i = 0; i < profile.subjects.length; i++) {
      final subject = profile.subjects[i];
      // Deterministik "tebranish" −8…+8 va har hafta orqaga −5.
      final wobble = ((daysAgo * 37 + i * 11) % 17) - 8;
      final percent =
          _baseByIndex[i % _baseByIndex.length] - (daysAgo ~/ 7) * 5 + wobble;
      final correct = (percent / 10).round().clamp(3, kDailyQuestionCount);
      final topics = _topics[subject]!;
      results.add(
        TestResult(
          id: 'preview-$daysAgo-${subject.name}',
          subject: subject,
          topic: LocalizedText(topics[daysAgo % topics.length]),
          correct: correct,
          total: kDailyQuestionCount,
          date: DateTime(now.year, now.month, now.day - daysAgo, 17, 20 * i),
        ),
      );
    }
  }
  return results..sort((a, b) => b.date.compareTo(a.date));
}
