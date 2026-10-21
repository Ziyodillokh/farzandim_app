// Xotiradagi Kelajak manbai — provider / notifier testlari uchun. Har
// endpoint javobi test tomonidan beriladi (tartibni boshqarish uchun
// `Completer` ham bo'lishi mumkin); chaqiruvlar yozib boriladi.

import 'package:farzandim_child/features/kelajak/data/kelajak_repository.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_overview.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_progress.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_session.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_types.dart';

/// `PUT .../answers/:questionId` chaqiruvi.
class SaveCall {
  const SaveCall(this.sessionId, this.questionId, {this.value, this.text});

  final String sessionId;
  final String questionId;
  final int? value;
  final String? text;

  /// Server javobi (bo'sh matn — javob o'chirildi).
  KelajakAnswerAck ack({
    KelajakSessionStatus status = KelajakSessionStatus.inProgress,
    int answeredCount = 1,
  }) => KelajakAnswerAck(
    questionId: questionId,
    value: value,
    text: text == null || text!.isEmpty ? null : text,
    sessionStatus: status,
    answeredCount: answeredCount,
  );
}

Never _missing(String endpoint) =>
    throw StateError('FakeKelajakRepository: $endpoint berilmagan');

class FakeKelajakRepository implements KelajakRepository {
  Future<KelajakOverview> Function() onOverview = () => _missing('overview');
  Future<KelajakSession> Function(String type) onStart = (_) =>
      _missing('start');
  Future<KelajakAnswerAck> Function(SaveCall call) onSave = (call) async =>
      call.ack();
  Future<KelajakSession> Function(String sessionId) onComplete = (_) =>
      _missing('complete');
  Future<KelajakProgress> Function() onProgress = () => _missing('progress');
  Future<KelajakResultsPage> Function(String? before, int limit) onResults =
      (_, _) => _missing('results');

  int overviewLoads = 0;
  final starts = <String>[];
  final saves = <SaveCall>[];
  final completes = <String>[];
  final resultCursors = <String?>[];

  @override
  Future<KelajakOverview> loadOverview() {
    overviewLoads++;
    return onOverview();
  }

  @override
  Future<KelajakSession> startSession(String type) {
    starts.add(type);
    return onStart(type);
  }

  @override
  Future<KelajakSession> loadSession(String sessionId) =>
      _missing('loadSession');

  @override
  Future<KelajakAnswerAck> saveAnswer({
    required String sessionId,
    required String questionId,
    int? value,
    String? text,
  }) {
    final call = SaveCall(sessionId, questionId, value: value, text: text);
    saves.add(call);
    return onSave(call);
  }

  @override
  Future<KelajakSession> completeSession(String sessionId) {
    completes.add(sessionId);
    return onComplete(sessionId);
  }

  @override
  Future<KelajakProgress> loadProgress() => onProgress();

  @override
  Future<KelajakResultsPage> loadResults({
    String? before,
    int limit = kKelajakResultsPageSize,
  }) {
    resultCursors.add(before);
    return onResults(before, limit);
  }
}
