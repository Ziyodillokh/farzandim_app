// Parvoz Kelajak — server enum qiymatlari (docs/KELAJAK-REJA.md §4).
// Noma'lum qiymat istisno tashlamaydi: `unknown` bo'lib o'qiladi (server
// yangi tur qo'shsa eski ilova yiqilmasin).

import 'package:farzandim_child/features/school/domain/school_json.dart';

/// Bolaning yosh holati — testlar faqat `ok` bo'lsa beriladi.
enum KelajakAgeStatus implements WireEnum {
  ok('OK'),

  /// Yosh ham, tug'ilgan sana ham yo'q — profilda yosh kiritiladi.
  ageRequired('AGE_REQUIRED'),

  /// 7–18 yoshdan tashqarida — Kelajak ko'rsatilmaydi.
  ageOutOfRange('AGE_OUT_OF_RANGE'),
  unknown('');

  const KelajakAgeStatus(this.wire);

  @override
  final String wire;

  static KelajakAgeStatus fromWire(Object? value) =>
      enumFromWire(values, value, unknown);
}

/// Testning bugungi holati (overview).
enum KelajakTodayStatus implements WireEnum {
  /// Bugun hali boshlanmagan (`NEW`).
  notStarted('NEW'),
  started('STARTED'),
  inProgress('IN_PROGRESS'),
  completed('COMPLETED'),
  unknown('');

  const KelajakTodayStatus(this.wire);

  @override
  final String wire;

  static KelajakTodayStatus fromWire(Object? value) =>
      enumFromWire(values, value, unknown);
}

/// Sessiya holati.
enum KelajakSessionStatus implements WireEnum {
  started('STARTED'),
  inProgress('IN_PROGRESS'),
  completed('COMPLETED'),

  /// O'tgan kunda yakunlanmay qolgan — javob ham, yakun ham yo'q.
  abandoned('ABANDONED'),
  unknown('');

  const KelajakSessionStatus(this.wire);

  @override
  final String wire;

  /// Javob berish mumkin (bugun ochiq).
  bool get isOpen => this == started || this == inProgress;

  static KelajakSessionStatus fromWire(Object? value) =>
      enumFromWire(values, value, unknown);
}

/// Savol javob turi (shkala yoki ochiq matn).
enum KelajakAnswerType implements WireEnum {
  interest4('interest_4'),
  likert5('likert_5'),
  careerLab5('career_lab_5'),
  text('text'),
  frequency5('frequency_5'),
  yesNo('yes_no'),
  support4('support_4'),
  unknown('');

  const KelajakAnswerType(this.wire);

  @override
  final String wire;

  static KelajakAnswerType fromWire(Object? value) =>
      enumFromWire(values, value, unknown);
}

/// Test turi (overview va sessiyadagi `type`).
enum KelajakTestType implements WireEnum {
  daily('daily'),
  career('career'),
  wellbeing('wellbeing'),
  learning('learning'),
  self('self'),
  careerLab('career_lab'),
  voice('voice'),
  unknown('');

  const KelajakTestType(this.wire);

  @override
  final String wire;

  static KelajakTestType fromWire(Object? value) =>
      enumFromWire(values, value, unknown);
}

/// Qo'llab-quvvatlash darajasi — bolaga raqamsiz, mehribon xabar bilan.
enum KelajakSupportLevel implements WireEnum {
  none('none'),
  watch('watch'),
  support('support'),
  unknown('');

  const KelajakSupportLevel(this.wire);

  @override
  final String wire;

  static KelajakSupportLevel fromWire(Object? value) =>
      enumFromWire(values, value, unknown);
}

/// Keyingi tavsiya turi.
enum KelajakNextKind implements WireEnum {
  takeTest('take_test'),
  careerLab('career_lab'),
  comeBack('come_back'),
  unknown('');

  const KelajakNextKind(this.wire);

  @override
  final String wire;

  static KelajakNextKind fromWire(Object? value) =>
      enumFromWire(values, value, unknown);
}

/// Career Lab faoliyati xulosasi.
enum KelajakVerdict implements WireEnum {
  liked('liked'),
  neutral('neutral'),
  disliked('disliked'),
  unknown('');

  const KelajakVerdict(this.wire);

  @override
  final String wire;

  static KelajakVerdict fromWire(Object? value) =>
      enumFromWire(values, value, unknown);
}
