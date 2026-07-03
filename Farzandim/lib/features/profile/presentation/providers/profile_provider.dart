// Ota-ona profili holati — backend /users/me bilan sinxron.

import 'dart:typed_data';

import 'package:farzandim/features/auth/data/repositories/backend_user_repository.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/profile/data/models/parent_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ota-ona profili — backend `/users/me` bilan sinxronlanadi.
///
/// Auth holati o'zgarganda profil qayta yuklanadi; `updateProfile`
/// PUT yuborib state'ni yangilaydi.
class ProfileNotifier extends StateNotifier<ParentProfile> {
  ProfileNotifier({
    required BackendUserRepository repository,
    required BackendAuthState initialAuthState,
  }) : _repository = repository,
       super(_initialState(initialAuthState)) {
    // Auth allaqachon tayyor bo'lsa darhol to'liq profilni olib kelamiz.
    if (initialAuthState is AuthAuthenticated) {
      _load();
    }
  }

  final BackendUserRepository _repository;

  static ParentProfile _initialState(BackendAuthState authState) {
    if (authState is AuthAuthenticated) {
      // Auth javobidagi user — boshlang'ich profil; to'liq versiyani
      // keyin `_load()` olib keladi.
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

  /// Profil tahrirlash — backend'ga PUT yuboradi, javob state'ga yoziladi.
  /// Xato bo'lsa exception otiladi — caller xabar ko'rsatadi.
  Future<void> updateProfile({required String name, String? language}) async {
    final updated = await _repository.updateMe(name: name, language: language);
    state = ParentProfile.fromAuthUser(updated);
  }

  /// Profil rasmini Backend'ga yuklaydi va profilni qayta yuklab oladi.
  Future<void> uploadAvatar(Uint8List bytes) async {
    await _repository.uploadAvatar(bytes);
    await _load();
  }

  /// Telefon o'zgartirish — 1-qadam: yangi raqamga OTP yuboradi.
  Future<void> requestPhoneOtp(String phone) =>
      _repository.requestPhoneOtp(phone);

  /// Telefon o'zgartirish — 2-qadam: OTP tasdiqlab saqlaydi va profilni
  /// yangilab oladi (yangi raqam UI'da ko'rinishi uchun).
  Future<void> verifyPhoneAndSave({
    required String phone,
    required String code,
  }) async {
    await _repository.verifyPhoneOtp(phone: phone, code: code);
    await _load();
  }
}

/// Profil provider'i — auth state o'zgarishiga listen qiladi.
final profileProvider = StateNotifierProvider<ProfileNotifier, ParentProfile>((
  ref,
) {
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
