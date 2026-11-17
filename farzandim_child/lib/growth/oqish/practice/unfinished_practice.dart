// Tugallanmagan mashq (U01 «Davom ettirish» kartasi uchun).
//
// Server yarim qolgan urinishni o'zi davom ettiradi (shu kun, shu fan), lekin
// ro'yxatini bermaydi — ilova oxirgi tugallanmagan mashqni qurilmada eslab
// qoladi (har bir akkauntniki alohida). Faqat shu kunniki ko'rsatiladi;
// yakunlanganda o'chiriladi.

import 'dart:convert';

import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/growth/kirish/data/account_local_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class UnfinishedPractice {
  const UnfinishedPractice({
    required this.subject,
    required this.answered,
    required this.total,
    required this.outcomes,
    required this.day,
    this.topic = '',
  });

  final Subject subject;
  final int answered;
  final int total;

  /// Savollar tartibida natija (`true`/`false`/`null` — javobsiz).
  final List<bool?> outcomes;

  /// Mahalliy kun `YYYY-MM-DD`.
  final String day;
  final String topic;

  Map<String, Object?> toJson() => {
    'subject': subject.name,
    'answered': answered,
    'total': total,
    'outcomes': outcomes,
    'day': day,
    'topic': topic,
  };

  static UnfinishedPractice? tryFromJson(Object? json) {
    if (json case {
      'subject': final String subjectName,
      'answered': final int answered,
      'total': final int total,
      'outcomes': final List<dynamic> outcomes,
      'day': final String day,
    }) {
      final subject = Subject.fromName(subjectName);
      if (subject == null || total <= 0 || answered <= 0 || answered >= total) {
        return null;
      }
      return UnfinishedPractice(
        subject: subject,
        answered: answered,
        total: total,
        outcomes: List.unmodifiable(outcomes.map((o) => o is bool ? o : null)),
        day: day,
        topic: json['topic'] is String ? json['topic']! as String : '',
      );
    }
    return null;
  }
}

String practiceDayKey(DateTime time) =>
    '${time.year.toString().padLeft(4, '0')}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';

/// Asos kalit — akkauntga bog'lanadi ([accountKey]).
const _prefsKey = 'g5_unfinished_practice_v1';

final unfinishedPracticeProvider =
    AsyncNotifierProvider<UnfinishedPracticeNotifier, UnfinishedPractice?>(
      UnfinishedPracticeNotifier.new,
    );

class UnfinishedPracticeNotifier extends AsyncNotifier<UnfinishedPractice?> {
  /// Joriy akkaunt kaliti (`null` — hech kim kirmagan).
  String? _key;

  @override
  Future<UnfinishedPractice?> build() async {
    _key = ref.watch(currentAccountKeyProvider(_prefsKey));
    final key = _key;
    if (key == null) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      return raw == null
          ? null
          : UnfinishedPractice.tryFromJson(jsonDecode(raw));
    } on Object catch (e) {
      debugPrint('[practice] tugallanmagan mashq o\'qilmadi: $e');
      return null;
    }
  }

  /// Javob berilgan, lekin yakunlanmagan mashq (javoblar soni 0 yoki to'liq bo'lsa — o'chiriladi).
  Future<void> save(UnfinishedPractice practice) async {
    if (practice.answered <= 0 || practice.answered >= practice.total) {
      await clear();
      return;
    }
    state = AsyncData(practice);
    final key = _key;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(practice.toJson()));
    } on Object catch (e) {
      debugPrint('[practice] tugallanmagan mashq saqlanmadi: $e');
    }
  }

  Future<void> clear() async {
    state = const AsyncData(null);
    final key = _key;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } on Object catch (e) {
      debugPrint('[practice] tugallanmagan mashq o\'chirilmadi: $e');
    }
  }
}
