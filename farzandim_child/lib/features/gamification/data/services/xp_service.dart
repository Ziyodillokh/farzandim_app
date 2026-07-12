// ─────────────────────────────────────────────────────────────────────
// XpService — XP/DON berish + Firestore atomik yangilash
// ─────────────────────────────────────────────────────────────────────
//
// Konkurs tugagach, kitob "o'qib tugatdim" bossanglar va h.k.
// Service shu yerda:
//   1. xp_events collection'iga event log INSERT
//   2. profile/gamification document'ini increment qiladi
//   3. Achievement check (yangi unlock bo'lsa qo'shadi)
//
// Hozir Firestore'da. Sprint 4.4 migration'da backend POST'ga o'tadi.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:farzandim_child/features/gamification/data/models/achievement.dart';
import 'package:farzandim_child/features/gamification/data/models/gamification_profile.dart';
import 'package:farzandim_child/features/gamification/data/models/xp_event.dart';

class XpService {
  XpService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _eventsRef({
    required String parentUid,
    required String childId,
  }) => _firestore
      .collection('users')
      .doc(parentUid)
      .collection('children')
      .doc(childId)
      .collection('xp_events');

  DocumentReference<Map<String, dynamic>> _profileRef({
    required String parentUid,
    required String childId,
  }) => _firestore
      .collection('users')
      .doc(parentUid)
      .collection('children')
      .doc(childId)
      .collection('profile')
      .doc('gamification');

  /// XP berish (asosiy API).
  ///
  /// Atomik: 1) event log, 2) profile increment, 3) achievement check.
  /// Agar shu `relatedId` bilan event allaqachon bor — dedup (qaytarmaslik).
  Future<XpAwardResult> awardXp({
    required String parentUid,
    required String childId,
    required XpEventType type,
    String? relatedId,
  }) async {
    // 1. Dedup tekshirish — bir konkurs uchun ikki marta XP bermaslik.
    if (relatedId != null) {
      final existing = await _eventsRef(parentUid: parentUid, childId: childId)
          .where('type', isEqualTo: type.firestoreCode)
          .where('relatedId', isEqualTo: relatedId)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        return const XpAwardResult.skippedDuplicate();
      }
    }

    final xp = type.xpReward;
    final don = type.donReward;

    // 2. Event log + profile increment — Firestore transaction.
    final eventsRef = _eventsRef(parentUid: parentUid, childId: childId);
    final profileRef = _profileRef(parentUid: parentUid, childId: childId);

    await _firestore.runTransaction((tx) async {
      final profileSnap = await tx.get(profileRef);
      final currentProfile = profileSnap.exists
          ? GamificationProfile.fromFirestore(profileSnap)
          : GamificationProfile.empty();

      tx.set(eventsRef.doc(), {
        'type': type.firestoreCode,
        'xpDelta': xp,
        'donDelta': don,
        'createdAt': FieldValue.serverTimestamp(),
        if (relatedId != null) 'relatedId': relatedId,
      });

      tx.set(profileRef, {
        'xp': currentProfile.xp + xp,
        'don': currentProfile.don + don,
        'streak': currentProfile.streak, // streak alohida funksiyada
        'unlockedAchievements': currentProfile.unlockedAchievements,
      }, SetOptions(merge: true));
    });

