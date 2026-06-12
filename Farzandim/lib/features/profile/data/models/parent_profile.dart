import 'package:farzandim/features/auth/data/models/auth_models.dart';
import 'package:flutter/foundation.dart';

/// Ota-ona profili.
///
/// Backend `/users/me` qaytargan `AuthUser`'dan `fromAuthUser` orqali
/// yasaladi.
@immutable
class ParentProfile {
  const ParentProfile({
    required this.name,
    this.phoneNumber,
    this.email,
    this.photoUrl,
    this.photoBytes,
  });

  /// Backend `AuthUser`'dan profil yaratish.
  factory ParentProfile.fromAuthUser(AuthUser user) {
    return ParentProfile(
      name: (user.displayName ?? '').trim(),
      photoUrl: user.photoUrl,
      phoneNumber: user.phone,
      email: user.email,
    );
  }

  /// Bo'sh boshlang'ich profil — backend'dan yuklangunga qadar state.
  static const ParentProfile empty = ParentProfile(name: '');

  /// Foydalanuvchi ismi.
  final String name;

  /// Telefon raqami (`+998 90 123 45 67` formati). Bo'sh -> `null`.
  final String? phoneNumber;

  /// Email manzili. Bo'sh -> `null`.
  final String? email;

  /// Avatar URL.
  final String? photoUrl;

  /// Profil rasmi bayt massivi — faqat tahrirlash sessiyasida (transient).
  final Uint8List? photoBytes;

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
