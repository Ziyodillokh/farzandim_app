// ─────────────────────────────────────────────────────────────────────
// children_provider — Backend REST only (Sprint 4.4.22 cleanup)
// ─────────────────────────────────────────────────────────────────────
//
// Sprint 4.4 migrationdan keyin Firebase fallback olib tashlandi.
// Bolalar ma'lumotlari faqat Backend REST orqali keladi (Telegram auth).

import 'dart:async';
import 'dart:typed_data';

import 'package:farzandim/core/utils/extensions.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/data/models/gender.dart';
import 'package:farzandim/features/child_management/data/repositories/backend_child_repository.dart';
import 'package:farzandim/shared/models/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bolalar ro'yxati — Backend REST orqali.
///
/// Auth bo'lmasa bo'sh ro'yxat qaytaradi.
/// CRUD operatsiyadan keyin `ref.invalidate(childrenProvider)` chaqiriladi.
final childrenProvider = StreamProvider<List<Child>>((ref) {
  final backendAuth = ref.watch(backendAuthProvider);
  if (backendAuth is AuthAuthenticated) {
    return _backendChildrenStream(ref);
  }
  return Stream.value(const <Child>[]);
});

/// Backend REST'dan bolalarni o'qiydi.
Stream<List<Child>> _backendChildrenStream(Ref ref) async* {
  final repo = ref.watch(backendChildRepositoryProvider);
  try {
    yield await repo.getChildren();
  } catch (_) {
    yield const <Child>[];
  }
}

/// Bolalar ro'yxati — sinxron access.
final childrenListProvider = Provider<List<Child>>((ref) {
  return ref.watch(childrenProvider).valueOrNull ?? const <Child>[];
});

/// `id` bo'yicha bolani topish (sync).
final childByIdProvider = Provider.family<Child?, String>((ref, id) {
  return ref
      .watch(childrenListProvider)
      .firstWhereOrNull((c) => c.id == id);
});

/// Bola CRUD harakatlari uchun notifier.
class ChildActionsNotifier extends StateNotifier<AsyncValue<void>> {
  ChildActionsNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  BackendChildRepository get _repo =>
      _ref.read(backendChildRepositoryProvider);

  void _invalidateList() => _ref.invalidate(childrenProvider);

  void _invalidateAvatar(String childId) =>
      _ref.invalidate(childAvatarUrlProvider(childId));

  /// Yangi bola qo'shish.
  Future<Result<Child>> addChild({
    required String name,
    required int age,
    required Gender gender,
    required String region,
    Uint8List? photoBytes,
    String? deviceModel,
  }) async {
    state = const AsyncValue.loading();
    try {
      var child = await _repo.addChild(
        name: name,
        age: age,
        gender: gender,
        region: region,
      );
      if (photoBytes != null) {
        try {
          child = await _repo.uploadAvatar(child.id, photoBytes);
          _invalidateAvatar(child.id);
        } catch (_) {
          // Avatar upload xato — fotosiz davom etamiz.
        }
      }
      state = const AsyncValue.data(null);
      _invalidateList();
      return Result.success(child);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return Result.failure(e.toString());
    }
  }

  /// Bola ma'lumotlarini yangilash.
  Future<Result<void>> updateChild(
    String childId,
    Child updated, {
    Uint8List? newPhotoBytes,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateChild(childId, updated);
      if (newPhotoBytes != null) {
        try {
          await _repo.uploadAvatar(childId, newPhotoBytes);
          _invalidateAvatar(childId);
        } catch (_) {
          // Avatar upload xato — metadata saqlangan, fotosiz.
        }
      }
      state = const AsyncValue.data(null);
      _invalidateList();
      return const Result<void>.success();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return Result.failure(e.toString());
    }
  }

  /// Yangi pair-code generatsiya.
  Future<Result<String>> regenerateFamilyCode(String childId) async {
    state = const AsyncValue.loading();
    try {
      final newCode = await _repo.regenerateFamilyCode(childId);
      state = const AsyncValue.data(null);
      _invalidateList();
      return Result.success(newCode);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return Result.failure(e.toString());
    }
  }

  /// Bolani o'chirish (Backend cascade delete).
  Future<Result<void>> deleteChild(String childId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteChild(childId);
      state = const AsyncValue.data(null);
      _invalidateList();
      return const Result<void>.success();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return Result.failure(e.toString());
    }
  }
}

final childActionsProvider =
    StateNotifierProvider<ChildActionsNotifier, AsyncValue<void>>(
  ChildActionsNotifier.new,
);

/// Bola avatar URL — Backend signed URL (1 soat amal qiladi).
final childAvatarUrlProvider =
    FutureProvider.family<String?, String>((ref, childId) async {
  final backendAuth = ref.watch(backendAuthProvider);
  if (backendAuth is! AuthAuthenticated) return null;
  final repo = ref.watch(backendChildRepositoryProvider);
  return repo.getAvatarUrl(childId);
});
