// Fanlarning v5 ko'rinishi: ikki rangli ikon va plita rangi (kanvas bilan bir xil).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';

extension SubjectLook on Subject {
  /// Har fanga o'z ikoni (globus — faqat geografiya, til fanlari alohida).
  GIconData get gIcon => switch (this) {
    Subject.math => GIcons.mathOperations,
    Subject.native => GIcons.bookOpenText,
    Subject.english => GIcons.translate,
    Subject.russian => GIcons.chatsCircle,
    Subject.history => GIcons.scroll,
    Subject.biology => GIcons.dna,
    Subject.geography => GIcons.globeHemisphereEast,
    Subject.physics => GIcons.atom,
    Subject.chemistry => GIcons.flask,
    Subject.informatics => GIcons.laptop,
  };

  /// Plita rangi. 8 rang 10 fanga: har sinfning asosiy 6 talik to'rida
  /// ranglar takrorlanmaydi; takrorlanadiganlar (fizika/geografiya, rus
  /// tili/tarix) faqat «Barcha fanlar»da yonma-yon chiqadi va ikoni bilan
  /// ajraladi.
  GHue get gHue => switch (this) {
    Subject.math => GHue.blue,
    Subject.native => GHue.green,
    Subject.english => GHue.orange,
    Subject.russian => GHue.rose,
    Subject.history => GHue.rose,
    Subject.biology => GHue.teal,
    Subject.geography => GHue.sky,
    Subject.physics => GHue.sky,
    Subject.chemistry => GHue.gold,
    Subject.informatics => GHue.slate,
  };

  /// Fan nomi joriy tilda.
  String get label => labelKey.tr();
}

/// Fanning plitasi (o'lcham kanvasdagidek: ro'yxatda 40, ko'rsatkichda 34).
GTile subjectTile(Subject subject, {double size = 40}) =>
    GTile(icon: subject.gIcon, hue: subject.gHue, size: size);
