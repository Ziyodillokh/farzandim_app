// K01–K06 ma'lumotlari: kasblar katalogi va xavfsizlik darslari (ilova
// ichida, uch tilda), sevimli fanlar, haftalik maqsad va darslar jarayoni —
// har biri faol akkauntga bog'langan va qurilmada saqlanadi.

import 'dart:async';
import 'dart:convert';

import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/growth/kirish/data/account_local_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── K03 · Kasblar ──────────────────────────────────────────────────────

/// Kasb sohasi. [code] — Kelajak profilidagi RIASEC o'lchami; [trySubject] —
/// «Sinab ko'rish» mashqi (sinfda o'qitilmasa — matematika).
enum CareerField {
  engineering(GIcons.wrench, GHue.blue, 'R', Subject.math),
  medicine(GIcons.stethoscope, GHue.rose, 'I', Subject.biology),
  design(GIcons.palette, GHue.gold, 'A', Subject.math),
  teaching(GIcons.student, GHue.green, 'S', Subject.native),
  business(GIcons.briefcase, GHue.orange, 'E', Subject.math),
  it(GIcons.cpu, GHue.teal, 'C', Subject.informatics);

  const CareerField(this.icon, this.hue, this.code, this.trySubject);

  final GIconData icon;
  final GHue hue;
  final String code;
  final Subject trySubject;

  String get key => 'g5.kelajak.careers.$name';

  /// Sinfga mos «Sinab ko'rish» fani.
  Subject subjectFor(int? grade) =>
      grade == null || trySubject.isTaughtIn(grade) ? trySubject : Subject.math;

  /// Kelajak profilining eng yuqori o'lchamiga mos soha (faqat tavsiya).
  static CareerField recommended(List<String> topCodes) {
    for (final code in topCodes) {
      for (final field in values) {
        if (field.code == code) return field;
      }
    }
    return engineering;
  }
}

// ── K01 · Sevimli fanlar ───────────────────────────────────────────────

const _favoritesBase = 'g5_favorite_subjects_v1';

final favoriteSubjectsProvider =
    AsyncNotifierProvider.autoDispose<FavoriteSubjects, Set<Subject>>(
      FavoriteSubjects.new,
    );

class FavoriteSubjects extends AutoDisposeAsyncNotifier<Set<Subject>> {
  String? _key;

  @override
  Future<Set<Subject>> build() async {
    _key = ref.watch(currentAccountKeyProvider(_favoritesBase));
    final key = _key;
    if (key == null) return const {};
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final name in prefs.getStringList(key) ?? const <String>[])
        ?Subject.fromName(name),
    };
  }

  Future<void> toggle(Subject subject) async {
    final key = _key;
    if (key == null) return;
    final current = state.valueOrNull ?? const <Subject>{};
    final next = current.contains(subject)
        ? ({...current}..remove(subject))
        : {...current, subject};
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, [for (final s in next) s.name]);
  }
}

// ── K04 · Haftalik maqsad ──────────────────────────────────────────────

const _goalBase = 'g5_weekly_goal_v1';

/// Haftalik maqsad: [target] marta mashq ([subject] — `null` bo'lsa istalgan
/// fan). Har dushanba yangi hafta boshlanadi, maqsad o'zi takrorlanadi.
@immutable
class WeeklyGoal {
  const WeeklyGoal({required this.target, this.subject});

  static WeeklyGoal? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final target = json['target'];
    if (target is! int || target < 1 || target > kGoalMaxTarget) return null;
    return WeeklyGoal(
      target: target,
      subject: Subject.fromName(json['subject'] as String?),
    );
  }

  final int target;
  final Subject? subject;

  Map<String, Object> toJson() => {'target': target, 'subject': ?subject?.name};
}

const kGoalMaxTarget = 4;

/// Haftaning boshi (dushanba 00:00, mahalliy vaqt).
DateTime weekStartOf(DateTime now) {
  final day = DateTime(now.year, now.month, now.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

/// Shu hafta maqsadga mos tugatilgan mashqlar soni.
int goalProgress(WeeklyGoal goal, List<TestResult> results, DateTime now) {
  final start = weekStartOf(now);
  return results
      .where(
        (r) =>
            !r.date.isBefore(start) &&
            (goal.subject == null || r.subject == goal.subject),
      )
      .length;
}

final weeklyGoalProvider =
    AsyncNotifierProvider.autoDispose<WeeklyGoalNotifier, WeeklyGoal?>(
      WeeklyGoalNotifier.new,
    );

class WeeklyGoalNotifier extends AutoDisposeAsyncNotifier<WeeklyGoal?> {
  String? _key;

  @override
  Future<WeeklyGoal?> build() async {
    _key = ref.watch(currentAccountKeyProvider(_goalBase));
    final key = _key;
    if (key == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      return WeeklyGoal.tryFromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  Future<void> save(WeeklyGoal goal) async {
    final key = _key;
    if (key == null) return;
    state = AsyncData(goal);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(goal.toJson()));
  }
}

/// Shu haftadagi natija (maqsad bo'lmasa `null`).
final weeklyGoalProgressProvider = Provider.autoDispose<int?>((ref) {
  final goal = ref.watch(weeklyGoalProvider).valueOrNull;
  if (goal == null) return null;
  return goalProgress(
    goal,
    ref.watch(learningResultsProvider),
    ref.watch(learningClockProvider)(),
  );
});

// ── K05/K06 · Xavfsizlik darslari ──────────────────────────────────────

/// Xavfsizlik darsi: ssenariy va javoblar ([safe] — xavfsiz javob; bir
/// nechta xavfsiz javob bo'lishi mumkin). Baholanadi, DON berilmaydi.
enum SafetyLesson {
  stranger(GIcons.chatCircleDots, GHue.sky, [
    'ignore',
    'tellParent',
    'address',
  ]),
  help(GIcons.handHeart, GHue.green, ['trusted', 'sos', 'silent']),
  codes(GIcons.password, GHue.gold, ['keep', 'tellAdult', 'give']),
  photos(GIcons.imageSquare, GHue.rose, ['askParent', 'noPrivate', 'send']);

  const SafetyLesson(this.icon, this.hue, this.options);

  final GIconData icon;
  final GHue hue;

  /// Javoblar; oxirgisi — xavfli (qolganlari xavfsiz).
  final List<String> options;

  Set<String> get safe => {...options.take(options.length - 1)};

  String get key => 'g5.kelajak.safety.$name';
}

const _safetyBase = 'g5_safety_done_v1';

final safetyProgressProvider =
    AsyncNotifierProvider.autoDispose<SafetyProgress, Set<SafetyLesson>>(
      SafetyProgress.new,
    );

class SafetyProgress extends AutoDisposeAsyncNotifier<Set<SafetyLesson>> {
  String? _key;

  @override
  Future<Set<SafetyLesson>> build() async {
    _key = ref.watch(currentAccountKeyProvider(_safetyBase));
    final key = _key;
    if (key == null) return const {};
    final prefs = await SharedPreferences.getInstance();
    final names = prefs.getStringList(key) ?? const <String>[];
    return {
      for (final lesson in SafetyLesson.values)
        if (names.contains(lesson.name)) lesson,
    };
  }

  Future<void> complete(SafetyLesson lesson) async {
    final key = _key;
    if (key == null) return;
    final next = {...state.valueOrNull ?? const <SafetyLesson>{}, lesson};
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, [for (final l in next) l.name]);
  }
}
