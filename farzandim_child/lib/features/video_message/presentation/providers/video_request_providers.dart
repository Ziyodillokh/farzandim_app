// ─────────────────────────────────────────────────────────────────────
// video_request_providers — Riverpod stream + repository providerlari
// ─────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/features/video_message/data/models/video_request.dart';
import 'package:farzandim_child/features/video_message/data/repositories/video_request_repository.dart';

final videoRequestRepositoryProvider =
    Provider<VideoRequestRepository?>((ref) {
  final pairing = ref.watch(pairingStateProvider);
  if (pairing.parentUid == null || pairing.childId == null) return null;

  return VideoRequestRepository(
    firestore: FirebaseFirestore.instance,
    parentUid: pairing.parentUid!,
    childId: pairing.childId!,
  );
});

/// Aktiv pending so'rov stream — null bo'lsa banner ko'rinmaydi.
final activeVideoRequestProvider = StreamProvider<VideoRequest?>((ref) {
  final repo = ref.watch(videoRequestRepositoryProvider);
  if (repo == null) return Stream<VideoRequest?>.value(null);
  return repo.streamActiveRequest();
});
