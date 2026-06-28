// ─────────────────────────────────────────────────────────────────────
// pair_request_providers — Backend WS + REST
// ─────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/pair_requests/data/models/pair_request.dart';
import 'package:farzandim/features/pair_requests/data/repositories/backend_pair_request_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bola uchun pending pair requests — Backend fetch + WS refresh.
final pendingPairRequestsProvider =
    StreamProvider.family<List<PairRequest>, String>((ref, childId) async* {
      final auth = ref.watch(backendAuthProvider);
      if (auth is! AuthAuthenticated) {
        yield const <PairRequest>[];
        return;
      }
      final repo = ref.watch(backendPairRequestRepositoryProvider);

      Future<List<PairRequest>> fetch() => repo.getPendingRequests(childId);

      yield await fetch();

      final controller = StreamController<List<PairRequest>>();
      Future<void> refresh(dynamic data) async {
        if (data is Map && data['childId'] != childId) return;
        try {
          final list = await fetch();
          if (!controller.isClosed) controller.add(list);
        } catch (_) {
          // WS-triggered refresh xatosi — oxirgi ro'yxat saqlanadi (EH-09:
          // repo endi throw qiladi; listener callback'da unhandled bo'lmasin).
        }
      }

      final c = repo.createdStream().listen(refresh);
      final a = repo.approvedStream().listen(refresh);
      final r = repo.rejectedStream().listen(refresh);

      ref.onDispose(() {
        c.cancel();
        a.cancel();
        r.cancel();
        controller.close();
      });
      yield* controller.stream;
    });

/// Hammasi (Dashboard badge uchun yig'ma soni).
final allPendingPairRequestsCountProvider = Provider<int>((ref) {
  final children = ref.watch(childrenListProvider);
  var total = 0;
  for (final c in children) {
    final list = ref.watch(pendingPairRequestsProvider(c.id)).valueOrNull;
    total += list?.length ?? 0;
  }
  return total;
});

/// Global pair_request:created event stream — Parent App'da banner.
final pairRequestCreatedProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final auth = ref.watch(backendAuthProvider);
  if (auth is! AuthAuthenticated) return const Stream.empty();
  final repo = ref.watch(backendPairRequestRepositoryProvider);
  return repo
      .createdStream()
      .map((d) => d is Map<String, dynamic> ? d : <String, dynamic>{})
      .where((m) => m.isNotEmpty);
});
