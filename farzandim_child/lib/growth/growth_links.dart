// Growth v5 ekranlari orasidagi o'tishlar — bitta joyda.
//
// Konsepsiyadagi har bir tugma shu yerdagi funksiya orqali ochiladi. Hali
// qurilmagan v5 ekranlar o'z bosqichigacha mavjud (eski) ekranga olib boradi —
// hech bir tugma bo'sh qolmaydi. Bosqich tugaganda faqat shu fayl o'zgaradi.

import 'package:farzandim_child/features/kelajak/presentation/kelajak_navigation.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/features/learning/presentation/learning_navigation.dart';
import 'package:farzandim_child/features/school/presentation/school_navigation.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

abstract final class GrowthLinks {
  /// B02 · Bildirishnomalar.
  static void notifications(BuildContext context) =>
      _push(context, GrowthV5Routes.notifications);

  /// F03 · SOS yordami.
  static void sos(BuildContext context) =>
      _push(context, GrowthV5Routes.familySos);

  /// I06 · Daraja va nishonlar.
  static void level(BuildContext context) =>
      _push(context, GrowthV5Routes.meLevel);

  /// I02 · Shaxsiy o'sish.
  static void meGrowth(BuildContext context) =>
      _push(context, GrowthV5Routes.meGrowth);

  /// I03 · DON tarixi.
  static void meDon(BuildContext context) =>
      _push(context, GrowthV5Routes.meDon);

  /// I04 · Sozlamalar.
  static void meSettings(BuildContext context) =>
      _push(context, GrowthV5Routes.meSettings);

  /// I05 · Mening ruxsatlarim.
  static void mePermissions(BuildContext context) =>
      _push(context, GrowthV5Routes.mePermissions);

  /// I07 · Bildirishnoma sozlamalari.
  static void meNotifications(BuildContext context) =>
      _push(context, GrowthV5Routes.meNotifications);

  /// I08 · Yordam.
  static void meHelp(BuildContext context) =>
      _push(context, GrowthV5Routes.meHelp);

  /// I09 · Maxfiylik va ma'lumotlarim.
  static void mePrivacy(BuildContext context) =>
      _push(context, GrowthV5Routes.mePrivacy);

  /// K01 · Qiziqishlarim.
  static void interests(BuildContext context) =>
      _push(context, GrowthV5Routes.kelajakInterests);

  /// F01 · Oila va aloqa.
  static void family(BuildContext context) =>
      _push(context, GrowthV5Routes.family);

  /// M01 · Maktab tabi.
  static void schoolTab(BuildContext context) =>
      context.go(GrowthV5Routes.school);

  /// U01 · O'qish tabi.
  static void learnTab(BuildContext context) =>
      context.go(GrowthV5Routes.learn);

  /// K02 · Kunning savoli (6-bosqichgacha: Kelajak kunlik testi).
  static void dailyQuestion(BuildContext context, String? type) {
    if (type == null) {
      openKelajakHub(context);
    } else {
      openKelajakSession(context, type);
    }
  }

  /// U02 · Fanning bilim xaritasi.
  static void subjectMap(BuildContext context, Subject subject) =>
      _push(context, GrowthV5Routes.subjectMap(subject));

  /// U01b · Barcha fanlar.
  static void allSubjects(BuildContext context) =>
      _push(context, GrowthV5Routes.allSubjects);

  /// I10 · Ilova qulfi (PIN-kod).
  static void meLock(BuildContext context) =>
      _push(context, GrowthV5Routes.meLock);

  /// I04b · Parolni almashtirish.
  static void mePassword(BuildContext context) =>
      _push(context, GrowthV5Routes.mePassword);

  /// U03 · Mavzu va mashq rejasi.
  static void topic(BuildContext context, Subject subject, String topicId) =>
      _push(context, GrowthV5Routes.topic(subject, topicId));

  /// U04 · Mavzu bo'yicha mashq.
  static void topicPractice(
    BuildContext context,
    Subject subject,
    String topicId,
  ) => _push(context, GrowthV5Routes.practice(subject, topicId: topicId));

  /// M02 · Maktab vazifalari.
  static void schoolTasks(BuildContext context) =>
      _push(context, GrowthV5Routes.schoolTasks);

  /// M03 · Topshiriq tafsiloti.
  static void schoolTask(BuildContext context, String id) =>
      _push(context, GrowthV5Routes.schoolTask(id));

  /// M08 · Yozma vazifa javobini yuborish.
  static void homeworkSubmit(BuildContext context, String id) =>
      _push(context, GrowthV5Routes.homeworkSubmit(id));

