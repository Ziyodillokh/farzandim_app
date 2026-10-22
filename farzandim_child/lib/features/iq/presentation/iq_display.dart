// IQ test — matn kalitlari, ranglar va navigatsiya (bir joyda).
// Daraja matnlari yumshoq: past darajalar "Rivojlanish zonasi"
// (skrining, tashxis emas — docs/IQ-REJA.md §3.5).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/iq/data/iq_repository.dart';
import 'package:farzandim_child/features/iq/domain/iq_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

abstract final class IqRoutes {
  static const hub = '/iq';
  static const test = '/iq/test';
  static const ageEdit = '/account-edit';
  static const home = '/dashboard';
}

void openIqHub(BuildContext context) {
  HapticFeedback.selectionClick();
  context.push(IqRoutes.hub);
}

void openIqTest(BuildContext context) {
  HapticFeedback.selectionClick();
  context.push(IqRoutes.test);
}

void closeIqPage(BuildContext context) =>
    context.canPop() ? context.pop() : context.go(IqRoutes.hub);

String iqBandLabel(IqBand band) => 'iq.band.${band.name}'.tr();

Color iqBandColor(IqBand band) => switch (band) {
  IqBand.veryHigh || IqBand.high || IqBand.aboveAverage => HomeColors.green,
  IqBand.average => HomeColors.blue,
  IqBand.belowAverage || IqBand.low || IqBand.veryLow => HomeColors.amber,
};

String iqErrorText(IqErrorCode code) => 'iq.error.${code.name}'.tr();

/// Savol turi nomi: "Naqsh", "Sonlar", "So'zlar", "Mantiq".
String iqKindLabel(IqItemKind kind) => 'iq.kind.${kind.name}'.tr();

Color iqKindColor(IqItemKind kind) => switch (kind) {
  IqItemKind.figural => HomeColors.blue,
  IqItemKind.numeric => HomeColors.green,
  IqItemKind.verbal => HomeColors.amber,
  IqItemKind.logic => HomeColors.orange,
};

/// "21 aprel 2027" — joriy til bo'yicha.
String iqDate(BuildContext context, DateTime instant) =>
    DateFormat.yMMMMd(context.locale.toLanguageTag()).format(instant.toLocal());