    return XpAwardResult.awarded(xp: xp, don: don);
  }

  /// Streak yangilash — kuniga bir marta App ochilganda chaqiriladi.
  /// Agar oxirgi aktiv kun kecha bo'lsa — streak +1, aks holda 1 ga reset.
  Future<int> updateStreakOnDailyOpen({
    required String parentUid,
    required String childId,
  }) async {
    final profileRef = _profileRef(parentUid: parentUid, childId: childId);

    return _firestore.runTransaction((tx) async {
      final snap = await tx.get(profileRef);
      final current = snap.exists
          ? GamificationProfile.fromFirestore(snap)
          : GamificationProfile.empty();

      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);

      int newStreak;
      if (current.lastActiveDate == null) {
        newStreak = 1;
      } else {
        final last = current.lastActiveDate!;
        final lastDate = DateTime(last.year, last.month, last.day);
        final diff = todayDate.difference(lastDate).inDays;
        if (diff == 0) {
          newStreak = current.streak; // bugun allaqachon — o'zgarmaydi
        } else if (diff == 1) {
          newStreak = current.streak + 1; // ketma-ket kun
        } else {
          newStreak = 1; // streak buzildi
        }
      }

      tx.set(profileRef, {
        'streak': newStreak,
        'lastActiveDate': Timestamp.fromDate(todayDate),
      }, SetOptions(merge: true));

      // Streak 7-7+ bo'lsa, haftalik bonus alohida `awardXp` orqali beriladi
      // (caller responsibility — caller streak qiymatini bilib chaqiradi).

      return newStreak;
    });
  }

  /// xp_events'dan AchievementCheckCtx qurish + achievement check qilish.
  /// Bu helper: caller ctx qurish o'rniga shunchaki chaqiradi.
  ///
  /// Hozir count'lar: bookCount, contestWins, contestParticipations,
  /// publishedContent. Streak — profile'dan. Helpful answers — feature
  /// hali yo'q, 0.
  Future<List<Achievement>> buildContextAndCheck({
    required String parentUid,
    required String childId,
  }) async {
    final profileRef = _profileRef(parentUid: parentUid, childId: childId);
    final eventsRef = _eventsRef(parentUid: parentUid, childId: childId);

    final results = await Future.wait([
      profileRef.get(),
      eventsRef
          .where('type', isEqualTo: XpEventType.bookCompleted.firestoreCode)
          .count()
          .get(),
      eventsRef
          .where('type', isEqualTo: XpEventType.contestWon.firestoreCode)
          .count()
          .get(),
      eventsRef
          .where('type', isEqualTo: XpEventType.contestJoined.firestoreCode)
          .count()
          .get(),
      eventsRef
          .where('type', isEqualTo: XpEventType.contentPublished.firestoreCode)
          .count()
          .get(),
    ]);

    final profileSnap = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final bookSnap = results[1] as AggregateQuerySnapshot;
    final contestWinSnap = results[2] as AggregateQuerySnapshot;
    final contestJoinSnap = results[3] as AggregateQuerySnapshot;
    final contentSnap = results[4] as AggregateQuerySnapshot;

    final profile = profileSnap.exists
        ? GamificationProfile.fromFirestore(profileSnap)
        : GamificationProfile.empty();

    final ctx = AchievementCheckCtx(
      bookCount: bookSnap.count ?? 0,
      streak: profile.streak,
      contestWins: contestWinSnap.count ?? 0,
      contestParticipations: contestJoinSnap.count ?? 0,
      publishedContentCount: contentSnap.count ?? 0,
      helpfulAnswers: 0, // hali tracking yo'q
    );

    return checkAndUnlockAchievements(
      parentUid: parentUid,
      childId: childId,
      ctx: ctx,
    );
  }

  /// Achievement check — XP yutgandan keyin chaqirish.
  /// Yangi unlock bo'lganlarini qaytaradi.
  Future<List<Achievement>> checkAndUnlockAchievements({
    required String parentUid,
    required String childId,
    required AchievementCheckCtx ctx,
  }) async {
    final profileRef = _profileRef(parentUid: parentUid, childId: childId);
    final snap = await profileRef.get();
    final current = snap.exists
        ? GamificationProfile.fromFirestore(snap)
        : GamificationProfile.empty();

    final newlyUnlocked = <Achievement>[];
    final updatedIds = [...current.unlockedAchievements];

    for (final achievement in Achievements.all) {
      if (current.unlockedAchievements.contains(achievement.id)) continue;
      if (achievement.checkUnlocked(ctx)) {
        newlyUnlocked.add(achievement);
        updatedIds.add(achievement.id);
      }
    }

    if (newlyUnlocked.isNotEmpty) {
      await profileRef.set({
        'unlockedAchievements': updatedIds,
      }, SetOptions(merge: true));
    }

    return newlyUnlocked;
  }
}

/// XP award natija — UI qaytadan qaror qabul qilish uchun.
class XpAwardResult {
  const XpAwardResult._({
    required this.awarded,
    required this.xp,
    required this.don,
  });

  const XpAwardResult.awarded({required int xp, required int don})
    : this._(awarded: true, xp: xp, don: don);

  const XpAwardResult.skippedDuplicate()
    : this._(awarded: false, xp: 0, don: 0);

  final bool awarded;
  final int xp;
  final int don;
}
