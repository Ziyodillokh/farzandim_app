// "Bugungi testlar" kartalari uchun umumiy matnlar (bosh sahifa va
// Testlar sahifasi bir xil holatlarni ko'rsatadi).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/domain/learning_stats.dart';

/// Sarlavha ostidagi izoh: tayyor / qisman bajarilgan / hammasi bajarilgan.
String dailyPlanSubtitle(DailyPlan plan) {
  if (plan.isComplete) {
    final percent = percentOf([for (final item in plan.items) ?item.result]);
    return 'learn.allDoneSubtitle'.tr(
      namedArgs: {'percent': '${percent ?? 0}'},
    );
  }
  if (plan.doneCount > 0) {
    return 'learn.todayProgress'.tr(
      namedArgs: {'done': '${plan.doneCount}', 'total': '${plan.items.length}'},
    );
  }
  return 'home.todayTestsReady'.tr(
    namedArgs: {'count': '${plan.items.length}'},
  );
}

/// Asosiy tugma: Boshlash → Davom etish → Natijalarim.
String dailyPlanButtonLabel(DailyPlan plan) {
  if (plan.isComplete) return 'learn.toResults'.tr();
  if (plan.doneCount > 0) return 'learn.continue'.tr();
  return 'home.start'.tr();
}

/// Plitkadagi ikkinchi qator: "10 ta savol" yoki "9/10 ✓".
String dailyPlanItemCaption(DailyPlanItem item) {
  final result = item.result;
  if (result == null) return 'home.questions'.plural(item.questionCount);
  return '${result.correct}/${result.total}';
}
