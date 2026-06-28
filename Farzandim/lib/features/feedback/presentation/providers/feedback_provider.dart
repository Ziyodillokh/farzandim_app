// Parent feedback inbox holati — bola yuborgan emoji + matn.

import 'dart:async';

import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/feedback/data/repositories/backend_feedback_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bola feedback ro'yxati — initial fetch + WS real-time append.
final childFeedbackProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      childId,
    ) async* {
      final auth = ref.watch(backendAuthProvider);
      if (auth is! AuthAuthenticated) {
        yield const [];
        return;
      }

      final repo = ref.watch(backendFeedbackRepositoryProvider);
      yield await repo.getFeedback(childId: childId);

      // WS `feedback:received` — bola yangi emoji yubordi (parent user room).
      final controller = StreamController<List<Map<String, dynamic>>>();
      final sub = repo.receivedStream().listen((data) async {
        if (data is Map && data['childId'] == childId) {
          final fresh = await repo.getFeedback(childId: childId);
          if (!controller.isClosed) controller.add(fresh);
        }
      });

      ref.onDispose(() {
        sub.cancel();
        controller.close();
      });
      yield* controller.stream;
    });

/// O'qilmagan feedback soni (badge uchun).
final unreadFeedbackCountProvider = Provider.family<int, String>((
  ref,
  childId,
) {
  final list =
      ref.watch(childFeedbackProvider(childId)).valueOrNull ?? const [];
  return list.where((f) => f['isRead'] == false).length;
});
