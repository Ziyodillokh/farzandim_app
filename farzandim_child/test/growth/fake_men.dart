// «Men» (I01–I09) testlari va skrinshotlari uchun soxta manbalar.

import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/growth/men/data/men_device.dart';
import 'package:farzandim_child/growth/men/data/men_models.dart';
import 'package:farzandim_child/growth/men/data/men_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FakeMenRepository implements MenRepository {
  FakeMenRepository({
    this.ledger,
    this.badges = const [],
    this.weekly,
    this.prefs = const NotificationPrefs(),
    this.consent,
    this.failSave = false,
  });

  DonLedgerPage? ledger;
  List<BadgeState> badges;
  WeeklyActivity? weekly;
  NotificationPrefs prefs;
  DateTime? consent;
  bool failSave;
  DeletionRequest? deletion;

  final saved = <NotificationPrefs>[];

  @override
  Future<DonLedgerPage> loadLedger({String? cursor}) async =>
      ledger ?? (throw const MenUnavailable());

  @override
  Future<List<BadgeState>> loadBadges() async => badges;

  @override
  Future<WeeklyActivity> loadWeekly() async =>
      weekly ?? (throw const MenUnavailable());

  @override
  Future<NotificationPrefs> loadNotificationPrefs() async => prefs;

  @override
  Future<NotificationPrefs> saveNotificationPrefs(
    NotificationPrefs next,
  ) async {
    if (failSave) throw StateError('offline');
    saved.add(next);
    prefs = next;
    return next;
  }

  @override
  Future<DeletionRequest?> latestDeletionRequest() async => deletion;

  @override
  Future<DeletionRequest> requestDeletion() async => deletion = DeletionRequest(
    id: 'del-1',
    createdAt: DateTime(2026, 11, 5, 9, 40),
  );

  @override
  Future<DateTime?> consentDate() async => consent;
}

class FakePermissionsSource implements MyPermissionsSource {
  const FakePermissionsSource(this.value);

  final MyPermissions value;

  @override
  Future<MyPermissions> read() async => value;
}

const kMyPermissions = MyPermissions(
  location: PermissionState.on,
  steps: PermissionState.off,
  device: PermissionState.on,
  screenTime: PermissionState.unavailable,
);

List<Override> menOverrides(FakeMenRepository men) => [
  menRepositoryProvider.overrideWithValue(men),
  myPermissionsSourceProvider.overrideWithValue(
    const FakePermissionsSource(kMyPermissions),
  ),
  thisDeviceNameProvider.overrideWith((ref) async => 'Galaxy A15'),
];

FakeMenRepository kFakeMen() => FakeMenRepository(
  ledger: DonLedgerPage(
    balance: 480,
    pending: 0,
    items: [
      DonEntry(
        id: 'e1',
        kind: DonKind.learning,
        amount: 16,
        at: DateTime(2026, 11, 5, 9, 12),
        subject: Subject.math,
        relatedId: 'att-1',
      ),
      DonEntry(
        id: 'e2',
        kind: DonKind.learning,
        amount: 14,
        at: DateTime(2026, 11, 5, 8, 40),
        subject: Subject.english,
        relatedId: 'att-2',
      ),
      DonEntry(
        id: 'steps:2026-11-04',
        kind: DonKind.steps,
        amount: 35,
        at: DateTime(2026, 11, 4, 21),
      ),
      DonEntry(
        id: 'e4',
        kind: DonKind.book,
        amount: 50,
        at: DateTime(2026, 11, 3, 18, 5),
        title: 'Oʻrmon sirlari',
      ),
    ],
  ),
  badges: const [
    BadgeState(id: 'streak_7', earned: true),
    BadgeState(id: 'first_book', earned: true),
    BadgeState(id: 'topic_master', earned: true),
    BadgeState(id: 'olympian', earned: false),
    BadgeState(id: 'streak_30', earned: false),
    BadgeState(id: 'thinker', earned: false),
  ],
  weekly: WeeklyActivity(
    previous: WeekActivity(
      weekStart: DateTime(2026, 10, 26),
      sessions: 5,
      minutes: 52,
      activeDays: 4,
      streak: 4,
    ),
    current: WeekActivity(
      weekStart: DateTime(2026, 11, 2),
      sessions: 7,
      minutes: 68,
      activeDays: 4,
      streak: 7,
    ),
  ),
  consent: DateTime(2026, 9, 3, 10),
);
