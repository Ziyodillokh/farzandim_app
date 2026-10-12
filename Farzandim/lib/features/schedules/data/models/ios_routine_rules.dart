// iPhone'dagi bola uchun rejim (routine) qoidalari — sof funksiyalar.
//
// iOS bola ilovasi haqiqiy ilovalar ro'yxatini yubormaydi: rejimning
// `blockedApps` ro'yxatida faqat virtual `kIosSelectionPackage` bo'lishi
// mumkin va u bola iPhone'da O'ZI tanlagan ilovalarni bildiradi. Apple
// DeviceActivity jadvali kamida 15 daqiqalik oynani talab qiladi — qisqaroq
// oynalar iOS'da e'tiborsiz qoladi (o'z vaqtida o'chmasdi), shuning uchun
// ota-ona ilovasi ularni saqlashdan oldin rad etadi.

import 'package:farzandim/core/utils/app_brand.dart';

/// Apple DeviceActivitySchedule eng qisqa oralig'i (daqiqa).
const kIosMinRoutineWindowMinutes = 15;

const _minutesPerDay = 24 * 60;

/// Rejim oynasi davomiyligi (daqiqa). Tugash boshlanishdan oldin bo'lsa oyna
/// yarim tundan o'tadi (masalan 22:00 → 07:00 = 540). Boshlanish == tugash
/// bo'lsa 0 — bola ilovasi ham bunday oynani hech qachon bloklamaydi.
int routineWindowMinutes({
  required int startHour,
  required int startMinute,
  required int endHour,
  required int endMinute,
}) {
  final start = startHour * 60 + startMinute;
  final end = endHour * 60 + endMinute;
  return (end - start + _minutesPerDay) % _minutesPerDay;
}

/// Oyna iOS bloklashi uchun yetarlicha uzunmi ([kIosMinRoutineWindowMinutes]
/// va undan ko'p).
bool isRoutineWindowValidForIos({
  required int startHour,
  required int startMinute,
  required int endHour,
  required int endMinute,
}) =>
    routineWindowMinutes(
      startHour: startHour,
      startMinute: startMinute,
      endHour: endHour,
      endMinute: endMinute,
    ) >=
    kIosMinRoutineWindowMinutes;

/// iOS bola uchun rejimning `blockedApps` qiymati: bloklash yoqilgan bo'lsa
/// virtual "tanlangan ilovalar" yozuvi, aks holda bo'sh ro'yxat.
List<String> iosRoutineBlockedApps({required bool block}) =>
    block ? const [kIosSelectionPackage] : const [];

/// Rejim iPhone'ning tanlangan ilovalarini bloklaydimi.
bool routineBlocksIosApps(List<String> blockedApps) =>
    blockedApps.contains(kIosSelectionPackage);
