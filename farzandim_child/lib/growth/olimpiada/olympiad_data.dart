// U17–U19 · Olimpiada (`/api/content/olympiads`): ro'yxat, musobaqa rejimidagi
// urinish (savol-savol, javob darhol serverda saqlanadi), «Yakunlash» va
// kvitansiya. Musobaqa rejimida server to'g'ri javob va ballni olimpiada
// tugaguncha bermaydi — ilova ham ko'rsatmaydi.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/config/env_config.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/school/domain/school_json.dart';
import 'package:farzandim_child/growth/kirish/data/account_local_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum OlympiadPhase { scheduled, active, finished }

@immutable
class Olympiad {
  const Olympiad({
    required this.id,
    required this.title,
    required this.subject,
    required this.phase,
    required this.startTime,
    required this.endTime,
    required this.durationMin,
    required this.questionCount,
    this.description,
    this.ageFrom,
    this.ageTo,
  });

  static Olympiad? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = jsonNonEmpty(json['id']);
    final title = jsonNonEmpty(json['title']);
    final start = DateTime.tryParse('${json['startTime']}');
    final end = DateTime.tryParse('${json['endTime']}');
    if (id == null || title == null || start == null || end == null) {
      return null;
    }
    return Olympiad(
      id: id,
      title: title,
      subject: jsonNonEmpty(json['subject']) ?? '',
      description: jsonNonEmpty(json['description']),
      phase: switch (json['lifecycle']) {
        'active' => OlympiadPhase.active,
        'scheduled' => OlympiadPhase.scheduled,
        _ => OlympiadPhase.finished,
      },
      startTime: start.toLocal(),
      endTime: end.toLocal(),
      durationMin: jsonInt(json['durationMin']) ?? 30,
      questionCount: jsonInt(json['questionCount']) ?? 0,
      ageFrom: jsonInt(json['ageFrom']),
      ageTo: jsonInt(json['ageTo']),
    );
  }

  final String id;
  final String title;
  final String subject;
  final String? description;
  final OlympiadPhase phase;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMin;
  final int questionCount;
  final int? ageFrom;
  final int? ageTo;
}

@immutable
class OlympiadQuestion {
  const OlympiadQuestion({
    required this.id,
    required this.text,
    required this.options,
    this.imageUrl,
  });

  static OlympiadQuestion? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = jsonNonEmpty(json['id']);
    final options = json['options'];
    if (id == null || options is! List || options.isEmpty) return null;
    final imageKey = jsonNonEmpty(json['imageKey']);
    return OlympiadQuestion(
      id: id,
      text: jsonNonEmpty(json['text']) ?? '',
      options: [for (final o in options) '$o'],
      imageUrl: imageKey == null
          ? null
          : '${EnvConfig.apiUrl}/olympiad-images/$imageKey',
    );
  }

  final String id;
  final String text;
  final List<String> options;
  final String? imageUrl;
}

/// Boshlangan (yoki davom ettirilgan) urinish.
@immutable
class OlympiadAttempt {
  const OlympiadAttempt({
    required this.id,
    required this.startedAt,
    required this.finished,
  });

  final String id;
  final DateTime startedAt;
  final bool finished;
}

/// Kvitansiya (U19).
@immutable
class OlympiadReceipt {
  const OlympiadReceipt({
    required this.saved,
    required this.total,
    this.finishedAt,
    this.resultsAt,
  });

  static OlympiadReceipt fromJson(Object? json, {required int total}) {
    final map = json is Map ? json : const <Object?, Object?>{};
    return OlympiadReceipt(
      saved:
          jsonInt(map['answersSaved']) ?? jsonInt(map['correctAnswers']) ?? 0,
      total: jsonInt(map['questionsTotal']) ?? total,
      finishedAt: DateTime.tryParse('${map['finishedAt']}')?.toLocal(),
      resultsAt: DateTime.tryParse('${map['resultsAt']}')?.toLocal(),
    );
  }

  final int saved;
  final int total;
  final DateTime? finishedAt;
  final DateTime? resultsAt;
}

class OlympiadException implements Exception {
  const OlympiadException({this.network = false, this.timeUp = false});

  final bool network;

  /// Server vaqt tugaganini aytdi — urinish avtomatik yopilgan.
  final bool timeUp;
}

class OlympiadRepository {
  OlympiadRepository(this._dio);

  final Dio _dio;

  Future<List<Olympiad>> list() => _guard(() async {
    final res = await _dio.get<Object?>('/content/olympiads');
    final data = res.data;
    final items = data is Map ? data['items'] : null;
    return [
      if (items is List)
        for (final raw in items) ?Olympiad.tryFromJson(raw),
    ];
  });

  Future<List<OlympiadQuestion>> questions(String olympiadId) =>
      _guard(() async {
        final res = await _dio.get<Object?>(
          '/content/olympiads/${Uri.encodeComponent(olympiadId)}',
        );
        final data = res.data;
        final raw = data is Map ? data['questions'] : null;
        return [
          if (raw is List)
            for (final q in raw) ?OlympiadQuestion.tryFromJson(q),
        ];
      });

  Future<OlympiadAttempt> start(String olympiadId) => _guard(() async {
    final res = await _dio.post<Object?>(
      '/content/olympiads/${Uri.encodeComponent(olympiadId)}/start',
    );
    final data = res.data;
    final id = data is Map ? jsonNonEmpty(data['attemptId']) : null;
    if (id == null) throw const OlympiadException();
    return OlympiadAttempt(
      id: id,
      startedAt:
          DateTime.tryParse('${(data as Map)['startedAt']}')?.toLocal() ??
          DateTime.now(),
      finished: data['status'] == 'finished',
    );
  });

  Future<void> answer({
    required String attemptId,
    required String questionId,
    required int selectedIndex,
  }) => _guard(() async {
    await _dio.post<Object?>(
      '/content/olympiads/attempts/${Uri.encodeComponent(attemptId)}/answer',
      data: {'questionId': questionId, 'selectedIndex': selectedIndex},
    );
  });

  Future<OlympiadReceipt> finish(
    String attemptId, {
    required int total,
  }) => _guard(() async {
    final res = await _dio.post<Object?>(
      '/content/olympiads/attempts/${Uri.encodeComponent(attemptId)}/finish',
    );
    return OlympiadReceipt.fromJson(res.data, total: total);
  });

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      debugPrint(
        '[olimpiada] ${e.requestOptions.path}: ${e.response?.statusCode}',
      );
      throw OlympiadException(
        network: e.response == null,
        timeUp: e.response?.statusCode == 408,
      );
    }
  }
}

final olympiadRepositoryProvider = Provider<OlympiadRepository>(
  (ref) => OlympiadRepository(ref.watch(dioClientProvider)),
);

final olympiadsProvider = FutureProvider.autoDispose<List<Olympiad>>(
  (ref) => ref.watch(olympiadRepositoryProvider).list(),
);

/// Urinishda javob berilgan savollar (ilova yopilsa ham davom etish uchun) —
/// faol akkauntga bog'langan.
class OlympiadProgressStore {
  const OlympiadProgressStore(this.childId);

  final String childId;

  String _key(String attemptId) =>
      accountKey('g5_olympiad_answers_v1_$attemptId', childId);

  Future<Map<String, int>> load(String attemptId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(attemptId));
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map
          ? {
              for (final e in decoded.entries)
                if (e.value is int) '${e.key}': e.value as int,
            }
          : {};
    } on FormatException {
      return {};
    }
  }

  Future<void> save(String attemptId, Map<String, int> answers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(attemptId), jsonEncode(answers));
  }

  Future<void> clear(String attemptId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(attemptId));
  }
}
