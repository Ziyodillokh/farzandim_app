// U10 · Oflayn to'plam: haftalik imzolangan to'plam (`/learning/offline-pack`)
// qurilmada saqlanadi, mashqlar internetsiz bajariladi va yuborish navbatiga
// tushadi; internet bo'lganda `/learning/offline-attempts` ga yuboriladi
// (urinish id si ilovaniki — qayta yuborish xavfsiz, DON bir marta).
// Hammasi faol akkauntga bog'langan.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/learning/domain/localized_text.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/features/school/domain/school_json.dart';
import 'package:farzandim_child/growth/kirish/data/account_local_data.dart';
import 'package:farzandim_child/growth/maktab/data/school_v5_repository.dart'
    show newRequestId;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class OfflineQuestion {
  const OfflineQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.explanation,
  });

  static OfflineQuestion? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = jsonNonEmpty(json['id']);
    final options = json['options'];
    final correct = jsonInt(json['correctIndex']);
    if (id == null || options is! List || correct == null) return null;
    try {
      return OfflineQuestion(
        id: id,
        prompt: LocalizedText.fromJson(json['prompt']),
        options: [for (final o in options) LocalizedText.fromJson(o)],
        correctIndex: correct,
        explanation: json['explanation'] == null
            ? null
            : LocalizedText.fromJson(json['explanation']),
      );
    } on FormatException {
      return null;
    }
  }

  final String id;
  final LocalizedText prompt;
  final List<LocalizedText> options;
  final int correctIndex;
  final LocalizedText? explanation;

  Map<String, Object?> toJson() => {
    'id': id,
    'prompt': prompt.toJson(),
    'options': [for (final o in options) o.toJson()],
    'correctIndex': correctIndex,
    'explanation': explanation?.toJson(),
  };
}

@immutable
class OfflineSet {
  const OfflineSet({
    required this.subject,
    required this.questions,
    required this.signature,
  });

  static OfflineSet? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final subject = Subject.fromName(json['subject'] as String?);
    final signature = jsonNonEmpty(json['signature']);
    final raw = json['questions'];
    if (subject == null || signature == null || raw is! List) return null;
    final questions = [for (final q in raw) ?OfflineQuestion.tryFromJson(q)];
    if (questions.isEmpty || questions.length != raw.length) return null;
    return OfflineSet(
      subject: subject,
      questions: questions,
      signature: signature,
    );
  }

  final Subject subject;
  final List<OfflineQuestion> questions;
  final String signature;

  Map<String, Object?> toJson() => {
    'subject': subject.name,
    'questions': [for (final q in questions) q.toJson()],
    'signature': signature,
  };
}

@immutable
class OfflinePack {
  const OfflinePack({
    required this.packId,
    required this.version,
    required this.issuedAt,
    required this.expiresAt,
    required this.sets,
  });

  static OfflinePack? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final packId = jsonNonEmpty(json['packId']);
    final issuedAt = DateTime.tryParse('${json['issuedAt']}');
    final expiresAt = DateTime.tryParse('${json['expiresAt']}');
    final raw = json['sets'];
    if (packId == null ||
        issuedAt == null ||
        expiresAt == null ||
        raw is! List) {
      return null;
    }
    return OfflinePack(
      packId: packId,
      version: jsonInt(json['version']) ?? 1,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      sets: [for (final s in raw) ?OfflineSet.tryFromJson(s)],
    );
  }

  final String packId;
  final int version;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final List<OfflineSet> sets;

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  Map<String, Object?> toJson() => {
    'packId': packId,
    'version': version,
    'issuedAt': issuedAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'sets': [for (final s in sets) s.toJson()],
  };
}

enum OfflineUploadState { pending, accepted, rejected }

/// Oflayn bajarilgan mashq (yuborish navbatida).
@immutable
class OfflineAttempt {
  const OfflineAttempt({
    required this.id,
    required this.packId,
    required this.expiresAt,
    required this.signature,
    required this.subject,
    required this.answers,
    required this.correct,
    required this.completedAt,
    this.state = OfflineUploadState.pending,
    this.don,
  });

