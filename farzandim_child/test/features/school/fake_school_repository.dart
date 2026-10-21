// Xotiradagi maktab manbai — provider / widget testlari va skrinshot harness'i
// uchun. Chaqirilgan metodlar `calls`ga yoziladi; `failNext` keyingi
// so'rovni bir marta yiqitadi.

import 'dart:async';

import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/features/school/domain/attendance_models.dart';
import 'package:farzandim_child/features/school/domain/care_models.dart';
import 'package:farzandim_child/features/school/domain/psych_answer.dart';
import 'package:farzandim_child/features/school/domain/psych_models.dart';
import 'package:farzandim_child/features/school/domain/school_assignment.dart';

class FakeSchoolRepository implements SchoolRepository {
  FakeSchoolRepository({
    this.today,
    this.checkInAction = CheckInAction.arrived,
    this.careSurvey = CareSurveyStatus.notEnrolled,
    List<CareRequest> careRequests = const [],
    List<PsychAssignmentSummary> psychAssignments = const [],
    List<PsychTest> psychTests = const [],
    List<SchoolAssignment> assignments = const [],
    DateTime Function()? clock,
  }) : careRequests = [...careRequests],
       psychAssignments = [...psychAssignments],
       psychTests = [...psychTests],
       assignments = [...assignments],
       _clock = clock ?? DateTime.now;

  SchoolToday? today;
  CheckInAction checkInAction;
  CareSurveyStatus careSurvey;
  final List<CareRequest> careRequests;
  final List<PsychAssignmentSummary> psychAssignments;
  final List<PsychTest> psychTests;
  final List<SchoolAssignment> assignments;
  final DateTime Function() _clock;

  /// Keyingi so'rov shu xato bilan yiqiladi (bir marta).
  SchoolException? failNext;

  /// Shu nomli metodning keyingi chaqiruvi yiqiladi (bir marta).
  final Map<String, SchoolException> failOnce = {};

  /// Chaqirilgan metodlar nomlari (tartibda).
  final List<String> calls = [];

  /// Oxirgi yuborilgan test javoblari va davomiyligi.
  Map<String, PsychAnswer>? submittedAnswers;
  int? submittedDurationSec;

  /// Oxirgi yuborilgan so'rovnoma javoblari.
  Map<String, int>? submittedSurvey;

  /// Yuborilgan murojaatlar (mavzu, matn, shoshilinchlik).
  final List<(CareTopic, String, CareUrgency)> sentRequests = [];

  /// Berilsa, keyingi yuborish (test / so'rovnoma / murojaat) shu
  /// tugaguncha kutadi ("yuborilmoqda").
  Completer<void>? holdNextSubmit;

  Future<void> _holdSubmit() async {
    final hold = holdNextSubmit;
    holdNextSubmit = null;
    if (hold != null) await hold.future;
  }

  /// Berilsa, keyingi `loadToday` shu tugaguncha kutadi va so'rov
  /// boshlangandagi holatni qaytaradi (sekin, "eski" javob).
  Completer<void>? holdNextToday;

  /// Berilsa, keyingi `checkIn` shu tugaguncha kutadi ("tekshirilmoqda").
  Completer<void>? holdNextCheckIn;

  /// `checkIn`ga yuborilgan tokenlar (tartibda).
  final List<String> checkInTokens = [];

  void _enter(String method) {
    calls.add(method);
    final error = failNext ?? failOnce.remove(method);
    if (error != null) {
      if (identical(error, failNext)) failNext = null;
      throw error;
    }
  }

  @override
  Future<SchoolToday?> loadToday() async {
    _enter('loadToday');
    final snapshot = today;
    final hold = holdNextToday;
    holdNextToday = null;
    if (hold != null) await hold.future;
    return snapshot;
  }

  @override
  Future<CheckInResult> checkIn(String token) async {
    checkInTokens.add(token);
    _enter('checkIn');
    final hold = holdNextCheckIn;
    holdNextCheckIn = null;
    if (hold != null) await hold.future;
    return CheckInResult(action: checkInAction, today: today);
  }

  @override
  Future<CareSurveyStatus> loadCareSurvey() async {
    _enter('loadCareSurvey');
    return careSurvey;
  }

  @override
  Future<void> submitCareSurvey(
    String surveyId,
    Map<String, int> answers,
  ) async {
    _enter('submitCareSurvey');
    await _holdSubmit();
    submittedSurvey = Map.unmodifiable(answers);
    careSurvey = const CareSurveyStatus(isEnrolled: true, isAnswered: true);
  }

  @override
  Future<List<CareRequest>> loadCareRequests() async {
    _enter('loadCareRequests');
    return List.unmodifiable(careRequests);
  }

  @override
  Future<CareRequest> createCareRequest({
    required CareTopic topic,
    required String message,
    CareUrgency urgency = CareUrgency.normal,
  }) async {
    _enter('createCareRequest');
    await _holdSubmit();
    sentRequests.add((topic, message, urgency));
    final request = CareRequest(
      id: 'request-${careRequests.length + 1}',
      topic: topic,
      urgency: urgency,
      status: CareRequestStatus.sent,
      createdAt: _clock().toUtc(),
    );
    careRequests.insert(0, request);
    return request;
  }

  @override
  Future<List<PsychAssignmentSummary>> loadPsychAssignments() async {
    _enter('loadPsychAssignments');
    return List.unmodifiable(psychAssignments);
  }

  @override
  Future<PsychTest> loadPsychTest(String assignmentId) async {
    _enter('loadPsychTest');
    for (final test in psychTests) {
      if (test.assignmentId == assignmentId) return test;
    }
    throw const SchoolException(SchoolErrorCode.assignmentNotFound);
  }

  @override
  Future<void> submitPsychTest(
    PsychTest test, {
    required Map<String, PsychAnswer> answers,
    int? durationSec,
  }) async {
    _enter('submitPsychTest');
    await _holdSubmit();
    submittedAnswers = Map.unmodifiable(answers);
    submittedDurationSec = durationSec;
    psychAssignments.removeWhere((a) => a.assignmentId == test.assignmentId);
  }

  @override
  Future<List<SchoolAssignment>> loadAssignments() async {
    _enter('loadAssignments');
    return List.unmodifiable(assignments);
  }
}
