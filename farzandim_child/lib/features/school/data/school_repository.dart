// Maktab ma'lumot manbai interfeysi — server (`/api/child/school`, CHILD
// token): davomat, "Bola ovozi", psixologik testlar, maktab topshiriqlari.
// Bola maktabga ota-ona ilovasi orqali bog'lanadi; bog'lanmagan bo'lsa
// o'qish so'rovlari bo'sh javob qaytaradi.

import 'package:farzandim_child/features/school/domain/attendance_models.dart';
import 'package:farzandim_child/features/school/domain/care_models.dart';
import 'package:farzandim_child/features/school/domain/psych_answer.dart';
import 'package:farzandim_child/features/school/domain/psych_models.dart';
import 'package:farzandim_child/features/school/domain/school_assignment.dart';

abstract interface class SchoolRepository {
  /// Bugungi davomat holati (`null` — bola maktabga bog'lanmagan).
  Future<SchoolToday?> loadToday();

  /// Kiosk QR tokeni bilan kirish (dars tugagach — chiqish).
  Future<CheckInResult> checkIn(String token);

  /// Faol "Bola ovozi" so'rovnomasi.
  Future<CareSurveyStatus> loadCareSurvey();

  /// So'rovnoma javoblari: savol id → 1..5 (bir marta).
  Future<void> submitCareSurvey(String surveyId, Map<String, int> answers);

  /// Bolaning psixologga murojaatlari — yangisi birinchi.
  Future<List<CareRequest>> loadCareRequests();

  /// Psixologga murojaat yuborish.
  Future<CareRequest> createCareRequest({
    required CareTopic topic,
    required String message,
    CareUrgency urgency,
  });

  /// Ochiq, hali yechilmagan psixologik testlar (yopilishi yaqini birinchi).
  Future<List<PsychAssignmentSummary>> loadPsychAssignments();

  /// Yechish uchun test (to'g'ri javoblarsiz).
  Future<PsychTest> loadPsychTest(String assignmentId);

  /// Javoblarni yuborish (bir marta; bolaga ball qaytmaydi).
  Future<void> submitPsychTest(
    PsychTest test, {
    required Map<String, PsychAnswer> answers,
    int? durationSec,
  });

  /// Sinfga berilgan maktab topshiriqlari (muddati bo'yicha).
  Future<List<SchoolAssignment>> loadAssignments();
}

/// Xato kodlari (UI tegishli matnni [messageKey] orqali tanlaydi).
enum SchoolErrorCode {
  /// Bola shu maktab o'quvchisi emas (yoki sinfga biriktirilmagan).
  notEnrolled,

  /// Kiosk QR yaroqsiz (imzo, maktab yoki format).
  kioskInvalid,

  /// Kiosk QR eskirgan — ekrandagi yangisini skanerlash kerak.
  kioskExpired,

  /// O'quv kuni yoki dars vaqti emas.
  outsideHours,

  /// So'rovnoma endi faol emas.
  surveyNotFound,

  /// So'rovnomaga allaqachon javob berilgan.
  alreadyAnswered,

  /// Test yopilgan yoki muddati tugagan.
  assignmentNotFound,

  /// Test allaqachon topshirilgan.
  alreadySubmitted,

  /// Juda ko'p so'rov (murojaat: kuniga 5 ta).
  tooManyRequests,

  /// Serverda maktab ma'lumotlari kaliti sozlanmagan.
  notConfigured,

  /// Ma'lumot noto'g'ri yoki to'liq emas.
  validation,

  /// Server bu funksiyani hali bilmaydi (404, kodsiz) — maktab UI'si
  /// yashiriladi.
  unavailable,

  /// Internet yo'q / javob kelmadi.
  network,
  unknown;

  /// Tarjima kaliti — `school.errors.<name>`.
  String get messageKey => 'school.errors.$name';
}

class SchoolException implements Exception {
  const SchoolException(this.code, [this.message]);

  final SchoolErrorCode code;

  /// Server xabari (VALIDATION: `"<maydon>: <i18n kalit>"`).
  final String? message;

  @override
  String toString() =>
      'SchoolException($code${message == null ? '' : ': $message'})';
}
