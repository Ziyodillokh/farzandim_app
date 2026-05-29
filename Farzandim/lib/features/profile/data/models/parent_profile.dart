import 'package:farzandim/features/auth/data/models/auth_models.dart';
import 'package:flutter/foundation.dart';

/// Ota-ona profili.
///
/// **Sprint 4.4.1'dan boshlab Backend manba** — `BackendUserRepository.me()`
/// `AuthUser` qaytaradi → `ParentProfile.fromAuthUser` orqali aylanadi.
/// Eski Firestore parse (`fromFirestore`) o'tish davrida saqlanadi va
/// migration tugagach olib tashlanadi.
///
/// Mapping (Backend → ParentProfile):
/// - `AuthUser.displayName` → `name`
/// - `AuthUser.photoUrl`    → `photoUrl` (Telegram avatar URL)
/// - Backend'da hozir parent `email`/`phoneNumber` field yo'q —
///   `null` qoldiriladi. Telefon raqami keyinroq `/users/me/phone`
///   endpoint orqali ulanadi.
@immutable
class ParentProfile {
  /// `ParentProfile` konstruktor.
  const ParentProfile({
    required this.name,
    this.phoneNumber,
    this.email,
    this.photoUrl,
    this.photoBytes,
  });

  /// Backend `AuthUser`'dan profil yaratish (Sprint 4.4.1).
  factory ParentProfile.fromAuthUser(AuthUser user) {
    return ParentProfile(
      name: (user.displayName ?? '').trim(),
      photoUrl: user.photoUrl,
    );
  }

  /// Bo'sh boshlang'ich profil — Backend hydrate'gacha state.
  static const ParentProfile empty = ParentProfile(name: '');

  /// Foydalanuvchi ismi (Firestore: `displayName`).
  final String name;

  /// Telefon raqami (`+998 90 123 45 67` formati). Bo'sh -> `null`.
  final String? phoneNumber;

  /// Email manzili. Bo'sh -> `null`.
  final String? email;

  /// Avatar URL (Backend `User.avatarUrl` — Telegram avatar).
  final String? photoUrl;

  /// Profil rasmi bayt massivi — faqat tahrirlash sessiyasida (transient).
  final Uint8List? photoBytes;

  /// Yangi `ParentProfile` — bitta yoki bir nechta maydonni o'zgartiradi.
  ParentProfile copyWith({
    String? name,
    String? phoneNumber,
    String? email,
    String? photoUrl,
    Uint8List? photoBytes,
  }) {
    return ParentProfile(
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      photoBytes: photoBytes ?? this.photoBytes,
    );
  }
}
