// ─────────────────────────────────────────────────────────────────────
// photo_request_provider — Photo requests state (Sprint 4.4.7)
// ─────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/photo_request/data/repositories/backend_photo_request_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bola uchun photo requests ro'yxati — Backend fetch + WS refresh.
final photoRequestsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
        (ref, childId) async* {
  final auth = ref.watch(backendAuthProvider);
  if (auth is! AuthAuthenticated) {
    yield const [];
    return;
  }

  final repo = ref.watch(backendPhotoRequestRepositoryProvider);
  yield await repo.getRequests(childId: childId);

  final controller = StreamController<List<Map<String, dynamic>>>();
  Future<void> refresh() async {
    if (controller.isClosed) return;
    final list = await repo.getRequests(childId: childId);
    if (!controller.isClosed) controller.add(list);
  }

  final createdSub = repo.createdStream().listen((data) {
    if (data is Map && data['childId'] == childId) refresh();
  });
  final completedSub = repo.completedStream().listen((data) {
    if (data is Map && data['childId'] == childId) refresh();
  });
  final declinedSub = repo.declinedStream().listen((data) {
    if (data is Map && data['childId'] == childId) refresh();
  });

  ref.onDispose(() {
    createdSub.cancel();
    completedSub.cancel();
    declinedSub.cancel();
    controller.close();
  });
  yield* controller.stream;
});

/// Photo request action'lari (Parent — create + delete).
class PhotoRequestActionsNotifier
    extends StateNotifier<AsyncValue<void>> {
  PhotoRequestActionsNotifier(this._ref)
      : super(const AsyncValue.data(null));

  final Ref _ref;

  BackendPhotoRequestRepository get _repo =>
      _ref.read(backendPhotoRequestRepositoryProvider);

  /// Parent yangi rasm so'rovi yaratadi.
  Future<bool> createRequest({
    required String childId,
    String? message,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.createRequest(childId: childId, message: message);
      _ref.invalidate(photoRequestsProvider(childId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteRequest({
    required String childId,
    required String requestId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final ok = await _repo.deleteRequest(requestId);
      if (ok) _ref.invalidate(photoRequestsProvider(childId));
      state = const AsyncValue.data(null);
      return ok;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final photoRequestActionsProvider = StateNotifierProvider<
    PhotoRequestActionsNotifier, AsyncValue<void>>(
  PhotoRequestActionsNotifier.new,
);
