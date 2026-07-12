// ─────────────────────────────────────────────────────────────────────
// gamification_providers — Riverpod state grafi
// ─────────────────────────────────────────────────────────────────────
//
// `xpServiceProvider`              — singleton XpService instance
// `gamificationProfileProvider`    — bola profile (StreamProvider)
// `recentXpEventsProvider`         — oxirgi 20 ta XP event (Stream)
//
// MUHIM: har ikkala stream DARHOL default qiymat (empty profile / bo'sh
// ro'yxat) emit qiladi — shunda UI hech qachon "skeleton"da osilib qolmaydi.
// Firestore (dev-stub) ishlamasa yoki permission-denied bersa ham ekran
// default ma'lumot bilan ochiladi. Firestore javob bersa — ustiga yangilanadi.
// Sprint 5.x: backend `GET /children/:id/gamification`ga ko'chirish rejada.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/gamification/data/models/gamification_profile.dart';
import 'package:farzandim_child/features/gamification/data/models/xp_event.dart';
import 'package:farzandim_child/features/gamification/data/services/xp_service.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';

final xpServiceProvider = Provider<XpService>((ref) => XpService());

/// Backend'dagi HAQIQIY gamifikatsiya qiymatlari (don/streak/xp).
///
/// Qadamdan kelgan don (`har 1000 qadam = 5 don`) va streak shu yerda —
/// backend `ChildProfile` (Prisma), Firestore emas. Profil ekrani ochilganda
/// yangilanadi. Backend javob bermasa `null` → UI Firestore/preview'ga tushadi.
class BackendGamification {
  const BackendGamification({
    required this.xp,
    required this.don,
    required this.streak,
    required this.level,
    required this.status,
  });

  final int xp;
  final int don;
  final int streak;
  final int level;
  final String status;
}

final backendGamificationProvider =
    FutureProvider.autoDispose<BackendGamification?>((ref) async {
  final childId = ref.watch(pairingStateProvider).childId;
  if (childId == null || childId.isEmpty) return null;
  final dio = ref.watch(dioClientProvider);
  try {
    final res = await dio.get<Map<String, dynamic>>(
      '/children/$childId/profile',
    );
    final d = res.data ?? const <String, dynamic>{};
    return BackendGamification(
      xp: (d['xp'] as num?)?.toInt() ?? 0,
      don: (d['donBalance'] as num?)?.toInt() ?? 0,
      streak: (d['streakDays'] as num?)?.toInt() ?? 0,
      level: (d['level'] as num?)?.toInt() ?? 1,
      status: (d['status'] as String?) ?? 'Boshlovchi',
    );
  } on DioException catch (e) {
    debugPrint('backendGamification: ${e.response?.statusCode} ${e.message}');
    return null;
  } catch (e) {
    debugPrint('backendGamification: $e');
    return null;
  }
});

/// Bola gamifikatsiya profili — real-time stream.
/// Darhol `empty()` emit qiladi → UI bloklanmaydi. Firestore javobi kelsa
/// ustiga yoziladi; xato (permission-denied) bo'lsa default saqlanadi.
final gamificationProfileProvider = StreamProvider<GamificationProfile>((ref) {
  final pairing = ref.watch(pairingStateProvider);
  final parentUid = pairing.parentUid;
  final childId = pairing.childId;

  final controller = StreamController<GamificationProfile>();
  // 1) Darhol default — ekran shu zahoti ochiladi.
  controller.add(GamificationProfile.empty());

  if (parentUid == null || childId == null) {
    ref.onDispose(controller.close);
    return controller.stream;
  }

  // 2) Firestore'dan real-time yangilanish (kelса). Xato → e'tiborsiz,
  //    default qiymat saqlanadi.
  final sub = FirebaseFirestore.instance
      .collection('users')
      .doc(parentUid)
      .collection('children')
      .doc(childId)
      .collection('profile')
      .doc('gamification')
      .snapshots()
      .listen(
        (snap) {
          if (controller.isClosed) return;
          controller.add(
            snap.exists
                ? GamificationProfile.fromFirestore(snap)
                : GamificationProfile.empty(),
          );
        },
        onError: (Object error) {
          debugPrint(
            'gamificationProfile: Firestore error: $error (default saqlanadi)',
          );
        },
      );

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Oxirgi 20 ta XP event — Profile ekrandagi tarix bo'limi uchun.
/// Darhol bo'sh ro'yxat emit qiladi → UI bloklanmaydi.
final recentXpEventsProvider = StreamProvider<List<XpEvent>>((ref) {
  final pairing = ref.watch(pairingStateProvider);
  final parentUid = pairing.parentUid;
  final childId = pairing.childId;

  final controller = StreamController<List<XpEvent>>();
  controller.add(const <XpEvent>[]);

  if (parentUid == null || childId == null) {
    ref.onDispose(controller.close);
    return controller.stream;
  }

  final sub = FirebaseFirestore.instance
      .collection('users')
      .doc(parentUid)
      .collection('children')
      .doc(childId)
      .collection('xp_events')
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .listen(
        (snap) {
          if (controller.isClosed) return;
          controller.add(snap.docs.map(XpEvent.fromFirestore).toList());
        },
        onError: (Object error) {
          debugPrint(
            'recentXpEvents: Firestore error: $error (bo\'sh saqlanadi)',
          );
        },
      );

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });
  return controller.stream;
});
