// ─────────────────────────────────────────────────────────────────────
// gamification_providers — Riverpod state grafi
// ─────────────────────────────────────────────────────────────────────
//
// `xpServiceProvider`              — singleton XpService instance
// `gamificationProfileProvider`    — bola profile (StreamProvider)
// `recentXpEventsProvider`         — oxirgi 20 ta XP event (Stream)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/features/gamification/data/models/gamification_profile.dart';
import 'package:farzandim_child/features/gamification/data/models/xp_event.dart';
import 'package:farzandim_child/features/gamification/data/services/xp_service.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';

final xpServiceProvider = Provider<XpService>((ref) => XpService());

/// Bola gamifikatsiya profili — real-time stream.
/// Pair bo'lmagan paytda hech narsa qaytarmaydi.
final gamificationProfileProvider =
    StreamProvider<GamificationProfile>((ref) {
  final pairing = ref.watch(pairingStateProvider);
  final parentUid = pairing.parentUid;
  final childId = pairing.childId;
  if (parentUid == null || childId == null) {
    return Stream.value(GamificationProfile.empty());
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(parentUid)
      .collection('children')
      .doc(childId)
      .collection('profile')
      .doc('gamification')
      .snapshots()
      .map((snap) {
    if (!snap.exists) return GamificationProfile.empty();
    return GamificationProfile.fromFirestore(snap);
  });
});

/// Oxirgi 20 ta XP event — Profile ekrandagi tarix bo'limi uchun.
final recentXpEventsProvider = StreamProvider<List<XpEvent>>((ref) {
  final pairing = ref.watch(pairingStateProvider);
  final parentUid = pairing.parentUid;
  final childId = pairing.childId;
  if (parentUid == null || childId == null) {
    return Stream.value(const <XpEvent>[]);
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(parentUid)
      .collection('children')
      .doc(childId)
      .collection('xp_events')
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((snap) => snap.docs.map(XpEvent.fromFirestore).toList());
});
