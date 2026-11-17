// Growth v5 ekran testlari uchun provider almashtirishlar: tarmoqsiz o'qish
// manbai, juftlangan bola, DON/seriya, maktab va Kelajak.

import 'package:farzandim_child/growth/men/lock/app_lock.dart';
import 'package:farzandim_child/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_providers.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:farzandim_child/features/pairing/data/models/pairing_state.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/growth/oqish/topics/topics_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/learning/fake_learning_repository.dart';
import 'package:farzandim_child/features/account/presentation/providers/child_repository_provider.dart';
import 'package:farzandim_child/growth/bugun/widgets/contact_tiles.dart';
import '../features/school/fake_school_repository.dart';

/// Testlardagi «bugun» — payshanba ertalab (B01 salomlashuvi: «Xayrli tong»).
final kG5Now = DateTime(2026, 11, 5, 9, 30);

List<Override> g5Overrides({
  required FakeLearningRepository learning,
  String? childName = 'Aziza Karimova',
  int unread = 0,
  BackendGamification gamification = const BackendGamification(
    xp: 900,
    don: 480,
    streak: 7,
    level: 4,
    status: 'active',
    unlockedAchievements: [],
  ),
  FakeSchoolRepository? school,
  String? schoolAccount,
  TopicsRepository? topics,
  PairingNotifier Function()? pairing,
}) => [
  if (topics != null) topicsRepositoryProvider.overrideWithValue(topics),
  learningRepositoryProvider.overrideWithValue(learning),
  learningClockProvider.overrideWithValue(() => kG5Now),
  pairingStateProvider.overrideWith(
    (ref) => pairing?.call() ?? FakeG5Pairing(childName),
  ),
  backendGamificationProvider.overrideWith((ref) => Stream.value(gamification)),
  gamificationProfileProvider.overrideWith((ref) => const Stream.empty()),
  unreadNotificationsCountProvider.overrideWithValue(AsyncData(unread)),
  schoolRepositoryProvider.overrideWithValue(school ?? FakeSchoolRepository()),
  schoolAccountProvider.overrideWithValue(schoolAccount),
  kelajakAvailableProvider.overrideWith((ref) => false),
  appLockProvider.overrideWithValue(AppLock(MemoryLockStore())),
  parentChatUnreadProvider.overrideWithValue(0),
  parentNameProvider.overrideWith((ref) async => null),
];

class FakeG5Pairing extends StateNotifier<AppPairingState>
    implements PairingNotifier {
  FakeG5Pairing(String? childName)
    : super(
        AppPairingState(
          status: PairingStatus.paired,
          parentUid: 'parent-1',
          childId: 'child-1',
          childName: childName,
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Ilova qulfi xotirasi (testda — xotirada).
class MemoryLockStore implements LockStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String? value) async =>
      value == null ? values.remove(key) : values[key] = value;
}
