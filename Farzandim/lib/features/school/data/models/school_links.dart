// ─────────────────────────────────────────────────────────────────────
// SchoolLinks — ota-onaning maktab bog'lanishlari (Parvoz School)
// ─────────────────────────────────────────────────────────────────────
//
// Backend: GET /api/parent/school/links. POST /link va
// PUT /students/:id/child ham shu shaklni qaytaradi. Faqat LINKED vasiy
// yozuvlari (ACTIVE maktablar), arxivdagi o'quvchilarsiz.
//
// Parse hech qachon otmaydi: noma'lum enum → `unknown`, buzuq yoki id'siz
// element tashlanadi.

import 'package:farzandim/core/utils/extensions.dart';
import 'package:farzandim/core/utils/safe_parse.dart';
import 'package:flutter/foundation.dart';

/// Logo data URI uchun yuqori chegara (backend ≈350 KB beradi).
const int kMaxSchoolLogoChars = 1024 * 1024;

/// `data:image/...;base64,...` → baytlar; yo'q, rasm emas yoki buzuq → null.
Uint8List? decodeSchoolLogo(String? dataUri) {
  if (dataUri == null ||
      dataUri.length > kMaxSchoolLogoChars ||
      !dataUri.startsWith('data:image/')) {
    return null;
  }
  try {
    final bytes = UriData.parse(dataUri).contentAsBytes();
    return bytes.isEmpty ? null : bytes;
  } catch (_) {
    // Buzuq URI yoki base64 — logo o'rniga harf-avatar ko'rsatiladi.
    return null;
  }
}

/// Vasiyning o'quvchiga qarindoshligi.
enum GuardianRelation {
  mother,
  father,
  grandparent,
  other,
  unknown;

  static GuardianRelation fromApi(Object? raw) => switch (raw) {
    'MOTHER' => mother,
    'FATHER' => father,
    'GRANDPARENT' => grandparent,
    'OTHER' => other,
    _ => unknown,
  };
}

/// O'quvchi kimning farzandiga moslangan: men (ME), oilaning boshqa a'zosi
/// (OTHER) yoki hali hech kim (NONE).
enum LinkedBy {
  me,
  other,
  none,
  unknown;

  static LinkedBy fromApi(Object? raw) => switch (raw) {
    'ME' => me,
    'OTHER' => other,
    'NONE' => none,
    _ => unknown,
  };
}

/// Maktab (ro'yxat kartasi uchun qisqa ma'lumot).
@immutable
class SchoolInfo {
  const SchoolInfo({
    required this.id,
    required this.name,
    required this.shortName,
    required this.city,
    this.logo,
    this.logoBytes,
  });

  factory SchoolInfo.fromJson(Map<String, dynamic> json) {
    final logo = json.readStringOrNull('logo');
    return SchoolInfo(
      id: json.readString('id'),
      name: json.readString('name'),
      shortName: json.readString('shortName'),
      city: json.readString('city'),
      logo: logo,
      logoBytes: decodeSchoolLogo(logo),
    );
  }

  final String id;
  final String name;
  final String shortName;
  final String city;

  /// Xom data URI — tenglik shu bo'yicha (baytlar emas).
  final String? logo;

  /// Bir marta dekodlangan logo: `Image.memory(bytes, cacheWidth: ...)`.
  final Uint8List? logoBytes;

  /// Qisqa nom bo'lsa o'shani, aks holda to'liq nom.
  String get displayName => shortName.isNotEmpty ? shortName : name;

  @override
  bool operator ==(Object other) =>
      other is SchoolInfo &&
      other.id == id &&
      other.name == name &&
      other.shortName == shortName &&
      other.city == city &&
      other.logo == logo;

  @override
  int get hashCode => Object.hash(id, name, shortName, city, logo);
}

/// Vasiy yozuviga bog'langan o'quvchi.
@immutable
class LinkedStudent {
  const LinkedStudent({
    required this.id,
    required this.fullName,
    required this.className,
    required this.linkedBy,
    this.childId,
  });

  factory LinkedStudent.fromJson(Map<String, dynamic> json) => LinkedStudent(
    id: json.readString('id'),
    fullName: json.readString('fullName'),
    className: json.readString('className'),
    childId: json.readStringOrNull('childId'),
    linkedBy: LinkedBy.fromApi(json['linkedBy']),
  );

  final String id;
  final String fullName;
  final String className;

  /// Backend faqat MENING farzandimga moslanganda beradi.
  final String? childId;
  final LinkedBy linkedBy;

  /// Mening farzandlarimdan biriga moslangan.
  bool get isMatchedToMine => childId != null;

  /// Hech kimga moslanmagan — moslash varag'ida taklif qilinadi.
  bool get needsMatch => linkedBy == LinkedBy.none && childId == null;

  /// Oilaning boshqa a'zosi moslagan — faqat o'qish uchun ko'rsatiladi.
  bool get isMatchedByOther => linkedBy == LinkedBy.other;

