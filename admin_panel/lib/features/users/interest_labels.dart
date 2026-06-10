// ─────────────────────────────────────────────────────────────────────
// InterestLabels — admin paneldagi bola qiziqishlari uchun ID → label/icon
// ─────────────────────────────────────────────────────────────────────
//
// Bola child appda onboarding'da tanlagan ID'lar backend'da `interests
// String[]` sifatida saqlanadi. Admin paneldagi profilda chip ko'rinishida
// ko'rsatish uchun shu fayl mapping beradi.
//
// Manba (truth source) — farzandim_child/lib/features/onboarding/data/
// interest_options.dart. Ikkala ro'yxat qo'lda sinxron tutiladi.

import 'package:flutter/material.dart';

class InterestMeta {
  const InterestMeta({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

const Map<String, InterestMeta> kAdminInterestLabels = {
  'book': InterestMeta(label: 'Kitoblar', icon: Icons.menu_book_rounded),
  'cartoon':
      InterestMeta(label: 'Multfilmlar', icon: Icons.movie_filter_rounded),
  'sport': InterestMeta(label: 'Sport', icon: Icons.sports_soccer_rounded),
  'music': InterestMeta(label: 'Musiqa', icon: Icons.music_note_rounded),
  'animals': InterestMeta(label: 'Hayvonlar', icon: Icons.pets_rounded),
  'space': InterestMeta(label: 'Kosmos', icon: Icons.rocket_launch_rounded),
  'tech': InterestMeta(label: 'Texnologiya', icon: Icons.memory_rounded),
  'art': InterestMeta(label: "San'at", icon: Icons.palette_rounded),
  'science': InterestMeta(label: 'Fan', icon: Icons.science_rounded),
  'games': InterestMeta(label: "O'yinlar", icon: Icons.sports_esports_rounded),
  'travel': InterestMeta(label: 'Sayohat', icon: Icons.map_rounded),
  'food': InterestMeta(label: 'Ovqat', icon: Icons.restaurant_rounded),
};

/// Noma'lum id uchun fallback (backend yangi tag qo'shgan, admin panel
/// hali yangilanmagan holatlarda).
InterestMeta labelFor(String id) {
  return kAdminInterestLabels[id] ??
      InterestMeta(label: id, icon: Icons.label_outline_rounded);
}
