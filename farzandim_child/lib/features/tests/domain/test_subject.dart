// ─────────────────────────────────────────────────────────────────────
// Testlar — fanlar bo'yicha guruhlash (sof mantiq, UI'siz)
// ─────────────────────────────────────────────────────────────────────
//
// Backend testlari (`/api/content/olympiads`) `soha`ni erkin satr bilan
// beradi ("Matematika 8-sinf", "Ingliz tili"…). `contestSubjectKey` ularni
// barqaror kalitga keltiradi; bu yerda kalit bo'yicha guruhlanadi va
// "Fanlar bo'yicha" gridi uchun tartiblanadi.

import 'package:farzandim_child/features/contests/data/models/contest_model.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';

/// Gridda fanlar tartibi (maketdagidek); qolganlari oxirida, alifbo bo'yicha.
const testSubjectOrder = <String>[
  'ilmiy',
  'matematika',
  'ingliz',
  'tarix',
  'geografiya',
  'biologiya',
  'ona_tili',
  'fizika',
  'kimyo',
  'it',
  'rus_tili',
];

/// Fan kaliti — `contestSubjectKey` + "Ilmiy-ommabop" kabi qo'shimcha toifa.
///
/// Fani yozilmagan test yo'qolmasin — "Aralash" guruhiga tushadi (repozitoriy
/// ham `null` sohani "Aralash" qiladi).
String testSubjectKey(String soha) {
  final key = contestSubjectKey(soha);
  if (key.isEmpty) return mixedSubjectKey;
  if (key.startsWith('ilmiy')) return 'ilmiy';
  if (key.startsWith('rus til')) return 'rus_tili';
  return key;
}

/// Fani noma'lum testlar guruhi.
const mixedSubjectKey = 'aralash';

/// Kunlik reja fani → testlar kaliti (fan testlarini ochish uchun).
String subjectTestKey(Subject subject) => switch (subject) {
  Subject.math => 'matematika',
  Subject.english => 'ingliz',
  Subject.native => 'ona_tili',
  Subject.history => 'tarix',
  Subject.biology => 'biologiya',
  Subject.geography => 'geografiya',
  Subject.physics => 'fizika',
  Subject.chemistry => 'kimyo',
  Subject.informatics => 'it',
  Subject.russian => 'rus_tili',
};

/// Ma'lum fan kaliti → `subjects.*` tarjima kaliti (bo'lmasa `null` —
/// backenddagi nom ko'rsatiladi).
String? subjectLabelKey(String key) => switch (key) {
  'matematika' => Subject.math.labelKey,
  'ingliz' => Subject.english.labelKey,
  'ona_tili' => Subject.native.labelKey,
  'tarix' => Subject.history.labelKey,
  'biologiya' => Subject.biology.labelKey,
  'geografiya' => Subject.geography.labelKey,
  'fizika' => Subject.physics.labelKey,
  'kimyo' => Subject.chemistry.labelKey,
  'it' => Subject.informatics.labelKey,
  'rus_tili' => Subject.russian.labelKey,
  mixedSubjectKey => 'tests.mixed',
  _ => null,
};

/// Bir fan bo'yicha testlar guruhi.
class TestSubjectGroup {
  const TestSubjectGroup({
    required this.key,
    required this.fallbackLabel,
    required this.tests,
  });

  /// Barqaror kalit (`testSubjectKey`).
  final String key;

  /// Backenddagi birinchi uchragan nom ("Ilmiy-ommabop") — tarjima kaliti
  /// bo'lmagan fanlar uchun.
  final String fallbackLabel;

  /// Faol testlar avval, keyin yakunlanganlar.
  final List<ContestModel> tests;

  int get count => tests.length;

  /// Hozir yutish mumkin bo'lgan DON — faqat faol testlar bonuslari yig'indisi.
  int get availableReward =>
      tests.where((t) => t.isActive).fold(0, (sum, t) => sum + t.bonus);
}

/// Testlarni fan bo'yicha guruhlaydi va `testSubjectOrder` tartibida beradi.
List<TestSubjectGroup> groupTestsBySubject(List<ContestModel> tests) {
  final byKey = <String, List<ContestModel>>{};
  final labels = <String, String>{};
  for (final test in tests) {
    final key = testSubjectKey(test.soha);
    byKey.putIfAbsent(key, () => []).add(test);
    labels.putIfAbsent(key, () => test.soha.trim());
  }

  int rank(String key) {
    final i = testSubjectOrder.indexOf(key);
    return i < 0 ? testSubjectOrder.length : i;
  }

  final keys = byKey.keys.toList()
    ..sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : a.compareTo(b);
    });

  return [
    for (final key in keys)
      TestSubjectGroup(
        key: key,
        fallbackLabel: labels[key]!,
        tests: [
          ...byKey[key]!.where((t) => t.isActive),
          ...byKey[key]!.where((t) => !t.isActive),
        ],
      ),
  ];
}

/// Qidiruv uchun normallashtirish: registr, apostrof turlari, ortiqcha bo'shliq.
String normalizeTestQuery(String text) => text
    .toLowerCase()
    .replaceAll(RegExp("[’ʻʼ‘`´]"), "'")
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Sarlavha yoki fan nomida so'rov bor testlar (bo'sh so'rov — bo'sh ro'yxat).
List<ContestModel> searchTests(List<ContestModel> tests, String query) {
  final q = normalizeTestQuery(query);
  if (q.isEmpty) return const [];
  return tests
      .where(
        (t) =>
            normalizeTestQuery(t.title).contains(q) ||
            normalizeTestQuery(t.soha).contains(q),
      )
      .toList();
}
