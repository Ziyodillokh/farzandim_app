// ─────────────────────────────────────────────────────────────────────
// SchoolConnect — "Maktab bilan bog'lanish": kontaktlar va yozishmalar
// ─────────────────────────────────────────────────────────────────────
//
// Backend: GET /parent/school/contacts?studentId=, GET|POST /threads,
// GET /threads/:id, POST /threads/:id/messages, POST /threads/:id/read.
// Yozishma = ota-ona + xodim + o'quvchi (chat kabi; mavzu har xabarda).
// Xabarni faqat qabul qiluvchi xodim o'qiydi.

import 'package:farzandim/core/utils/safe_parse.dart';
import 'package:flutter/foundation.dart';

/// Ota-ona xabari uzunligi (backend `PARENT_MESSAGE_MAX`).
const int kParentMessageMax = 1000;

/// Xodim roli (ota-onaga ko'rinadigan).
enum StaffRole {
  director,
  admin,
  homeroom,
  psychologist,
  teacher,
  unknown;

  static StaffRole fromApi(Object? raw) => switch (raw) {
    'DIRECTOR' => director,
    'ADMIN' => admin,
    'HOMEROOM' => homeroom,
    'PSYCHOLOGIST' => psychologist,
    'TEACHER' => teacher,
    _ => unknown,
  };

  /// `school.connect.role.<name>`.
  String get labelKey => 'school.connect.role.$name';
}

/// Kontakt guruhi (ro'yxat bo'limlari tartibi bilan).
enum ContactGroup {
  classTeacher,
  leadership,
  support,
  subject;

  static ContactGroup fromApi(Object? raw) => switch (raw) {
    'CLASS' => classTeacher,
    'LEADERSHIP' => leadership,
    'SUPPORT' => support,
    _ => subject,
  };

  String get labelKey => 'school.connect.group.$name';
}

/// Shablon mavzusi (backend `PARENT_TOPICS` bilan bir xil).
enum ContactTopic {
  absence('ABSENCE'),
  earlyPickup('EARLY_PICKUP'),
  homework('HOMEWORK'),
  progress('PROGRESS'),
  meeting('MEETING'),
  behavior('BEHAVIOR'),
  wellbeing('WELLBEING'),
  bullying('BULLYING'),
  advice('ADVICE'),
  payment('PAYMENT'),
  document('DOCUMENT'),
  suggestion('SUGGESTION'),
  problem('PROBLEM'),
  thanks('THANKS'),
  extraLesson('EXTRA_LESSON'),
  other('OTHER');

  const ContactTopic(this.api);

  final String api;

  static ContactTopic? fromApi(Object? raw) {
    for (final t in values) {
      if (t.api == raw) return t;
    }
    return null;
  }

  /// `school.connect.topic.<name>.title|body|hint`.
  String get titleKey => 'school.connect.topic.$name.title';
  String get bodyKey => 'school.connect.topic.$name.body';
  String get hintKey => 'school.connect.topic.$name.hint';
}

/// Rolga mos shablonlar (eng ko'p kerakligi oldin). Ota-ona har birini
/// tahrirlab yuboradi; "O'zim yozaman" — `other`.
List<ContactTopic> topicsFor(StaffRole role) => switch (role) {
  StaffRole.homeroom => const [
    ContactTopic.absence,
    ContactTopic.earlyPickup,
    ContactTopic.homework,
    ContactTopic.progress,
    ContactTopic.meeting,
    ContactTopic.behavior,
  ],
  StaffRole.teacher => const [
    ContactTopic.progress,
    ContactTopic.homework,
    ContactTopic.extraLesson,
    ContactTopic.meeting,
  ],
  StaffRole.director => const [
    ContactTopic.meeting,
    ContactTopic.suggestion,
    ContactTopic.problem,
    ContactTopic.thanks,
  ],
  StaffRole.admin => const [
    ContactTopic.payment,
    ContactTopic.document,
    ContactTopic.meeting,
    ContactTopic.problem,
  ],
  StaffRole.psychologist => const [
    ContactTopic.wellbeing,
    ContactTopic.bullying,
    ContactTopic.advice,
    ContactTopic.meeting,
  ],
  StaffRole.unknown => const [ContactTopic.meeting],
};

/// Kontaktlar so'ralgan o'quvchi.
@immutable
class ConnectStudent {
  const ConnectStudent({
    required this.id,
    required this.name,
    required this.className,
    this.schoolName = '',
  });

  factory ConnectStudent.fromJson(Map<String, dynamic> json) => ConnectStudent(
    id: json.readString('id'),
    name: json.readString('name'),
    className: json.readString('className'),
    schoolName: json.readString('schoolName'),
  );

  final String id;
  final String name;
  final String className;
  final String schoolName;
}

/// Maktab xodimi (ota-onaga ko'rinadigan qism; telefon yo'q).
@immutable
class SchoolContact {
  const SchoolContact({
    required this.staffId,
    required this.fullName,
    required this.role,
    required this.position,
    required this.group,
    this.threadId,
    this.unread = 0,
    this.lastMessageAt,
  });