  static OfflineAttempt? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = jsonNonEmpty(json['id']);
    final subject = Subject.fromName(json['subject'] as String?);
    final answers = json['answers'];
    final completedAt = DateTime.tryParse('${json['completedAt']}');
    if (id == null ||
        subject == null ||
        answers is! Map ||
        completedAt == null) {
      return null;
    }
    return OfflineAttempt(
      id: id,
      packId: '${json['packId']}',
      expiresAt: '${json['expiresAt']}',
      signature: '${json['signature']}',
      subject: subject,
      answers: {
        for (final e in answers.entries)
          if (e.value is int) '${e.key}': e.value as int,
      },
      correct: jsonInt(json['correct']) ?? 0,
      completedAt: completedAt,
      state:
          OfflineUploadState.values.asNameMap()[json['state']] ??
          OfflineUploadState.pending,
      don: jsonInt(json['don']),
    );
  }

  final String id;
  final String packId;
  final String expiresAt;
  final String signature;
  final Subject subject;

  /// Savol id si → tanlangan variant (to'plamdagi tartibda).
  final Map<String, int> answers;
  final int correct;
  final DateTime completedAt;
  final OfflineUploadState state;
  final int? don;

  int get total => answers.length;

  OfflineAttempt withState(OfflineUploadState state, {int? don}) =>
      OfflineAttempt(
        id: id,
        packId: packId,
        expiresAt: expiresAt,
        signature: signature,
        subject: subject,
        answers: answers,
        correct: correct,
        completedAt: completedAt,
        state: state,
        don: don ?? this.don,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'packId': packId,
    'expiresAt': expiresAt,
    'signature': signature,
    'subject': subject.name,
    'answers': answers,
    'correct': correct,
    'completedAt': completedAt.toUtc().toIso8601String(),
    'state': state.name,
    'don': ?don,
  };

  Map<String, Object> toUpload() => {
    'clientAttemptId': id,
    'packId': packId,
    'expiresAt': expiresAt,
    'signature': signature,
    'subject': subject.name,
    'questionIds': answers.keys.toList(),
    'answers': [
      for (final e in answers.entries)
        {'questionId': e.key, 'selectedIndex': e.value},
    ],
    'completedAt': completedAt.toUtc().toIso8601String(),
  };
}

/// Yuborish natijasi.
enum UploadOutcome { accepted, rejected, retryLater }

class OfflineRepository {
  OfflineRepository(this._dio);

  final Dio _dio;

  Future<OfflinePack?> download() async {
    final res = await _dio.get<Object?>('/learning/offline-pack');
    return OfflinePack.tryFromJson(res.data);
  }

  /// `(natija, DON)`: tarmoq / server vaqtinchalik xatosi — keyinroq qayta.
  Future<(UploadOutcome, int?)> upload(OfflineAttempt attempt) async {
    try {
      final res = await _dio.post<Object?>(
        '/learning/offline-attempts',
        data: attempt.toUpload(),
      );
      final data = res.data;
      return (
        UploadOutcome.accepted,
        data is Map ? jsonInt(data['donEarned']) : null,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      debugPrint('[oflayn] yuborish: $status');
      // 4xx (muddat o'tgan, imzo yaroqsiz) — qayta yuborish foydasiz.
      if (status != null && status >= 400 && status < 500 && status != 429) {
        return (UploadOutcome.rejected, null);
      }
      return (UploadOutcome.retryLater, null);
    }
  }
}

final offlineRepositoryProvider = Provider<OfflineRepository>(
  (ref) => OfflineRepository(ref.watch(dioClientProvider)),
);

const _packBase = 'g5_offline_pack_v1';
const _queueBase = 'g5_offline_queue_v1';

/// Navbatdagi qabul qilingan yozuvlar shuncha kundan keyin tozalanadi.
const _keepAcceptedDays = 14;

@immutable
class OfflineState {
  const OfflineState({this.pack, this.queue = const []});

