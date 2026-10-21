// ─────────────────────────────────────────────────────────────────────
// SchoolAnnouncement — maktab e'lonlari (ota-ona ko'rinishi)
// ─────────────────────────────────────────────────────────────────────
//
// Backend: GET /api/parent/school/announcements?page=&limit= (limit ≤ 50),
// POST /announcements/:id/read. Yangisi oldin; faqat menga yuborilganlar.

import 'package:farzandim/core/utils/safe_parse.dart';
import 'package:flutter/foundation.dart';

/// Bir sahifadagi e'lonlar (backend standarti).
const int kAnnouncementsPageSize = 20;

/// Backend qabul qiladigan eng katta sahifa.
const int kMaxAnnouncementsPageSize = 50;

/// E'lon muhimligi.
enum AnnouncementPriority {
  normal,
  important,
  unknown;

  static AnnouncementPriority fromApi(Object? raw) => switch (raw) {
    'NORMAL' => normal,
    'IMPORTANT' => important,
    _ => unknown,
  };
}

@immutable
class SchoolAnnouncement {
  const SchoolAnnouncement({
    required this.id,
    required this.schoolId,
    required this.schoolName,
    required this.title,
    required this.body,
    required this.priority,
    this.sentAt,
    this.readAt,
  });

  factory SchoolAnnouncement.fromJson(Map<String, dynamic> json) =>
      SchoolAnnouncement(
        id: json.readString('id'),
        schoolId: json.readString('schoolId'),
        schoolName: json.readString('schoolName'),
        title: json.readString('title'),
        body: json.readString('body'),
        priority: AnnouncementPriority.fromApi(json['priority']),
        sentAt: json.readDateTime('sentAt'),
        readAt: json.readDateTime('readAt'),
      );

  final String id;
  final String schoolId;
  final String schoolName;
  final String title;
  final String body;
  final AnnouncementPriority priority;
  final DateTime? sentAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;
  bool get isImportant => priority == AnnouncementPriority.important;

  /// O'qilgan nusxa (optimistik belgilash) — avvalgi `readAt` saqlanadi.
  SchoolAnnouncement markedRead(DateTime at) => SchoolAnnouncement(
    id: id,
    schoolId: schoolId,
    schoolName: schoolName,
    title: title,
    body: body,
    priority: priority,
    sentAt: sentAt,
    readAt: readAt ?? at,
  );
}

/// E'lonlar sahifasi + o'qilmaganlar soni (server hisoblaydi).
@immutable
class AnnouncementPage {
  const AnnouncementPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.unread,
  });

  factory AnnouncementPage.fromJson(Map<String, dynamic> json) {
    final items = List<SchoolAnnouncement>.unmodifiable(
      parseListSafely(
        json.readList('items'),
        SchoolAnnouncement.fromJson,
        tag: 'SchoolAnnouncement',
      ).where((a) => a.id.isNotEmpty),
    );
    final paging = json.readMapOrNull('pagination') ?? const {};
    return AnnouncementPage(
      items: items,
      page: paging.readInt('page', fallback: 1),
      limit: paging.readInt('limit', fallback: kAnnouncementsPageSize),
      total: paging.readInt('total', fallback: items.length),
      totalPages: paging.readInt('totalPages', fallback: 1),
      unread: json.readInt('unread'),
    );
  }

  static const empty = AnnouncementPage(
    items: [],
    page: 1,
    limit: kAnnouncementsPageSize,
    total: 0,
    totalPages: 1,
    unread: 0,
  );

  final List<SchoolAnnouncement> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final int unread;

  /// Keyingi sahifa bormi.
  bool get hasMore => page < totalPages;
}
