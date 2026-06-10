// ─────────────────────────────────────────────────────────────────────
// InterestOptions — onboarding'da bola tanlay oladigan qiziqishlar
// ─────────────────────────────────────────────────────────────────────
//
// 12 ta umumiy qiziqish. Har biri:
//   - `id`           — backend'ga yuboriladi (interests array element)
//   - `label`        — UI'da ko'rinadigan o'zbekcha nomi
//   - `icon`         — Material icon (chip ichida ko'rsatiladi)
//   - `contentTags`  — tavsiya tizimi shu tag'larga qarab kontent saralaydi
//                       (Books/Videos/Audiobooks/Olimpiada `category` slug'i)
//
// Backend `Child.interests` `String[]` — shu yerdagi `id`'lar saqlanadi.
// Admin paneldagi profil shu ID'lardan label'larga aylantirib chip qiladi.

// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';

class InterestOption {
  const InterestOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.contentTags,
  });

  final String id;
  final String label;
  final IconData icon;

  /// ContentCategory.slug'lar — `id` `interests` array'ida bo'lsa shu
  /// kategoriyalardagi kontent tavsiya etiladi (overlap-based sort).
  final List<String> contentTags;
}

/// Onboarding chip grid'da chiqadigan qat'iy ro'yxat.
/// O'zgartirilsa `_v1` schema buziladi — yangi versiyaga `_v2` qo'shish.
const List<InterestOption> kInterestOptions = [
  InterestOption(
    id: 'book',
    label: 'Kitoblar',
    icon: Icons.menu_book_rounded,
    contentTags: ['book', 'adabiyot', 'tarjima'],
  ),
  InterestOption(
    id: 'cartoon',
    label: 'Multfilmlar',
    icon: Icons.movie_filter_rounded,
    contentTags: ['cartoon', 'animation'],
  ),
  InterestOption(
    id: 'sport',
    label: 'Sport',
    icon: Icons.sports_soccer_rounded,
    contentTags: ['sport'],
  ),
  InterestOption(
    id: 'music',
    label: 'Musiqa',
    icon: Icons.music_note_rounded,
    contentTags: ['music'],
  ),
  InterestOption(
    id: 'animals',
    label: 'Hayvonlar',
    icon: Icons.pets_rounded,
    contentTags: ['animals', 'nature'],
  ),
  InterestOption(
    id: 'space',
    label: 'Kosmos',
    icon: Icons.rocket_launch_rounded,
    contentTags: ['space', 'science'],
  ),
  InterestOption(
    id: 'tech',
    label: 'Texnologiya',
    icon: Icons.memory_rounded,
    contentTags: ['tech', 'it', 'science'],
  ),
  InterestOption(
    id: 'art',
    label: "San'at",
    icon: Icons.palette_rounded,
    contentTags: ['art', 'culture'],
  ),
  InterestOption(
    id: 'science',
    label: 'Fan',
    icon: Icons.science_rounded,
    contentTags: ['science', 'fan', 'school'],
  ),
  InterestOption(
    id: 'games',
    label: "O'yinlar",
    icon: Icons.sports_esports_rounded,
    contentTags: ['game', 'games'],
  ),
  InterestOption(
    id: 'travel',
    label: 'Sayohat',
    icon: Icons.map_rounded,
    contentTags: ['travel', 'geography'],
  ),
  InterestOption(
    id: 'food',
    label: 'Ovqat',
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
