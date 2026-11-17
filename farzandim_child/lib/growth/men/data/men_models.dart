// «Men» (I01–I09) ma'lumotlari: DON daftari, nishonlar, haftalik faollik,
// bildirishnoma sozlamalari va ma'lumotni o'chirish so'rovi
// (docs/MEN-DON-API.md, docs/MEN-NOTIFY-API.md).

import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/features/school/domain/school_json.dart';

/// Har 150 DON — yangi daraja (konsepsiya v2, 6-qaror). DON sarflanmaydi.
const kDonPerLevel = 150;

/// DON bo'yicha daraja: 0–149 → 1, 150–299 → 2, …
int donLevel(int don) => (don < 0 ? 0 : don) ~/ kDonPerLevel + 1;

/// Keyingi darajagacha qolgan DON.
int donToNextLevel(int don) =>
    donLevel(don) * kDonPerLevel - (don < 0 ? 0 : don);

/// Joriy daraja ichidagi ulush (0..1).
double donLevelProgress(int don) =>
    ((don < 0 ? 0 : don) % kDonPerLevel) / kDonPerLevel;

/// DON manbai.
enum DonKind implements WireEnum {
  learning('LEARNING'),
  steps('STEPS'),
  olympiad('OLYMPIAD'),
  book('BOOK'),
  video('VIDEO'),
  other('OTHER');

  const DonKind(this.wire);

  @override
  final String wire;

  static DonKind fromWire(Object? value) => enumFromWire(values, value, other);
}

/// DON daftaridagi yozuv.
class DonEntry {
  const DonEntry({
    required this.id,
    required this.kind,
    required this.amount,
    required this.at,
    this.pending = false,
    this.subject,
    this.title,
    this.relatedId,
  });

  static DonEntry? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = jsonNonEmpty(json['id']);
    final at = jsonInstant(json['at']);
    final amount = jsonInt(json['amount']);
    if (id == null || at == null || amount == null || amount == 0) return null;
    return DonEntry(
      id: id,
      kind: DonKind.fromWire(json['kind']),
      amount: amount,
      at: at,
      pending: json['status'] == 'PENDING',
      subject: Subject.fromName(jsonString(json['subject'])),
      title: jsonNonEmpty(json['title']),
      relatedId: jsonNonEmpty(json['relatedId']),
    );
  }

  final String id;
  final DonKind kind;
  final int amount;
  final DateTime at;
  final bool pending;
  final Subject? subject;
  final String? title;

  /// LEARNING — urinish (natija) id'si.
  final String? relatedId;
}

/// DON daftari sahifasi.
class DonLedgerPage {
  const DonLedgerPage({
    required this.balance,
    required this.pending,
    required this.items,
    this.nextCursor,
  });

  static DonLedgerPage fromJson(Object? json) {
    if (json is! Map) {
      return const DonLedgerPage(balance: 0, pending: 0, items: []);
    }
    return DonLedgerPage(
      balance: jsonInt(json['balance']) ?? 0,
      pending: jsonInt(json['pending']) ?? 0,
      items: jsonList(json['items'], DonEntry.tryFromJson),
      nextCursor: jsonNonEmpty(json['nextCursor']),
    );
  }

  /// Tasdiqlangan balans.
  final int balance;

  /// Kutilayotgan DON (hozircha server doim 0 beradi).
  final int pending;
  final List<DonEntry> items;
  final String? nextCursor;
}

/// Nishon (server katalogi: `streak_7`, `streak_30`, `first_book`, `olympian`,
/// `topic_master`, `thinker`).
class BadgeState {
  const BadgeState({required this.id, required this.earned, this.earnedAt});

  static BadgeState? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = jsonNonEmpty(json['id']);
    if (id == null) return null;
    return BadgeState(
      id: id,
      earned: json['earned'] == true,
      earnedAt: jsonInstant(json['earnedAt']),
    );
  }

  final String id;
  final bool earned;
  final DateTime? earnedAt;
}

/// Bir haftalik o'qish faolligi (Du–Ya, Toshkent).
class WeekActivity {
  const WeekActivity({
    required this.weekStart,
    required this.sessions,
    required this.minutes,
    required this.activeDays,
    required this.streak,
  });

