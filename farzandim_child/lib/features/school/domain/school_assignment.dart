// Maktab topshiriqlari (`GET /child/school/assignments`): sinf rahbari
// bergan Parvoz materiallari — fan testi, audiokitob yoki video. Test
// topshirig'i shu fandan kunlik test yakunlanganda "bajarildi" bo'ladi.

import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/features/school/domain/school_json.dart';

/// Material turi.
enum SchoolAssignmentKind implements WireEnum {
  test('TEST'),
  audiobook('AUDIOBOOK'),
  video('VIDEO'),
  unknown('');

  const SchoolAssignmentKind(this.wire);

  @override
  final String wire;

  static SchoolAssignmentKind fromWire(Object? value) =>
      enumFromWire(values, value, unknown);
}

const _audiobookPrefix = 'audiobook:';

/// Bitta maktab topshirig'i.
class SchoolAssignment {
  const SchoolAssignment({
    required this.id,
    required this.kind,
    required this.materialId,
    required this.title,
    required this.note,
    required this.isOverdue,
    this.subject,
    this.dueDate,
    this.isDone,
  });

  static SchoolAssignment? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = jsonNonEmpty(json['id']);
    if (id == null) return null;
    final subject = jsonString(json['subject']);
    final done = json['done'];
    return SchoolAssignment(
      id: id,
      kind: SchoolAssignmentKind.fromWire(json['kind']),
      materialId: jsonText(json['materialId']),
      title: jsonText(json['title']),
      note: jsonText(json['note']),
      isOverdue: json['overdue'] == true,
      // Server fanni KATTA harfda yuboradi ("MATH") — ilova enum'i kichik.
      subject: subject == null ? null : Subject.fromName(subject.toLowerCase()),
      dueDate: jsonDay(json['dueDate']),
      isDone: done is bool ? done : null,
    );
  }

  final String id;
  final SchoolAssignmentKind kind;

  /// `"test:MATH"` yoki `"audiobook:<uuid>"`.
  final String materialId;

  /// Server nomi (faqat o'zbekcha) — test nomi ilovada tarjima qilinadi.
  final String title;

  /// O'qituvchi izohi (bo'sh bo'lishi mumkin).
  final String note;

  /// Muddati o'tgan (server 7 kungacha ko'rsatadi).
  final bool isOverdue;

  /// Test fani — boshqa turda yoki noma'lum fanda `null`.
  final Subject? subject;

  /// Topshirish sanasi (vaqtsiz).
  final DateTime? dueDate;

  /// Faqat TEST uchun: bajarilganmi (boshqa turda `null`).
  final bool? isDone;

  /// Audiokitob id'si (`audiobook:<uuid>`) — boshqa material uchun `null`.
  String? get audiobookId {
    if (!materialId.startsWith(_audiobookPrefix)) return null;
    final id = materialId.substring(_audiobookPrefix.length);
    return id.isEmpty ? null : id;
  }

  /// Hali bajarilmagan. Audiokitob / videoda server bajarilganini bilmaydi
  /// (`isDone == null`) — ular muddati o'tib ro'yxatdan tushguncha shu holatda.
  bool get isPending => isDone != true;
}

/// Hali bajarilmagan test topshiriqlari fanlari ("Bugungi testlar"
/// plitkalaridagi "Maktab topshirig'i" belgisi uchun).
Set<Subject> pendingTestSubjects(Iterable<SchoolAssignment> assignments) => {
  for (final a in assignments)
    if (a.kind == SchoolAssignmentKind.test && a.isPending) ?a.subject,
};