  factory SchoolContact.fromJson(Map<String, dynamic> json) => SchoolContact(
    staffId: json.readString('staffId'),
    fullName: json.readString('fullName'),
    role: StaffRole.fromApi(json['role']),
    position: json.readString('position'),
    group: ContactGroup.fromApi(json['group']),
    threadId: json.readStringOrNull('threadId'),
    unread: json.readInt('unread'),
    lastMessageAt: json.readDateTime('lastMessageAt'),
  );

  final String staffId;
  final String fullName;
  final StaffRole role;

  /// Lavozim ("Matematika o'qituvchisi"); bo'sh bo'lishi mumkin.
  final String position;
  final ContactGroup group;
  final String? threadId;
  final int unread;
  final DateTime? lastMessageAt;

  /// Psixolog — suhbat maxfiy (UI'da qulf belgisi).
  bool get isConfidential => role == StaffRole.psychologist;
}

@immutable
class SchoolContacts {
  const SchoolContacts({required this.student, required this.contacts});

  factory SchoolContacts.fromJson(Map<String, dynamic> json) => SchoolContacts(
    student: ConnectStudent.fromJson(json.readMapOrNull('student') ?? const {}),
    contacts: List.unmodifiable(
      parseListSafely(
        json.readList('contacts'),
        SchoolContact.fromJson,
        tag: 'SchoolContact',
      ).where((c) => c.staffId.isNotEmpty),
    ),
  );

  final ConnectStudent student;
  final List<SchoolContact> contacts;

  List<SchoolContact> inGroup(ContactGroup group) =>
      contacts.where((c) => c.group == group).toList(growable: false);
}

/// Xabar muallifi.
enum MessageAuthor {
  parent,
  staff;

  static MessageAuthor fromApi(Object? raw) => raw == 'STAFF' ? staff : parent;
}

@immutable
class ThreadMessage {
  const ThreadMessage({
    required this.id,
    required this.author,
    required this.body,
    this.topic,
    this.createdAt,
    this.seen = false,
  });

  factory ThreadMessage.fromJson(Map<String, dynamic> json) => ThreadMessage(
    id: json.readString('id'),
    author: MessageAuthor.fromApi(json['author']),
    body: json.readString('body'),
    topic: ContactTopic.fromApi(json['topic']),
    createdAt: json.readDateTime('createdAt'),
    seen: json.readBool('seen'),
  );

  final String id;
  final MessageAuthor author;
  final String body;
  final ContactTopic? topic;
  final DateTime? createdAt;

  /// Qarshi tomon o'qigan.
  final bool seen;

  bool get mine => author == MessageAuthor.parent;
}

/// Yozishma (ro'yxat qatori yoki to'liq — `messages` bilan).
@immutable
class SchoolThread {
  const SchoolThread({
    required this.id,
    required this.resolved,
    required this.schoolName,
    required this.staff,
    required this.student,
    required this.lastFromStaff,
    required this.available,
    this.lastMessageAt,
    this.unread = 0,
    this.preview,
    this.messages = const [],
  });

  factory SchoolThread.fromJson(Map<String, dynamic> json) {
    final staff = json.readMapOrNull('staff') ?? const {};
    final preview = json.readMapOrNull('preview');
    return SchoolThread(
      id: json.readString('id'),
      resolved: json['status'] == 'RESOLVED',
      schoolName: json.readString('schoolName'),
      staff: SchoolContact(
        staffId: staff.readString('id'),
        fullName: staff.readString('fullName'),
        role: StaffRole.fromApi(staff['role']),
        position: staff.readString('position'),
        group: ContactGroup.subject,
      ),
      student: ConnectStudent.fromJson(
        json.readMapOrNull('student') ?? const {},
      ),
      lastFromStaff: json['lastAuthor'] == 'STAFF',
      available: json['available'] != false,
      lastMessageAt: json.readDateTime('lastMessageAt'),
      unread: json.readInt('unread'),
      preview: preview?.readString('text'),
      messages: List.unmodifiable(
        parseListSafely(
          json.readList('messages'),
          ThreadMessage.fromJson,
          tag: 'ThreadMessage',
        ),
      ),
    );
  }

  final String id;
  final bool resolved;
  final String schoolName;
  final SchoolContact staff;
  final ConnectStudent student;

  /// Oxirgi xabar xodimdan (ota-ona javob kutmayapti).
  final bool lastFromStaff;

  /// Xodim hali kontakt (faol, sinf doirasida) — yozish mumkin.
  final bool available;
  final DateTime? lastMessageAt;
  final int unread;
  final String? preview;
  final List<ThreadMessage> messages;
}

@immutable
class SchoolThreads {
  const SchoolThreads({required this.items, required this.unread});

  factory SchoolThreads.fromJson(Map<String, dynamic> json) => SchoolThreads(
    items: List.unmodifiable(
      parseListSafely(
        json.readList('items'),
        SchoolThread.fromJson,
        tag: 'SchoolThread',
      ).where((t) => t.id.isNotEmpty),
    ),
    unread: json.readInt('unread'),
  );

  static const empty = SchoolThreads(items: [], unread: 0);

  final List<SchoolThread> items;
  final int unread;
}
