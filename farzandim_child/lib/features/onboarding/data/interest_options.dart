// ─────────────────────────────────────────────────────────────────────
// InterestOptions — onboarding'da bola tanlay oladigan qiziqishlar
// ─────────────────────────────────────────────────────────────────────
//
// 12 ta umumiy qiziqish. Har biri:
//   - `id`           — backend'ga yuboriladi (interests array element)
//   - `labelKey`     — easy_localization kaliti (`interests.book` ...)
//   - `icon`         — Material icon (chip ichida ko'rsatiladi)
//   - `accent`       — chip ikon va doiracha rangi (har biri o'z brand rangi)
//   - `contentTags`  — tavsiya tizimi shu tag'larga qarab kontent saralaydi
//                       (Books/Videos/Audiobooks/Olimpiada `category` slug'i)
//
// Backend `Child.interests` `String[]` — shu yerdagi `id`'lar saqlanadi.
// Admin paneldagi profil shu ID'lardan label'larga aylantirib chip qiladi.

// ignore_for_file: public_member_api_docs

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class InterestOption {
  const InterestOption({
    required this.id,
    required this.labelKey,
    required this.icon,
    required this.accent,
    required this.contentTags,
  });

  final String id;

  /// easy_localization kaliti — runtime'da `.tr()` bilan o'zgaradi.
  final String labelKey;
  final IconData icon;

  /// Chip ikon va doiracha rangi — har bir qiziqishga o'z brand rangi
  /// (Duolingo / Notion uslubidagi rangli ikonkalar).
  final Color accent;

  /// ContentCategory.slug'lar — `id` `interests` array'ida bo'lsa shu
  /// kategoriyalardagi kontent tavsiya etiladi (overlap-based sort).
  final List<String> contentTags;

  /// UI'da chiqadigan tarjima qilingan nom.
  String label() => labelKey.tr();
}

/// Onboarding chip grid'da chiqadigan qat'iy ro'yxat.
/// O'zgartirilsa `_v1` schema buziladi — yangi versiyaga `_v2` qo'shish.
///
/// Ikonalar 2026 modern Material Symbols Rounded — bolaga tanish va
/// jonli (auto_stories, theaters, biotech, flight_takeoff va h.k.).
const List<InterestOption> kInterestOptions = [
  InterestOption(
    id: 'book',
    labelKey: 'interests.book',
    icon: Icons.auto_stories_rounded,
    accent: Color(0xFF3B82F6), // blue
    contentTags: ['book', 'adabiyot', 'tarjima', 'school'],
  ),
  InterestOption(
    id: 'cartoon',
    labelKey: 'interests.cartoon',
    icon: Icons.theaters_rounded,
    accent: Color(0xFFA855F7), // purple
    contentTags: ['cartoon', 'animation'],
  ),
  InterestOption(
    id: 'sport',
    labelKey: 'interests.sport',
    icon: Icons.sports_basketball_rounded,
    accent: Color(0xFFF97316), // orange
    contentTags: ['sport'],
  ),
  InterestOption(
    id: 'music',
    labelKey: 'interests.music',
    icon: Icons.headphones_rounded,
    accent: Color(0xFFEC4899), // pink
    contentTags: ['music'],
  ),
  InterestOption(
    id: 'animals',
    labelKey: 'interests.animals',
    icon: Icons.pets_rounded,
    accent: Color(0xFF10B981), // emerald
    contentTags: ['animals', 'nature'],
  ),
  InterestOption(
    id: 'space',
    labelKey: 'interests.space',
    icon: Icons.rocket_launch_rounded,
    accent: Color(0xFF6366F1), // indigo
    contentTags: ['space', 'science'],
  ),
  InterestOption(
    id: 'tech',
    labelKey: 'interests.tech',
    icon: Icons.smart_toy_rounded,
    accent: Color(0xFF14B8A6), // teal
    contentTags: ['tech', 'it', 'science'],
  ),
  InterestOption(
    id: 'art',
    labelKey: 'interests.art',
    icon: Icons.brush_rounded,
    accent: Color(0xFFF43F5E), // rose
    contentTags: ['art', 'culture'],
  ),
  InterestOption(
    id: 'science',
    labelKey: 'interests.science',
    icon: Icons.biotech_rounded,
    accent: Color(0xFF06B6D4), // cyan
    contentTags: ['science', 'fan', 'school'],
  ),
  InterestOption(
    id: 'games',
    labelKey: 'interests.games',
    icon: Icons.videogame_asset_rounded,
    accent: Color(0xFF8B5CF6), // violet
    contentTags: ['game', 'games'],
  ),
  InterestOption(
    id: 'travel',
    labelKey: 'interests.travel',
    icon: Icons.flight_takeoff_rounded,
    accent: Color(0xFF0EA5E9), // sky
    contentTags: ['travel', 'geography'],
  ),
  InterestOption(
    id: 'food',
    labelKey: 'interests.food',
    icon: Icons.cookie_rounded,
    accent: Color(0xFFF59E0B), // amber
    contentTags: ['food', 'cooking'],
  ),
];

/// ID → InterestOption tezkor topish uchun (profile/admin display'da).
final Map<String, InterestOption> kInterestById = {
  for (final o in kInterestOptions) o.id: o,
};

/// SharedPreferences kaliti — onboarding'da tanlangan, hali backend'ga
/// yuborilmagan tag'lar (pairing tugagach sync qilinadi).
const String kPendingInterestsKey = 'child_interests_pending_v1';

/// Backend'ga muvaffaqiyatli yuborilganidan keyin saqlanadigan cache.
/// Profile/Dashboard local read uchun (offline ham ko'rinadi).
const String kSyncedInterestsKey = 'child_interests_synced_v1';