  final OfflinePack? pack;
  final List<OfflineAttempt> queue;

  List<OfflineAttempt> get pending => [
    for (final a in queue)
      if (a.state == OfflineUploadState.pending) a,
  ];
}

final offlineProvider =
    AsyncNotifierProvider.autoDispose<OfflineNotifier, OfflineState>(
      OfflineNotifier.new,
    );

class OfflineNotifier extends AutoDisposeAsyncNotifier<OfflineState> {
  String? _packKey;
  String? _queueKey;
  var _syncing = false;

  @override
  Future<OfflineState> build() async {
    _packKey = ref.watch(currentAccountKeyProvider(_packBase));
    _queueKey = ref.watch(currentAccountKeyProvider(_queueBase));
    final packKey = _packKey;
    final queueKey = _queueKey;
    if (packKey == null || queueKey == null) return const OfflineState();
    final prefs = await SharedPreferences.getInstance();
    return OfflineState(
      pack: _decode(prefs.getString(packKey), OfflinePack.tryFromJson),
      queue: [
        for (final raw in _decodeList(prefs.getString(queueKey)))
          ?OfflineAttempt.tryFromJson(raw),
      ],
    );
  }

  /// Yangi to'plamni yuklab olish (eskisi almashtiriladi; navbat qoladi).
  Future<void> download() async {
    final key = _packKey;
    if (key == null) return;
    final pack = await ref.read(offlineRepositoryProvider).download();
    if (pack == null) throw const FormatException('offline pack');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(pack.toJson()));
    state = AsyncData(OfflineState(pack: pack, queue: _queue));
  }

  /// Oflayn bajarilgan mashq navbatga qo'shiladi (keyin yuboriladi).
  Future<OfflineAttempt> record({
    required OfflinePack pack,
    required OfflineSet set,
    required Map<String, int> answers,
  }) async {
    final correct = set.questions
        .where((q) => answers[q.id] == q.correctIndex)
        .length;
    final attempt = OfflineAttempt(
      id: newRequestId(),
      packId: pack.packId,
      expiresAt: pack.expiresAt.toUtc().toIso8601String(),
      signature: set.signature,
      subject: set.subject,
      answers: {for (final q in set.questions) q.id: answers[q.id]!},
      correct: correct,
      completedAt: DateTime.now(),
    );
    await _saveQueue([..._queue, attempt]);
    return attempt;
  }

  /// Navbatdagilarni yuborish (biri xato bersa ham qolganlari davom etadi).
  Future<void> sync() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final repo = ref.read(offlineRepositoryProvider);
      for (final attempt in _queue.where(
        (a) => a.state == OfflineUploadState.pending,
      )) {
        final (outcome, don) = await repo.upload(attempt);
        if (outcome == UploadOutcome.retryLater) continue;
        await _saveQueue([
          for (final a in _queue)
            a.id == attempt.id
                ? a.withState(
                    outcome == UploadOutcome.accepted
                        ? OfflineUploadState.accepted
                        : OfflineUploadState.rejected,
                    don: don,
                  )
                : a,
        ]);
      }
    } finally {
      _syncing = false;
    }
  }

  List<OfflineAttempt> get _queue => state.valueOrNull?.queue ?? const [];

  Future<void> _saveQueue(List<OfflineAttempt> queue) async {
    final key = _queueKey;
    if (key == null) return;
    final cutoff = DateTime.now().subtract(
      const Duration(days: _keepAcceptedDays),
    );
    final kept = [
      for (final a in queue)
        if (a.state == OfflineUploadState.pending ||
            a.completedAt.isAfter(cutoff))
          a,
    ];
    state = AsyncData(OfflineState(pack: state.valueOrNull?.pack, queue: kept));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode([for (final a in kept) a.toJson()]));
  }

  static T? _decode<T>(String? raw, T? Function(Object?) parse) {
    if (raw == null) return null;
    try {
      return parse(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  static List<Object?> _decodeList(String? raw) {
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : const [];
    } on FormatException {
      return const [];
    }
  }
}
