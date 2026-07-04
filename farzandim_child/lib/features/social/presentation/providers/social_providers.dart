// ─────────────────────────────────────────────────────────────────────
// social_providers — Riverpod state
// ─────────────────────────────────────────────────────────────────────
//
// Real backend'da social feed hali yo'q — ro'yxatlar bo'sh (mock o'chirildi).
// Backend tayyor bo'lganda shu provayderlar REST/WS'ga ulanadi.

import 'package:farzandim_child/features/social/data/models/social_post.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SocialFeedTab { following, forYou }

/// Joriy tab — "Following" yoki "Siz uchun".
final socialFeedTabProvider = StateProvider<SocialFeedTab>(
  (_) => SocialFeedTab.following,
);

/// Bola kuzatadigan author ID'lari (Set — qo'shish/o'chirish tez).
final followingAuthorIdsProvider = StateProvider<Set<String>>(
  (_) => <String>{},
);

/// Bola yoqtirgan post ID'lari.
final likedPostIdsProvider = StateProvider<Set<String>>(
  (_) => <String>{},
);

/// Barcha postlar — backend yo'q, hozircha bo'sh (real holat).
final allSocialPostsProvider = Provider<List<SocialPost>>((_) {
  return const <SocialPost>[];
});

/// Filtered postlar — joriy tab'ga ko'ra.
final filteredSocialPostsProvider = Provider<List<SocialPost>>((ref) {
  final tab = ref.watch(socialFeedTabProvider);
  final all = ref.watch(allSocialPostsProvider);

  switch (tab) {
    case SocialFeedTab.following:
      final following = ref.watch(followingAuthorIdsProvider);
      return all.where((p) => following.contains(p.author.id)).toList();
    case SocialFeedTab.forYou:
      return all; // hozircha barchasi
  }
});
