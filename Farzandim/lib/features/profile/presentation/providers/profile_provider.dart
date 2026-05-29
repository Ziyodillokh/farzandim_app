// ─────────────────────────────────────────────────────────────────────
// ProfileProvider — Parent profil state (Sprint 4.4.1 — Backend)
// ─────────────────────────────────────────────────────────────────────
//
// Eski versiya: Firestore `users/{uid}` real-time listen + Firebase
// Storage avatar upload. Sprint 4.4.1'da Backend REST'ga ko'chirildi:
//
//   GET /api/users/me     — startup'da va auth state o'zgarganda fetch
//   PUT /api/users/me     — updateProfile() chaqirilganda PUT yuboriladi
//
// Backend'da hozir parent avatar upload endpoint YO'Q. Telegram'dan
// kelgan `avatarUrl` ko'rsatiladi. Foydalanuvchi rasmni o'zgartirib bo'lmaydi
// (UI tomonida disabled). Backend endpoint qo'shilganda Yana ulanadi.

import 'dart:typed_data';

import 'package:farzandim/features/auth/data/repositories/backend_user_repository.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/profile/data/models/parent_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ota-ona profili — Backend `/api/users/me` bilan sinxronlanadi.
///
/// Lifecycle:
/// 1. App boshlanganda `BackendAuthState` `AuthAuthenticated` bo'lsa,
///    notifier konstruktor'da Backend'dan profil oladi (`_load`)
/// 2. Auth state'i o'zgarsa (login/logout) — `ref.listen` orqali yangilanish
/// 3. `updateProfile(...)` PUT /users/me yuboradi va state'ni yangilaydi
class ProfileNotifier extends StateNotifier<ParentProfile> {
  /// `ProfileNotifier` konstruktor.
  ProfileNotifier({
    required BackendUserRepository repository,
    required BackendAuthState initialAuthState,
  })  : _repository = repository,
        super(_initialState(initialAuthState)) {
    // Agar auth allaqachon Authenticated bo'lsa darhol Backend'dan fetch
    // (AuthUser obyektida `language` bo'lmasligi mumkin — toza versiya).
    if (initialAuthState is AuthAuthenticated) {
      _load();
    }
  }

  final BackendUserRepository _repository;

  static ParentProfile _initialState(BackendAuthState authState) {
    if (authState is AuthAuthenticated) {
      // Auth javobidagi user'dan boshlang'ich profil yaratamiz, keyin
      // `_load()` Backend'dan to'liq versiyani oladi.
      return ParentProfile.fromAuthUser(authState.user);
    }
    return ParentProfile.empty;
  }

  /// Backend'dan profilni yangilab olish.
  Future<void> _load() async {
    final user = await _repository.me();
    if (user == null) return;
    state = ParentProfile.fromAuthUser(user);
  }

  /// Auth state o'zgarganda chaqiriladi (provider'da `ref.listen`).
  void onAuthChanged(BackendAuthState authState) {
    if (authState is AuthAuthenticated) {
      state = ParentProfile.fromAuthUser(authState.user);
      _load();
    } else {
      state = ParentProfile.empty;
    }
  }

  /// Profil tahrirlash — Backend'ga PUT yuboradi, response state'ga yoziladi.
  ///
  /// Backend'da `email`/`phoneNumber` field YO'Q — bu metodda `name` (va
  /// kelajakda `language`) qabul qilinadi. `photoBytes` parametri Sprint
  /// 4.4.1'da hech qanday joyga yuborilmaydi (avatar upload backend
  /// endpoint kelguncha disabled).
  ///
  /// Xato bo'lsa `Exception` qayta otiladi — caller SnackBar ko'rsatadi.
  Future<void> updateProfile({
    required String name,
    String? language,
  }) async {
    final updated = await _repository.updateMe(
      name: name,
      language: language,
    );
    state = ParentProfile.fromAuthUser(updated);
  }

  /// Profil rasmini Backend'ga yuklaydi va profilni qayta yuklab oladi.
  Future<void> uploadAvatar(Uint8List bytes) async {
    await _repository.uploadAvatar(bytes);
    await _load();
  }
}

/// Profil provider'i. `BackendAuthState`'ga listen qiladi.
///
/// Foydalanish:
/// ```dart
/// final profile = ref.watch(profileProvider);
/// await ref.read(profileProvider.notifier).updateProfile(name: 'Ali');
/// ```
final profileProvider =
    StateNotifierProvider<ProfileNotifier, ParentProfile>((ref) {
  final notifier = ProfileNotifier(
    repository: ref.watch(backendUserRepositoryProvider),
    initialAuthState: ref.read(backendAuthProvider),
  );
  // Auth state o'zgarganda profilni qayta yuklash.
  ref.listen<BackendAuthState>(backendAuthProvider, (previous, next) {
    notifier.onAuthChanged(next);
  });
  return notifier;
});