  /// M04 · Davomat.
  static void attendance(BuildContext context) =>
      _push(context, GrowthV5Routes.attendance);

  /// M05 · Davomat tarixi.
  static void attendanceHistory(BuildContext context) =>
      _push(context, GrowthV5Routes.attendanceHistory);

  /// Kiosk QR'ini skanerlash (mavjud xavfsiz kirish/chiqish oqimi).
  static void schoolCheckIn(BuildContext context) =>
      _push(context, SchoolRoutes.checkIn);

  /// M06 · Maktab e'lonlari.
  static void notices(BuildContext context) =>
      _push(context, GrowthV5Routes.notices);

  /// M07 · Dars jadvali.
  static void timetable(BuildContext context) =>
      _push(context, GrowthV5Routes.timetable);

  /// H01 · Bola ovozi.
  static void studentVoice(BuildContext context) =>
      _push(context, GrowthV5Routes.voice);

  /// H04 · Shaxsiy yordam (psixologga yozish).
  static void psychologist(BuildContext context) =>
      _push(context, GrowthV5Routes.voiceHelp);

  /// H02 · Anonim so'rovga taklif.
  static void voiceSurvey(BuildContext context) =>
      _push(context, GrowthV5Routes.voiceSurvey);

  /// H03 · Anonim so'rov savollari (taklif ekrani o'rnida ochiladi).
  static void voiceSurveyRun(BuildContext context) {
    HapticFeedback.selectionClick();
    context.pushReplacement(GrowthV5Routes.voiceSurveyRun);
  }

  /// H05 · Yangi shaxsiy murojaat.
  static void voiceCompose(BuildContext context) =>
      _push(context, GrowthV5Routes.voiceCompose);

  /// H06 · Murojaatlarim.
  static void voiceRequests(BuildContext context) =>
      _push(context, GrowthV5Routes.voiceRequests);

  /// H07/H08 · Murojaat holati va yozishma ([replace] — yuborilgan shakl o'rnida).
  static void voiceRequest(
    BuildContext context,
    String id, {
    bool replace = false,
  }) {
    HapticFeedback.selectionClick();
    final location = GrowthV5Routes.voiceRequest(id);
    if (replace) {
      context.pushReplacement(location);
    } else {
      context.push(location);
    }
  }

  /// H10 · Mutaxassis tayinlagan shaxsiy so'rov (vaqtli yoki xotira savolli
  /// test — mavjud test ekranida).
  static void voicePersonal(
    BuildContext context,
    String assignmentId, {
    bool legacy = false,
  }) => legacy
      ? openPsychTest(context, assignmentId)
      : _push(context, GrowthV5Routes.voicePersonal(assignmentId));

  /// U09 · Urinishlar tarixi.
  static void attempts(BuildContext context) =>
      _push(context, GrowthV5Routes.attempts);

  /// U08 · Saqlangan mashq natijasi.
  static void result(BuildContext context, String resultId) =>
      _push(context, GrowthV5Routes.result(resultId));

  /// U11 · Kutubxona.
  static void library(BuildContext context) =>
      _push(context, GrowthV5Routes.library);

  /// U12 · Audiokitob (seriyaning istalgan qismi).
  static void audiobook(BuildContext context, String id) =>
      _push(context, GrowthV5Routes.audiobook(id));

  /// U13 · Videodars.
  static void video(BuildContext context, String id) =>
      _push(context, GrowthV5Routes.video(id));

  /// U14 · Maqola.
  static void article(BuildContext context, String id) =>
      _push(context, GrowthV5Routes.article(id));

  /// U17 · Olimpiada.
  static void olympiads(BuildContext context) =>
      _push(context, GrowthV5Routes.olympiads);

  /// U10 · Oflayn to'plam.
  static void offline(BuildContext context) =>
      _push(context, GrowthV5Routes.offline);

  /// U16 · Tafakkur natijasi (U15 topshiriqlari mavjud testda).
  static void thinking(BuildContext context) =>
      _push(context, GrowthV5Routes.thinking);

  /// U04 · Fan bo'yicha mashq.
  static void practice(BuildContext context, Subject subject) =>
      _push(context, GrowthV5Routes.practice(subject));

  /// A06 · Sinf va fanlar (5-bosqichgacha: mavjud sozlash ekrani).
  static void learningSetup(BuildContext context) =>
      _push(context, LearningRoutes.setup);

  static void _push(BuildContext context, String location) {
    HapticFeedback.selectionClick();
    context.push(location);
  }
}
