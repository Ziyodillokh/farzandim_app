// «Men» ekranlari uchun umumiy ko'rinish: nishon belgisi, DON yozuvi nomi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/growth/common/subject_look.dart';
import 'package:farzandim_child/growth/common/media_visibility.dart';
import 'package:farzandim_child/growth/men/data/men_models.dart';

/// Server katalogi tartibi (javobda bo'lmasa ham ko'rsatiladi — qulf bilan).
/// Ko'rsatiladigan nishonlar («Birinchi kitob» — audio yashirin paytda yo'q).
List<String> get kVisibleBadges => [
  for (final id in kBadgeCatalog)
    if (kShowAudioVideo || id != 'first_book') id,
];

const kBadgeCatalog = [
  'streak_7',
  'first_book',
  'topic_master',
  'olympian',
  'streak_30',
  'thinker',
];

({GIconData icon, GHue hue}) badgeLook(String id) => switch (id) {
  'streak_7' => (icon: GIcons.fire, hue: GHue.orange),
  'streak_30' => (icon: GIcons.crown, hue: GHue.gold),
  'first_book' => (icon: GIcons.bookOpen, hue: GHue.green),
  'olympian' => (icon: GIcons.trophy, hue: GHue.gold),
  'topic_master' => (icon: GIcons.medal, hue: GHue.blue),
  'thinker' => (icon: GIcons.brain, hue: GHue.teal),
  _ => (icon: GIcons.star, hue: GHue.slate),
};

String badgeTitle(String id) => 'g5.men.level.badge.$id.title'.tr();

String badgeHint(String id) => 'g5.men.level.badge.$id.hint'.tr();

/// DON yozuvi nomi («Matematika mashqi», «Qadamlar», kitob nomi …).
String donEntryTitle(DonEntry e) => switch (e.kind) {
  DonKind.learning =>
    e.subject == null
        ? 'g5.men.don.learningAny'.tr()
        : 'g5.men.don.learning'.tr(namedArgs: {'subject': e.subject!.label}),
  DonKind.steps => 'g5.men.don.steps'.tr(),
  DonKind.olympiad => e.title ?? 'g5.men.don.olympiad'.tr(),
  DonKind.book => e.title ?? 'g5.men.don.book'.tr(),
  DonKind.video => e.title ?? 'g5.men.don.video'.tr(),
  DonKind.other => e.title ?? 'g5.men.don.other'.tr(),
};

({GIconData icon, GHue hue}) donEntryLook(DonEntry e) => switch (e.kind) {
  DonKind.learning when e.subject != null => (
    icon: e.subject!.gIcon,
    hue: e.subject!.gHue,
  ),
  DonKind.learning => (icon: GIcons.sparkle, hue: GHue.blue),
  DonKind.steps => (icon: GIcons.footprints, hue: GHue.green),
  DonKind.olympiad => (icon: GIcons.trophy, hue: GHue.gold),
  DonKind.book => (icon: GIcons.bookOpen, hue: GHue.green),
  DonKind.video => (icon: GIcons.play, hue: GHue.rose),
  DonKind.other => (icon: GIcons.star, hue: GHue.slate),
};