  @override
  bool operator ==(Object other) =>
      other is LinkedStudent &&
      other.id == id &&
      other.fullName == fullName &&
      other.className == className &&
      other.childId == childId &&
      other.linkedBy == linkedBy;

  @override
  int get hashCode => Object.hash(id, fullName, className, childId, linkedBy);
}

/// Bitta maktab bog'lanishi (vasiy yozuvi) va uning o'quvchilari.
@immutable
class SchoolLink {
  const SchoolLink({
    required this.guardianId,
    required this.fullName,
    required this.relation,
    required this.school,
    required this.students,
    this.linkedAt,
  });

  factory SchoolLink.fromJson(Map<String, dynamic> json) => SchoolLink(
    guardianId: json.readString('guardianId'),
    fullName: json.readString('fullName'),
    relation: GuardianRelation.fromApi(json['relation']),
    linkedAt: json.readDateTime('linkedAt'),
    school: SchoolInfo.fromJson(json.readMapOrNull('school') ?? const {}),
    students: List.unmodifiable(
      parseListSafely(
        json.readList('students'),
        LinkedStudent.fromJson,
        tag: 'LinkedStudent',
      ).where((s) => s.id.isNotEmpty),
    ),
  );

  /// Aloqani uzish shu id bilan (`DELETE /links/:guardianId`).
  final String guardianId;

  /// Maktab yozgan vasiy ismi.
  final String fullName;
  final GuardianRelation relation;
  final DateTime? linkedAt;
  final SchoolInfo school;
  final List<LinkedStudent> students;

  @override
  bool operator ==(Object other) =>
      other is SchoolLink &&
      other.guardianId == guardianId &&
      other.fullName == fullName &&
      other.relation == relation &&
      other.linkedAt == linkedAt &&
      other.school == school &&
      listEquals(other.students, students);

  @override
  int get hashCode => Object.hash(
    guardianId,
    fullName,
    relation,
    linkedAt,
    school,
    Object.hashAll(students),
  );
}

/// Ota-onaning farzandi (moslash ro'yxati uchun; eng eskisi birinchi).
@immutable
class ChildRef {
  const ChildRef({required this.id, required this.name});

  factory ChildRef.fromJson(Map<String, dynamic> json) =>
      ChildRef(id: json.readString('id'), name: json.readString('name'));

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is ChildRef && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// `/parent/school/links` javobi + bo'lim mavjudligi.
@immutable
class SchoolLinks {
  const SchoolLinks({
    required this.links,
    required this.children,
    this.available = true,
  });

  factory SchoolLinks.fromJson(Map<String, dynamic> json) => SchoolLinks(
    links: List.unmodifiable(
      parseListSafely(
        json.readList('links'),
        SchoolLink.fromJson,
        tag: 'SchoolLink',
      ).where((l) => l.guardianId.isNotEmpty),
    ),
    children: List.unmodifiable(
      parseListSafely(
        json.readList('children'),
        ChildRef.fromJson,
        tag: 'ChildRef',
      ).where((c) => c.id.isNotEmpty),
    ),
  );

  /// Bog'lanish yo'q, lekin bo'lim mavjud.
  static const empty = SchoolLinks(links: [], children: []);

  /// Backend bu bo'limni bermaydi (404, `code`siz) — maktab UI yashiriladi.
  static const unavailable = SchoolLinks(
    links: [],
    children: [],
    available: false,
  );

  final List<SchoolLink> links;
  final List<ChildRef> children;

  /// `false` — backend'da maktab bo'limi yo'q (hali deploy qilinmagan).
  final bool available;

  bool get hasLinks => links.isNotEmpty;

  /// Barcha o'quvchilar; bir nechta vasiy yozuvida takrorlansa — bir marta.
  List<LinkedStudent> get students {
    final seen = <String>{};
    return List.unmodifiable([
      for (final link in links)
        for (final student in link.students)
          if (seen.add(student.id)) student,
    ]);
  }

  /// Shu farzandga moslangan o'quvchi (yo'q → `null`).
  LinkedStudent? studentForChild(String childId) =>
      students.firstWhereOrNull((s) => s.childId == childId);

  /// Hali hech kimga moslanmagan o'quvchilar.
  List<LinkedStudent> get unmatchedStudents =>
      List.unmodifiable(students.where((s) => s.needsMatch));

  /// O'quvchi qaysi maktab bog'lanishida (birinchisi; yo'q → `null`).
  SchoolLink? linkOfStudent(String studentId) =>
      links.firstWhereOrNull((l) => l.students.any((s) => s.id == studentId));

  @override
  bool operator ==(Object other) =>
      other is SchoolLinks &&
      other.available == available &&
      listEquals(other.links, links) &&
      listEquals(other.children, children);

  @override
  int get hashCode =>
      Object.hash(available, Object.hashAll(links), Object.hashAll(children));
}
