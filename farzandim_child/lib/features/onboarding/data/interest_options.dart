// ─────────────────────────────────────────────────────────────────────
// InterestOptions — onboarding'da bola tanlay oladigan qiziqishlar
// ─────────────────────────────────────────────────────────────────────
//
// 12 ta umumiy qiziqish. Har biri:
//   - `id`           — backend'ga yuboriladi (interests array element)
//   - `labelKey`     — easy_localization kaliti (`interests.book` ...)
//   - `icon`         — Material icon (chip ichida ko'rsatiladi)
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
    required this.contentTags,
  });

  final String id;

  /// easy_localization kaliti — runtime'da `.tr()` bilan o'zgaradi.
  final String labelKey;
  final IconData icon;

  /// ContentCategory.slug'lar — `id` `interests` array'ida bo'lsa shu
  /// kategoriyalardagi kontent tavsiya etiladi (overlap-based sort).
  final List<String> contentTags;

  /// UI'da chiqadigan tarjima qilingan nom.
  String label() => labelKey.tr();
}

/// Onboarding chip grid'da chiqadigan qat'iy ro'yxat.
/// O'zgartirilsa `_v1` schema buziladi — yangi versiyaga `_v2` qo'shish.
const List<InterestOption> kInterestOptions = [
  InterestOption(
    id: 'book',
    labelKey: 'interests.book',
    icon: Icons.menu_book_rounded,
    contentTags: ['book', 'adabiyot', 'tarjima', 'school'],
  ),
  InterestOption(
    id: 'cartoon',
    labelKey: 'interests.cartoon',
    icon: Icons.movie_filter_rounded,
    contentTags: ['cartoon', 'animation'],
  ),
  InterestOption(
    id: 'sport',
    labelKey: 'interests.sport',
    icon: Icons.sports_soccer_rounded,
    contentTags: ['sport'],
  ),
  InterestOption(
    id: 'music',
    labelKey: 'interests.music',
    icon: Icons.music_note_rounded,
    contentTags: ['music'],
  ),
  InterestOption(
    id: 'animals',
    labelKey: 'interests.animals',
    icon: Icons.pets_rounded,
    contentTags: ['animals', 'nature'],
  ),
  InterestOption(
    id: 'space',
    labelKey: 'interests.space',
    icon: Icons.rocket_launch_rounded,
    contentTags: ['space', 'science'],
  ),
  InterestOption(
    id: 'tech',
    labelKey: 'interests.tech',
    icon: Icons.memory_rounded,
    contentTags: ['tech', 'it', 'science'],
  ),
  InterestOption(
    id: 'art',
    labelKey: 'interests.art',
    icon: Icons.palette_rounded,
    contentTags: ['art', 'culture'],
  ),
  InterestOption(
    id: 'science',
    labelKey: 'interests.science',
    icon: Icons.science_rounded,
    contentTags: ['science', 'fan', 'school'],
  ),
  InterestOption(
    id: 'games',
    labelKey: 'interests.games',
    icon: Icons.sports_esports_rounded,
    contentTags: ['game', 'games'],
  ),
  InterestOption(
    id: 'travel',
    labelKey: 'interests.travel',
    icon: Icons.map_rounded,
    contentTags: ['travel', 'geography'],
  ),
  InterestOption(
    id: 'food',
    labelKey: 'interests.food',
    icon: Icons.restaurant_rounded,
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