  static WeekActivity? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final start = jsonDay(json['weekStart']);
    if (start == null) return null;
    int n(String key) => (jsonInt(json[key]) ?? 0).clamp(0, 1 << 30);
    return WeekActivity(
      weekStart: start,
      sessions: n('sessions'),
      minutes: n('minutes'),
      activeDays: n('activeDays'),
      streak: n('streak'),
    );
  }

  final DateTime weekStart;
  final int sessions;
  final int minutes;
  final int activeDays;
  final int streak;
}

/// `GET /learning/weekly` — avvalgi va joriy hafta.
class WeeklyActivity {
  const WeeklyActivity({this.previous, this.current, this.firstWeek = false});

  static WeeklyActivity fromJson(Object? json) {
    if (json is! Map) return const WeeklyActivity();
    final weeks = jsonList(json['weeks'], WeekActivity.tryFromJson)
      ..sort((a, b) => a.weekStart.compareTo(b.weekStart));
    return WeeklyActivity(
      previous: weeks.length > 1 ? weeks[weeks.length - 2] : null,
      current: weeks.isEmpty ? null : weeks.last,
      firstWeek: json['firstWeek'] == true,
    );
  }

  final WeekActivity? previous;
  final WeekActivity? current;

  /// Birinchi hafta — taqqoslash o'rniga «boshlang'ich nuqta».
  final bool firstWeek;
}

/// Bildirishnoma sozlamalari (bola qurilmasi uchun).
class NotificationPrefs {
  const NotificationPrefs({
    this.homeworkReminder = true,
    this.schoolAnnouncements = true,
    this.familyMessages = true,
    this.dailyReminder = true,
    this.dailyReminderTime = '18:00',
    this.hideText = true,
  });

  static NotificationPrefs fromJson(Object? json) {
    if (json is! Map) return const NotificationPrefs();
    bool flag(String key, bool fallback) =>
        json[key] is bool ? json[key] as bool : fallback;
    return NotificationPrefs(
      homeworkReminder: flag('homeworkReminder', true),
      schoolAnnouncements: flag('schoolAnnouncements', true),
      familyMessages: flag('familyMessages', true),
      dailyReminder: flag('dailyReminder', true),
      dailyReminderTime: jsonClock(json['dailyReminderTime']) ?? '18:00',
      hideText: flag('hideText', true),
    );
  }

  final bool homeworkReminder;
  final bool schoolAnnouncements;
  final bool familyMessages;
  final bool dailyReminder;
  final String dailyReminderTime;
  final bool hideText;

  NotificationPrefs copyWith({
    bool? homeworkReminder,
    bool? schoolAnnouncements,
    bool? familyMessages,
    bool? dailyReminder,
    String? dailyReminderTime,
    bool? hideText,
  }) => NotificationPrefs(
    homeworkReminder: homeworkReminder ?? this.homeworkReminder,
    schoolAnnouncements: schoolAnnouncements ?? this.schoolAnnouncements,
    familyMessages: familyMessages ?? this.familyMessages,
    dailyReminder: dailyReminder ?? this.dailyReminder,
    dailyReminderTime: dailyReminderTime ?? this.dailyReminderTime,
    hideText: hideText ?? this.hideText,
  );

  Map<String, Object> toJson() => {
    'homeworkReminder': homeworkReminder,
    'schoolAnnouncements': schoolAnnouncements,
    'familyMessages': familyMessages,
    'dailyReminder': dailyReminder,
    'dailyReminderTime': dailyReminderTime,
    'hideText': hideText,
  };
}

/// Ma'lumotni o'chirish so'rovi (I09).
class DeletionRequest {
  const DeletionRequest({required this.id, required this.createdAt});

  static DeletionRequest? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = jsonNonEmpty(json['id']);
    final createdAt = jsonInstant(json['createdAt']);
    if (id == null || createdAt == null || json['status'] == 'CLOSED') {
      return null;
    }
    return DeletionRequest(id: id, createdAt: createdAt);
  }

  final String id;
  final DateTime createdAt;
}
